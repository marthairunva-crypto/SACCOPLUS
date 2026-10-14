import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../core/firebase_service.dart';
import '../core/constants.dart';

/// Reporting service. Trial Balance, Balance Sheet and the Dashboard all read
/// their balances from [getPosition], so they can never disagree.
class ReportService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;

  /// The SACCO's OWN cash / bank / mobile-money accounts.
  /// Each doc: tenantId, type ('cash' | 'bank' | 'mobile_money'), balance (num).
  /// >>> Change this to whatever collection CashBankScreen writes to. <<<
  static const String cashAccountsCol = 'saccoplus-cash-accounts';

  /// Loans that still have money outstanding.
  static const _live = {'Active', 'active', 'Overdue', 'overdue', 'Disbursed', 'disbursed', 'Approved', 'approved'};

  /// Loans where money has actually left the SACCO.
  /// NOTE: 'approved' is deliberately excluded (approved != paid out).
  /// If in your system approving == disbursing, add 'approved' to both sets.
  static const _everDisbursed = {
    'Active', 'active', 'Overdue', 'overdue', 'Disbursed', 'disbursed', 
    'Paid', 'paid', 'closed', 'completed'
  };

  // ─── helpers ──────────────────────────────────────────────────────────────
  static int _i(dynamic v) => v is num ? v.toInt() : 0;
  static String _st(dynamic v) => (v?.toString() ?? '').toLowerCase();
  static DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static int _loanAmount(Map<String, dynamic> d) => _i(d['loanAmount'] ?? d['amount']);
  static int _principalPaid(Map<String, dynamic> d) =>
      _i(d['principalPaid'] ?? d['totalRepaid'] ?? d['amountPaid']);
  static int _principalOut(Map<String, dynamic> d) => d.containsKey('principalOutstanding')
      ? _i(d['principalOutstanding'])
      : _loanAmount(d) - _principalPaid(d);
  static int _interestOut(Map<String, dynamic> d) {
    if (d.containsKey('interestOutstanding')) return _i(d['interestOutstanding']);
    final r = _i(d['interest']) - _i(d['interestPaid']);
    return r > 0 ? r : 0;
  }

  static Future<List<Map<String, dynamic>>> _tenantLoans() async {
    final s = await _db
        .collection(AppConstants.loansCol)
        .where('tenantId', isEqualTo: _tenantId)
        .get();
    return s.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();
  }

  static Future<Map<String, int>> _cashAccounts() async {
    int cash = 0, bank = 0, mm = 0;
    try {
      final s = await _db
          .collection(cashAccountsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();
      for (final d in s.docs) {
        final x = d.data();
        final b = _i(x['balance']);
        switch (_st(x['type'])) {
          case 'bank':
            bank += b;
            break;
          case 'mobile_money':
          case 'mobile':
          case 'momo':
            mm += b;
            break;
          default:
            cash += b;
        }
      }
    } catch (_) {
      // collection missing / no permission -> treated as nothing recorded
    }
    return {'cash': cash, 'bank': bank, 'mobileMoney': mm};
  }

  // ─── Financial position (single source of truth) ──────────────────────────
  static Future<Map<String, dynamic>> getPosition({DateTime? asOf}) async {
    final members = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    int savings = 0, shares = 0, wallets = 0;
    for (final doc in members.docs) {
      final d = doc.data();
      savings += _i(d['savingsBalance']);
      shares += _i(d['sharesBalance']);
      wallets += _i(d['walletBalance']);
    }

    int principal = 0, interest = 0, liveCount = 0;
    final statusCounts = <String, int>{};
    for (final l in await _tenantLoans()) {
      final s = _st(l['status']);
      statusCounts[s] = (statusCounts[s] ?? 0) + 1;
      if (!_live.contains(s)) continue;
      final out = _principalOut(l);
      if (out > 0) {
        principal += out;
        interest += _interestOut(l);
        liveCount++;
      }
    }

    int fixedDeposits = 0;
    final fds = await _db
        .collection('fixedDeposits')
        .where('tenantId', isEqualTo: _tenantId)
        .where('status', isEqualTo: 'active')
        .get();
    for (final d in fds.docs) {
      fixedDeposits += _i(d.data()['amount']);
    }

    final c = await _cashAccounts();
    final liquid = c['cash']! + c['bank']! + c['mobileMoney']!;

    final totalAssets = liquid + principal + interest;
    // Member savings, wallets and fixed deposits are what the SACCO OWES.
    final totalLiabilities = savings + wallets + fixedDeposits;
    // Member shares are share CAPITAL (equity), not a liability.
    final retained = totalAssets - totalLiabilities - shares;

    return {
      'asOfDate': asOf ?? DateTime.now(),
      'cash': c['cash'],
      'bank': c['bank'],
      'mobileMoney': c['mobileMoney'],
      'liquid': liquid,
      'principal': principal,
      'interest': interest,
      'liveLoanCount': liveCount,
      'savings': savings,
      'wallets': wallets,
      'fixedDeposits': fixedDeposits,
      'shares': shares,
      'totalAssets': totalAssets,
      'totalLiabilities': totalLiabilities,
      'retained': retained,
      // Member money that is not out on loan - should be sitting in cash/bank/mobile money.
      'expectedLiquid': savings + wallets + fixedDeposits + shares - principal,
      // Debug: how many loans per status (check these match the sets above)
      'loanStatusCounts': statusCounts,
    };
  }

  // ─── Trial Balance ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateTrialBalance({DateTime? asOfDate}) async {
    final p = await getPosition(asOf: asOfDate);
    return {
      'asOfDate': p['asOfDate'],
      'assets': {
        'cashInHand': p['cash'],
        'bank': p['bank'],
        'mobileMoney': p['mobileMoney'],
        'liquid': p['liquid'],
        'loansReceivable': {
          'principal': p['principal'],
          'interest': p['interest'],
          'total': p['principal'] + p['interest'],
        },
        'total': p['totalAssets'],
      },
      'liabilities': {
        'memberSavings': p['savings'],
        'memberWallets': p['wallets'],
        'fixedDeposits': p['fixedDeposits'],
        'total': p['totalLiabilities'],
      },
      'equity': {
        'shareCapital': p['shares'],
        'retainedEarnings': p['retained'], // balancing figure, NOT a ledger balance
        'total': p['shares'] + p['retained'],
      },
      'retainedIsBalancingFigure': true,
      'loanStatusCounts': p['loanStatusCounts'],
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Balance Sheet ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateBalanceSheet({DateTime? asOfDate}) async {
    final p = await getPosition(asOf: asOfDate);
    final equity = p['shares'] + p['retained'];
    return {
      'asOfDate': p['asOfDate'],
      'assets': {
        'currentAssets': {
          'cashInHand': p['cash'],
          'bank': p['bank'],
          'mobileMoney': p['mobileMoney'],
          'loansPrincipal': p['principal'],
          'loansInterest': p['interest'],
          'total': p['totalAssets'],
        },
        'total': p['totalAssets'],
      },
      'liabilities': {
        'currentLiabilities': {
          'memberSavings': p['savings'],
          'memberWallets': p['wallets'],
          'fixedDeposits': p['fixedDeposits'],
          'total': p['totalLiabilities'],
        },
        'total': p['totalLiabilities'],
      },
      'equity': {
        'shareCapital': p['shares'],
        'retainedEarnings': p['retained'],
        'total': equity,
      },
      'totalLiabilitiesAndEquity': p['totalLiabilities'] + equity,
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Monthly Report ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateMonthlyReport({
    required int year,
    required int month,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    final period = '${DateFormat.MMMM().format(startDate)} $year';

    bool inRange(DateTime? d) => d != null && !d.isBefore(startDate) && !d.isAfter(endDate);

    try {
      Future<QuerySnapshot<Map<String, dynamic>>> col(String name) =>
          _db.collection(name).where('tenantId', isEqualTo: _tenantId).get();

      final loans = await _tenantLoans();
      final repayments = await col(AppConstants.repaymentsCol);
      final savings = await col(AppConstants.savingsCol);
      final shares = await col(AppConstants.sharesCol);

      int loanN = 0, loanAmt = 0, repN = 0, repAmt = 0, savN = 0, savAmt = 0, shN = 0, shAmt = 0;

      for (final l in loans) {
        if (!_everDisbursed.contains(_st(l['status']))) continue;
        final when = _dt(l['disbursedAt']) ?? _dt(l['createdAt']) ?? _dt(l['timestamp']);
        if (!inRange(when)) continue;
        loanN++;
        loanAmt += _loanAmount(l);
      }
      for (final doc in repayments.docs) {
        final d = doc.data();
        if (!inRange(_dt(d['date']) ?? _dt(d['timestamp']))) continue;
        repN++;
        repAmt += _i(d['amount']);
      }
      for (final doc in savings.docs) {
        final d = doc.data();
        if (!inRange(_dt(d['timestamp']))) continue;
        if (_st(d['type']) == 'deposit' && _st(d['status']) == 'approved') {
          savN++;
          savAmt += _i(d['amount']);
        }
      }
      for (final doc in shares.docs) {
        final d = doc.data();
        if (!inRange(_dt(d['timestamp']))) continue;
        if (_st(d['type']) == 'purchase' && _st(d['status']) == 'approved') {
          shN++;
          shAmt += _i(d['amount']);
        }
      }

      return {
        'period': period,
        'startDate': startDate,
        'endDate': endDate,
        'loans': {'count': loanN, 'amount': loanAmt},
        'repayments': {'count': repN, 'amount': repAmt},
        'savings': {'count': savN, 'amount': savAmt},
        'shares': {'count': shN, 'amount': shAmt},
        'netCashFlow': repAmt + savAmt + shAmt - loanAmt,
        'generatedAt': DateTime.now(),
      };
    } catch (e) {
      // Throw so the screen shows an error + Retry instead of fake zeros.
      throw Exception('Could not build monthly report: $e');
    }
  }

  // ─── KYC Report ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateKYCReport() async {
    final membersSnapshot = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    int total = 0, verified = 0, pending = 0, rejected = 0, notSubmitted = 0;
    final pendingList = <Map<String, dynamic>>[];
    final rejectedList = <Map<String, dynamic>>[];

    for (final doc in membersSnapshot.docs) {
      total++;
      final data = doc.data();
      final idStatus = data['idStatus'] as String? ?? 'not_submitted';
      switch (idStatus) {
        case 'approved':
          verified++;
          break;
        case 'pending':
          pending++;
          final submittedAt = data['idSubmittedAt'];
          pendingList.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? '',
            'submittedAt': submittedAt is Timestamp ? submittedAt.toDate() : DateTime.now(),
          });
          break;
        case 'rejected':
          rejected++;
          rejectedList.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? '',
            'reason': data['idRejectionReason'] ?? 'Not specified',
          });
          break;
        default:
          notSubmitted++;
      }
    }

    return {
      'summary': {
        'total': total,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
        'notSubmitted': notSubmitted,
        'verificationRate': total > 0 ? (verified / total * 100) : 0.0,
      },
      'pendingVerifications': pendingList,
      'rejectedVerifications': rejectedList,
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Loan Report ──────────────────────────────────────────────────────────
  /// All-time by default (a portfolio report must compare like with like).
  /// Filters in memory - no composite index needed.
  static Future<Map<String, dynamic>> generateLoanReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final loans = (await _tenantLoans()).where((l) {
      final c = _dt(l['createdAt']);
      if (startDate != null && (c == null || c.isBefore(startDate))) return false;
      if (endDate != null && (c == null || c.isAfter(endDate))) return false;
      return true;
    }).toList();

    int pending = 0, rejected = 0, paid = 0, overdue = 0;
    int requested = 0, disbursed = 0, repaid = 0, outstanding = 0;
    final overdueLoans = <Map<String, dynamic>>[];
    final activeLoans = <Map<String, dynamic>>[];

    for (final l in loans) {
      final status = _st(l['status']);
      final amount = _loanAmount(l);
      requested += amount;

      if (status == 'pending') pending++;
      if (status == 'rejected') rejected++;

      final isLive = _live.contains(status);
      if (_everDisbursed.contains(status)) {
        disbursed += amount;
        repaid += isLive ? _principalPaid(l) : amount;
      }

      if (!isLive) {
        if (_everDisbursed.contains(status)) paid++;
        continue;
      }

      final out = _principalOut(l);
      if (out <= 0) continue;
      outstanding += out;

      final due = _dt(l['dueDate']);
      final row = <String, dynamic>{
        'id': l['id'],
        'farmerId': l['farmerId'],
        'farmerName': l['farmerName'] ?? l['memberName'] ?? 'Unknown',
        'amount': amount,
        'repaid': _principalPaid(l),
        'outstanding': out,
        'dueDate': due,
      };
      if (due != null && due.isBefore(now)) {
        overdue++;
        overdueLoans.add({...row, 'daysOverdue': now.difference(due).inDays});
      } else {
        activeLoans.add(row);
      }
    }

    final total = loans.length;
    final approved = total - pending - rejected; // ever approved (incl. paid)
    overdueLoans.sort((a, b) => (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int));

    return {
      'period': {'start': startDate, 'end': endDate},
      'summary': {
        'totalLoans': total,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'paid': paid,
        'overdue': overdue,
        'approvalRate': total > 0 ? approved / total * 100 : 0.0,
        'repaymentRate': disbursed > 0 ? repaid / disbursed * 100 : 0.0,
      },
      'financials': {
        'totalAmountRequested': requested,
        'totalAmountDisbursed': disbursed,
        'totalRepaid': repaid,
        'totalOutstanding': outstanding,
      },
      'overdueLoans': overdueLoans,
      'activeLoans': activeLoans,
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Wallet Report ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateWalletReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final end = endDate ?? DateTime.now();

    // Filter dates in memory -> no composite index required.
    final snap = await _db
        .collection('wallet_transactions')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    int total = 0, deposits = 0, withdrawals = 0, transfers = 0, airtime = 0, bills = 0;
    int dAmt = 0, wAmt = 0, tAmt = 0, aAmt = 0, bAmt = 0;
    final all = <Map<String, dynamic>>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = _dt(data['timestamp']);
      if (ts == null || ts.isBefore(start) || ts.isAfter(end)) continue;
      total++;
      final amount = _i(data['amount']);
      all.add({'id': doc.id, ...data, 'timestamp': ts});
      switch (_st(data['type'])) {
        case 'deposit':
          deposits++;
          dAmt += amount;
          break;
        case 'withdrawal':
          withdrawals++;
          wAmt += amount;
          break;
        case 'transfer':
          transfers++;
          tAmt += amount;
          break;
        case 'airtime':
        case 'data':
          airtime++;
          aAmt += amount;
          break;
        case 'bill_payment':
          bills++;
          bAmt += amount;
          break;
      }
    }
    all.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return {
      'period': {'start': start, 'end': end},
      'summary': {
        'totalTransactions': total,
        'deposits': deposits,
        'withdrawals': withdrawals,
        'transfers': transfers,
        'airtimePurchases': airtime,
        'billPayments': bills,
      },
      'financials': {
        'totalDeposits': dAmt,
        'totalWithdrawals': wAmt,
        'totalTransfers': tAmt,
        'totalAirtime': aAmt,
        'totalBills': bAmt,
        'netFlow': dAmt - (wAmt + tAmt + aAmt + bAmt),
      },
      'recentTransactions': all.take(50).toList(),
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Member Report ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateMemberReport() async {
    final membersSnapshot = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    // One query for all loans (was one query per member).
    final byMember = <String, List<Map<String, dynamic>>>{};
    for (final l in await _tenantLoans()) {
      final k = (l['farmerId'] ?? l['memberId'] ?? '').toString();
      if (k.isEmpty) continue;
      byMember.putIfAbsent(k, () => []).add(l);
    }

    final members = <Map<String, dynamic>>[];
    for (final doc in membersSnapshot.docs) {
      final data = doc.data();
      final loans = byMember[doc.id] ?? const <Map<String, dynamic>>[];

      int active = 0, borrowed = 0, repaid = 0, outstanding = 0;
      for (final l in loans) {
        final s = _st(l['status']);
        if (!_everDisbursed.contains(s)) continue;
        final amount = _loanAmount(l);
        borrowed += amount;
        if (_live.contains(s)) {
          repaid += _principalPaid(l);
          final out = _principalOut(l);
          if (out > 0) {
            active++;
            outstanding += out;
          }
        } else {
          repaid += amount;
        }
      }

      members.add({
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'phone': data['phone'] ?? '',
        'email': data['email'] ?? '',
        'idStatus': data['idStatus'] ?? 'not_submitted',
        'membershipDate': _dt(data['createdAt']) ?? DateTime.now(),
        'savingsBalance': _i(data['savingsBalance']),
        'sharesValue': _i(data['sharesBalance'] ?? data['sharesValue']),
        'walletBalance': _i(data['walletBalance']),
        'totalLoans': loans.length,
        'activeLoans': active,
        'totalBorrowed': borrowed,
        'totalRepaid': repaid,
        'outstandingBalance': outstanding,
      });
    }
    return members;
  }

  // ─── Export to CSV Helper ─────────────────────────────────────────────────
  static String exportMembersToCSV(List<Map<String, dynamic>> members) {
    String q(dynamic v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final b = StringBuffer()
      ..writeln('Member ID,Name,Phone,Email,KYC Status,Membership Date,Savings Balance,Shares Value,Wallet Balance,Total Loans,Active Loans,Total Borrowed,Total Repaid,Outstanding Balance');
    for (final m in members) {
      b.writeln([
        q(m['id']),
        q(m['name']),
        q(m['phone']),
        q(m['email']),
        q(m['idStatus']),
        DateFormat('yyyy-MM-dd').format(m['membershipDate'] ?? DateTime.now()),
        m['savingsBalance'],
        m['sharesValue'],
        m['walletBalance'],
        m['totalLoans'],
        m['activeLoans'],
        m['totalBorrowed'],
        m['totalRepaid'],
        m['outstandingBalance'],
      ].join(','));
    }
    return b.toString();
  }
}
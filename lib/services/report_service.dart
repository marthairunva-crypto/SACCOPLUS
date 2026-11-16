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
  /// Each doc: tenantId, type ('cash' | 'bank' | 'till'), balance (num).
  /// FIX: Changed from 'saccoplus-cash-accounts' to 'accounts' (Bug #1).
  static const String cashAccountsCol = 'accounts';

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
      // Accounts created from the "New account" dialog have no tenantId,
      // so load them all and filter in memory (null tenantId = ours).
      final s = await _db.collection(cashAccountsCol).get();
      for (final d in s.docs) {
        final x = d.data();
        final tid = x['tenantId'];
        if (tid != null && tid != _tenantId) continue;
        if (x['isActive'] == false) continue;
        final b = _i(x['balance']);
        switch (_st(x['type'])) {
          case 'bank':
            bank += b;
            break;
          case 'till':
          case 'mobile_money':
          case 'mobile':
          case 'momo':
            mm += b;
            break;
          default:
            cash += b;
        }
      }
    } catch (_) {}
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
    // FIX Bug #7: App writes 'Active' (capital A) and 'principal' (not 'amount')
    // Also handle missing tenantId (Bug #6)
    final fds = await _db.collection(AppConstants.fixedDepositCol).get();
    for (final d in fds.docs) {
      final data = d.data();
      final tid = data['tenantId'];
      if (tid != null && tid != _tenantId) continue;
      final status = _st(data['status']);
      if (status == 'active' || status == 'matured') {
        fixedDeposits += _i(data['principal'] ?? data['amount']);
      }
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
  static const _okStatus = {'approved', 'completed', 'distributed', 'success'};
  static bool _okStat(dynamic s) {
    final x = _st(s);
    return x.isEmpty || _okStatus.contains(x);
  }

  static bool _isReversed(Map<String, dynamic> d) =>
      d['reversed'] == true || d['isReversed'] == true || _st(d['status']) == 'reversed';

  /// Member-app deposits/purchases are paid from the member's WALLET, so they
  /// are not new cash (the wallet top-up was the cash).
  static bool _walletFunded(Map<String, dynamic> d) => d['verificationMethod'] == 'PIN+OTP';

  static DateTime? _firstDate(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = _dt(d[k]);
      if (v != null) return v;
    }
    return null;
  }

  static const _inTypes = {'deposit', 'transfer_in', 'opening'};

  /// Opening / closing balance of cash + bank accounts for a month, rolled back
  /// from the current balance using each account's movements ledger.
  /// Till accounts are overwritten by the till sync (no movements), so they can't
  /// be rolled back: they are returned separately as their CURRENT total.
  /// 
  /// For historical months, tries to load from account_snapshots collection first.
  static Future<Map<String, dynamic>> _cashPosition(DateTime start, DateTime end) async {
    final now = DateTime.now();
    final isHistorical = end.isBefore(now.subtract(const Duration(days: 15)));
    final monthKey = '${start.year}-${start.month.toString().padLeft(2, '0')}';
    
    // Try to load snapshot for historical months
    if (isHistorical) {
      try {
        final snapDoc = await _db
            .collection('account_snapshots')
            .doc('$_tenantId-$monthKey')
            .get();
        if (snapDoc.exists) {
          final data = snapDoc.data()!;
          return {
            'opening': _i(data['opening']),
            'closing': _i(data['closing']),
            'tillsNow': _i(data['tills']),
            'nonTillAccounts': _i(data['nonTillAccounts']),
            'hasManualOpening': data['hasManualOpening'] == true,
            'hasNoCashAccounts': false,
            'fromSnapshot': true,
          };
        }
      } catch (_) {}
    }

    final snap = await _db.collection('accounts').get();
    final startTs = Timestamp.fromDate(start);
    double opening = 0, closing = 0;
    int nonTillCount = 0;

    for (final doc in snap.docs) {
      final a = doc.data();
      final tid = a['tenantId'];
      if (tid != null && tid != _tenantId) continue;
      if (a['isActive'] == false) continue;

      final accountType = _st(a['type']);
      
      // Skip till accounts - we'll query till_sessions separately
      // Tills are ONLY the auto-synced till_<tellerId> accounts
      if (accountType == 'till') continue;

      // Count all non-till accounts (cash, bank, mobile_money)
      // mobile_money accounts (MTN, Airtel) are treated like bank accounts
      nonTillCount++;
      final bal = a['balance'] is num ? (a['balance'] as num).toDouble() : 0.0;
      
      final mv = await doc.reference
          .collection('movements')
          .where('date', isGreaterThanOrEqualTo: startTs)
          .get();

      double sinceStart = 0, afterEnd = 0;
      for (final m in mv.docs) {
        final x = m.data();
        final amt = x['amount'] is num ? (x['amount'] as num).toDouble() : 0.0;
        final signed = _inTypes.contains(_st(x['type'])) ? amt : -amt;
        sinceStart += signed;
        final when = _dt(x['date']);
        if (when != null && when.isAfter(end)) afterEnd += signed;
      }

      opening += bal - sinceStart;
      closing += bal - afterEnd;
    }

    // FIX: Calculate till balance from OPEN till_sessions using AppConstants
    // Per teller: take most recent session by openedAt ?? createdAt
    // open = openingFloat + totalIn - totalOut, closed = 0
    double tills = 0;
    try {
      final allSessions = await _db
          .collection(AppConstants.tillSessionsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();
      
      // Group by tellerId, find most recent per teller
      final Map<String, Map<String, dynamic>> latestByTeller = {};
      
      for (final doc in allSessions.docs) {
        final data = doc.data();
        final tellerId = data['tellerId'] as String?;
        if (tellerId == null) continue;
        
        final openedAt = (data['openedAt'] as Timestamp?)?.toDate() ?? 
                        (data['createdAt'] as Timestamp?)?.toDate();
        if (openedAt == null) continue;
        
        final existing = latestByTeller[tellerId];
        if (existing == null || openedAt.isAfter(existing['date'] as DateTime)) {
          latestByTeller[tellerId] = {'data': data, 'date': openedAt};
        }
      }
      
      // Calculate balance from most recent session per teller
      for (final entry in latestByTeller.values) {
        final data = entry['data'] as Map<String, dynamic>;
        final status = _st(data['status']);
        
        if (status == 'open') {
          final openingFloat = (data['openingFloat'] as num?)?.toDouble() ?? 0.0;
          final totalIn = (data['totalIn'] as num?)?.toDouble() ?? 0.0;
          final totalOut = (data['totalOut'] as num?)?.toDouble() ?? 0.0;
          tills += openingFloat + totalIn - totalOut;
        }
        // closed sessions contribute 0
      }
    } catch (e) {
      print('Could not fetch till sessions: $e');
    }

    // Check if opening balance was manually set
    bool hasManualOpening = false;
    try {
      final snapDoc = await _db
          .collection('account_snapshots')
          .doc('$_tenantId-$monthKey')
          .get();
      
      print('📊 Checking manual opening for $monthKey: exists=${snapDoc.exists}');
      
      if (snapDoc.exists) {
        final data = snapDoc.data()!;
        hasManualOpening = data['hasManualOpening'] == true;
        print('  hasManualOpening=$hasManualOpening, opening=${data['opening']}');
        
        if (hasManualOpening) {
          opening = (data['opening'] as num?)?.toDouble() ?? opening;
          print('  ✅ Using manual opening: $opening');
        }
      } else {
        print('  ⚠️ No snapshot document found');
      }
    } catch (e) {
      print('  ❌ Error loading snapshot: $e');
    }

    // Save snapshot for completed months (15+ days ago)
    if (isHistorical && nonTillCount > 0) {
      _db
          .collection('account_snapshots')
          .doc('$_tenantId-$monthKey')
          .set({
        'tenantId': _tenantId,
        'month': monthKey,
        'opening': opening.round(),
        'closing': closing.round(),
        'tills': tills.round(),
        'nonTillAccounts': nonTillCount,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true))
          .catchError((_) {});
    }

    final hasNoCashAccounts = nonTillCount == 0 && tills == 0;

    return {
      'opening': opening.round(),
      'closing': closing.round(),
      'tillsNow': tills.round(),
      'nonTillAccounts': nonTillCount,
      'hasManualOpening': hasManualOpening,
      'hasNoCashAccounts': hasNoCashAccounts,
      'fromSnapshot': false,
    };
  }

  static Future<Map<String, dynamic>> generateMonthlyReport({
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);
    final prevStart = DateTime(year, month - 1, 1);
    final prevEnd = DateTime(year, month, 0, 23, 59, 59);
    final period = '${DateFormat.MMMM().format(start)} $year';

    try {
      // Many app writes (savings txns, shares, FDs, wallet, income, expenses)
      // don't carry tenantId yet, so load and filter in memory: null = ours.
      Future<List<Map<String, dynamic>>> loose(String name) async {
        final s = await _db.collection(name).get();
        return s.docs
            .map((d) => d.data())
            .where((m) => m['tenantId'] == null || m['tenantId'] == _tenantId)
            .toList();
      }

      Future<List<Map<String, dynamic>>> strict(String name) async {
        final s = await _db.collection(name).where('tenantId', isEqualTo: _tenantId).get();
        return s.docs.map((d) => d.data()).toList();
      }

      Future<List<Map<String, dynamic>>> ledger(String name) async {
        final s = await _db
            .collection(name)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(prevStart))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get();
        return s.docs
            .map((d) => d.data())
            .where((m) => m['tenantId'] == null || m['tenantId'] == _tenantId)
            .toList();
      }

      final loans = await _tenantLoans();
      final repayments = await strict(AppConstants.repaymentsCol);
      final teller = await strict(AppConstants.tellerTxnCol);
      final members = await strict('saccoplus-members');
      final savingsTxns = await loose(AppConstants.savingsTxnCol); // FIX Bug #2: transactions, NOT savingsCol
      
      // FIX: Load share TRANSACTIONS from subcollections, not just the parent shares collection
      final sharesTxns = <Map<String, dynamic>>[];
      final sharesSnap = await _db.collection(AppConstants.sharesCol).get();
      for (final memberShareDoc in sharesSnap.docs) {
        final tid = memberShareDoc.data()['tenantId'];
        if (tid != null && tid != _tenantId) continue;
        final txnsSnap = await memberShareDoc.reference.collection('transactions').get();
        for (final txnDoc in txnsSnap.docs) {
          sharesTxns.add(txnDoc.data());
        }
      }
      
      final fds = await loose(AppConstants.fixedDepositCol);
      final walletTxns = await loose(AppConstants.walletTxnCol);
      final incomeDocs = await ledger('income');
      final expenseDocs = await ledger('expenses');

      String incomeCat(String text) {
        final t = text.toLowerCase();
        if (t.contains('penalt')) return 'Penalties';
        if (t.contains('fee') || t.contains('charge') || t.contains('processing')) return 'Fees';
        if (t.contains('interest')) return 'Interest';
        return 'Other';
      }

      String expenseCat(String text) {
        final t = text.toLowerCase();
        if (t.contains('salar') || t.contains('allowance') || t.contains('welfare')) return 'Salaries';
        if (t.contains('util') || t.contains('airtime') || t.contains('fuel') || t.contains('transport')) {
          return 'Utilities';
        }
        if (t.contains('office') || t.contains('stationery') || t.contains('photocopy') || t.contains('print')) {
          return 'Office Expenses';
        }
        return 'Other';
      }

      // All money movements for one date window.
      Map<String, dynamic> flows(DateTime s, DateTime e) {
        bool within(DateTime? d) => d != null && !d.isBefore(s) && !d.isAfter(e);

        // Loans disbursed
        int loanN = 0, loanAmt = 0;
        for (final l in loans) {
          if (!_everDisbursed.contains(_st(l['status']))) continue;
          if (!within(_firstDate(l, ['disbursedAt', 'createdAt', 'timestamp']))) continue;
          loanN++;
          loanAmt += _loanAmount(l);
        }

        // Repayments (FIX Bug #4: multiple date fields, skip reversed)
        int repN = 0, repAmt = 0, repInterest = 0, repCharges = 0, repPrincipalDirect = 0;
        for (final d in repayments) {
          if (_isReversed(d)) continue;
          if (!within(_firstDate(d, ['paymentDate', 'paidAt', 'date', 'timestamp', 'createdAt']))) continue;
          repN++;
          repAmt += _i(d['amount']);
          // Support both field name variations
          repInterest += _i(d['interestAmount'] ?? d['interestPayment']);
          repCharges += _i(d['chargesAmount'] ?? d['chargesPayment']);
          // Some repayments may have principalPayment directly
          if (d.containsKey('principalPayment')) {
            repPrincipalDirect += _i(d['principalPayment']);
          }
        }
        // Calculate principal: use direct if available, else derive
        final repPrincipal = repPrincipalDirect > 0 
            ? repPrincipalDirect 
            : (repAmt - repInterest - repCharges).clamp(0, repAmt);

        // Savings deposits / withdrawals
        int savN = 0, savAmt = 0, savWallet = 0, wdN = 0, wdNet = 0, wdCharges = 0;
        for (final d in savingsTxns) {
          if (!_okStat(d['status'])) continue;
          if (!within(_firstDate(d, ['timestamp', 'createdAt']))) continue;
          final type = _st(d['type']);
          if (type == 'deposit') {
            if (_walletFunded(d)) {
              savWallet += _i(d['amount']);
            } else {
              savN++;
              savAmt += _i(d['amount']);
            }
          } else if (type == 'withdrawal') {
            final amt = _i(d['amount']);
            final net = d.containsKey('netAmount') ? _i(d['netAmount']) : amt;
            wdN++;
            wdNet += net;
            wdCharges += amt - net;
          }
        }

        // Share purchases (FIX: Load from subcollections, support multiple date fields and type variations)
        int shN = 0, shAmt = 0, shWallet = 0;
        for (final d in sharesTxns) {
          // Type check: must be 'purchase' OR if type is missing, assume it's a purchase
          final type = _st(d['type']);
          if (type.isNotEmpty && type != 'purchase') continue;
          
          // Status check: must be approved/completed
          if (!_okStat(d['status'])) continue;
          
          // Support multiple date fields: timestamp, createdAt, approvedAt, paidAt, purchaseDate
          if (!within(_firstDate(d, ['timestamp', 'createdAt', 'approvedAt', 'paidAt', 'purchaseDate']))) continue;
          
          final amt = _i(d['amount'] ?? d['totalAmount']);
          if (_walletFunded(d)) {
            shWallet += amt;
          } else {
            shN++;
            shAmt += amt;
          }
        }

        // Fixed deposits placed (approved/active/matured only)
        // FIX: Add 'depositDate' to date keys
        int fdN = 0, fdAmt = 0;
        for (final d in fds) {
          final st = _st(d['status']);
          if (st != 'active' && st != 'matured') continue;
          if (_walletFunded(d)) continue;
          if (!within(_firstDate(d, ['approvedAt', 'createdAt', 'depositDate']))) continue;
          fdN++;
          fdAmt += _i(d['principal'] ?? d['amount']);
        }

        // Wallet top-ups (real cash in) and payouts to mobile money (real cash out)
        // Exclude transactions flagged as excludeFromReports (test transactions)
        int topN = 0, topAmt = 0, payN = 0, payAmt = 0;
        for (final d in walletTxns) {
          if (d['excludeFromReports'] == true) continue; // Skip test transactions
          if (_st(d['status']) != 'completed') continue;
          if (!within(_firstDate(d, ['completedAt', 'createdAt', 'timestamp']))) continue;
          final type = _st(d['type']);
          if (type == 'deposit') {
            topN++;
            topAmt += _i(d['amount']);
          } else if (type == 'withdrawal') {
            payN++;
            payAmt += _i(d['amount']);
          }
        }

        // FIX Bug #5: Include income / expenses from Finance + teller + loan interest
        double interestInc = 0, feeInc = 0, penaltyInc = 0, otherInc = 0, tellerInterest = 0;
        double salaries = 0, utilities = 0, officeExp = 0, otherExp = 0;
        final incomeTx = <Map<String, dynamic>>[];
        final expenseTx = <Map<String, dynamic>>[];

        void addIncome(DateTime? date, String desc, String source, String category, num amt,
            String receipt, String teller, {bool fromTeller = false}) {
          final a = amt.toDouble();
          switch (category) {
            case 'Interest':
              if (fromTeller) tellerInterest += a;
              break;
            case 'Fees':
              feeInc += a;
              break;
            case 'Penalties':
              penaltyInc += a;
              break;
            default:
              otherInc += a;
          }
          incomeTx.add({
            'date': date,
            'description': desc,
            'source': source,
            'category': category,
            'amount': a,
            'receiptNumber': receipt,
            'tellerName': teller,
          });
        }

        void addExpense(DateTime? date, String desc, String origCat, num amt, String receipt, String teller) {
          final a = amt.toDouble();
          final cat = expenseCat(origCat);
          switch (cat) {
            case 'Salaries':
              salaries += a;
              break;
            case 'Utilities':
              utilities += a;
              break;
            case 'Office Expenses':
              officeExp += a;
              break;
            default:
              otherExp += a;
          }
          expenseTx.add({
            'date': date,
            'description': desc,
            'category': cat,
            'originalCategory': origCat,
            'amount': a,
            'receiptNumber': receipt,
            'tellerName': teller,
          });
        }

        for (final d in incomeDocs) {
          final date = _dt(d['date']);
          if (!within(date)) continue;
          final cat = (d['category'] ?? '').toString();
          addIncome(date, (d['description'] ?? '').toString(), (d['party'] ?? d['source'] ?? '').toString(),
              incomeCat(cat), _i(d['amount']), (d['reference'] ?? '').toString(), '');
        }

        for (final d in expenseDocs) {
          final date = _dt(d['date']);
          if (!within(date)) continue;
          addExpense(date, (d['description'] ?? '').toString(), (d['category'] ?? '').toString(),
              _i(d['amount']), (d['reference'] ?? '').toString(), '');
        }

        for (final d in teller) {
          final date = _firstDate(d, ['timestamp', 'createdAt']);
          if (!within(date)) continue;
          final type = _st(d['type']);
          final amt = _i(d['amount']).abs();
          if (type == 'revenue') {
            final src = _st(d['source']);
            addIncome(date, _st(d['description']), src, incomeCat(src), amt, _st(d['receiptNumber']),
                _st(d['tellerName']),
                fromTeller: true);
          } else if (type == 'expense') {
            addExpense(date, _st(d['description']), _st(d['category']), amt, _st(d['receiptNumber']),
                _st(d['tellerName']));
          }
        }

        // Add interest transactions from repayments (for display only, don't accumulate)
        for (final d in repayments) {
          if (_isReversed(d)) continue;
          final date = _firstDate(d, ['paymentDate', 'paidAt', 'date', 'timestamp', 'createdAt']);
          if (!within(date)) continue;
          
          final interest = _i(d['interestAmount'] ?? d['interestPayment']);
          if (interest > 0) {
            final memberName = _st(d['memberName']);
            // Add to transaction list only, category 'Interest' adds to tellerInterest which we'll override
            incomeTx.add({
              'date': date,
              'description': 'Interest on loan repayment${memberName.isNotEmpty ? " - $memberName" : ""}',
              'source': 'Interest on loans',
              'category': 'Interest',
              'amount': interest.toDouble(),
              'receiptNumber': _st(d['receiptNumber']),
              'tellerName': _st(d['recordedBy']),
            });
          }
        }

        // Loan interest: use ONLY repayments total (ignore tellerInterest since we added transactions manually)
        interestInc = repInterest.toDouble();

        final nonLoanIncome = feeInc + penaltyInc + otherInc;
        final incomeTotal = interestInc + repCharges + nonLoanIncome;
        final expenseTotal = salaries + utilities + officeExp + otherExp;

        final totalInflows = repAmt + savAmt + shAmt + fdAmt + topAmt + nonLoanIncome;
        final totalOutflows = loanAmt + wdNet + payAmt + expenseTotal;

        return {
          'loans': {'count': loanN, 'amount': loanAmt},
          'repayments': {
            'count': repN,
            'amount': repAmt,
            'principal': repPrincipal,
            'interest': repInterest,
            'charges': repCharges,
          },
          'savings': {'count': savN, 'amount': savAmt, 'fromWallet': savWallet},
          'savingsWithdrawals': {'count': wdN, 'amount': wdNet, 'charges': wdCharges},
          'shares': {'count': shN, 'amount': shAmt, 'fromWallet': shWallet},
          'fixedDeposits': {'count': fdN, 'amount': fdAmt},
          'walletTopups': {'count': topN, 'amount': topAmt},
          'walletPayouts': {'count': payN, 'amount': payAmt},
          'incomeData': {
            'interest': interestInc,
            'loanCharges': repCharges,
            'fees': feeInc,
            'penalties': penaltyInc,
            'other': otherInc,
            'total': incomeTotal,
            'transactions': incomeTx,
          },
          'expenseData': {
            'salaries': salaries,
            'utilities': utilities,
            'officeExpenses': officeExp,
            'other': otherExp,
            'total': expenseTotal,
            'transactions': expenseTx,
          },
          'totalInflows': totalInflows,
          'totalOutflows': totalOutflows,
          'netCashFlow': totalInflows - totalOutflows,
        };
      }

      final cur = flows(start, end);
      final prev = flows(prevStart, prevEnd);
      final cash = await _cashPosition(start, end);

      // Get or calculate opening balance
      final monthKey = '${start.year}-${start.month.toString().padLeft(2, '0')}';
      int openingCash = _i(cash['opening']);
      bool hasManualOpening = cash['hasManualOpening'] == true; // Use value from _cashPosition
      
      print('📋 Monthly report: monthKey=$monthKey, hasManualOpening=$hasManualOpening, opening=$openingCash');
      
      // Calculate ONE closing cash value (includes tills)
      final closingCash = _i(cash['closing']);
      final tillsNow = _i(cash['tillsNow']);
      final totalClosingCash = closingCash + tillsNow;
      final nonTillAccounts = _i(cash['nonTillAccounts']);
      final hasNoCashAccounts = nonTillAccounts == 0 && tillsNow == 0;

      // Portfolio snapshot with arrears ageing & enhanced metrics
      final now = DateTime.now();
      int outstanding = 0, overdueAmt = 0, overdueN = 0, liveN = 0;
      int outstandingNonMigrated = 0, overdueNonMigrated = 0;
      int arrears1_30 = 0, arrears31_60 = 0, arrears61_90 = 0, arrears90Plus = 0;
      final overdueLoans = <Map<String, dynamic>>[];
      
      int pendingLoans = 0, approvedLoans = 0, rejectedLoans = 0;
      
      for (final l in loans) {
        final status = _st(l['status']);
        final createdDate = _firstDate(l, ['createdAt', 'timestamp']);
        final withinPeriod = createdDate != null && !createdDate.isBefore(start) && !createdDate.isAfter(end);
        
        if (status == 'pending' && withinPeriod) pendingLoans++;
        if (status == 'rejected' && withinPeriod) rejectedLoans++;
        if (_everDisbursed.contains(status) && withinPeriod) approvedLoans++;
        
        if (!_live.contains(status)) continue;
        final out = _principalOut(l);
        if (out <= 0) continue;
        
        liveN++;
        outstanding += out;
        final isMigrated = l['migratedFrom'] != null || l['legacyPrincipalPaid'] != null;
        
        final due = _dt(l['dueDate']);
        if (due != null && due.isBefore(now)) {
          final daysOverdue = now.difference(due).inDays;
          overdueN++;
          overdueAmt += out;
          
          if (!isMigrated) {
            outstandingNonMigrated += out;
            overdueNonMigrated += out;
          }
          
          // Arrears ageing buckets
          if (daysOverdue <= 30) {
            arrears1_30 += out;
          } else if (daysOverdue <= 60) {
            arrears31_60 += out;
          } else if (daysOverdue <= 90) {
            arrears61_90 += out;
          } else {
            arrears90Plus += out;
          }
          
          // Track for top 10
          overdueLoans.add({
            'loanId': l['id'],
            'memberName': l['memberName'] ?? l['farmerName'] ?? 'Unknown',
            'memberId': l['memberId'] ?? l['farmerId'],
            'amount': _loanAmount(l),
            'outstanding': out,
            'daysOverdue': daysOverdue,
            'dueDate': due,
            'isMigrated': isMigrated,
          });
        } else if (!isMigrated) {
          outstandingNonMigrated += out;
        }
      }
      
      // Sort overdue loans by days overdue (desc) and take top 10
      overdueLoans.sort((a, b) => (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int));
      final top10Overdue = overdueLoans.take(10).toList();

      // Member counting - only count where role == AppConstants.roleMember
      // FIX: Support multiple date field variations (createdAt, joinDate, registeredAt, activatedAt)
      int totalMembers = 0, newMembers = 0;
      int totalSavings = 0, totalShares = 0;
      for (final m in members) {
        final role = m['role'];
        if (role != AppConstants.roleMember) continue;
        
        totalMembers++;
        totalSavings += _i(m['savingsBalance']);
        totalShares += _i(m['sharesBalance'] ?? m['sharesValue']);
        
        // Try multiple date fields: createdAt (new members), joinDate/registeredAt (imports), activatedAt (activated members)
        final c = _dt(m['createdAt']) ?? 
                  _dt(m['joinDate']) ?? 
                  _dt(m['registeredAt']) ?? 
                  _dt(m['dateJoined']) ?? 
                  _dt(m['activatedAt']);
        if (c != null && !c.isBefore(start) && !c.isAfter(end)) newMembers++;
      }
      
      // Fixed deposits total and maturing next month
      int fdTotal = 0, fdMaturingNext = 0;
      final nextMonthStart = DateTime(end.year, end.month + 1, 1);
      final nextMonthEnd = DateTime(end.year, end.month + 2, 0);
      
      for (final fd in fds) {
        final status = _st(fd['status']);
        if (status == 'active' || status == 'matured') {
          fdTotal += _i(fd['principal'] ?? fd['amount']);
          
          final maturityDate = _dt(fd['maturityDate']);
          if (maturityDate != null && 
              !maturityDate.isBefore(nextMonthStart) && 
              !maturityDate.isAfter(nextMonthEnd)) {
            fdMaturingNext += _i(fd['principal'] ?? fd['amount']);
          }
        }
      }
      
      // Till totals for reconciliation
      int tellerDepTotal = 0, tellerWdTotal = 0;
      for (final t in teller) {
        final txDate = _firstDate(t, ['timestamp', 'createdAt']);
        if (txDate == null) continue;
        if (txDate.isBefore(start) || txDate.isAfter(end)) continue;
        
        final type = _st(t['type']);
        if (type == 'deposit' || type == 'savings_deposit') {
          tellerDepTotal += _i(t['amount']);
        } else if (type == 'withdrawal' || type == 'savings_withdrawal') {
          tellerWdTotal += _i(t['amount']);
        }
      }

      final net = cur['netCashFlow'] as num;
      final incomeData = cur['incomeData'] as Map<String, dynamic>;
      final expenseData = cur['expenseData'] as Map<String, dynamic>;
      
      // Calculate unexplained difference (only if opening is set)
      final unexplained = hasManualOpening ? totalClosingCash - openingCash - net.round() : 0;
      
      // Auto-save month-end snapshot for completed months (15+ days ago)
      final isCompletedMonth = end.isBefore(now.subtract(const Duration(days: 15)));
      if (isCompletedMonth) {
        _db
            .collection('account_snapshots')
            .doc('$_tenantId-$monthKey')
            .set({
          'tenantId': _tenantId,
          'month': monthKey,
          'opening': openingCash,
          'closing': closingCash,
          'tills': tillsNow,
          'totalClosing': totalClosingCash, // This becomes next month's opening
          'nonTillAccounts': nonTillAccounts,
          'hasManualOpening': hasManualOpening,
          'autoSaved': true,
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
            .catchError((_) {});
      }

      final result = <String, dynamic>{
        'period': period,
        'startDate': start,
        'endDate': end,
        // Old keys (same shape as before, so the current screen keeps working)
        'loans': cur['loans'],
        'repayments': cur['repayments'],
        'savings': cur['savings'],
        'shares': cur['shares'],
        'netCashFlow': net,
        // New keys
        'savingsWithdrawals': cur['savingsWithdrawals'],
        'fixedDeposits': cur['fixedDeposits'],
        'walletTopups': cur['walletTopups'],
        'walletPayouts': cur['walletPayouts'],
        'totalInflows': cur['totalInflows'],
        'totalOutflows': cur['totalOutflows'],
        'cash': {
          'opening': openingCash,
          'closing': closingCash,
          'tillsNow': tillsNow,
          'totalClosing': totalClosingCash, // ONE value for both closing display and calculations
          'nonTillAccounts': nonTillAccounts,
          'hasNoCashAccounts': hasNoCashAccounts,
          'hasManualOpening': hasManualOpening,
          'unexplained': unexplained,
          'fromSnapshot': cash['fromSnapshot'] ?? false,
        },
        'previous': {
          'loans': (prev['loans'] as Map)['amount'],
          'repayments': (prev['repayments'] as Map)['amount'],
          'savings': (prev['savings'] as Map)['amount'],
          'shares': (prev['shares'] as Map)['amount'],
          'totalInflows': prev['totalInflows'],
          'totalOutflows': prev['totalOutflows'],
          'netCashFlow': prev['netCashFlow'],
          'income': (prev['incomeData'] as Map)['total'],
          'expenses': (prev['expenseData'] as Map)['total'],
        },
        'portfolio': {
          'asOf': now,
          'liveLoans': liveN,
          'outstanding': outstanding,
          'overdueLoans': overdueN,
          'overdueAmount': overdueAmt,
          'parPercent': outstanding > 0 ? overdueAmt / outstanding * 100 : 0.0,
          // Non-migrated PAR (more accurate)
          'outstandingNonMigrated': outstandingNonMigrated,
          'overdueNonMigrated': overdueNonMigrated,
          'parPercentNonMigrated': outstandingNonMigrated > 0 
              ? overdueNonMigrated / outstandingNonMigrated * 100 
              : 0.0,
          // Arrears ageing
          'arrears1to30': arrears1_30,
          'arrears31to60': arrears31_60,
          'arrears61to90': arrears61_90,
          'arrears90plus': arrears90Plus,
          // Top overdue
          'top10Overdue': top10Overdue,
          // Loan applications this month
          'pendingLoans': pendingLoans,
          'approvedLoans': approvedLoans,
          'rejectedLoans': rejectedLoans,
          // Balances
          'totalSavings': totalSavings,
          'totalShares': totalShares,
          'totalFixedDeposits': fdTotal,
          'fdMaturingNextMonth': fdMaturingNext,
        },
        'members': {
          'total': totalMembers,
          'newThisMonth': newMembers,
        },
        'reconciliation': {
          'savingsDepositsVsTeller': {
            'reportTotal': _i((cur['savings'] as Map)['amount']),
            'tellerTotal': tellerDepTotal,
            'difference': _i((cur['savings'] as Map)['amount']) - tellerDepTotal,
          },
          'savingsWithdrawalsVsTeller': {
            'reportTotal': _i((cur['savingsWithdrawals'] as Map)['amount']),
            'tellerTotal': tellerWdTotal,
            'difference': _i((cur['savingsWithdrawals'] as Map)['amount']) - tellerWdTotal,
          },
        },
        'generatedAt': DateTime.now(),
      };

      // Same behaviour as before: only present when there is something to show.
      if ((incomeData['total'] as num) > 0) result['income'] = incomeData;
      if ((expenseData['total'] as num) > 0) result['expenses'] = expenseData;

      return result;
    } catch (e) {
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';
import '../core/constants.dart';

/// Comprehensive reporting service for all financial and operational reports
class ReportService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;

  // ─── Monthly Report ───────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateMonthlyReport({
    required int year,
    required int month,
  }) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      // Fetch ALL tenant data and filter in memory to avoid composite index requirements
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      final repaymentsSnapshot = await _db
          .collection(AppConstants.repaymentsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      final savingsSnapshot = await _db
          .collection(AppConstants.savingsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      final sharesSnapshot = await _db
          .collection(AppConstants.sharesCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      // Calculate totals with in-memory date filtering
      int totalLoansDisbursed = 0;
      int totalLoansAmount = 0;
      int totalRepayments = 0;
      int totalRepaymentsAmount = 0;
      int totalSavingsDeposits = 0;
      int totalSavingsAmount = 0;
      int totalSharesPurchased = 0;
      int totalSharesAmount = 0;

      // Filter loans by date
      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null || createdAt.isBefore(startDate) || createdAt.isAfter(endDate)) {
          continue;
        }

        final status = data['status'] as String? ?? '';
        if (status == 'approved' || status == 'paid') {
          totalLoansDisbursed++;
          totalLoansAmount += (data['amount'] as num?)?.toInt() ?? 0;
        }
      }

      // Filter repayments by date
      for (var doc in repaymentsSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null || date.isBefore(startDate) || date.isAfter(endDate)) {
          continue;
        }

        totalRepayments++;
        totalRepaymentsAmount += (data['amount'] as num?)?.toInt() ?? 0;
      }

      // Filter savings by date
      for (var doc in savingsSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null || timestamp.isBefore(startDate) || timestamp.isAfter(endDate)) {
          continue;
        }

        if (data['type'] == 'deposit' && data['status'] == 'approved') {
          totalSavingsDeposits++;
          totalSavingsAmount += (data['amount'] as num?)?.toInt() ?? 0;
        }
      }

      // Filter shares by date
      for (var doc in sharesSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null || timestamp.isBefore(startDate) || timestamp.isAfter(endDate)) {
          continue;
        }

        if (data['type'] == 'purchase' && data['status'] == 'approved') {
          totalSharesPurchased++;
          totalSharesAmount += (data['amount'] as num?)?.toInt() ?? 0;
        }
      }

      return {
        'period': '${DateFormat.MMMM().format(startDate)} $year',
        'startDate': startDate,
        'endDate': endDate,
        'loans': {
          'count': totalLoansDisbursed,
          'amount': totalLoansAmount,
        },
        'repayments': {
          'count': totalRepayments,
          'amount': totalRepaymentsAmount,
        },
        'savings': {
          'count': totalSavingsDeposits,
          'amount': totalSavingsAmount,
        },
        'shares': {
          'count': totalSharesPurchased,
          'amount': totalSharesAmount,
        },
        'netCashFlow': totalRepaymentsAmount + totalSavingsAmount + totalSharesAmount - totalLoansAmount,
        'generatedAt': DateTime.now(),
      };
    } catch (e) {
      // Return error info for debugging
      return {
        'error': e.toString(),
        'period': '${DateFormat.MMMM().format(DateTime(year, month))} $year',
        'startDate': DateTime(year, month, 1),
        'endDate': DateTime(year, month + 1, 0, 23, 59, 59),
        'loans': {'count': 0, 'amount': 0},
        'repayments': {'count': 0, 'amount': 0},
        'savings': {'count': 0, 'amount': 0},
        'shares': {'count': 0, 'amount': 0},
        'netCashFlow': 0,
        'generatedAt': DateTime.now(),
      };
    }
  }

  // ─── Trial Balance ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateTrialBalance({
    DateTime? asOfDate,
  }) async {
    final cutoffDate = asOfDate ?? DateTime.now();

    // Get all member balances
    final membersSnapshot = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    int totalSavingsBalance = 0;
    int totalSharesBalance = 0;
    int totalLoansPrincipal = 0;
    int totalLoansInterest = 0;
    int totalFixedDeposits = 0;

    for (var doc in membersSnapshot.docs) {
      final data = doc.data();
      totalSavingsBalance += (data['savingsBalance'] as num?)?.toInt() ?? 0;
      totalSharesBalance += (data['sharesValue'] as num?)?.toInt() ?? 0;
    }

    // Get all active loans
    final loansSnapshot = await _db
        .collection(AppConstants.loansCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('status', whereIn: ['approved', 'paid'])
        .get();

    for (var doc in loansSnapshot.docs) {
      final principal = (doc['amount'] as num?)?.toInt() ?? 0;
      final repaid = (doc.data() as Map).containsKey('totalRepaid') 
          ? (doc['totalRepaid'] as num?)?.toInt() ?? 0
          : (doc.data() as Map).containsKey('amountPaid')
              ? (doc['amountPaid'] as num?)?.toInt() ?? 0
              : 0;
      final outstanding = principal - repaid;
      
      if (outstanding > 0) {
        totalLoansPrincipal += outstanding;
        // Calculate interest on outstanding (simplified)
        // Safe field access - handle missing or null interestRate
        try {
          final data = doc.data() as Map<String, dynamic>;
          final interestRate = (data['interestRate'] as num?)?.toDouble() ?? 
                               (data['interest'] as num?)?.toDouble() ?? 
                               15.0; // Default interest rate
          totalLoansInterest += (outstanding * interestRate / 100).toInt();
        } catch (e) {
          // If field doesn't exist, use default 15% interest
          totalLoansInterest += (outstanding * 15.0 / 100).toInt();
        }
      }
    }

    // Get fixed deposits
    final fdsSnapshot = await _db
        .collection('fixedDeposits')
        .where('tenantId', isEqualTo: _tenantId)
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in fdsSnapshot.docs) {
      totalFixedDeposits += (doc['amount'] as num?)?.toInt() ?? 0;
    }

    // Calculate totals
    final totalAssets = totalLoansPrincipal + totalLoansInterest;
    final totalLiabilities = totalSavingsBalance + totalSharesBalance + totalFixedDeposits;
    final netPosition = totalAssets - totalLiabilities;

    return {
      'asOfDate': cutoffDate,
      'assets': {
        'loansReceivable': {
          'principal': totalLoansPrincipal,
          'interest': totalLoansInterest,
          'total': totalLoansPrincipal + totalLoansInterest,
        },
        'total': totalAssets,
      },
      'liabilities': {
        'memberSavings': totalSavingsBalance,
        'memberShares': totalSharesBalance,
        'fixedDeposits': totalFixedDeposits,
        'total': totalLiabilities,
      },
      'equity': {
        'retainedEarnings': netPosition,
        'total': netPosition,
      },
      'balanced': totalAssets == (totalLiabilities + netPosition),
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Balance Sheet ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateBalanceSheet({
    DateTime? asOfDate,
  }) async {
    final cutoffDate = asOfDate ?? DateTime.now();
    
    // Get trial balance first
    final trialBalance = await generateTrialBalance(asOfDate: cutoffDate);

    // Get additional cash and bank balances
    final walletTransactions = await _db
        .collection('wallet_transactions')
        .where('tenantId', isEqualTo: _tenantId)
        .where('timestamp', isLessThanOrEqualTo: cutoffDate)
        .get();

    int cashInHand = 0;
    for (var doc in walletTransactions.docs) {
      final type = doc['type'] as String? ?? '';
      final amount = (doc['amount'] as num?)?.toInt() ?? 0;
      
      if (type == 'deposit' || type == 'loan_repayment') {
        cashInHand += amount;
      } else if (type == 'withdrawal' || type == 'loan_disbursement') {
        cashInHand -= amount;
      }
    }

    // Recalculate totals including cash
    final totalAssets = cashInHand + trialBalance['assets']['total'];
    final totalLiabilities = trialBalance['liabilities']['total'];
    // Equity must equal Assets - Liabilities to balance
    final totalEquity = totalAssets - totalLiabilities;

    return {
      'asOfDate': cutoffDate,
      'assets': {
        'currentAssets': {
          'cashInHand': cashInHand,
          'loansReceivable': trialBalance['assets']['loansReceivable']['total'],
          'total': cashInHand + trialBalance['assets']['loansReceivable']['total'],
        },
        'total': totalAssets,
      },
      'liabilities': {
        'currentLiabilities': {
          'memberSavings': trialBalance['liabilities']['memberSavings'],
          'memberShares': trialBalance['liabilities']['memberShares'],
          'fixedDeposits': trialBalance['liabilities']['fixedDeposits'],
          'total': totalLiabilities,
        },
        'total': totalLiabilities,
      },
      'equity': {
        'retainedEarnings': totalEquity,
        'total': totalEquity,
      },
      'totalLiabilitiesAndEquity': totalLiabilities + totalEquity,
      'generatedAt': DateTime.now(),
    };
  }

  // ─── KYC Report ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateKYCReport() async {
    final membersSnapshot = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    int totalMembers = 0;
    int verified = 0;
    int pending = 0;
    int rejected = 0;
    int notSubmitted = 0;

    List<Map<String, dynamic>> pendingList = [];
    List<Map<String, dynamic>> rejectedList = [];

    for (var doc in membersSnapshot.docs) {
      totalMembers++;
      final data = doc.data();
      final idStatus = data['idStatus'] as String? ?? 'not_submitted'; // Default if missing
      
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
        'total': totalMembers,
        'verified': verified,
        'pending': pending,
        'rejected': rejected,
        'notSubmitted': notSubmitted,
        'verificationRate': totalMembers > 0 ? (verified / totalMembers * 100) : 0.0,
      },
      'pendingVerifications': pendingList,
      'rejectedVerifications': rejectedList,
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Loan Report ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateLoanReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final start = startDate ?? DateTime(DateTime.now().year, 1, 1);
    final end = endDate ?? DateTime.now();

    final loansSnapshot = await _db
        .collection(AppConstants.loansCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThanOrEqualTo: end)
        .get();

    int totalLoans = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int paid = 0;
    int overdue = 0;

    int totalAmountRequested = 0;
    int totalAmountDisbursed = 0;
    int totalRepaid = 0;
    int totalOutstanding = 0;

    List<Map<String, dynamic>> overdueLoans = [];
    List<Map<String, dynamic>> activeLoans = [];

    for (var doc in loansSnapshot.docs) {
      totalLoans++;
      final data = doc.data();
      final status = data['status'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final repaid = data.containsKey('totalRepaid') 
          ? (data['totalRepaid'] as num?)?.toInt() ?? 0
          : data.containsKey('amountPaid')
              ? (data['amountPaid'] as num?)?.toInt() ?? 0
              : 0;
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();

      totalAmountRequested += amount;

      switch (status) {
        case 'pending':
          pending++;
          break;
        case 'approved':
          approved++;
          totalAmountDisbursed += amount;
          totalRepaid += repaid;
          totalOutstanding += (amount - repaid);
          
          // Check if overdue
          if (dueDate != null && dueDate.isBefore(DateTime.now()) && repaid < amount) {
            overdue++;
            overdueLoans.add({
              'id': doc.id,
              'farmerId': data['farmerId'],
              'farmerName': data['farmerName'] ?? 'Unknown',
              'amount': amount,
              'repaid': repaid,
              'outstanding': amount - repaid,
              'dueDate': dueDate,
              'daysOverdue': DateTime.now().difference(dueDate).inDays,
            });
          } else if (repaid < amount) {
            activeLoans.add({
              'id': doc.id,
              'farmerId': data['farmerId'],
              'farmerName': data['farmerName'] ?? 'Unknown',
              'amount': amount,
              'repaid': repaid,
              'outstanding': amount - repaid,
              'dueDate': dueDate,
            });
          }
          break;
        case 'rejected':
          rejected++;
          break;
        case 'paid':
          paid++;
          totalAmountDisbursed += amount;
          totalRepaid += amount;
          break;
      }
    }

    return {
      'period': {
        'start': start,
        'end': end,
      },
      'summary': {
        'totalLoans': totalLoans,
        'pending': pending,
        'approved': approved,
        'rejected': rejected,
        'paid': paid,
        'overdue': overdue,
        'approvalRate': totalLoans > 0 ? (approved / totalLoans * 100) : 0,
        'repaymentRate': totalAmountDisbursed > 0 ? (totalRepaid / totalAmountDisbursed * 100) : 0,
      },
      'financials': {
        'totalAmountRequested': totalAmountRequested,
        'totalAmountDisbursed': totalAmountDisbursed,
        'totalRepaid': totalRepaid,
        'totalOutstanding': totalOutstanding,
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

    final transactionsSnapshot = await _db
        .collection('wallet_transactions')
        .where('tenantId', isEqualTo: _tenantId)
        .where('timestamp', isGreaterThanOrEqualTo: start)
        .where('timestamp', isLessThanOrEqualTo: end)
        .orderBy('timestamp', descending: true)
        .get();

    int totalTransactions = 0;
    int deposits = 0;
    int withdrawals = 0;
    int transfers = 0;
    int airtimePurchases = 0;
    int billPayments = 0;

    int totalDepositsAmount = 0;
    int totalWithdrawalsAmount = 0;
    int totalTransfersAmount = 0;
    int totalAirtimeAmount = 0;
    int totalBillsAmount = 0;

    List<Map<String, dynamic>> recentTransactions = [];

    for (var doc in transactionsSnapshot.docs) {
      totalTransactions++;
      final data = doc.data();
      final type = data['type'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toInt() ?? 0;

      if (recentTransactions.length < 50) {
        recentTransactions.add({
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
        });
      }

      switch (type) {
        case 'deposit':
          deposits++;
          totalDepositsAmount += amount;
          break;
        case 'withdrawal':
          withdrawals++;
          totalWithdrawalsAmount += amount;
          break;
        case 'transfer':
          transfers++;
          totalTransfersAmount += amount;
          break;
        case 'airtime':
        case 'data':
          airtimePurchases++;
          totalAirtimeAmount += amount;
          break;
        case 'bill_payment':
          billPayments++;
          totalBillsAmount += amount;
          break;
      }
    }

    return {
      'period': {
        'start': start,
        'end': end,
      },
      'summary': {
        'totalTransactions': totalTransactions,
        'deposits': deposits,
        'withdrawals': withdrawals,
        'transfers': transfers,
        'airtimePurchases': airtimePurchases,
        'billPayments': billPayments,
      },
      'financials': {
        'totalDeposits': totalDepositsAmount,
        'totalWithdrawals': totalWithdrawalsAmount,
        'totalTransfers': totalTransfersAmount,
        'totalAirtime': totalAirtimeAmount,
        'totalBills': totalBillsAmount,
        'netFlow': totalDepositsAmount - (totalWithdrawalsAmount + totalTransfersAmount + totalAirtimeAmount + totalBillsAmount),
      },
      'recentTransactions': recentTransactions,
      'generatedAt': DateTime.now(),
    };
  }

  // ─── Member Report ────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> generateMemberReport() async {
    // Simplified query - removed orderBy to avoid composite index requirement
    final membersSnapshot = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: _tenantId)
        .get();

    List<Map<String, dynamic>> members = [];

    for (var doc in membersSnapshot.docs) {
      final data = doc.data();
      
      // Get member's loan count
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('farmerId', isEqualTo: doc.id)
          .get();

      int activeLoans = 0;
      int totalLoans = loansSnapshot.docs.length;
      int totalBorrowed = 0;
      int totalRepaid = 0;

      for (var loan in loansSnapshot.docs) {
        final data = loan.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final repaid = data.containsKey('totalRepaid') 
            ? (data['totalRepaid'] as num?)?.toInt() ?? 0
            : data.containsKey('amountPaid')
                ? (data['amountPaid'] as num?)?.toInt() ?? 0
                : 0;

        if (status == 'approved' && repaid < amount) {
          activeLoans++;
        }
        if (status == 'approved' || status == 'paid') {
          totalBorrowed += amount;
          totalRepaid += repaid;
        }
      }

      // Safe date parsing
      DateTime? membershipDate;
      final createdAtValue = data['createdAt'];
      if (createdAtValue is Timestamp) {
        membershipDate = createdAtValue.toDate();
      } else if (createdAtValue is String) {
        try {
          membershipDate = DateTime.parse(createdAtValue);
        } catch (_) {
          membershipDate = DateTime.now();
        }
      } else {
        membershipDate = DateTime.now();
      }

      members.add({
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'phone': data['phone'] ?? '',
        'email': data['email'] ?? '',
        'idStatus': data['idStatus'] ?? 'not_submitted',
        'membershipDate': membershipDate,
        'savingsBalance': (data['savingsBalance'] as num?)?.toInt() ?? 0,
        'sharesValue': (data['sharesValue'] as num?)?.toInt() ?? 0,
        'walletBalance': (data['walletBalance'] as num?)?.toInt() ?? 0,
        'totalLoans': totalLoans,
        'activeLoans': activeLoans,
        'totalBorrowed': totalBorrowed,
        'totalRepaid': totalRepaid,
        'outstandingBalance': totalBorrowed - totalRepaid,
      });
    }

    return members;
  }

  // ─── Export to CSV Helper ─────────────────────────────────────────────────
  static String exportMembersToCSV(List<Map<String, dynamic>> members) {
    final buffer = StringBuffer();
    
    // Headers
    buffer.writeln('Member ID,Name,Phone,Email,KYC Status,Membership Date,Savings Balance,Shares Value,Wallet Balance,Total Loans,Active Loans,Total Borrowed,Total Repaid,Outstanding Balance');
    
    // Data rows
    for (var member in members) {
      buffer.writeln([
        member['id'],
        member['name'],
        member['phone'],
        member['email'],
        member['idStatus'],
        DateFormat('yyyy-MM-dd').format(member['membershipDate'] ?? DateTime.now()),
        member['savingsBalance'],
        member['sharesValue'],
        member['walletBalance'],
        member['totalLoans'],
        member['activeLoans'],
        member['totalBorrowed'],
        member['totalRepaid'],
        member['outstandingBalance'],
      ].join(','));
    }
    
    return buffer.toString();
  }
}

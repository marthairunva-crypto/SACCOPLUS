import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';
import '../core/constants.dart';

/// Comprehensive loan portfolio management service
class LoanPortfolioService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;

  // ─── Get Member Loan Portfolio ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMemberLoanPortfolio(String memberId) async {
    try {
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('farmerId', isEqualTo: memberId)
          .get();

      final repaymentsSnapshot = await _db
          .collection(AppConstants.repaymentsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('farmerId', isEqualTo: memberId)
          .get();

      List<Map<String, dynamic>> activeLoans = [];
      List<Map<String, dynamic>> completedLoans = [];
      List<Map<String, dynamic>> pendingLoans = [];
      List<Map<String, dynamic>> rejectedLoans = [];

      int totalBorrowed = 0;
      int totalRepaid = 0;
      int totalOutstanding = 0;
      int overdueAmount = 0;
      int numberOfOverdueLoans = 0;

      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase(); // Case-insensitive
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final repaid = (data['totalRepaid'] as num?)?.toInt() ?? 0;
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final outstanding = amount - repaid;

        final loan = {
          'id': doc.id,
          ...data,
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          'dueDate': dueDate,
          'amount': amount,
          'totalRepaid': repaid,
          'outstanding': outstanding,
        };

        switch (status) {
          case 'approved':
            if (outstanding > 0) {
              activeLoans.add(loan);
              totalBorrowed += amount;
              totalRepaid += repaid;
              totalOutstanding += outstanding;

              // Check if overdue
              if (dueDate != null && dueDate.isBefore(DateTime.now())) {
                overdueAmount += outstanding;
                numberOfOverdueLoans++;
                loan['isOverdue'] = true;
                loan['daysOverdue'] = DateTime.now().difference(dueDate).inDays;
              }
            }
            break;
          case 'paid':
            completedLoans.add(loan);
            totalBorrowed += amount;
            totalRepaid += amount;
            break;
          case 'pending':
            pendingLoans.add(loan);
            break;
          case 'rejected':
            rejectedLoans.add(loan);
            break;
        }
      }

      // Build repayment history
      List<Map<String, dynamic>> repaymentHistory = [];
      for (var doc in repaymentsSnapshot.docs) {
        final data = doc.data();
        repaymentHistory.add({
          'id': doc.id,
          ...data,
          'date': (data['date'] as Timestamp?)?.toDate(),
          'amount': (data['amount'] as num?)?.toInt() ?? 0,
        });
      }

      return {
        'memberId': memberId,
        'summary': {
          'totalLoans': loansSnapshot.docs.length,
          'activeLoans': activeLoans.length,
          'completedLoans': completedLoans.length,
          'pendingLoans': pendingLoans.length,
          'rejectedLoans': rejectedLoans.length,
          'totalBorrowed': totalBorrowed,
          'totalRepaid': totalRepaid,
          'totalOutstanding': totalOutstanding,
          'overdueAmount': overdueAmount,
          'numberOfOverdueLoans': numberOfOverdueLoans,
          'repaymentRate': totalBorrowed > 0 ? (totalRepaid / totalBorrowed * 100) : 0,
        },
        'activeLoans': activeLoans,
        'completedLoans': completedLoans,
        'pendingLoans': pendingLoans,
        'rejectedLoans': rejectedLoans,
        'repaymentHistory': repaymentHistory,
        'generatedAt': DateTime.now(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'memberId': memberId,
      };
    }
  }

  // ─── Get All Overdue Loans ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getOverdueLoans() async {
    try {
      final now = DateTime.now();
      
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('status', isEqualTo: 'approved')
          .get();

      List<Map<String, dynamic>> overdueLoans = [];

      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final repaid = (data['totalRepaid'] as num?)?.toInt() ?? 0;
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final outstanding = amount - repaid;

        if (dueDate != null && dueDate.isBefore(now) && outstanding > 0) {
          final daysOverdue = now.difference(dueDate).inDays;
          
          overdueLoans.add({
            'id': doc.id,
            'farmerId': data['farmerId'],
            'farmerName': data['farmerName'] ?? 'Unknown',
            'farmerPhone': data['farmerPhone'] ?? '',
            'amount': amount,
            'totalRepaid': repaid,
            'outstanding': outstanding,
            'dueDate': dueDate,
            'daysOverdue': daysOverdue,
            'interestRate': (data['interestRate'] as num?)?.toDouble() ?? 0,
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
            'penalty': _calculatePenalty(outstanding, daysOverdue),
          });
        }
      }

      // Sort by days overdue (most overdue first)
      overdueLoans.sort((a, b) => (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int));

      return overdueLoans;
    } catch (e) {
      return [];
    }
  }

  // ─── Get Loan Details with Repayment Schedule ─────────────────────────────
  static Future<Map<String, dynamic>?> getLoanDetails(String loanId) async {
    try {
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) return null;

      final data = loanDoc.data()!;
      
      // Get repayment history for this loan
      final repaymentsSnapshot = await _db
          .collection(AppConstants.repaymentsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('loanId', isEqualTo: loanId)
          .get();

      final repayments = repaymentsSnapshot.docs.map((doc) {
        final repayData = doc.data();
        return {
          'id': doc.id,
          ...repayData,
          'date': (repayData['date'] as Timestamp?)?.toDate(),
          'amount': (repayData['amount'] as num?)?.toInt() ?? 0,
        };
      }).toList();

      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final repaid = (data['totalRepaid'] as num?)?.toInt() ?? 0;
      final outstanding = amount - repaid;
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      
      bool isOverdue = false;
      int daysOverdue = 0;
      int penalty = 0;

      if (dueDate != null && dueDate.isBefore(DateTime.now()) && outstanding > 0) {
        isOverdue = true;
        daysOverdue = DateTime.now().difference(dueDate).inDays;
        penalty = _calculatePenalty(outstanding, daysOverdue);
      }

      return {
        'id': loanId,
        ...data,
        'amount': amount,
        'totalRepaid': repaid,
        'outstanding': outstanding,
        'createdAt': createdAt,
        'dueDate': dueDate,
        'isOverdue': isOverdue,
        'daysOverdue': daysOverdue,
        'penalty': penalty,
        'repayments': repayments,
        'totalWithPenalty': outstanding + penalty,
      };
    } catch (e) {
      return null;
    }
  }

  // ─── Get Portfolio Summary ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getPortfolioSummary() async {
    try {
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      int totalLoans = 0;
      int activeLoans = 0;
      int overdueLoans = 0;
      int completedLoans = 0;
      int totalDisbursed = 0;
      int totalRepaid = 0;
      int totalOutstanding = 0;
      int totalOverdueAmount = 0;

      final now = DateTime.now();

      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] as String? ?? '').toLowerCase(); // Make case-insensitive
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final repaid = (data['totalRepaid'] as num?)?.toInt() ?? 0;
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        final outstanding = amount - repaid;

        totalLoans++;

        if (status == 'approved') {
          totalDisbursed += amount;
          totalRepaid += repaid;

          if (outstanding > 0) {
            activeLoans++;
            totalOutstanding += outstanding;

            if (dueDate != null && dueDate.isBefore(now)) {
              overdueLoans++;
              totalOverdueAmount += outstanding;
            }
          }
        } else if (status == 'paid') {
          completedLoans++;
          totalDisbursed += amount;
          totalRepaid += amount;
        }
      }

      final portfolioAtRisk = totalOutstanding > 0 ? (totalOverdueAmount / totalOutstanding * 100) : 0;
      final repaymentRate = totalDisbursed > 0 ? (totalRepaid / totalDisbursed * 100) : 0;

      return {
        'totalLoans': totalLoans,
        'activeLoans': activeLoans,
        'overdueLoans': overdueLoans,
        'completedLoans': completedLoans,
        'totalDisbursed': totalDisbursed,
        'totalRepaid': totalRepaid,
        'totalOutstanding': totalOutstanding,
        'totalOverdueAmount': totalOverdueAmount,
        'portfolioAtRisk': portfolioAtRisk,
        'repaymentRate': repaymentRate,
        'generatedAt': DateTime.now(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  // ─── Send Overdue Reminders ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendOverdueReminders() async {
    try {
      final overdueLoans = await getOverdueLoans();
      int remindersSent = 0;

      for (var loan in overdueLoans) {
        // Create notification for member
        await _db.collection('notifications').add({
          'tenantId': _tenantId,
          'userId': loan['farmerId'],
          'type': 'loan_overdue',
          'title': 'Loan Payment Overdue',
          'message': 'Your loan payment of UGX ${loan['outstanding']} is ${loan['daysOverdue']} days overdue. Please make a payment as soon as possible.',
          'read': false,
          'timestamp': DateTime.now(),
          'data': {
            'loanId': loan['id'],
            'amount': loan['outstanding'],
            'daysOverdue': loan['daysOverdue'],
            'penalty': loan['penalty'],
          },
        });

        remindersSent++;
      }

      return {
        'success': true,
        'remindersSent': remindersSent,
        'totalOverdue': overdueLoans.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ─── Calculate Penalty ────────────────────────────────────────────────────
  static int _calculatePenalty(int outstanding, int daysOverdue) {
    // 1% penalty per day, max 30%
    final penaltyRate = (daysOverdue * 0.01).clamp(0.0, 0.30);
    return (outstanding * penaltyRate).toInt();
  }

  // ─── Mark Loan as Paid ────────────────────────────────────────────────────
  static Future<bool> markLoanAsPaid(String loanId) async {
    try {
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'status': 'paid',
        'paidAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Get Loan Performance Metrics ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getLoanPerformanceMetrics() async {
    try {
      final summary = await getPortfolioSummary();
      final overdueLoans = await getOverdueLoans();

      // Group by overdue ranges
      int overdue1to30 = 0;
      int overdue31to60 = 0;
      int overdue61to90 = 0;
      int overdue91plus = 0;

      for (var loan in overdueLoans) {
        final days = loan['daysOverdue'] as int;
        if (days <= 30) {
          overdue1to30++;
        } else if (days <= 60) {
          overdue31to60++;
        } else if (days <= 90) {
          overdue61to90++;
        } else {
          overdue91plus++;
        }
      }

      return {
        ...summary,
        'overdueBreakdown': {
          '1-30 days': overdue1to30,
          '31-60 days': overdue31to60,
          '61-90 days': overdue61to90,
          '91+ days': overdue91plus,
        },
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ArrearsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate arrears for a loan based on payment schedule vs actual payments
  static Future<Map<String, dynamic>> calculateLoanArrears(String loanId) async {
    try {
      // Get loan details
      final loanDoc = await _db.collection('saccoplus-loans').doc(loanId).get();
      if (!loanDoc.exists) {
        return {'error': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final principal = (loanData['loanAmount'] ?? 0).toDouble();
      final interestRate = (loanData['interestRate'] ?? 0).toDouble();
      final duration = (loanData['duration'] ?? 12) as int;
      final interestMethod = loanData['interestMethod'] ?? 'flat';
      final penaltyRate = (loanData['penaltyRate'] ?? 5).toDouble();
      final paymentFrequency = loanData['paymentFrequency'] ?? 'monthly'; // monthly, weekly, daily
      
      // Get disbursement date
      DateTime? disbursementDate;
      if (loanData['disbursementDate'] is Timestamp) {
        disbursementDate = (loanData['disbursementDate'] as Timestamp).toDate();
      } else if (loanData['disbursedAt'] is Timestamp) {
        disbursementDate = (loanData['disbursedAt'] as Timestamp).toDate();
      }

      if (disbursementDate == null) {
        return {'error': 'Disbursement date not set'};
      }

      // Calculate total loan amount with interest
      double totalInterest;
      if (interestMethod == 'reducing') {
        final r = interestRate / (100 * 12);
        final n = duration.toDouble();
        if (r > 0) {
          final powValue = _pow(1.0 + r, n);
          final monthlyPayment = principal * r * powValue / (powValue - 1);
          totalInterest = (monthlyPayment * n) - principal;
        } else {
          totalInterest = 0;
        }
      } else {
        totalInterest = (principal * interestRate * duration) / (100 * 12);
      }

      final totalLoanAmount = principal + totalInterest;
      
      // Calculate expected payment based on frequency
      double expectedPayment;
      int periodsElapsed;
      
      final now = DateTime.now();
      
      switch (paymentFrequency) {
        case 'daily':
          expectedPayment = totalLoanAmount / duration; // duration in days
          periodsElapsed = now.difference(disbursementDate).inDays;
          break;
        case 'weekly':
          expectedPayment = totalLoanAmount / duration; // duration in weeks
          periodsElapsed = (now.difference(disbursementDate).inDays / 7).floor();
          break;
        case 'monthly':
        default:
          expectedPayment = totalLoanAmount / duration;
          periodsElapsed = _monthsBetween(disbursementDate, now);
      }

      // Get all repayments
      final repaymentsSnapshot = await _db
          .collection('saccoplus-loans')
          .doc(loanId)
          .collection('repayments')
          .orderBy('timestamp', descending: false)
          .get();

      double totalPaid = 0;
      for (var doc in repaymentsSnapshot.docs) {
        totalPaid += (doc.data()['amount'] ?? 0).toDouble();
      }

      // Calculate expected amount paid based on periods elapsed
      final expectedAmountPaid = periodsElapsed > 0 
        ? expectedPayment * periodsElapsed.clamp(0, duration)
        : 0.0;

      // Calculate arrears
      double arrearsAmount = 0;
      int periodsOverdue = 0;

      // Only calculate arrears if at least one period has passed
      if (periodsElapsed >= 1 && periodsElapsed <= duration) {
        arrearsAmount = (expectedAmountPaid - totalPaid).clamp(0, double.infinity);
        if (arrearsAmount > 0) {
          periodsOverdue = (arrearsAmount / expectedPayment).ceil();
        }
      }

      // Calculate penalty on arrears
      double penaltyAmount = 0;
      if (arrearsAmount > 0) {
        penaltyAmount = (arrearsAmount * penaltyRate / 100) * periodsOverdue;
      }

      // Calculate remaining balance
      final remainingBalance = (totalLoanAmount - totalPaid).clamp(0, double.infinity);
      final totalDue = remainingBalance + penaltyAmount;

      return {
        'loanId': loanId,
        'principal': principal,
        'totalInterest': totalInterest,
        'totalLoanAmount': totalLoanAmount,
        'expectedPayment': expectedPayment,
        'paymentFrequency': paymentFrequency,
        'totalPaid': totalPaid,
        'remainingBalance': remainingBalance,
        'expectedAmountPaid': expectedAmountPaid,
        'arrearsAmount': arrearsAmount,
        'periodsOverdue': periodsOverdue,
        'penaltyRate': penaltyRate,
        'penaltyAmount': penaltyAmount,
        'totalDue': totalDue,
        'periodsElapsed': periodsElapsed,
        'duration': duration,
        'disbursementDate': disbursementDate,
        'isOverdue': arrearsAmount > 0,
        'status': _getLoanStatus(periodsElapsed, duration, arrearsAmount, remainingBalance),
      };
    } catch (e) {
      print('Error calculating arrears: $e');
      return {'error': e.toString()};
    }
  }

  /// Update arrears for a specific loan in Firestore
  static Future<bool> updateLoanArrears(String loanId) async {
    try {
      final arrearsData = await calculateLoanArrears(loanId);
      
      if (arrearsData.containsKey('error')) {
        print('Cannot update arrears: ${arrearsData['error']}');
        return false;
      }

      await _db.collection('saccoplus-loans').doc(loanId).update({
        'arrears': arrearsData['arrearsAmount'],
        'penalties': arrearsData['penaltyAmount'],
        'monthsOverdue': arrearsData['monthsOverdue'],
        'totalDue': arrearsData['totalDue'],
        'remainingBalance': arrearsData['remainingBalance'],
        'lastArrearsUpdate': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating loan arrears: $e');
      return false;
    }
  }

  /// Update arrears for all active loans
  static Future<Map<String, int>> updateAllLoansArrears() async {
    int successCount = 0;
    int failCount = 0;
    
    try {
      final loansSnapshot = await _db
          .collection('saccoplus-loans')
          .where('status', isEqualTo: 'approved')
          .get();

      for (var doc in loansSnapshot.docs) {
        final success = await updateLoanArrears(doc.id);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }
    } catch (e) {
      print('Error updating all loans arrears: $e');
    }

    return {
      'success': successCount,
      'failed': failCount,
      'total': successCount + failCount,
    };
  }

  /// Get loans with arrears
  static Future<List<Map<String, dynamic>>> getLoansWithArrears() async {
    try {
      final loansSnapshot = await _db
          .collection('saccoplus-loans')
          .where('status', isEqualTo: 'approved')
          .where('arrears', isGreaterThan: 0)
          .get();

      final loansWithArrears = <Map<String, dynamic>>[];
      
      for (var doc in loansSnapshot.docs) {
        final loanData = doc.data();
        loanData['loanId'] = doc.id;
        
        // Get member details
        final memberId = loanData['memberId'];
        if (memberId != null) {
          final memberDoc = await _db.collection('saccoplus-members').doc(memberId).get();
          if (memberDoc.exists) {
            loanData['memberName'] = memberDoc.data()?['fullName'];
            loanData['accountNumber'] = memberDoc.data()?['accountNumber'];
            loanData['phoneNumber'] = memberDoc.data()?['phoneNumber'];
          }
        }
        
        loansWithArrears.add(loanData);
      }

      return loansWithArrears;
    } catch (e) {
      print('Error getting loans with arrears: $e');
      return [];
    }
  }

  /// Helper: Calculate months between two dates
  static int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12;
    months += end.month - start.month;
    
    // If the end day is before the start day, subtract one month
    if (end.day < start.day) {
      months--;
    }
    
    return months.clamp(0, 1000); // Clamp to reasonable range
  }

  /// Helper: Power function
  static double _pow(double base, double exponent) {
    if (exponent == 0) return 1;
    if (exponent == 1) return base;
    
    double result = 1;
    bool isNegative = exponent < 0;
    double exp = isNegative ? -exponent : exponent;
    
    for (int i = 0; i < exp.toInt(); i++) {
      result *= base;
    }
    
    // Handle fractional exponent (approximation)
    if (exp % 1 != 0) {
      final fraction = exp - exp.truncate();
      result *= (1 + (base - 1) * fraction);
    }
    
    return isNegative ? 1 / result : result;
  }

  /// Helper: Determine loan status
  static String _getLoanStatus(int monthsElapsed, int duration, double arrears, double remaining) {
    if (remaining <= 0) {
      return 'Fully Paid';
    } else if (monthsElapsed >= duration && remaining > 0) {
      return 'Defaulted';
    } else if (arrears > 0) {
      return 'In Arrears';
    } else if (monthsElapsed < duration) {
      return 'Active';
    } else {
      return 'Unknown';
    }
  }

  /// Format currency
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'en_US');
    return 'UGX ${formatter.format(amount.round())}';
  }
}

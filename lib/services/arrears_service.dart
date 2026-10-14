import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';

class ArrearsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Statuses that mean the loan is live (cover both casings).
  static const List<String> _liveStatuses = [
    'disbursed', 'Disbursed',
    'active', 'Active',
    'overdue', 'Overdue',
  ];

  // ─── Helpers ────────────────────────────────────────────────────────────────
  static double _d(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  /// SINGLE SOURCE OF TRUTH for interest.
  /// [ratePerPeriod] is the rate per payment period (10 = 10% per month
  /// for a monthly loan). Flat: principal × rate% × periods.
  static double calculateInterest({
    required double principal,
    required double ratePerPeriod,
    required int periods,
    String method = 'flat',
  }) {
    if (principal <= 0 || ratePerPeriod <= 0 || periods <= 0) return 0;
    final r = ratePerPeriod / 100;

    if (method == 'reducing') {
      final f = math.pow(1 + r, periods).toDouble();
      final payment = principal * r * f / (f - 1);
      return (payment * periods - principal).roundToDouble();
    }
    return (principal * r * periods).roundToDouble();
  }

  // ─── Arrears calculation ────────────────────────────────────────────────────
  /// Arrears = what should have been paid by now − what was actually paid.
  static Future<Map<String, dynamic>> calculateLoanArrears(String loanId) async {
    try {
      final loanDoc =
          await _db.collection(AppConstants.loansCol).doc(loanId).get();
      if (!loanDoc.exists) {
        return {'error': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final principal = _d(loanData['loanAmount'], _d(loanData['amount']));
      final interestRate = _d(loanData['interestRate']);
      final duration = _d(loanData['duration'], 12).round();
      final interestMethod =
          (loanData['interestMethod'] ?? 'flat').toString().toLowerCase();
      final penaltyRate = _d(loanData['penaltyRate'], 5);
      final paymentFrequency =
          (loanData['paymentFrequency'] ?? 'monthly').toString().toLowerCase();

      if (duration <= 0) {
        return {'error': 'Invalid loan duration'};
      }

      // Disbursement date
      DateTime? disbursementDate;
      if (loanData['disbursementDate'] is Timestamp) {
        disbursementDate = (loanData['disbursementDate'] as Timestamp).toDate();
      } else if (loanData['disbursedAt'] is Timestamp) {
        disbursementDate = (loanData['disbursedAt'] as Timestamp).toDate();
      }
      if (disbursementDate == null) {
        return {'error': 'Disbursement date not set'};
      }

      // Interest & totals
      final totalInterest = calculateInterest(
        principal: principal,
        ratePerPeriod: interestRate,
        periods: duration,
        method: interestMethod,
      );
      final totalLoanAmount = principal + totalInterest;
      final expectedPayment = totalLoanAmount / duration;

      // Periods elapsed since disbursement
      final now = DateTime.now();
      int periodsElapsed;
      switch (paymentFrequency) {
        case 'daily':
          periodsElapsed = now.difference(disbursementDate).inDays;
          break;
        case 'weekly':
          periodsElapsed = (now.difference(disbursementDate).inDays / 7).floor();
          break;
        case 'monthly':
        default:
          periodsElapsed = _monthsBetween(disbursementDate, now);
      }
      if (periodsElapsed < 0) periodsElapsed = 0;

      // Actual payments (same collection the screen writes to)
      final repaymentsSnapshot = await _db
          .collection(AppConstants.repaymentsCol)
          .where('loanId', isEqualTo: loanId)
          .get();

      double totalPaid = 0;
      for (final doc in repaymentsSnapshot.docs) {
        final data = doc.data();
        var amount = _d(data['amount']);
        if (amount <= 0) amount = _d(data['totalAmount']);
        if (amount <= 0) {
          amount = _d(data['principalAmount']) +
              _d(data['interestAmount']) +
              _d(data['chargesAmount']);
        }
        if (amount <= 0) {
          amount = _d(data['principalPaid']) +
              _d(data['interestPaid']) +
              _d(data['chargesPaid']);
        }
        totalPaid += amount;
      }

      // Installments that should be settled by now (capped at the full term,
      // so arrears keep showing after the loan has matured).
      final periodsDue = math.min(periodsElapsed, duration);
      final expectedAmountPaid = expectedPayment * periodsDue;

      // Calculate arrears but cap it at remaining balance
      // (arrears cannot exceed what's actually owed)
      final remainingBalance = math.max(0.0, totalLoanAmount - totalPaid);
      double arrearsAmount = math.max(0.0, expectedAmountPaid - totalPaid);
      
      // CRITICAL FIX: Arrears should NEVER exceed the remaining balance
      // This prevents situations where arrears show as higher than outstanding
      arrearsAmount = math.min(arrearsAmount, remainingBalance);
      
      if (arrearsAmount < 1) arrearsAmount = 0; // ignore rounding dust

      int periodsOverdue = 0;
      if (arrearsAmount > 0 && expectedPayment > 0) {
        periodsOverdue = (arrearsAmount / expectedPayment).ceil();
      }

      // Penalty on arrears
      double penaltyAmount = 0;
      if (arrearsAmount > 0) {
        penaltyAmount = (arrearsAmount * penaltyRate / 100) * periodsOverdue;
      }

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
        'status': _getLoanStatus(
            periodsElapsed, duration, arrearsAmount, remainingBalance),
      };
    } catch (e) {
      print('Error calculating arrears: $e');
      return {'error': e.toString()};
    }
  }

  /// Save the latest arrears figures on the loan document.
  static Future<bool> updateLoanArrears(String loanId) async {
    try {
      final a = await calculateLoanArrears(loanId);

      if (a.containsKey('error')) {
        print('Cannot update arrears: ${a['error']}');
        return false;
      }

      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'arrears': a['arrearsAmount'],
        'penalties': a['penaltyAmount'],
        'periodsOverdue': a['periodsOverdue'],
        'monthsOverdue': a['periodsOverdue'], // kept for older screens
        'totalDue': a['totalDue'],
        'remainingBalance': a['remainingBalance'],
        'totalOutstanding': a['remainingBalance'], // Keep in sync
        'principalOutstanding': a['remainingBalance'], // Keep in sync for backward compatibility
        'lastArrearsUpdate': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating loan arrears: $e');
      return false;
    }
  }

  /// Update arrears for every live loan.
  static Future<Map<String, int>> updateAllLoansArrears() async {
    int successCount = 0;
    int failCount = 0;

    try {
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('status', whereIn: _liveStatuses)
          .get();

      for (final doc in loansSnapshot.docs) {
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

  /// Live loans that currently have arrears (filtered in memory so no
  /// composite Firestore index is needed).
  static Future<List<Map<String, dynamic>>> getLoansWithArrears() async {
    try {
      final loansSnapshot = await _db
          .collection(AppConstants.loansCol)
          .where('status', whereIn: _liveStatuses)
          .get();

      final result = <Map<String, dynamic>>[];

      for (final doc in loansSnapshot.docs) {
        final loanData = doc.data();
        if (_d(loanData['arrears']) <= 0) continue;
        loanData['loanId'] = doc.id;

        final memberId = loanData['memberId'];
        if (memberId != null) {
          final memberDoc =
              await _db.collection('saccoplus-members').doc(memberId).get();
          if (memberDoc.exists) {
            loanData['memberName'] = memberDoc.data()?['fullName'];
            loanData['accountNumber'] = memberDoc.data()?['accountNumber'];
            loanData['phoneNumber'] = memberDoc.data()?['phoneNumber'];
          }
        }

        result.add(loanData);
      }

      return result;
    } catch (e) {
      print('Error getting loans with arrears: $e');
      return [];
    }
  }

  /// Completed months between two dates.
  static int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months--;
    return months.clamp(0, 1000);
  }

  static String _getLoanStatus(
      int periodsElapsed, int duration, double arrears, double remaining) {
    if (remaining <= 0) return 'Fully Paid';
    if (periodsElapsed >= duration) return 'Defaulted';
    if (arrears > 0) return 'In Arrears';
    return 'Active';
  }

  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'en_US');
    return 'UGX ${formatter.format(amount.round())}';
  }
}
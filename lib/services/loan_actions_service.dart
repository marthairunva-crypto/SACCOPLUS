import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import '../core/constants.dart';
import 'audit_service.dart';

/// Handles loan actions: Reschedule, Write-Off, Waive Interest, Top-Up, Close
class LoanActionsService {
  static final _db = FirebaseFirestore.instance;

  // ============================================================================
  // RESCHEDULE LOAN - Extend payment schedule
  // ============================================================================
  
  /// Reschedule a loan by extending the duration and recalculating payments
  static Future<Map<String, dynamic>> rescheduleLoan({
    required String loanId,
    required int newDuration,
    required String rescheduledBy,
    String? reason,
    DateTime? newDisbursementDate,
  }) async {
    try {
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final principal = (loanData['loanAmount'] ?? 0).toDouble();
      final interestRate = (loanData['interestRate'] ?? 0).toDouble();
      final interestMethod = loanData['interestMethod'] ?? 'flat';
      
      // Recalculate interest for new duration
      double newInterest;
      if (interestMethod == 'flat') {
        newInterest = (principal * interestRate * newDuration) / (100 * 12);
      } else {
        // Reducing balance calculation
        final r = interestRate / (100 * 12);
        final n = newDuration.toDouble();
        if (r > 0) {
          final powValue = math.pow(1 + r, n);
          final monthlyPayment = principal * r * powValue / (powValue - 1);
          newInterest = (monthlyPayment * n) - principal;
        } else {
          newInterest = 0;
        }
      }
      
      final newTotalAmount = principal + newInterest;
      
      // Create reschedule record
      final rescheduleId = const Uuid().v4();
      await _db.collection('loan-reschedules').doc(rescheduleId).set({
        'id': rescheduleId,
        'loanId': loanId,
        'memberId': loanData['farmerId'] ?? loanData['memberId'],
        'tenantId': loanData['tenantId'],
        'oldDuration': loanData['duration'],
        'newDuration': newDuration,
        'oldInterestAmount': loanData['interestAmount'] ?? 0,
        'newInterestAmount': newInterest,
        'oldTotalAmount': loanData['totalAmount'] ?? 0,
        'newTotalAmount': newTotalAmount,
        'reason': reason ?? 'Loan rescheduled',
        'rescheduledBy': rescheduledBy,
        'rescheduledAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update loan
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'duration': newDuration,
        'interestAmount': newInterest,
        'totalAmount': newTotalAmount,
        'rescheduleId': rescheduleId,
        'rescheduledAt': FieldValue.serverTimestamp(),
        'rescheduledBy': rescheduledBy,
        'rescheduleReason': reason ?? 'Loan rescheduled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (newDisbursementDate != null) {
        await _db.collection(AppConstants.loansCol).doc(loanId).update({
          'disbursementDate': Timestamp.fromDate(newDisbursementDate),
        });
      }
      
      // Audit log
      await AuditService.log(
        action: 'LOAN_RESCHEDULED',
        details: 'Loan rescheduled: Duration changed from ${loanData['duration']} to $newDuration months',
        userId: rescheduledBy,
        affectedUserId: loanData['farmerId'] ?? loanData['memberId'],
        metadata: {
          'loanId': loanId,
          'oldDuration': loanData['duration'],
          'newDuration': newDuration,
          'rescheduleId': rescheduleId,
        },
      );
      
      return {
        'success': true,
        'message': 'Loan rescheduled successfully',
        'rescheduleId': rescheduleId,
      };
    } catch (e) {
      print('❌ Error rescheduling loan: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ============================================================================
  // WRITE OFF LOAN - Mark as bad debt
  // ============================================================================
  
  /// Write off a loan (mark as uncollectable)
  static Future<Map<String, dynamic>> writeOffLoan({
    required String loanId,
    required String writtenOffBy,
    required String reason,
    double? writeOffAmount,
  }) async {
    try {
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final principalOutstanding = (loanData['principalOutstanding'] ?? 0).toDouble();
      final interestOutstanding = (loanData['interestOutstanding'] ?? 0).toDouble();
      final totalOutstanding = principalOutstanding + interestOutstanding;
      
      final actualWriteOffAmount = writeOffAmount ?? totalOutstanding;
      
      // Create write-off record
      final writeOffId = const Uuid().v4();
      await _db.collection('loan-writeoffs').doc(writeOffId).set({
        'id': writeOffId,
        'loanId': loanId,
        'memberId': loanData['farmerId'] ?? loanData['memberId'],
        'tenantId': loanData['tenantId'],
        'writeOffAmount': actualWriteOffAmount,
        'principalWrittenOff': principalOutstanding,
        'interestWrittenOff': interestOutstanding,
        'reason': reason,
        'writtenOffBy': writtenOffBy,
        'writtenOffAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update loan status
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'status': AppConstants.statusWrittenOff,
        'writeOffId': writeOffId,
        'writeOffAmount': actualWriteOffAmount,
        'writtenOffAt': FieldValue.serverTimestamp(),
        'writtenOffBy': writtenOffBy,
        'writeOffReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Audit log
      await AuditService.log(
        action: 'LOAN_WRITTEN_OFF',
        details: 'Loan written off: UGX $actualWriteOffAmount. Reason: $reason',
        userId: writtenOffBy,
        affectedUserId: loanData['farmerId'] ?? loanData['memberId'],
        metadata: {
          'loanId': loanId,
          'writeOffAmount': actualWriteOffAmount,
          'writeOffId': writeOffId,
          'reason': reason,
        },
      );
      
      return {
        'success': true,
        'message': 'Loan written off successfully',
        'writeOffId': writeOffId,
      };
    } catch (e) {
      print('❌ Error writing off loan: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ============================================================================
  // WAIVE INTEREST - Forgive interest charges
  // ============================================================================
  
  /// Waive interest on a loan (partial or full)
  static Future<Map<String, dynamic>> waiveInterest({
    required String loanId,
    required double waiveAmount,
    required String waivedBy,
    String? reason,
  }) async {
    try {
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final interestOutstanding = (loanData['interestOutstanding'] ?? 0).toDouble();
      
      if (waiveAmount > interestOutstanding) {
        return {'success': false, 'message': 'Waive amount exceeds outstanding interest'};
      }
      
      final newInterestOutstanding = interestOutstanding - waiveAmount;
      final totalWaived = (loanData['totalInterestWaived'] ?? 0).toDouble() + waiveAmount;
      
      // Create waiver record
      final waiverId = const Uuid().v4();
      await _db.collection('loan-waivers').doc(waiverId).set({
        'id': waiverId,
        'loanId': loanId,
        'memberId': loanData['farmerId'] ?? loanData['memberId'],
        'tenantId': loanData['tenantId'],
        'waiveAmount': waiveAmount,
        'interestBefore': interestOutstanding,
        'interestAfter': newInterestOutstanding,
        'reason': reason ?? 'Interest waived',
        'waivedBy': waivedBy,
        'waivedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update loan
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'interestOutstanding': newInterestOutstanding,
        'totalInterestWaived': totalWaived,
        'lastWaiverId': waiverId,
        'lastWaivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Audit log
      await AuditService.log(
        action: 'INTEREST_WAIVED',
        details: 'Interest waived: UGX $waiveAmount. Reason: ${reason ?? "Interest waived"}',
        userId: waivedBy,
        affectedUserId: loanData['farmerId'] ?? loanData['memberId'],
        metadata: {
          'loanId': loanId,
          'waiveAmount': waiveAmount,
          'waiverId': waiverId,
        },
      );
      
      return {
        'success': true,
        'message': 'Interest waived successfully',
        'waiverId': waiverId,
      };
    } catch (e) {
      print('❌ Error waiving interest: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ============================================================================
  // TOP UP LOAN - Add more funds to existing loan
  // ============================================================================
  
  /// Top up an existing loan with additional funds
  static Future<Map<String, dynamic>> topUpLoan({
    required String loanId,
    required double topUpAmount,
    required String approvedBy,
    String? reason,
  }) async {
    try {
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final currentPrincipal = (loanData['loanAmount'] ?? 0).toDouble();
      final interestRate = (loanData['interestRate'] ?? 0).toDouble();
      final duration = loanData['duration'] ?? 12;
      final interestMethod = loanData['interestMethod'] ?? 'flat';
      
      final newPrincipal = currentPrincipal + topUpAmount;
      
      // Calculate new interest
      double newInterest;
      if (interestMethod == 'flat') {
        newInterest = (newPrincipal * interestRate * duration) / (100 * 12);
      } else {
        final r = interestRate / (100 * 12);
        final n = duration.toDouble();
        if (r > 0) {
          final powValue = math.pow(1 + r, n);
          final monthlyPayment = newPrincipal * r * powValue / (powValue - 1);
          newInterest = (monthlyPayment * n) - newPrincipal;
        } else {
          newInterest = 0;
        }
      }
      
      final newTotalAmount = newPrincipal + newInterest;
      
      // Create top-up record
      final topUpId = const Uuid().v4();
      await _db.collection('loan-topups').doc(topUpId).set({
        'id': topUpId,
        'loanId': loanId,
        'memberId': loanData['farmerId'] ?? loanData['memberId'],
        'tenantId': loanData['tenantId'],
        'topUpAmount': topUpAmount,
        'oldPrincipal': currentPrincipal,
        'newPrincipal': newPrincipal,
        'oldInterest': loanData['interestAmount'] ?? 0,
        'newInterest': newInterest,
        'oldTotalAmount': loanData['totalAmount'] ?? 0,
        'newTotalAmount': newTotalAmount,
        'reason': reason ?? 'Loan top-up',
        'approvedBy': approvedBy,
        'approvedAt': FieldValue.serverTimestamp(),
        'status': 'pending_disbursement',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update loan
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'loanAmount': newPrincipal,
        'interestAmount': newInterest,
        'totalAmount': newTotalAmount,
        'principalOutstanding': newPrincipal,
        'interestOutstanding': newInterest,
        'topUpId': topUpId,
        'topUpAmount': topUpAmount,
        'toppedUpAt': FieldValue.serverTimestamp(),
        'toppedUpBy': approvedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Audit log
      await AuditService.log(
        action: 'LOAN_TOPPED_UP',
        details: 'Loan topped up with UGX $topUpAmount. New principal: UGX $newPrincipal',
        userId: approvedBy,
        affectedUserId: loanData['farmerId'] ?? loanData['memberId'],
        metadata: {
          'loanId': loanId,
          'topUpAmount': topUpAmount,
          'topUpId': topUpId,
        },
      );
      
      return {
        'success': true,
        'message': 'Loan topped up successfully. Top-up pending disbursement.',
        'topUpId': topUpId,
      };
    } catch (e) {
      print('❌ Error topping up loan: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ============================================================================
  // CLOSE LOAN - Manually close a loan
  // ============================================================================
  
  /// Close a loan manually
  static Future<Map<String, dynamic>> closeLoan({
    required String loanId,
    required String closedBy,
    String? reason,
  }) async {
    try {
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      
      // Create closure record
      final closureId = const Uuid().v4();
      await _db.collection('loan-closures').doc(closureId).set({
        'id': closureId,
        'loanId': loanId,
        'memberId': loanData['farmerId'] ?? loanData['memberId'],
        'tenantId': loanData['tenantId'],
        'principalOutstanding': loanData['principalOutstanding'] ?? 0,
        'interestOutstanding': loanData['interestOutstanding'] ?? 0,
        'reason': reason ?? 'Loan closed manually',
        'closedBy': closedBy,
        'closedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Update loan status
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'status': 'Closed',
        'closureId': closureId,
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': closedBy,
        'closureReason': reason ?? 'Loan closed manually',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Audit log
      await AuditService.log(
        action: 'LOAN_CLOSED',
        details: 'Loan closed. Reason: ${reason ?? "Loan closed manually"}',
        userId: closedBy,
        affectedUserId: loanData['farmerId'] ?? loanData['memberId'],
        metadata: {
          'loanId': loanId,
          'closureId': closureId,
        },
      );
      
      return {
        'success': true,
        'message': 'Loan closed successfully',
        'closureId': closureId,
      };
    } catch (e) {
      print('❌ Error closing loan: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}

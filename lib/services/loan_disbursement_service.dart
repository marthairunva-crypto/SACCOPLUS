import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/till_session.dart';
import '../models/till_entry.dart';
import 'audit_service.dart';
import 'till_service.dart';
import '../core/sacco_service.dart';
import '../core/firebase_service.dart';

/// Handles loan disbursement operations
class LoanDisbursementService {
  static final _db = FirebaseFirestore.instance;

  /// Disburse an approved loan by crediting member's savings account
  /// 
  /// [loanId] - The loan document ID
  /// [disbursedBy] - User ID of the person disbursing
  /// [amount] - Amount being disbursed (should match loan amount)
  /// [narration] - Description of the transaction
  static Future<Map<String, dynamic>> disburseLoan({
    required String loanId,
    required String disbursedBy,
    required double amount,
    String? narration,
  }) async {
    try {
      // 1. Get loan details
      final loanDoc = await _db.collection(AppConstants.loansCol).doc(loanId).get();
      
      if (!loanDoc.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanDoc.data()!;
      final loanStatus = loanData['status'] as String?;
      final loanAmount = (loanData['amount'] ?? loanData['loanAmount'] ?? 0).toDouble();
      final memberId = loanData['farmerId'] ?? loanData['memberId'];
      final tenantId = loanData['tenantId'];

      // 2. Validate loan can be disbursed
      if (loanStatus != AppConstants.statusApproved) {
        return {'success': false, 'message': 'Only approved loans can be disbursed'};
      }

      if (amount != loanAmount) {
        return {'success': false, 'message': 'Disbursement amount must match loan amount'};
      }

      // 3. Get member details
      final memberDoc = await _db.collection(AppConstants.usersCol).doc(memberId).get();
      if (!memberDoc.exists) {
        return {'success': false, 'message': 'Member not found'};
      }
      
      final memberData = memberDoc.data()!;
      final memberName = memberData['name'] ?? 'Unknown';
      final currentSavings = (memberData['savingsBalance'] ?? 0).toDouble();

      // 4. Create disbursement transaction record
      final disbursementId = const Uuid().v4();
      final now = DateTime.now();
      
      await _db.collection('loan-disbursements').doc(disbursementId).set({
        'id': disbursementId,
        'loanId': loanId,
        'memberId': memberId,
        'memberName': memberName,
        'tenantId': tenantId,
        'amount': amount,
        'destinationType': 'savings_credit', // Credited to savings
        'narration': narration ?? 'Loan disbursement credited to savings',
        'disbursedBy': disbursedBy,
        'disbursedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Update loan status and set disbursement date
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'status': AppConstants.statusDisbursed,
        'disbursedAt': FieldValue.serverTimestamp(),
        'disbursementDate': FieldValue.serverTimestamp(),
        'disbursementId': disbursementId,
        'disbursedBy': disbursedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 6. Credit member's savings account
      final newSavingsBalance = currentSavings + amount;
      await _db.collection(AppConstants.usersCol).doc(memberId).update({
        'savingsBalance': newSavingsBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 7. Create savings deposit transaction
      final depositId = const Uuid().v4();
      await _db.collection(AppConstants.tellerTxnCol).doc(depositId).set({
        'id': depositId,
        'type': 'deposit',
        'accountType': 'savings',
        'category': 'loan_disbursement',
        'memberId': memberId,
        'memberName': memberName,
        'loanId': loanId,
        'tenantId': tenantId,
        'amount': amount,
        'paymentMethod': 'Internal Transfer',
        'source': 'teller',
        'narration': narration ?? 'Loan disbursement credited to savings',
        'processedBy': disbursedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'businessRecordId': disbursementId,
        'businessRecordType': 'loan_disbursement',
      });

      // 8. Update member's loan balance
      final currentLoanBalance = (memberData['loanBalance'] ?? 0).toDouble();
      await _db.collection(AppConstants.usersCol).doc(memberId).update({
        'loanBalance': currentLoanBalance + amount,
      });

      // 9. Audit log
      await AuditService.log(
        action: AuditService.ACTION_LOAN_DISBURSED,
        details: 'Loan disbursed: UGX ${amount.toStringAsFixed(0)} credited to savings account',
        userId: disbursedBy,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'amount': amount,
          'destinationType': 'savings_credit',
          'disbursementId': disbursementId,
          'previousSavings': currentSavings,
          'newSavings': newSavingsBalance,
        },
      );

      // 10. Send SMS notification to member
      final phone = memberData['phone'] as String?;
      final alternativePhone = memberData['alternativePhone'] as String?;
      
      if (phone != null && phone.isNotEmpty) {
        final saccoName = SaccoService.current.saccoName;
        final formattedAmount = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        final formattedBalance = newSavingsBalance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
        
        final message = '$saccoName: Dear $memberName, your loan of UGX $formattedAmount has been disbursed and credited to your savings account. Your new savings balance is UGX $formattedBalance. Visit any branch to withdraw. Thank you!';
        
        try {
          print('📤 Sending loan disbursement SMS to member phone: $phone');
          await FirebaseService.sendSmsToPhone(phone, message);
          
          // Also send to alternative phone if provided
          if (alternativePhone != null && alternativePhone.isNotEmpty) {
            print('📤 Sending loan disbursement SMS to alternative phone: $alternativePhone');
            await FirebaseService.sendSmsToPhone(alternativePhone, message);
          }
        } catch (smsError) {
          print('⚠️ Failed to send loan disbursement SMS: $smsError');
          // Non-critical error, don't fail the disbursement
        }
      }

      return {
        'success': true,
        'message': 'Loan disbursed successfully. Amount credited to member savings account.',
        'disbursementId': disbursementId,
        'newSavingsBalance': newSavingsBalance,
      };
    } catch (e) {
      print('❌ Error disbursing loan: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get disbursement history for a loan
  static Future<List<Map<String, dynamic>>> getDisbursementHistory(String loanId) async {
    try {
      final snapshot = await _db
          .collection('loan-disbursements')
          .where('loanId', isEqualTo: loanId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting disbursement history: $e');
      return [];
    }
  }

  /// Get all disbursements for reporting
  static Stream<QuerySnapshot> getAllDisbursements() {
    return _db
        .collection('loan-disbursements')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get disbursements by date range
  static Future<List<Map<String, dynamic>>> getDisbursementsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _db
          .collection('loan-disbursements')
          .where('disbursedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('disbursedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('disbursedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting disbursements by date range: $e');
      return [];
    }
  }
}

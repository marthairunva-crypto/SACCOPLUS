import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import 'audit_service.dart';

/// Handles loan disbursement operations
class LoanDisbursementService {
  static final _db = FirebaseFirestore.instance;

  /// Disburse an approved loan
  /// 
  /// [loanId] - The loan document ID
  /// [destinationType] - 'cash', 'bank', or 'mobile_money'
  /// [referenceNumber] - Receipt/reference number
  /// [chequeNumber] - Cheque number if applicable
  /// [narration] - Description of the transaction
  /// [disbursedBy] - User ID of the person disbursing
  /// [amount] - Amount being disbursed (should match loan amount)
  static Future<Map<String, dynamic>> disburseLoan({
    required String loanId,
    required String destinationType,
    required String disbursedBy,
    required double amount,
    String? referenceNumber,
    String? chequeNumber,
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

      // 3. Create disbursement transaction record
      final disbursementId = const Uuid().v4();
      final now = DateTime.now();
      
      await _db.collection('loan-disbursements').doc(disbursementId).set({
        'id': disbursementId,
        'loanId': loanId,
        'memberId': memberId,
        'tenantId': tenantId,
        'amount': amount,
        'destinationType': destinationType,
        'referenceNumber': referenceNumber ?? '',
        'chequeNumber': chequeNumber ?? '',
        'narration': narration ?? 'Loan disbursement',
        'disbursedBy': disbursedBy,
        'disbursedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Update loan status and set disbursement date
      await _db.collection(AppConstants.loansCol).doc(loanId).update({
        'status': AppConstants.statusDisbursed,
        'disbursedAt': FieldValue.serverTimestamp(),
        'disbursementDate': FieldValue.serverTimestamp(),
        'disbursementId': disbursementId,
        'disbursedBy': disbursedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Create teller transaction
      final txnId = const Uuid().v4();
      await _db.collection(AppConstants.tellerTxnCol).doc(txnId).set({
        'id': txnId,
        'type': 'loan_disbursement',
        'category': 'loan',
        'memberId': memberId,
        'loanId': loanId,
        'tenantId': tenantId,
        'amount': amount,
        'destinationType': destinationType,
        'referenceNumber': referenceNumber ?? '',
        'chequeNumber': chequeNumber ?? '',
        'narration': narration ?? 'Loan disbursement',
        'processedBy': disbursedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // 6. Update member's loan balance (if they track it)
      if (memberId != null) {
        final memberDoc = await _db.collection(AppConstants.usersCol).doc(memberId).get();
        if (memberDoc.exists) {
          final currentLoanBalance = (memberDoc.data()?['loanBalance'] ?? 0).toDouble();
          await _db.collection(AppConstants.usersCol).doc(memberId).update({
            'loanBalance': currentLoanBalance + amount,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 7. Audit log
      await AuditService.log(
        action: AuditService.ACTION_LOAN_DISBURSED,
        details: 'Loan disbursed: $amount via $destinationType',
        userId: disbursedBy,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'amount': amount,
          'destinationType': destinationType,
          'referenceNumber': referenceNumber ?? '',
          'disbursementId': disbursementId,
        },
      );

      return {
        'success': true,
        'message': 'Loan disbursed successfully',
        'disbursementId': disbursementId,
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

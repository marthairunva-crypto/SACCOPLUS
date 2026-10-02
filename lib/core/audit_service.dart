import 'package:cloud_firestore/cloud_firestore.dart';
import 'constants.dart';
import 'firebase_service.dart';

/// Writes tamper-proof audit log entries to saccoplus-audit-logs.
/// Call this after every significant action (loan approval, KYC, payments, etc.)
class AuditService {
  static final _db = FirebaseFirestore.instance;

  // ── Action constants ──────────────────────────────────────────────────────
  static const String kLoanApproved    = 'LOAN_APPROVED';
  static const String kLoanRejected    = 'LOAN_REJECTED';
  static const String kKycApproved     = 'KYC_APPROVED';
  static const String kKycRejected     = 'KYC_REJECTED';
  static const String kDeposit         = 'WALLET_DEPOSIT';
  static const String kWithdrawal      = 'WALLET_WITHDRAWAL';
  static const String kRepayment       = 'LOAN_REPAYMENT';
  static const String kSavingsDeposit  = 'SAVINGS_DEPOSIT';
  static const String kSavingsEdit     = 'SAVINGS_EDIT';
  static const String kSavingsDelete   = 'SAVINGS_DELETE';
  static const String kSharePurchase   = 'SHARE_PURCHASE';
  static const String kFdApproved      = 'FD_APPROVED';
  static const String kFdRejected      = 'FD_REJECTED';
  static const String kFdMatured       = 'FD_MATURED';
  static const String kLogin           = 'USER_LOGIN';
  static const String kPinChanged      = 'PIN_CHANGED';
  static const String kProfileUpdated  = 'PROFILE_UPDATED';
  static const String kNotifSent       = 'NOTIFICATION_SENT';

  /// Log an audit event. Fire-and-forget — never throws.
  static Future<void> log({
    required String action,
    required String description,
    String? targetId,       // e.g. loanId, memberId
    String? targetName,     // human-readable name
    Map<String, dynamic>? meta,
  }) async {
    try {
      final actorUid  = FirebaseService.sessionUid;
      final actorName = FirebaseService.sessionProfile?['name'] as String? ?? 'System';
      final actorRole = FirebaseService.sessionProfile?['role'] as String? ?? 'unknown';

      final id = '${DateTime.now().millisecondsSinceEpoch}_${actorUid.hashCode.abs()}';
      await _db.collection(AppConstants.auditLogCol).doc(id).set({
        'id': id,
        'action': action,
        'description': description,
        'actorUid': actorUid,
        'actorName': actorName,
        'actorRole': actorRole,
        if (targetId   != null) 'targetId': targetId,
        if (targetName != null) 'targetName': targetName,
        if (meta       != null) 'meta': meta,
        'timestamp': FieldValue.serverTimestamp(),
        'timestampLocal': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Audit logging must never crash the app
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';

/// Comprehensive audit trail service for tracking all system actions
class AuditService {
  static final _db = FirebaseFirestore.instance;
  static final _tenantId = SaccoService.current.tenantId;

  /// Log an audit event
  static Future<void> log({
    required String action,
    required String details,
    required String userId,
    String? affectedUserId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _db.collection('audit_logs').add({
        'tenantId': _tenantId,
        'action': action,
        'details': details,
        'userId': userId,
        'userName': FirebaseService.sessionProfile?['name'] ?? 'System',
        'affectedUserId': affectedUserId,
        'metadata': metadata ?? {},
        'timestamp': DateTime.now(),
        'ipAddress': 'N/A', // Could be enhanced with actual IP tracking
      });
    } catch (e) {
      // Silently fail - audit logging should not break functionality
      print('Audit log failed: $e');
    }
  }

  /// Get audit logs with filters - Reading from CORRECT collection
  static Future<List<Map<String, dynamic>>> getLogs({
    String? userId,
    String? affectedUserId,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      // Read from saccoplus-audit-logs (where logs are actually written)
      final snapshot = await _db
          .collection('saccoplus-audit-logs')
          .limit(limit)
          .get();

      var logs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'action': data['action'] ?? '',
          'details': data['description'] ?? '',
          'userId': data['actorUid'] ?? '',
          'userName': data['actorName'] ?? '',
          'affectedUserId': data['targetId'] ?? '',
          'timestamp': data['timestamp'] != null 
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.parse(data['timestampLocal'] ?? DateTime.now().toIso8601String()),
          'metadata': data['meta'] ?? {},
        };
      }).toList();

      // Sort by timestamp descending
      logs.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      // Apply filters client-side
      if (action != null) {
        logs = logs.where((log) => log['action'].toString().contains(action)).toList();
      }
      if (userId != null) {
        logs = logs.where((log) => log['userId'] == userId).toList();
      }
      if (startDate != null) {
        logs = logs.where((log) => (log['timestamp'] as DateTime).isAfter(startDate)).toList();
      }
      if (endDate != null) {
        logs = logs.where((log) => (log['timestamp'] as DateTime).isBefore(endDate)).toList();
      }

      return logs;
    } catch (e) {
      print('Error loading audit logs: $e');
      return [];
    }
  }

  /// Common audit action types
  static const String ACTION_LOGIN = 'LOGIN';
  static const String ACTION_LOGOUT = 'LOGOUT';
  static const String ACTION_LOAN_APPROVED = 'LOAN_APPROVED';
  static const String ACTION_LOAN_REJECTED = 'LOAN_REJECTED';
  static const String ACTION_LOAN_DISBURSED = 'LOAN_DISBURSED';
  static const String ACTION_REPAYMENT_RECEIVED = 'REPAYMENT_RECEIVED';
  static const String ACTION_KYC_APPROVED = 'KYC_APPROVED';
  static const String ACTION_KYC_REJECTED = 'KYC_REJECTED';
  static const String ACTION_SAVINGS_DEPOSIT = 'SAVINGS_DEPOSIT';
  static const String ACTION_SAVINGS_WITHDRAWAL = 'SAVINGS_WITHDRAWAL';
  static const String ACTION_SHARES_PURCHASED = 'SHARES_PURCHASED';
  static const String ACTION_TELLER_DEPOSIT = 'TELLER_DEPOSIT';
  static const String ACTION_TELLER_WITHDRAWAL = 'TELLER_WITHDRAWAL';
  static const String ACTION_SETTINGS_UPDATED = 'SETTINGS_UPDATED';
  static const String ACTION_STAFF_ADDED = 'STAFF_ADDED';
  static const String ACTION_STAFF_REMOVED = 'STAFF_REMOVED';
  static const String ACTION_DATA_EXPORT = 'DATA_EXPORT';
}

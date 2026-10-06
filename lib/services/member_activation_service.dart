import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/constants.dart';

/// Service to activate migrated member accounts with temporary passwords
class MemberActivationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Set temporary password for a single member
  static Future<Map<String, dynamic>> activateMember({
    required String memberId,
    String? customTempPassword,
  }) async {
    try {
      final tempPassword = customTempPassword ?? _generateTempPassword();

      await _db.collection(AppConstants.usersCol).doc(memberId).update({
        'tempPassword': tempPassword,
        'firstLoginComplete': false,
        'accountActivated': true,
        'activatedAt': DateTime.now(),
      });

      return {
        'success': true,
        'tempPassword': tempPassword,
        'message': 'Account activated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to activate account: ${e.toString()}',
      };
    }
  }

  /// Activate all members without accounts (bulk activation)
  static Future<Map<String, dynamic>> activateAllMembers({
    String? tenantId,
    bool sendSMS = false,
  }) async {
    final tid = tenantId ?? FirebaseService.sessionTenantId;
    int successCount = 0;
    int failCount = 0;
    List<String> errors = [];

    try {
      // Get all members who don't have tempPassword or firstLoginComplete
      final membersSnapshot = await _db
          .collection(AppConstants.usersCol)
          .where('tenantId', isEqualTo: tid)
          .where('role', isEqualTo: 'farmer')
          .get();

      print('📊 Found ${membersSnapshot.docs.length} members');

      for (final doc in membersSnapshot.docs) {
        try {
          final data = doc.data();
          final accountNumber = data['accountNumber'] as String?;
          final phone = data['phone'] as String?;
          final name = data['name'] as String?;
          
          // Skip if already activated
          if (data['tempPassword'] != null && 
              (data['tempPassword'] as String).isNotEmpty) {
            continue;
          }

          // Generate temp password (last 4 digits of account number or random)
          String tempPassword;
          if (accountNumber != null && accountNumber.length >= 4) {
            tempPassword = accountNumber.substring(accountNumber.length - 4);
          } else {
            tempPassword = _generateTempPassword();
          }

          // Update member with temp password
          await _db.collection(AppConstants.usersCol).doc(doc.id).update({
            'tempPassword': tempPassword,
            'firstLoginComplete': false,
            'accountActivated': true,
            'activatedAt': DateTime.now(),
          });

          // Send SMS if enabled and phone exists
          if (sendSMS && phone != null && phone.isNotEmpty) {
            try {
              await FirebaseService.sendSmsToPhone(
                phone,
                'MBADIFA SACCO\n'
                'Dear ${name ?? 'Member'}, your account has been activated. '
                'Account No: $accountNumber\n'
                'Temporary Password: $tempPassword\n'
                'Login and change your password. Thank you.',
              );
            } catch (smsError) {
              print('SMS failed for $phone: $smsError');
              // Don't fail the whole operation if SMS fails
            }
          }

          successCount++;
          print('✅ Activated: ${name ?? doc.id} ($accountNumber)');
        } catch (e) {
          failCount++;
          errors.add('${doc.id}: ${e.toString()}');
          print('❌ Failed: ${doc.id} - $e');
        }
      }

      return {
        'success': true,
        'activated': successCount,
        'failed': failCount,
        'total': membersSnapshot.docs.length,
        'errors': errors,
        'message': 'Activated $successCount members successfully. $failCount failed.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Bulk activation failed: ${e.toString()}',
      };
    }
  }

  /// Get members who need activation
  static Future<List<Map<String, dynamic>>> getMembersNeedingActivation({
    String? tenantId,
  }) async {
    final tid = tenantId ?? FirebaseService.sessionTenantId;

    try {
      final snapshot = await _db
          .collection(AppConstants.usersCol)
          .where('tenantId', isEqualTo: tid)
          .where('role', isEqualTo: 'farmer')
          .get();

      final needsActivation = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tempPassword = data['tempPassword'] as String?;
        final firstLoginComplete = data['firstLoginComplete'] as bool?;

        // Needs activation if no temp password set
        if (tempPassword == null || tempPassword.isEmpty) {
          needsActivation.add({
            'id': doc.id,
            ...data,
          });
        }
      }

      return needsActivation;
    } catch (e) {
      print('Error getting members needing activation: $e');
      return [];
    }
  }

  /// Generate a random 4-digit temporary password
  static String _generateTempPassword() {
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return random.toString().padLeft(4, '0');
  }

  /// Send activation SMS to a member
  static Future<bool> sendActivationSMS({
    required String phone,
    required String name,
    required String accountNumber,
    required String tempPassword,
  }) async {
    try {
      await FirebaseService.sendSmsToPhone(
        phone,
        'MBADIFA SACCO\n'
        'Dear $name, your account has been activated.\n'
        'Account No: $accountNumber\n'
        'Temporary Password: $tempPassword\n'
        'Login at app.mbadifasacco.com and change your password.\n'
        'Keep your password secure. Thank you.',
      );
      return true;
    } catch (e) {
      print('Failed to send activation SMS: $e');
      return false;
    }
  }
}

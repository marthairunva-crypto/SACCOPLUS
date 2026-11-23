import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';

/// Service to send subscription expiry reminders via SMS
/// Sends SMS to all admins/tellers 2 days before expiry
class SubscriptionReminderService {
  static final _db = FirebaseFirestore.instance;

  /// Check if we need to send reminder and send SMS to admins/tellers
  /// Call this on app startup or daily
  static Future<void> checkAndSendReminders() async {
    try {
      final sacco = SaccoService.current;
      final daysLeft = sacco.daysUntilExpiry;

      // Only send reminder at exactly 2 days before expiry
      if (daysLeft != 2) return;

      final tenantId = sacco.tenantId;
      final expiryDate = sacco.subscriptionEnd;
      
      if (expiryDate == null) return;

      // Check if we already sent reminder for this expiry date
      final reminderDoc = await _db
          .collection('subscription_reminders')
          .doc('${tenantId}_${DateFormat('yyyyMMdd').format(expiryDate)}')
          .get();

      if (reminderDoc.exists) {
        // Already sent reminder for this expiry date
        return;
      }

      // Get all admins and tellers
      final users = await _db
          .collection('saccoplus-users')
          .where('tenantId', isEqualTo: tenantId)
          .where('role', whereIn: ['admin', 'teller', 'super_admin'])
          .get();

      if (users.docs.isEmpty) {
        print('⚠️ No admins/tellers found to send subscription reminder');
        return;
      }

      final dateStr = DateFormat('d MMM yyyy').format(expiryDate);
      final message = '''MBADIFA SACCO - URGENT
Your subscription expires in 2 DAYS (${dateStr}).

Renew now to avoid service interruption.

Contact: +256 779 876 876
Email: support@saccoplus.com''';

      // Send SMS to each admin/teller
      int sentCount = 0;
      for (final userDoc in users.docs) {
        final data = userDoc.data();
        final phone = data['phone'] as String?;
        final name = data['name'] as String? ?? 'Admin';

        if (phone != null && phone.isNotEmpty) {
          try {
            await FirebaseService.sendSmsToPhone(phone, message);
            print('✅ Sent subscription reminder SMS to $name ($phone)');
            sentCount++;
          } catch (e) {
            print('❌ Failed to send SMS to $name ($phone): $e');
          }
        }
      }

      // Record that we sent the reminder
      await _db
          .collection('subscription_reminders')
          .doc('${tenantId}_${DateFormat('yyyyMMdd').format(expiryDate)}')
          .set({
        'tenantId': tenantId,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'sentAt': FieldValue.serverTimestamp(),
        'sentTo': users.docs.map((d) => d.data()['phone']).toList(),
        'sentCount': sentCount,
        'daysBeforeExpiry': 2,
      });

      print('✅ Subscription reminder sent to $sentCount users');
    } catch (e) {
      print('❌ Error checking/sending subscription reminders: $e');
    }
  }

  /// Send immediate test SMS (for testing purposes)
  static Future<void> sendTestReminder(String phoneNumber) async {
    try {
      final sacco = SaccoService.current;
      final expiryDate = sacco.subscriptionEnd;
      
      if (expiryDate == null) {
        print('❌ No subscription expiry date set');
        return;
      }

      final dateStr = DateFormat('d MMM yyyy').format(expiryDate);
      final daysLeft = sacco.daysUntilExpiry ?? 0;
      
      final message = '''TEST - MBADIFA SACCO
Your subscription expires in $daysLeft days (${dateStr}).

This is a TEST notification.

Contact: +256 779 876 876''';

      await FirebaseService.sendSmsToPhone(phoneNumber, message);
      print('✅ Test reminder sent to $phoneNumber');
    } catch (e) {
      print('❌ Failed to send test reminder: $e');
    }
  }
}

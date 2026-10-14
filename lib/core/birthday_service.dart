import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';

/// Handles birthday notification (in-app + SMS) for SACCOPLUS members.
///
/// Normal flow  → call [checkAndWish] after profile loads on dashboard.
/// Developer    → call [forceSend] to bypass all guards and send immediately.
class BirthdayService {
  // ─── Public API ─────────────────────────────────────────────────────────

  /// Called automatically after profile loads on the dashboard.
  /// Fires only when today matches the stored dateOfBirth, and at most
  /// once per calendar day (guarded by SharedPreferences).
  static Future<void> checkAndWish({
    required String uid,
    required Map<String, dynamic> profile,
  }) async {
    final dob = profile['dateOfBirth'] as String?;
    if (dob == null || dob.isEmpty) return;

    DateTime birthDate;
    try {
      birthDate = DateTime.parse(dob);
    } catch (_) {
      return;
    }

    final now = DateTime.now();

    // Compare day + month only (birthday recurs every year)
    if (birthDate.day != now.day || birthDate.month != now.month) return;

    // Guard: only send once per calendar day
    final prefs = await SharedPreferences.getInstance();
    final guardKey =
        'birthday_wished_${uid}_${now.year}_${now.month}_${now.day}';
    if (prefs.getBool(guardKey) == true) return;

    await _send(uid: uid, profile: profile);
    await prefs.setBool(guardKey, true);
  }

  /// Developer tool — sends the birthday notification immediately,
  /// ignoring the date check and the once-per-day guard.
  /// Only available in debug builds (no-op in release).
  static Future<void> forceSend({
    required String uid,
    required Map<String, dynamic> profile,
  }) async {
    if (!kDebugMode) return; // never fires in production
    await _send(uid: uid, profile: profile);

    // Reset guard so the real auto-check can still fire today if needed
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final guardKey =
        'birthday_wished_${uid}_${now.year}_${now.month}_${now.day}';
    await prefs.remove(guardKey);
  }

  // ─── Internal ────────────────────────────────────────────────────────────

  static Future<void> _send({
    required String uid,
    required Map<String, dynamic> profile,
  }) async {
    final name = (profile['name'] as String? ?? 'Member').trim();
    final phone = profile['phone'] as String? ?? '';

    const title = 'Happy Birthday!';

    // In-app message — clean, no emojis, no age
    final inAppMessage =
        'Dear $name, MBADIFA SACCO wishes you a wonderful birthday! '
        'May this year bring you prosperity, good health, and financial success.';

    // SMS — plain ASCII only, EgoSMS gateway does not support Unicode or emojis
    final smsText =
        'Happy Birthday $name! MBADIFA SACCO wishes you a blessed birthday. '
        'May this year be your best yet!';

    // 1. In-app Firestore notification
    await FirebaseService.sendNotification(uid, title, inAppMessage,
        type: 'birthday');

    // 2. SMS via EgoSMS
    if (phone.isNotEmpty) {
      await FirebaseService.sendSmsToPhone(phone, smsText);
    }
  }
}

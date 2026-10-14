import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks failed PIN attempts per account and locks the account temporarily
/// after too many wrong guesses.
///
/// Data lives in Firestore (collection `saccoplus-login-attempts`, one doc per
/// account), so the counter survives app restarts, reinstalls and other devices.
///
/// Put this file at: lib/core/login_attempt_service.dart
class LoginAttemptService {
  /// Wrong PINs allowed before the account is locked
  static const int maxAttempts = 5;

  /// How long the account stays locked
  static const Duration lockDuration = Duration(minutes: 15);

  static const String _collection = 'saccoplus-login-attempts';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(_collection);

  /// Remaining lock time, or null if the account is NOT locked.
  static Future<Duration?> getRemainingLock(String key) async {
    try {
      final snap = await _col.doc(key).get();
      final data = snap.data();
      if (data == null) return null;

      final lockedUntil = data['lockedUntil'];
      if (lockedUntil is! Timestamp) return null;

      final remaining = lockedUntil.toDate().difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    } catch (e) {
      // If Firestore rules block this collection we don't want to lock every
      // member out of the app. Fix the rules if you ever see this message.
      // ignore: avoid_print
      print('⚠️ LoginAttemptService.getRemainingLock failed: $e');
      return null;
    }
  }

  /// Records a wrong PIN. Returns how many attempts are LEFT
  /// (0 means the account has just been locked).
  static Future<int> recordFailure(String key) async {
    try {
      return await FirebaseFirestore.instance.runTransaction<int>((tx) async {
        final ref = _col.doc(key);
        final snap = await tx.get(ref);
        final data = snap.data() ?? <String, dynamic>{};

        var failed = (data['failedAttempts'] as num?)?.toInt() ?? 0;

        // A previous lock that has already expired starts a fresh count
        final lockedUntil = data['lockedUntil'];
        if (lockedUntil is Timestamp && lockedUntil.toDate().isBefore(DateTime.now())) {
          failed = 0;
        }

        failed += 1;

        if (failed >= maxAttempts) {
          tx.set(
            ref,
            {
              'failedAttempts': failed,
              'lockedUntil': Timestamp.fromDate(DateTime.now().add(lockDuration)),
              'lastFailedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          return 0;
        }

        tx.set(
          ref,
          {
            'failedAttempts': failed,
            'lockedUntil': FieldValue.delete(),
            'lastFailedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return maxAttempts - failed;
      });
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ LoginAttemptService.recordFailure failed: $e');
      return maxAttempts; // can't track -> don't show a misleading number
    }
  }

  /// Call after a SUCCESSFUL login to clear the counter.
  static Future<void> reset(String key) async {
    try {
      await _col.doc(key).set(
        {
          'failedAttempts': 0,
          'lockedUntil': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ LoginAttemptService.reset failed: $e');
    }
  }

  /// "14 minutes", "1 minute", "less than a minute"
  static String formatRemaining(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    if (minutes <= 1) return d.inSeconds < 60 ? 'less than a minute' : '1 minute';
    return '$minutes minutes';
  }
}

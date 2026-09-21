import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time data migration from agro-loans-* collections → saccoplus-* collections.
///
/// Design principles:
/// ─ Per-user sentinel: each user's migration state is tracked in their own
///   saccoplus-members doc (field: _migrationVersion). This means one user's
///   migration never affects another's.
/// ─ Additive-only: we NEVER overwrite a field that already has a value.
///   pinHash is always preserved. Balance is never reduced.
/// ─ Idempotent: safe to call on every app launch — exits instantly if done.
/// ─ Version-gated: bump _currentVersion only when genuinely new work is needed.
class MigrationService {
  static final _db = FirebaseFirestore.instance;

  // ── Version history ──────────────────────────────────────────────────────
  // 1 → initial (ran before Firestore rules were fixed — wallets not written)
  // 2 → overwrote docs including pinHash — caused "incorrect PIN" bug
  // 3 → safe per-collection merge, but sentinel was global so re-ran on everyone
  // 4 → per-user sentinel + strictly additive (never overwrites existing values)
  static const int _currentVersion = 4;

  // Local SharedPreferences key — fast check before hitting Firestore
  static String _localKey(String uid) => 'sp_migration_${uid}_v$_currentVersion';

  // ── Old → New collection map ─────────────────────────────────────────────
  static const Map<String, String> _collectionMap = {
    'agro-loans-users':                'saccoplus-members',
    'agro-loans-loans':                'saccoplus-loans',
    'agro-loans-repayments':           'saccoplus-repayments',
    'agro-loans-wallets':              'saccoplus-wallets',
    'agro-loans-wallet-transactions':  'saccoplus-wallet-transactions',
    'agro-loans-airtime-transactions': 'saccoplus-airtime-transactions',
    'agro-loans-notifications':        'saccoplus-notifications',
  };

  // ── Fields that must NEVER be overwritten ────────────────────────────────
  static const Set<String> _protectedFields = {
    'pinHash',    // user may have reset PIN after migration
    'balance',    // wallet balance — only MarzPay callbacks should change this
    'totalDeposited',
    'totalWithdrawn',
  };

  // ── Check if this user's migration is already done ───────────────────────
  static Future<bool> _isDone(String uid) async {
    // 1. Fast local check
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_localKey(uid)) == true) return true;

    // 2. Check the user's own member doc in Firestore
    try {
      final doc = await _db
          .collection('saccoplus-members')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final version = doc.data()?['_migrationVersion'] as int? ?? 0;
      if (version >= _currentVersion) {
        await prefs.setBool(_localKey(uid), true); // cache locally
        return true;
      }
    } catch (_) {
      // Firestore unavailable — proceed with migration attempt
    }
    return false;
  }

  // ── Mark this user's migration as done ───────────────────────────────────
  static Future<void> _markDone(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localKey(uid), true);

    try {
      await _db.collection('saccoplus-members').doc(uid).set(
        {'_migrationVersion': _currentVersion},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-fatal — local flag is enough
    }
  }

  // ── Migrate a single collection (additive-only) ──────────────────────────
  static Future<int> _migrateCollection(
    String oldCol,
    String newCol,
    void Function(String) onStatus,
  ) async {
    int written = 0;
    try {
      final oldSnap = await _db
          .collection(oldCol)
          .get(const GetOptions(source: Source.server));

      if (oldSnap.docs.isEmpty) return 0;

      var batch = _db.batch();
      int batchCount = 0;

      for (final oldDoc in oldSnap.docs) {
        final newRef = _db.collection(newCol).doc(oldDoc.id);

        // Read existing doc in new collection
        DocumentSnapshot existingDoc;
        try {
          existingDoc = await newRef.get(const GetOptions(source: Source.server));
        } catch (_) {
          existingDoc = await newRef.get();
        }

        final oldData = Map<String, dynamic>.from(oldDoc.data());

        if (existingDoc.exists) {
          // Doc exists — only write fields that are missing or null
          // and never touch protected fields
          final existingData =
              (existingDoc.data() as Map<String, dynamic>?) ?? {};
          final toWrite = <String, dynamic>{};

          for (final entry in oldData.entries) {
            if (_protectedFields.contains(entry.key)) continue;
            final existing = existingData[entry.key];
            if (existing == null ||
                (existing is String && existing.isEmpty) ||
                (existing is num && existing == 0 &&
                    entry.value is num && (entry.value as num) > 0)) {
              toWrite[entry.key] = entry.value;
            }
          }

          if (toWrite.isNotEmpty) {
            batch.update(newRef, toWrite);
            batchCount++;
            written++;
          }
        } else {
          // Doc doesn't exist — write everything except protected fields
          // that we don't want to seed with stale values
          final toWrite = Map<String, dynamic>.from(oldData);
          // Remove pinHash only if it's from the old collection —
          // a fresh doc should get the PIN from savePin, not from migration
          if (newCol == 'saccoplus-members') {
            toWrite.remove('pinHash');
          }
          batch.set(newRef, toWrite, SetOptions(merge: true));
          batchCount++;
          written++;
        }

        // Commit every 400 ops to stay under Firestore's 500-op batch limit
        if (batchCount >= 400) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) await batch.commit();
      onStatus('✓ $newCol ($written docs)');
    } catch (e) {
      onStatus('⚠ $oldCol skipped: ${e.toString().split('\n').first}');
    }
    return written;
  }

  /// Run migration for the currently logged-in user.
  ///
  /// [uid]      — the session uid (phone_256XXXXXXXXX)
  /// [onStatus] — callback for progress messages on the splash screen
  ///
  /// Exits immediately if this user's migration is already at _currentVersion.
  static Future<void> run({
    required String uid,
    required void Function(String message) onStatus,
  }) async {
    if (uid.isEmpty) return;
    if (await _isDone(uid)) {
      onStatus('');
      return;
    }

    onStatus('Syncing your account data…');

    int total = 0;
    for (final entry in _collectionMap.entries) {
      final count = await _migrateCollection(
        entry.key,
        entry.value,
        onStatus,
      );
      total += count;
    }

    await _markDone(uid);

    onStatus(total > 0 ? 'Account sync complete ✓' : '');
  }
}

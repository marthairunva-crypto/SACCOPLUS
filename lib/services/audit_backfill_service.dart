import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/constants.dart';
import 'audit_service.dart';

/// One-off tool: creates the audit-trail entries that were never written
/// (or were written to the wrong collection) for teller transactions.
///
/// HOW IT WORKS
///  1. Reads every completed teller transaction (deposit, withdrawal,
///     fixed-deposit maturity) for the current tenant.
///  2. Checks BOTH audit collections (the one the Audit Trail screen reads and
///     the old 'audit_logs') and skips any transaction already covered
///     (matched by transactionId or receiptNumber). Safe to run twice.
///  3. Writes one entry per missing transaction into the collection the Audit
///     Trail screen reads, dated with the ORIGINAL transaction time and
///     attributed to the teller who did it. Entries are flagged
///     `backfilled: true` with `backfilledAt` / `backfilledBy`.
///
/// ALWAYS RUN WITH dryRun: true FIRST and check the numbers.
class AuditBackfillService {
  static const String _legacyCollection = 'audit_logs';

  static const Map<String, String> _actionByType = {
    'deposit': 'TELLER_DEPOSIT',
    'withdrawal': 'TELLER_WITHDRAWAL',
    'fixed_deposit_maturity': 'FIXED_DEPOSIT_MATURED',
  };

  static final _db = FirebaseFirestore.instance;

  /// Returns counts: scanned, alreadyAudited, missing, written.
  /// [since] limits the scan to transactions on/after that date (optional).
  static Future<Map<String, int>> run({
    bool dryRun = true,
    DateTime? since,
  }) async {
    final tenantId = FirebaseService.sessionTenantId;
    final actions = _actionByType.values.toList();

    // 1) Teller transactions
    final txnSnap = await _db
        .collection(AppConstants.tellerTxnCol)
        .where('tenantId', isEqualTo: tenantId)
        .get();

    final txns = txnSnap.docs.where((d) {
      final data = d.data();
      if (!_actionByType.containsKey(data['type'])) return false;
      if (data['status'] != 'completed') return false;
      final ts = (data['timestamp'] as Timestamp?)?.toDate();
      if (ts == null) return false;
      if (since != null && ts.isBefore(since)) return false;
      return true;
    }).toList();

    // 2) Existing audit entries (both collections, both field-name styles)
    final covered = <String>{};

    void collect(Map<String, dynamic> data) {
      final meta = data['meta'] ?? data['metadata'];
      if (meta is Map) {
        final tid = meta['transactionId'];
        final rcpt = meta['receiptNumber'];
        if (tid != null) covered.add(tid.toString());
        if (rcpt != null) covered.add(rcpt.toString());
      }
    }

    final viewerSnap = await _db
        .collection(AuditService.collection)
        .where('action', whereIn: actions)
        .get();
    for (final d in viewerSnap.docs) {
      collect(d.data());
    }

    final legacySnap = await _db
        .collection(_legacyCollection)
        .where('action', whereIn: actions)
        .get();
    for (final d in legacySnap.docs) {
      collect(d.data());
    }

    // 3) Work out what's missing
    final missing = txns.where((d) {
      final receipt = d.data()['receiptNumber']?.toString();
      return !covered.contains(d.id) &&
          !(receipt != null && covered.contains(receipt));
    }).toList()
      ..sort((a, b) => (a.data()['timestamp'] as Timestamp)
          .compareTo(b.data()['timestamp'] as Timestamp));

    var written = 0;

    if (!dryRun && missing.isNotEmpty) {
      // Firestore batches are limited to 500 writes; stay well under.
      const chunk = 400;
      for (var i = 0; i < missing.length; i += chunk) {
        final slice = missing.skip(i).take(chunk);
        final batch = _db.batch();
        for (final d in slice) {
          batch.set(
            _db.collection(AuditService.collection).doc(),
            _buildEntry(d, tenantId),
          );
        }
        await batch.commit();
        written += slice.length;
      }
    }

    print('🧾 AUDIT BACKFILL (${dryRun ? "DRY RUN" : "LIVE"})');
    print('   scanned:        ${txns.length}');
    print('   alreadyAudited: ${txns.length - missing.length}');
    print('   missing:        ${missing.length}');
    print('   written:        $written');

    return {
      'scanned': txns.length,
      'alreadyAudited': txns.length - missing.length,
      'missing': missing.length,
      'written': written,
    };
  }

  /// Builds an entry using the SAME field names AuditService.log() now writes
  /// and getLogs() reads.
  static Map<String, dynamic> _buildEntry(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String tenantId,
  ) {
    final d = doc.data();
    final type = d['type'] as String;
    final action = _actionByType[type]!;
    final ts = d['timestamp'] as Timestamp;

    final tellerName = d['tellerName']?.toString() ?? 'Unknown teller';
    final memberName = d['memberName']?.toString() ?? 'Unknown member';
    final accountType = d['accountType']?.toString() ?? '';
    final amount = (d['amount'] as num?)?.toInt() ?? 0;

    String details;
    Map<String, dynamic> meta;

    if (type == 'fixed_deposit_maturity') {
      final principal = (d['principal'] as num?)?.toInt() ?? 0;
      final interest = (d['interestEarned'] as num?)?.toInt() ?? 0;
      details = 'Teller $tellerName matured fixed deposit for $memberName. '
          'Principal: UGX $principal, Interest: UGX $interest, Total: UGX $amount';
      meta = {
        'fixedDepositId': d['fixedDepositId'],
        'principal': principal,
        'interestEarned': interest,
        'totalPayout': amount,
        'receiptNumber': d['receiptNumber'],
      };
    } else {
      final verb = type == 'deposit' ? 'deposit of' : 'withdrawal of';
      final prep = type == 'deposit' ? 'to' : 'from';
      details = 'Teller $tellerName processed $verb UGX $amount $prep '
          '$memberName ($accountType)';
      meta = {
        'amount': amount,
        'accountType': accountType,
        'transactionId': doc.id,
        'receiptNumber': d['receiptNumber'],
      };
    }

    return {
      'tenantId': tenantId,
      'action': action,
      'description': '$details [backfilled]',
      'actorUid': d['tellerId'] ?? FirebaseService.sessionUid,
      'actorName': tellerName,
      'targetId': d['memberId'],
      'meta': meta,
      // Event time = original transaction time
      'timestamp': ts,
      'timestampLocal': ts.toDate().toIso8601String(),
      'ipAddress': 'N/A',
      // Backfill markers
      'backfilled': true,
      'backfilledAt': FieldValue.serverTimestamp(),
      'backfilledBy': FirebaseService.sessionUid,
    };
  }
}

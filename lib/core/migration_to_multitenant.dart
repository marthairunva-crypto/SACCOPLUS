/// One-time migration to multi-tenant architecture.
/// Run this ONCE from the admin dashboard after deploying the new code.
/// 
/// NOW ALSO: Generates account numbers for existing members without one.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_number_service.dart';
import 'sacco_service.dart';

class MultiTenantMigration {
  static final _db = FirebaseFirestore.instance;
  static const _defaultTenant = 'sacco_001';

  static const _collections = [
    'saccoplus-members',
    'saccoplus-loans',
    'saccoplus-repayments',
    'saccoplus-guarantors',
    'saccoplus-savings',
    'saccoplus-savings-transactions',
    'saccoplus-fixed-deposits',
    'saccoplus-shares',
    'saccoplus-wallets',
    'saccoplus-wallet-transactions',
    'saccoplus-airtime-transactions',
    'saccoplus-notifications',
    'saccoplus-audit-logs',
  ];

  /// Migrate all collections to include tenantId.
  /// Returns a progress stream: {collection, updated, skipped, total}
  static Stream<Map<String, dynamic>> migrate() async* {
    for (final colName in _collections) {
      yield {'collection': colName, 'status': 'starting'};

      try {
        final snap = await _db.collection(colName).get();
        
        if (snap.docs.isEmpty) {
          yield {
            'collection': colName,
            'status': 'complete',
            'updated': 0,
            'skipped': 0,
            'total': 0,
          };
          continue;
        }

        int updated = 0;
        int skipped = 0;
        final batch = _db.batch();
        int batchCount = 0;

        for (final doc in snap.docs) {
          if (doc.data().containsKey('tenantId')) {
            skipped++;
            continue;
          }

          batch.update(doc.reference, {'tenantId': _defaultTenant});
          batchCount++;
          updated++;

          // Firestore batch limit is 500 operations
          if (batchCount >= 400) {
            await batch.commit();
            yield {
              'collection': colName,
              'status': 'progress',
              'updated': updated,
              'skipped': skipped,
              'total': snap.docs.length,
            };
            // Create a new batch
            batchCount = 0;
          }
        }

        // Commit remaining
        if (batchCount > 0) {
          await batch.commit();
        }

        yield {
          'collection': colName,
          'status': 'complete',
          'updated': updated,
          'skipped': skipped,
          'total': snap.docs.length,
        };
      } catch (e) {
        yield {
          'collection': colName,
          'status': 'error',
          'error': e.toString(),
        };
      }
    }

    // Create default SACCO profile
    yield {'collection': 'saccoplus-saccos', 'status': 'starting'};
    try {
      await _createDefaultSaccoProfile();
      yield {
        'collection': 'saccoplus-saccos',
        'status': 'complete',
        'message': 'Default SACCO profile created',
      };
    } catch (e) {
      yield {
        'collection': 'saccoplus-saccos',
        'status': 'error',
        'error': e.toString(),
      };
    }

    yield {'status': 'done', 'message': '🎉 Migration complete!'};
  }

  /// Generate account numbers for all existing members without one.
  /// Call this AFTER the main tenantId migration.
  static Stream<Map<String, dynamic>> generateAccountNumbers() async* {
    yield {'status': 'starting', 'message': 'Generating account numbers for existing members...'};

    try {
      // Get all members across all SACCOs
      final membersSnap = await _db
          .collection('saccoplus-members')
          .where('role', isEqualTo: 'member')
          .get();

      if (membersSnap.docs.isEmpty) {
        yield {'status': 'complete', 'message': 'No members found'};
        return;
      }

      // Group members by tenantId
      final membersByTenant = <String, List<QueryDocumentSnapshot>>{};
      for (final doc in membersSnap.docs) {
        final tid = doc.data()['tenantId'] as String? ?? 'sacco_001';
        membersByTenant.putIfAbsent(tid, () => []).add(doc);
      }

      int totalGenerated = 0;
      int totalSkipped = 0;

      // Process each SACCO's members
      for (final entry in membersByTenant.entries) {
        final tenantId = entry.key;
        final members = entry.value;

        yield {
          'status': 'progress',
          'message': 'Processing $tenantId (${members.length} members)...'
        };

        // Load this SACCO so AccountNumberService generates correct prefix
        await SaccoService.loadById(tenantId);

        final batch = _db.batch();
        int batchCount = 0;
        int generated = 0;
        int skipped = 0;

        for (final doc in members) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Skip if already has account number
          if (data.containsKey('accountNumber') && 
              (data['accountNumber'] as String?)?.isNotEmpty == true) {
            skipped++;
            continue;
          }

          // Generate account number
          final accountNumber = await AccountNumberService.generateNext();
          batch.update(doc.reference, {'accountNumber': accountNumber});
          batchCount++;
          generated++;

          // Commit in batches of 400
          if (batchCount >= 400) {
            await batch.commit();
            yield {
              'status': 'progress',
              'message': '$tenantId: generated $generated account numbers...'
            };
            batchCount = 0;
          }
        }

        // Commit remaining
        if (batchCount > 0) {
          await batch.commit();
        }

        totalGenerated += generated;
        totalSkipped += skipped;

        yield {
          'status': 'sacco_complete',
          'tenantId': tenantId,
          'generated': generated,
          'skipped': skipped,
        };
      }

      yield {
        'status': 'complete',
        'totalGenerated': totalGenerated,
        'totalSkipped': totalSkipped,
        'message': '✅ Account numbers generated!',
      };
    } catch (e) {
      yield {
        'status': 'error',
        'error': e.toString(),
        'message': 'Failed to generate account numbers',
      };
    }
  }

  static Future<void> _createDefaultSaccoProfile() async {
    final saccoRef = _db.collection('saccoplus-saccos').doc(_defaultTenant);
    final saccoDoc = await saccoRef.get();

    if (saccoDoc.exists && saccoDoc.data()!.containsKey('tenantId')) {
      return; // Already exists
    }

    // Try to migrate from legacy 'config' doc
    final configDoc = await _db.collection('saccoplus-saccos').doc('config').get();
    final base = configDoc.exists ? configDoc.data()! : <String, dynamic>{};

    await saccoRef.set({
      'tenantId': _defaultTenant,
      'saccoName': base['name'] ?? base['saccoName'] ?? 'SACCOPLUS Pro',
      'shortName': base['shortName'] ?? '',
      'tagline': base['tagline'] ?? 'Banking Made Simple',
      'registrationNo': base['regNo'] ?? base['registrationNo'] ?? '',
      'logoUrl': base['logoUrl'] ?? '',
      'primaryColor': base['primaryColor'] ?? 0xFF0D2B6B,
      'accentColor': base['accentColor'] ?? 0xFFF47920,
      'phone': base['phone'] ?? '',
      'email': base['email'] ?? '',
      'address': base['address'] ?? '',
      'website': base['website'] ?? '',
      'country': base['country'] ?? 'UG',
      'currency': base['currency'] ?? 'UGX',
      'minLoan': base['minLoan'] ?? 50000,
      'maxLoan': base['maxLoan'] ?? 10000000,
      'loanRate': base['loanRate'] ?? 18.0,
      'penaltyRate': base['penaltyRate'] ?? 5.0,
      'minSavings': base['minSavings'] ?? 10000,
      'savingsRate': base['savingsRate'] ?? 8.0,
      'shareValue': base['shareValue'] ?? 1000,
      'minShares': base['minShares'] ?? 1,
      'status': 'active',
      'migratedFromConfig': configDoc.exists,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

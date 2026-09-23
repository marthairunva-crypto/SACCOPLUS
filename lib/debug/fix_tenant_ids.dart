import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One-time script to add tenantId to all existing documents
class TenantIdFixer {
  static final _db = FirebaseFirestore.instance;
  static const _tenantId = 'saccoplus';

  /// Check and fix missing tenantIds in all collections
  static Future<String> fixAllCollections() async {
    final results = StringBuffer();
    results.writeln('🔧 Adding tenantId to existing documents...\n');

    final collections = [
      'saccoplus-loans',
      'saccoplus-repayments',
      'saccoplus-savings',
      'saccoplus-shares',
      'saccoplus-members',
      'saccoplus-guarantors',
      'saccoplus-savings-transactions',
      'saccoplus-wallet-transactions',
      'saccoplus-wallets',
      'saccoplus-notifications',
      'saccoplus-audit-logs',
      'saccoplus-fixed-deposits',
      'saccoplus-dividends',
    ];

    int grandTotal = 0;

    for (final collectionName in collections) {
      try {
        // Get all documents without tenantId field
        final snapshot = await _db.collection(collectionName).get();
        
        if (snapshot.docs.isEmpty) {
          results.writeln('📂 $collectionName: empty (skipped)');
          continue;
        }

        final batch = _db.batch();
        int batchCount = 0;
        int fixed = 0;
        int skipped = 0;

        for (final doc in snapshot.docs) {
          final data = doc.data();
          
          // Check if tenantId exists and matches
          final existingTenantId = data['tenantId'] as String?;
          
          if (existingTenantId == null || existingTenantId.isEmpty) {
            // Add tenantId
            batch.update(doc.reference, {'tenantId': _tenantId});
            batchCount++;
            fixed++;

            // Firestore batch limit is 500
            if (batchCount >= 400) {
              await batch.commit();
              batchCount = 0;
            }
          } else if (existingTenantId != _tenantId) {
            // Wrong tenantId - update it
            batch.update(doc.reference, {'tenantId': _tenantId});
            batchCount++;
            fixed++;

            if (batchCount >= 400) {
              await batch.commit();
              batchCount = 0;
            }
          } else {
            skipped++;
          }
        }

        // Commit remaining batch
        if (batchCount > 0) {
          await batch.commit();
        }

        grandTotal += fixed;

        if (fixed > 0) {
          results.writeln('✅ $collectionName: fixed $fixed, skipped $skipped');
        } else {
          results.writeln('✓  $collectionName: all good ($skipped docs)');
        }
      } catch (e) {
        results.writeln('❌ $collectionName: ERROR - $e');
      }
    }

    results.writeln('\n' + '='*50);
    if (grandTotal > 0) {
      results.writeln('✅ DONE! Fixed $grandTotal documents total.');
      results.writeln('🔄 Restart your app to see the data.');
    } else {
      results.writeln('✅ All documents already have correct tenantId!');
    }

    return results.toString();
  }

  /// Show a dialog with the fix results
  static Future<void> showFixDialog(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fixing tenantId fields...'),
          ],
        ),
      ),
    );

    try {
      final result = await fixAllCollections();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show results
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('TenantId Fix Complete'),
            content: SingleChildScrollView(
              child: Text(
                result,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Show error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to fix tenantIds: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }
}

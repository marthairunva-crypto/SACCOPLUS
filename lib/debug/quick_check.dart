import 'package:cloud_firestore/cloud_firestore.dart';

/// Quick check to see what collections exist and what data is in them
class QuickCheck {
  static final _db = FirebaseFirestore.instance;

  static Future<void> checkCollections() async {
    print('\n' + '='*60);
    print('🔍 QUICK FIREBASE CHECK');
    print('='*60);

    final collectionsToCheck = [
      'saccoplus-loans',
      'saccoplus-repayments',
      'saccoplus-savings',
      'saccoplus-shares',
      'saccoplus-members',
      'loans',
      'repayments',
      'savings',
      'shares',
      'members',
    ];

    for (final collectionName in collectionsToCheck) {
      try {
        // Get ALL documents, not just 1
        final snapshot = await _db.collection(collectionName).get();
        
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final hasTenantId = data.containsKey('tenantId');
          final tenantIdValue = data['tenantId'];
          
          print('✅ $collectionName: ${snapshot.docs.length} doc(s)');
          print('   Has tenantId: $hasTenantId');
          if (hasTenantId) {
            print('   tenantId value: $tenantIdValue');
          }
          print('   Sample keys: ${data.keys.take(5).join(', ')}');
        } else {
          print('📭 $collectionName: EMPTY');
        }
      } catch (e) {
        print('❌ $collectionName: ERROR - $e');
      }
    }

    print('='*60 + '\n');
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Flutter test wrapper to fix the Nov 17 2026 internal transfer transaction
/// that was incorrectly recorded as revenue.
/// 
/// Run with: flutter test test/migrations/fix_internal_transfer_test.dart
/// 
/// This is idempotent - safe to run multiple times.

void main() {
  setUpAll(() async {
    // Initialize Firebase for testing
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
  });

  test('Fix rct2026111797336 - change revenue to internal_transfer', () async {
    final firestore = FirebaseFirestore.instance;
    final receiptNumber = 'rct2026111797336';
    
    print('🔍 Searching for transaction: $receiptNumber');
    
    // Find the transaction
    final querySnapshot = await firestore
        .collection('teller-transactions')
        .where('receiptNumber', isEqualTo: receiptNumber)
        .limit(1)
        .get();
    
    if (querySnapshot.docs.isEmpty) {
      print('❌ Transaction $receiptNumber not found!');
      print('   Either it doesn\'t exist or was already fixed.');
      return;
    }
    
    final doc = querySnapshot.docs.first;
    final data = doc.data();
    
    print('✅ Found transaction:');
    print('   Document ID: ${doc.id}');
    print('   Current type: ${data['type']}');
    print('   Amount: ${data['amount']}');
    print('   Date: ${data['timestamp']?.toDate()}');
    
    // Check if already fixed
    if (data['type'] == 'internal_transfer') {
      print('✅ Already fixed! Type is already "internal_transfer"');
      print('   Direction: ${data['direction']}');
      return;
    }
    
    // Apply the fix
    print('🔧 Applying fix...');
    await doc.reference.update({
      'type': 'internal_transfer',
      'direction': 'in',
      'fixedAt': FieldValue.serverTimestamp(),
      'fixNote': 'Changed from revenue to internal_transfer - bank->cash is not income',
    });
    
    print('✅ Fix applied successfully!');
    print('');
    print('📊 Next steps:');
    print('   1. Check Income Report (Nov 2026) - should drop by 1M UGX');
    print('   2. Check Till session (Nov 17) - should show "Cash from bank (internal transfer)"');
    print('   3. Test new "Cash from bank" button in Teller Center > General ledger');
  });
}

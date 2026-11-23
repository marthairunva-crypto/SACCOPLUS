// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

/// One-time migration script to fix the Nov 17, 2026 transaction (rct2026111797336)
/// that was incorrectly recorded as revenue instead of internal_transfer.
/// 
/// This transaction was UGX 1,000,000 "Cash from bank" that inflated income reports.
/// 
/// SAFE TO RUN MULTIPLE TIMES: Uses Firestore transactions and only updates if needed.

void main() async {
  print('═══════════════════════════════════════════════════════════════');
  print('Fix Internal Transfer - rct2026111797336');
  print('═══════════════════════════════════════════════════════════════\n');

  // WARNING: This script requires Firebase initialization
  // Run it from Flutter test environment or add Firebase setup here
  
  final db = FirebaseFirestore.instance;
  
  // Find the transaction by receipt number
  print('🔍 Searching for transaction rct2026111797336...');
  
  final querySnapshot = await db
      .collection('teller-transactions')
      .where('receiptNumber', isEqualTo: 'rct2026111797336')
      .limit(1)
      .get();
  
  if (querySnapshot.docs.isEmpty) {
    print('❌ Transaction rct2026111797336 not found!');
    print('   This may have already been fixed or deleted.');
    return;
  }
  
  final doc = querySnapshot.docs.first;
  final data = doc.data();
  
  print('✅ Found transaction:');
  print('   ID: ${doc.id}');
  print('   Type: ${data['type']}');
  print('   Amount: UGX ${data['amount']}');
  print('   Date: ${(data['timestamp'] as Timestamp?)?.toDate()}');
  print('   Description: ${data['description'] ?? data['source'] ?? '(none)'}');
  print('   Current type: ${data['type']}\n');
  
  // Check if already fixed
  if (data['type'] == 'internal_transfer') {
    print('✅ Transaction is already marked as internal_transfer.');
    print('   No changes needed. Migration complete!');
    return;
  }
  
  // Verify this is the correct transaction (Nov 17, 2026, UGX 1,000,000)
  final amount = (data['amount'] as num?)?.toInt() ?? 0;
  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
  
  if (amount != 1000000) {
    print('⚠️  WARNING: Amount is $amount, expected 1,000,000');
    print('   Please verify this is the correct transaction before proceeding.');
    return;
  }
  
  if (timestamp == null || 
      timestamp.year != 2026 || 
      timestamp.month != 11 || 
      timestamp.day != 17) {
    print('⚠️  WARNING: Date is ${timestamp}, expected Nov 17, 2026');
    print('   Please verify this is the correct transaction before proceeding.');
    return;
  }
  
  print('📝 Updating transaction to type: internal_transfer...');
  
  // Update the transaction
  try {
    await db.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(doc.reference);
      
      if (!docSnapshot.exists) {
        throw Exception('Transaction was deleted during update');
      }
      
      final currentData = docSnapshot.data()!;
      
      // Don't update if already fixed (race condition protection)
      if (currentData['type'] == 'internal_transfer') {
        print('   (Already updated by another process)');
        return;
      }
      
      // Build update payload
      final updates = <String, dynamic>{
        'type': 'internal_transfer',
        'direction': 'in', // Cash from bank
        
        // Add audit trail
        'migration': {
          'migratedAt': FieldValue.serverTimestamp(),
          'migratedBy': 'fix_internal_transfer_script',
          'reason': 'Reclassified from revenue to internal transfer',
          'oldType': currentData['type'],
          'oldSource': currentData['source'],
          'oldDescription': currentData['description'],
        },
      };
      
      // Update description if it was just the source/category
      if (currentData['description'] == null || 
          currentData['description'] == '' ||
          currentData['description'] == 'Cash from bank') {
        updates['description'] = 'Cash from bank (internal transfer)';
      }
      
      transaction.update(doc.reference, updates);
      
      print('✅ Transaction updated successfully!');
    });
    
    print('\n═══════════════════════════════════════════════════════════════');
    print('Migration Complete!');
    print('═══════════════════════════════════════════════════════════════');
    print('');
    print('Changes made:');
    print('  • type: revenue → internal_transfer');
    print('  • direction: in (cash from bank)');
    print('  • Added migration audit trail');
    print('');
    print('What to verify:');
    print('  1. Income Report (November 2026) should decrease by UGX 1,000,000');
    print('  2. Till session for Nov 17 should still show the cash movement');
    print('  3. Trial Balance should still balance');
    print('  4. Member statements should not show this transaction');
    print('');
    print('Safe to run again: This script is idempotent.');
    
  } catch (e, stackTrace) {
    print('\n❌ ERROR during migration:');
    print('   $e');
    print('\n   Stack trace:');
    print('   $stackTrace');
    print('\n   The original transaction was NOT modified.');
    rethrow;
  }
}

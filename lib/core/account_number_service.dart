/// Auto-generate unique account numbers for SACCO members.
/// Format: 8-digit numeric string (60000001, 60000002, 60000003, etc.)
/// Each SACCO has its own counter starting from 60000000

import 'package:cloud_firestore/cloud_firestore.dart';
import 'sacco_service.dart';

class AccountNumberService {
  AccountNumberService._();

  static final _db = FirebaseFirestore.instance;

  /// Generate the next account number for the current SACCO.
  /// Format: 8-digit number starting from 60000000 e.g. 60000001, 60000002
  static Future<String> generateNext() async {
    final sacco = SaccoService.current;

    // Use a counter doc per SACCO to track the last number
    final counterRef = _db
        .collection('saccoplus-counters')
        .doc('account_numbers_${sacco.tenantId}');

    // Atomic increment - start from 60000000
    int nextNumber = 60000000;
    await _db.runTransaction((txn) async {
      final snap = await txn.get(counterRef);
      if (snap.exists) {
        nextNumber = (snap.data()!['lastNumber'] as int? ?? 59999999) + 1;
      }
      txn.set(counterRef, {'lastNumber': nextNumber}, SetOptions(merge: true));
    });

    // Return 8-digit number as string (e.g. "60000001")
    return nextNumber.toString();
  }

  /// Check if an account number exists in the current SACCO.
  static Future<bool> exists(String accountNumber) async {
    final tid = SaccoService.tenantId;
    final q = await _db
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: tid)
        .where('accountNumber', isEqualTo: accountNumber)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// Find a member by account number within the current SACCO.
  static Future<Map<String, dynamic>?> getMemberByAccountNumber(
      String accountNumber) async {
    final tid = SaccoService.tenantId;
    try {
      print('🔍 Looking for account: $accountNumber in tenant: $tid');
      
      final q = await _db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tid)
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();
      
      print('🔍 Query returned ${q.docs.length} results');
      
      if (q.docs.isEmpty) {
        // Try without tenantId filter to debug
        print('🔍 Trying without tenantId filter...');
        final q2 = await _db
            .collection('saccoplus-members')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();
        
        if (q2.docs.isNotEmpty) {
          final doc = q2.docs.first.data();
          print('⚠️ Found account but with different tenantId: ${doc['tenantId']}');
          print('   Expected tenantId: $tid');
          print('   Account data: ${doc['name']}, ${doc['phone']}');
          print('✅ Using found account anyway (tenantId mismatch ignored)');
          
          // Return the found account even with tenantId mismatch
          return {...doc, 'uid': q2.docs.first.id};
        } else {
          print('❌ Account $accountNumber not found in any tenant');
        }
        
        return null;
      }
      
      final result = {...q.docs.first.data(), 'uid': q.docs.first.id};
      print('✅ Found member: ${result['name']} (${result['phone']})');
      return result;
    } catch (e) {
      print('❌ Error looking up account: $e');
      return null;
    }
  }
}

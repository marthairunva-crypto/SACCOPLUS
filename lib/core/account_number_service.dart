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
      final q = await _db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tid)
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return {...q.docs.first.data(), 'uid': q.docs.first.id};
    } catch (_) {
      return null;
    }
  }
}

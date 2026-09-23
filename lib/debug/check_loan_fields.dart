import 'package:cloud_firestore/cloud_firestore.dart';

/// Check if loan documents have the required fields for queries
class LoanFieldChecker {
  static final _db = FirebaseFirestore.instance;

  static Future<void> checkLoanFields() async {
    print('\n' + '='*60);
    print('🔍 CHECKING LOAN DOCUMENT FIELDS');
    print('='*60);

    try {
      final snapshot = await _db.collection('saccoplus-loans').get();
      
      print('Total loans found: ${snapshot.docs.length}\n');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        
        print('Loan ID: $id');
        print('  Has tenantId: ${data.containsKey('tenantId')}');
        print('  tenantId value: ${data['tenantId']}');
        print('  Has createdAt: ${data.containsKey('createdAt')}');
        print('  createdAt type: ${data['createdAt']?.runtimeType}');
        print('  createdAt value: ${data['createdAt']}');
        print('  Has status: ${data.containsKey('status')}');
        print('  status value: ${data['status']}');
        print('  All keys: ${data.keys.toList()}');
        print('');
      }
      
      print('='*60 + '\n');
    } catch (e) {
      print('❌ ERROR: $e');
      print('='*60 + '\n');
    }
  }
}

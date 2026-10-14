import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/sacco_service.dart';

/// Diagnose data issues and show what's in Firebase
class DataDiagnostics {
  static final _db = FirebaseFirestore.instance;
  static final _tenantId = SaccoService.current.tenantId;

  /// Check all collections and show counts
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    print('\n🔍 Running Full Data Diagnostics...\n');
    print('Tenant ID: $_tenantId\n');

    final results = <String, dynamic>{};

    // Check loans
    final loansAll = await _db.collection('saccoplus-loans').get();
    final loansForTenant = await _db.collection('saccoplus-loans').where('tenantId', isEqualTo: _tenantId).get();
    
    print('📊 LOANS:');
    print('  Total in database: ${loansAll.docs.length}');
    print('  For this tenant: ${loansForTenant.docs.length}');
    
    if (loansForTenant.docs.isNotEmpty) {
      final sample = loansForTenant.docs.first.data();
      print('  Sample loan status: ${sample['status']}');
      print('  Sample loan amount: ${sample['amount']}');
      print('  Has tenantId: ${sample.containsKey('tenantId')}');
      
      // Count by status
      final statuses = <String, int>{};
      for (var doc in loansForTenant.docs) {
        final status = doc['status']?.toString() ?? 'null';
        statuses[status] = (statuses[status] ?? 0) + 1;
      }
      print('  Status breakdown: $statuses');
    }
    
    results['loans'] = {
      'total': loansAll.docs.length,
      'forTenant': loansForTenant.docs.length,
    };

    // Check members
    final membersAll = await _db.collection('saccoplus-members').get();
    final membersForTenant = await _db.collection('saccoplus-members').where('tenantId', isEqualTo: _tenantId).get();
    
    print('\n👥 MEMBERS:');
    print('  Total in database: ${membersAll.docs.length}');
    print('  For this tenant: ${membersForTenant.docs.length}');
    
    if (membersForTenant.docs.isNotEmpty) {
      final sample = membersForTenant.docs.first.data();
      print('  Sample member name: ${sample['name']}');
      print('  Has tenantId: ${sample.containsKey('tenantId')}');
    }
    
    results['members'] = {
      'total': membersAll.docs.length,
      'forTenant': membersForTenant.docs.length,
    };

    // Check audit logs
    final auditLogs = await _db.collection('saccoplus-audit-logs').limit(10).get();
    
    print('\n📝 AUDIT LOGS:');
    print('  Total (sample): ${auditLogs.docs.length}');
    
    if (auditLogs.docs.isNotEmpty) {
      final sample = auditLogs.docs.first.data();
      print('  Sample action: ${sample['action']}');
      print('  Sample description: ${sample['description']}');
    }
    
    results['auditLogs'] = {
      'sample': auditLogs.docs.length,
    };

    // Check repayments
    final repaymentsAll = await _db.collection('saccoplus-repayments').get();
    final repaymentsForTenant = await _db.collection('saccoplus-repayments').where('tenantId', isEqualTo: _tenantId).get();
    
    print('\n💰 REPAYMENTS:');
    print('  Total in database: ${repaymentsAll.docs.length}');
    print('  For this tenant: ${repaymentsForTenant.docs.length}');
    
    results['repayments'] = {
      'total': repaymentsAll.docs.length,
      'forTenant': repaymentsForTenant.docs.length,
    };

    // Check savings
    final savingsAll = await _db.collection('saccoplus-savings').get();
    final savingsForTenant = await _db.collection('saccoplus-savings').where('tenantId', isEqualTo: _tenantId).get();
    
    print('\n💵 SAVINGS:');
    print('  Total in database: ${savingsAll.docs.length}');
    print('  For this tenant: ${savingsForTenant.docs.length}');
    
    results['savings'] = {
      'total': savingsAll.docs.length,
      'forTenant': savingsForTenant.docs.length,
    };

    // Check shares
    final sharesAll = await _db.collection('saccoplus-shares').get();
    final sharesForTenant = await _db.collection('saccoplus-shares').where('tenantId', isEqualTo: _tenantId).get();
    
    print('\n📈 SHARES:');
    print('  Total in database: ${sharesAll.docs.length}');
    print('  For this tenant: ${sharesForTenant.docs.length}');
    
    results['shares'] = {
      'total': sharesAll.docs.length,
      'forTenant': sharesForTenant.docs.length,
    };

    print('\n✅ Diagnostics Complete!\n');
    print('📋 SUMMARY:');
    print('  If "For this tenant" shows 0 but "Total" shows data,');
    print('  then your data is missing tenantId fields.');
    print('  Run fixMissingTenantIds() to fix this.\n');

    return results;
  }

  /// Fix documents that are missing tenantId
  static Future<void> fixMissingTenantIds() async {
    print('\n🔧 Fixing missing tenantId fields...\n');

    final collections = [
      'saccoplus-loans',
      'saccoplus-repayments',
      'saccoplus-savings',
      'saccoplus-shares',
      'saccoplus-members'
    ];
    int totalFixed = 0;

    for (var collectionName in collections) {
      final snapshot = await _db.collection(collectionName).get();
      int fixed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (!data.containsKey('tenantId') || data['tenantId'] == null) {
          await doc.reference.update({'tenantId': _tenantId});
          fixed++;
        }
      }

      if (fixed > 0) {
        print('✅ Fixed $fixed documents in $collectionName');
        totalFixed += fixed;
      }
    }

    if (totalFixed == 0) {
      print('✅ All documents already have tenantId!');
    } else {
      print('\n✅ Fixed $totalFixed total documents!');
      print('🔄 Refresh your app to see the data.');
    }
  }
}

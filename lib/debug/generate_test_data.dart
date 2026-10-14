import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/audit_service.dart';
import '../core/sacco_service.dart';
import '../core/constants.dart';

/// Generate test data for debugging - ONLY FOR DEVELOPMENT
class TestDataGenerator {
  static final _db = FirebaseFirestore.instance;
  static final _tenantId = SaccoService.current.tenantId;

  /// Generate sample audit logs
  static Future<void> generateAuditLogs() async {
    print('🔧 Generating test audit logs...');
    
    final actions = [
      {'action': 'LOAN_APPROVED', 'desc': 'Loan approved for member'},
      {'action': 'LOAN_REJECTED', 'desc': 'Loan rejected - insufficient documentation'},
      {'action': 'KYC_APPROVED', 'desc': 'KYC verification approved'},
      {'action': 'SAVINGS_DEPOSIT', 'desc': 'Savings deposit processed'},
      {'action': 'SHARE_PURCHASE', 'desc': 'Share purchase approved'},
      {'action': 'TELLER_DEPOSIT', 'desc': 'Teller deposit processed'},
      {'action': 'TELLER_WITHDRAWAL', 'desc': 'Teller withdrawal processed'},
    ];

    for (var i = 0; i < 20; i++) {
      final action = actions[i % actions.length];
      await AuditService.log(
        action: action['action']!,
        description: '${action['desc']} (Test #${i + 1})',
        targetId: 'test-target-$i',
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('✅ Generated 20 test audit logs');
  }

  /// Generate sample monthly transactions
  static Future<void> generateMonthlyData() async {
    print('🔧 Generating test monthly data...');
    
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);

    // Create test loans
    for (var i = 0; i < 5; i++) {
      await _db.collection(AppConstants.loansCol).add({
        'tenantId': _tenantId,
        'amount': 100000 + (i * 50000),
        'status': 'approved',
        'farmerName': 'Test Member $i',
        'farmerId': 'test-member-$i',
        'createdAt': thisMonth.add(Duration(days: i * 2)),
        'totalRepaid': 0,
      });
    }

    // Create test repayments
    for (var i = 0; i < 8; i++) {
      await _db.collection(AppConstants.repaymentsCol).add({
        'tenantId': _tenantId,
        'amount': 20000 + (i * 5000),
        'date': thisMonth.add(Duration(days: i * 3)),
        'farmerId': 'test-member-${i % 5}',
      });
    }

    // Create test savings
    for (var i = 0; i < 10; i++) {
      await _db.collection(AppConstants.savingsCol).add({
        'tenantId': _tenantId,
        'amount': 10000 + (i * 2000),
        'type': 'deposit',
        'status': 'approved',
        'timestamp': thisMonth.add(Duration(days: i * 2)),
        'farmerId': 'test-member-${i % 5}',
      });
    }

    print('✅ Generated test monthly data: 5 loans, 8 repayments, 10 savings');
  }

  /// Generate all test data
  static Future<void> generateAll() async {
    print('\n🚀 Starting test data generation...\n');
    
    try {
      await generateAuditLogs();
      await generateMonthlyData();
      
      print('\n✅ All test data generated successfully!');
      print('📊 Check your Firebase console to verify');
      print('🔄 Hot reload your app to see the data\n');
    } catch (e) {
      print('❌ Error generating test data: $e');
    }
  }

  /// Clear all test data
  static Future<void> clearTestData() async {
    print('🧹 Clearing test data...');
    
    // Delete audit logs
    final auditLogs = await _db
        .collection('saccoplus-audit-logs')
        .where('description', isGreaterThanOrEqualTo: 'Test #')
        .get();
    
    for (var doc in auditLogs.docs) {
      await doc.reference.delete();
    }

    print('✅ Test data cleared');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../services/charge_service.dart';

/// One-time script to seed default charge types
/// Run this once per tenant to create the standard charge types
class SeedChargeTypes {
  static final _db = FirebaseFirestore.instance;

  static Future<void> run() async {
    try {
      final tenantId = FirebaseService.sessionTenantId;
      
      if (tenantId.isEmpty) {
        print('❌ Error: No tenant ID found. Please log in first.');
        return;
      }

      print('🌱 Seeding default charge types for tenant: $tenantId');
      print('');

      // Check if charge types already exist
      final existing = await _db
          .collection('charge_types')
          .where('tenantId', isEqualTo: tenantId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        print('⚠️  Charge types already exist for this tenant.');
        print('   Found ${existing.docs.length} existing charge type(s).');
        print('');
        print('❓ Do you want to seed anyway? This will add more charge types.');
        print('   (You can manually delete duplicates in Firestore Console)');
        print('');
        // In production, you'd prompt the user here
        // For now, we'll proceed
      }

      await ChargeService.seedDefaultChargeTypes(tenantId);

      print('');
      print('✅ Default charge types seeded successfully!');
      print('');
      print('📋 Created charge types:');
      print('   1. Late Payment Fee (2% of overdue instalment)');
      print('   2. Demand Letter Fee (UGX 50,000 flat)');
      print('   3. Recovery Fee (5% of arrears)');
      print('   4. Legal Fee (manual amount)');
      print('   5. Rescheduling Fee (UGX 100,000 flat)');
      print('');
      print('🎯 You can now add charges to loans!');
      print('   Go to: Loan Details → More actions → Add charge');
      print('');
      
    } catch (e) {
      print('❌ Error seeding charge types: $e');
    }
  }
}

/// Quick script to set subscription for MBADIFA SACCO
/// 
/// Usage: dart run scripts/set_subscription.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  print('═══════════════════════════════════════════════════════');
  print('           SET MBADIFA SUBSCRIPTION                     ');
  print('═══════════════════════════════════════════════════════\n');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;

  // Set subscription for MBADIFA
  final tenantId = 'mbadifa'; // Change if your SACCO ID is different
  final expiryDate = DateTime(2026, 11, 29, 23, 59, 59); // Nov 29, 2026
  
  print('Setting subscription for: $tenantId');
  print('Expiry date: ${expiryDate.toString()}');
  print('Plan: Growth');
  print('Status: active\n');

  try {
    await db.collection('saccoplus-saccos').doc(tenantId).set({
      'subscriptionEnd': Timestamp.fromDate(expiryDate),
      'subscriptionPlan': 'Growth',
      'subscriptionStatus': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ SUCCESS! Subscription set for $tenantId');
    print('\n📋 Details:');
    print('   • Expires: November 29, 2026 at 11:59 PM');
    print('   • Plan: Growth (350,000 UGX/month, 500 members)');
    print('   • Status: Active');
    print('\n⏰ Timeline:');
    print('   • Nov 22: Warning banner appears (7 days before)');
    print('   • Nov 27: SMS sent to admins/tellers (2 days before)');
    print('   • Nov 29: Last day of access');
    print('   • Nov 30: System locks 🔒');
    print('\n💡 Restart your Flutter app to see the changes!');
  } catch (e) {
    print('❌ ERROR: Failed to set subscription');
    print('   $e');
    print('\n💡 You may need to set it manually in Firebase Console');
  }

  print('\n═══════════════════════════════════════════════════════');
}

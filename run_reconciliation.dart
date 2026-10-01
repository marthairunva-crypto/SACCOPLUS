#!/usr/bin/env dart
/// Command-line script to run savings reconciliation
/// Usage: dart run_reconciliation.dart

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'lib/scripts/reconcile_savings.dart';

void main() async {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║        MBADIFA SACCO - Savings Reconciliation Tool          ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
  
  try {
    // Initialize Firebase
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully\n');
    
    // Create reconciliation script instance
    final script = SavingsReconciliationScript();
    
    // Run reconciliation
    print('🚀 Starting reconciliation process...\n');
    final results = await script.reconcileAllMembers();
    
    if (results['success'] == true) {
      print('\n✅ RECONCILIATION COMPLETED SUCCESSFULLY');
      print('   You can now close this window.');
    } else {
      print('\n❌ RECONCILIATION FAILED');
      print('   Error: ${results['error']}');
    }
    
  } catch (e, stackTrace) {
    print('\n❌ FATAL ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}

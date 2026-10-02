#!/usr/bin/env dart
/// EMERGENCY: Restore savings balances

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'lib/scripts/restore_savings_balances.dart';

void main() async {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║          🚨 EMERGENCY BALANCE RESTORATION 🚨                ║');
  print('╚══════════════════════════════════════════════════════════════╝');
  print('');
  
  try {
    // Initialize Firebase
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized\n');
    
    // Create restoration script instance
    final script = RestoreSavingsBalances();
    
    // Run restoration
    print('🚀 Starting restoration...\n');
    await script.restoreAllBalances();
    
    print('\n✅ RESTORATION COMPLETED');
    print('   Please check the app now.');
    
  } catch (e, stackTrace) {
    print('\n❌ FATAL ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Quick script to create test SACCO and member data
void main() async {
  print('🔥 Setting up test data...');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  final timestamp = FieldValue.serverTimestamp();
  
  // 1. Create Test SACCO
  final saccoId = 'sacco_test_${DateTime.now().millisecondsSinceEpoch}';
  print('\n📋 Creating SACCO: $saccoId');
  
  await firestore.collection('saccoplus-saccos').doc(saccoId).set({
    'saccoId': saccoId,
    'name': 'Test SACCO',
    'contactEmail': 'admin@testsacco.com',
    'contactPhone': '0700000000',
    'address': 'Kampala, Uganda',
    'registrationNumber': 'TST001',
    'status': 'active',
    'createdAt': timestamp,
    'updatedAt': timestamp,
    'settings': {
      'currency': 'UGX',
      'loanInterestRate': 10.0,
      'savingsInterestRate': 5.0,
      'minLoanAmount': 100000,
      'maxLoanAmount': 10000000,
    },
  });
  
  // 2. Create Admin User
  final adminUid = 'admin_${DateTime.now().millisecondsSinceEpoch}';
  print('👤 Creating Admin: $adminUid');
  
  await firestore.collection('saccoplus-users').doc(adminUid).set({
    'uid': adminUid,
    'tenantId': saccoId,
    'phone': '+256700000000',
    'email': 'admin@test.com',
    'firstName': 'Admin',
    'lastName': 'User',
    'role': 'admin',
    'accountNumber': '60000001',
    'pin': '1234', // Hashed in production
    'status': 'active',
    'createdAt': timestamp,
    'profileImageUrl': '',
    'nationalId': 'CM00000000000',
  });
  
  // 3. Create Test Member
  final memberUid = 'phone_+256700000001';
  print('👤 Creating Member: $memberUid');
  
  await firestore.collection('saccoplus-users').doc(memberUid).set({
    'uid': memberUid,
    'tenantId': saccoId,
    'phone': '+256700000001',
    'email': 'member@test.com',
    'firstName': 'John',
    'lastName': 'Doe',
    'role': 'member',
    'accountNumber': '60000002',
    'pin': '1234',
    'status': 'active',
    'createdAt': timestamp,
    'profileImageUrl': '',
    'nationalId': 'CM00000000001',
  });
  
  // 4. Create Wallet for Member
  print('💰 Creating Wallet...');
  
  await firestore.collection('saccoplus-wallets').doc(memberUid).set({
    'uid': memberUid,
    'tenantId': saccoId,
    'balance': 500000, // 500,000 UGX
    'totalDeposited': 500000,
    'totalWithdrawn': 0,
    'lastTransactionAt': timestamp,
    'createdAt': timestamp,
    'updatedAt': timestamp,
  });
  
  // 5. Create Sample Transaction
  print('📝 Creating Transaction...');
  
  await firestore.collection('saccoplus-wallet-transactions').add({
    'uid': memberUid,
    'tenantId': saccoId,
    'type': 'deposit',
    'amount': 500000,
    'balanceBefore': 0,
    'balanceAfter': 500000,
    'description': 'Initial deposit',
    'status': 'completed',
    'createdAt': timestamp,
    'reference': 'DEP${DateTime.now().millisecondsSinceEpoch}',
  });
  
  print('\n✅ Test data created successfully!');
  print('\n📱 Login Credentials:');
  print('   Admin: 0700000000 / PIN: 1234');
  print('   Member: 0700000001 / PIN: 1234');
  print('   Account: 60000002');
  print('\n💰 Member Wallet Balance: 500,000 UGX');
  
  exit(0);
}

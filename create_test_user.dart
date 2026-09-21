import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  print('Creating test user...');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final db = FirebaseFirestore.instance;
  
  // Test user data
  final testUser = {
    'uid': 'phone_+256700000001',
    'phone': '+256700000001',
    'firstName': 'Test',
    'lastName': 'User',
    'email': 'test@saccoplus.com',
    'role': 'member',
    'accountNumber': '60000001',
    'pin': '1234', // Plain text for testing (hash in production!)
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
  };
  
  await db.collection('users').doc('phone_+256700000001').set(testUser);
  
  // Create wallet
  await db.collection('wallets').doc('phone_+256700000001').set({
    'uid': 'phone_+256700000001',
    'balance': 500000,
    'totalDeposited': 500000,
    'totalWithdrawn': 0,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  print('✅ Test user created!');
  print('Phone: 0700000001');
  print('Account: 60000001');
  print('PIN: 1234');
  print('Wallet: 500,000 UGX');
}

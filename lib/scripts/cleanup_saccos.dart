/// Delete only SACCO records (keep members, loans, etc.)
/// Run: dart lib/scripts/cleanup_saccos.dart

void main() {
  print('🗑️  DELETE SACCOS ONLY\n');
  print('This keeps all members, loans, savings, shares data.');
  print('Only deletes SACCO organization records.\n');
  
  print('📍 Go to Firebase Console:');
  print('   https://console.firebase.google.com/\n');
  
  print('Steps:');
  print('  1. Select your project');
  print('  2. Go to Firestore Database');
  print('  3. Open "saccoplus-saccos" collection');
  print('  4. Click the ⋮ menu on each SACCO document');
  print('  5. Click "Delete document"\n');
  
  print('Current SACCOs to delete:');
  print('  - MBADIFA SACCO (sacco_001)');
  print('  - TEST (test_1789898934484)');
  print('  - Any other SACCO you see\n');
  
  print('✅ After deletion, you can create fresh SACCOs!');
  print('   All your members and transaction data will remain intact.');
}

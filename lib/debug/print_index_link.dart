/// Print direct Firebase Console link for creating indexes
void printFirebaseIndexLink() {
  print('\n' + '='*70);
  print('🔗 FIREBASE COMPOSITE INDEX REQUIRED');
  print('='*70);
  print('\nYour Loan Applications screen needs a Firestore composite index.');
  print('\n📍 Click this link to open Firebase Console:');
  print('   https://console.firebase.google.com/project/_/firestore/indexes');
  print('\n📝 Create an index with these settings:');
  print('   Collection ID: saccoplus-loans');
  print('   Field 1: tenantId → Ascending');
  print('   Field 2: createdAt → Descending');
  print('   Status: Enabled');
  print('\n⏱️  The index will take 1-2 minutes to build.');
  print('\n💡 After the index is created, uncomment the orderBy lines in');
  print('   firebase_service.dart (getAllLoans and getLoansByStatus methods)');
  print('='*70 + '\n');
}

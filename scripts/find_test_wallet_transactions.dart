// Script to find test wallet transactions for October 2026
// Run with: dart run scripts/find_test_wallet_transactions.dart

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('Finding test wallet transactions for October 2026...\n');
  
  // NOTE: This script needs Firebase initialization which requires
  // a service account. Instead, run this query in Firebase Console:
  
  print('''
Run this query in Firebase Console > Firestore:

Collection: wallet_transactions

Filters:
- type == "deposit"
- status == "completed"  
- createdAt >= 2026-10-01 00:00:00
- createdAt <= 2026-10-31 23:59:59
- amount < 15000

Then for each result, note the Document ID and run:

UPDATE:
  excludeFromReports = true

Alternatively, use this JavaScript in Firebase Console:

```javascript
const db = firebase.firestore();

db.collection('wallet_transactions')
  .where('type', '==', 'deposit')
  .where('status', '==', 'completed')
  .where('createdAt', '>=', new Date('2026-10-01'))
  .where('createdAt', '<=', new Date('2026-10-31'))
  .get()
  .then(snapshot => {
    console.log('Found', snapshot.size, 'wallet transactions in October 2026:');
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.amount < 15000) {
        console.log('\\nDoc ID:', doc.id);
        console.log('  Amount:', data.amount);
        console.log('  Date:', data.createdAt?.toDate());
        console.log('  User:', data.userId || data.memberId);
        console.log('  Method:', data.verificationMethod);
        console.log('  ');
        // Uncomment to automatically flag:
        // doc.ref.update({excludeFromReports: true});
      }
    });
  });
```

Look for transactions with:
- Small amounts (< 10,000 UGX)
- Your personal user ID
- Test descriptions or patterns
  ''');
}

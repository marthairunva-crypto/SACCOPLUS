/**
 * EMERGENCY BALANCE RESTORATION
 * 
 * Run this in Firebase Console (Firestore Rules Playground or Cloud Functions):
 * 1. Go to https://console.firebase.google.com/project/mwiza-projects/firestore/data
 * 2. Click "Rules" tab
 * 3. Paste this script in the Playground
 * 4. Or run via Cloud Functions Console
 */

// Manual restoration based on screenshot values
const balancesToRestore = [
  { accountNumber: '92202000176', oldBalance: 50.00 },
  { accountNumber: '92202000176', oldBalance: 50.00 },  // Owomugisha Grace (duplicate in screenshot)
  { accountNumber: '92202000176', oldBalance: 50.00 },  // Bamurera Ireen
  { accountNumber: '92202000175', oldBalance: 12000.00 }, // Nuwagaba Dativa
  { accountNumber: '92202000175', oldBalance: 9000.00 },  // Kyoshabire Rabecca
];

// OR - Better approach: Calculate from actual transactions
// This query will work in Firestore Console directly

/**
 * MANUAL FIX IN FIREBASE CONSOLE:
 * 
 * 1. Open Firebase Console: https://console.firebase.google.com/project/mwiza-projects/firestore/data
 * 2. Click on "saccoplus-members" collection
 * 3. For each member showing "Difference: UGX XX.00":
 *    a. Click on the member document
 *    b. Find the "savingsBalance" field
 *    c. Click Edit
 *    d. Change from 0 back to the "Old" value shown in your screenshot
 *    e. Click Update
 * 
 * Example:
 * - Owomugisha Grace (Account: 92202000176): Change savingsBalance from 0 to 50
 * - Bamurera Ireen (Account: 92202000176): Change savingsBalance from 0 to 50  
 * - Nuwagaba Dativa (Account: 92202000175): Change savingsBalance from 0 to 12000
 * - Kyoshabire Rabecca (Account: 92202000175): Change savingsBalance from 0 to 9000
 */

// Alternative: Run this in Cloud Functions Console
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function restoreBalances() {
  console.log('Starting restoration...');
  
  // Get all members with 0 balance
  const membersSnapshot = await db.collection('saccoplus-members')
    .where('savingsBalance', '==', 0)
    .get();
  
  console.log(`Found ${membersSnapshot.docs.length} members with 0 balance`);
  
  for (const memberDoc of membersSnapshot.docs) {
    const memberData = memberDoc.data();
    const accountNumber = memberData.accountNumber;
    const farmerId = memberData.farmerId;
    const memberName = memberData.fullName;
    
    console.log(`Processing: ${memberName} (${accountNumber})`);
    
    // Calculate balance from transactions
    let balance = 0;
    
    // Try querying by different fields
    const queries = [
      db.collection('saccoplus-savings').where('accountNumber', '==', accountNumber),
      db.collection('saccoplus-savings').where('farmerId', '==', farmerId),
      db.collection('saccoplus-savings').where('memberId', '==', memberDoc.id),
    ];
    
    for (const query of queries) {
      try {
        const transactionsSnapshot = await query.get();
        
        if (!transactionsSnapshot.empty) {
          console.log(`  Found ${transactionsSnapshot.docs.length} transactions`);
          
          for (const txDoc of transactionsSnapshot.docs) {
            const tx = txDoc.data();
            const amount = parseFloat(tx.amount || 0);
            const type = tx.transactionType || '';
            
            if (type === 'deposit') {
              balance += amount;
            } else if (type === 'withdrawal') {
              balance -= amount;
            }
          }
          
          break; // Stop if we found transactions
        }
      } catch (error) {
        console.log(`  Query error: ${error.message}`);
      }
    }
    
    if (balance > 0) {
      // Update member document
      await memberDoc.ref.update({
        savingsBalance: balance,
        restoredAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`  ✓ Restored balance: ${balance}`);
    } else {
      console.log(`  ! No transactions found - keeping at 0`);
    }
  }
  
  console.log('Restoration complete!');
}

// To run: call restoreBalances();
// restoreBalances().catch(console.error);

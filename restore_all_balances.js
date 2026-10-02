/**
 * EMERGENCY RESTORATION SCRIPT
 * This will restore all member savings balances automatically
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

// Initialize Firebase Admin
initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function restoreAllBalances() {
  console.log('╔══════════════════════════════════════════════════════════════╗');
  console.log('║          🚨 EMERGENCY BALANCE RESTORATION 🚨                ║');
  console.log('╚══════════════════════════════════════════════════════════════╝');
  console.log('');
  
  try {
    // Get all members
    console.log('📊 Fetching all members...');
    const membersSnapshot = await db.collection('saccoplus-members').get();
    
    console.log(`✓ Found ${membersSnapshot.docs.length} members`);
    console.log('');
    
    let restoredCount = 0;
    let errorCount = 0;
    
    for (const memberDoc of membersSnapshot.docs) {
      const memberData = memberDoc.data();
      const memberId = memberDoc.id;
      const accountNumber = memberData.accountNumber || '';
      const farmerId = memberData.farmerId || '';
      const memberName = memberData.fullName || 'Unknown';
      const currentBalance = memberData.savingsBalance || 0;
      
      console.log(`👤 ${memberName} (Account: ${accountNumber})`);
      console.log(`   Current balance: UGX ${currentBalance.toFixed(2)}`);
      
      try {
        let balance = 0;
        let transactionsFound = 0;
        
        // Try multiple query approaches
        const queryStrategies = [
          { field: 'accountNumber', value: accountNumber },
          { field: 'farmerId', value: farmerId },
          { field: 'memberId', value: memberId }
        ];
        
        for (const strategy of queryStrategies) {
          if (!strategy.value) continue;
          
          try {
            const txSnapshot = await db.collection('saccoplus-savings')
              .where(strategy.field, '==', strategy.value)
              .get();
            
            if (!txSnapshot.empty) {
              console.log(`   ✓ Found ${txSnapshot.docs.length} transactions via ${strategy.field}`);
              
              for (const txDoc of txSnapshot.docs) {
                const tx = txDoc.data();
                const amount = parseFloat(tx.amount || 0);
                const type = (tx.transactionType || '').toLowerCase();
                
                if (type === 'deposit') {
                  balance += amount;
                  transactionsFound++;
                } else if (type === 'withdrawal') {
                  balance -= amount;
                  transactionsFound++;
                }
              }
              
              break; // Stop after finding transactions
            }
          } catch (queryError) {
            // Continue to next strategy
          }
        }
        
        if (transactionsFound > 0) {
          // Update the member document
          await memberDoc.ref.update({
            savingsBalance: balance,
            restoredAt: FieldValue.serverTimestamp(),
            restoredFrom: 'emergency_script'
          });
          
          console.log(`   ✅ RESTORED: UGX ${balance.toFixed(2)} (${transactionsFound} transactions)`);
          restoredCount++;
        } else {
          console.log(`   ⚠️  No transactions found - keeping at ${currentBalance}`);
        }
        
      } catch (error) {
        console.log(`   ❌ Error: ${error.message}`);
        errorCount++;
      }
      
      console.log('');
    }
    
    console.log('═══════════════════════════════════════════════════════════════');
    console.log('✅ RESTORATION COMPLETE');
    console.log('═══════════════════════════════════════════════════════════════');
    console.log(`Total members: ${membersSnapshot.docs.length}`);
    console.log(`Successfully restored: ${restoredCount}`);
    console.log(`Errors: ${errorCount}`);
    console.log('');
    console.log('✓ Please refresh your app to see the restored balances');
    console.log('');
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ FATAL ERROR:', error);
    process.exit(1);
  }
}

// Run the restoration
restoreAllBalances();

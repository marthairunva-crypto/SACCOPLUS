// Quick restoration script - simpler version
const admin = require('firebase-admin');

// Initialize
admin.initializeApp({
  credential: admin.credential.cert(require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json'))
});

const db = admin.firestore();

async function restore() {
  console.log('🚨 Starting restoration...\n');
  
  const members = await db.collection('saccoplus-members').get();
  console.log(`Found ${members.size} members\n`);
  
  let fixed = 0;
  
  for (const doc of members.docs) {
    const data = doc.data();
    const name = data.fullName || 'Unknown';
    const account = data.accountNumber || '';
    const farmerId = data.farmerId || '';
    
    console.log(`👤 ${name} (${account})`);
    
    // Calculate balance from saccoplus-savings
    let balance = 0;
    
    // Try by farmerId first (most common)
    if (farmerId) {
      const txs = await db.collection('saccoplus-savings')
        .where('farmerId', '==', farmerId)
        .get();
      
      if (!txs.empty) {
        console.log(`   Found ${txs.size} transactions`);
        txs.forEach(tx => {
          const d = tx.data();
          const amt = parseFloat(d.amount || 0);
          if (d.transactionType === 'deposit') balance += amt;
          if (d.transactionType === 'withdrawal') balance -= amt;
        });
      }
    }
    
    if (balance > 0) {
      await doc.ref.update({ savingsBalance: balance });
      console.log(`   ✅ Restored: UGX ${balance.toFixed(2)}\n`);
      fixed++;
    } else {
      console.log(`   No transactions found\n`);
    }
  }
  
  console.log(`\n✅ Done! Restored ${fixed} members`);
  process.exit(0);
}

restore().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});

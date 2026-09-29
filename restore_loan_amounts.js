// Restore loan amounts - multiply by 10 (since we divided twice)
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function restoreLoanAmounts() {
  console.log('\n🔧 Restoring Loan Amounts (multiply by 10)...\n');
  
  const loans = await db.collection('saccoplus-loans')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${loans.size} loans to restore\n`);
  
  const batches = [];
  let fixed = 0;
  
  for (let i = 0; i < loans.docs.length; i += 450) {
    const batch = db.batch();
    const chunk = loans.docs.slice(i, i + 450);
    
    chunk.forEach(doc => {
      const data = doc.data();
      
      // Multiply all amount fields by 10
      const updates = {
        amount: Math.round(data.amount * 10),
        balance: Math.round(data.balance * 10),
        totalAmount: Math.round(data.totalAmount * 10),
        amountPaid: Math.round(data.amountPaid * 10),
        outstandingPrincipal: Math.round(data.outstandingPrincipal * 10),
        outstandingInterest: Math.round(data.outstandingInterest * 10),
        interestAmount: Math.round(data.interestAmount * 10),
        disbursed: data.disbursed ? Math.round(data.disbursed * 10) : 0,
      };
      
      batch.update(doc.ref, updates);
      fixed++;
      
      if (fixed <= 5) {
        console.log(`${data.farmerName}:`);
        console.log(`  Amount: ${data.amount} → ${updates.amount}`);
        console.log(`  Balance: ${data.balance} → ${updates.balance}`);
      }
    });
    
    batches.push(batch.commit());
  }
  
  await Promise.all(batches);
  
  console.log(`\n✅ Restored ${fixed} loans!`);
}

async function restoreMemberBalances() {
  console.log('\n🔧 Restoring Member Loan Balances (multiply by 10)...\n');
  
  const members = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${members.size} members\n`);
  
  const batches = [];
  let fixed = 0;
  
  for (let i = 0; i < members.docs.length; i += 450) {
    const batch = db.batch();
    const chunk = members.docs.slice(i, i + 450);
    
    chunk.forEach(doc => {
      const data = doc.data();
      const oldBalance = data.loanBalance || 0;
      
      if (oldBalance > 0) {
        const newBalance = Math.round(oldBalance * 10);
        
        batch.update(doc.ref, { loanBalance: newBalance });
        fixed++;
        
        if (fixed <= 5) {
          console.log(`${data.name}: ${oldBalance} → ${newBalance}`);
        }
      }
    });
    
    batches.push(batch.commit());
  }
  
  await Promise.all(batches);
  
  console.log(`\n✅ Restored ${fixed} member loan balances!`);
}

async function restore() {
  try {
    await restoreLoanAmounts();
    await restoreMemberBalances();
    
    console.log('\n🎉 All amounts restored correctly! Hot reload your app.\n');
  } catch (error) {
    console.error('\n❌ Error:', error);
    throw error;
  }
}

restore()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

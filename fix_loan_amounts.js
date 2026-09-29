// Fix loan amounts - divide by 100
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function fixLoanAmounts() {
  console.log('\n🔧 Fixing Loan Amounts (dividing by 100)...\n');
  
  const loans = await db.collection('saccoplus-loans')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${loans.size} loans to fix\n`);
  
  const batches = [];
  let fixed = 0;
  
  for (let i = 0; i < loans.docs.length; i += 450) {
    const batch = db.batch();
    const chunk = loans.docs.slice(i, i + 450);
    
    chunk.forEach(doc => {
      const data = doc.data();
      
      // Divide all amount fields by 100
      const updates = {
        amount: Math.round(data.amount / 100),
        balance: Math.round(data.balance / 100),
        totalAmount: Math.round(data.totalAmount / 100),
        amountPaid: Math.round(data.amountPaid / 100),
        outstandingPrincipal: Math.round(data.outstandingPrincipal / 100),
        outstandingInterest: Math.round(data.outstandingInterest / 100),
        interestAmount: Math.round(data.interestAmount / 100),
        disbursed: data.disbursed ? Math.round(data.disbursed / 100) : 0,
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
  
  console.log(`\n✅ Fixed ${fixed} loans!`);
  console.log('\n📝 Next: Fix member loan balances...\n');
}

async function fixMemberBalances() {
  console.log('🔧 Fixing Member Loan Balances...\n');
  
  const members = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${members.size} members with loan balances\n`);
  
  const batches = [];
  let fixed = 0;
  
  for (let i = 0; i < members.docs.length; i += 450) {
    const batch = db.batch();
    const chunk = members.docs.slice(i, i + 450);
    
    chunk.forEach(doc => {
      const data = doc.data();
      const oldBalance = data.loanBalance || 0;
      
      if (oldBalance > 0) {
        const newBalance = Math.round(oldBalance / 100);
        
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
  
  console.log(`\n✅ Fixed ${fixed} member loan balances!`);
}

async function fix() {
  try {
    await fixLoanAmounts();
    await fixMemberBalances();
    
    console.log('\n🎉 All amounts fixed! Hot reload your app.\n');
  } catch (error) {
    console.error('\n❌ Error:', error);
    throw error;
  }
}

fix()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

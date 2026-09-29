// Check actual loan amounts in database
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function checkLoans() {
  console.log('\n🔍 Checking Loan Amounts...\n');
  
  const loans = await db.collection('saccoplus-loans')
    .where('tenantId', '==', 'mbadifa')
    .limit(10)
    .get();
  
  console.log(`Found ${loans.size} loans\n`);
  
  loans.docs.forEach(doc => {
    const data = doc.data();
    console.log(`${data.farmerName}`);
    console.log(`  Amount: ${data.amount}`);
    console.log(`  Balance: ${data.balance}`);
    console.log(`  Outstanding Principal: ${data.outstandingPrincipal}`);
    console.log('');
  });
}

checkLoans()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

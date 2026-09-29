// Check current state of everything
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function check() {
  console.log('\n🔍 CURRENT STATE CHECK\n');
  console.log('='.repeat(60));
  
  // 1. Check members
  console.log('\n📊 MEMBERS:');
  const members = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .where('role', '==', 'Member')
    .limit(5)
    .get();
  console.log(`  Total found: ${members.size}`);
  if (members.size > 0) {
    const sample = members.docs[0].data();
    console.log(`  Sample: ${sample.name}`);
    console.log(`    ID: ${members.docs[0].id}`);
    console.log(`    TenantId: ${sample.tenantId}`);
    console.log(`    Role: ${sample.role}`);
  }
  
  // 2. Check admin
  console.log('\n👤 ADMIN ACCOUNT:');
  const admin = await db.collection('saccoplus-members')
    .doc('phone_256758356480')
    .get();
  if (admin.exists) {
    const data = admin.data();
    console.log(`  Name: ${data.name}`);
    console.log(`  Phone: ${data.phone}`);
    console.log(`  Role: ${data.role}`);
    console.log(`  TenantId: ${data.tenantId}`);
    console.log(`  PIN Hash: ${data.pinHash ? 'SET' : 'NOT SET'}`);
  } else {
    console.log('  ❌ ADMIN NOT FOUND!');
  }
  
  // 3. Check loans
  console.log('\n💰 LOANS:');
  const loans = await db.collection('saccoplus-loans')
    .where('tenantId', '==', 'mbadifa')
    .limit(3)
    .get();
  console.log(`  Total: ${loans.size}`);
  if (loans.size > 0) {
    loans.docs.forEach(doc => {
      const data = doc.data();
      console.log(`    ${data.farmerName}: UGX ${data.amount.toLocaleString()}`);
    });
  }
  
  // 4. Check indexes
  console.log('\n📇 CRITICAL QUERY TEST:');
  try {
    const query = db.collection('saccoplus-members')
      .where('tenantId', '==', 'mbadifa')
      .where('role', '==', 'Member');
    
    const result = await query.get();
    console.log(`  ✅ Query SUCCESS: ${result.size} members`);
  } catch (error) {
    console.log(`  ❌ Query FAILED: ${error.message}`);
  }
  
  console.log('\n' + '='.repeat(60));
  console.log('\n💡 TROUBLESHOOTING:\n');
  console.log('If members still not showing in app:');
  console.log('1. Make sure you logged out completely');
  console.log('2. Login with phone: 0758356480');
  console.log('3. PIN: 1234');
  console.log('4. Hot restart app (not just reload)\n');
}

check()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

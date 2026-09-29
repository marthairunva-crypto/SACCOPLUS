// Check admin accounts in both collections
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function checkAdmins() {
  console.log('\n🔍 Checking Admin Accounts...\n');
  
  // Check saccoplus-members collection
  const members = await db.collection('saccoplus-members')
    .where('role', 'in', ['admin', 'super_admin'])
    .get();
  
  console.log(`📊 Admins in saccoplus-members: ${members.size}`);
  members.docs.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${doc.id}`);
    console.log(`    Name: ${data.name}`);
    console.log(`    Phone: ${data.phone || 'N/A'}`);
    console.log(`    Role: ${data.role}`);
    console.log(`    TenantId: ${data.tenantId || 'NOT SET'}`);
    console.log('');
  });
  
  // Check users collection
  const users = await db.collection('users')
    .where('role', 'in', ['admin', 'super_admin'])
    .get();
  
  console.log(`\n📊 Admins in users collection: ${users.size}`);
  users.docs.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${doc.id}`);
    console.log(`    Name: ${data.name || data.fullName || 'N/A'}`);
    console.log(`    Email: ${data.email || 'N/A'}`);
    console.log(`    Phone: ${data.phone || 'N/A'}`);
    console.log(`    Role: ${data.role}`);
    console.log(`    TenantId: ${data.tenantId || 'NOT SET'}`);
    console.log('');
  });
  
  console.log('\n💡 SOLUTION:');
  console.log('   To view MBADIFA members, you need to:');
  console.log('   1. Either set your admin account tenantId to "mbadifa"');
  console.log('   2. Or create a new admin for MBADIFA');
  console.log('\n   Run: node create_mbadifa_admin.js\n');
}

checkAdmins()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

// Quick script to check MBADIFA admin profile in Firebase
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function checkMbadifaAdmin() {
  const phone = '256758356480';
  
  console.log('\n🔍 Searching for admin with phone:', phone);
  console.log('=====================================\n');
  
  // Check saccoplus-members collection
  const membersQuery = await db.collection('saccoplus-members')
    .where('phone', '==', phone)
    .get();
  
  if (!membersQuery.empty) {
    console.log('✅ Found in saccoplus-members:');
    membersQuery.forEach(doc => {
      const data = doc.data();
      console.log('   Doc ID:', doc.id);
      console.log('   Name:', data.name);
      console.log('   Phone:', data.phone);
      console.log('   Role:', data.role);
      console.log('   TenantID:', data.tenantId, data.tenantId === 'mbadifa' ? '✅' : '❌ WRONG!');
      console.log('   UID:', data.uid);
      console.log('\n   Full data:', JSON.stringify(data, null, 2));
    });
  } else {
    console.log('❌ NOT found in saccoplus-members');
  }
  
  // Check legacy users collection
  console.log('\n---\n');
  const usersQuery = await db.collection('users')
    .where('phone', '==', phone)
    .get();
  
  if (!usersQuery.empty) {
    console.log('⚠️  Found in legacy users collection:');
    usersQuery.forEach(doc => {
      const data = doc.data();
      console.log('   Doc ID:', doc.id);
      console.log('   Name:', data.name);
      console.log('   Phone:', data.phone);
      console.log('   Role:', data.role);
      console.log('   TenantID:', data.tenantId || '(not set)');
      console.log('   UID:', data.uid);
    });
  } else {
    console.log('✅ Not in legacy users collection (good)');
  }
  
  process.exit(0);
}

checkMbadifaAdmin().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});

// Check MBADIFA members in Firebase
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function checkMembers() {
  console.log('\n🔍 Checking MBADIFA members...\n');
  
  // Query 1: All docs with tenantId = mbadifa
  console.log('═══ Query 1: All docs with tenantId=mbadifa ═══');
  const allMbadifa = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${allMbadifa.size} total documents with tenantId=mbadifa\n`);
  
  const roles = {};
  allMbadifa.forEach(doc => {
    const data = doc.data();
    const role = data.role || '(no role)';
    roles[role] = (roles[role] || 0) + 1;
  });
  
  console.log('Breakdown by role:');
  Object.entries(roles).forEach(([role, count]) => {
    console.log(`  ${role}: ${count}`);
  });
  
  console.log('\n═══ Query 2: Members with role=member AND tenantId=mbadifa ═══');
  const members = await db.collection('saccoplus-members')
    .where('role', '==', 'member')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${members.size} members\n`);
  
  if (members.size > 0) {
    console.log('Sample members:');
    members.docs.slice(0, 5).forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.name || data.fullName} (${data.phone})`);
    });
  }
  
  // Query 3: Check if role is 'farmer' instead
  console.log('\n═══ Query 3: Check for role=farmer ═══');
  const farmers = await db.collection('saccoplus-members')
    .where('role', '==', 'farmer')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Found ${farmers.size} with role=farmer\n`);
  
  if (farmers.size > 0) {
    console.log('Sample farmers:');
    farmers.docs.slice(0, 5).forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.name || data.fullName} (${data.phone}, role: ${data.role})`);
    });
  }
  
  process.exit(0);
}

checkMembers().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});

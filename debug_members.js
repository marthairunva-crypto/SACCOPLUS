// Debug script to check members in Firestore
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function debug() {
  console.log('\n🔍 Checking saccoplus-members collection...\n');
  
  // Query 1: All docs in saccoplus-members
  const allMembers = await db.collection('saccoplus-members').get();
  console.log(`📊 Total docs in saccoplus-members: ${allMembers.size}`);
  
  if (allMembers.size > 0) {
    const sample = allMembers.docs[0].data();
    console.log('\n📝 Sample member doc:');
    console.log(JSON.stringify(sample, null, 2));
  }
  
  // Query 2: Filter by tenantId = 'mbadifa'
  const mbadifaMembers = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .get();
  console.log(`\n🏢 Docs with tenantId='mbadifa': ${mbadifaMembers.size}`);
  
  // Query 3: Filter by tenantId = 'mbadifa' AND role = 'Member'
  const membersWithRole = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .where('role', '==', 'Member')
    .get();
  console.log(`👥 Docs with tenantId='mbadifa' AND role='Member': ${membersWithRole.size}`);
  
  if (membersWithRole.size > 0) {
    const sample = membersWithRole.docs[0].data();
    console.log('\n📝 Sample filtered member:');
    console.log(`  - ID: ${membersWithRole.docs[0].id}`);
    console.log(`  - Name: ${sample.name}`);
    console.log(`  - TenantId: ${sample.tenantId}`);
    console.log(`  - Role: ${sample.role}`);
    console.log(`  - Phone: ${sample.phone || 'N/A'}`);
  }
  
  // Query 4: Check if there are any docs without role field
  const allMbadifa = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  let noRole = 0;
  let differentRole = 0;
  allMbadifa.docs.forEach(doc => {
    const data = doc.data();
    if (!data.role) {
      noRole++;
    } else if (data.role !== 'Member') {
      differentRole++;
      console.log(`  ⚠️  Found role='${data.role}' in doc ${doc.id}`);
    }
  });
  
  if (noRole > 0) {
    console.log(`\n⚠️  ${noRole} docs missing 'role' field`);
  }
  if (differentRole > 0) {
    console.log(`⚠️  ${differentRole} docs with role != 'Member'`);
  }
  
  // Query 5: Check users collection (old location)
  const usersCollection = await db.collection('users').get();
  console.log(`\n📁 Total docs in 'users' collection: ${usersCollection.size}`);
  
  // Query 6: Check what tenantIds exist
  const tenantIds = new Set();
  allMembers.docs.forEach(doc => {
    const tid = doc.data().tenantId;
    if (tid) tenantIds.add(tid);
  });
  console.log(`\n🏢 Unique tenantIds found: ${Array.from(tenantIds).join(', ')}`);
}

debug()
  .then(() => {
    console.log('\n✅ Debug complete\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

// Test the exact query that the app uses
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function testQuery() {
  console.log('\n🔍 Testing Member Query (Exact App Query)...\n');
  
  try {
    // This is the EXACT query from getAllFarmers()
    const query = db.collection('saccoplus-members')
      .where('tenantId', '==', 'mbadifa')
      .where('role', '==', 'Member');
    
    console.log('📊 Executing query...');
    const snapshot = await query.get();
    
    console.log(`✅ Query succeeded! Found ${snapshot.size} members\n`);
    
    if (snapshot.size > 0) {
      console.log('📝 First 5 members:');
      snapshot.docs.slice(0, 5).forEach((doc, i) => {
        const data = doc.data();
        console.log(`  ${i + 1}. ${data.name} (${data.memberNumber})`);
        console.log(`     ID: ${doc.id}`);
        console.log(`     Phone: ${data.phone || 'N/A'}`);
        console.log(`     Tenant: ${data.tenantId}`);
        console.log(`     Role: ${data.role}`);
        console.log('');
      });
    }
    
    // Check if there's an index requirement
    console.log('🔍 Checking for composite index...');
    console.log('   Fields: tenantId + role');
    console.log('   Status: ✅ Query executed successfully (index exists or not required)');
    
  } catch (error) {
    console.error('❌ Query failed:', error.message);
    
    if (error.message.includes('index')) {
      console.log('\n⚠️  MISSING COMPOSITE INDEX!');
      console.log('   This query requires a composite index on:');
      console.log('   - Collection: saccoplus-members');
      console.log('   - Fields: tenantId (ASC), role (ASC)');
      console.log('');
      console.log('🔧 Solution: Add to firestore.indexes.json and deploy:');
      console.log(`
{
  "collectionGroup": "saccoplus-members",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "tenantId", "order": "ASCENDING" },
    { "fieldPath": "role", "order": "ASCENDING" }
  ]
}
`);
    }
  }
}

testQuery()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

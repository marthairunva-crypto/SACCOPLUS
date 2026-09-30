// Check detailed member structure
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function checkMemberStructure() {
  console.log('\n🔍 Checking MBADIFA member structure...\n');
  
  const members = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .where('role', '==', 'Member')
    .limit(3)
    .get();
  
  console.log(`Found ${members.size} sample members\n`);
  
  members.docs.forEach((doc, index) => {
    const data = doc.data();
    console.log(`═══ MEMBER ${index + 1}: ${data.fullName || data.name} ═══`);
    console.log('Doc ID:', doc.id);
    console.log('\nALL FIELDS:');
    
    // Sort fields alphabetically for easier reading
    const sortedFields = Object.keys(data).sort();
    sortedFields.forEach(field => {
      let value = data[field];
      
      // Format timestamps
      if (value && typeof value === 'object' && value._seconds) {
        value = `Timestamp(${new Date(value._seconds * 1000).toISOString()})`;
      }
      
      // Truncate long values
      if (typeof value === 'string' && value.length > 100) {
        value = value.substring(0, 100) + '...';
      }
      
      console.log(`  ${field}: ${JSON.stringify(value)}`);
    });
    console.log('');
  });
  
  // Show all unique fields across all members
  console.log('═══════════════════════════════════════════════');
  console.log('ALL UNIQUE FIELDS FOUND:');
  console.log('═══════════════════════════════════════════════');
  
  const allMembers = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .where('role', '==', 'Member')
    .get();
  
  const allFields = new Set();
  allMembers.forEach(doc => {
    Object.keys(doc.data()).forEach(field => allFields.add(field));
  });
  
  const sortedAllFields = Array.from(allFields).sort();
  sortedAllFields.forEach(field => console.log(`  - ${field}`));
  
  console.log(`\nTotal unique fields: ${allFields.size}\n`);
  
  process.exit(0);
}

checkMemberStructure().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});

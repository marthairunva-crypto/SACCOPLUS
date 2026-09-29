// Copy members from saccoplus-members to users collection
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function copyMembersToUsers() {
  console.log('📋 Copying members from saccoplus-members to users...');
  
  try {
    const membersSnapshot = await db.collection('saccoplus-members').get();
    
    console.log(`   Found ${membersSnapshot.size} members to copy`);
    
    const batches = [];
    const members = membersSnapshot.docs;
    
    for (let i = 0; i < members.length; i += 450) {
      const batch = db.batch();
      const chunk = members.slice(i, i + 450);
      
      chunk.forEach(doc => {
        const data = doc.data();
        const userRef = db.collection('users').doc(doc.id);
        batch.set(userRef, {
          ...data,
          role: 'Member', // Ensure role is set
        }, { merge: true });
      });
      
      batches.push(batch.commit());
    }
    
    await Promise.all(batches);
    console.log(`   ✅ Copied ${members.length} members to users collection`);
    
  } catch (error) {
    console.error('   ❌ Error:', error);
    throw error;
  }
}

copyMembersToUsers()
  .then(() => {
    console.log('\n✅ Copy complete! Members now in users collection.');
    console.log('   Press R in Flutter to hot reload and see members.');
    process.exit(0);
  })
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

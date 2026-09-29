// Migration script to move members from saccoplus-members to users collection
// Run with: node migrate_members.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateMembersToUsers() {
  console.log('🚀 Starting migration: saccoplus-members → users');
  
  try {
    // Get all members from saccoplus-members
    const membersSnapshot = await db.collection('saccoplus-members').get();
    
    if (membersSnapshot.empty) {
      console.log('✅ No members found in saccoplus-members collection');
      return;
    }

    console.log(`📊 Found ${membersSnapshot.size} members to migrate`);

    const batch = db.batch();
    let count = 0;
    let batchCount = 0;

    for (const doc of membersSnapshot.docs) {
      const data = doc.data();
      const memberId = doc.id;

      // Check if already exists in users collection
      const userDoc = await db.collection('users').doc(memberId).get();
      
      if (userDoc.exists) {
        console.log(`⏭️  Skipping ${memberId} - already exists in users collection`);
        continue;
      }

      // Add to users collection with role: 'Member'
      const userData = {
        ...data,
        role: data.role || 'Member',
        migratedFrom: 'saccoplus-members',
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      batch.set(db.collection('users').doc(memberId), userData);
      count++;
      batchCount++;

      // Firestore batch limit is 500 operations
      if (batchCount === 450) {
        await batch.commit();
        console.log(`✅ Batch committed: ${count} members migrated so far`);
        batchCount = 0;
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`✅ Final batch committed`);
    }

    console.log(`\n🎉 Migration complete!`);
    console.log(`   Total members migrated: ${count}`);
    console.log(`   Skipped (already exist): ${membersSnapshot.size - count}`);
    console.log('\n⚠️  NOTE: Original saccoplus-members collection is preserved');
    console.log('   You can delete it manually after verifying the migration');

  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

// Run migration
migrateMembersToUsers()
  .then(() => {
    console.log('\n✅ Migration script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Migration script failed:', error);
    process.exit(1);
  });

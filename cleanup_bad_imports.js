/**
 * Cleanup Script: Delete members imported with incorrect data
 * 
 * This script removes members that were imported from CSV with bad parsing
 * (showing UGX 0 balance when they should have actual values)
 * 
 * Run with: node cleanup_bad_imports.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  console.log('Firebase already initialized or error:', error.message);
}

const db = admin.firestore();

async function cleanupBadImports() {
  console.log('🧹 Starting cleanup of bad import records...\n');

  try {
    // Find all members imported from CSV with sharesBalance = 0
    const badMembers = await db.collection('saccoplus-members')
      .where('importedFrom', '==', 'shares_csv_migration')
      .where('sharesBalance', '==', 0)
      .get();

    if (badMembers.empty) {
      console.log('✅ No bad records found!');
      process.exit(0);
    }

    console.log(`Found ${badMembers.size} bad import records\n`);

    // Delete each bad record
    const batch = db.batch();
    let count = 0;

    for (const doc of badMembers.docs) {
      const data = doc.data();
      console.log(`🗑️  Deleting: ${data.name || 'Unknown'} (ID: ${doc.id})`);
      
      // Delete from saccoplus-members
      batch.delete(db.collection('saccoplus-members').doc(doc.id));
      
      // Delete from users
      batch.delete(db.collection('users').doc(doc.id));
      
      count++;

      // Firestore batch limit is 500
      if (count % 500 === 0) {
        await batch.commit();
        console.log(`✅ Committed batch of ${count} deletions`);
      }
    }

    // Commit remaining
    if (count % 500 !== 0) {
      await batch.commit();
    }

    console.log(`\n✨ Cleanup complete! Deleted ${count} bad records.`);
    console.log('Now restart your app and run the migration again.');

  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }

  process.exit(0);
}

cleanupBadImports();

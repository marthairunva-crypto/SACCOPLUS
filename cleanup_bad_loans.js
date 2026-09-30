/**
 * Cleanup Script: Delete bad loan records with missing data
 * 
 * Run with: node cleanup_bad_loans.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

// Initialize Firebase Admin
initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function cleanupBadLoans() {
  console.log('🧹 Starting cleanup of bad loan records...\n');

  try {
    const tenantId = 'mbadifa'; // Changed from 'mwiza'
    
    // Find all loans - check for misaligned data
    const allLoans = await db.collection('saccoplus-loans')
      .where('tenantId', '==', tenantId)
      .get();

    console.log(`📊 Total loans found: ${allLoans.size}\n`);

    const badLoans = [];
    
    for (const doc of allLoans.docs) {
      const data = doc.data();
      const amount = data.amount || 0;
      const memberName = data.memberName || '';
      const referenceNumber = data.referenceNumber || '';
      const migratedFrom = data.migratedFrom || '';
      
      // Mark as bad if:
      // 1. Amount is 0
      // 2. Migrated from CSV (all CSV imports need to be redone with fixed parser)
      // 3. Column misalignment indicators:
      //    - memberName is "Individual" (should be a person's name)
      //    - loanProduct contains "/" (it's actually the reference number)
      const isMisaligned = 
        data.loanProduct?.includes('/') || 
        memberName === 'Individual' ||
        memberName === 'Group' ||
        memberName === '';
        
      if (amount === 0 || migratedFrom === 'csv_import' || isMisaligned) {
        badLoans.push({
          id: doc.id,
          memberName: memberName || '(empty)',
          amount,
          referenceNumber,
          status: data.status || '(none)',
          migratedFrom,
          loanProduct: data.loanProduct || '(none)',
        });
      }
    }

    if (badLoans.length === 0) {
      console.log('✅ No bad loan records found!');
      process.exit(0);
    }

    console.log(`Found ${badLoans.length} bad loan records:\n`);
    
    // Show first 10
    badLoans.slice(0, 10).forEach((loan, i) => {
      console.log(`${i + 1}. Member: "${loan.memberName}" | Amount: ${loan.amount} | Product: ${loan.loanProduct} | Ref: ${loan.referenceNumber}`);
    });
    
    if (badLoans.length > 10) {
      console.log(`... and ${badLoans.length - 10} more\n`);
    }

    console.log(`\n⚠️  About to delete ${badLoans.length} records...\n`);

    // Delete in batches
    const batchSize = 500;
    let deleted = 0;
    
    for (let i = 0; i < badLoans.length; i += batchSize) {
      const batch = db.batch();
      const chunk = badLoans.slice(i, i + batchSize);
      
      chunk.forEach(loan => {
        batch.delete(db.collection('saccoplus-loans').doc(loan.id));
      });
      
      await batch.commit();
      deleted += chunk.length;
      console.log(`✅ Deleted ${deleted}/${badLoans.length} records...`);
    }

    console.log(`\n✨ Cleanup complete! Deleted ${deleted} bad loan records.`);
    console.log('Now run the loan migration again with the fixed CSV parser.');

  } catch (error) {
    console.error('❌ Error during cleanup:', error);
  }

  process.exit(0);
}

cleanupBadLoans();

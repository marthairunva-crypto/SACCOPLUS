#!/usr/bin/env node
/**
 * SACCOPLUS Multi-Tenant Migration Script
 * 
 * Assigns tenantId = 'sacco_001' to all existing Firestore records.
 * Run ONCE after deploying the multi-tenant code.
 * 
 * Prerequisites:
 *   1. npm install firebase-admin
 *   2. Download serviceAccountKey.json from Firebase Console
 *   3. Place it in the project root
 * 
 * Usage:
 *   node scripts/migrate_to_multitenant.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'serviceAccountKey.json');
try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('✅ Firebase Admin initialized\n');
} catch (err) {
  console.error('❌ Error: serviceAccountKey.json not found.');
  console.error('   Download it from Firebase Console → Project Settings → Service Accounts');
  console.error('   Place it in the project root directory.\n');
  process.exit(1);
}

const db = admin.firestore();
const DEFAULT_TENANT_ID = 'sacco_001';

// All collections that need tenantId
const COLLECTIONS = [
  'saccoplus-members',
  'saccoplus-loans',
  'saccoplus-repayments',
  'saccoplus-guarantors',
  'saccoplus-savings',
  'saccoplus-savings-transactions',
  'saccoplus-fixed-deposits',
  'saccoplus-shares',
  'saccoplus-wallets',
  'saccoplus-wallet-transactions',
  'saccoplus-airtime-transactions',
  'saccoplus-notifications',
  'saccoplus-audit-logs',
];

async function migrateCollection(collectionName) {
  console.log(`📦 Processing ${collectionName}...`);
  
  try {
    const snapshot = await db.collection(collectionName).get();
    
    if (snapshot.empty) {
      console.log(`   ℹ️  Collection is empty, skipping\n`);
      return { updated: 0, skipped: 0 };
    }

    let updated = 0;
    let skipped = 0;
    const batchSize = 400; // Firestore batch write limit is 500
    let batch = db.batch();
    let batchCount = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      if (data.tenantId) {
        skipped++;
        continue;
      }

      // Add tenantId to the document
      batch.update(doc.ref, { tenantId: DEFAULT_TENANT_ID });
      batchCount++;
      updated++;

      // Commit batch when it reaches the size limit
      if (batchCount >= batchSize) {
        await batch.commit();
        console.log(`   💾 Committed batch of ${batchCount} documents`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Commit any remaining documents
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   💾 Committed final batch of ${batchCount} documents`);
    }

    console.log(`   ✅ Updated: ${updated} | Skipped: ${skipped}\n`);
    return { updated, skipped };
  } catch (error) {
    console.error(`   ❌ Error migrating ${collectionName}:`, error.message, '\n');
    return { updated: 0, skipped: 0, error: true };
  }
}

async function createDefaultSaccoProfile() {
  console.log(`🏢 Creating default SACCO profile (${DEFAULT_TENANT_ID})...`);
  
  try {
    const saccoRef = db.collection('saccoplus-saccos').doc(DEFAULT_TENANT_ID);
    const saccoDoc = await saccoRef.get();

    if (saccoDoc.exists && saccoDoc.data().tenantId) {
      console.log('   ℹ️  SACCO profile already exists, skipping\n');
      return;
    }

    // Try to migrate from legacy 'config' doc
    const configRef = db.collection('saccoplus-saccos').doc('config');
    const configDoc = await configRef.get();
    
    const baseData = configDoc.exists ? configDoc.data() : {};
    
    const saccoProfile = {
      tenantId: DEFAULT_TENANT_ID,
      saccoName: baseData.name || baseData.saccoName || 'SACCOPLUS Pro',
      shortName: baseData.shortName || '',
      tagline: baseData.tagline || 'Banking Made Simple',
      registrationNo: baseData.regNo || baseData.registrationNo || '',
      logoUrl: baseData.logoUrl || '',
      primaryColor: baseData.primaryColor || 0xFF0D2B6B,
      accentColor: baseData.accentColor || 0xFFF47920,
      phone: baseData.phone || '',
      email: baseData.email || '',
      address: baseData.address || '',
      website: baseData.website || '',
      country: baseData.country || 'UG',
      currency: baseData.currency || 'UGX',
      minLoan: baseData.minLoan || 50000,
      maxLoan: baseData.maxLoan || 10000000,
      loanRate: baseData.loanRate || 18.0,
      penaltyRate: baseData.penaltyRate || 5.0,
      minSavings: baseData.minSavings || 10000,
      savingsRate: baseData.savingsRate || 8.0,
      shareValue: baseData.shareValue || 1000,
      minShares: baseData.minShares || 1,
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      migratedFromConfig: configDoc.exists,
    };

    await saccoRef.set(saccoProfile, { merge: true });
    console.log('   ✅ SACCO profile created\n');
  } catch (error) {
    console.error('   ❌ Error creating SACCO profile:', error.message, '\n');
  }
}

async function main() {
  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║     SACCOPLUS Multi-Tenant Migration                          ║');
  console.log('║     Assigning tenantId to all existing records                ║');
  console.log('╚════════════════════════════════════════════════════════════════╝\n');
  console.log(`🎯 Target tenantId: ${DEFAULT_TENANT_ID}\n`);

  const startTime = Date.now();
  let totalUpdated = 0;
  let totalSkipped = 0;
  let errors = 0;

  // Migrate all collections
  for (const collection of COLLECTIONS) {
    const result = await migrateCollection(collection);
    totalUpdated += result.updated || 0;
    totalSkipped += result.skipped || 0;
    if (result.error) errors++;
  }

  // Create the default SACCO profile
  await createDefaultSaccoProfile();

  const duration = ((Date.now() - startTime) / 1000).toFixed(1);

  console.log('╔════════════════════════════════════════════════════════════════╗');
  console.log('║     Migration Summary                                          ║');
  console.log('╚════════════════════════════════════════════════════════════════╝');
  console.log(`   📊 Total documents updated: ${totalUpdated}`);
  console.log(`   ⏭️  Already had tenantId:    ${totalSkipped}`);
  console.log(`   ❌ Collections with errors:  ${errors}`);
  console.log(`   ⏱️  Duration:                ${duration}s\n`);

  if (errors === 0) {
    console.log('🎉 Migration completed successfully!');
    console.log('\n📋 Next steps:');
    console.log('   1. Deploy updated Firestore rules: firebase deploy --only firestore:rules');
    console.log('   2. Create composite indexes when prompted by the app');
    console.log('   3. Create a super_admin user (see MULTI_TENANT_SETUP.md)');
    console.log('   4. Test login and verify data isolation\n');
  } else {
    console.log('⚠️  Migration completed with errors. Review the log above.\n');
  }

  process.exit(errors > 0 ? 1 : 0);
}

main().catch((error) => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});

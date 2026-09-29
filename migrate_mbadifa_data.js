// MBADIFA SACCO Data Migration Script
// Migrates members, shares, loans, and savings from CSV exports to Firebase

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const fs = require('fs');
const csv = require('csv-parser');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();
const TENANT_ID = 'mbadifa'; // MBADIFA SACCO tenant ID

// Helper to clean member name
function cleanName(name) {
  if (!name) return 'Unknown';
  return name.trim()
    .replace(/\s+/g, ' ')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

// Helper to parse currency
function parseCurrency(value) {
  if (!value) return 0;
  return parseInt(value.toString().replace(/[^0-9]/g, '')) || 0;
}

// Helper to parse date
function parseDate(dateStr) {
  if (!dateStr) return null;
  try {
    return Timestamp.fromDate(new Date(dateStr));
  } catch (e) {
    return null;
  }
}

// Generate phone-based member ID
function generateMemberId(referenceId) {
  // Use reference ID as unique identifier
  return `mbadifa_${referenceId.replace(/[^a-zA-Z0-9]/g, '_')}`;
}

// Step 1: Migrate Members with Savings
async function migrateSavings() {
  console.log('\n📊 Step 1: Migrating Members and Savings...');
  
  const members = [];
  let skipLines = 1; // Skip the title row
  
  return new Promise((resolve, reject) => {
    fs.createReadStream('./SavingSnapshotReport-2026-09-29.csv')
      .pipe(csv({
        skipLines: skipLines
      }))
      .on('data', (row) => {
        // Skip the empty row after header
        if (!row['Member Id'] || row['Member Id'].trim() === '' || !row['Client Name']) return;
        
        const memberId = generateMemberId(row['Reference Id'] || row['Member Id']);
        const name = cleanName(row['Client Name']);
        const savingsBalance = parseCurrency(row['Total Balance']);
        
        members.push({
          id: memberId,
          tenantId: TENANT_ID,
          memberNumber: row['Member Id'],
          referenceId: row['Reference Id'],
          accountNumber: row['Account Number'],
          name: name,
          fullName: name,
          branch: row['Branch'] || 'Main Branch',
          gender: row['Gender'] || '',
          memberType: row['Member Type'] || 'Individual',
          group: row['Group'] || '',
          role: 'Member',
          savingsBalance: savingsBalance,
          walletBalance: 0,
          sharesBalance: 0,
          totalShares: 0,
          loanBalance: 0,
          idStatus: 'approved', // All existing members are approved
          createdAt: FieldValue.serverTimestamp(),
          registrationDate: FieldValue.serverTimestamp(),
          migratedFrom: 'SavingSnapshot',
          migratedAt: FieldValue.serverTimestamp(),
        });
      })
      .on('end', async () => {
        console.log(`   Found ${members.length} members with savings`);
        
        // Batch write members
        const batches = [];
        for (let i = 0; i < members.length; i += 450) {
          const batch = db.batch();
          const chunk = members.slice(i, i + 450);
          
          chunk.forEach(member => {
            const ref = db.collection('saccoplus-members').doc(member.id);
            batch.set(ref, member, { merge: true });
          });
          
          batches.push(batch.commit());
        }
        
        await Promise.all(batches);
        console.log(`   ✅ Migrated ${members.length} members with savings`);
        resolve(members);
      })
      .on('error', reject);
  });
}

// Step 2: Migrate Shares
async function migrateShares(existingMembers) {
  console.log('\n💰 Step 2: Migrating Shares...');
  
  const memberMap = new Map(existingMembers.map(m => [m.memberNumber, m.id]));
  const updates = [];
  
  return new Promise((resolve, reject) => {
    fs.createReadStream('./ShareSnapshotReport-2026-09-29.csv')
      .pipe(csv({
        skipLines: 1
      }))
      .on('data', (row) => {
        if (!row['Member Id'] || row['Member Id'].trim() === '' || !row['Total Balance']) return;
        
        const memberId = memberMap.get(row['Member Id']);
        if (!memberId) {
          console.log(`   ⚠️  Member not found: ${row['Member Id']}`);
          return;
        }
        
        const sharesBalance = parseCurrency(row['Total Balance']);
        const sharePrice = 1000; // UGX 1,000 per share
        const totalShares = Math.floor(sharesBalance / sharePrice);
        
        updates.push({
          memberId,
          sharesBalance,
          totalShares,
        });
      })
      .on('end', async () => {
        console.log(`   Found ${updates.length} members with shares`);
        
        // Batch update shares
        const batches = [];
        for (let i = 0; i < updates.length; i += 450) {
          const batch = db.batch();
          const chunk = updates.slice(i, i + 450);
          
          chunk.forEach(update => {
            const ref = db.collection('saccoplus-members').doc(update.memberId);
            batch.update(ref, {
              sharesBalance: update.sharesBalance,
              totalShares: update.totalShares,
            });
          });
          
          batches.push(batch.commit());
        }
        
        await Promise.all(batches);
        console.log(`   ✅ Updated ${updates.length} members with share data`);
        resolve();
      })
      .on('error', reject);
  });
}

// Step 3: Migrate Active Loans
async function migrateLoans(existingMembers) {
  console.log('\n💳 Step 3: Migrating Active Loans...');
  
  const memberMap = new Map(existingMembers.map(m => [m.name, m.id]));
  const loans = [];
  
  return new Promise((resolve, reject) => {
    fs.createReadStream('./ActiveLoanReport-2026-09-29.csv')
      .pipe(csv({
        skipLines: 1
      }))
      .on('data', (row) => {
        if (!row['Client Name'] || row['Client Name'].trim() === '' || !row['Total Loan Amount']) return;
        
        const clientName = cleanName(row['Client Name']);
        const memberId = memberMap.get(clientName);
        
        if (!memberId) {
          console.log(`   ⚠️  Member not found for loan: ${clientName}`);
          return;
        }
        
        const principal = parseCurrency(row['Total Loan Amount']);
        const interest = parseCurrency(row['Total Interest Amount']);
        const outstanding = parseCurrency(row['Outstanding Principal']);
        const outstandingInterest = parseCurrency(row['Outstanding Interest']);
        const disbursed = parseCurrency(row['OriginalDisbursedAmount']);
        const overdueDays = parseInt(row['Overdue Days']) || 0;
        
        const loanId = `${memberId}_${row['Account Number']}`;
        
        loans.push({
          id: loanId,
          tenantId: TENANT_ID,
          farmerId: memberId,
          farmerName: clientName,
          accountNumber: row['Account Number'],
          referenceNumber: row['Reference Number'],
          loanProduct: row['Loan Product'],
          loanType: row['Loan Product'].toLowerCase().includes('business') ? 'business' :
                    row['Loan Product'].toLowerCase().includes('emergency') ? 'emergency' :
                    row['Loan Product'].toLowerCase().includes('agriculture') ? 'agriculture' : 'personal',
          amount: principal,
          interestAmount: interest,
          totalAmount: principal + interest,
          balance: outstanding + outstandingInterest,
          amountPaid: disbursed - outstanding,
          outstandingPrincipal: outstanding,
          outstandingInterest: outstandingInterest,
          status: overdueDays > 0 ? 'overdue' : 'approved',
          overdueDays: overdueDays,
          tenure: row['Tenure'],
          tenureType: row['Tenure Type'],
          createdAt: parseDate(row['Creation Date']) || FieldValue.serverTimestamp(),
          disbursedAt: parseDate(row['Disbursement Date']),
          expiryDate: parseDate(row['Expiry Date']),
          dueDate: parseDate(row['Due Date']),
          loanOfficer: row['Loan Officer'] || '',
          migratedFrom: 'ActiveLoanReport',
          migratedAt: FieldValue.serverTimestamp(),
        });
      })
      .on('end', async () => {
        console.log(`   Found ${loans.length} active loans`);
        
        // Batch write loans
        const batches = [];
        for (let i = 0; i < loans.length; i += 450) {
          const batch = db.batch();
          const chunk = loans.slice(i, i + 450);
          
          chunk.forEach(loan => {
            const ref = db.collection('saccoplus-loans').doc(loan.id);
            batch.set(ref, loan);
          });
          
          batches.push(batch.commit());
        }
        
        await Promise.all(batches);
        console.log(`   ✅ Migrated ${loans.length} active loans`);
        
        // Update member loan balances
        console.log('   Updating member loan balances...');
        const loanBalances = new Map();
        loans.forEach(loan => {
          const current = loanBalances.get(loan.farmerId) || 0;
          loanBalances.set(loan.farmerId, current + loan.balance);
        });
        
        const updateBatches = [];
        const entries = Array.from(loanBalances.entries());
        for (let i = 0; i < entries.length; i += 450) {
          const batch = db.batch();
          const chunk = entries.slice(i, i + 450);
          
          chunk.forEach(([memberId, balance]) => {
            const ref = db.collection('saccoplus-members').doc(memberId);
            batch.update(ref, { loanBalance: balance });
          });
          
          updateBatches.push(batch.commit());
        }
        
        await Promise.all(updateBatches);
        console.log(`   ✅ Updated loan balances for ${loanBalances.size} members`);
        resolve();
      })
      .on('error', reject);
  });
}

// Main migration function
async function migrate() {
  console.log('🚀 Starting MBADIFA SACCO Data Migration');
  console.log('==========================================\n');
  
  try {
    const members = await migrateSavings();
    await migrateShares(members);
    await migrateLoans(members);
    
    console.log('\n==========================================');
    console.log('✅ Migration Complete!');
    console.log(`   Total Members: ${members.length}`);
    console.log(`   Tenant ID: ${TENANT_ID}`);
    console.log('\n📝 Next Steps:');
    console.log('   1. Login to SACCOPLUS with tenant: mbadifa');
    console.log('   2. Verify member data in Members screen');
    console.log('   3. Check loan portfolio');
    console.log('   4. Verify shares and savings balances');
    
  } catch (error) {
    console.error('\n❌ Migration Failed:', error);
    throw error;
  }
}

// Run migration
migrate()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

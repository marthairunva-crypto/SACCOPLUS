// Check ALL MBADIFA data in Firebase
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./mwiza-projects-firebase-adminsdk-fbsvc-7cd90dbd8f.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function checkAllData() {
  console.log('\n🔍 Checking ALL MBADIFA data...\n');
  
  // ═══ MEMBERS ═══
  console.log('═══════════════════════════════════════════════════');
  console.log('📊 MEMBERS (saccoplus-members)');
  console.log('═══════════════════════════════════════════════════');
  
  const members = await db.collection('saccoplus-members')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Total docs: ${members.size}`);
  
  const roleBreakdown = {};
  members.forEach(doc => {
    const role = doc.data().role || '(no role)';
    roleBreakdown[role] = (roleBreakdown[role] || 0) + 1;
  });
  
  console.log('\nRole breakdown:');
  Object.entries(roleBreakdown).forEach(([role, count]) => {
    console.log(`  ${role}: ${count}`);
  });
  
  // ═══ LOANS ═══
  console.log('\n═══════════════════════════════════════════════════');
  console.log('💰 LOANS (saccoplus-loans)');
  console.log('═══════════════════════════════════════════════════');
  
  const loans = await db.collection('saccoplus-loans')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Total loans: ${loans.size}`);
  
  if (loans.size > 0) {
    const statusBreakdown = {};
    let totalAmount = 0;
    let totalRepaid = 0;
    
    loans.forEach(doc => {
      const data = doc.data();
      const status = data.status || '(no status)';
      statusBreakdown[status] = (statusBreakdown[status] || 0) + 1;
      
      totalAmount += (data.amount || data.loanAmount || 0);
      totalRepaid += (data.totalRepaid || data.amountPaid || 0);
    });
    
    console.log('\nStatus breakdown:');
    Object.entries(statusBreakdown).forEach(([status, count]) => {
      console.log(`  ${status}: ${count}`);
    });
    
    console.log(`\nTotal amount: UGX ${totalAmount.toLocaleString()}`);
    console.log(`Total repaid: UGX ${totalRepaid.toLocaleString()}`);
    console.log(`Outstanding: UGX ${(totalAmount - totalRepaid).toLocaleString()}`);
    
    // Sample loan
    const sampleLoan = loans.docs[0].data();
    console.log('\nSample loan fields:');
    console.log('  Fields present:', Object.keys(sampleLoan).sort().join(', '));
  }
  
  // ═══ APPLICATIONS ═══
  console.log('\n═══════════════════════════════════════════════════');
  console.log('📝 LOAN APPLICATIONS (saccoplus-loan-applications)');
  console.log('═══════════════════════════════════════════════════');
  
  const applications = await db.collection('saccoplus-loan-applications')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Total applications: ${applications.size}`);
  
  if (applications.size > 0) {
    const statusBreakdown = {};
    applications.forEach(doc => {
      const status = doc.data().status || '(no status)';
      statusBreakdown[status] = (statusBreakdown[status] || 0) + 1;
    });
    
    console.log('\nStatus breakdown:');
    Object.entries(statusBreakdown).forEach(([status, count]) => {
      console.log(`  ${status}: ${count}`);
    });
  }
  
  // ═══ WALLETS ═══
  console.log('\n═══════════════════════════════════════════════════');
  console.log('💵 WALLETS (saccoplus-wallets)');
  console.log('═══════════════════════════════════════════════════');
  
  const wallets = await db.collection('saccoplus-wallets')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Total wallets: ${wallets.size}`);
  
  if (wallets.size > 0) {
    let totalBalance = 0;
    wallets.forEach(doc => {
      totalBalance += (doc.data().balance || 0);
    });
    console.log(`Total balance: UGX ${totalBalance.toLocaleString()}`);
  }
  
  // ═══ SHARES ═══
  console.log('\n═══════════════════════════════════════════════════');
  console.log('📈 SHARES (saccoplus-shares)');
  console.log('═══════════════════════════════════════════════════');
  
  const shares = await db.collection('saccoplus-shares')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Total shares: ${shares.size}`);
  
  // ═══ SAVINGS ═══
  console.log('\n═══════════════════════════════════════════════════');
  console.log('🏦 SAVINGS (saccoplus-savings)');
  console.log('═══════════════════════════════════════════════════');
  
  const savings = await db.collection('saccoplus-savings')
    .where('tenantId', '==', 'mbadifa')
    .get();
  
  console.log(`Total savings: ${savings.size}`);
  
  console.log('\n═══════════════════════════════════════════════════\n');
  
  process.exit(0);
}

checkAllData().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});

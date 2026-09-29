// Create admin account for MBADIFA SACCO
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

function hashPin(pin) {
  return crypto.createHash('sha256').update(pin).digest('hex');
}

async function createMbadifaAdmin() {
  console.log('\n🔐 Creating MBADIFA SACCO Admin Account...\n');
  
  const phone = '256758356480'; // Same phone as existing admin
  const pin = '1234'; // Default PIN
  const docId = `phone_${phone}`;
  
  const adminData = {
    uid: docId,
    id: docId,
    phone: phone,
    name: 'MBADIFA ADMIN',
    fullName: 'MBADIFA ADMIN',
    role: 'admin',
    tenantId: 'mbadifa',
    pinHash: hashPin(pin),
    idStatus: 'approved',
    createdAt: FieldValue.serverTimestamp(),
    registrationDate: FieldValue.serverTimestamp(),
  };
  
  await db.collection('saccoplus-members').doc(docId).set(adminData, { merge: true });
  
  console.log('✅ Admin account created successfully!');
  console.log('');
  console.log('📋 Login Details:');
  console.log(`   Phone: ${phone}`);
  console.log(`   PIN: ${pin}`);
  console.log(`   Tenant: mbadifa`);
  console.log('');
  console.log('📝 Next Steps:');
  console.log('   1. Open your app');
  console.log('   2. Login with phone: 0758356480');
  console.log('   3. Enter PIN: 1234');
  console.log('   4. You should now see 433 MBADIFA members!');
  console.log('');
}

createMbadifaAdmin()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });

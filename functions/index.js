/**
 * Firebase Cloud Functions for MBADIFA SACCO
 * 
 * Provides SMS proxy to bypass CORS restrictions on web
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

admin.initializeApp();

/**
 * SMS Proxy Function
 * 
 * Sends SMS via EgoSMS API, bypassing CORS restrictions for web clients
 * 
 * @param {string} phone - Phone number in format 256XXXXXXXXX
 * @param {string} message - SMS message text
 * @param {string} sender - Sender ID (max 11 chars)
 * 
 * @returns {object} { success: boolean, message: string, statusCode?: number, body?: string }
 */
exports.sendSMS = functions.https.onCall(async (data, context) => {
  // Extract parameters
  const { phone, message, sender = 'MBADIFA' } = data;

  // Validate required fields
  if (!phone || !message) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Phone and message are required'
    );
  }

  // EgoSMS credentials (store these in Firebase Config or Environment Variables)
  const EGOSMS_USERNAME = 'INFINITECH';
  const EGOSMS_PASSWORD = 'Moses,123##';
  
  // Build EgoSMS API URL
  const url = `https://www.egosms.co/api/v1/plain/` +
    `?number=${encodeURIComponent(phone)}` +
    `&message=${encodeURIComponent(message)}` +
    `&username=${encodeURIComponent(EGOSMS_USERNAME)}` +
    `&password=${encodeURIComponent(EGOSMS_PASSWORD)}` +
    `&sender=${encodeURIComponent(sender)}`;

  try {
    console.log('📤 Sending SMS to:', phone);
    console.log('📤 Message length:', message.length);
    console.log('📤 Sender:', sender);

    // Make request to EgoSMS API
    const response = await fetch(url, {
      method: 'GET',
      timeout: 10000
    });

    const body = await response.text();
    
    console.log('📥 SMS API Status:', response.status);
    console.log('📥 SMS API Response:', body);

    if (response.status === 200) {
      console.log('✅ SMS sent successfully');
      return {
        success: true,
        message: 'SMS sent successfully',
        statusCode: response.status,
        body: body
      };
    } else {
      console.log('❌ SMS API error:', response.status, body);
      return {
        success: false,
        message: `SMS API returned status ${response.status}`,
        statusCode: response.status,
        body: body
      };
    }
  } catch (error) {
    console.error('❌ SMS sending failed:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send SMS: ' + error.message
    );
  }
});

/**
 * OTP Generation and Storage (optional, for enhanced security)
 * 
 * Stores OTPs in Firestore instead of memory for web compatibility
 */
exports.generateOTP = functions.https.onCall(async (data, context) => {
  const { phone } = data;

  if (!phone) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone is required');
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Store in Firestore with 5-minute expiry
  const expiryTime = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 5 * 60 * 1000)
  );

  await admin.firestore().collection('otps').doc(phone).set({
    code: otp,
    expiry: expiryTime,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  console.log('✅ OTP generated for:', phone);

  return {
    success: true,
    message: 'OTP generated and stored'
  };
});

/**
 * OTP Verification (optional, for enhanced security)
 */
exports.verifyOTP = functions.https.onCall(async (data, context) => {
  const { phone, code } = data;

  if (!phone || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone and code are required');
  }

  // Get OTP from Firestore
  const otpDoc = await admin.firestore().collection('otps').doc(phone).get();

  if (!otpDoc.exists) {
    return {
      success: false,
      message: 'OTP not found or expired'
    };
  }

  const otpData = otpDoc.data();
  const now = admin.firestore.Timestamp.now();

  // Check expiry
  if (now.toMillis() > otpData.expiry.toMillis()) {
    await otpDoc.ref.delete();
    return {
      success: false,
      message: 'OTP expired'
    };
  }

  // Check code match
  if (otpData.code === code.trim()) {
    await otpDoc.ref.delete(); // One-time use
    console.log('✅ OTP verified for:', phone);
    return {
      success: true,
      message: 'OTP verified successfully'
    };
  } else {
    return {
      success: false,
      message: 'Invalid OTP'
    };
  }
});

/**
 * Simple SMS Proxy Server for MBADIFA SACCO
 * 
 * This bypasses CORS restrictions without needing Firebase Cloud Functions
 * Can be hosted on any Node.js hosting (Heroku, Render, Railway, etc.)
 */

const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
const PORT = process.env.PORT || 3000;

// EgoSMS credentials
const EGOSMS_USERNAME = 'INFINITECH';
const EGOSMS_PASSWORD = 'Moses,123##';
const EGOSMS_SENDER = 'MBADIFA';

// Enable CORS for your domain
app.use(cors({
  origin: [
    'http://localhost:5000',
    'https://mbadifa.infinitech.co.ug',
    'https://mbadifainfinitech.netlify.app',
    'https://mwiza-projects.web.app',
    'https://mwiza-projects.firebaseapp.com'
  ]
}));

app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'MBADIFA SACCO SMS Proxy Server',
    version: '1.0.0'
  });
});

// SMS sending endpoint
app.post('/send-sms', async (req, res) => {
  try {
    const { phone, message, sender = EGOSMS_SENDER } = req.body;

    // Validate input
    if (!phone || !message) {
      return res.status(400).json({
        success: false,
        error: 'Phone and message are required'
      });
    }

    console.log(`📤 Sending SMS to: ${phone}`);
    console.log(`📤 Message: ${message.substring(0, 50)}...`);

    // Build EgoSMS API URL
    const url = `https://www.egosms.co/api/v1/plain/` +
      `?number=${encodeURIComponent(phone)}` +
      `&message=${encodeURIComponent(message)}` +
      `&username=${encodeURIComponent(EGOSMS_USERNAME)}` +
      `&password=${encodeURIComponent(EGOSMS_PASSWORD)}` +
      `&sender=${encodeURIComponent(sender)}`;

    // Call EgoSMS API
    const response = await fetch(url, {
      method: 'GET',
      timeout: 10000
    });

    const body = await response.text();
    
    console.log(`📥 EgoSMS Status: ${response.status}`);
    console.log(`📥 EgoSMS Response: ${body}`);

    if (response.status === 200) {
      console.log('✅ SMS sent successfully');
      return res.json({
        success: true,
        message: 'SMS sent successfully',
        statusCode: response.status,
        response: body
      });
    } else {
      console.log(`❌ SMS failed: ${response.status}`);
      return res.status(500).json({
        success: false,
        error: `SMS API returned status ${response.status}`,
        statusCode: response.status,
        response: body
      });
    }
  } catch (error) {
    console.error('❌ SMS error:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 SMS Proxy Server running on port ${PORT}`);
  console.log(`📍 Access at: http://localhost:${PORT}`);
});

# 🔐 OTP/SMS Setup for Web Platform

## Problem

Web browsers **block direct HTTP requests** to external APIs like EgoSMS due to CORS (Cross-Origin Resource Sharing) security policies. This prevents OTP SMS from being sent when running on web.

## Solution

Use **Firebase Cloud Functions** as a proxy to send SMS. The Cloud Function runs on Google's servers and can make external API calls without CORS restrictions.

---

## 📋 Setup Steps

### Step 1: Install Dependencies

```powershell
# Add cloud_functions package
flutter pub add cloud_functions:^6.5.0

# Get dependencies
flutter pub get
```

### Step 2: Deploy Cloud Functions

The Cloud Functions are already created in `functions/` folder:
- `functions/index.js` - Contains `sendSMS` function
- `functions/package.json` - Node.js dependencies

**Install Function Dependencies:**
```powershell
cd functions
npm install
cd ..
```

**Deploy to Firebase:**
```powershell
firebase deploy --only functions
```

This will deploy the `sendSMS` cloud function.

### Step 3: Test the Setup

After deployment, Firebase will give you a function URL like:
```
https://us-central1-mwiza-projects.cloudfunctions.net/sendSMS
```

The Dart code automatically detects when running on web and uses the Cloud Function instead of direct API calls.

---

## 🔧 How It Works

### Mobile/Desktop (Direct API)
```
Flutter App → EgoSMS API → SMS Delivered
```

### Web (Via Cloud Function)
```
Flutter Web → Firebase Cloud Function → EgoSMS API → SMS Delivered
```

### Code Implementation

The `firebase_service.dart` now includes:

```dart
if (kIsWeb) {
  return await _sendSmsViaCloudFunction(number, message);
} else {
  // Direct API call for mobile/desktop
}
```

---

## ⚡ Quick Deploy

```powershell
# 1. Install function dependencies
cd functions
npm install

# 2. Deploy functions
cd ..
firebase deploy --only functions

# 3. Rebuild web app
flutter build web --release

# 4. Deploy web app
firebase deploy --only hosting
```

---

## 🧪 Testing

### Test Cloud Function Manually

Use Firebase Console:
1. Go to: https://console.firebase.google.com/project/mwiza-projects/functions
2. Find `sendSMS` function
3. Click "Test function" tab
4. Send test data:
```json
{
  "phone": "256712345678",
  "message": "Test OTP: 123456",
  "sender": "MBADIFA"
}
```

### Test from Web App

1. Deploy the web app
2. Open in browser
3. Try to register or login (triggers OTP)
4. Check browser console for logs:
   - `📤 Sending SMS via Cloud Function (WEB)`
   - `✅ SMS sent successfully via Cloud Function!`

---

## 🛡️ Security

### Credentials Storage

Current setup: Credentials are in the Cloud Function code.

**Best Practice:** Use Firebase environment configuration:

```powershell
# Set environment variables (DO THIS INSTEAD)
firebase functions:config:set egosms.username="INFINITECH"
firebase functions:config:set egosms.password="Moses,123##"

# Redeploy
firebase deploy --only functions
```

Then update `functions/index.js`:

```javascript
// Instead of hardcoded credentials
const EGOSMS_USERNAME = functions.config().egosms.username;
const EGOSMS_PASSWORD = functions.config().egosms.password;
```

---

## 💰 Cost

Firebase Cloud Functions pricing (Free tier):
- ✅ 2 million invocations/month FREE
- ✅ 400,000 GB-seconds compute FREE
- ✅ 200,000 GHz-seconds compute FREE

**SMS sending is well within free limits** for normal SACCO usage.

Beyond free tier:
- $0.40 per million invocations
- $0.0000025 per GB-second

**Example:** 10,000 OTPs/month = FREE (well below 2 million limit)

---

## 🔍 Troubleshooting

### Issue: "Cloud Function not found"

**Solution:**
```powershell
firebase deploy --only functions
```

Verify deployment:
```powershell
firebase functions:list
```

### Issue: "Permission denied"

**Solution:** Check Firebase project permissions:
1. Go to https://console.firebase.google.com/project/mwiza-projects/settings/iam
2. Ensure you have "Editor" or "Owner" role

### Issue: "Function timeout"

**Solution:** Increase timeout in `functions/index.js`:

```javascript
exports.sendSMS = functions
  .runWith({ timeoutSeconds: 30 })
  .https.onCall(async (data, context) => {
    // ... function code
  });
```

### Issue: SMS still not sending

**Check:**
1. Function deployed: `firebase functions:list`
2. Function logs: `firebase functions:log`
3. Browser console for errors
4. EgoSMS credentials correct
5. Phone number format (256XXXXXXXXX)

---

## 📊 Monitoring

### View Function Logs

```powershell
# Real-time logs
firebase functions:log --only sendSMS

# Or in Firebase Console
# https://console.firebase.google.com/project/mwiza-projects/functions/logs
```

### Check Invocations

Firebase Console → Functions → sendSMS → Usage tab

Shows:
- Number of invocations
- Execution time
- Success/error rate

---

## 🚀 Alternative Solutions

If Cloud Functions don't work, you have options:

### Option 1: Backend Proxy Server

Deploy your own Node.js/Python server:
- Receives SMS requests from Flutter web
- Forwards to EgoSMS API
- Returns success/failure

### Option 2: Firebase Realtime Database Trigger

1. Web app writes OTP request to Realtime Database
2. Cloud Function triggers on write
3. Function sends SMS
4. Function updates status in database
5. Web app listens for status change

### Option 3: Different SMS Provider

Use SMS providers with web-friendly APIs:
- Twilio (has web SDK)
- Africa's Talking (CORS-enabled)
- MessageBird (web-friendly)

---

## ✅ Verification Checklist

Before deploying to production:

- [ ] `cloud_functions` package added to `pubspec.yaml`
- [ ] Firebase Functions deployed (`firebase deploy --only functions`)
- [ ] Function shows in Firebase Console
- [ ] Test SMS sent successfully via function
- [ ] Web app rebuilt (`flutter build web --release`)
- [ ] Web app redeployed (`firebase deploy --only hosting`)
- [ ] OTP works on web browser
- [ ] Mobile app still works (direct API)
- [ ] Credentials secured (environment variables)
- [ ] Function logs show successful sends

---

## 📞 Support

**Firebase Functions Documentation:**
https://firebase.google.com/docs/functions

**EgoSMS API Documentation:**
https://www.egosms.co/api-documentation

**Cloud Functions Dashboard:**
https://console.firebase.google.com/project/mwiza-projects/functions

---

## 🎯 Quick Reference

```powershell
# Deploy everything
flutter pub get
cd functions && npm install && cd ..
firebase deploy

# Deploy only functions
firebase deploy --only functions

# Deploy only web hosting
flutter build web --release
firebase deploy --only hosting

# View function logs
firebase functions:log

# Test locally (requires Firebase emulator)
firebase emulators:start
```

---

**Once Cloud Functions are deployed, OTP will work seamlessly on web! 🎉**

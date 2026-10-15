# MBADIFA SACCO SMS Proxy Server

Simple Node.js proxy to bypass CORS restrictions for SMS sending on web.

## Quick Start

```bash
cd sms-proxy
npm install
npm start
```

Server runs on: http://localhost:3000

## Deploy to Free Hosting

### Option 1: Render.com (Recommended - FREE)

1. Go to: https://render.com
2. Sign up/Login
3. Click "New" → "Web Service"
4. Connect GitHub repo
5. Select: `sms-proxy` folder
6. Settings:
   - Name: `mbadifa-sms-proxy`
   - Build Command: `npm install`
   - Start Command: `npm start`
7. Click "Create Web Service"
8. Get URL: `https://mbadifa-sms-proxy.onrender.com`

### Option 2: Railway.app (FREE)

1. Go to: https://railway.app
2. Login with GitHub
3. Click "New Project" → "Deploy from GitHub"
4. Select your repo
5. Railway auto-detects Node.js
6. Get URL: `https://mbadifa-sms-proxy.up.railway.app`

### Option 3: Heroku (FREE with verification)

```bash
heroku create mbadifa-sms-proxy
git push heroku main
```

## Update Flutter Code

After deploying, update `lib/core/firebase_service.dart`:

```dart
// At the top of the file, add:
static const String _smsProxyUrl = 'https://your-proxy-url.onrender.com';

// Update _sendSmsViaCloudFunction:
static Future<bool> _sendSmsViaCloudFunction(String number, String message) async {
  try {
    final response = await http.post(
      Uri.parse('$_smsProxyUrl/send-sms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': number,
        'message': message,
        'sender': _egoSender,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    debugPrint('SMS Proxy Error: $e');
    return false;
  }
}
```

## Test

```bash
curl -X POST http://localhost:3000/send-sms \
  -H "Content-Type: application/json" \
  -d '{"phone":"256712345678","message":"Test OTP: 123456"}'
```

## Cost

- Render.com: FREE (750 hours/month)
- Railway.app: FREE ($5 credit/month)
- Heroku: FREE (550-1000 hours/month)

All options are FREE for your usage!

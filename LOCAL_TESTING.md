# Testing Marz Pay Airtime Locally

## Quick Start

### 1. Start Local Proxy Server

```bash
cd proxy
npm install
npm start
```

Server will run on `http://localhost:3000`

### 2. Update Flutter Constants for Local Testing

In `lib/core/constants.dart`, temporarily change:

```dart
static const String renderProxyUrl = 'http://localhost:3000';
// Or if testing on Android emulator:
// static const String renderProxyUrl = 'http://10.0.2.2:3000';
```

### 3. Test the App

```bash
flutter run -d chrome
# or
flutter run -d <your-device>
```

### 4. When Done Testing

Change back to production URL:

```dart
static const String renderProxyUrl = 'https://marzpay-proxy.onrender.com';
```

---

## Deploy to Render

Once local testing works:

### 1. Push Updated Code

```bash
git add proxy/
git commit -m "Replace Relworx with Marz Pay for airtime/data"
git push
```

### 2. Render Auto-Deploys

Render will automatically deploy the new version.

### 3. Update Environment Variables in Render Dashboard

Go to your Render dashboard and make sure these are set:

- `MARZPAY_BASE_URL` = `https://wallet.wearemarz.com/api/v1`
- `MARZPAY_AUTH` = Your base64 encoded `api_key:api_secret`
- `PROXY_KEY` = `saccoplus_pro_2025_proxy_key`

**Remove these (no longer needed):**
- ~~RELWORX_BASE_URL~~
- ~~RELWORX_ACCOUNT_NO~~

### 4. Test the Deployed Proxy

Visit: `https://marzpay-proxy.onrender.com/`

You should see:

```json
{
  "service": "SACCOPLUS Pro Proxy",
  "status": "running",
  "version": "2.0.0",
  "endpoints": {
    "marzpay": [...],
    "marzpay_airtime": [
      "airtime/catalog",
      "airtime/purchase",
      "airtime/:reference",
      "airtime/purchases"
    ]
  }
}
```

**Note: No more `relworx` in endpoints!**

---

## Troubleshooting

### Error: "Unexpected token <!DOCTYPE"

This means the proxy returned HTML (404 page) instead of JSON.

**Causes:**
- Proxy server not running
- Wrong URL in constants.dart
- Route doesn't exist on proxy

**Fix:**
1. Make sure proxy server is running
2. Check the URL is correct
3. Verify route exists in server.js

### Error: "Failed to connect"

**Causes:**
- Proxy server not started
- Firewall blocking port 3000
- Wrong URL format

**Fix:**
1. Start proxy: `cd proxy && npm start`
2. Check firewall settings
3. Use correct localhost URL

### CORS Errors on Web

The code already handles CORS with `corsproxy.io` wrapper. If you still get CORS errors:

1. Make sure you're using the CORS wrapper (kIsWeb check in code)
2. Try running on mobile/desktop instead of web for testing
3. Ensure proxy has `cors()` middleware enabled

---

## Testing Checklist

- [ ] Proxy server starts without errors
- [ ] Health check returns JSON with new routes
- [ ] `/marzpay/airtime/catalog` returns MTN bundles
- [ ] Can buy 1000 UGX airtime successfully
- [ ] Can select and buy a data bundle
- [ ] Transaction records in Firestore
- [ ] Wallet balance deducted correctly

---

## Production Deployment Checklist

- [ ] Code pushed to Git
- [ ] Render auto-deployed successfully
- [ ] Environment variables updated (removed Relworx vars)
- [ ] Health check endpoint shows v2.0.0
- [ ] Subscribed to "Airtime & Data" on Marz Pay
- [ ] UG wallet has balance
- [ ] Server IP whitelisted on Marz Pay
- [ ] Test purchase works in production

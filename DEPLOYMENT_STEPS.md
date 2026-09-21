# 🚀 Marz Pay Migration - Deployment Steps

## ✅ What's Been Done

1. **Replaced Relworx with Marz Pay** for airtime & data
2. **Added phone verification** - Shows registered name before purchase
3. **Fixed data bundles loading** - Better error messages
4. **Removed all Relworx code** completely
5. **Fixed Flutter theme errors** (CardTheme, TabBarTheme)

---

## 📋 Next Steps to Deploy

### 1️⃣ Test Locally First

```bash
# Start proxy server
cd proxy
npm install
npm start
```

The proxy will run on `http://localhost:3000`

**Already done:** `lib/core/constants.dart` is set to `http://localhost:3000`

```bash
# Test the app
flutter run -d chrome
```

Try:
- Buy 1000 UGX airtime - should show phone verification dialog
- Select data bundle - should load MTN bundles
- Verify wallet deduction works

---

### 2️⃣ Deploy to Render

Once local testing passes:

**A. Update constants back to production:**

In `lib/core/constants.dart` line 86, change:

```dart
static const String renderProxyUrl = 'https://marzpay-proxy.onrender.com';
```

**B. Push to Git:**

```bash
git add .
git commit -m "Migrate to Marz Pay airtime API, add phone verification"
git push
```

**C. Render auto-deploys** - Wait for deployment to complete

**D. Update Render Environment Variables:**

Go to Render dashboard → Your proxy service → Environment

**REMOVE these:**
- ❌ `RELWORX_BASE_URL`
- ❌ `RELWORX_ACCOUNT_NO`

**KEEP these:**
- ✅ `MARZPAY_BASE_URL` = `https://wallet.wearemarz.com/api/v1`
- ✅ `MARZPAY_AUTH` = Your base64 `api_key:api_secret`
- ✅ `PROXY_KEY` = `saccoplus_pro_2025_proxy_key`
- ✅ `PORT` = `3000`

---

### 3️⃣ Marz Pay Setup

Before testing production:

1. **Subscribe to service:**
   - Go to https://wallet.wearemarz.com
   - Subscribe to "Airtime & Data" in marketplace

2. **Whitelist your server IP:**
   - Get your Render server IP
   - Add it to Marz Pay API whitelist

3. **Top up UG wallet:**
   - Fund your Uganda wallet balance
   - Minimum 500 UGX for testing

---

### 4️⃣ Test Production

**A. Check proxy health:**

Visit: `https://marzpay-proxy.onrender.com/`

Should show:

```json
{
  "service": "SACCOPLUS Pro Proxy",
  "status": "running",
  "version": "2.0.0",
  "endpoints": {
    "marzpay": [...],
    "marzpay_airtime": ["airtime/catalog", "airtime/purchase", ...]
  }
}
```

**NO `relworx` should appear!**

**B. Test app features:**

- [ ] Phone verification shows registered name
- [ ] Can buy 1000 UGX airtime
- [ ] Data bundles load and display
- [ ] Can purchase data bundle
- [ ] Wallet deduction works
- [ ] Transaction recorded in Firestore

---

## 🆘 Troubleshooting

### "Unexpected token <!DOCTYPE"

**Cause:** Proxy server returned HTML instead of JSON

**Fix:**
- Make sure local proxy is running (`npm start`)
- Or deploy to Render and update constants to production URL

### "No bundles available"

**Cause:** Catalog API call failed

**Fix:**
- Check proxy server is running
- Check `MARZPAY_AUTH` is correct in env vars
- Verify you subscribed to Airtime & Data service

### "SERVICE_NOT_SUBSCRIBED"

**Fix:** Subscribe to "Airtime & Data" in Marz Pay marketplace

### "INSUFFICIENT_BALANCE"

**Fix:** Top up your Marz Pay UG wallet

### "UNSUPPORTED_NETWORK"

**Info:** Only MTN works for now. Airtel coming soon from Marz Pay.

---

## 📁 Files Changed

- ✅ `lib/core/firebase_service.dart` - Replaced Relworx with Marz Pay
- ✅ `lib/screens/farmer/airtime_data_screen.dart` - Added phone verification
- ✅ `lib/core/theme.dart` - Fixed Flutter 3.44 deprecations
- ✅ `lib/core/constants.dart` - Removed Relworx account
- ✅ `proxy/server.js` - Removed Relworx routes, added Marz Pay airtime
- ✅ `proxy/render.yaml` - Removed Relworx env vars
- ✅ `proxy/.env.example` - Updated template
- ✅ `proxy/package.json` - Updated description

---

## 🎯 Summary

**Before:** Relworx (2-step async, fees, MTN+Airtel)  
**After:** Marz Pay (1-step sync, 0% fees, MTN only)

**New Features:**
- ✅ Phone verification before purchase
- ✅ Shows registered name confirmation
- ✅ Better error messages
- ✅ Synchronous processing (instant results)

**Your UI:** No changes - works exactly the same!

---

## ✨ Ready to Go!

1. Test locally: `cd proxy && npm start` + `flutter run -d chrome`
2. Deploy: Push to Git, Render auto-deploys
3. Update env vars on Render (remove Relworx)
4. Test production purchase

🎉 **You're all set!**

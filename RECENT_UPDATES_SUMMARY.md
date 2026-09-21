# Recent Updates Summary — September 19, 2026

---

## 🌍 Multi-Country Payments — 12 African Markets

**The biggest update yet.** SACCOPLUS payments now work across 12 African countries via MarzPay — no new payment engine, just a clean extension of the existing Uganda system.

### Countries Live
🇺🇬 Uganda · 🇰🇪 Kenya · 🇷🇼 Rwanda · 🇨🇩 DRC · 🇿🇲 Zambia · 🇨🇲 Cameroon · 🇧🇯 Benin · 🇨🇮 Côte d'Ivoire · 🇬🇦 Gabon · 🇨🇬 Congo-Brazzaville · 🇸🇳 Senegal · 🇸🇱 Sierra Leone

### What Was Built

**New config layer** (`lib/core/payment_countries.dart`)
- Single source of truth for all 12 countries
- Each country has: MarzPay code, currency, dial code, phone hint, networks, min amount
- Helper methods: `formatPhone()`, `isValidPhone()`, `byCode()`, `resolveCurrency()`

**Country selector widget** (`lib/widgets/country_selector.dart`)
- Searchable bottom-sheet picker with flags and network info
- DRC shows CDF/USD currency toggle
- Compact chip variant for space-constrained layouts

**12-country marketing banner** (`lib/widgets/africa_payments_banner.dart`)
- Full dark-navy banner on farmer dashboard
- Shows all 12 country chips with flags and currencies
- "Payments powered by MarzPay" footer
- Compact version available for other screens

**Firebase service extensions** (`lib/core/firebase_service.dart`)
- `marzPayCollect()` — added `countryCode`, `currencyCode` params (defaults: `'UG'`, `'UGX'`)
- `walletDeposit()` — same country params, stored in Firestore transaction
- `walletWithdraw()` — same country params, country-aware daily limit message
- `verifyPhoneNumber()` — added `countryCode` param; gracefully returns "not available" for non-UG
- `formatPhoneForCountry()` — new E.164 formatter for any country
- `getCollectionServices()` — queries available providers per country
- `_marzPayRequest()` — added `queryParams` support for country-filtered GET endpoints

**Proxy server** (`proxy/server.js`)
- `/collect` and `/withdraw` now log country/currency in output
- Added `/collect-money/services?country=XX` endpoint
- Added `/send-money/services?country=XX` endpoint  
- Added `/withdraw-status/:uuid` endpoint
- Version bumped to v2.1.0

**Payment modals updated**
- `modern_deposit_modal.dart` — country selector, dynamic network list, country-aware phone validation, currency symbol
- `modern_withdraw_modal.dart` — same
- `modern_send_money_modal.dart` — same

**Transaction history** (`transaction_history_screen.dart`)
- `_Txn` model now carries `country` + `currency` fields
- Transaction tiles show correct currency per transaction
- Detail bottom-sheet shows Country/Currency rows for non-UG transactions
- PDF export has Country column

### What Was NOT Changed
- Uganda payment flow — identical, unchanged
- Wallet architecture
- Bank transfer (Uganda-primary per MarzPay docs)
- Phone verification (Uganda-primary; graceful fallback for other countries)
- Firebase auth
- Existing transaction records (country/currency default to UG/UGX when absent)
- MarzPay authentication
- Render proxy architecture
- Any unrelated screens

### Deployment
```bash
# 1. Deploy proxy
cd proxy && git add server.js && git commit -m "feat: multi-country v2.1.0" && git push

# 2. Rebuild app
flutter clean && flutter pub get && flutter build apk --release
```

**Full details:** `MULTI_COUNTRY_PAYMENTS.md`

---

## Previous Updates (May 2, 2026)

### ✅ Bank Transfer Bug Fix
- Fixed MarzPay bank-transfer response parsing
- Account validation now optional (warning instead of blocking)
- Improved proxy logging and error handling

**Files:** `lib/core/firebase_service.dart`, `lib/screens/farmer/bank_transfer_screen.dart`, `render_proxy/server.js`  
**Docs:** `BANK_TRANSFER_BUG_FIX.md`

### 🆕 Phone Number Verification
- Verify recipient name before wallet withdrawal
- Works with MTN/Airtel Uganda numbers
- Optional — doesn't block if verification fails

**Files:** `lib/core/firebase_service.dart`, `lib/screens/farmer/wallet_screen.dart`, `render_proxy/server.js`  
**Docs:** `PHONE_VERIFICATION_INTEGRATION.md`

---

**Updated by:** Kiro AI Assistant  
**Date:** September 19, 2026  
**Status:** ✅ Ready for Deployment

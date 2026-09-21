# SACCOPLUS — Multi-Country Payments Update

**Date:** September 19, 2026  
**Status:** ✅ Complete  
**Author:** Kiro AI Assistant

---

## Overview

Expanded the existing MarzPay payment system from **Uganda-only** to all **12 supported African markets**, without rebuilding anything. The Uganda flow is unchanged and remains the default.

---

## Countries Now Supported

| Flag | Country | Code | Currency | Networks |
|------|---------|------|----------|----------|
| 🇺🇬 | Uganda | UG | UGX | MTN, Airtel |
| 🇧🇯 | Benin | BJ | XOF (CFA) | MTN, Moov |
| 🇨🇲 | Cameroon | CM | XAF (FCFA) | MTN, Orange |
| 🇨🇬 | Congo-Brazzaville | CG | XAF (FCFA) | MTN, Airtel |
| 🇨🇮 | Côte d'Ivoire | CI | XOF (CFA) | MTN, Orange |
| 🇨🇩 | DR Congo | CD | CDF / USD | Vodacom, Airtel, Orange |
| 🇬🇦 | Gabon | GA | XAF (FCFA) | Airtel |
| 🇰🇪 | Kenya | KE | KES | M-Pesa |
| 🇷🇼 | Rwanda | RW | RWF | MTN, Airtel |
| 🇸🇳 | Senegal | SN | XOF (CFA) | Orange, Free |
| 🇸🇱 | Sierra Leone | SL | SLE | Orange |
| 🇿🇲 | Zambia | ZM | ZMW | MTN, Airtel, Zamtel |

> DRC supports two currencies: **CDF** (default) and **USD**. The user selects which currency when DRC is chosen.

---

## What Was Changed

### New Files

| File | Purpose |
|------|---------|
| `lib/core/payment_countries.dart` | Single source of truth for all 12 countries — codes, currencies, dial codes, phone formats, networks, min amounts |
| `lib/widgets/country_selector.dart` | Reusable country picker widget (card + compact chip + searchable bottom-sheet) |
| `lib/widgets/africa_payments_banner.dart` | 12-country marketing banner widget placed on the farmer dashboard |

### Modified Files

| File | What Changed |
|------|-------------|
| `lib/core/firebase_service.dart` | `marzPayCollect`, `walletDeposit`, `walletWithdraw` now accept `countryCode` + `currencyCode` (default `'UG'`/`'UGX'`). `verifyPhoneNumber` accepts `countryCode`. `formatPhoneForCountry()` added. `_marzPayRequest` accepts `queryParams`. `getCollectionServices()` added. Transaction records now write `country` + `currency` fields. |
| `proxy/server.js` | `/collect` and `/withdraw` routes log country/currency. Added `/collect-money/services`, `/send-money/services`, and `/withdraw-status/:uuid` endpoints. Version bumped to v2.1.0. |
| `lib/screens/farmer/modern_deposit_modal.dart` | Country selector added (Uganda default). Dynamic network list per country. Phone validation is country-aware. Currency symbol dynamic. Passes `countryCode`/`currencyCode` to deposit. |
| `lib/screens/farmer/modern_withdraw_modal.dart` | Same country-awareness as deposit. Withdrawal passes country/currency to MarzPay via firebase_service. |
| `lib/screens/farmer/modern_send_money_modal.dart` | Same country-awareness. Send money passes country/currency. |
| `lib/screens/farmer/transaction_history_screen.dart` | `_Txn` model has `country`+`currency` fields. Transaction tiles, detail sheet, and PDF export show correct currency per transaction. |
| `lib/screens/farmer/farmer_dashboard.dart` | `AfricaPaymentsBanner` inserted above Recent Activity section. |
| `lib/screens/farmer/bank_transfer_screen.dart` | Added comment — bank transfer remains Uganda-primary per MarzPay docs. |
| `test/widget_test.dart` | Fixed stale default Flutter template test (had invalid `MyApp` reference). |

---

## Architecture

The change follows a **single-layer extension** pattern:

```
User selects country
       ↓
CountrySelector widget (lib/widgets/country_selector.dart)
       ↓
Modal (deposit / withdraw / send)
  - validates phone for selected country
  - passes countryCode + currencyCode
       ↓
FirebaseService.walletDeposit / walletWithdraw
  - passes country + currency to marzPayCollect / walletWithdraw
  - records country + currency in Firestore transaction
       ↓
Render Proxy (proxy/server.js)
  - forwards full req.body → MarzPay
  - country + currency already in body
       ↓
MarzPay API
  - routes to correct provider for the country
```

---

## Key Design Decisions

1. **Uganda default preserved** — all existing callers work unchanged (countryCode defaults to `'UG'`).
2. **No duplicate payment system** — same `marzPayCollect`/`walletWithdraw` methods, just country-aware params.
3. **Phone verification Uganda-only** — MarzPay verification API is Uganda-primary. For other countries the UI shows a graceful "not available yet" message and allows proceeding.
4. **Bank transfer Uganda-only** — MarzPay bank-transfer API is Uganda-primary. No country selector added there.
5. **DRC dual-currency** — CDF is the default; a USD toggle appears when DRC is selected.
6. **Existing transactions unaffected** — `country`/`currency` fields default to `'UG'`/`'UGX'` when absent, so all legacy records still display correctly.

---

## Testing Checklist

### Uganda regression (must pass)
- [ ] Uganda still selects by default
- [ ] UGX shown throughout deposit/withdraw/send flows
- [ ] MTN + Airtel networks shown
- [ ] Phone validation accepts +256 numbers
- [ ] Phone verification still works (Uganda only)
- [ ] Bank transfer unchanged
- [ ] Existing transaction history shows correct amounts
- [ ] Wallet deposit → MarzPay → poll → confirm still works

### New markets (verify config generation)
- [ ] Kenya — KES, M-Pesa, +254
- [ ] Rwanda — RWF, MTN/Airtel, +250
- [ ] DRC — CDF/USD toggle, Vodacom/Airtel/Orange, +243
- [ ] Zambia — ZMW, MTN/Airtel/Zamtel, +260
- [ ] Cameroon — XAF, MTN/Orange, +237
- [ ] Benin — XOF, MTN/Moov, +229
- [ ] Côte d'Ivoire — XOF, MTN/Orange, +225
- [ ] Gabon — XAF, Airtel, +241
- [ ] Congo-Brazzaville — XAF, MTN/Airtel, +242
- [ ] Senegal — XOF, Orange/Free, +221
- [ ] Sierra Leone — SLE, Orange, +232

---

## Deployment

### 1. Deploy Proxy Server
```bash
cd proxy
git add server.js
git commit -m "feat: multi-country support v2.1.0 - 12 African markets"
git push
```
Wait for Render to redeploy automatically.

### 2. Rebuild Flutter App
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 3. Verify
- Check Render logs show country in `[COLLECT]` and `[WITHDRAW]` lines
- Test Uganda deposit end-to-end first
- Test Kenya/Rwanda config generation

---

## MarzPay Requirements (per market)

Before a new market goes live, the MarzPay business account must:
1. Subscribe to the collection service for that country in the MarzPay marketplace
2. Subscribe to the disbursement service for that country  
3. Ensure the server IP is whitelisted for disbursements
4. Fund the country-specific wallet

**Payments powered by MarzPay** — SACCOPLUS is not the payment processor.

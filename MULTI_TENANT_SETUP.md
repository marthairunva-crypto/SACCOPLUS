# SACCOPLUS Multi-Tenant Setup Guide
**Version:** 1.0 — September 2026  
**Status:** ✅ Implementation Complete

---

## What Was Built

SACCOPLUS is now a **multi-tenant white-label SACCO platform**. One codebase supports unlimited SACCOs, each with isolated data and dynamic branding.

```
ONE SACCOPLUS PLATFORM
         │
    ┌────┴────┐
    │         │
 SACCO A   SACCO B   (+ unlimited more)
    │         │
 members   members
 loans     loans
 savings   savings
```

---

## Architecture

**Approach:** `tenantId` field on every Firestore document + query scoping.

Every document now carries:
```json
{ "tenantId": "sacco_001", ...other fields }
```

Every admin query filters by:
```dart
.where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
```

This is **additive and non-destructive** — existing data continues to work with `tenantId = 'sacco_001'`.

---

## Files Changed

| File | What Changed |
|------|-------------|
| `lib/core/sacco_profile.dart` | **NEW** — SaccoProfile model with all SACCO fields |
| `lib/core/sacco_service.dart` | **NEW** — Tenant management: load/create/update SACCOs, dynamic ThemeData |
| `lib/core/firebase_service.dart` | Added `sessionTenantId`, wired tenantId into all writes and admin queries, dynamic SMS sender |
| `lib/main.dart` | Dynamic theme from `SaccoService.buildTheme()` |
| `lib/screens/auth/login_screen.dart` | Calls `SaccoService.loadForUser()` after login, routes super_admin to PlatformAdminScreen |
| `lib/screens/admin/platform_admin_screen.dart` | **NEW** — Platform Super Admin SACCO management hub |
| `lib/screens/admin/sacco_settings_screen.dart` | Now reads/writes to `saccoplus-saccos/{tenantId}` instead of `saccoplus-saccos/config` |
| `firestore.rules` | Added multi-tenant documentation comment |

---

## Step 1 — Migrate Existing Data to `sacco_001`

Run this **once** from the Firestore console or a Node.js script to assign `tenantId: "sacco_001"` to all existing records that don't have one.

### Option A — Firestore Console (manual, small datasets)

For each collection below, open the Firestore console and use the bulk edit if available, or run the Node script below.

### Option B — Node.js Migration Script

```javascript
// save as migrate_tenant.js, run with: node migrate_tenant.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const TENANT_ID = 'sacco_001';

const COLLECTIONS = [
  'saccoplus-members',
  'saccoplus-loans',
  'saccoplus-repayments',
  'saccoplus-guarantors',
  'saccoplus-savings',
  'saccoplus-savings-transactions',
  'saccoplus-fixed-deposits',
  'saccoplus-shares',
  'saccoplus-wallets',
  'saccoplus-wallet-transactions',
  'saccoplus-airtime-transactions',
  'saccoplus-notifications',
  'saccoplus-audit-logs',
];

async function migrateCollection(colName) {
  const snap = await db.collection(colName).get();
  let updated = 0;
  const batch_size = 400;
  let batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    if (!doc.data().tenantId) {
      batch.update(doc.ref, { tenantId: TENANT_ID });
      count++;
      if (count % batch_size === 0) {
        await batch.commit();
        batch = db.batch();
        console.log(`  ${colName}: committed ${count} docs`);
      }
      updated++;
    }
  }
  if (count % batch_size !== 0) await batch.commit();
  console.log(`✅ ${colName}: ${updated} docs updated`);
}

async function main() {
  console.log(`Migrating all records to tenantId = "${TENANT_ID}"...`);
  for (const col of COLLECTIONS) {
    await migrateCollection(col);
  }
  // Also create the sacco_001 profile doc if it doesn't exist
  const saccoRef = db.collection('saccoplus-saccos').doc(TENANT_ID);
  const saccoDoc = await saccoRef.get();
  if (!saccoDoc.exists) {
    // Copy from legacy 'config' doc if available
    const configDoc = await db.collection('saccoplus-saccos').doc('config').get();
    const base = configDoc.exists ? configDoc.data() : {};
    await saccoRef.set({
      ...base,
      tenantId:  TENANT_ID,
      saccoName: base.name || base.saccoName || 'SACCOPLUS Pro',
      status:    'active',
      country:   base.country  || 'UG',
      currency:  base.currency || 'UGX',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('✅ saccoplus-saccos/sacco_001 created');
  }
  console.log('\n🎉 Migration complete!');
}

main().catch(console.error);
```

---

## Step 2 — Create the Platform Super Admin

Run once in your terminal or Firestore console:

```javascript
// In Firestore console → saccoplus-members → Add document
// Doc ID: phone_256XXXXXXXXX (your phone)
{
  "uid":          "phone_256XXXXXXXXX",
  "name":         "Platform Admin",
  "phone":        "256XXXXXXXXX",
  "role":         "super_admin",
  "tenantId":     "sacco_001",
  "memberStatus": "Active"
}
```

Then set the PIN via the app's "Forgot PIN" flow or directly:
```javascript
// In saccoplus-members/phone_256XXXXXXXXX
// Add field: pinHash = sha256("1234") 
// Use the actual hash from the app's savePin() method
```

---

## Step 3 — Onboard a New SACCO (Zero Code)

1. Log in as `super_admin`
2. You land on **Platform Admin** screen
3. Tap **+ New SACCO**
4. Fill in:
   - SACCO Name (required)
   - Short Name
   - Registration Number
   - Phone / Email / Address
   - Country & Currency
   - Admin Name + Phone (optional — creates their account)
5. Tap **Create SACCO**
6. The new SACCO gets a unique `tenantId` (e.g. `mbarara_united_sacco_1726789012345`)
7. Tap **Enter** on the SACCO card to manage it as admin
8. The admin can log in and set their PIN via "Forgot PIN"

---

## Step 4 — Member Registration for a Specific SACCO

Currently, the registration screen creates members with `tenantId = sessionTenantId`. To onboard members to a specific SACCO:

**Option A:** The SACCO admin registers members from the admin dashboard.

**Option B:** Share a SACCO-specific login link (future feature — can pre-populate tenantId from URL parameter).

**Option C:** The platform admin creates member accounts from the Platform Admin screen.

---

## Data Isolation Verification

After migration, verify:

```
SACCO A admin logs in → sees only SACCO A members/loans/savings
SACCO B admin logs in → sees only SACCO B members/loans/savings
```

Test by:
1. Creating two SACCOs from Platform Admin
2. Creating one member in each
3. Logging in as each SACCO's admin
4. Confirming member lists are separate

---

## Dynamic Branding

Each SACCO can have:
- Custom primary colour
- Custom accent colour
- Custom logo URL
- Custom name/tagline

These are loaded at login and applied to the entire app theme automatically.

To update branding: SACCO Settings → Save → theme refreshes on next login.

---

## Existing SACCO (sacco_001) — No Disruption

- All existing members, loans, savings, and transactions continue working
- After running the migration script, they all carry `tenantId: "sacco_001"`
- The existing admin login works exactly as before
- Uganda payments, wallet, bank transfer — all unchanged

---

## Composite Indexes Required

After deploying, Firestore will prompt for composite indexes when queries run for the first time. The required indexes are:

| Collection | Fields |
|---|---|
| `saccoplus-loans` | `tenantId ASC`, `createdAt DESC` |
| `saccoplus-loans` | `tenantId ASC`, `status ASC`, `createdAt DESC` |
| `saccoplus-repayments` | `tenantId ASC`, `paidAt DESC` |
| `saccoplus-members` | `role ASC`, `tenantId ASC` |
| `saccoplus-notifications` | `tenantId ASC`, `createdAt DESC` |

Create these in the Firebase Console → Firestore → Indexes → Composite, or let the app create them automatically from the error links in the debug console.

---

## Powered by SACCOPLUS
*Infinitech Innovations Ltd — Mbarara, Uganda*

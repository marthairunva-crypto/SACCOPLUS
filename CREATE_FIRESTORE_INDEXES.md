# 🔥 CREATE FIRESTORE INDEXES - 5 MINUTE GUIDE

## Step 1: Open Firebase Console
**CLICK THIS LINK:** https://console.firebase.google.com/project/mwiza-projects/firestore/indexes

## Step 2: Click "Create Index" Button
You'll see a button that says **"Create Index"** - click it

## Step 3: Fill in First Index

**Collection ID:** saccoplus-teller-transactions

Click **"Add field"** twice and fill:
- Field 1: `tenantId` → Select **Ascending**
- Field 2: `timestamp` → Select **Descending**

Click **"Create"**

---

## Step 4: Repeat for These 7 More Indexes

### Index 2:
- Collection: `loanRepayments`
- Field 1: `tenantId` (Ascending)
- Field 2: `createdAt` (Descending)

### Index 3:
- Collection: `payments`
- Field 1: `tenantId` (Ascending)
- Field 2: `createdAt` (Descending)

### Index 4:
- Collection: `mobileMoneyTransactions`
- Field 1: `tenantId` (Ascending)
- Field 2: `createdAt` (Descending)

### Index 5:
- Collection: `bankTransfers`
- Field 1: `tenantId` (Ascending)
- Field 2: `createdAt` (Descending)

### Index 6:
- Collection: `notifications`
- Field 1: `tenantId` (Ascending)
- Field 2: `createdAt` (Descending)

### Index 7:
- Collection: `fixedDeposits`
- Field 1: `tenantId` (Ascending)
- Field 2: `createdAt` (Descending)

### Index 8:
- Collection: `saccoplus-teller-transactions`
- Field 1: `tenantId` (Ascending)
- Field 2: `timestamp` (Ascending)

---

## Step 5: Wait 2-5 Minutes

Each index will show "Building..." status. Wait until all show "Enabled".

## Step 6: Hot Restart Flutter

Press **R** in your terminal where Flutter is running.

---

## ✅ Done!

Now check your app - loaders should be gone and data should load! 🎉

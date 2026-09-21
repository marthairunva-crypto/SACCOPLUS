# 🚀 SACCOPLUS - Quick Setup Guide

## 📦 Building Windows Desktop App

### Requirements:
- ✅ Flutter SDK
- ✅ Visual Studio 2022 with C++ tools
- ✅ Firebase project configured

### Build Commands:
```bash
cd C:\SACCOPLUS
flutter clean
flutter pub get
flutter build windows --release
```

### Output Location:
```
C:\SACCOPLUS\build\windows\x64\runner\Release\saccoplus.exe
```

### Distribution:
Copy the entire `Release` folder to distribute your app.

---

## 🏢 Creating a New SACCO

### Step 1: Login as Platform Admin
- **Phone:** `256778474686` (or your super admin phone)
- **PIN:** Your 4-digit PIN

### Step 2: Go to Platform Admin Screen
- Navigate to Admin section
- Click "Platform Admin"

### Step 3: Create SACCO
Click **"Create New SACCO"** and fill in:

```
SACCO Name:      MBADIFA SACCO
Short Name:      MBA
Tagline:         Your trusted savings partner
Registration No: REG/2024/001
Phone:           0700000000
Email:           info@mbadifa.com
Address:         Kampala, Uganda
Country:         Uganda (UG)
Currency:        UGX

Admin Name:      John Doe
Admin Phone:     0700000001
```

### Step 4: SACCO Created!
- Tenant ID generated automatically
- Admin user created automatically
- Admin can now login with their phone

---

## 👤 Admin User Login

After creating a SACCO, the admin can login:

### Login Credentials:
- **Phone:** The phone number you provided (e.g., `0700000001`)
- **Account Number:** Generated automatically (e.g., `60000001`)
- **PIN:** Set on first login

### Admin Features:
- ✅ Create and manage members
- ✅ Approve/reject loans
- ✅ View all transactions
- ✅ Generate reports
- ✅ Send SMS notifications
- ✅ Generate account numbers
- ✅ Manage SACCO settings

---

## 🔢 Account Numbers

### Format:
8-digit numeric: `60000001`, `60000002`, `60000003`, etc.

### Generate Account Numbers:
1. Login as admin
2. Go to Migration screen
3. Click "Generate Account Numbers"
4. All members without account numbers get one

### Manual Assignment:
Account numbers are auto-generated during member registration.

---

## 📱 Member Features

### Registration:
- Phone number (primary identifier)
- 4-digit PIN
- Personal details
- Auto-generated account number

### Login Options:
- Login with **Phone Number** + PIN
- Login with **Account Number** + PIN

### Features:
- ✅ Apply for loans
- ✅ Make savings deposits
- ✅ Buy shares
- ✅ Check wallet balance
- ✅ View transaction history
- ✅ Receive SMS notifications

---

## 📊 Reports Available

1. **Monthly Statement** - Overview of all activities
2. **Loan Report** - All loan applications and status
3. **Savings Report** - Member savings summaries
4. **Shares Report** - Share capital distribution
5. **Wallet Report** - Wallet balances and transactions
6. **Members Report** - Complete member directory
7. **Balance Sheet** - Assets, Liabilities, Equity
8. **Trial Balance** - Debit and Credit accounts
9. **Annual Report** - Yearly performance
10. **Loan Portfolio** - Detailed loan tracking

---

## 🔔 SMS Notifications

### Configuration:
- **Provider:** EgoSMS
- **Credentials:** Configured in Firebase
- **Sender ID:** Dynamic per SACCO (e.g., MBADIFA)

### Use Cases:
- Loan approval/rejection
- Payment confirmations
- Balance updates
- Important announcements

---

## 🔧 Troubleshooting

### "Visual Studio not found"
Install Visual Studio 2022 with "Desktop development with C++" workload.

### "Firebase error"
Check `firebase-credentials.json` is in the project root.

### "Account number not generated"
Run the account number generator from Migration screen.

### "SMS not sending"
Verify EgoSMS credentials in Firebase configuration.

---

## 📞 Support

For technical support, contact the development team.

---

## 🎉 You're Ready!

Your SACCOPLUS system is now fully configured and ready for production use!

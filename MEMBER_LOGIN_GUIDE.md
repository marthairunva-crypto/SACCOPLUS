# MEMBER LOGIN GUIDE - How Members Access the System

## Overview
**Members use the SAME login screen as admins/tellers!** There's one unified login system - `ProfessionalLoginScreen`.

## 🔐 Login Flow

### Step 1: Member Activation (Admin Task)
Before members can login, an admin must activate their accounts:

1. **Navigate to:** `Members > Member Activation`
2. **View:** List of members who need activation (no login credentials yet)
3. **Click:** "Activate All Members" button
4. **What happens:**
   - System creates login credentials for each member
   - **Username:** Member's phone number (e.g., 256712345678)
   - **Temporary Password:** Last 4 digits of their account number
   - Optional: SMS sent to member with their credentials
5. **SMS Message Example:**
   ```
   Welcome to MBADIFA SACCO! 
   Your login details:
   Username: 256712345678
   Temp Password: 0053 (last 4 digits of your account)
   Please change your password on first login.
   ```

### Step 2: Member First Login
1. Member opens the app → sees the same **Professional Login Screen**
2. Enters:
   - **Username:** Their phone number (256XXXXXXXXX)
   - **PIN:** Last 4 digits of account number (e.g., 0053)
3. System detects it's a temporary password
4. Redirects to **First Login Setup Screen**
5. Member must:
   - Verify their phone number
   - Create a new 4-digit PIN
   - Confirm the new PIN
6. After setup → Member is logged into their dashboard

### Step 3: Regular Login (After Setup)
1. Member opens app
2. Enters:
   - **Username:** Phone number
   - **New PIN:** Their custom 4-digit PIN (set during first login)
3. → Logged into Member Dashboard

## 🏠 What Members See After Login

### Member Dashboard Features:
- **Account Summary:** Savings, Shares, Loans balances
- **Transactions:** Recent deposits, withdrawals, loan payments
- **Loan Management:**
  - View active loans
  - See payment schedule
  - Outstanding balance
  - Payment history
- **Savings:** View savings balance and transaction history
- **Mobile Money:** Deposit funds via Mobile Money
- **Bank Transfer:** Transfer from bank account
- **Profile:** View personal information

## 👥 User Roles in the System

### 1. **Admin**
- Full system access
- Activate members
- Manage all features
- View reports

### 2. **Teller**
- Process transactions (deposits, withdrawals, loan payments)
- Record repayments
- View member information
- Limited admin features

### 3. **Member/Farmer**
- View their own accounts
- See loan details
- Request mobile money deposits
- Check balances
- View transaction history

## 🔄 Current Login System

**ONE LOGIN SCREEN FOR ALL USERS:**
```
App Startup
    ↓
Splash Screen (8 seconds)
    ↓
Professional Login Screen
    ↓
    ├─→ Admin/Teller (direct to dashboard)
    ├─→ Member (first time) → First Login Setup → Member Dashboard
    └─→ Member (returning) → Member Dashboard
```

## 📱 How to Test Member Login

### Test Steps:
1. **As Admin:**
   - Go to Member Activation screen
   - Activate a member (e.g., KOMUHANGI PEACE)
   - Note their account number (e.g., mbadifa_046053)
   - Last 4 digits: 6053

2. **Logout and Login as Member:**
   - Username: Member's phone (from member profile)
   - PIN: 6053 (last 4 digits)
   - You'll be forced to create a new PIN
   - After setup, you'll see the Member Dashboard

3. **Future Logins:**
   - Use same phone number
   - Use your custom PIN

## ⚙️ Technical Details

### Collections Used:
- **Authentication:** Firebase Auth
- **User Profiles:** `saccoplus-users` collection
  - Fields: `phone`, `role`, `tempPassword`, `firstLoginComplete`
  
### Member Activation Process:
```dart
// Creates Firebase Auth account
FirebaseAuth.createUserWithEmailAndPassword()

// Stores temporary credentials
saccoplus-users/{uid} {
  phone: "256712345678",
  role: "member",
  tempPassword: "6053", // last 4 digits
  firstLoginComplete: false,
  accountNumber: "mbadifa_046053"
}
```

### First Login Detection:
```dart
if (profile['tempPassword'] != null && 
    profile['firstLoginComplete'] != true) {
  // Redirect to First Login Setup
}
```

## 🚨 Important Notes

1. **No Separate Member App:** Members use the same app, same login screen
2. **Role-Based Navigation:** System shows different dashboards based on user role
3. **Security:** Members must change temporary password on first login
4. **SMS Optional:** SMS sending can be toggled on/off during activation
5. **Account Number Required:** Members need their account number's last 4 digits

## 📞 Member Support

**If member can't login:**
1. Check if account is activated (Member Activation screen)
2. Verify phone number format (must include country code: 256XXXXXXXXX)
3. Confirm account number (check Member 360 or member list)
4. Reset if needed: Deactivate and reactivate member

## 🎯 Demo Script for Presentation

**"Let me show you how members login..."**

1. "First, admin activates members here" → Show Member Activation screen
2. "Click Activate All - system creates login credentials"
3. "Member receives SMS with username and temporary password"
4. "Now let me logout and login as a member..." → Logout
5. "I enter the phone number and last 4 digits..." → Login
6. "First time - I must create a new PIN" → First Login Setup
7. "Now I see the member dashboard with my accounts!" → Member Dashboard
8. "Member can view loans, savings, make deposits..."

---

**The key message: ONE APP, MULTIPLE ROLES, SAME LOGIN SCREEN!**

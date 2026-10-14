# Requirements Document

## Introduction

The Savings Withdrawal feature allows SACCOPLUS Pro members to withdraw funds from their savings balance (Voluntary or Compulsory) to one of two destinations: their in-app wallet (instant, no mobile money required) or directly to a mobile money number via MarzPay. The feature mirrors the security model of the existing savings deposit flow — requiring both PIN and OTP verification before any funds are moved. A service charge is applied on mobile money withdrawals. The savings balance is immediately deducted upon a successful, verified withdrawal. A new "Withdraw" tab is added to the existing Savings screen alongside Overview, Transactions, and Deposit.

---

## Glossary

- **Savings_Withdrawal_Screen**: The new "Withdraw" tab added as the 4th tab in the existing Savings screen.
- **Withdrawal_Service**: The backend logic in `FirebaseService` responsible for executing savings withdrawals, verifying security credentials, updating balances, and recording transactions.
- **Savings_Account**: The Firestore document in `saccoplus-savings` representing a member's savings balances (voluntary and compulsory).
- **Savings_Transaction**: A record written to `saccoplus-savings-transactions` documenting a withdrawal event.
- **Wallet**: The Firestore document in `saccoplus-wallets` representing a member's in-app wallet balance.
- **Wallet_Transaction**: A record written to `saccoplus-wallet-transactions` documenting a credit to the wallet.
- **MarzPay**: The third-party mobile money disbursement API used to send funds to a phone number.
- **PIN**: The member's 4-digit security PIN stored as a hash in Firestore.
- **OTP**: A 6-digit one-time password sent to the member's registered phone number via EgoSMS.
- **Service_Charge**: A fee calculated as a percentage of the withdrawal amount, subject to a minimum charge floor, applied only on mobile money withdrawals.
- **Withdrawal_Destination**: The target of a savings withdrawal — either `To Wallet` or `To Mobile Money`.
- **Savings_Type**: The category of savings being withdrawn — either `Voluntary` or `Compulsory`.

---

## Requirements

### Requirement 1: Withdraw Tab in Savings Screen

**User Story:** As a SACCOPLUS Pro member, I want a dedicated Withdraw tab in my Savings screen, so that I can initiate a savings withdrawal without leaving the savings section.

#### Acceptance Criteria

1. THE Savings_Withdrawal_Screen SHALL be presented as the 4th tab labelled "Withdraw" in the existing Savings screen `TabController`, after the existing Overview, Transactions, and Deposit tabs.
2. WHEN the member navigates to the Withdraw tab, THE Savings_Withdrawal_Screen SHALL display the member's current total savings balance, voluntary balance, and compulsory balance.
3. WHEN the member's total savings balance is zero, THE Savings_Withdrawal_Screen SHALL display an informational message indicating there are no funds available to withdraw.

---

### Requirement 2: Withdrawal Destination Selection

**User Story:** As a member, I want to choose where my withdrawn savings go — to my wallet or to mobile money — so that I can access funds in the way that suits me best.

#### Acceptance Criteria

1. THE Savings_Withdrawal_Screen SHALL present two mutually exclusive destination options: "To Wallet" and "To Mobile Money".
2. WHEN the member selects "To Wallet", THE Savings_Withdrawal_Screen SHALL hide the mobile money phone number input field.
3. WHEN the member selects "To Mobile Money", THE Savings_Withdrawal_Screen SHALL display a phone number input field pre-populated with the member's registered phone number in `+256XXXXXXXXX` format.
4. THE Savings_Withdrawal_Screen SHALL default the selected destination to "To Wallet" on initial render.

---

### Requirement 3: Savings Type Selection

**User Story:** As a member, I want to specify which savings type (Voluntary or Compulsory) I am withdrawing from, so that the correct balance is debited.

#### Acceptance Criteria

1. THE Savings_Withdrawal_Screen SHALL present two mutually exclusive savings type options: "Voluntary" and "Compulsory".
2. WHEN the member selects a Savings_Type, THE Savings_Withdrawal_Screen SHALL display the available balance for that Savings_Type.
3. IF the member enters an amount greater than the available balance for the selected Savings_Type, THEN THE Savings_Withdrawal_Screen SHALL display an inline error message and prevent the OTP send step from proceeding.

---

### Requirement 4: Service Charge Calculation and Display

**User Story:** As a member, I want to see the service charge before confirming a withdrawal, so that I know the exact cost of the transaction.

#### Acceptance Criteria

1. WHEN the member selects "To Mobile Money" and enters a valid amount, THE Savings_Withdrawal_Screen SHALL compute the service charge as `ceil(amount × walletWithdrawChargePercent)` clamped to a minimum of `walletMinCharge` UGX.
2. WHEN the member selects "To Wallet", THE Savings_Withdrawal_Screen SHALL display a service charge of UGX 0 (no charge applies for wallet transfers).
3. WHEN a valid amount is entered, THE Savings_Withdrawal_Screen SHALL display a charges summary showing: withdrawal amount, service charge, and total deducted from savings.
4. THE Savings_Withdrawal_Screen SHALL update the charges summary in real time as the member changes the amount.

---

### Requirement 5: PIN and OTP Security Verification

**User Story:** As a member, I want my savings withdrawal to require PIN and OTP verification, so that my savings are protected from unauthorised access.

#### Acceptance Criteria

1. WHEN the member taps "Send OTP & Continue", THE Savings_Withdrawal_Screen SHALL validate that the entered amount is at least UGX 1,000 before sending the OTP.
2. WHEN validation passes, THE Withdrawal_Service SHALL send a 6-digit OTP to the member's registered phone number via EgoSMS.
3. WHEN the OTP is sent successfully, THE Savings_Withdrawal_Screen SHALL reveal the PIN input field and OTP input field.
4. IF the OTP cannot be sent, THEN THE Savings_Withdrawal_Screen SHALL display an error message and remain on the form step.
5. THE Savings_Withdrawal_Screen SHALL enforce a maximum length of 4 digits for the PIN field and 6 digits for the OTP field.

---

### Requirement 6: Withdrawal Execution — To Wallet

**User Story:** As a member, I want to transfer my savings directly to my wallet instantly, so that I can use the funds for other in-app transactions without mobile money fees.

#### Acceptance Criteria

1. WHEN the member submits a "To Wallet" withdrawal with a valid PIN and OTP, THE Withdrawal_Service SHALL verify the PIN against the stored hash using `FirebaseService.verifyPin`.
2. WHEN the PIN is valid, THE Withdrawal_Service SHALL verify the OTP against the in-memory OTP store.
3. WHEN both PIN and OTP are valid, THE Withdrawal_Service SHALL atomically, within a single Firestore batch:
   a. Decrement the member's `voluntaryBalance` or `compulsoryBalance` (and `totalBalance`) in `saccoplus-savings` by the withdrawal amount.
   b. Increment the member's `balance` in `saccoplus-wallets` by the withdrawal amount.
   c. Write a debit record to `saccoplus-savings-transactions` with `type: 'withdrawal'`, `destination: 'wallet'`, `status: 'Approved'`, `securityVerified: true`, and `verificationMethod: 'PIN+OTP'`.
   d. Write a credit record to `saccoplus-wallet-transactions` with `type: 'credit'`, `category: 'savings_withdrawal'`.
4. WHEN the batch commits successfully, THE Withdrawal_Service SHALL clear the used OTP from the in-memory store.
5. WHEN the batch commits successfully, THE Withdrawal_Service SHALL send an SMS confirmation to the member's registered phone number stating the amount withdrawn, the destination, and the updated savings balance.
6. IF the PIN is invalid, THEN THE Withdrawal_Service SHALL throw an exception with the message "Invalid PIN. Transaction cancelled for security." without modifying any balances.
7. IF the OTP is expired or invalid, THEN THE Withdrawal_Service SHALL throw an exception without modifying any balances.
8. IF the savings balance is insufficient, THEN THE Withdrawal_Service SHALL throw an exception without modifying any balances.

---

### Requirement 7: Withdrawal Execution — To Mobile Money

**User Story:** As a member, I want to withdraw my savings directly to my mobile money number, so that I can access cash without first going through my wallet.

#### Acceptance Criteria

1. WHEN the member submits a "To Mobile Money" withdrawal with a valid PIN and OTP, THE Withdrawal_Service SHALL verify the PIN and OTP using the same logic as Requirement 6, criteria 1–2.
2. WHEN both PIN and OTP are valid, THE Withdrawal_Service SHALL call `MarzPay` via the existing `_marzPayRequest` proxy to disburse the withdrawal amount (excluding the service charge) to the specified phone number.
3. WHEN MarzPay returns a success response, THE Withdrawal_Service SHALL atomically, within a single Firestore batch:
   a. Decrement the member's `voluntaryBalance` or `compulsoryBalance` (and `totalBalance`) in `saccoplus-savings` by `amount + serviceCharge`.
   b. Write a debit record to `saccoplus-savings-transactions` with `type: 'withdrawal'`, `destination: 'mobile_money'`, `charge: serviceCharge`, `totalDeducted: amount + serviceCharge`, `status: 'Approved'`, `securityVerified: true`, and `verificationMethod: 'PIN+OTP'`.
4. WHEN the batch commits successfully, THE Withdrawal_Service SHALL clear the used OTP and send an SMS confirmation to the member.
5. IF MarzPay returns a non-success response, THEN THE Withdrawal_Service SHALL throw an exception with the MarzPay error message and SHALL NOT modify any savings balances.
6. IF the PIN is invalid, THEN THE Withdrawal_Service SHALL throw an exception without calling MarzPay and without modifying any balances.
7. IF the OTP is expired or invalid, THEN THE Withdrawal_Service SHALL throw an exception without calling MarzPay and without modifying any balances.
8. IF the savings balance (including service charge) is insufficient, THEN THE Withdrawal_Service SHALL throw an exception without calling MarzPay and without modifying any balances.

---

### Requirement 8: Audit Trail

**User Story:** As a SACCO administrator, I want every savings withdrawal to be logged in the audit trail, so that I can review member activity and detect anomalies.

#### Acceptance Criteria

1. WHEN a savings withdrawal completes successfully, THE Withdrawal_Service SHALL write an audit log entry via `AuditService.log` with action `kSavingsWithdrawal`, including the amount, savings type, destination, and security level metadata.
2. THE Withdrawal_Service SHALL record `securityLevel: 'HIGH'` and `verificationMethod: 'PIN+OTP'` in every audit log entry for savings withdrawals.

---

### Requirement 9: UI Feedback and State Management

**User Story:** As a member, I want clear feedback at every step of the withdrawal process, so that I always know what is happening with my transaction.

#### Acceptance Criteria

1. WHEN a withdrawal is being processed, THE Savings_Withdrawal_Screen SHALL display a loading indicator and disable all interactive controls.
2. WHEN a withdrawal completes successfully, THE Savings_Withdrawal_Screen SHALL display a success message including the amount, destination, and updated savings balance, and SHALL invoke the parent screen's refresh callback to reload balances.
3. WHEN a withdrawal fails, THE Savings_Withdrawal_Screen SHALL display a user-friendly error message and allow the member to retry.
4. WHEN a withdrawal completes (success or failure), THE Savings_Withdrawal_Screen SHALL reset the form fields and security verification state.
5. WHEN the member has not yet sent an OTP, THE Savings_Withdrawal_Screen SHALL hide the PIN and OTP input fields.

# Till Management & Cash Handling — Requirements Specification

**Project:** MBADIFA SACCO (SACCOPLUS)  
**Feature:** Till Management with Blind Count Reconciliation  
**Version:** 1.0  
**Date:** 2026-10-06  
**Format:** EARS (Easy Approach to Requirements Syntax)

---

## 1. Introduction

This document specifies requirements for a complete till management system where every shilling of physical cash moving through the SACCO is tied to a till session, recorded in an append-only ledger, and reconciled by blind count at close. Mobile money, bank transfers, and savings-transfer transactions are recorded for audit but do not affect expected cash.

---

## 2. Functional Requirements (EARS Format)

### R1. Open a Till

**R1.1** WHEN a teller opens a till, THE SYSTEM SHALL create exactly one `open` session document in `saccoplus-till-sessions` with:
- `tillSessionId` (unique UUID)
- `tellerId` (session user ID)
- `tellerName` (session user name)
- `tenantId` (current tenant ID)
- `businessDate` (yyyy-MM-dd string derived from server timestamp in Africa/Kampala timezone)
- `openingFloat` (integer UGX provided)
- `floatIssuedBy` (supervisor/admin name)
- `status` = `'open'`
- `openedAt` (Firestore serverTimestamp)
- `totalIn` = 0
- `totalOut` = 0
- `nonCashTotal` = 0
- `txnCount` = 0

**R1.2** IF the teller already has an `open` or `pending_review` session for this tenantId, THEN THE SYSTEM SHALL refuse to open another session and display the existing session details with a message "You already have an open till session".

**R1.3** IF an `open` session exists with a `businessDate` before today's EAT business day, THEN THE SYSTEM SHALL block all new transactions (deposits, withdrawals, repayments, disbursements) and show "Yesterday's till is still open. Please close it before starting today's session."

**R1.4** WHERE the tenant setting `requireFloatApproval` is true, THE SYSTEM SHALL set initial status to `'pending_float_approval'` and require a head teller or admin to approve the float before changing status to `'open'`.

### R2. Resume After Reload

**R2.1** WHEN the Teller screen loads, THE SYSTEM SHALL query for the current teller's open session (status = `'open'` OR `'pending_review'`, tellerId = session user) and restore the UI state.

**R2.2** THE SYSTEM SHALL display live session figures via a Firestore stream that updates in real-time:
- Opening float
- Total cash in
- Total cash out  
- Expected cash (computed: `openingFloat + totalIn - totalOut`)
- Transaction count
- Non-cash total (for audit, displayed separately)

**R2.3** IF no open session is found on load, THE SYSTEM SHALL display a closed-till state with an "Open Till" button.

### R3. Gate Every Transaction

**R3.1** IF the teller has no open session (status ≠ `'open'`), THEN THE SYSTEM SHALL disable and grey out all transaction buttons (New Deposit, New Withdrawal, Record Loan Payment, Disburse Loan) and show a banner "Open your till to start accepting transactions".

**R3.2** WHEN a transaction is saved (deposit, withdrawal, loan repayment, loan disbursement), THE SYSTEM SHALL:
- Write the business record (savings transaction, repayment, etc.) and a corresponding till entry in a single Firestore batch/transaction
- Attach `tillSessionId` to the business record
- Create a till entry document in `saccoplus-till-entries` with all required fields
- Increment the session's running totals (`totalIn`, `totalOut`, `nonCashTotal`, `txnCount`) using `FieldValue.increment()`

**R3.3** IF a cash withdrawal OR cash loan disbursement amount exceeds the session's current expected cash (`openingFloat + totalIn - totalOut`), THEN THE SYSTEM SHALL block the transaction and show "Insufficient cash in till. Expected: UGX X. Request a top-up from the vault."

**R3.4** IF a transaction amount exceeds the tenant setting `tellerTxnLimit` (e.g., 5,000,000), THEN THE SYSTEM SHALL require supervisor approval before proceeding (Phase 2 feature; can show "Coming soon" message for now).

### R4. Cash vs Non-Cash

**R4.1** THE SYSTEM SHALL record till entries with `affectsCash = true` ONLY for:
- Cash deposits
- Cash withdrawals  
- Cash loan repayments
- Cash loan disbursements
- Vault top-ups (cash in)
- Vault sweeps (cash out)

**R4.2** THE SYSTEM SHALL record till entries with `affectsCash = false` for:
- Mobile money deposits
- Mobile money withdrawals
- Mobile money loan repayments
- Bank transfer deposits
- Bank loan disbursements
- Savings-to-loan transfers (internal book entry)

**R4.3** THE SYSTEM SHALL compute expected cash using ONLY entries where `affectsCash = true`.

**R4.4** THE SYSTEM SHALL display non-cash totals separately in reports and daily summaries for reconciliation against provider statements (MTN, Airtel, bank).

### R5. Vault Movements

**R5.1** WHEN a till needs more cash, THE SYSTEM SHALL allow a teller to request a vault top-up (cash in) by entering:
- Amount (integer UGX)
- Approved by (head teller/admin name or ID)
- Note (optional)

**R5.2** WHEN a till has excess cash, THE SYSTEM SHALL allow a teller to send cash to the vault (cash out) by entering:
- Amount (integer UGX)
- Approved by (head teller/admin name or ID)
- Note (optional)

**R5.3** EACH vault movement SHALL create a till entry with:
- `type` = `'vault_topup'` OR `'vault_sweep'`
- `direction` = `'in'` OR `'out'`
- `amount` (integer)
- `affectsCash` = `true`
- `approvedBy` (head teller/admin identifier)
- `note`

**R5.4** VAULT movements SHALL increment/decrement the session's `totalIn` or `totalOut` just like any other cash transaction.

**R5.5** WHEN expected cash exceeds the tenant setting `tillMaxCash` (e.g., 10,000,000), THE SYSTEM SHALL show a warning banner "Till over maximum capacity. Please sweep excess cash to the vault."

### R6. Close a Till (Blind Count)

**R6.1** WHEN closing a till, THE SYSTEM SHALL display a denomination count dialog with fields for:
- UGX 50,000 notes (count × 50000)
- UGX 20,000 notes (count × 20000)
- UGX 10,000 notes (count × 10000)
- UGX 5,000 notes (count × 5000)
- UGX 2,000 notes (count × 2000)
- UGX 1,000 notes (count × 1000)
- UGX 500 coins (count × 500)
- UGX 200 coins (count × 200)
- UGX 100 coins (count × 100)
- UGX 50 coins (count × 50)

Each with +/- buttons or direct numeric input. A live "Counted Total" updates as counts change.

**R6.2** THE SYSTEM SHALL NOT display or prefill the expected cash amount anywhere in the count dialog before the count is submitted.

**R6.3** WHEN the teller submits the count, THE SYSTEM SHALL:
- Compute `countedCash` from the denomination counts
- Retrieve the session document and recompute `expectedCash = openingFloat + totalIn - totalOut` from the current database values
- Compute `variance = countedCash - expectedCash`
- Display a result screen showing:
  - Counted: UGX X
  - Expected: UGX X  
  - Variance: UGX Y (with color: green if zero, amber if within tolerance, red if beyond)

**R6.4** IF `abs(variance) <= tillVarianceTolerance` (default 5,000 from tenant settings), THEN THE SYSTEM SHALL:
- Update the session document:
  - `status` = `'closed'`
  - `closedAt` = serverTimestamp
  - `denominations` = {...counts}
  - `countedCash` = counted total
  - `expectedCash` = expected snapshot
  - `variance` = variance amount
- Show success message "Till closed successfully. Variance: UGX Y"

**R6.5** IF `abs(variance) > tillVarianceTolerance`, THEN THE SYSTEM SHALL:
- Require the teller to enter a written reason (text field, min 10 characters)
- Update the session document:
  - `status` = `'pending_review'`
  - `closedAt` = serverTimestamp
  - `denominations` = {...counts}
  - `countedCash` = counted total
  - `expectedCash` = expected snapshot
  - `variance` = variance amount
  - `varianceReason` = entered reason
- Show message "Variance exceeds tolerance. Your till is pending review by a supervisor."
- Send in-app notification to all head tellers and admins

**R6.6** THE SYSTEM SHALL record the counted cash being handed to the vault as a till entry with `type = 'vault_sweep'`, `direction = 'out'`, `amount = countedCash`, `affectsCash = false` (already counted; this is just for audit trail).

**R6.7** A `closed` session SHALL be immutable. Any attempt to add a till entry to a closed session SHALL be rejected by Firestore security rules.

**R6.8** AT close, THE SYSTEM SHALL recompute totals from the till entries ledger (sum of all entries where `tillSessionId` = this session) and compare to the session's running totals (`totalIn`, `totalOut`, `nonCashTotal`, `txnCount`). IF they differ by more than 1 UGX (to account for rounding), THEN THE SYSTEM SHALL set `integrityWarning = true` on the session document and flag it in the supervisor review queue.

### R7. Approve Variance (Head Teller / Admin Only)

**R7.1** WHEN a head teller or admin views a `pending_review` session, THE SYSTEM SHALL display:
- Teller name
- Business date
- Counted cash
- Expected cash
- Variance amount and reason
- List of all till entries for the session

**R7.2** THE HEAD TELLER SHALL be able to approve or reject the variance with a note.

**R7.3** IF approved, THE SYSTEM SHALL update the session to `status = 'closed'`, record `reviewedBy`, `reviewedAt`, `reviewNote`.

**R7.4** IF rejected, THE SYSTEM SHALL keep `status = 'pending_review'`, record the rejection note, and send a notification to the teller to recount or investigate.

### R8. Reversals

**R8.1** WHEN a payment or transaction is reversed (from the loan details screen, transaction history, or member 360 view), THE SYSTEM SHALL:
- Create a reversing till entry in the teller's current open session with:
  - `type = 'reversal'`
  - `direction` = opposite of original (if original was 'in', reversal is 'out')
  - `amount` = original amount
  - `affectsCash` = same as original
  - `reversalOf` = original till entry ID
- Update the session's running totals accordingly

**R8.2** IF the teller does not have an open session at the time of reversal (e.g., next day), THEN THE SYSTEM SHALL:
- Still create the reversing till entry but mark it with `crossSession = true`
- Add it to a supervisor review queue with notification
- The supervisor can then assign it to a till session or handle it as a vault adjustment

**R8.3** THE ORIGINAL till entry SHALL remain untouched (append-only principle). The reversal is a separate, linked entry.

### R9. Reporting and Oversight

**R9.1** HEAD TELLERS AND ADMINS SHALL see an "All Tills" dashboard showing:
- All sessions for today (or selected date range)
- Each row: teller name, status, opening float, expected cash, transaction count, last activity time
- Visual warnings: stale sessions (> 2 hours no activity), pending review, integrity warnings

**R9.2** THE SYSTEM SHALL produce a per-session reconciliation report (printable / CSV) containing:
- Session metadata (teller, date, opening float, status)
- All till entries in chronological order (time, type, member, method, amount in/out, running expected cash)
- Totals by transaction type
- Totals by method (cash, mobile money, bank, savings transfer)
- Variance summary (if closed)

**R9.3** THE SYSTEM SHALL show variance history by teller (last 30 days or configurable period) with:
- Date, variance amount, reason, review status

**R9.4** THE DAILY SUMMARY screen SHALL:
- Offer a scope toggle: "My till" (current teller's session) OR "All tills" (all tellers for selected date)
- Split totals by method:
  - Cash: deposits, withdrawals, loan repayments, loan disbursements, vault movements
  - Mobile Money: deposits, withdrawals, loan repayments
  - Bank: deposits, disbursements
  - Savings Transfer: loan repayments (internal book entry)
- NOT combine cash and non-cash into a single "net cash flow" figure (this was a bug)

**R9.5** THE TRANSACTION HISTORY tab SHALL:
- In "My Till" scope: show only entries for the current teller's open session
- In "All Tills" scope: show entries for all tellers (admin/head_teller only)
- Allow filtering by transaction type and payment method

### R10. Integrity and Security

**R10.1** FIRESTORE SECURITY RULES SHALL enforce:
- Tellers can only create till entries if the target session is `open` and belongs to them
- Tellers can only read their own till entries
- Head tellers and admins can read all till entries for their tenant
- Till entries can never be updated or deleted (append-only)
- Closed sessions can never be modified (except by head_teller/admin for review approval)

**R10.2** THE SYSTEM SHALL log all till operations in the audit trail (`saccoplus-audit-logs`) with:
- Action: TILL_OPENED, TILL_CLOSED, TILL_ENTRY_CREATED, VARIANCE_APPROVED, etc.
- User ID, affected user ID (if applicable)
- Metadata (session ID, amount, transaction type, etc.)

---

## 3. Data Requirements

### 3.1 New Collections

**`saccoplus-till-sessions`**
```
{
  "id": "session-uuid",
  "tenantId": "saccoplus",
  "branchId": "branch-123" (optional, for multi-branch),
  "tellerId": "teller-uid",
  "tellerName": "John Doe",
  "status": "open" | "pending_review" | "closed",
  "businessDate": "2026-10-06",
  "openedAt": serverTimestamp,
  "openedBy": "teller-uid",
  "floatIssuedBy": "supervisor-name",
  "openingFloat": 500000,
  "totalIn": 1200000,
  "totalOut": 900000,
  "nonCashTotal": 300000,
  "txnCount": 24,
  "lastActivityAt": serverTimestamp,
  // At close:
  "closedAt": serverTimestamp,
  "denominations": {
    "50000": 10,
    "20000": 15,
    "10000": 5,
    // ... etc
  },
  "countedCash": 800000,
  "expectedCash": 800000,
  "variance": 0,
  "varianceReason": "Cash drawer was sticky",
  "reviewedBy": "head-teller-uid",
  "reviewedAt": serverTimestamp,
  "reviewNote": "Approved after investigation",
  "integrityWarning": false
}
```

**`saccoplus-till-entries`** (append-only ledger)
```
{
  "id": "entry-uuid",
  "tenantId": "saccoplus",
  "tillSessionId": "session-uuid",
  "tellerId": "teller-uid",
  "type": "deposit" | "withdrawal" | "loan_repayment" | "loan_disbursement" 
         | "share_purchase" | "fee" | "expense" | "vault_topup" | "vault_sweep"
         | "reversal" | "adjustment",
  "direction": "in" | "out",
  "amount": 50000,
  "affectsCash": true | false,
  "method": "Cash" | "Mobile Money" | "Bank" | "Savings Transfer",
  "refCollection": "saccoplus-savings-transactions",
  "refId": "savings-txn-id",
  "receiptNumber": "TXN-20261006-001",
  "memberId": "member-uid",
  "memberName": "Jane Doe",
  "note": "Savings deposit",
  "reversalOf": "original-entry-id" (if reversal),
  "crossSession": true (if reversal in different session),
  "approvedBy": "supervisor-name" (for vault movements),
  "createdAt": serverTimestamp,
  "createdBy": "teller-uid"
}
```

### 3.2 New Settings (in `saccoplus-settings/{tenantId}`)

```
{
  "tillVarianceTolerance": 5000,      // UGX
  "tillMaxCash": 10000000,            // UGX
  "tellerTxnLimit": 5000000,          // UGX
  "requireFloatApproval": false       // bool
}
```

### 3.3 Modified Collections

**Existing transaction collections SHALL gain a `tillSessionId` field:**
- `saccoplus-savings-transactions.tillSessionId`
- `saccoplus-repayments.tillSessionId`  
- `saccoplus-teller-transactions.tillSessionId`
- Loan disbursement records SHALL gain `tillSessionId`

---

## 4. Non-Functional Requirements

**NFR1. Performance**  
- Opening a till SHALL complete within 2 seconds
- Recording a transaction (business record + till entry) SHALL complete within 3 seconds
- Closing a till (blind count + reconciliation) SHALL complete within 5 seconds
- Loading the "All Tills" dashboard with 20 sessions SHALL complete within 2 seconds

**NFR2. Data Integrity**  
- Every till entry SHALL be immutably recorded (append-only)
- Expected cash SHALL always be recomputed from the ledger at close, never trusted from UI input
- Firestore security rules SHALL enforce append-only and role-based access

**NFR3. Usability**  
- The blind count dialog SHALL NOT show expected cash before submission
- Denomination counts SHALL be editable via +/- buttons OR direct numeric input
- Variance SHALL be color-coded (green = 0, amber = within tolerance, red = beyond)
- All money figures SHALL use tabular numerals for vertical alignment

**NFR4. Audit Trail**  
- Every till operation SHALL be logged in `saccoplus-audit-logs`
- Audit logs SHALL include user ID, action, timestamp, session ID, amount, metadata

**NFR5. Multi-Tenancy**  
- All queries SHALL filter by `tenantId`
- A teller in tenant A SHALL NOT see or modify till sessions in tenant B

**NFR6. Timezone**  
- Business dates SHALL be computed in Africa/Kampala (EAT, UTC+3)
- Server timestamps SHALL be used for all date/time recording

---

## 5. Acceptance Criteria

**AC1. Happy Path (No Variance)**  
GIVEN a teller opens a till with float 500,000  
WHEN they process cash deposits 1,200,000 and cash withdrawals 900,000  
AND they also process mobile money deposits 300,000 (non-cash)  
THEN expected cash = 500,000 + 1,200,000 - 900,000 = 800,000  
AND non-cash total = 300,000  
WHEN they close with counted 800,000  
THEN variance = 0  
AND status = 'closed'

**AC2. Variance Within Tolerance**  
GIVEN expected cash = 800,000 and tolerance = 5,000  
WHEN teller counts 795,000  
THEN variance = -5,000  
AND status = 'closed' (within tolerance)

**AC3. Variance Beyond Tolerance**  
GIVEN expected cash = 800,000 and tolerance = 5,000  
WHEN teller counts 780,000  
THEN variance = -20,000  
AND system requires reason  
AND status = 'pending_review'  
AND notification sent to head tellers

**AC4. Insufficient Cash**  
GIVEN expected cash = 800,000  
WHEN teller attempts cash withdrawal of 900,000  
THEN system blocks with "Insufficient cash in till"

**AC5. Closed Till**  
GIVEN teller has no open session  
WHEN teller attempts deposit/withdrawal/repayment  
THEN buttons are disabled  
AND banner shows "Open your till to start"

**AC6. Reload Mid-Day**  
GIVEN teller has open session with 10 transactions  
WHEN browser refreshes  
THEN same session restores  
AND all 10 transactions visible  
AND expected cash unchanged

**AC7. Duplicate Prevention**  
GIVEN teller has open session in tab A  
WHEN teller tries to open till in tab B  
THEN system shows "You already have an open till session"

**AC8. Stale Session**  
GIVEN teller opened session yesterday (businessDate = 2026-10-05)  
WHEN teller attempts deposit today (2026-10-06)  
THEN system blocks with "Yesterday's till is still open"

**AC9. Reversal**  
GIVEN teller has open session with expected cash 500,000  
WHEN admin reverses a 100,000 cash repayment  
THEN reversing till entry created (out, -100,000)  
AND expected cash drops to 400,000  
AND original till entry unchanged

**AC10. Closed Session Immutable**  
GIVEN session status = 'closed'  
WHEN attempting to add till entry  
THEN Firestore security rules reject write

**AC11. Blind Close**  
GIVEN teller closing till  
WHEN denomination count dialog opens  
THEN expected cash is NOT visible anywhere in dialog  
AND only after submission is variance computed and shown

**AC12. Integrity Check**  
GIVEN someone manually changes `totalIn` in Firestore  
WHEN teller closes till  
THEN system recomputes from ledger  
AND sets `integrityWarning = true`

---

## 6. Out of Scope (Future Phases)

- **Phase 2:** Vault management (vault balance, vault-to-vault transfers)
- **Phase 2:** Multi-currency support
- **Phase 2:** Supervisor approval workflow for large transactions (`tellerTxnLimit`)
- **Phase 2:** Cash forecasting and liquidity planning
- **Phase 2:** Integration with accounting ledger (double-entry bookkeeping)
- **Phase 3:** Biometric authentication for till open/close
- **Phase 3:** CCTV integration for security audit

---

## 7. Dependencies

- Existing `TellerService` methods SHALL be refactored to accept till session and write batch
- `LoanPaymentCashDialog` SHALL be updated to record till entry
- `LoanDisbursementService` SHALL be updated to record till entry for cash disbursements
- Firestore composite indexes SHALL be created for till queries
- Firestore security rules SHALL be deployed

---

## 8. References

- Brief: `till-management-brief.md` (provided)
- Existing code: `lib/services/teller_service.dart`, `lib/screens/admin/teller_screen.dart`
- Firebase Firestore documentation: https://firebase.google.com/docs/firestore

---

**END OF REQUIREMENTS**

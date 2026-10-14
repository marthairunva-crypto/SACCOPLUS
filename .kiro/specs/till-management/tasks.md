# Till Management & Cash Handling — Tasks & Implementation Plan

**Project:** MBADIFA SACCO (SACCOPLUS)  
**Feature:** Till Management with Blind Count Reconciliation  
**Version:** 1.0  
**Date:** 2026-10-06  
**References:** `requirements.md`, `design.md`

---

## Task Breakdown

### Phase 1: Foundation (Non-Breaking)

#### Task 1: Data Models & TillService Core
**Estimated Time:** 4 hours  
**Priority:** Critical  
**Dependencies:** None

**Files to Create:**
- `lib/services/till_service.dart` (new)

**Files to Modify:**
- `lib/core/constants.dart` (add collection names)

**Subtasks:**
1. Add collection constants to `AppConstants`:
   ```dart
   static const String tillSessionsCol = 'saccoplus-till-sessions';
   static const String tillEntriesCol = 'saccoplus-till-entries';
   ```

2. Create data classes in `till_service.dart`:
   - `TillSession` (with `fromFirestore`, `toFirestore`)
   - `TillEntryInput` (input DTO)
   - `CloseResult` (close operation result)
   - `TillClosedException` (custom exception)
   - `InsufficientCashException` (custom exception)

3. Implement core methods:
   - `getOpenSession(String tellerId)` → `Future<TillSession?>`
   - `watchOpenSession(String tellerId)` → `Stream<TillSession?>`
   - `openSession({required int openingFloat, required String floatIssuedBy})` → `Future<TillSession>`
     - Use Firestore transaction to guarantee one session per teller
     - Compute businessDate from server timestamp in EAT (UTC+3)
   - `requireOpenSession(TillSession? s)` → `void` (throws if null or not open)
   - `expectedCash(TillSession s)` → `int` (compute formula)
   - `isStaleSession(TillSession s)` → `bool` (check businessDate < today)
   - `checkSufficientCash(TillSession s, int amount)` → `void` (throws if insufficient)

4. Implement `postEntry()`:
   ```dart
   static void postEntry(WriteBatch batch, TillSession session, TillEntryInput entry)
   ```
   - Creates till entry document
   - Updates session running totals using `FieldValue.increment()`
   - Does NOT commit batch (caller commits)

**Tests:**
- Unit test: `openSession()` creates session with correct fields
- Unit test: `openSession()` throws if teller already has open session
- Unit test: `expectedCash()` computes correctly
- Unit test: `isStaleSession()` detects yesterday's session
- Unit test: `postEntry()` increments correct totals based on `affectsCash`

**Manual Verification:**
1. Open Flutter app, run till service methods in Dart console
2. Verify Firestore documents created with correct structure
3. Verify running totals increment correctly

---

#### Task 2: Settings & Role Helpers
**Estimated Time:** 1 hour  
**Priority:** High  
**Dependencies:** None

**Files to Modify:**
- `lib/core/firebase_service.dart` (add role helper)
- Create initial settings doc in Firestore

**Subtasks:**
1. Add `isHeadTeller()` helper to `FirebaseService`:
   ```dart
   static bool get isHeadTeller {
     final role = sessionProfile?['role'] as String?;
     return role == 'head_teller' || role == 'admin';
   }
   ```

2. Create/update settings document:
   - Manually add to Firestore: `saccoplus-settings/{tenantId}`
   - Add fields:
     ```json
     {
       "tillVarianceTolerance": 5000,
       "tillMaxCash": 10000000,
       "tellerTxnLimit": 5000000,
       "requireFloatApproval": false
     }
     ```

**Tests:**
- Unit test: `isHeadTeller` returns true for head_teller and admin roles
- Manual test: Verify settings doc exists in Firestore

**Manual Verification:**
1. Check Firebase Console → Firestore → `saccoplus-settings/{tenantId}`
2. Verify settings fields present with correct values

---

#### Task 3: Firestore Security Rules & Indexes
**Estimated Time:** 2 hours  
**Priority:** Critical  
**Dependencies:** Task 1

**Files to Create:**
- `firestore.indexes.json` (if doesn't exist)

**Files to Modify:**
- `firestore.rules` (add till rules)
- `firestore.indexes.json` (add till indexes)

**Subtasks:**
1. Add security rules to `firestore.rules`:
   ```javascript
   match /saccoplus-till-sessions/{sessionId} {
     allow read: if request.auth != null && sameTenant();
     allow create: if isTeller() && request.resource.data.status == 'open' &&
                     request.resource.data.tellerId == request.auth.uid;
     allow update: if resource.data.status != 'closed' &&
                     (resource.data.tellerId == request.auth.uid || isHeadTeller());
     allow delete: if false;
   }
   
   match /saccoplus-till-entries/{entryId} {
     allow read: if request.auth != null && sameTenant();
     allow create: if isTeller() && sameTenant() &&
                     sessionIsOpen(request.resource.data.tillSessionId);
     allow update, delete: if false; // Append-only
   }
   ```

2. Add helper functions to rules:
   ```javascript
   function sessionIsOpen(sessionId) {
     let session = get(/databases/$(database)/documents/saccoplus-till-sessions/$(sessionId)).data;
     return session.status == 'open';
   }
   ```

3. Add composite indexes to `firestore.indexes.json`:
   - `tenantId + tellerId + status`
   - `tenantId + businessDate + openedAt`
   - `tenantId + tillSessionId + createdAt`
   - (See design.md section 6 for complete list)

4. Deploy rules and indexes:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

**Tests:**
- Manual test: Try to create till session as non-teller (should fail)
- Manual test: Try to update closed session (should fail)
- Manual test: Try to update/delete till entry (should fail)

**Manual Verification:**
1. Firebase Console → Firestore → Rules tab: verify rules deployed
2. Firebase Console → Firestore → Indexes tab: verify indexes building/built
3. Test app with different user roles to verify access control

---

### Phase 2: Service Integration

#### Task 4: Refactor TellerService (Deposits & Withdrawals)
**Estimated Time:** 4 hours  
**Priority:** Critical  
**Dependencies:** Task 1, Task 3

**Files to Modify:**
- `lib/services/teller_service.dart`

**Subtasks:**
1. Add `tillSession` parameter to `processDeposit()`:
   ```dart
   static Future<Map<String, dynamic>> processDeposit({
     required TillSession? tillSession,  // NEW
     // ... existing params
   })
   ```

2. Update `processDeposit()` implementation:
   - Call `TillService.requireOpenSession(tillSession)` at start
   - Determine `affectsCash` from `paymentMethod` ('Cash' = true, else false)
   - Use `WriteBatch` instead of individual writes
   - Add business record to batch
   - Call `TillService.postEntry(batch, tillSession, entry)` to add till entry
   - Add `tillSessionId` to savings transaction document
   - Commit batch atomically
   - Keep existing SMS/notification code (non-critical, fire after commit)

3. Repeat for `processWithdrawal()`:
   - Add `tillSession` parameter
   - Call `TillService.checkSufficientCash(tillSession, amount)` before proceeding
   - Use batch write with `TillService.postEntry()`
   - Withdrawals always have `affectsCash = true` (cash only)

4. Update method signatures in calling code (make `tillSession` optional for now):
   - Add `tillSession: _currentSession` when calling from teller screen
   - Existing calls without tillSession will fail gracefully with clear error

**Tests:**
- Unit test: `processDeposit()` with cash creates till entry with `affectsCash = true`
- Unit test: `processDeposit()` with MM creates till entry with `affectsCash = false`
- Unit test: `processWithdrawal()` with insufficient cash throws exception
- Integration test: Deposit + till entry committed atomically (both or neither)

**Manual Verification:**
1. Open till in app
2. Process cash deposit → verify savings transaction + till entry created
3. Process MM deposit → verify till entry has `affectsCash = false`
4. Process withdrawal → verify till entry subtracts from expected cash
5. Check Firestore: verify session `totalIn`/`totalOut` incremented correctly

---

#### Task 5: Loan Payment Integration (Cash Repayments)
**Estimated Time:** 3 hours  
**Priority:** High  
**Dependencies:** Task 1, Task 3

**Files to Modify:**
- `lib/screens/admin/loan_details_screen.dart`
- `lib/widgets/loan_payment_cash_dialog.dart`

**Subtasks:**
1. Pass `tillSession` to cash payment dialog from loan details screen:
   ```dart
   await showDialog(
     context: context,
     builder: (ctx) => LoanPaymentCashDialog(
       tillSession: _currentTillSession,  // NEW
       // ... existing params
     ),
   );
   ```

2. Update `LoanPaymentCashDialog`:
   - Add `tillSession` field to widget
   - Add `tillSession` to `onPaymentComplete` callback data

3. In loan details screen, after recording repayment:
   ```dart
   if (paymentData['paymentMethod'] == 'Cash' && tillSession != null) {
     final batch = _db.batch();
     
     // Add repayment doc to batch (if not already added)
     
     // Add till entry
     TillService.postEntry(batch, tillSession, TillEntryInput(
       type: 'loan_repayment',
       direction: 'in',
       amount: totalPaid.toInt(),
       affectsCash: true,
       method: 'Cash',
       refCollection: AppConstants.repaymentsCol,
       refId: repaymentDocId,
       memberId: loanData['memberId'],
       memberName: loanData['memberName'],
       receiptNumber: receiptNumber,
       note: 'Loan repayment',
       crossSession: false,
     ));
     
     await batch.commit();
   }
   ```

4. Add `tillSessionId` field to repayment document

**Tests:**
- Manual test: Record cash loan repayment → verify till entry created
- Manual test: Record MM loan repayment → verify till entry has `affectsCash = false`

**Manual Verification:**
1. Open loan details screen
2. Record cash repayment → verify repayment + till entry created
3. Check till session `totalIn` incremented
4. Verify expected cash updated correctly

---

#### Task 6: Loan Disbursement Integration
**Estimated Time:** 3 hours  
**Priority:** High  
**Dependencies:** Task 1, Task 3

**Files to Modify:**
- `lib/services/loan_disbursement_service.dart`
- `lib/screens/admin/loan_details_screen.dart` (disburse dialog)

**Subtasks:**
1. Add `tillSession` parameter to `disburseLoan()`:
   ```dart
   static Future<Map<String, dynamic>> disburseLoan({
     required TillSession? tillSession,  // NEW
     // ... existing params
   })
   ```

2. In `disburseLoan()`:
   - If `destinationType == 'cash'`:
     - Call `TillService.requireOpenSession(tillSession)`
     - Call `TillService.checkSufficientCash(tillSession, amount.toInt())`
     - Use batch write
     - Add disbursement record to batch
     - Call `TillService.postEntry()` with:
       - `type: 'loan_disbursement'`
       - `direction: 'out'`
       - `affectsCash: true`
   - If `destinationType == 'mobile_money'` or `'bank'`:
     - Still record till entry but with `affectsCash: false` (for audit)

3. Add `tillSessionId` to loan document at disbursement

**Tests:**
- Manual test: Disburse cash loan → verify till entry created, expected cash reduced
- Manual test: Disburse with insufficient cash → blocked with error message

**Manual Verification:**
1. Approve a loan
2. Disburse as cash → verify till entry created, expected cash drops
3. Try to disburse more than expected cash → verify blocked
4. Disburse as bank → verify till entry has `affectsCash = false`

---

#### Task 7: Vault Transfers & Reversals
**Estimated Time:** 3 hours  
**Priority:** Medium  
**Dependencies:** Task 1

**Files to Modify:**
- `lib/services/till_service.dart` (complete implementations)

**Subtasks:**
1. Implement `vaultTopUp()`:
   - Check session is open
   - Create till entry with `type: 'vault_topup'`, `direction: 'in'`
   - Record `approvedBy` field
   - Log audit trail

2. Implement `vaultSweep()`:
   - Check session is open
   - Check sufficient cash
   - Create till entry with `type: 'vault_sweep'`, `direction: 'out'`
   - Record `approvedBy` field
   - Log audit trail

3. Implement `reverseEntry()`:
   - Fetch original entry
   - Get current teller's open session
   - If session exists and same as original → create reversing entry
   - If no session or different → create orphan reversal with `crossSession: true`
   - Notify head tellers of cross-session reversals

4. Update loan reversal code to call `TillService.reverseEntry()`

**Tests:**
- Manual test: Vault top-up → expected cash increases
- Manual test: Vault sweep → expected cash decreases
- Manual test: Reverse payment → expected cash adjusts correctly
- Manual test: Cross-session reversal → flagged for supervisor

**Manual Verification:**
1. Record vault top-up → verify till entry, expected cash increases
2. Record vault sweep → verify till entry, expected cash decreases
3. Reverse a payment same day → verify reversing entry in same session
4. Reverse a payment next day → verify cross-session flag

---

### Phase 3: Teller UI

#### Task 8: Teller Screen State (Resume & Gating)
**Estimated Time:** 4 hours  
**Priority:** Critical  
**Dependencies:** Task 1

**Files to Modify:**
- `lib/screens/admin/teller_screen.dart`

**Subtasks:**
1. Remove disabled `_loadTillStatus()` method and commented code

2. Add state fields:
   ```dart
   TillSession? _currentSession;
   StreamSubscription? _sessionSub;
   ```

3. In `initState()`, watch session:
   ```dart
   void _watchSession() {
     final tellerId = FirebaseService.sessionUid;
     _sessionSub = TillService.watchOpenSession(tellerId).listen((session) {
       if (mounted) {
         setState(() => _currentSession = session);
         if (session != null && TillService.isStaleSession(session)) {
           _showStaleSessionDialog();
         }
       }
     });
   }
   ```

4. Add transaction gating:
   ```dart
   bool get _canTransact => _currentSession != null &&
       _currentSession!.status == 'open' &&
       !TillService.isStaleSession(_currentSession!);
   ```

5. Update deposit/withdrawal buttons to pass `_currentSession`:
   ```dart
   onPressed: _canTransact ? () => _showDepositDialog(_currentSession!) : null
   ```

6. Show banner when till closed:
   ```dart
   if (!_canTransact) _buildClosedTillBanner()
   ```

7. Show stale session warning if businessDate < today

**Tests:**
- Manual test: Reload page mid-session → same session restored
- Manual test: Try transaction with no session → buttons disabled
- Manual test: Open session yesterday → shows stale warning, blocks transactions

**Manual Verification:**
1. Open till → verify session state updates
2. Refresh browser → verify session restored
3. Try deposit with closed till → verify button disabled
4. Open session, wait until next day, try transaction → verify blocked

---

#### Task 9: Open & Close Till Dialogs
**Estimated Time:** 5 hours  
**Priority:** Critical  
**Dependencies:** Task 1, Task 8

**Files to Modify:**
- `lib/screens/admin/teller_screen.dart`

**Subtasks:**
1. Implement `_showOpenTillDialog()`:
   - Show dialog with float amount input
   - Optional: supervisor name input for `floatIssuedBy`
   - Call `TillService.openSession()`
   - Handle exceptions (already has open session, etc.)
   - Show success toast

2. Implement `_showCloseTillDialog()` (Step 1: Denomination Count):
   - Create stateful dialog with denomination fields
   - 10 rows: 50k, 20k, 10k, 5k, 2k, 1k, 500, 200, 100, 50
   - Each row: +/- buttons and numeric input
   - Live "Counted Total" updates as counts change
   - **DO NOT show expected cash**
   - Submit button calls `_submitCount()`

3. Implement `_submitCount()`:
   - Call `TillService.closeSession(sessionId, denominations)`
   - Get `CloseResult`
   - If `needsReview` → show reason input dialog → call again with reason
   - Else → show variance result dialog

4. Implement `_showVarianceResult()` (Step 2: Result):
   - Show counted, expected, variance
   - Color code: green (zero), amber (within tolerance), red (beyond)
   - "Done" button closes and returns to closed till state

5. Update till bar to show:
   - When open: opening float, cash in, cash out, **expected cash**, close button
   - When closed: "Till is closed", open button

**Tests:**
- Manual test: Open till → session created in Firestore
- Manual test: Try to open again → shows "already open" error
- Manual test: Close with zero variance → closes immediately
- Manual test: Close with variance within tolerance → closes with variance noted
- Manual test: Close with variance beyond tolerance → requires reason, pending review

**Manual Verification:**
1. Open till with 500k float → verify session created
2. Process transactions (deposits, withdrawals)
3. Close till:
   - Count denominations → verify expected NOT shown
   - Submit count → verify variance computed
   - If beyond tolerance → verify reason required
4. Verify session status updated to 'closed' or 'pending_review'

---

#### Task 10: Vault Transfer UI
**Estimated Time:** 2 hours  
**Priority:** Medium  
**Dependencies:** Task 7, Task 9

**Files to Modify:**
- `lib/screens/admin/teller_screen.dart`

**Subtasks:**
1. Add "Cash from Vault" button to till bar (when open)
2. Implement `_showVaultTopUpDialog()`:
   - Amount input
   - "Approved by" input (supervisor name)
   - Optional note
   - Call `TillService.vaultTopUp()`

3. Add "Send to Vault" button to till bar
4. Implement `_showVaultSweepDialog()`:
   - Amount input (max = expected cash)
   - "Approved by" input
   - Optional note
   - Call `TillService.vaultSweep()`

5. Show warning banner when `expectedCash > tillMaxCash`:
   - "Till over maximum capacity (UGX 10M). Please sweep excess cash to vault."

**Tests:**
- Manual test: Vault top-up → expected cash increases
- Manual test: Vault sweep → expected cash decreases
- Manual test: Over max warning → shows when exceeded

**Manual Verification:**
1. Process deposits until over 10M → verify warning appears
2. Click "Send to Vault" → sweep 5M → verify warning disappears
3. Need more cash → click "Cash from Vault" → top up → verify expected increases

---

### Phase 4: Supervisor & Reporting

#### Task 11: All Tills Dashboard (Supervisor)
**Estimated Time:** 4 hours  
**Priority:** High  
**Dependencies:** Task 1

**Files to Create:**
- `lib/screens/admin/all_tills_screen.dart` (new)

**Subtasks:**
1. Create `AllTillsScreen` widget:
   - Tab or separate screen accessible to head_teller and admin only
   - Stream all sessions for today (or selected date)
   - List view with cards showing:
     - Teller name
     - Status (open/pending_review/closed) with color chip
     - Opening float, expected cash, transaction count
     - Last activity time
     - Warning icons: stale session, over max, integrity warning

2. Implement filters:
   - Date picker (default: today)
   - Status filter (all/open/closed/pending_review)

3. Tap session → show session details dialog:
   - All session metadata
   - Button: "View Ledger" → shows all till entries

4. Pending review queue:
   - Filter to `status = 'pending_review'`
   - Each item shows variance, reason
   - "Approve" / "Reject" buttons

5. Implement `_showApproveVarianceDialog()`:
   - Review note input
   - Call `TillService.approveVariance()`

**Tests:**
- Manual test: View all tills as head teller → shows all sessions
- Manual test: Filter by date → shows sessions for that date
- Manual test: Approve variance → status changes to 'closed'

**Manual Verification:**
1. Log in as head_teller
2. View All Tills screen → verify sees all tellers' sessions
3. Click pending review session → approve → verify status updates
4. Verify teller receives notification of approval

---

#### Task 12: My Till Tab (Ledger View)
**Estimated Time:** 3 hours  
**Priority:** Medium  
**Dependencies:** Task 1, Task 8

**Files to Modify:**
- `lib/screens/admin/teller_screen.dart` (add tab)

**Subtasks:**
1. Add "My Till" tab to teller screen:
   - Stream `TillService.watchSessionEntries(_currentSession!.id)`
   - List view showing all till entries for current session

2. Each entry row shows:
   - Time (HH:MM)
   - Type icon (deposit/withdrawal/repayment/etc.)
   - Member name (if applicable)
   - Method chip (Cash/MM/Bank)
   - Amount (green for in, red for out)
   - Running expected cash

3. Add filters:
   - By type (all/deposit/withdrawal/repayment/disbursement/vault)
   - By method (all/cash/MM/bank)

4. Add totals footer:
   - Total cash in
   - Total cash out
   - Total non-cash
   - Net: expected cash

**Tests:**
- Manual test: View My Till tab → shows all entries for session
- Manual test: Filter by type → shows only matching entries
- Manual test: Running expected cash column updates correctly

**Manual Verification:**
1. Open till, process several transactions
2. View My Till tab → verify all entries listed chronologically
3. Filter by "Cash" → verify only cash entries shown
4. Verify running expected cash column computes correctly

---

#### Task 13: Daily Summary Rework
**Estimated Time:** 3 hours  
**Priority:** Medium  
**Dependencies:** Task 1

**Files to Modify:**
- `lib/screens/admin/teller_screen.dart` (Daily Summary tab)

**Subtasks:**
1. Add scope toggle: "My Till" / "All Tills"
   - My Till: aggregate current teller's session entries
   - All Tills: aggregate all tellers for selected date (head_teller/admin only)

2. Split totals by method:
   - **Cash:**
     - Deposits: X
     - Withdrawals: X
     - Loan Repayments: X
     - Loan Disbursements: X
     - Vault Top-ups: X
     - Vault Sweeps: X
     - **Net Cash:** opening + in - out
   - **Mobile Money:**
     - Deposits: X
     - Withdrawals: X
     - Loan Repayments: X
   - **Bank:**
     - Deposits: X
     - Disbursements: X
   - **Savings Transfer:**
     - Loan Repayments: X (internal book entry)

3. Remove old "net cash flow" figure that mixed cash with non-cash

4. Add date picker for historical summaries

**Tests:**
- Manual test: Daily summary splits cash vs non-cash correctly
- Manual test: "All Tills" scope shows combined totals (head_teller only)

**Manual Verification:**
1. Process mix of cash, MM, bank transactions
2. View Daily Summary → verify split by method
3. Switch to "All Tills" scope → verify sees all tellers' totals
4. Select previous date → verify shows historical data

---

#### Task 14: Reports (Reconciliation & Variance History)
**Estimated Time:** 4 hours  
**Priority:** Low  
**Dependencies:** Task 1

**Files to Create:**
- `lib/screens/admin/till_reports_screen.dart` (new)

**Subtasks:**
1. Create `TillReportsScreen`:
   - Accessible to head_teller and admin
   - Three report types:
     - Session Reconciliation
     - Variance History
     - Daily Cash Position

2. **Session Reconciliation Report:**
   - Select session (by date + teller)
   - Show:
     - Session metadata
     - All till entries in table
     - Totals by type and method
     - Closing variance (if closed)
   - Export to CSV button

3. **Variance History Report:**
   - Select teller and date range
   - Table showing:
     - Date, variance amount, reason, review status, reviewed by
   - Chart: variance trend over time

4. **Daily Cash Position:**
   - Select date
   - Table showing all sessions:
     - Teller, opening float, cash in, cash out, expected, counted (if closed), variance
   - Export to CSV

5. Implement CSV export for each report type

**Tests:**
- Manual test: Generate session reconciliation → verify all entries listed
- Manual test: Export to CSV → verify file downloads with correct data
- Manual test: Variance history → shows past variances with reasons

**Manual Verification:**
1. View Session Reconciliation for closed session → verify matches Firestore
2. Export to CSV → open in Excel → verify data correct
3. View Variance History for a teller → verify shows all past variances
4. View Daily Cash Position → verify aggregates all tellers correctly

---

### Phase 5: Cleanup & Migration

#### Task 15: Backfill & Legacy Marking
**Estimated Time:** 2 hours  
**Priority:** Low  
**Dependencies:** All previous tasks complete

**Files to Create:**
- `lib/scripts/mark_legacy_transactions.dart` (one-time script)

**Subtasks:**
1. Create migration script to mark legacy transactions:
   - Find all documents in transaction collections without `tillSessionId`
   - Add field `legacy: true` to each
   - Log count of migrated records

2. Run script once in production:
   ```dart
   dart run lib/scripts/mark_legacy_transactions.dart
   ```

3. DO NOT create retroactive till entries (would corrupt reconciliation)

**Tests:**
- Dry-run script on test tenant → verify marks correct documents
- Check Firestore after migration → verify legacy flag present

**Manual Verification:**
1. Run script
2. Query Firestore: count docs with `legacy: true`
3. Verify no new till entries created for old transactions

---

#### Task 16: Code Cleanup
**Estimated Time:** 2 hours  
**Priority:** Low  
**Dependencies:** All previous tasks complete

**Files to Modify:**
- `lib/services/teller_service.dart`
- `lib/screens/admin/teller_screen.dart`

**Subtasks:**
1. Remove all commented-out till code from `teller_screen.dart`
2. Remove disabled `_loadTillStatus()` method
3. Replace all `print()` calls with `debugPrint()` in till-related code
4. Remove unused imports
5. Run `dart format` on all modified files
6. Run `flutter analyze` and fix any warnings

**Tests:**
- Run `flutter analyze` → no errors or warnings
- Run app → verify no runtime errors

**Manual Verification:**
1. Run app end-to-end
2. Open/close till, process transactions
3. Verify no console errors or warnings
4. Check code quality: no commented code, consistent formatting

---

## Summary

### Total Estimated Time: 54 hours (≈ 7 working days)

### Task Dependencies

```
Phase 1 (Foundation):
  Task 1 (Data Models) → [Task 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14]
  Task 2 (Settings) → [Task 11]
  Task 3 (Rules) → [Task 4, 5, 6]

Phase 2 (Service Integration):
  Task 4 (TellerService) → [Task 8]
  Task 5 (Loan Payment) → []
  Task 6 (Loan Disbursement) → []
  Task 7 (Vault/Reversals) → [Task 10]

Phase 3 (Teller UI):
  Task 8 (Screen State) → [Task 9, 10, 12]
  Task 9 (Open/Close) → []
  Task 10 (Vault UI) → []

Phase 4 (Supervisor & Reporting):
  Task 11 (All Tills) → []
  Task 12 (My Till Tab) → []
  Task 13 (Daily Summary) → []
  Task 14 (Reports) → []

Phase 5 (Cleanup):
  Task 15 (Backfill) → [Task 16]
  Task 16 (Cleanup) → []
```

### Critical Path
Task 1 → Task 3 → Task 4 → Task 8 → Task 9

### Risk Mitigation
1. **Firestore index build time:** Deploy indexes (Task 3) ASAP, they can build while coding
2. **Breaking changes:** Keep `tillSession` parameter optional during Phase 2, enforce in Phase 5
3. **User training:** Create user guide/video for till open/close flow before rollout

### Rollout Plan
1. **Week 1:** Deploy Phase 1 (non-breaking, no UI changes)
2. **Week 2:** Deploy Phase 2 + 3 (tellers can opt-in to use new till flow)
3. **Week 3:** Deploy Phase 4 (supervisor tools)
4. **Week 4:** Enforce till requirement, run cleanup (Phase 5)

---

**END OF TASKS DOCUMENT**

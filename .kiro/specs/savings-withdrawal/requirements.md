# Requirements Document

## Introduction

The Savings Withdrawal feature adds a staff-facing withdrawal operation to the SACCOPLUS PHP admin system. A teller or manager selects a member, chooses which savings type (Voluntary or Compulsory) to debit and the destination (cash/bank/mobile money), enters the amount, and confirms. The system posts a double-entry journal, decrements the `member_savings_summary` cached balance, writes a `savings_transactions` row, and logs an audit entry — all inside a single database transaction. The feature is built on top of the existing MVC skeleton (Controllers, Services, Views), follows the double-entry ledger already in `schema.sql`, and uses the same CSS and layout as the rest of the admin UI.

---

## Glossary

- **Withdrawal_Screen**: The page at `/savings/withdraw` where a teller initiates a savings withdrawal.
- **SavingsService**: The PHP service class that executes the withdrawal inside a DB transaction.
- **member_savings_summary**: The MySQL table caching voluntary, compulsory, and share-capital balances per member.
- **savings_transactions**: The MySQL table recording each deposit or withdrawal event.
- **journal_entries / journal_lines**: The double-entry ledger tables; every money movement posts here.
- **audit_logs**: The MySQL table tracking who did what, with old and new values.
- **Savings_Type**: The category being debited — `Voluntary` or `Compulsory`.
- **Payment_Method**: How the cash leaves the SACCO — `Cash`, `Bank Transfer`, or `Mobile Money`.
- **GL_Savings_Liability**: The general-ledger liability account that represents member savings (credit normal).
- **GL_Cash / GL_Bank**: The GL asset accounts used on the debit side of the journal entry.

---

## Requirements

### Requirement 1: Withdrawal Entry Screen

**User Story:** As a teller, I want a dedicated savings-withdrawal page, so that I can process a member's withdrawal without leaving the savings section.

#### Acceptance Criteria

1. THE Withdrawal_Screen SHALL be accessible at the clean URL `/savings/withdraw` with no `.php` extension, routed through the front controller.
2. WHEN a teller navigates to `/savings/withdraw` without a `member_id` query parameter, THE Withdrawal_Screen SHALL display a member-search input that filters by name, phone, or member number, and SHALL render matching results as a selectable list without a full page reload (via `fetch`).
3. WHEN a member is selected, THE Withdrawal_Screen SHALL display the member's name, account number, voluntary balance, compulsory balance, and total savings balance fetched from `member_savings_summary`.
4. IF the selected member's total savings balance is zero, THEN THE Withdrawal_Screen SHALL display an informational message "No savings available to withdraw" and SHALL disable the amount input and submit button.
5. THE Withdrawal_Screen SHALL require the user to hold at least the `teller` role; users with lesser roles SHALL be redirected with an error flash message.

---

### Requirement 2: Withdrawal Form Inputs

**User Story:** As a teller, I want to specify the savings type, amount, payment method, and reference when processing a withdrawal, so that the transaction is recorded accurately.

#### Acceptance Criteria

1. THE Withdrawal_Screen SHALL present a dropdown for Savings_Type with options `Voluntary` and `Compulsory`, defaulting to `Voluntary`.
2. WHEN a Savings_Type is selected, THE Withdrawal_Screen SHALL update the displayed available balance for that type in real time without a page reload.
3. THE Withdrawal_Screen SHALL present a dropdown for Payment_Method with options `Cash`, `Bank Transfer`, and `Mobile Money`.
4. THE Withdrawal_Screen SHALL include a numeric amount input field accepting whole UGX amounts only (no decimals).
5. THE Withdrawal_Screen SHALL include an optional free-text reference/notes field (max 255 characters).
6. IF the teller enters an amount greater than the available balance of the selected Savings_Type, THEN THE Withdrawal_Screen SHALL display an inline validation error and SHALL prevent form submission.
7. IF the teller enters an amount less than UGX 1,000, THEN THE Withdrawal_Screen SHALL display an inline validation error and SHALL prevent form submission.
8. THE Withdrawal_Screen SHALL include a CSRF token in the POST form to protect against cross-site request forgery.

---

### Requirement 3: Withdrawal Execution

**User Story:** As a teller, I want the system to atomically update all relevant records when I submit a withdrawal, so that balances and the ledger stay consistent even if the server crashes mid-process.

#### Acceptance Criteria

1. WHEN the teller submits a valid withdrawal form, THE SavingsService SHALL execute all database writes inside a single PDO transaction using `BEGIN … COMMIT`.
2. WITHIN that transaction, THE SavingsService SHALL:
   a. Decrement `voluntary_balance` or `compulsory_balance` (as selected) in `member_savings_summary` using a `SELECT … FOR UPDATE` row lock.
   b. Insert one row into `savings_transactions` with `transaction_type = 'withdrawal'`, the selected `savings_type`, `payment_method`, `amount`, `status = 'Approved'`, `auto_approved = 1`, and `recorded_by` set to the logged-in user's ID.
   c. Insert one `journal_entries` row with `txn_type = 'savings_withdrawal'`, `value_date = CURDATE()`, and `posted_by` set to the logged-in user's ID.
   d. Insert two `journal_lines` rows that balance to zero: debit GL_Savings_Liability by the withdrawal amount, credit GL_Cash (or GL_Bank) by the same amount, both linked to the `journal_entries` row.
3. IF the available balance after locking is less than the requested amount, THEN THE SavingsService SHALL rollback the transaction and throw a domain exception with message "Insufficient balance".
4. IF any database write fails, THEN THE SavingsService SHALL rollback the transaction so no partial state is committed.
5. WHEN the transaction commits successfully, THE SavingsService SHALL return the new savings balance to the controller.

---

### Requirement 4: Audit Logging

**User Story:** As a SACCO administrator, I want every savings withdrawal recorded in the audit trail, so that I can review teller activity and detect errors.

#### Acceptance Criteria

1. AFTER the withdrawal transaction commits, THE SavingsService SHALL insert one row into `audit_logs` with `action = 'savings_withdrawal'`, `entity = 'savings_transactions'`, `entity_id` set to the new `savings_transactions.id`, `old_values` containing the balances before the withdrawal (as JSON), `new_values` containing the balances after (as JSON), `user_id` set to the logged-in user's ID, and `ip` set to the request IP.
2. IF the audit log insert fails, THE SavingsService SHALL NOT rollback the already-committed withdrawal; the failure SHALL be logged to the PHP error log and surfaced as a non-fatal warning in the response.
3. THE audit log row SHALL include `sacco_id` so multi-tenant audit queries remain isolated.

---

### Requirement 5: Post-Withdrawal Feedback and Navigation

**User Story:** As a teller, I want clear confirmation after a withdrawal is processed, so that I know the transaction succeeded and can serve the next member quickly.

#### Acceptance Criteria

1. WHEN a withdrawal completes successfully, THE controller SHALL set a flash success message containing the member's name, amount withdrawn, payment method, and new savings balance, then redirect to `/savings/withdraw` (GET) to prevent form re-submission on refresh.
2. WHEN a withdrawal fails due to insufficient balance or a database error, THE controller SHALL set a flash error message with a human-readable reason and redirect back to the form with the previously entered values preserved in the session so the teller does not have to re-enter data.
3. WHEN a withdrawal fails because the DB transaction rolled back after the MarzPay/mobile-money disbursement has already been initiated externally (not applicable in this admin-side cash/bank flow), the failure SHALL be logged to the PHP error log; this scenario is out of scope for the current implementation and SHALL be documented in a code comment.
4. THE Withdrawal_Screen SHALL display any pending flash messages (success or error) at the top of the page using the existing flash-message partial.

---

### Requirement 6: Permission and Role Enforcement

**User Story:** As a system administrator, I want only authorised staff to process withdrawals, so that member savings are protected from unauthorised access.

#### Acceptance Criteria

1. THE withdrawal route SHALL require an authenticated session; unauthenticated requests SHALL be redirected to `/login`.
2. ONLY users with roles `admin`, `sacco_admin`, `branch_manager`, or `teller` SHALL be allowed to POST a withdrawal; users with `auditor` or `viewer` roles SHALL receive an HTTP 403 response.
3. THE controller SHALL verify that the member's `sacco_id` matches the logged-in user's `sacco_id` before processing, preventing cross-tenant data access.

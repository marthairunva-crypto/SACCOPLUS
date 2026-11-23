# Implementation Plan: Member Portal — SACCOPLUS PHP

## Overview

Build the member-facing self-service portal under the `/member` URL prefix on the existing `saccoplus-php` skeleton. The portal shares the same MySQL database, Services layer, and CSS file as the admin system but uses a completely separate session namespace (`$_SESSION['member']` vs `$_SESSION['user']`). Work proceeds in vertical slices: schema → service/controller → view → wired to router, one feature at a time.

**Critical constraints carried through every task:**
- No `.php` extensions in any URL. All routes registered in `public/index.php`.
- Every POST has a CSRF token validated via the existing `Csrf` class.
- Every money-changing operation: `DB::beginTransaction()` + `SELECT … FOR UPDATE` + `COMMIT`.
- `LoanService` is the single source of loan arithmetic. No formulas in views.
- Late-payment penalties are **never** auto-applied. Staff-only via `POST loans/add-charge`.
- All output escaped with `htmlspecialchars()` (use existing `e()` helper).
- All queries scoped by `sacco_id`.
- Existing `MemberDashboardController` (in `App\Controllers\`) is a placeholder — replace it with the proper `App\Controllers\Member\MemberDashboardController` and its new session namespace.

---

## Tasks

- [x] 1. Database migrations — new tables and member column additions
  - [x] 1.1 Create `database/migrations/002_member_portal.sql` with all new tables
    - Include DDL exactly as specified in design.md: `member_login_history`, `member_otp`, `member_change_requests`, `member_next_of_kin`, `member_documents`, `member_notifications`, `member_notification_preferences`, `payment_transactions`, `loan_liens`, `loan_applications`, `loan_application_guarantors`, `receipts`, `rate_limits`
    - All tables: InnoDB, utf8mb4_unicode_ci, proper foreign keys, indexes
    - _Requirements: 1.x, 3.6, 5.x, 6.x, 7.x, 8.x, 9.x, 15.1_
  - [x] 1.2 Create `database/migrations/003_member_columns.sql` with ALTER TABLE additions
    - Add `must_change_password TINYINT(1)`, `login_attempts TINYINT UNSIGNED`, `login_locked_until TIMESTAMP NULL`, `password_hash VARCHAR(255) NULL` to `members` table
    - Add `IF NOT EXISTS` guards so the migration is safe to re-run
    - _Requirements: 1.4, 1.5, 1.6_
  - [ ]* 1.3 Write a migration runner script `database/migrations/run_migrations.php`
    - Reads all `*.sql` files from migrations directory in filename order, executes them, tracks executed files in a `schema_migrations` table
    - Safe to run multiple times (idempotent)
    - _Requirements: 15.5_

- [x] 2. Core infrastructure — `RateLimiter`, `AuditLogger`, `PasswordValidator`
  - [x] 2.1 Create `app/Core/RateLimiter.php`
    - `RateLimiter::check(string $bucketKey, int $maxAttempts, int $windowSeconds): bool`
    - Uses `rate_limits` table with `INSERT … ON DUPLICATE KEY UPDATE` to atomically increment; resets counter when `window_start` is older than `$windowSeconds`
    - Returns `false` (limit breached) or `true` (allowed); never throws
    - _Requirements: 14.2_
  - [x] 2.2 Create `app/Core/AuditLogger.php`
    - Static `AuditLogger::log(int $saccoId, ?int $userId, ?int $memberId, string $action, string $entity, int $entityId, array $oldValues, array $newValues, string $ip): void`
    - Inserts one row into `audit_logs`; failures are logged with `error_log()` and swallowed
    - _Requirements: 15.6, 3.8_
  - [x] 2.3 Create `app/Core/PasswordValidator.php`
    - Static `PasswordValidator::validate(string $password): array` returning an array of error strings (empty = valid)
    - Rules: min 8 chars, 1 uppercase, 1 lowercase, 1 digit, 1 special char
    - _Requirements: 1.13_
  - [ ]* 2.4 Write unit tests for `PasswordValidator` in `tests/Unit/PasswordValidatorTest.php`
    - Test all boundary cases: exactly 8 chars, missing each character class, empty string
    - _Requirements: 1.13_

- [x] 3. `LedgerService` — extracted double-entry posting shared service
  - [x] 3.1 Create `app/Services/LedgerService.php`
    - `post(array $entry, array $lines): int` — validates `SUM(debit) === SUM(credit)`, inserts `journal_entries` + `journal_lines` inside caller-provided transaction; throws `\RuntimeException` on imbalance before touching DB
    - `reverse(int $entryId, string $reason, int $postedBy): int` — creates mirror entry referencing original via `reverses_entry_id`
    - `getMemberSavingsBalance(int $memberId, int $saccoId): float` — `SUM(credit - debit)` over `journal_lines` for member's `member_account_id`s
    - All queries use prepared statements, all scoped by `sacco_id`
    - _Requirements: 15.1, 15.2, 15.3, 15.4_
  - [ ]* 3.2 Write unit tests for `LedgerService` in `tests/Unit/LedgerServiceTest.php`
    - Test: balanced entry accepted, unbalanced entry throws `RuntimeException`, reversal produces mirror lines summing to zero
    - Uses in-memory SQLite or mock PDO (no real DB needed for balance-check logic)
    - _Requirements: 15.1, 15.2, 15.3_

- [ ] 4. Member authentication — `MemberAuthController` + views
  - [~] 4.1 Create `app/Controllers/Member/MemberAuthController.php` (does NOT extend `MemberBaseController`)
    - `showLogin()` / `login()` — look up member by `member_no` or `phone`, `password_verify` against `members.password_hash`, call `RateLimiter::check('login:ip:…', 5, 60)`, handle locked status, generate 6-digit OTP via `SmsService::generateOTP()`, hash it with `password_hash(PASSWORD_ARGON2ID)`, store in `member_otp`, send via `SmsService::sendOTP()`, redirect to OTP screen
    - `showOtp()` / `verifyOtp()` — find unexpired OTP row, `password_verify`, check `attempts <= 3`, call `createMemberSession()`, redirect to dashboard or force-password-change
    - `resendOtp()` — rate-limited (3 resends per 15 min per member), generates new OTP
    - `showForgotPassword()` / `forgotPassword()` — same OTP flow with `purpose = 'reset'`
    - `showResetPassword()` / `resetPassword()` — verify OTP, validate with `PasswordValidator`, `password_hash(PASSWORD_ARGON2ID)`, update `members.password_hash`, `AuditLogger::log()`, `SmsService::send()` alert
    - `showChangePassword()` / `changePassword()` — verify current password, validate new, update, send SMS
    - `logout()` — unset `$_SESSION['member']`, regenerate session ID, redirect to `member/login`
    - `ping()` — updates `$_SESSION['member']['last_activity']`, returns JSON `{ok: true}`
    - Private `createMemberSession(array $member): void` — `session_regenerate_id(true)`, populate `$_SESSION['member']` with `member_id`, `sacco_id`, `full_name`, `member_no`, `must_change_password`, `last_activity`; insert `member_login_history` row; prune to last 10
    - _Requirements: 1.1–1.16_
  - [ ] 4.2 Register all `member/login`, `member/login/otp`, `member/forgot-password`, `member/reset-password`, `member/change-password`, `member/logout`, `member/api/ping` routes in `public/index.php`
    - Add use-statement for `App\Controllers\Member\MemberAuthController`
    - Remove or redirect old `member/dashboard` routes pointing to the old `MemberDashboardController` placeholder
    - _Requirements: 1.x, 14.6_
  - [ ] 4.3 Create member auth views in `app/Views/member/auth/`
    - `login.php` — member number / phone field, password field, CSRF token, "Forgot password" link; reuses existing form card style
    - `otp.php` — 6-digit OTP input, countdown timer (JS), resend button; shows masked phone hint
    - `change-password.php` — current password + new password + confirm; shows strength requirements
    - `forgot-password.php` — phone or member number input
    - `reset-password.php` — OTP + new password + confirm
    - _Requirements: 1.1, 1.9, 1.10, 1.13_

- [ ] 5. `MemberBaseController` + routing guard + member layout
  - [ ] 5.1 Create `app/Controllers/Member/MemberBaseController.php`
    - Abstract class; constructor checks `$_SESSION['member']['member_id']`, verifies inactivity (30 min), calls `verifyMemberSession()` (SELECT member from DB, check `status != 'exited'`), sets `$this->member`
    - Protected helpers: `memberId(): int`, `saccoId(): int`, `redirectToLogin(string $msg = ''): never`
    - _Requirements: 1.7, 14.6_
  - [ ] 5.2 Extend `public/index.php` routing guard (`$router->before()`)
    - Routes under `member/` (except `member/login`, `member/forgot-password`, `member/reset-password`, `member/login/otp`, `webhooks/`) require `$_SESSION['member']['member_id']`
    - Routes NOT under `member/` or `webhooks/` require `$_SESSION['user']['id']` (existing guard — don't break it)
    - `webhooks/` routes bypass both guards
    - _Requirements: 14.6, 17.1_
  - [ ] 5.3 Create `app/Views/member/layout.php`
    - Same HTML skeleton as `app/Views/layout.php` (same `<head>`, same CSS links, same JS helpers)
    - Desktop: top navigation bar (no sidebar). Mobile (< 768 px): bottom tab bar with icons: Home, Accounts, Loans, Guarantors, Notifications
    - Notification badge and guarantor badge injected via PHP from session or quick DB counts
    - Inactivity ping: `setInterval(() => fetch(url('member/api/ping')), 240000)` in `<script>`
    - Flash message rendering identical to admin layout
    - _Requirements: 16.3, 16.4, 16.5_

- [ ] 6. Member dashboard
  - [ ] 6.1 Create `app/Controllers/Member/MemberDashboardController.php` (extends `MemberBaseController`)
    - `index()`: fetch savings balance via `LedgerService::getMemberSavingsBalance()`, fetch shares balance, fetch total outstanding loan balance via `LoanService`, fetch last 5 ledger transactions, fetch upcoming installments within 30 days via `LoanService`, count unread notifications, count pending guarantor requests; pass all to view
    - All queries scoped by `$this->saccoId()` and `$this->memberId()`
    - _Requirements: 2.1–2.8_
  - [ ] 6.2 Rewrite `app/Views/member/dashboard.php` with full layout
    - Wrap in `member/layout.php`
    - Hero card: Savings_Balance (large number), Shares_Balance, outstanding loan balance
    - Arrears warning card (red border, total arrears + oldest overdue date) — visible only when arrears > 0
    - Last 5 transactions table (date, description, ±amount, running balance)
    - Upcoming installments within 30 days (loan number, amount, due date, days remaining)
    - Quick-action buttons: Deposit, Apply for Loan, Repay Loan, Buy Airtime, View Statement
    - Guarantor request badge + notification badge in nav
    - _Requirements: 2.1–2.8_
  - [ ] 6.3 Register `GET member/dashboard` in `public/index.php` pointing to new `App\Controllers\Member\MemberDashboardController`
    - Remove/redirect the old `member/dashboard` registration pointing to the old placeholder controller
    - _Requirements: 2.x_

- [ ] 7. Profile management
  - [ ] 7.1 Create `app/Controllers/Member/MemberProfileController.php` (extends `MemberBaseController`)
    - `show()` — fetch member row + next of kin records + documents list; render profile view
    - `update()` — allow email and address changes only; `AuditLogger::log()` with old/new values; CSRF check
    - `requestChange()` — creates `member_change_requests` row for full_name, national_id, or date_of_birth changes; notifies member via `SmsService`
    - `requestPhoneChange()` — generates OTP (`purpose = 'phone_change'`), sends to NEW phone, awaits verification
    - `verifyPhoneChange()` — verifies OTP, applies phone update, sends alert SMS to old phone AND new phone, `AuditLogger::log()`
    - `documents()` — list member's documents from `member_documents`
    - `upload()` — accept JPEG/PNG/PDF ≤ 5 MB, assign `random_bytes(16)` filename, store outside web root to `storage/uploads/members/{sacco_id}/`, insert `member_documents` row
    - _Requirements: 3.1–3.8_
  - [ ] 7.2 Create profile views in `app/Views/member/profile/`
    - `index.php` — label/value card rows: member no, full name, national ID, DOB, phone, email, address, membership date; "Edit" section for email/address; "Request Change" buttons for locked fields; next of kin management table (add/edit/remove rows, share % must sum to 100)
    - `documents.php` — list of uploaded documents with type, upload date, download link; drag-and-drop upload form with MIME/size validation in JS before submit
    - _Requirements: 3.1–3.8_
  - [ ] 7.3 Register profile routes in `public/index.php`
    - `GET/POST member/profile`, `POST member/profile/update`, `POST member/profile/request-change`, `POST member/profile/request-phone-change`, `POST member/profile/verify-phone-change`, `GET member/profile/documents`, `POST member/profile/documents/upload`
    - _Requirements: 3.x_

- [ ] 8. Savings, accounts, and statement
  - [ ] 8.1 Create `app/Controllers/Member/MemberAccountController.php` (extends `MemberBaseController`)
    - `index()` — list all member accounts grouped by type (savings, shares, fixed deposits); balance from `LedgerService::getMemberSavingsBalance()` for savings; flag liened amounts from `loan_liens` table
    - `transactions()` — paginated ledger transactions (default 20/page), filterable by date range and type; sourced from `journal_entries`/`journal_lines`/`member_accounts` with `member_id` + `sacco_id` scope
    - `statement()` GET — date range selector form; POST — invoke `StatementService::getStatementData()`, render printable HTML statement, offer PDF download via Dompdf
    - `receipts()` — list all receipts from `receipts` table for this member
    - `downloadReceipt()` — verify `receipts.member_id = $this->memberId()` before serving PDF file
    - `balanceAjax()` — returns JSON `{savings, shares, withdrawable}` for real-time dashboard updates
    - _Requirements: 4.1–4.7, 9.5–9.6_
  - [ ] 8.2 Create account views in `app/Views/member/accounts/`
    - `index.php` — card per account type; savings card shows balance + liened amount as separate read-only row; shares card shows non-withdrawable notice + share count + value; fixed deposit card shows principal, rate, maturity date
    - `transactions.php` — paginated table; date range filter; type filter; running balance column; export to CSV button
    - `statement.php` — date selector form + rendered statement table (DFCU-style: header with SACCO details, opening balance, dated rows with debit/credit/running balance, closing balance, page numbers); print button + PDF download button
    - _Requirements: 4.1–4.7_
  - [ ] 8.3 Register account routes in `public/index.php`
    - `GET member/accounts`, `GET member/accounts/transactions`, `GET/POST member/accounts/statement`, `GET member/receipts`, `GET member/receipts/download`, `GET member/api/balance`
    - _Requirements: 4.x_

- [ ] 9. `PaymentService` + `ReceiptService` — MoMo payment infrastructure
  - [ ] 9.1 Create `app/Services/PaymentService.php`
    - `initiateDeposit(int $memberId, int $saccoId, float $amount, string $phone, string $provider): string` — generates UUID v4 as idempotency key, inserts `payment_transactions` row with `status = 'pending'`, calls aggregator API via cURL, returns idempotency key
    - `handleCallback(array $payload): void` — HMAC verify, `SELECT … FOR UPDATE` on `payment_transactions`, idempotency check (already `completed` → return), validate amount, call `LedgerService::post()` inside `DB::beginTransaction()`, update row to `completed`, trigger `ReceiptService::generate()` and `NotificationService::notify()`
    - `initiateWithdrawal(int $paymentTxnId): void` — calls aggregator payout API
    - All cURL calls have 30 s timeout; network failures set `status = 'failed'` and log to error_log
    - _Requirements: 5.1–5.4, 7.7_
  - [ ] 9.2 Create `app/Services/ReceiptService.php`
    - `generate(int $memberId, int $saccoId, string $txnType, float $amount, int $journalEntryId, array $meta = []): string` — `SELECT MAX(receipt_seq) + 1 FOR UPDATE` inside transaction, generates receipt number `RCP-NNNN-YYYY`, renders Dompdf PDF with SACCO header + member info + transaction details, saves to `storage/receipts/{sacco_id}/{year}/`, inserts `receipts` row
    - `getPath(int $receiptId, int $memberId, int $saccoId): ?string` — returns file path only if `receipts.member_id = $memberId` AND `receipts.sacco_id = $saccoId`
    - _Requirements: 9.5, 9.6_

- [ ] 10. Deposits — member-initiated MoMo deposits
  - [ ] 10.1 Create deposit methods in `MemberAccountController`
    - `showDeposit()` — deposit form with amount field, MoMo provider selector (MTN/Airtel), phone field (pre-populated from member's phone)
    - `initiateDeposit()` — `RateLimiter::check('payment:member:…', 10, 900)`, validate amount > 0 and ≤ configured max, call `PaymentService::initiateDeposit()`, redirect to pending screen
    - Pending status screen polls `GET member/api/balance` every 5 s to detect completed deposit
    - _Requirements: 5.1, 5.4, 5.8, 5.9_
  - [ ] 10.2 Create `app/Controllers/Member/MemberWebhookController.php` (no `MemberBaseController`, no session guard)
    - `mobileMoney()` — reads raw `php://input`, verifies HMAC signature against configured secret, calls `PaymentService::handleCallback()`, returns HTTP 200/400
    - `aggregator()` — same pattern for secondary aggregator endpoint
    - _Requirements: 5.2, 5.3_
  - [ ] 10.3 Create `app/Views/member/deposits/index.php`
    - Deposit form with amount, provider, phone; displays configured min/max deposit limits
    - Pending screen: spinner + "Approve the payment prompt on your phone" message; JS polls balance endpoint
    - _Requirements: 5.1, 5.4_
  - [ ] 10.4 Register deposit + webhook routes in `public/index.php`
    - `GET member/deposits`, `POST member/deposits/initiate`, `POST webhooks/mobile-money`, `POST webhooks/aggregator`
    - _Requirements: 5.x_

- [ ] 11. Withdrawals — OTP-confirmed withdrawal requests
  - [ ] 11.1 Create `app/Services/LienService.php`
    - `placeLien(int $guarantorMemberId, int $loanId, int $loanGuarantorId, float $amount, int $saccoId): int` — `DB::beginTransaction()`, `SELECT savings_balance … FOR UPDATE` on `member_savings_summary`, compute free balance = `savings_balance - existing_liens_total - min_balance`, throw `\RuntimeException` if `free_balance < amount`, insert `loan_liens` row, `COMMIT`, return lien ID
    - `releaseLien(int $lienId): void` — set `loan_liens.status = 'released'`, `released_at = NOW()`, send SMS to guarantor via `SmsService`
    - `getActiveLienTotal(int $memberId, int $saccoId): float`
    - `getWithdrawableBalance(int $memberId, int $saccoId): float` — savings_balance − active_liens − configured_min_balance
    - _Requirements: 5.5, 8.3, 8.4_
  - [ ] 11.2 Create withdrawal methods in `MemberAccountController`
    - `showWithdrawal()` — display withdrawal form with computed `Withdrawable_Balance` from `LienService::getWithdrawableBalance()`
    - `requestWithdrawal()` — validate amount ≤ withdrawable balance, generate OTP (`purpose = 'withdrawal'`), send SMS, redirect to OTP confirmation form
    - `confirmWithdrawal()` — verify OTP, check auto-approval limit from settings, if below limit: post `LedgerService` debit + call `PaymentService::initiateWithdrawal()`, else: create pending withdrawal record for staff approval; generate receipt on completion
    - _Requirements: 5.5, 5.6, 5.7_
  - [ ] 11.3 Create `app/Views/member/withdrawals/index.php`
    - Withdrawal form showing Withdrawable_Balance, locked amounts breakdown; OTP confirmation step
    - _Requirements: 5.5–5.7_
  - [ ] 11.4 Register withdrawal routes in `public/index.php`
    - `GET member/withdrawals`, `POST member/withdrawals/request`, `POST member/withdrawals/confirm`
    - _Requirements: 5.x_

- [ ] 12. `NotificationService` + notification preferences
  - [ ] 12.1 Create `app/Services/NotificationService.php`
    - `notify(int $memberId, int $saccoId, string $type, string $message, bool $forceSms = false): void` — insert `member_notifications` row always; check `member_notification_preferences` before SMS; security-critical categories (`password_change`, `phone_change`, `account_lock`) always send SMS regardless of preference; SMS failures caught, logged, never bubble up
    - `unreadCount(int $memberId, int $saccoId): int`
    - `markRead(int $notificationId, int $memberId): void` — sets `read_at = NOW()` only if `member_id` matches
    - _Requirements: 9.1–9.9_
  - [ ] 12.2 Create `app/Controllers/Member/MemberNotificationController.php` (extends `MemberBaseController`)
    - `index()` — paginated notification list (unread visually distinct); marks page-loaded notifications as "seen" (separate from read)
    - `markRead()` — POST `{notification_id}`, delegates to `NotificationService::markRead()`, returns JSON
    - `countAjax()` — returns JSON `{count: N}` for nav badge
    - Notification preferences page: list all categories with toggles; POST saves to `member_notification_preferences`
    - _Requirements: 9.3, 9.4, 9.7, 9.9_
  - [ ] 12.3 Create `app/Views/member/notifications/index.php`
    - Notification list with unread items highlighted (bold, blue dot); date, type icon, message; mark-all-read button
    - Notification preferences sub-page with per-category toggle switches; security categories shown as disabled/locked
    - _Requirements: 9.3, 9.4, 9.7, 9.9_
  - [ ] 12.4 Register notification routes in `public/index.php`
    - `GET member/notifications`, `POST member/notifications/read`, `GET member/api/notifications/count`
    - _Requirements: 9.x_

- [ ] 13. Loan application — member-initiated apply flow
  - [ ] 13.1 Create `app/Controllers/Member/MemberLoanController.php` (extends `MemberBaseController`)
    - `index()` — list all `loan_applications` for this member + all `loans` for this member, unified view with status from full sequence: Draft → Awaiting Guarantors → Submitted → Under Review → Approved → Rejected → Disbursed → Cleared → Defaulted
    - `showApply()` — list active `loan_products` for this SACCO with eligibility summary; render loan calculator inline
    - `calculateAjax()` — `GET member/api/loan-calculator?amount=&term=&product_id=`; calls `LoanService` to compute installment, total interest, all fees, full amortisation schedule; returns JSON; no DB writes
    - `apply()` — run eligibility checks (member status active, no overdue loans per `LoanService`, amount ≤ product max, membership duration ≥ product minimum); if passes: validate guarantors (look up by member number/phone), create `loan_applications` row with status `awaiting_guarantors` if guarantors required else `submitted`, create `loan_application_guarantors` rows, send SMS to each guarantor, `AuditLogger::log()`
    - `saveDraft()` — upsert `loan_applications` row with `status = 'draft'`
    - `cancel()` — only allowed when status is `draft` or `awaiting_guarantors`; updates status to `cancelled`
    - `view()` — show single `loan_applications` or `loans` row; if `loan_applications`: show current status, rejection reason if rejected, guarantor acceptance status; if `loans`: delegate to LoanService for all arithmetic, show migrated-loan banner if `is_migrated = 1`
    - `payoffQuote()` — calls `LoanService` for early settlement amount; returns JSON
    - `statement()` — calls `StatementService` for loan statement PDF
    - _Requirements: 6.1–6.8, 7.1–7.5, 7.10–7.11_
  - [ ] 13.2 Create loan application views in `app/Views/member/loans/`
    - `index.php` — unified list: applications with status badges + active loans with balance + arrears; "Apply" CTA button
    - `apply.php` — multi-step form: (1) product selector with eligibility summary; (2) amount + purpose + term + loan calculator (AJAX); (3) guarantor search (AJAX by member number/phone) + document uploads; draft save button at each step
    - `view.php` — three-tab layout (Summary / Schedule / Loan Card) matching admin loan details style; migrated-loan banner; all charges list with reason and date; repayment history table; no penalty amounts displayed unless staff-added
    - `repay.php` — repayment form: source selector (MoMo / from savings), amount input, payoff quote link
    - _Requirements: 6.x, 7.x_
  - [ ] 13.3 Register loan routes in `public/index.php`
    - `GET member/loans`, `GET member/loans/view`, `GET/POST member/loans/apply`, `POST member/loans/save-draft`, `POST member/loans/cancel`, `POST member/loans/repay`, `GET member/loans/payoff-quote`, `GET member/loans/statement`, `GET member/api/loan-calculator`, `GET member/api/member-search`
    - _Requirements: 6.x, 7.x_

- [ ] 14. Loan repayment — MoMo and from-savings flows
  - [ ] 14.1 Add `repay()` method to `MemberLoanController`
    - Validate loan belongs to `$this->memberId()` + `$this->saccoId()`
    - MoMo path: call `PaymentService::initiateDeposit()` with `type = 'loan_repayment'`; callback handler allocates via `LoanService` repayment allocation (penalties → interest → principal)
    - From-savings path: verify `LienService::getWithdrawableBalance() >= amount`; inside single `DB::beginTransaction()`: `SELECT … FOR UPDATE` on `member_accounts`, post savings debit via `LedgerService::post()`, call `LoanService` repayment allocation, post loan credit lines, insert `loan_repayments` row, `COMMIT`; generate receipt; send SMS confirmation
    - _Requirements: 7.7, 7.8, 7.9_
  - [ ] 14.2 Implement SMS installment reminders as a callable method in `MemberLoanController`
    - `sendInstallmentReminders()` — query `loan_schedule` for installments due in 3 days and installments that became overdue today (for the SACCO); send SMS via `SmsService`; designed to be called from a cron job or admin trigger; not auto-applied penalties
    - _Requirements: 7.12, 7.13_

- [ ] 15. Guarantor management + lien lifecycle
  - [ ] 15.1 Create `app/Controllers/Member/MemberGuarantorController.php` (extends `MemberBaseController`)
    - `index()` — list pending `loan_application_guarantors` requests for this member; list all active guarantorships (loans being guaranteed) showing borrower name, guaranteed amount, current loan status, lien status
    - `accept()` — require OTP (`purpose = 'guarantor'`): generate OTP, send SMS, return OTP form; on OTP verify: call `LienService::placeLien()` inside transaction, update `loan_application_guarantors.status = 'accepted'`, check if all guarantors accepted → if yes advance application to `submitted` + send applicant SMS, `AuditLogger::log()`
    - `reject()` — update `loan_application_guarantors.status = 'rejected'`, send SMS to applicant, `AuditLogger::log()`
    - `searchMember()` — `GET member/api/member-search?q=` — search active members by name/member_no for guarantor selection; returns JSON array; scoped by `sacco_id`; excludes the requesting member themselves
    - _Requirements: 8.1–8.7_
  - [ ] 15.2 Create `app/Views/member/guarantors/index.php`
    - Pending requests section: card per request with borrower name, loan amount, purpose, guarantee amount, "Accept" (→ OTP modal) / "Reject" buttons
    - Active guarantorships section: table with borrower, guaranteed amount, current loan status, lien amount, release date if released
    - OTP modal for accept flow
    - _Requirements: 8.1–8.7_
  - [ ] 15.3 Add lien auto-release hook to loan clearing logic
    - In `LoansController::repay()` (admin side) and `MemberLoanController::repay()`: after loan reaches `cleared` status, call `LienService::releaseLien()` for all active liens on that loan; this is done inside the same DB transaction as the final repayment
    - _Requirements: 8.6_
  - [ ] 15.4 Register guarantor routes in `public/index.php`
    - `GET member/guarantors`, `POST member/guarantors/accept`, `POST member/guarantors/reject`, `GET member/api/member-search`
    - _Requirements: 8.x_

- [ ] 16. Checkpoint — wire all Phase 1 routes, smoke-test end-to-end
  - Ensure all 37 member routes defined in design.md route table are registered in `public/index.php`
  - Verify member login → OTP → dashboard → deposit flow renders without errors
  - Verify no admin route is accessible from a member session (check `.htaccess` + router guard)
  - Verify no member route is accessible from a staff session
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 17. Property-based and unit tests
  - [ ]* 17.1 Write property test for Ledger Balance Invariant (Property 1)
    - **Property 1: Ledger Balance Invariant**
    - **Validates: Requirements 15.1, 15.2, 15.5**
    - File: `tests/Property/LedgerBalanceInvariantTest.php`
    - For any sequence of N deposits and M withdrawals posted via `LedgerService::post()`, `getMemberSavingsBalance()` must equal `SUM(credit) - SUM(debit)` across all posted lines for that member — checked after each posting
    - Use eris or a simple loop-based property runner with 100+ random amount sequences
  - [ ]* 17.2 Write property test for Idempotency of Payment Postings (Property 2)
    - **Property 2: Idempotency of Payment Postings**
    - **Validates: Requirements 5.3, 7.7, 15.4**
    - File: `tests/Property/PaymentIdempotencyTest.php`
    - For any `idempotency_key`, calling `PaymentService::handleCallback()` N times (N ≥ 2) with `status = 'success'` must yield exactly 1 row in `journal_entries` and 1 `payment_transactions` row with `status = 'completed'`; subsequent calls must be no-ops
  - [ ]* 17.3 Write property test for Lien Non-Exceedance Invariant (Property 3)
    - **Property 3: Lien Non-Exceedance Invariant**
    - **Validates: Requirements 8.3, 8.4**
    - File: `tests/Property/LienNonExceedanceTest.php`
    - For any savings balance and any sequence of `LienService::placeLien()` calls, `SUM(active liens)` must never exceed the member's savings_balance; lien placements that would breach this must throw `RuntimeException` and leave no partial state
  - [ ]* 17.4 Write property test for Member Data Isolation (Property 4)
    - **Property 4: Member Data Isolation**
    - **Validates: Requirements 14.6, 17.1**
    - File: `tests/Property/MemberDataIsolationTest.php`
    - For any two distinct member sessions (A, B), every row returned by any account/loan/transaction query executed with A's `member_id` + `sacco_id` must have `member_id = A.member_id`; no row belonging to B must appear
  - [ ]* 17.5 Write unit test for No-Auto-Penalty Invariant (Property 5)
    - **Property 5: No Auto-Penalty Insertion**
    - **Validates: Requirements 7.6**
    - File: `tests/Unit/NoAutoPenaltyTest.php`
    - Verify that `MemberLoanController::repay()`, `PaymentService::handleCallback()`, and `MemberWebhookController::mobileMoney()` never insert a `loan_charges` row with `charge_type = 'late_payment_fee'` — assert `loan_charges` table count is unchanged before and after each operation
  - [ ]* 17.6 Write integration tests for auth flow
    - File: `tests/Integration/MemberAuthIntegrationTest.php`
    - Login with correct credentials → correct OTP → session created
    - Login with 5 wrong passwords → member `status = 'locked'`
    - Wrong OTP 3 times → OTP locked for 15 min (cannot verify even with correct OTP)
    - _Requirements: 1.1–1.4_

- [ ] 18. Final checkpoint — all tests, security review
  - Run all PHPUnit test suites; confirm zero failures
  - Verify CSRF token present on every POST form in member views
  - Verify every money-changing controller action uses `DB::beginTransaction()` / `COMMIT` / `ROLLBACK`
  - Verify `htmlspecialchars` / `e()` used on all user-supplied output in member views
  - Confirm `AuditLogger::log()` called in: profile updates, phone change, loan application, repayment, guarantor accept/reject, password change
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 19. Phase 2 — Airtime purchases (optional)
  - [ ]* 19.1 Create airtime purchase method in `MemberAccountController`
    - `showAirtime()` / `purchaseAirtime()` — debit Savings_Balance only; call `PaymentService` for aggregator; list saved beneficiaries; per-transaction and per-day limits from settings
    - Saved beneficiaries: `POST member/airtime/save-beneficiary`, `DELETE member/airtime/delete-beneficiary`
    - _Requirements: 10.1–10.8_
  - [ ]* 19.2 Create `app/Views/member/airtime/index.php`
    - Network selector, recipient phone, amount, saved beneficiaries list; PIN/OTP confirmation step
    - _Requirements: 10.x_

- [ ] 20. Phase 2 — Bill payments (optional)
  - [ ]* 20.1 Create `app/Controllers/Member/MemberBillController.php` (extends `MemberBaseController`)
    - `index()` — list active Admin-configured billers
    - `validate()` — AJAX: send meter/account number to aggregator for customer name validation
    - `pay()` — validate reference, confirm amount, call `PaymentService`, post Ledger debit, send token via SMS
    - Saved beneficiaries management
    - _Requirements: 11.1–11.8_
  - [ ]* 20.2 Create `app/Views/member/bills/index.php`
    - Biller selector, reference number input, AJAX validation step, payment confirmation screen
    - _Requirements: 11.x_

- [ ] 21. Phase 2 — Governance and communication (optional)
  - [ ]* 21.1 Create `app/Controllers/Member/MemberGovernanceController.php` (extends `MemberBaseController`)
    - `announcements()` — list active announcements scoped by `sacco_id`
    - `meetings()` — list scheduled meetings + AGMs + download links for minutes
    - `support()` GET/POST — create support ticket with unique reference, SMS acknowledgement
    - `documents()` — list Admin-published FAQs/policies/bylaws
    - `vote()` — if e-voting enabled for resolution: cast exactly one vote, prevent re-vote
    - _Requirements: 12.1–12.7_
  - [ ]* 21.2 Create governance views in `app/Views/member/governance/`
    - Announcements list, meetings list, support ticket form + status page, documents list, voting page
    - _Requirements: 12.x_
  - [ ]* 21.3 Create savings goals and exit request methods (additional member services)
    - Savings goals: create goal (name, target amount, target date, linked account), progress bar
    - Exit request: create pending exit record, SMS notification, audit log
    - Language preference: persist to session + member profile; English / Luganda toggle
    - _Requirements: 13.1–13.4_

---

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- The existing `MemberDashboardController` in `App\Controllers\` is a placeholder — it uses `$_SESSION['member_id']` (old namespace). Task 6 replaces it with `App\Controllers\Member\MemberDashboardController` using `$_SESSION['member']['member_id']`
- `LoanService` and `StatementService` are shared services — import and call them, never duplicate their logic
- Property tests (17.1–17.5) validate the correctness properties defined in design.md. Each property test is a separate file so it can be run individually
- Phase 2 tasks (19–21) depend on Phase 1 completing cleanly. Do not start Phase 2 until all Phase 1 checkpoints pass
- Currency: UGX, stored as `DECIMAL(18,2)`. Never float/double in money fields
- All dates displayed in `Africa/Kampala` timezone (UTC+3); `DB::pdo()` already sets `SET time_zone = '+03:00'`
- Phone numbers normalized to `256XXXXXXXXX` via `SmsService::formatPhone()` before any SMS or MoMo call
- `Csrf::field()` and `Csrf::verify()` are used as-is from the existing `App\Core\Csrf` class

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "2.1", "2.2", "2.3"] },
    { "id": 2, "tasks": ["2.4", "3.1"] },
    { "id": 3, "tasks": ["3.2", "4.1"] },
    { "id": 4, "tasks": ["4.2", "4.3"] },
    { "id": 5, "tasks": ["5.1", "5.2", "5.3"] },
    { "id": 6, "tasks": ["6.1", "6.2"] },
    { "id": 7, "tasks": ["6.3", "7.1"] },
    { "id": 8, "tasks": ["7.2", "7.3", "8.1"] },
    { "id": 9, "tasks": ["8.2", "8.3", "9.1", "9.2"] },
    { "id": 10, "tasks": ["10.1", "10.2"] },
    { "id": 11, "tasks": ["10.3", "10.4", "11.1"] },
    { "id": 12, "tasks": ["11.2", "11.3", "11.4", "12.1"] },
    { "id": 13, "tasks": ["12.2", "12.3", "12.4", "13.1"] },
    { "id": 14, "tasks": ["13.2", "13.3", "14.1"] },
    { "id": 15, "tasks": ["14.2", "15.1"] },
    { "id": 16, "tasks": ["15.2", "15.3", "15.4"] },
    { "id": 17, "tasks": ["17.1", "17.2", "17.3", "17.4", "17.5"] },
    { "id": 18, "tasks": ["17.6"] },
    { "id": 19, "tasks": ["19.1", "20.1", "21.1"] },
    { "id": 20, "tasks": ["19.2", "20.2", "21.2", "21.3"] }
  ]
}
```

# Design Document

## Member Portal — SACCOPLUS PHP

---

## Overview

The Member Portal is a member-facing self-service web application that runs under the `/member` URL prefix on the same Apache/Nginx server and MySQL database as the SACCOPLUS admin system. It is built with the same PHP 8.1+ MVC-lite skeleton, the same shared Services layer, and the same single CSS file.

The portal is intentionally **not** a separate application. It reuses `app/Core/`, all existing Services (`LoanService`, `StatementService`, `SmsService`), the front controller (`public/index.php`), and the existing `.htaccess` rewrites. New code is added as new namespaces, new view directories, and new database tables—nothing existing is modified.

Key design invariants:
- Member session (`$_SESSION['member']`) is completely separate from staff session (`$_SESSION['user']`).
- All money movements: DB transaction + `SELECT … FOR UPDATE` + double-entry `journal_entries`/`journal_lines`.
- All loan arithmetic goes through `LoanService`. No formulas in views or member controllers.
- No automatic penalty insertion of any kind.
- Migrated loan arrears start from `loans.migrated_balance` / `loans.migrated_date`.
- Every query is scoped by `sacco_id`.

---

## Architecture

### High-Level Component Map

```
Browser
  │  HTTPS
  ▼
public/index.php  ← single front controller
  │
  ├── /member/* routes  ──▶  App\Controllers\Member\*   (new)
  │                               │
  │                               ├── MemberBaseController  (auth guard + sacco guard)
  │                               ├── MemberAuthController
  │                               ├── MemberDashboardController
  │                               ├── MemberAccountController
  │                               ├── MemberLoanController
  │                               ├── MemberGuarantorController
  │                               ├── MemberNotificationController
  │                               ├── MemberProfileController
  │                               └── MemberWebhookController (no session guard)
  │
  ├── /webhooks/* routes ──▶  App\Controllers\Member\MemberWebhookController
  │
  └── /admin & all other routes — untouched (staff only)

App\Controllers\Member\*
  │
  ├── App\Services\LoanService       (existing, shared)
  ├── App\Services\StatementService  (existing, shared)
  ├── App\Services\SmsService        (existing, shared)
  ├── App\Services\PaymentService    (new)
  ├── App\Services\LienService       (new)
  ├── App\Services\NotificationService (new)
  ├── App\Services\ReceiptService    (new)
  └── App\Services\LedgerService     (new — extracted double-entry posting logic)

App\Core\* (Router, DB, View, Csrf, Auth) — untouched
```

### Request Lifecycle

1. Browser hits any URL → `public/.htaccess` strips extension, rewrites to `public/index.php?_url=...`
2. `index.php` calls `$router->dispatch()`
3. Router resolves to `[ControllerClass, 'method']`
4. All `/member/*` controllers extend `MemberBaseController::__construct()` which:
   - Verifies `$_SESSION['member']['member_id']` exists
   - Verifies `$_SESSION['member']['sacco_id']` matches the member's DB row
   - Checks session inactivity (`last_activity` timestamp)
   - If any check fails → destroys session → redirects to `/member/login`
5. Webhook routes skip `MemberBaseController` and use their own HMAC signature verification.

### Session Namespace Design

Staff session key: `$_SESSION['user']` (array: `id`, `sacco_id`, `role`, etc.)  
Member session key: `$_SESSION['member']` (array: `member_id`, `sacco_id`, `full_name`, `must_change_password`, `last_activity`)

These two arrays are independent. The Router's access guard in `index.php` enforces:
- Any route starting with `member/` may ONLY be dispatched if `$_SESSION['member']` is populated. A `$_SESSION['user']` being present does NOT grant member access.
- Any route NOT starting with `member/` or `webhooks/` must have `$_SESSION['user']` populated (existing admin guard — unchanged).
- No cross-contamination is possible because the session keys are different and never read cross-namespace.

---

## Components and Interfaces

### MemberBaseController

```php
namespace App\Controllers\Member;

abstract class MemberBaseController
{
    protected array $member; // $_SESSION['member']

    public function __construct()
    {
        // 1. Session must have member key
        if (empty($_SESSION['member']['member_id'])) {
            $this->redirectToLogin();
        }

        // 2. Inactivity check (30 minutes)
        $idle = time() - ($_SESSION['member']['last_activity'] ?? 0);
        if ($idle > 1800) {
            session_unset();
            session_destroy();
            $this->redirectToLogin('Session expired due to inactivity.');
        }
        $_SESSION['member']['last_activity'] = time();

        // 3. DB integrity check — member must still be active in their sacco
        $this->verifyMemberSession();

        $this->member = $_SESSION['member'];
    }

    private function verifyMemberSession(): void
    {
        $db = \App\Core\DB::pdo();
        $st = $db->prepare(
            "SELECT id, sacco_id, status FROM members WHERE id = ? AND sacco_id = ? LIMIT 1"
        );
        $st->execute([
            $_SESSION['member']['member_id'],
            $_SESSION['member']['sacco_id'],
        ]);
        $row = $st->fetch();
        if (!$row || $row['status'] === 'exited') {
            session_unset();
            session_destroy();
            $this->redirectToLogin('Your account is no longer active.');
        }
    }

    protected function redirectToLogin(string $msg = ''): never
    {
        if ($msg) $_SESSION['member_error'] = $msg;
        header('Location: ' . url('member/login'));
        exit;
    }

    protected function memberId(): int  { return (int)$this->member['member_id']; }
    protected function saccoId(): int   { return (int)$this->member['sacco_id']; }
}
```

### MemberAuthController

Handles login, OTP verification, password change, and password reset. Does **not** extend `MemberBaseController` (no auth guard needed).

Key methods:
- `showLogin()` / `login()` — validate credentials against `members` table (by `member_no` or `phone`), check `status`, hash OTP, store in `member_otp`, call `SmsService::sendOTP()`, redirect to OTP screen.
- `showOtp()` / `verifyOtp()` — find OTP row, verify hash, check expiry + attempt count, call `createMemberSession()`, redirect to dashboard or force-password-change page.
- `showForgotPassword()` / `forgotPassword()` — same OTP flow with `purpose = 'reset'`.
- `showResetPassword()` / `resetPassword()` — verify OTP, validate new password strength, `password_hash(PASSWORD_ARGON2ID)`, update `members.password_hash`, log to `audit_logs`, send SMS alert.
- `showChangePassword()` / `changePassword()` — protected (member must be logged in), verify current password, update, SMS.
- `logout()` — destroy `$_SESSION['member']`, redirect to login.

OTP locking rules:
- 3 wrong OTP attempts in one login attempt → lock OTP for 15 minutes (tracked in `member_otp.attempts` + `expires_at` being reset).
- 5 wrong password attempts → set `members.status = 'locked'`, send SMS alert.

```php
private function createMemberSession(array $member): void
{
    session_regenerate_id(true);
    $_SESSION['member'] = [
        'member_id'           => (int)$member['id'],
        'sacco_id'            => (int)$member['sacco_id'],
        'full_name'           => $member['full_name'],
        'member_no'           => $member['member_no'],
        'must_change_password'=> (bool)($member['must_change_password'] ?? false),
        'last_activity'       => time(),
    ];
}
```

### PaymentService

Wraps the MoMo aggregator API. Completely separate from ledger posting; ledger work is done inside `LedgerService`.

```php
namespace App\Services;

class PaymentService
{
    /**
     * Initiate a mobile money payment prompt.
     * Returns the idempotency key (UUID v4) to be shown as a reference.
     */
    public function initiateDeposit(
        int $memberId, int $saccoId, float $amount, string $phone, string $provider
    ): string;

    /**
     * Handle an incoming aggregator callback (from /webhooks/mobile-money).
     * Idempotent: if the key already has status=completed, returns without re-posting.
     */
    public function handleCallback(array $payload): void;

    /**
     * Initiate a withdrawal payout (staff-approved or auto-approved).
     */
    public function initiateWithdrawal(int $paymentTxnId): void;
}
```

Internal flow for `handleCallback()`:
1. Find `payment_transactions` row by `idempotency_key` — if not found → log + return 400.
2. Verify HMAC signature of callback payload.
3. `SELECT … FOR UPDATE` on `payment_transactions` row.
4. If `status = 'completed'` → return 200 (idempotent).
5. Validate amount matches.
6. Call `LedgerService::post()` inside `DB::beginTransaction()`.
7. Update `payment_transactions.status = 'completed'`, `journal_entry_id`, `provider_ref`.
8. `COMMIT`.
9. Queue `ReceiptService::generate()` and `NotificationService::notify()`.

### LedgerService

Extracted from the existing teller posting logic into a shared service usable by both admin and member portal.

```php
namespace App\Services;

class LedgerService
{
    /**
     * Post a double-entry journal entry.
     * @param array $entry  Keys: sacco_id, branch_id, txn_type, description, value_date,
     *                             posted_by (user or member id), idempotency_key (optional)
     * @param array $lines  Each: ['gl_account_id', 'member_account_id'|null, 'loan_id'|null,
     *                              'debit', 'credit']
     * @throws \RuntimeException if SUM(debit) != SUM(credit) or DB error
     * @return int  journal_entries.id
     */
    public function post(array $entry, array $lines): int;

    /**
     * Reverse a posted journal entry.
     * Creates a mirror entry where debits and credits are swapped.
     * @return int  New journal_entries.id (the reversal)
     */
    public function reverse(int $entryId, string $reason, int $postedBy): int;

    /**
     * Get member savings balance (sum of credit - debit for member's GL accounts).
     */
    public function getMemberSavingsBalance(int $memberId, int $saccoId): float;
}
```

`post()` enforces `SUM(debit) = SUM(credit)` before inserting. If they don't balance, it throws a `\RuntimeException` and never touches the DB.

### LienService

```php
namespace App\Services;

class LienService
{
    /**
     * Place a lien on a guarantor's savings balance.
     * Uses SELECT FOR UPDATE on member_savings_summary.
     * @throws \RuntimeException if free balance < amount
     */
    public function placeLien(
        int $guarantorMemberId, int $loanId, int $loanGuarantorId,
        float $amount, int $saccoId
    ): int; // returns loan_liens.id

    /**
     * Release a lien when a guaranteed loan is cleared or guarantor is removed.
     * Restores free balance, sends SMS notification via SmsService.
     */
    public function releaseLien(int $lienId): void;

    /**
     * Get total active lien amount for a member.
     */
    public function getActiveLienTotal(int $memberId, int $saccoId): float;

    /**
     * Compute withdrawable balance: savings_balance - active_liens - min_balance.
     */
    public function getWithdrawableBalance(int $memberId, int $saccoId): float;
}
```

`placeLien()` internal flow:
1. `DB::beginTransaction()`
2. `SELECT savings_balance FROM member_savings_summary WHERE member_id = ? FOR UPDATE`
3. Compute free balance = `savings_balance - existing_liens_total - configured_min_balance`
4. If `free_balance < amount` → `ROLLBACK` → throw `\RuntimeException`
5. `INSERT INTO loan_liens ...`
6. `COMMIT`

### NotificationService

```php
namespace App\Services;

class NotificationService
{
    /**
     * Create an in-app notification and optionally send SMS.
     * Checks member_notification_preferences before sending SMS.
     * Security-critical categories (password_change, phone_change, account_lock)
     * always send SMS regardless of preferences.
     */
    public function notify(
        int $memberId, int $saccoId, string $type, string $message,
        bool $forceSms = false
    ): void;

    /**
     * Count unread notifications for a member (used by dashboard badge).
     */
    public function unreadCount(int $memberId, int $saccoId): int;

    /**
     * Mark notification(s) as read.
     */
    public function markRead(int $notificationId, int $memberId): void;
}
```

SMS is sent synchronously via `SmsService::send()`. On failure, the failure is logged to `sms_failures` (existing mechanism in `SmsService`). The in-app notification is always written regardless of SMS outcome.

### ReceiptService

```php
namespace App\Services;

class ReceiptService
{
    /**
     * Generate a PDF receipt, save it, and insert a receipts row.
     * Uses Dompdf (already a Composer dependency).
     * @return string  Sequential receipt number (e.g. "RCP-0001-2026")
     */
    public function generate(
        int $memberId, int $saccoId, string $txnType,
        float $amount, int $journalEntryId, array $meta = []
    ): string;

    /**
     * Retrieve the file path for a receipt owned by memberId.
     * Returns null if not found or not owned by this member.
     */
    public function getPath(int $receiptId, int $memberId, int $saccoId): ?string;
}
```

Receipt PDF layout follows the bank statement style described in Requirement 4.3: SACCO header (name, logo, address), member name + account number, transaction type, amount, date/time, reference number, receipt number, teller/system identifier.

Sequential receipt number is generated inside a DB transaction with `SELECT MAX(receipt_seq) + 1 FROM receipts WHERE sacco_id = ? FOR UPDATE` to ensure uniqueness per SACCO.

---

## Data Models

### New Database Tables (Full DDL)

```sql
-- ============================================================
-- MEMBER PORTAL ADDITIONS — migrations/002_member_portal.sql
-- ============================================================
USE saccoplus_v2;

-- 1. Login history (last 10 per member retained)
CREATE TABLE member_login_history (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id    BIGINT UNSIGNED NOT NULL,
  member_id   BIGINT UNSIGNED NOT NULL,
  ip          VARCHAR(45) NOT NULL,
  user_agent  TEXT,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_login_hist (sacco_id, member_id, created_at),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. OTP store (login / reset / phone_change / guarantor / withdrawal)
CREATE TABLE member_otp (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id    BIGINT UNSIGNED NOT NULL,
  member_id   BIGINT UNSIGNED NOT NULL,
  otp_hash    VARCHAR(255) NOT NULL,
  purpose     ENUM('login','reset','phone_change','guarantor','withdrawal') NOT NULL,
  expires_at  TIMESTAMP NOT NULL,
  attempts    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  used_at     TIMESTAMP NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_otp_member (member_id, purpose, expires_at),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Change requests for sensitive fields (require staff approval)
CREATE TABLE member_change_requests (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id     BIGINT UNSIGNED NOT NULL,
  member_id    BIGINT UNSIGNED NOT NULL,
  field_name   VARCHAR(50) NOT NULL,
  old_value    TEXT,
  new_value    TEXT NOT NULL,
  status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  reviewed_by  BIGINT UNSIGNED NULL,
  review_note  TEXT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at  TIMESTAMP NULL,
  KEY idx_chgreq (sacco_id, member_id, status),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Next of kin (already partially exists in prod; clean canonical table)
CREATE TABLE member_next_of_kin (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id      BIGINT UNSIGNED NOT NULL,
  member_id     BIGINT UNSIGNED NOT NULL,
  full_name     VARCHAR(150) NOT NULL,
  relationship  VARCHAR(60) NOT NULL,
  phone         VARCHAR(30),
  share_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_nok (member_id),
  CONSTRAINT chk_share_pct CHECK (share_percent >= 0 AND share_percent <= 100),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Member documents (profile photo, national ID scans, loan supporting docs)
CREATE TABLE member_documents (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id     BIGINT UNSIGNED NOT NULL,
  member_id    BIGINT UNSIGNED NOT NULL,
  doc_type     VARCHAR(50) NOT NULL COMMENT 'profile_photo, id_front, id_back, loan_support, other',
  filename     VARCHAR(120) NOT NULL COMMENT 'random UUID filename',
  mime_type    VARCHAR(60) NOT NULL,
  file_path    VARCHAR(500) NOT NULL COMMENT 'absolute path outside web root',
  related_id   BIGINT UNSIGNED NULL COMMENT 'loan_application.id when doc_type = loan_support',
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_docs (sacco_id, member_id, doc_type),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. In-app notifications
CREATE TABLE member_notifications (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id   BIGINT UNSIGNED NOT NULL,
  member_id  BIGINT UNSIGNED NOT NULL,
  type       VARCHAR(60) NOT NULL,
  message    TEXT NOT NULL,
  read_at    TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_notif (sacco_id, member_id, read_at, created_at),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Notification preferences per category
CREATE TABLE member_notification_preferences (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id    BIGINT UNSIGNED NOT NULL,
  member_id   BIGINT UNSIGNED NOT NULL,
  category    VARCHAR(60) NOT NULL,
  sms_enabled TINYINT(1) NOT NULL DEFAULT 1,
  inapp_enabled TINYINT(1) NOT NULL DEFAULT 1,
  UNIQUE KEY uq_notif_pref (member_id, category),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Payment transactions (MoMo deposits, withdrawals, airtime, bill payments)
CREATE TABLE payment_transactions (
  id               BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id         BIGINT UNSIGNED NOT NULL,
  member_id        BIGINT UNSIGNED NOT NULL,
  idempotency_key  CHAR(36) NOT NULL COMMENT 'UUID v4',
  type             ENUM('deposit','withdrawal','loan_repayment','airtime','bill') NOT NULL,
  amount           DECIMAL(18,2) NOT NULL,
  provider         ENUM('mtn','airtel','cash','other') NOT NULL,
  phone            VARCHAR(30) NOT NULL,
  status           ENUM('pending','completed','failed','reversed') NOT NULL DEFAULT 'pending',
  provider_ref     VARCHAR(120) NULL COMMENT 'Gateway transaction reference',
  journal_entry_id BIGINT UNSIGNED NULL,
  failure_reason   TEXT NULL,
  created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at     TIMESTAMP NULL,
  UNIQUE KEY uq_idem_key (idempotency_key),
  KEY idx_pt_member (sacco_id, member_id, created_at),
  KEY idx_pt_status (sacco_id, status),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Loan liens (guarantor savings/shares locks)
CREATE TABLE loan_liens (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id            BIGINT UNSIGNED NOT NULL,
  guarantor_member_id BIGINT UNSIGNED NOT NULL,
  loan_id             BIGINT UNSIGNED NOT NULL,
  loan_guarantor_id   BIGINT UNSIGNED NULL COMMENT 'loan_application_guarantors.id',
  amount              DECIMAL(18,2) NOT NULL,
  status              ENUM('active','released') NOT NULL DEFAULT 'active',
  released_at         TIMESTAMP NULL,
  created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_liens_guarantor (sacco_id, guarantor_member_id, status),
  KEY idx_liens_loan (loan_id),
  FOREIGN KEY (guarantor_member_id) REFERENCES members(id),
  FOREIGN KEY (loan_id) REFERENCES loans(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Loan applications (member-initiated, pre-approval stage)
--     NOTE: This is distinct from the `loans` table.
--     A loan_application becomes a `loans` row only after staff approval + disbursal.
CREATE TABLE loan_applications (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id        BIGINT UNSIGNED NOT NULL,
  member_id       BIGINT UNSIGNED NOT NULL,
  product_id      BIGINT UNSIGNED NOT NULL,
  ref_no          VARCHAR(30) NOT NULL,
  amount          DECIMAL(18,2) NOT NULL,
  purpose         TEXT NOT NULL,
  term_months     INT UNSIGNED NOT NULL,
  status          ENUM(
                    'draft','awaiting_guarantors','submitted',
                    'under_review','approved','rejected','disbursed','cleared','defaulted'
                  ) NOT NULL DEFAULT 'draft',
  rejection_reason TEXT NULL,
  loan_id         BIGINT UNSIGNED NULL COMMENT 'Set when disbursed to loans.id',
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ref_no (sacco_id, ref_no),
  KEY idx_la_member (sacco_id, member_id, status),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (product_id) REFERENCES loan_products(id),
  FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Guarantors per loan application
CREATE TABLE loan_application_guarantors (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  application_id      BIGINT UNSIGNED NOT NULL,
  guarantor_member_id BIGINT UNSIGNED NOT NULL,
  amount              DECIMAL(18,2) NOT NULL,
  status              ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  responded_at        TIMESTAMP NULL,
  KEY idx_lag_app (application_id),
  KEY idx_lag_guarantor (guarantor_member_id, status),
  FOREIGN KEY (application_id) REFERENCES loan_applications(id) ON DELETE CASCADE,
  FOREIGN KEY (guarantor_member_id) REFERENCES members(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Receipts
CREATE TABLE receipts (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id        BIGINT UNSIGNED NOT NULL,
  member_id       BIGINT UNSIGNED NOT NULL,
  receipt_no      VARCHAR(30) NOT NULL,
  receipt_seq     INT UNSIGNED NOT NULL COMMENT 'Sequential number per sacco per year',
  txn_year        YEAR NOT NULL,
  transaction_type VARCHAR(60) NOT NULL,
  amount          DECIMAL(18,2) NOT NULL,
  journal_entry_id BIGINT UNSIGNED NULL,
  pdf_path        VARCHAR(500) NOT NULL,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_receipt_no (sacco_id, receipt_no),
  KEY idx_receipts_member (sacco_id, member_id, created_at),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Rate limiting (replaces session-only approach for distributed safety)
CREATE TABLE rate_limits (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bucket_key   VARCHAR(120) NOT NULL COMMENT 'e.g. login:ip:192.168.1.1 or payment:member:42',
  attempts     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  window_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_bucket (bucket_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Additions to Existing Tables

The `members` table needs two additional columns (applied via migration):

```sql
ALTER TABLE members
  ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 0
    COMMENT 'Set to 1 on first login; portal forces a password change',
  ADD COLUMN login_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN login_locked_until TIMESTAMP NULL,
  ADD COLUMN password_hash VARCHAR(255) NULL
    COMMENT 'Argon2id hash; NULL until member first logs in via portal';
```

> **Note:** `members.password_hash` is separate from `users.password_hash`. Staff have a `users` row; members authenticate through `members` directly. This avoids confusing role blending and matches the session namespace separation.

---

## Route Table

All routes are registered in `public/index.php`. Member controllers live in `App\Controllers\Member\*`. Webhook routes are public (no session guard).

| Method | Route | Controller::method | Notes |
|--------|-------|--------------------|-------|
| GET | `member/login` | `MemberAuthController::showLogin` | No auth guard |
| POST | `member/login` | `MemberAuthController::login` | Rate-limited (5/min/IP) |
| GET | `member/login/otp` | `MemberAuthController::showOtp` | |
| POST | `member/login/otp` | `MemberAuthController::verifyOtp` | |
| POST | `member/login/resend-otp` | `MemberAuthController::resendOtp` | |
| GET | `member/logout` | `MemberAuthController::logout` | Destroys member session |
| GET | `member/forgot-password` | `MemberAuthController::showForgotPassword` | |
| POST | `member/forgot-password` | `MemberAuthController::forgotPassword` | |
| GET | `member/reset-password` | `MemberAuthController::showResetPassword` | |
| POST | `member/reset-password` | `MemberAuthController::resetPassword` | |
| GET | `member/change-password` | `MemberAuthController::showChangePassword` | Auth guard |
| POST | `member/change-password` | `MemberAuthController::changePassword` | Auth guard |
| GET | `member/dashboard` | `MemberDashboardController::index` | Auth guard |
| GET | `member/profile` | `MemberProfileController::show` | Auth guard |
| POST | `member/profile/update` | `MemberProfileController::update` | Email/address only |
| POST | `member/profile/request-change` | `MemberProfileController::requestChange` | Sensitive fields |
| GET | `member/profile/documents` | `MemberProfileController::documents` | |
| POST | `member/profile/documents/upload` | `MemberProfileController::upload` | |
| GET | `member/accounts` | `MemberAccountController::index` | |
| GET | `member/accounts/transactions` | `MemberAccountController::transactions` | Paginated |
| GET | `member/accounts/statement` | `MemberAccountController::statement` | PDF download |
| GET | `member/deposits` | `MemberAccountController::showDeposit` | |
| POST | `member/deposits/initiate` | `MemberAccountController::initiateDeposit` | Rate-limited (10/15min/member) |
| GET | `member/withdrawals` | `MemberAccountController::showWithdrawal` | |
| POST | `member/withdrawals/request` | `MemberAccountController::requestWithdrawal` | OTP required |
| GET | `member/loans` | `MemberLoanController::index` | |
| GET | `member/loans/view` | `MemberLoanController::view` | ?id= |
| GET | `member/loans/apply` | `MemberLoanController::showApply` | |
| POST | `member/loans/apply` | `MemberLoanController::apply` | |
| POST | `member/loans/save-draft` | `MemberLoanController::saveDraft` | |
| POST | `member/loans/cancel` | `MemberLoanController::cancel` | Draft/awaiting only |
| POST | `member/loans/repay` | `MemberLoanController::repay` | MoMo or savings |
| GET | `member/loans/payoff-quote` | `MemberLoanController::payoffQuote` | |
| GET | `member/loans/statement` | `MemberLoanController::statement` | PDF |
| GET | `member/guarantors` | `MemberGuarantorController::index` | |
| POST | `member/guarantors/accept` | `MemberGuarantorController::accept` | OTP required |
| POST | `member/guarantors/reject` | `MemberGuarantorController::reject` | |
| GET | `member/notifications` | `MemberNotificationController::index` | |
| POST | `member/notifications/read` | `MemberNotificationController::markRead` | |
| GET | `member/receipts` | `MemberAccountController::receipts` | |
| GET | `member/receipts/download` | `MemberAccountController::downloadReceipt` | ?id= |
| POST | `webhooks/mobile-money` | `MemberWebhookController::mobileMoney` | HMAC verified |
| POST | `webhooks/aggregator` | `MemberWebhookController::aggregator` | HMAC verified |
| GET | `member/api/loan-calculator` | `MemberLoanController::calculateAjax` | JSON |
| GET | `member/api/member-search` | `MemberGuarantorController::searchMember` | JSON, for guarantor |
| GET | `member/api/balance` | `MemberAccountController::balanceAjax` | JSON |
| GET | `member/api/notifications/count` | `MemberNotificationController::countAjax` | JSON |
| GET | `member/api/ping` | `MemberAuthController::ping` | Updates last_activity |

---

## Folder Structure

```
/app
  /Controllers
    /Member
      MemberBaseController.php
      MemberAuthController.php
      MemberDashboardController.php
      MemberAccountController.php
      MemberLoanController.php
      MemberGuarantorController.php
      MemberNotificationController.php
      MemberProfileController.php
      MemberWebhookController.php
  /Services
    LedgerService.php          (new — extracted from TellerController)
    PaymentService.php         (new)
    LienService.php            (new)
    NotificationService.php    (new)
    ReceiptService.php         (new)
    LoanService.php            (existing — shared, no changes)
    StatementService.php       (existing — shared, no changes)
    SmsService.php             (existing — shared, no changes)
  /Views
    /member
      layout.php               (member layout, same structure as admin layout.php)
      /auth
        login.php
        otp.php
        change-password.php
        forgot-password.php
        reset-password.php
      dashboard.php
      /profile
        index.php
        documents.php
      /accounts
        index.php
        transactions.php
        statement.php
      /deposits
        index.php
      /withdrawals
        index.php
      /loans
        index.php
        view.php
        apply.php
        repay.php
      /guarantors
        index.php
      /notifications
        index.php
      /receipts
        index.php
/database
  /migrations
    001_initial_schema.sql     (existing schema.sql)
    002_member_portal.sql      (new tables above)
    003_member_columns.sql     (ALTER TABLE members additions)
/storage
  /receipts
    /{sacco_id}/{year}/        (PDF receipts — outside web root)
```

---

## UI Design

### Member Layout (`/app/Views/member/layout.php`)

Uses the **same HTML skeleton** as `/app/Views/layout.php`. No new CSS file is introduced. A new section `/* === MEMBER PORTAL ===` is appended to `public/assets/css/app.css` containing only additive overrides for the member bottom-navigation bar on mobile.

Member-specific navigation:
- Desktop: top navigation bar (no sidebar — members have fewer sections)
- Mobile (< 768 px): bottom tab bar with icons: Home, Accounts, Loans, Guarantors, Notifications

All card, badge, label/value, table, button, and form styles are inherited unchanged from the existing admin CSS.

### Key Page Sketches

**Dashboard** — White cards showing:
- Savings balance (large hero number), shares balance, total outstanding loan balance
- Arrears warning card (red border, visible only when overdue installments exist)
- Last 5 transactions table (date, description, amount with ±colour, running balance)
- Upcoming installments within 30 days
- Quick-action buttons: Deposit, Apply Loan, Repay Loan, View Statement
- Notification badge on nav item when unread count > 0
- Guarantor request badge when pending requests exist

**Loan Detail** — Three tabs (Summary / Schedule / Loan Card), identical tab component style to admin loan details page. Migrated-loan banner shown when `is_migrated = 1`.

**Account Statement** — Invokes `StatementService::getStatementData()`, renders a printable page, and offers a PDF download button that POSTs to `/member/accounts/statement` triggering `ReceiptService` via Dompdf.

---

## Security Design

### Input Validation

All POST parameters validated before any DB query:
- Monetary amounts: cast to `float`, check > 0, check against configured limits.
- Member IDs in URLs (`?id=X`): cast to `int`, then SELECT with `member_id = ? AND sacco_id = ?` so a member cannot access another member's data even if they guess the ID.
- File uploads: whitelist MIME types (`image/jpeg`, `image/png`, `application/pdf`), max 5 MB, `random_bytes(16)` filename, stored to `/storage/uploads/` (outside web root).
- Phone numbers: normalised to `256XXXXXXXXX` via `SmsService::formatPhone()` before any SMS or MoMo call.

### CSRF

Every POST form in member views calls `Csrf::field()`. Every POST handler calls `Csrf::verify()`. The existing `Csrf` class is reused without modification. Member CSRF tokens live in `$_SESSION['_csrf']` — the same session key used by the admin side; this is safe because member and staff sessions are never active simultaneously on the same PHP session ID (different session IDs after `session_regenerate_id()`).

### Rate Limiting

`App\Core\RateLimiter` (new small class) wraps the `rate_limits` table:

```php
// Check and increment atomically
RateLimiter::check('login:ip:' . $ip, 5, 60);       // 5 attempts / 60 s
RateLimiter::check('otp:member:' . $memberId, 3, 900); // 3 OTP attempts / 15 min
RateLimiter::check('payment:member:' . $memberId, 10, 900); // 10 payments / 15 min
```

On limit breach, `RateLimiter::check()` returns false; the controller returns HTTP 429 with a user-friendly message.

### Password Policy

Enforced by `PasswordValidator::validate(string $password): array` (returns an array of error strings, empty = valid):
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 digit
- At least 1 special character (`!@#$%^&*()_+-=[]{}|;':,./<>?`)

Storage: `password_hash($password, PASSWORD_ARGON2ID)` with fallback to `PASSWORD_BCRYPT` if Argon2id is unavailable (detected via `defined('PASSWORD_ARGON2ID')`).

### Route Isolation Enforcement

The existing `$router->before()` callback in `index.php` is extended:

```php
$router->before(function (string $path, string $method) {
    // Member portal routes — require member session
    if (str_starts_with($path, 'member/') && !str_starts_with($path, 'member/login')
        && !str_starts_with($path, 'member/forgot')
        && !str_starts_with($path, 'member/reset')) {
        if (empty($_SESSION['member']['member_id'])) {
            header('Location: ' . url('member/login'));
            exit;
        }
    }

    // Webhook routes — no session needed (HMAC verified in controller)
    if (str_starts_with($path, 'webhooks/')) {
        return;
    }

    // Admin routes — require staff session; member session does NOT satisfy this
    if (!str_starts_with($path, 'member/') && !in_array($path, ['login', 'logout'], true)) {
        if (empty($_SESSION['user']['id'])) {
            header('Location: ' . url('login'));
            exit;
        }
    }
});
```

This is the sole choke-point. A member with `$_SESSION['member']` but no `$_SESSION['user']` will always be redirected away from any admin route.

### Inactivity Timeout

`MemberBaseController::__construct()` compares `time()` against `$_SESSION['member']['last_activity']`. If the gap exceeds 1800 s (30 minutes), the session is destroyed. Additionally, the member layout injects a small JS snippet that calls `GET /member/api/ping` every 4 minutes to keep the session alive while the tab is open. On ping, the server updates `last_activity`.

### Audit Logging

Every action that modifies money, loans, or sensitive profile fields writes to `audit_logs`:

```php
AuditLogger::log(
    saccoId: $this->saccoId(),
    userId: null,             // NULL for member actions
    memberId: $this->memberId(),
    action: 'savings_deposit',
    entity: 'journal_entries',
    entityId: $entryId,
    oldValues: [],
    newValues: ['amount' => $amount, 'type' => 'deposit'],
    ip: $_SERVER['REMOTE_ADDR'] ?? ''
);
```

`AuditLogger` is a thin static class that calls the existing `audit_logs` INSERT.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Ledger Balance Invariant

*For any* member and any sequence of deposits and withdrawals posted through the member portal, the member's savings balance as returned by `LedgerService::getMemberSavingsBalance()` SHALL equal the sum of all `journal_lines.credit` minus `journal_lines.debit` values for that member's `member_account_id`, regardless of how many transactions have been posted.

**Validates: Requirements 15.1, 15.2, 15.5**

### Property 2: Idempotency of Payment Postings

*For any* valid `idempotency_key`, posting the same payment callback to `PaymentService::handleCallback()` two or more times SHALL result in exactly one row in `journal_entries` referencing that key and exactly one `payment_transactions` row with `status = 'completed'`. Subsequent calls SHALL return without modifying any row.

**Validates: Requirements 5.3, 7.7, 15.4**

### Property 3: Lien Non-Exceedance Invariant

*For any* member, the sum of all `loan_liens.amount` rows with `status = 'active'` for that member SHALL never exceed the member's `savings_balance` as reflected in `member_savings_summary`. This invariant must hold immediately after every `LienService::placeLien()` call.

**Validates: Requirements 8.3, 8.4**

### Property 4: Member Data Isolation

*For any* authenticated Member_Session belonging to member A (identified by `member_id` and `sacco_id`), every database query executed in any member controller that returns data SHALL include both `member_id = A.member_id` and `sacco_id = A.sacco_id` as filter predicates. No query SHALL return rows belonging to a different `member_id` or a different `sacco_id`.

**Validates: Requirements 14.6, 17.1**

### Property 5: No Auto-Penalty Insertion

*For any* HTTP request to any route in the system (including cron jobs, webhooks, and AJAX endpoints), no code path triggered by the request SHALL insert a row into `loan_charges` with `charge_type = 'late_payment_fee'` unless the request is authenticated with a staff `$_SESSION['user']` session AND the route is one of the designated manual charge routes (`POST loans/add-charge`). Member-portal requests and webhook callbacks SHALL NEVER insert `loan_charges` rows.

**Validates: Requirements 7.6**

---

## Error Handling

### User-Facing Errors

All member controllers catch exceptions at the action level and use the existing flash message pattern:

```php
try {
    // ... business logic
} catch (\RuntimeException $e) {
    $_SESSION['member_flash']['error'] = $e->getMessage();
    header('Location: ' . url('member/withdrawals'));
    exit;
} catch (\Throwable $e) {
    error_log('[MemberPortal] ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    $_SESSION['member_flash']['error'] = 'An unexpected error occurred. Please try again.';
    header('Location: ' . url('member/dashboard'));
    exit;
}
```

`\RuntimeException` is used for anticipated business-rule failures (e.g. insufficient balance, expired OTP) and its message is safe to show to the user. `\Throwable` catches system errors; the raw message is never shown—only logged.

### Payment Failures

`PaymentService::initiateDeposit()` failure paths:
- Aggregator unreachable (cURL timeout) → `payment_transactions.status = 'failed'`, error shown to member, no ledger entry.
- Aggregator returns error → same as above.
- Callback with `status = 'failed'` from aggregator → `payment_transactions.status = 'failed'`, SMS notification to member.
- Duplicate callback → detected by `idempotency_key`, acknowledged with HTTP 200, no second posting.
- Callback for unknown key → logged to `storage/logs/webhook_*.log`, returns HTTP 400.

### DB Transaction Failures

All `LedgerService::post()` calls are wrapped in `DB::beginTransaction()` / `COMMIT` / `ROLLBACK`. On exception inside the transaction:

```php
$pdo->beginTransaction();
try {
    // ... multi-step inserts
    $pdo->commit();
} catch (\Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e; // re-throw for controller to handle
}
```

### SMS Failures

`SmsService::send()` failures are caught, logged to `sms_failures`, and never bubble up to kill the request. The financial transaction completes; the SMS is a notification, not a gating step.

---

## Testing Strategy

### Unit Tests

Target the pure PHP service layer with PHPUnit. No DB or HTTP calls in unit tests.

Key test classes:
- `LedgerServiceTest` — verify balanced entries accepted, unbalanced entries rejected, reversal produces mirror lines.
- `LienServiceTest` — verify lien placement rejected when free balance < amount; verify release adds amount back.
- `PaymentServiceTest` (with mock DB) — verify idempotent callbacks produce no second posting.
- `PasswordValidatorTest` — test all password policy edge cases.
- `SmsService::formatPhone` — test Uganda phone normalisation for various input formats.

### Property-Based Tests

Using [eris](https://github.com/giorgiosironi/eris) (PHP property-based testing library).

Each property test runs a minimum of **100 iterations** with randomly generated inputs.

**Feature: member-portal, Property 1: Ledger Balance Invariant** — Validates: Requirements 15.1, 15.5

```php
// Tag: Feature: member-portal, Property 1: Ledger balance invariant
// For any sequence of deposits and withdrawals, balance = SUM(credit) - SUM(debit)
$this->forAll(
    Generator\seq(Generator\choose(1, 5_000_000)), // random amounts
    Generator\elements(['deposit', 'withdrawal'])
)->then(function (array $amounts, string $type) {
    // post N transactions via LedgerService (in-memory mock DB)
    // assert getMemberSavingsBalance() equals running sum
});
```

**Feature: member-portal, Property 2: Idempotency** — Validates: Requirements 5.3, 15.4

```php
// Tag: Feature: member-portal, Property 2: Idempotency of payment postings
// Posting the same idempotency_key N times yields exactly 1 journal_entry
$this->forAll(Generator\string(), Generator\choose(2, 10))
->then(function (string $key, int $times) {
    for ($i = 0; $i < $times; $i++) {
        $service->handleCallback(['idempotency_key' => $key, 'status' => 'success']);
    }
    $this->assertSame(1, $this->countJournalEntries($key));
});
```

**Feature: member-portal, Property 3: Lien Non-Exceedance** — Validates: Requirements 8.3, 8.4

```php
// Tag: Feature: member-portal, Property 3: Lien non-exceedance invariant
// After placing any number of liens, sum(active liens) <= savings_balance
$this->forAll(Generator\choose(100_000, 10_000_000)) // savings balance
->then(function (int $balance) {
    // set member savings to $balance
    // attempt N random lien placements, some should succeed, some should fail
    // assert sum(accepted liens) <= balance at all times
});
```

**Feature: member-portal, Property 4: Data Isolation** — Validates: Requirements 14.6, 17.1

```php
// Tag: Feature: member-portal, Property 4: Member data isolation
// For any two distinct members A and B, A's session never returns B's data
$this->forAll(
    Generator\choose(1, 1000), // member A id
    Generator\choose(1, 1000)  // member B id
)->suchThat(fn($a, $b) => $a !== $b)
->then(function (int $memberA, int $memberB) {
    $rows = $this->fetchMemberData($memberA, saccoId: 1);
    foreach ($rows as $row) {
        $this->assertSame($memberA, (int)$row['member_id']);
    }
});
```

### Integration Tests

Thin, example-based tests with a real test database:
- Login flow end-to-end: correct credentials + correct OTP → session created.
- Login lockout: 5 wrong passwords → status locked.
- Deposit callback: POST to `/webhooks/mobile-money` with valid HMAC → ledger row created, balance updated.
- Duplicate callback: POST same callback twice → second call is no-op.
- Guarantor acceptance with insufficient balance → rejected with correct message.

### Manual / Acceptance Tests

- Render all member pages on a 320 px viewport and a 1920 px viewport.
- Verify no admin route is reachable from a member session (return 302 to login or 403).
- Verify no member route is reachable from a staff session.
- Generate and download a statement PDF for a member with 50+ transactions.
- Verify that changing phone number sends OTP to the new number and alert SMS to the old number.

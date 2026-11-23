# Design Document: Savings Withdrawal

## Overview

The Savings Withdrawal feature adds a staff-facing withdrawal operation to the SACCOPLUS PHP admin system. A teller navigates to `/savings/withdraw`, searches for a member, picks the savings type (Voluntary or Compulsory), enters an amount and payment method, and submits. The system atomically posts a double-entry journal entry, decrements the `member_savings_summary` cached balance, inserts a `savings_transactions` row, and writes an `audit_logs` row — all inside a single PDO transaction.

The feature extends the existing `SavingsController` and creates a new `SavingsService` class. It follows exactly the same MVC-lite patterns already used by `MembersController`, `LoansController`, and the existing `SavingsController::deposit()` / `approve()` methods. No new frameworks, no Firestore, no Flutter, no MarzPay, no OTP.

---

## Architecture

```
Browser
  │
  ├─ GET  /savings/withdraw        → SavingsController::withdraw()   → View: savings/withdraw.php
  ├─ POST /savings/withdraw        → SavingsController::processWithdrawal()
  │                                       └─ SavingsService::processWithdrawal()
  │                                             ├─ DB transaction (PDO)
  │                                             │    ├─ SELECT member_savings_summary FOR UPDATE
  │                                             │    ├─ UPDATE member_savings_summary
  │                                             │    ├─ INSERT savings_transactions
  │                                             │    ├─ INSERT journal_entries
  │                                             │    ├─ INSERT journal_lines (2 rows)
  │                                             │    └─ COMMIT
  │                                             └─ INSERT audit_logs (outside transaction)
  │
  └─ GET  /api/savings/member-balance → SavingsController::getMemberBalance()  → JSON
```

The view uses vanilla JS `fetch` for the member search (reusing the existing `GET /api/members/search` endpoint already wired in `index.php`) and for loading the member's savings balances from the new `GET /api/savings/member-balance` endpoint.

---

## Components and Interfaces

### Route Table Additions

Three new routes are appended to `public/index.php` in the "Savings & Shares" section:

```php
$router->get('savings/withdraw',           [SavingsController::class, 'withdraw']);
$router->post('savings/withdraw',          [SavingsController::class, 'processWithdrawal']);
$router->get('api/savings/member-balance', [SavingsController::class, 'getMemberBalance']);
```

No other routes need changes.

---

### SavingsController — New Methods

**`withdraw(GET)`**

Checks session (authenticated + role ≥ teller). Reads optional `?member_id=` query param for deep-linking from Member 360. If present, pre-loads the member's savings summary from `member_savings_summary` and passes it to the view. Renders `savings/withdraw`.

```php
public function withdraw(): void
{
    Auth::require();
    $this->requireRole(['admin', 'sacco_admin', 'branch_manager', 'teller']);

    $memberId = isset($_GET['member_id']) ? (int)$_GET['member_id'] : null;
    $member   = null;
    $savings  = null;

    if ($memberId) {
        $saccoId = (int)($_SESSION['user']['sacco_id'] ?? 1);
        $member  = $this->fetchMember($memberId, $saccoId);
        $savings = $member ? $this->fetchSavings($memberId) : null;
    }

    // Re-populate form after redirect-back-on-error
    $old = $_SESSION['_old_withdrawal'] ?? [];
    unset($_SESSION['_old_withdrawal']);

    View::render('savings/withdraw', [
        'title'       => 'Savings Withdrawal',
        'pageTitle'   => 'Savings Withdrawal',
        'activeRoute' => 'savings',
        'member'      => $member,
        'savings'     => $savings,
        'old'         => $old,
    ]);
}
```

**`processWithdrawal(POST)`**

Validates CSRF, validates role, sanitises input, delegates to `SavingsService::processWithdrawal()`, then sets flash message and redirects.

```php
public function processWithdrawal(): void
{
    Auth::require();
    $this->requireRole(['admin', 'sacco_admin', 'branch_manager', 'teller']);

    // CSRF
    if (($_POST['_csrf'] ?? '') !== ($_SESSION['_csrf'] ?? '')) {
        $_SESSION['_flash']['error'] = 'Invalid request (CSRF).';
        header('Location: ' . url('savings/withdraw'));
        exit;
    }

    $memberId     = (int)($_POST['member_id']     ?? 0);
    $savingsType  = $_POST['savings_type']         ?? '';
    $amount       = (int)($_POST['amount']         ?? 0);
    $paymentMethod = $_POST['payment_method']      ?? '';
    $reference    = trim($_POST['reference']       ?? '');
    $saccoId      = (int)($_SESSION['user']['sacco_id'] ?? 1);
    $userId       = (int)($_SESSION['user']['id']       ?? 0);
    $branchId     = (int)($_SESSION['user']['branch_id'] ?? 1);
    $ip           = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';

    // Controller-level validation (UI duplicate of service guard)
    $allowedTypes   = ['Voluntary', 'Compulsory'];
    $allowedMethods = ['Cash', 'Bank Transfer', 'Mobile Money'];
    $errors = [];

    if (!$memberId)                              $errors[] = 'Member is required.';
    if (!in_array($savingsType, $allowedTypes))  $errors[] = 'Invalid savings type.';
    if ($amount < 1000)                          $errors[] = 'Minimum withdrawal is UGX 1,000.';
    if (!in_array($paymentMethod, $allowedMethods)) $errors[] = 'Invalid payment method.';

    if ($errors) {
        $_SESSION['_flash']['error']      = implode(' ', $errors);
        $_SESSION['_old_withdrawal']      = $_POST;
        header('Location: ' . url('savings/withdraw'));
        exit;
    }

    try {
        $service = new \App\Services\SavingsService();
        $result  = $service->processWithdrawal(
            memberId:      $memberId,
            saccoId:       $saccoId,
            branchId:      $branchId,
            userId:        $userId,
            savingsType:   $savingsType,
            amount:        $amount,
            paymentMethod: $paymentMethod,
            reference:     $reference ?: null,
            ip:            $ip
        );

        $_SESSION['_flash']['success'] = sprintf(
            'UGX %s withdrawn from %s savings for %s. New balance: UGX %s.',
            number_format($amount),
            htmlspecialchars($savingsType),
            htmlspecialchars($result['member_name']),
            number_format($result['new_balance'])
        );
        header('Location: ' . url('savings/withdraw'));
        exit;

    } catch (\App\Services\SavingsInsufficientBalanceException $e) {
        $_SESSION['_flash']['error']  = 'Insufficient balance: ' . $e->getMessage();
        $_SESSION['_old_withdrawal']  = $_POST;
        header('Location: ' . url('savings/withdraw'));
        exit;
    } catch (\Exception $e) {
        error_log('Savings withdrawal error: ' . $e->getMessage());
        $_SESSION['_flash']['error']  = 'Withdrawal failed: ' . $e->getMessage();
        $_SESSION['_old_withdrawal']  = $_POST;
        header('Location: ' . url('savings/withdraw'));
        exit;
    }
}
```

**`getMemberBalance(GET)`** — JSON endpoint

Returns the member's savings breakdown from `member_savings_summary`. Enforces sacco_id match to prevent cross-tenant reads.

```php
public function getMemberBalance(): void
{
    header('Content-Type: application/json');
    Auth::require();

    $memberId = (int)($_GET['member_id'] ?? 0);
    $saccoId  = (int)($_SESSION['user']['sacco_id'] ?? 1);

    if (!$memberId) {
        echo json_encode(['success' => false, 'message' => 'member_id required']);
        exit;
    }

    $member = $this->fetchMember($memberId, $saccoId);
    if (!$member) {
        echo json_encode(['success' => false, 'message' => 'Member not found']);
        exit;
    }

    $savings = $this->fetchSavings($memberId);

    echo json_encode([
        'success'             => true,
        'member_id'           => $memberId,
        'name'                => $member['full_name'],
        'account_number'      => $member['account_number'],
        'voluntary_balance'   => (int)($savings['voluntary_balance']   ?? 0),
        'compulsory_balance'  => (int)($savings['compulsory_balance']  ?? 0),
        'total_balance'       => (int)($savings['total_balance']       ?? 0),
    ]);
    exit;
}
```

**Private helpers on SavingsController:**

```php
private function requireRole(array $allowed): void
{
    $role = $_SESSION['user']['role'] ?? '';
    if (!in_array($role, $allowed, true)) {
        http_response_code(403);
        $_SESSION['_flash']['error'] = 'You do not have permission to perform this action.';
        header('Location: ' . url('savings'));
        exit;
    }
}

private function fetchMember(int $memberId, int $saccoId): ?array
{
    $rows = DB::query(
        "SELECT id, sacco_id, member_no, account_number,
                COALESCE(NULLIF(TRIM(full_name),''), name, 'Unknown') AS full_name,
                phone, savings_balance
         FROM members WHERE id = ? AND sacco_id = ?",
        [$memberId, $saccoId]
    );
    return $rows[0] ?? null;
}

private function fetchSavings(int $memberId): ?array
{
    $rows = DB::query(
        "SELECT voluntary_balance, compulsory_balance,
                share_capital_balance, total_balance
         FROM member_savings_summary WHERE member_id = ?",
        [$memberId]
    );
    return $rows[0] ?? null;
}
```

---

### SavingsService — `processWithdrawal`

New file: `/app/Services/SavingsService.php`

This is the single authoritative location for all withdrawal business logic.

```php
<?php
declare(strict_types=1);
namespace App\Services;

use App\Core\DB;

/** Thrown when the requested amount exceeds the available balance. */
class SavingsInsufficientBalanceException extends \RuntimeException {}

class SavingsService
{
    /**
     * Execute a savings withdrawal atomically.
     *
     * Caller must validate:
     *   - $amount >= 1000
     *   - $savingsType in ['Voluntary','Compulsory']
     *   - $paymentMethod in ['Cash','Bank Transfer','Mobile Money']
     *   - sacco_id match between member and logged-in user
     *
     * @return array{new_balance:int, member_name:string, txn_id:int}
     * @throws SavingsInsufficientBalanceException
     * @throws \RuntimeException on any DB failure
     */
    public function processWithdrawal(
        int    $memberId,
        int    $saccoId,
        int    $branchId,
        int    $userId,
        string $savingsType,
        int    $amount,
        string $paymentMethod,
        ?string $reference,
        string $ip
    ): array {
        $db = DB::pdo();

        // ── 1. Resolve GL account IDs ────────────────────────────────────
        [$savingsGlId, $offsetGlId] = $this->resolveGlAccounts(
            $db, $saccoId, $savingsType, $paymentMethod
        );

        $db->beginTransaction();
        try {
            // ── 2. Lock the savings summary row ─────────────────────────
            $stmt = $db->prepare(
                "SELECT id, voluntary_balance, compulsory_balance, total_balance,
                        (SELECT COALESCE(NULLIF(TRIM(full_name),''),name,'?')
                         FROM members WHERE id = m.member_id LIMIT 1) AS member_name
                 FROM member_savings_summary m
                 WHERE member_id = ?
                 FOR UPDATE"
            );
            $stmt->execute([$memberId]);
            $summary = $stmt->fetch(\PDO::FETCH_ASSOC);

            if (!$summary) {
                throw new \RuntimeException('No savings record found for this member.');
            }

            $balField  = $savingsType === 'Voluntary' ? 'voluntary_balance' : 'compulsory_balance';
            $available = (int)$summary[$balField];

            if ($amount > $available) {
                throw new SavingsInsufficientBalanceException(
                    "Requested UGX " . number_format($amount)
                    . ", available UGX " . number_format($available)
                    . " ({$savingsType})."
                );
            }

            // ── 3. Decrement the cached balance ──────────────────────────
            $upStmt = $db->prepare(
                "UPDATE member_savings_summary
                 SET {$balField} = {$balField} - ?,
                     last_transaction_at = NOW()
                 WHERE member_id = ?"
            );
            $upStmt->execute([$amount, $memberId]);

            // ── 4. Insert savings_transactions row ───────────────────────
            $txnRef = 'WD-' . strtoupper(bin2hex(random_bytes(5)));
            $stStmt = $db->prepare(
                "INSERT INTO savings_transactions
                   (sacco_id, member_id, amount, savings_type, transaction_type,
                    status, auto_approved, payment_method, reference_number,
                    description, recorded_by, created_at)
                 VALUES (?, ?, ?, ?, 'withdrawal', 'Approved', 1, ?, ?, ?, ?, NOW())"
            );
            $stStmt->execute([
                $saccoId, $memberId, $amount, $savingsType,
                $paymentMethod,
                $reference,
                "Savings withdrawal via {$paymentMethod}",
                $userId,
            ]);
            $txnId = (int)$db->lastInsertId();

            // ── 5. Insert journal_entries row ────────────────────────────
            $jeStmt = $db->prepare(
                "INSERT INTO journal_entries
                   (sacco_id, branch_id, txn_ref, txn_type, description,
                    value_date, posted_by, created_at)
                 VALUES (?, ?, ?, 'savings_withdrawal', ?, CURDATE(), ?, NOW())"
            );
            $jeStmt->execute([
                $saccoId, $branchId, $txnRef,
                "Savings withdrawal — {$savingsType} — {$paymentMethod}",
                $userId,
            ]);
            $jeId = (int)$db->lastInsertId();

            // ── 6. Insert two balanced journal_lines ─────────────────────
            //   DR  GL_Savings_Liability  (reduces liability → normal debit on a liability)
            //   CR  GL_Cash / GL_Bank     (reduces asset      → normal credit on an asset)
            $jlStmt = $db->prepare(
                "INSERT INTO journal_lines
                   (sacco_id, entry_id, gl_account_id, debit, credit)
                 VALUES (?, ?, ?, ?, 0),
                        (?, ?, ?, 0, ?)"
            );
            $jlStmt->execute([
                $saccoId, $jeId, $savingsGlId, $amount,   // DR savings liability
                $saccoId, $jeId, $offsetGlId,  $amount,   // CR cash/bank asset
            ]);

            // ── 7. Fetch new balance to return ───────────────────────────
            $newBalRow = $db->prepare(
                "SELECT {$balField} FROM member_savings_summary WHERE member_id = ?"
            );
            $newBalRow->execute([$memberId]);
            $newBalance = (int)($newBalRow->fetchColumn() ?? 0);

            $db->commit();

        } catch (\Exception $e) {
            if ($db->inTransaction()) $db->rollBack();
            throw $e;
        }

        // ── 8. Write audit log (outside transaction — non-fatal on failure) ──
        try {
            $db->prepare(
                "INSERT INTO audit_logs
                   (sacco_id, user_id, action, entity, entity_id,
                    old_values, new_values, ip, created_at)
                 VALUES (?, ?, 'savings_withdrawal', 'savings_transactions', ?,
                         ?, ?, ?, NOW())"
            )->execute([
                $saccoId,
                $userId,
                $txnId,
                json_encode([
                    'balance_before'   => $available,
                    'savings_type'     => $savingsType,
                ]),
                json_encode([
                    'balance_after'    => $newBalance,
                    'amount_withdrawn' => $amount,
                    'payment_method'   => $paymentMethod,
                    'txn_ref'          => $txnRef,
                    'journal_entry_id' => $jeId,
                ]),
                $ip,
            ]);
        } catch (\Exception $auditEx) {
            error_log('Audit log write failed (non-fatal): ' . $auditEx->getMessage());
        }

        return [
            'new_balance'  => $newBalance,
            'member_name'  => $summary['member_name'],
            'txn_id'       => $txnId,
        ];
    }

    // ────────────────────────────────────────────────────────────────────────
    // GL Account Resolution
    // ────────────────────────────────────────────────────────────────────────

    /**
     * Returns [savings_liability_gl_id, cash_or_bank_gl_id].
     *
     * Convention in this SACCO's chart of accounts (from FinanceController):
     *   - Savings liability: type='liability', code LIKE '3%' (member savings)
     *     Fallback: first active liability account if code pattern not found.
     *   - Cash on Hand: code '1101'
     *   - Bank account: code '1102'
     *   - Mobile Money: code '1104'
     *
     * @throws \RuntimeException if required GL accounts are missing
     */
    private function resolveGlAccounts(
        \PDO   $db,
        int    $saccoId,
        string $savingsType,
        string $paymentMethod
    ): array {
        // 8a. Savings liability GL (DR side)
        //     Try code='3001' (common savings-liability code); fall back to
        //     any active liability account.
        $liabilityRow = $db->prepare(
            "SELECT id FROM gl_accounts
             WHERE sacco_id = ? AND type = 'liability' AND status = 'active'
             ORDER BY CASE WHEN code = '3001' THEN 0
                          WHEN code LIKE '30%' THEN 1
                          ELSE 2 END, code ASC
             LIMIT 1"
        );
        $liabilityRow->execute([$saccoId]);
        $liabilityId = $liabilityRow->fetchColumn();

        if (!$liabilityId) {
            throw new \RuntimeException(
                'GL savings liability account not found. '
                . 'Please ensure a liability GL account exists in the chart of accounts.'
            );
        }

        // 8b. Offset (cash/bank) GL (CR side)
        $offsetCode = match($paymentMethod) {
            'Bank Transfer' => '1102',
            'Mobile Money'  => '1104',
            default         => '1101',   // Cash
        };

        $offsetRow = $db->prepare(
            "SELECT id FROM gl_accounts
             WHERE sacco_id = ? AND code = ? AND status = 'active'
             LIMIT 1"
        );
        $offsetRow->execute([$saccoId, $offsetCode]);
        $offsetId = $offsetRow->fetchColumn();

        if (!$offsetId) {
            // Fall back to any active asset account
            $fallback = $db->prepare(
                "SELECT id FROM gl_accounts
                 WHERE sacco_id = ? AND type = 'asset' AND status = 'active'
                 ORDER BY code ASC LIMIT 1"
            );
            $fallback->execute([$saccoId]);
            $offsetId = $fallback->fetchColumn();
        }

        if (!$offsetId) {
            throw new \RuntimeException(
                "GL asset account for payment method '{$paymentMethod}' not found. "
                . "Please check the chart of accounts."
            );
        }

        return [(int)$liabilityId, (int)$offsetId];
    }
}
```

---

## Data Models

### Tables Used (all pre-existing in `schema.sql`)

| Table | Operation | Notes |
|---|---|---|
| `members` | SELECT | Read `full_name`, `account_number`, `sacco_id` |
| `member_savings_summary` | SELECT FOR UPDATE, UPDATE | Lock + decrement `voluntary_balance` or `compulsory_balance` |
| `savings_transactions` | INSERT | `transaction_type='withdrawal'`, `status='Approved'`, `auto_approved=1` |
| `journal_entries` | INSERT | `txn_type='savings_withdrawal'` |
| `journal_lines` | INSERT ×2 | DR savings liability, CR cash/bank; both must sum to zero |
| `gl_accounts` | SELECT | Resolve liability GL and cash/bank GL by `code` and `type` |
| `audit_logs` | INSERT | Written outside main transaction; failure is non-fatal |

### GL Posting Summary

```
DR  GL_Savings_Liability  (type=liability, code≈3001)   +amount
CR  GL_Cash_or_Bank       (type=asset,     code 1101/1102/1104)   +amount
Net: 0 ✓
```

The double-entry convention: debiting a liability *reduces* it (the SACCO owes less to the member). Crediting an asset *reduces* it (the SACCO pays out cash).

### `txn_ref` Format

`WD-` + 10 random uppercase hex characters, e.g. `WD-A3F91C2B04`. Globally unique per `(sacco_id, txn_ref)` unique key on `journal_entries`.

---

## View Layout — `savings/withdraw.php`

The view follows the same card/section structure as `savings/summary.php`. Key sections:

```
┌─────────────────────────────────────────────────────────────┐
│  Header: "Savings Withdrawal"       [Back to Savings]        │
├─────────────────────────────────────────────────────────────┤
│  SECTION 1: Member Search                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  🔍 [Search by name, phone, or member number...     ] │   │
│  │  ──────────────────────────────────────────────────  │   │
│  │  (results dropdown: Member # | Name | Balance)        │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  SECTION 2: Member Info Card (shown after selection)        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  👤 ALICE NAKATO                   Member #9220000002 │   │
│  │  Phone: 0701234567   Account: 922020000002            │   │
│  │  ─────────────────────────────────────────────────── │   │
│  │  Voluntary: UGX 450,000   Compulsory: UGX 120,000    │   │
│  │  Total Savings: UGX 570,000                           │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  SECTION 3: Withdrawal Form                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Savings Type  [Voluntary ▼]                          │   │
│  │  Available:    UGX 450,000   (updates on change)      │   │
│  │                                                        │   │
│  │  Amount        [________________]  UGX                 │   │
│  │                Inline error: amount > available        │   │
│  │                Inline error: amount < 1,000            │   │
│  │                                                        │   │
│  │  Payment Method  [Cash ▼]                             │   │
│  │  Reference / Notes  [________________] (optional)     │   │
│  │                                                        │   │
│  │  [Cancel]              [Process Withdrawal →]         │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**JS behaviour (vanilla, no build step):**

1. `DOMContentLoaded` — if `memberId` was pre-loaded (query param), skip search section and show member card immediately.
2. Search input: debounced `fetch('/api/members/search?q=…')` (existing endpoint) on `input` event, renders a results list below the input.
3. On member select: `fetch('/api/savings/member-balance?member_id=…')` → populate member card and set hidden `member_id` input; if `total_balance === 0` show "No savings" message and disable the form.
4. Savings type `change` event: swap displayed available balance between `voluntary_balance` and `compulsory_balance` from the JS-cached response.
5. Amount `input` event: real-time inline validation (< 1000 or > available).
6. Form `submit` event: prevent default if inline errors are visible, otherwise allow normal HTML form POST.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Journal lines always balance

*For any* successfully committed savings withdrawal of amount A, the sum of all `journal_lines.debit` values for the created `journal_entries` row must equal the sum of all `journal_lines.credit` values, and both must equal A.

**Validates: Requirements 3.1, 3.2**

---

### Property 2: Balance decremented equals amount withdrawn

*For any* member with savings balance B and a withdrawal of amount A (where A ≤ B and A ≥ 1000), after `SavingsService::processWithdrawal` commits, the balance in `member_savings_summary` for the selected savings type must equal B − A.

**Validates: Requirements 3.2, 3.5**

---

### Property 3: Insufficient balance always rejected

*For any* withdrawal request where the requested amount A exceeds the available balance B for the selected savings type (A > B), `SavingsService::processWithdrawal` must throw `SavingsInsufficientBalanceException` and the `member_savings_summary` balance must remain unchanged.

**Validates: Requirements 2.6, 3.3**

---

### Property 4: Minimum amount always enforced

*For any* amount in the range [1, 999], the controller's input validation must reject the request with a validation error, and no database write must occur.

**Validates: Requirements 2.7**

---

### Property 5: Audit log always written for committed withdrawal

*For any* successfully committed withdrawal that produced a `savings_transactions` row with id T, there must exist exactly one row in `audit_logs` with `entity = 'savings_transactions'` and `entity_id = T` and `action = 'savings_withdrawal'` containing correct `old_values` and `new_values`.

**Validates: Requirements 4.1, 4.3**

---

### Property 6: Cross-tenant access always blocked

*For any* combination of (member.sacco_id, user.sacco_id) where they differ, the `getMemberBalance` API endpoint must return `success: false` and `processWithdrawal` must abort before any database write.

**Validates: Requirements 6.3**

---

## Error Handling

| Failure scenario | Handling |
|---|---|
| CSRF token missing/mismatched | Redirect to form with error flash; no DB write |
| Role unauthorised (GET) | 403 HTTP response; redirect to `/savings` |
| Role unauthorised (POST) | 403 HTTP response; redirect to `/savings` |
| Member not found / wrong sacco | Error flash + redirect; no DB write |
| No savings summary row | Exception caught in service; rolled back; error flash |
| Insufficient balance | `SavingsInsufficientBalanceException`; rolled back; error flash with amounts |
| Amount < 1000 | Controller validation; redirect + error flash; no DB write |
| GL accounts missing | `RuntimeException` from `resolveGlAccounts`; rolled back; error flash asking admin to check chart of accounts |
| Any DB write failure mid-transaction | PDO exception → `rollBack()` → error flash |
| `journal_lines` balance constraint fails | PDO constraint violation → rollback → error flash |
| Audit log INSERT fails | Logged to PHP error log; NOT rolled back; non-fatal warning in response |

---

## Testing Strategy

This feature is primarily server-rendered PHP with a thin vanilla JS layer. The core business logic lives in `SavingsService::processWithdrawal` as a set of pure database operations.

**Unit tests** (PHPUnit, targeting `SavingsService` with a test database or PDO mock):

- Verify `processWithdrawal` decrements the correct balance field (`voluntary_balance` vs `compulsory_balance`) based on `$savingsType`.
- Verify `processWithdrawal` throws `SavingsInsufficientBalanceException` when `amount > available`.
- Verify the returned `new_balance` matches `old_balance − amount` for the selected type.
- Verify two `journal_lines` rows are created with matching debit/credit amounts.
- Verify `journal_entries.txn_type = 'savings_withdrawal'`.
- Verify an audit log row exists after a successful withdrawal.
- Verify a failed audit log insert does not roll back the withdrawal (mock the audit INSERT to throw, assert the savings row exists).

**Property-based tests** (PHPUnit with `eris/eris` or manual generators):

- **Property 1 (Journal balance):** Generate random valid `(member, amount, savingsType, paymentMethod)` tuples. For each, run `processWithdrawal` and assert `SUM(debit) == SUM(credit) == amount` on the created journal entry.
- **Property 2 (Balance invariant):** Generate random members with random balances and random amounts ≤ balance. Assert `new_balance == old_balance − amount` after each withdrawal.
- **Property 3 (Insufficient balance rejection):** Generate random `(balance, amount)` pairs where `amount > balance`. Assert `SavingsInsufficientBalanceException` is always thrown and no balance change occurs.
- **Property 4 (Minimum amount):** Generate amounts in [1, 999]. Assert controller validation always rejects these.
- **Property 5 (Audit log always written):** For any successful withdrawal, assert a matching `audit_logs` row exists with the correct `entity_id`.
- **Property 6 (Cross-tenant block):** Generate random `(member.sacco_id, user.sacco_id)` pairs where they differ. Assert the API and service always reject them.

Each property test must run a minimum of 100 iterations. Tag format: `// Feature: savings-withdrawal, Property N: <title>`

**Integration tests** (manual/browser or a PHP HTTP test client):

- GET `/savings/withdraw` without session → redirect to `/login`.
- GET `/savings/withdraw` with `viewer` role → 403.
- GET `/savings/withdraw` with `teller` role → 200.
- POST with mismatched CSRF → redirect + error flash.
- POST a valid withdrawal → success flash, balance updated in DB, journal entry created.
- GET `/api/savings/member-balance?member_id=X` with mismatched sacco → `success: false`.

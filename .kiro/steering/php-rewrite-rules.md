# skills.md — SACCOPLUS PHP rewrite (steering file for Kiro)

## 0. Mission
Rebuild the SACCO admin system (currently Flutter + Firestore) as a **core PHP 8.x + MySQL + HTML/CSS/vanilla JS** web app.

**HARD RULE: The existing Flutter app and Firestore stay live and untouched.** The PHP version is a separate, parallel system until Moses decides to cut over.
- Never write to Firestore. Never change Firestore rules, collections, or Flutter code.
- PHP app has its own MySQL database and its own subdomain (e.g. `v2.<domain>`).
- Data comes in through a **repeatable, read-only Firestore -> MySQL import** (idempotent, safe to re-run).

## 1. Stack rules
- PHP 8.1+, **no Laravel / no heavy framework**. Plain PHP, small hand-written MVC-lite.
- PDO with prepared statements only. Never concatenate SQL.
- MySQL 8 / MariaDB 10.6+, InnoDB, utf8mb4.
- Frontend: server-rendered PHP templates, HTML5, one CSS file (clean white cards, label/value rows), vanilla JS (fetch for AJAX). No build step. Charts: Chart.js via CDN is fine.
- PDFs: Dompdf or TCPDF via Composer (only Composer dependency allowed besides PHPMailer).
- Must run on ordinary shared/VPS hosting (Apache + mod_rewrite or Nginx).

## 2. Folder structure
```
/public            index.php (front controller), assets/, .htaccess
/app
  /Core            Router, DB, Auth, Csrf, View, Validator, Logger
  /Controllers
  /Models          thin classes: queries only
  /Services        business logic (LoanService, LedgerService, StatementService)
  /Views           templates + /partials
/config            config.php (reads .env), never committed secrets
/database          schema.sql, migrations/, seeds/
/scripts           import_firestore.php, recalc_balances.php
/storage           logs/, exports/, uploads/ (outside web root if possible)
```

## 2b. Clean URLs (non-negotiable)
- **No file extensions in any URL, ever.** `/index`, `/login`, `/members`, `/loans/view`, never `index.php`.
- One front controller (`public/index.php`) + `.htaccess` rewrite. Typing `*.php` 301-redirects to the clean URL.
- Build every link with `url('login')`. Never hard-code `login.php` in links, forms, redirects or JS.
- `/` and `/index` are the same page. Start every build from the index page, then login, then dashboard.
- A starter skeleton (`saccoplus-php.zip`) already exists with the router, views, CSRF, auth and layout. Extend it. Do NOT restart it.

## 3. Security (non-negotiable)
- `password_hash` / `password_verify` (Argon2id or bcrypt). Session regenerate on login, secure + httponly + samesite cookies.
- CSRF token on every POST. Escape all output with `htmlspecialchars`.
- Role-based access: `admin`, `manager`, `teller`, `accountant`, `viewer` (adjust to match what Firestore has). Every controller action checks permission.
- **Audit log** table: who, what, entity, old/new values, IP, timestamp. Every money or loan-data change writes to it.
- File uploads: whitelist mime/extension, random filenames, stored outside web root.

## 4. Money & accounting rules
- Currency UGX. Store as `BIGINT` (whole shillings) unless the Firestore data proves decimals are used; then `DECIMAL(15,2)`. Never FLOAT/DOUBLE.
- **Savings and wallet are the SAME thing.** One savings balance per member. No separate wallet table or balance.
- Every money movement is a row in a **ledger/transactions table** (append-only). Balances are derived or cached and must be re-computable via `scripts/recalc_balances.php`.
- Every posting runs inside a DB transaction (`BEGIN ... COMMIT`), with row locks (`SELECT ... FOR UPDATE`) on the account being changed.
- Reversals are new rows that reference the original, never deletes/updates of posted rows.

## 5. Loan rules
- Loan account details page has tabs: **Summary / Schedule / Loan Card**.
- **Late repayment charges are MANUAL ONLY.** Staff add them with a reason. Never auto-apply penalties via cron or on page load.
- **Migrated loans**: balances were imported from the old system but repayment history was NOT. Add `is_migrated` flag and `opening_balance`, `opening_date` on loans. Arrears calc for migrated loans must start from the opening balance/date, not assume a full schedule of past payments. (This is why arrears looked wrong in Oct 2026.)
- Provide a **Correct Loan Data** admin screen (admin only, fully audit logged) for fixing migrated loan figures.
- Loan status and arrears must be computed in ONE place (`LoanService`) and reused everywhere (details page, reports, statements). No duplicate formulas in views.

## 6. Screens to rebuild (priority order)
1. Login, roles, dashboard
2. Members list + **Member 360** (clean white cards, label/value rows, same look as loan details)
3. Teller operations (member search, deposit/withdraw, bank transfer, transaction history, daily summary)
4. Loans (apply, approve, disburse, repay, details, correct data)
5. **Member account statement PDF** (as clean as a DFCU bank statement: header with SACCO details, opening balance, dated rows, debit/credit/running balance, closing balance, page numbers)
6. Financial reports: Monthly, Income, Expense, Trial Balance, Balance Sheet, KYC, Loans, Members (export to PDF + CSV)
7. Settings, users, audit log viewer

## 7. Firestore -> MySQL import (`scripts/import_firestore.php`)
- Input: JSON exports produced by `dump_firestore_schema.js` / a full export script, NOT live writes to Firestore.
- Store the Firestore document id in a `legacy_id` column (UNIQUE) on every imported table. Import = `INSERT ... ON DUPLICATE KEY UPDATE` so it can run many times.
- Convert Firestore timestamps to MySQL `DATETIME` in `Africa/Kampala`.
- Log counts per collection (source docs vs rows imported) and list skipped/bad docs in `storage/logs/import_*.log`.
- Schema design must follow the real structure in `schema_report.md`. Do not invent tables the data doesn't support. Ask Moses when two collections look like duplicates.

## 8. Working style (how to behave)
- Moses wants **complete working deliverables fast**, not long back-and-forth. State assumptions in one line and build.
- Build in vertical slices: schema -> import -> screen working end to end -> next screen.
- Keep code readable, commented where money logic is involved. No over-engineering.
- After each slice, give: files changed, how to run it, what to test.
- Pricing/product context: MBADIFA SACCO has 416 members; the system is sold to other SACCOs, so keep it **multi-SACCO ready** (a `sacco_id` on tenant data) even if only one tenant exists today.

## 9. Out of scope for now
- USSD (only after 5+ SACCOs are on the system).
- Any change to the Flutter app.

## 10. Cutover (later, only when Moses says so)
Freeze Flutter writes -> final import -> reconcile totals (members, savings sum, loan outstanding sum, GL trial balance) against Firestore -> switch users -> keep Firestore read-only as backup.

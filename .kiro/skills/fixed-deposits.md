# Skill: Fixed Deposits Module (SACCO System)  
  
## Goal  
Add a **Fixed Deposits (FD)** module to the existing SACCO admin app (PHP + MySQL). An FD is money moved from a member's **savings** into a **locked, interest-earning account** for a set term. At maturity, principal + interest goes back to savings (or rolls over).  
  
## Before you write any code  
1. Inspect the existing project and **follow its conventions**: folder structure, controller patterns, database table names, naming, how transactions/ledger entries are written, how the loan module and permissions are done.  
2. Find how **savings/wallet** is stored. In this SACCO, **savings and wallet are the same thing** (no separate wallet balance). Reuse that balance field. Do NOT create a second balance.  
3. Find the existing **transactions/ledger** tables and reuse them for all FD money movements.  
4. Reuse the UI style of the **loan account details page** (clean white cards, label/value rows, tabs).  
5. Summarize what you found in a short plan before generating code.  
  
## Core rules (do not break)  
- FD is a **separate account type**, not a flag on savings.  
- Opening an FD moves money: **debit savings, create FD**, in ONE atomic database transaction. Never leave one half done.  
- **Rate, term, dates and expected interest are snapshotted at opening.** Changing a product's rate later must NOT affect existing FDs.  
- **Never delete FDs.** Only change `status`.  
- **Interest and maturity are staff-triggered (manual), not automatic.** No background job posts money. Staff press "Process Maturity" and review before confirming. (Same philosophy as late repayment charges: manual only.)  
- Every money movement writes a ledger entry so it appears on the member statement PDF.  
- All amounts are UGX, stored as DECIMAL(18,2) or BIGINT (integers for whole shillings).  
- Every write records `created_by` / `processed_by` (staff user_id) and a timestamp.  
  
## Data model  
  
### `fd_products` (admin config)  
```sql
CREATE TABLE fd_products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL DEFAULT 1,
  name VARCHAR(150) NOT NULL,
  term_months INT UNSIGNED NOT NULL,
  annual_rate_percent DECIMAL(5,2) NOT NULL,
  min_amount DECIMAL(18,2) NOT NULL,
  max_amount DECIMAL(18,2) NULL,
  interest_payout ENUM('at_maturity','monthly','quarterly','annually') DEFAULT 'at_maturity',
  maturity_action_default ENUM('payout_to_savings','rollover') DEFAULT 'payout_to_savings',
  early_withdrawal_penalty_type ENUM('percent_of_interest','percent_of_principal','forfeit_interest') DEFAULT 'forfeit_interest',
  early_withdrawal_penalty_value DECIMAL(5,2) DEFAULT 0,
  withholding_tax_percent DECIMAL(5,2) DEFAULT 0,
  is_active TINYINT(1) DEFAULT 1,
  created_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
```  
  
### `fixed_deposits`  
```sql
CREATE TABLE fixed_deposits (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL DEFAULT 1,
  member_id BIGINT UNSIGNED NOT NULL,
  member_name VARCHAR(150) NOT NULL COMMENT 'Denormalized for lists',
  product_id BIGINT UNSIGNED NOT NULL,
  account_number VARCHAR(50) NOT NULL UNIQUE,
  principal DECIMAL(18,2) NOT NULL,
  annual_rate_percent DECIMAL(5,2) NOT NULL COMMENT 'Snapshot from product',
  term_months INT UNSIGNED NOT NULL COMMENT 'Snapshot from product',
  start_date DATE NOT NULL,
  maturity_date DATE NOT NULL,
  expected_interest DECIMAL(18,2) NOT NULL,
  interest_paid_to_date DECIMAL(18,2) DEFAULT 0,
  last_interest_payout_date DATE NULL,
  interest_payout ENUM('at_maturity','monthly','quarterly','annually'),
  maturity_action ENUM('payout_to_savings','rollover'),
  status ENUM('active','matured','closed_early','rolled_over') DEFAULT 'active',
  lien_loan_id BIGINT UNSIGNED NULL COMMENT 'Loan using FD as collateral',
  rolled_over_from_id BIGINT UNSIGNED NULL,
  rolled_over_to_id BIGINT UNSIGNED NULL,
  closed_at TIMESTAMP NULL,
  close_reason TEXT NULL,
  penalty_amount DECIMAL(18,2) DEFAULT 0,
  tax_amount DECIMAL(18,2) DEFAULT 0,
  payment_method ENUM('Cash','Bank Transfer','Mobile Money','Cheque') NULL,
  reference_number VARCHAR(100) NULL,
  notes TEXT NULL,
  created_by BIGINT UNSIGNED NULL,
  processed_by BIGINT UNSIGNED NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_fd_member (sacco_id, member_id, status),
  KEY idx_fd_maturity (maturity_date, status),
  KEY idx_fd_lien (lien_loan_id),
  FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES fd_products(id),
  FOREIGN KEY (lien_loan_id) REFERENCES loans(id) ON DELETE SET NULL,
  FOREIGN KEY (rolled_over_from_id) REFERENCES fixed_deposits(id) ON DELETE SET NULL,
  FOREIGN KEY (rolled_over_to_id) REFERENCES fixed_deposits(id) ON DELETE SET NULL,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  FOREIGN KEY (processed_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;
```  
  
### Ledger entry types (add to existing journal_entries/savings_transactions)  
Transaction types: `fd_open`, `fd_interest`, `fd_maturity`, `fd_rollover`, `fd_early_close`, `fd_penalty`, `fd_tax`  
Each entry links to `fd_id` and `member_id`.  
  
## Interest calculation  
- Simple interest, fixed rate: `interest = principal * (annual_rate_percent / 100) * days / 365`  
- Compute with the stored snapshot values, round to whole UGX or 2 decimal places.  
- Put this in ONE pure, well-tested function (unit tests required).  
- If `withholding_tax_percent > 0`: `tax = round(interest * tax_percent / 100)`, member receives `interest - tax`. Post tax as a separate `fd_tax` ledger entry.  
  
## Features to build  
  
### 1. FD Products screen (admin)  
Create/edit/deactivate products. Editing never touches existing FDs.  
Route: `/fixed-deposits/products`
  
### 2. Open Fixed Deposit  
- Select member, product, amount, maturity action (default from product).  
- Validate: amount >= min_amount, amount <= member savings balance, product active.  
- Show a **confirmation preview** (principal, rate, maturity date, expected interest) before saving.  
- On confirm: atomic transaction -> debit savings, create `fixed_deposits` row, write `fd_open` ledger entry.  
Route: `/fixed-deposits/open`
  
### 3. Fixed Deposits list (admin)  
- Tabs/filters: Active, Maturing in 30 days, Matured, Closed.  
- Search by member name. Show principal, maturity date, days left, status.  
- **"Maturing soon" list** sorted by maturity date so staff never miss one.  
Route: `/fixed-deposits`
  
### 4. FD Details page  
Match the loan details page style. Tabs:  
- **Summary**: member, product, principal, rate, term, start/maturity dates, expected interest, status, lien info.  
- **Transactions**: all ledger entries for this FD.  
Route: `/fixed-deposits/view?id={id}`
  
### 5. Process Maturity (staff action)  
- Only available when `today >= maturity_date` and status is `active`.  
- Show preview: principal, interest, tax, net payout.  
- If `payout_to_savings`: atomic -> credit savings (principal + net interest), write `fd_maturity` (+ `fd_tax` if any), status = `matured`.  
- If `rollover`: close current FD as `rolled_over`, create a new FD (same product or chosen product, snapshot the current rate), link via `rolled_over_from_id`/`rolled_over_to_id`, write `fd_rollover`. Let staff choose whether interest is added to the new principal or paid to savings.  
Route: `POST /fixed-deposits/mature`
  
### 6. Interest payout for monthly/quarterly products  
- A staff action "Post Interest" per FD (and optionally bulk for all due FDs).  
- Prevent double posting: track `interest_paid_to_date` / `last_interest_payout_date` and refuse duplicates.  
Route: `POST /fixed-deposits/post-interest`
  
### 7. Early closure  
- Requires a specific permission (e.g. `fd.closeEarly`) and a **mandatory reason**.  
- Calculate interest earned up to today, apply the product's penalty, show a full preview.  
- Atomic: credit savings with net amount, write `fd_early_close` + `fd_penalty` (+ tax) entries, status = `closed_early`.  
Route: `POST /fixed-deposits/close-early`
  
### 8. Loan lien (collateral)  
- Allow staff to link an FD to a loan (`lien_loan_id`).  
- A FD with a lien cannot be closed early or matured-out until the lien is released or the loan is cleared. Show a clear message.  
- Releasing a lien requires permission and is logged.  
Route: `POST /fixed-deposits/lien` (set/release)
  
### 9. Integration with existing screens  
- **Member 360**: add a "Fixed Deposits" card (count, total locked amount, next maturity) in the same label/value card style. Tap opens the member's FDs.  
- **Member statement PDF**: FD ledger entries appear as normal statement lines with clear descriptions (e.g. "Fixed deposit opened - FD#1234"). Keep the clean DFCU-style layout. Locked FD balance should be shown separately from available savings, never mixed into it.  
- Savings screens must show **available savings** (FD money is not spendable).  
  
### 10. Permissions  
Add permissions and respect the existing role system:  
`fd.view`, `fd.open`, `fd.processMaturity`, `fd.closeEarly`, `fd.manageProducts`, `fd.manageLien`.  
  
## Database transaction safety  
- Use MySQL **transactions (BEGIN/COMMIT/ROLLBACK)** with row locks (`SELECT ... FOR UPDATE`) for anything touching savings balance + FD + ledger.  
- Re-read the savings balance inside the transaction (never trust UI state).  
- Handle failures gracefully: show a clear error, rollback, leave data unchanged.  
  
## Acceptance checklist  
- [ ] Open FD with insufficient savings is blocked.  
- [ ] Opening FD reduces available savings by exactly the principal; ledger entry exists.  
- [ ] Changing a product's rate does not change an existing FD.  
- [ ] Interest function has unit tests (full term, partial term, leap year, tax on/off).  
- [ ] Maturity pays principal + net interest once; running it twice is blocked.  
- [ ] Rollover creates a linked new FD and closes the old one.  
- [ ] Early closure applies the penalty and requires permission + reason.  
- [ ] FD with a lien cannot be closed until released.  
- [ ] Member 360 shows the FD card; statement PDF shows FD lines and locked balance separately.  
- [ ] Nothing posts money automatically; every posting is a staff action with a preview.  
  
## Out of scope for now  
Automatic scheduled interest posting, member-facing/USSD FD requests, variable/floating rates, partial withdrawals.  
  
## Build order  
1. Database schema + interest calculation function + unit tests  
2. FD products CRUD screen  
3. Open FD (atomic transaction)  
4. FD list + details page  
5. Process maturity + rollover  
6. Early closure + penalty  
7. Monthly/quarterly interest posting  
8. Lien on loans  
9. Member 360 card + statement PDF changes  
10. Permissions and audit logging  
  
## UI/UX Style  
- Follow the existing SACCOPLUS PHP app style: clean white cards, label/value rows, Material Icons  
- Use SweetAlert2 for modals with gradient headers (matching shares/savings modals)  
- Professional button styles: m360-btn, m360-btn-primary, m360-btn-outline  
- Tables: m360-table with sticky headers, hover states  
- Status badges with colors: 🟢 Active, 🔵 Matured, 🟡 Closed Early, ⚫ Rolled Over  

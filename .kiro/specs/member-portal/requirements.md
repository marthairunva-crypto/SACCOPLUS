# Requirements Document

## Introduction

The Member Portal is a member-facing self-service web application built on the existing SACCOPLUS PHP 8.x / MySQL codebase (`saccoplus-php`). It provides SACCO members with secure online access to their savings accounts, share balances, loan accounts, and financial transactions without visiting a branch. The portal runs under the `/member` URL prefix on the same server as the admin system, sharing the same database, Services layer, CSS file, and component library — but in a completely separate session namespace so members cannot reach admin routes and staff cannot log in through the member portal.

The portal is delivered in two phases. Phase 1 (Requirements 1–9) covers authentication, dashboard, profile management, savings/shares, deposits/withdrawals, loan application, loan tracking/repayment, guarantor management, and notifications/receipts. Phase 2 (Requirements 10–13) adds airtime/data purchases, bill payments, communication/governance tools, and additional member services.

All money amounts are stored in UGX as `DECIMAL(18,2)`. Every financial posting runs inside a database transaction with `SELECT … FOR UPDATE`. Balances are always derivable from the ledger. The Flutter app and Firestore remain live and untouched.

---

## Glossary

- **Member_Portal**: The PHP web application under the `/member` prefix that provides self-service access for SACCO members.
- **Member_Session**: The PHP session namespace used exclusively for authenticated members (`$_SESSION['member_id']`, distinct from `$_SESSION['user']` used by staff).
- **OTP**: A one-time password delivered via SMS to a member's registered phone number, valid for a single use and expiring after a configurable time window (default 5 minutes).
- **MemberAuth**: The authentication subsystem that handles member login, OTP verification, session lifecycle, lockout, and password reset.
- **MemberDashboard**: The landing page displayed to a member immediately after successful authentication.
- **LoanService**: The single shared PHP service class (`App\Services\LoanService`) that computes loan status, outstanding balance, arrears, and schedule for all consumers (admin and member portal alike). No loan arithmetic is performed in views.
- **StatementService**: The single shared PHP service class (`App\Services\StatementService`) that builds statement data for on-screen display and PDF generation, reused by the member portal without modification.
- **SmsService**: The existing `App\Services\SmsService` class that sends SMS via the EgoSMS gateway.
- **Ledger**: The append-only `journal_entries` / `journal_lines` double-entry table set. Every money movement is a row here. Records are never deleted or updated; corrections are reversals.
- **Savings_Balance**: The single spendable savings balance of a member, derived from the ledger or cached on the `members` table. Savings and wallet are the same concept; there is no separate wallet table.
- **Shares_Balance**: The member's share capital balance. Shares are non-withdrawable except through a formal exit or transfer process.
- **Withdrawable_Balance**: `Savings_Balance` minus shares, locked/lien amounts, and any configured minimum balance. Computed at withdrawal-request time.
- **Migrated_Loan**: A loan whose repayment history was not imported from Firestore. Its arrears are calculated starting from `opening_balance` / `opening_date`, not from an assumed full schedule of past payments.
- **Guarantor**: A member who pledges savings or shares as security for another member's loan. Acceptance places a lien on the guarantor's account equal to the guaranteed amount.
- **Lien**: A hold placed on a portion of a member's Savings_Balance or Shares_Balance, making that portion non-withdrawable until the guaranteed loan is cleared or the lien is released.
- **MoMo_Provider**: MTN Mobile Money or Airtel Money, accessed via a configured payment aggregator API.
- **Idempotency_Key**: A unique string per financial request stored on `journal_entries` so that duplicate callbacks from a payment gateway never produce a second posting.
- **Receipt**: A PDF document with a unique sequential receipt number generated for every completed financial transaction (deposit, withdrawal, repayment, bill payment, airtime purchase).
- **Aggregator**: A third-party payment middleware service that interfaces with MoMo_Provider networks to initiate and confirm mobile money transactions.
- **Biller**: An Admin-configured payee entity (e.g. UMEME, NWSC, DStv) accessible through the Aggregator for bill payments (Phase 2).
- **Notification_Center**: The in-app page listing all in-app notifications for the logged-in member, with read/unread state.
- **Change_Request**: A record created when a member requests modification of a sensitive field (full name, national ID, date of birth) that requires staff approval before being applied.
- **Sacco_Id**: The tenant identifier carried on every data row. All queries are scoped to the member's `sacco_id`.

---

## Requirements

### Requirement 1: Authentication and Account Security

**User Story:** As a SACCO member, I want to log in securely using my member number or phone number and a password followed by an SMS OTP, so that only I can access my account even if my password is compromised.

#### Acceptance Criteria

1. WHEN a member submits a login form with a valid member number or registered phone number and correct password, THE MemberAuth SHALL send a 6-digit OTP to the member's registered phone number before granting access.

2. WHEN the member submits the correct OTP within the configured validity window (default 5 minutes), THE MemberAuth SHALL create a Member_Session, regenerate the PHP session ID, and redirect the member to the MemberDashboard.

3. WHEN a member submits an incorrect OTP 3 consecutive times during the same login attempt, THE MemberAuth SHALL lock OTP verification for that member for 15 minutes and SHALL NOT grant access regardless of subsequent OTP input during the lockout period.

4. WHEN a member submits an incorrect password on 5 consecutive login attempts, THE MemberAuth SHALL lock the member account, SET the member's status to `locked`, and send an SMS alert to the member's registered phone number.

5. THE MemberAuth SHALL store all member passwords using `password_hash` with the `PASSWORD_ARGON2ID` algorithm (falling back to `PASSWORD_BCRYPT` if Argon2id is unavailable on the host).

6. WHEN a member logs in successfully for the first time after account creation, THE MemberAuth SHALL force a password change before displaying the MemberDashboard.

7. WHILE a Member_Session is active and no user interaction is detected for 5 consecutive minutes, THE Member_Portal SHALL destroy the Member_Session and redirect the member to the login page with an inactivity message.

8. THE MemberAuth SHALL set all Member_Session cookies with the `Secure`, `HttpOnly`, and `SameSite=Strict` flags.

9. THE MemberAuth SHALL include a CSRF token on every POST form in the Member_Portal and reject any POST request whose CSRF token does not match the Member_Session token.

10. WHEN a member requests a password reset, THE MemberAuth SHALL send a 6-digit OTP to the member's registered phone number and SHALL allow the password to be changed only after the OTP is verified.

11. WHEN a member's password is changed, THE MemberAuth SHALL send an SMS alert to the member's registered phone number containing the date, time, and a contact prompt.

12. WHEN a member's registered phone number is changed (via profile update), THE MemberAuth SHALL send an SMS alert to BOTH the old phone number and the new phone number.

13. THE MemberAuth SHALL enforce a minimum password strength of at least 8 characters containing at least one uppercase letter, one lowercase letter, one digit, and one special character.

14. WHEN a member is authenticated, THE Member_Portal SHALL record a login history entry containing the timestamp, IP address, and user-agent string, and THE Member_Portal SHALL retain the last 10 login history entries per member.

15. WHEN a member views their profile security section, THE Member_Portal SHALL display the last 10 login history entries (timestamp, IP, device/user-agent).

16. IF a login request arrives for an account whose status is `locked`, THEN THE MemberAuth SHALL reject the attempt with an error message instructing the member to contact the SACCO office.

17. THE Member_Portal SHALL NOT expose any `/admin` or `/member/api/admin` route to a member session, and SHALL NOT allow creation of staff accounts from any member-facing form.

### Requirement 2: Member Dashboard

**User Story:** As an authenticated member, I want a dashboard that shows my key balances and upcoming obligations at a glance, so that I can understand my financial position and take quick actions without navigating deep menus.

#### Acceptance Criteria

1. WHEN an authenticated member loads the MemberDashboard, THE Member_Portal SHALL display the member's current Savings_Balance, Shares_Balance, and total outstanding loan balance sourced from LoanService.

2. WHEN an authenticated member loads the MemberDashboard, THE Member_Portal SHALL display the member's last 5 Ledger transactions (date, description, amount, running balance).

3. WHEN an authenticated member loads the MemberDashboard, THE Member_Portal SHALL display all upcoming loan installment due dates and amounts within the next 30 days, sourced from LoanService.

4. WHEN an authenticated member loads the MemberDashboard and the member has unread in-app notifications, THE Member_Portal SHALL display a count badge on the Notifications navigation item.

5. WHEN an authenticated member loads the MemberDashboard and the member has pending guarantor requests, THE Member_Portal SHALL display a count badge on the Guarantor Requests navigation item.

6. WHEN an authenticated member loads the MemberDashboard and at least one loan installment is overdue according to LoanService, THE Member_Portal SHALL display a prominent arrears warning card showing the total arrears amount and the oldest overdue installment date.

7. WHEN an authenticated member loads the MemberDashboard, THE Member_Portal SHALL display quick-action buttons for: Deposit, Apply for Loan, Repay Loan, Buy Airtime, and View Statement.

8. THE Member_Portal SHALL render the MemberDashboard using the same white-card layout, label/value rows, typography, colors, and component styles as the admin system, applied mobile-first with a responsive layout.

### Requirement 3: Profile Management

**User Story:** As an authenticated member, I want to view and update my personal information, next of kin, and uploaded documents, so that the SACCO always holds accurate records and I can manage my identity details.

#### Acceptance Criteria

1. WHEN an authenticated member views the profile page, THE Member_Portal SHALL display: member number, full name, national ID, date of birth, phone, email, address, occupation, and membership date.

2. WHEN an authenticated member submits a change to phone number, THE MemberAuth SHALL send an OTP to the new phone number and SHALL apply the change only after the member verifies the OTP.

3. WHEN an authenticated member submits a change to email or address, THE Member_Portal SHALL apply the change immediately and write an audit log entry recording who changed what field, the old value, the new value, the IP address, and the timestamp.

4. WHEN an authenticated member requests a change to full name, national ID, or date of birth, THE Member_Portal SHALL create a Change_Request record with status `pending` instead of modifying the member record directly, and SHALL notify the member that the change is awaiting staff approval.

5. WHEN an authenticated member manages next of kin records, THE Member_Portal SHALL allow adding, editing, and removing next of kin entries each containing: full name, relationship, phone number, and percentage share (all shares per member must sum to 100%).

6. WHEN an authenticated member uploads a profile photo or identity document, THE Member_Portal SHALL accept only JPEG, PNG, and PDF files up to 5 MB, assign a random filename, store the file outside the web root, and record the file reference in the `member_documents` table.

7. IF a file upload exceeds 5 MB or is of an unsupported MIME type, THEN THE Member_Portal SHALL reject the upload and display a descriptive error message without saving any partial file.

8. THE Member_Portal SHALL write an audit log entry for every change to phone, email, address, next of kin, and document uploads, scoped by `sacco_id` and `member_id`.

### Requirement 4: Savings and Shares

**User Story:** As an authenticated member, I want to see all my savings accounts, share holdings, and transaction history, and download an account statement, so that I can track my financial activity with the SACCO.

#### Acceptance Criteria

1. WHEN an authenticated member views the accounts page, THE Member_Portal SHALL list all the member's accounts grouped by type: savings, fixed deposits, shares, and other registered products, each showing the current balance.

2. WHEN an authenticated member selects an account to view its transaction history, THE Member_Portal SHALL display a paginated list of transactions (default 20 per page) filterable by date range and transaction type, sourced from the Ledger.

3. WHEN an authenticated member requests a statement PDF for a date range, THE Member_Portal SHALL invoke StatementService and generate a PDF containing: SACCO header (name, logo, address), member name and account number, opening balance, dated rows with description, debit amount, credit amount, and running balance, closing balance, and page numbers.

4. THE Member_Portal SHALL display interest earned and dividend history for the member's savings and share accounts.

5. WHEN an authenticated member views a fixed deposit account, THE Member_Portal SHALL display the account as non-withdrawable and SHALL show the principal amount, interest rate, start date, maturity date, and expected interest at maturity.

6. WHEN an authenticated member views a shares account, THE Member_Portal SHALL display shares as non-withdrawable and SHALL show the number of shares, price per share, and total share value.

7. WHILE a Lien is active on a portion of the member's Savings_Balance, THE Member_Portal SHALL display the liened amount as a separate read-only line in the account summary so the member can see which portion is restricted.

### Requirement 5: Deposits and Withdrawals

**User Story:** As an authenticated member, I want to deposit money to my savings account via mobile money and request withdrawals, so that I can fund my account and access my funds from anywhere.

#### Acceptance Criteria

1. WHEN an authenticated member initiates a deposit via MTN MoMo or Airtel Money, THE Member_Portal SHALL send a payment prompt to the member's selected phone number through the Aggregator and SHALL display a pending status screen.

2. WHEN the Aggregator sends a successful payment callback, THE Member_Portal SHALL verify the Idempotency_Key, post a Ledger credit entry inside a database transaction with `SELECT … FOR UPDATE`, update the Savings_Balance, generate a Receipt PDF, and send an SMS confirmation to the member.

3. IF the Aggregator sends a duplicate callback for a transaction whose Idempotency_Key already exists in `journal_entries`, THEN THE Member_Portal SHALL acknowledge the callback to the Aggregator without creating a second Ledger entry.

4. WHEN a mobile money payment times out or the Aggregator reports failure, THE Member_Portal SHALL NOT modify the member's balance, SHALL display a failure status message, and SHALL require the teller or reconciliation process to resolve the transaction.

5. WHEN an authenticated member submits a withdrawal request, THE Member_Portal SHALL compute the Withdrawable_Balance (Savings_Balance minus shares, locked deposits, lien amounts, and configured minimum balance) and SHALL reject the request with an explanatory message if the requested amount exceeds the Withdrawable_Balance.

6. WHEN a valid withdrawal amount is requested, THE Member_Portal SHALL require the member to confirm via OTP before submitting the request for staff approval (or auto-approval if the amount is below the Admin-configured auto-approval limit).

7. WHEN a withdrawal request is approved (by staff or auto-approved), THE Member_Portal SHALL post a Ledger debit entry inside a database transaction with `SELECT … FOR UPDATE`, update the Savings_Balance, generate a Receipt PDF, and send an SMS confirmation to the member.

8. THE Member_Portal SHALL enforce per-transaction and per-day deposit and withdrawal limits as configured by Admin in system settings, and SHALL reject any request that would exceed these limits.

9. THE Member_Portal SHALL rate-limit deposit and withdrawal initiation requests per member to prevent abuse, with a maximum of 10 initiation attempts per 15-minute window per member.

### Requirement 6: Loan Application

**User Story:** As an authenticated member, I want to browse loan products, calculate my potential repayments, and submit a loan application with guarantors online, so that I can apply for a loan without visiting a branch.

#### Acceptance Criteria

1. WHEN an authenticated member views the loan products page, THE Member_Portal SHALL list all active loan products for the member's SACCO, displaying for each: product name, interest rate, interest method (flat/reducing), maximum amount, maximum term in months, fees, and eligibility summary.

2. WHEN an authenticated member enters a loan amount and term into the loan calculator, THE Member_Portal SHALL display: total interest, all applicable fees, monthly installment amount, total repayable amount, and the full amortisation schedule, computed by LoanService, before the member submits the application.

3. WHEN an authenticated member submits a loan application, THE Member_Portal SHALL evaluate eligibility and SHALL reject the application if any of these conditions are true: member status is not `active`; membership duration is below the product's minimum; the member has an existing overdue loan; the requested principal exceeds the product's maximum amount-to-savings-multiple rule.

4. WHEN a loan application passes eligibility checks, THE Member_Portal SHALL require the member to specify: requested amount, loan purpose, repayment period, at least the product's required number of guarantors (identified by member number or phone), and any supporting documents.

5. WHEN a loan application is submitted with one or more guarantors, THE Member_Portal SHALL set the application status to `awaiting_guarantors`, send an SMS notification to each guarantor's phone, and create an in-app guarantor request for each guarantor.

6. WHEN all required guarantors have accepted, THE Member_Portal SHALL automatically advance the application status to `submitted` and send an SMS acknowledgement with a reference number to the applicant.

7. WHEN a member submits a loan application, THE Member_Portal SHALL write an audit log entry, assign a unique reference number, and send an SMS acknowledgement to the member.

8. THE Member_Portal SHALL allow a member to save an incomplete loan application as a draft and resume it later, and SHALL allow cancellation of any application that has not yet been reviewed by staff (status is `draft` or `awaiting_guarantors`).

### Requirement 7: Loan Tracking and Repayment

**User Story:** As an authenticated member, I want to view the full details of my active and historical loans, track their status, and make repayments via mobile money or from my savings, so that I can manage my loan obligations without visiting a branch.

#### Acceptance Criteria

1. WHEN an authenticated member views the loans page, THE Member_Portal SHALL list all the member's loan applications and loans with their current status from the following state sequence: Draft → Awaiting Guarantors → Submitted → Under Review → Approved → Rejected → Disbursed → Cleared → Defaulted.

2. IF a loan application is in `rejected` status, THEN THE Member_Portal SHALL display the rejection reason provided by staff.

3. WHEN an authenticated member views a loan's detail page, THE Member_Portal SHALL display, sourced exclusively from LoanService: principal amount, total interest, outstanding balance, next due date, next installment amount, total arrears, and all staff-added late charges with their reasons and dates.

4. WHEN an authenticated member views a loan's detail page, THE Member_Portal SHALL render three tabs: Summary, Schedule, and Loan Card, using the same tab layout as the admin loan details page.

5. WHILE a loan has the `is_migrated` flag set, THE Member_Portal SHALL display a note on the loan detail page explaining that repayment history was not imported and that arrears are calculated from the opening balance and opening date.

6. THE Member_Portal SHALL NEVER display, calculate, suggest, or apply a penalty amount automatically; all displayed late charges SHALL be only those manually entered by staff via the admin system.

7. WHEN an authenticated member initiates a loan repayment via mobile money, THE Member_Portal SHALL apply the same Aggregator flow as deposits: prompt → callback verification → Idempotency_Key check → Ledger posting in a database transaction → receipt generation → SMS confirmation.

8. WHEN an authenticated member initiates a loan repayment from savings, THE Member_Portal SHALL check that the Withdrawable_Balance covers the repayment amount, post both a Ledger savings debit and a loan credit inside a single database transaction with `SELECT … FOR UPDATE`, and generate a receipt.

9. WHEN a loan repayment is posted, THE Member_Portal SHALL allocate the payment in the configured order: outstanding penalties first, then interest, then principal, calling LoanService to perform the allocation.

10. WHEN an authenticated member requests a payoff quote, THE Member_Portal SHALL display the early settlement amount as of the current date, computed by LoanService.

11. THE Member_Portal SHALL generate a loan statement PDF for any active or cleared loan on request, using StatementService, in the same format as the savings statement.

12. WHEN a loan installment is 3 days from its due date, THE Member_Portal SHALL send an SMS reminder to the member via SmsService.

13. WHEN a loan installment becomes overdue, THE Member_Portal SHALL send an SMS reminder to the member via SmsService the day the installment is due.

### Requirement 8: Guarantor Management

**User Story:** As a SACCO member, I want to review and respond to guarantor requests, track loans I am guaranteeing, and be notified of repayment events on guaranteed loans, so that I can make informed decisions about my financial exposure.

#### Acceptance Criteria

1. WHEN an authenticated member has pending guarantor requests, THE Member_Portal SHALL display each request on the Guarantor Requests page showing: borrower's name, loan amount, loan purpose, and the specific amount the member is being asked to guarantee.

2. WHEN an authenticated member chooses to accept a guarantor request, THE Member_Portal SHALL require OTP verification before confirming acceptance.

3. WHEN OTP verification succeeds for guarantor acceptance, THE Member_Portal SHALL place a Lien on the guarantor's Savings_Balance or Shares_Balance equal to the guaranteed amount, recorded in a Lien table, inside a database transaction with `SELECT … FOR UPDATE`.

4. IF a member's free savings (Savings_Balance minus existing liens and minimum balance) is less than the requested guarantee amount, THEN THE Member_Portal SHALL reject the guarantee acceptance with a descriptive message and SHALL NOT place any Lien.

5. WHEN an authenticated member views the Guarantor page, THE Member_Portal SHALL list all loans the member is currently guaranteeing, showing the borrower name, original guaranteed amount, current loan repayment status, and remaining lien.

6. WHEN a guaranteed loan reaches `cleared` status, THE Member_Portal SHALL automatically remove the corresponding Lien and send an SMS notification to the guarantor via SmsService.

7. WHEN a guaranteed loan installment becomes overdue, THE Member_Portal SHALL send an SMS notification to the guarantor via SmsService.

### Requirement 9: Notifications and Receipts

**User Story:** As an authenticated member, I want to receive SMS and in-app notifications for all important account events and download receipts for every financial transaction, so that I have a real-time record of my SACCO activity.

#### Acceptance Criteria

1. THE SmsService SHALL send an SMS notification to the member's registered phone number for each of the following events: savings deposit confirmed, withdrawal approved, loan application status change, guarantor request received, loan repayment reminder (3 days before and on due date), password changed, phone number changed, SACCO-wide announcement, and overdraft/arrears alert.

2. WHEN any of the events listed in criterion 1 occurs, THE Member_Portal SHALL also create an in-app notification record in the `member_notifications` table with a read/unread flag, the event type, a descriptive message, and the timestamp.

3. WHEN an authenticated member views the Notification_Center, THE Member_Portal SHALL display all the member's notifications ordered by date descending, showing unread items visually distinct from read items.

4. WHEN an authenticated member marks a notification as read, THE Member_Portal SHALL update the `read_at` timestamp on the notification record.

5. WHEN a financial transaction is completed (deposit, withdrawal, loan repayment, bill payment, airtime purchase), THE Member_Portal SHALL generate a Receipt PDF containing: unique sequential receipt number (per SACCO), SACCO name and logo, member name and account number, transaction type, amount, date and time, reference number, and teller/system identifier.

6. WHEN an authenticated member views the Receipts page, THE Member_Portal SHALL list all receipts for the member's transactions and allow download of each Receipt PDF.

7. WHERE a member has opted out of non-security notifications for a category, THE Member_Portal SHALL suppress SMS and in-app notifications for that category, but SHALL always send security-critical SMS (password change, phone change, account lock).

8. WHEN SmsService fails to deliver an SMS, THE Member_Portal SHALL log the failure to the `sms_failures` table and SHALL retry delivery according to the configured retry schedule.

9. THE Member_Portal SHALL provide a notification preferences page where the member can toggle notification categories on or off, excluding security-critical categories.

---

## Phase 2 Requirements

### Requirement 10: Airtime and Data Purchase

**User Story:** As an authenticated member, I want to buy airtime and data bundles for any phone number from my savings balance, so that I can handle my telecommunications needs through the SACCO portal.

#### Acceptance Criteria

1. WHEN an authenticated member views the Airtime purchase page, THE Member_Portal SHALL display all supported networks (MTN, Airtel, and other configured networks) and allow the member to enter a recipient phone number (own or another number).

2. WHEN an authenticated member initiates an airtime purchase, THE Member_Portal SHALL display: the amount, applicable fee, source account, and require PIN or OTP confirmation before submitting to the Aggregator.

3. THE Member_Portal SHALL ONLY permit airtime debit from the member's Savings_Balance and SHALL NOT debit shares, locked deposits, or liened amounts.

4. WHEN an Aggregator confirms airtime delivery, THE Member_Portal SHALL post a Ledger debit entry inside a database transaction, generate a receipt, and send an SMS confirmation to the member.

5. WHEN the Aggregator returns a failure response for an airtime request, THE Member_Portal SHALL automatically reverse any pending balance hold, notify the member of the failure, and make no permanent Ledger entry.

6. WHEN an Aggregator response for an airtime request is pending beyond the configured timeout, THE Member_Portal SHALL mark the transaction as `pending`, hold the amount from the Withdrawable_Balance, and resolve it through the reconciliation process.

7. THE Member_Portal SHALL allow members to save beneficiary phone numbers with labels, list saved beneficiaries for quick selection, and delete saved beneficiaries.

8. THE Member_Portal SHALL enforce per-transaction and per-day airtime purchase limits as configured by Admin, and SHALL reject any request that would exceed these limits.

### Requirement 11: Bill Payments

**User Story:** As an authenticated member, I want to pay utility bills and other configured billers directly from my savings account, so that I can manage recurring payments through a single platform.

#### Acceptance Criteria

1. WHEN an authenticated member views the Bill Payments page, THE Member_Portal SHALL list only Admin-configured active billers (which may include UMEME, NWSC, DStv, GOtv, StarTimes, URA, internet providers, and school fees collectors).

2. WHEN an authenticated member enters a meter number, account number, or smart card number for a biller, THE Member_Portal SHALL validate the reference with the biller through the Aggregator and SHALL display the customer name returned by the biller before the member confirms payment.

3. IF the Aggregator cannot validate the biller reference, THEN THE Member_Portal SHALL display a validation failure message and SHALL NOT allow the member to proceed with payment.

4. WHEN a bill payment is confirmed and the Aggregator reports success, THE Member_Portal SHALL post a Ledger debit entry inside a database transaction, generate a Receipt PDF, display the biller token or reference number (e.g. UMEME prepaid token), and send the token to the member via SMS.

5. WHEN the Aggregator returns a failure response for a bill payment, THE Member_Portal SHALL apply the same failure and auto-reversal rules as Requirement 10 criterion 5.

6. WHEN an Aggregator response for a bill payment is pending, THE Member_Portal SHALL apply the same pending-hold and reconciliation rules as Requirement 10 criterion 6.

7. THE Member_Portal SHALL display a payment history list for bill payments and allow download of each receipt, scoped to the authenticated member and `sacco_id`.

8. THE Member_Portal SHALL allow members to save biller references as beneficiaries with labels, list saved beneficiaries for quick selection, and delete them.

### Requirement 12: Communication and Governance

**User Story:** As an authenticated member, I want to read SACCO announcements, view meeting information, raise support tickets, access policy documents, and optionally vote in resolutions, so that I can participate in SACCO governance from the portal.

#### Acceptance Criteria

1. WHEN an authenticated member views the Announcements page, THE Member_Portal SHALL display all active announcements published by staff, ordered by date descending, scoped to the member's `sacco_id`.

2. WHEN an authenticated member views the Meetings page, THE Member_Portal SHALL list scheduled meetings and AGMs showing date, venue, and agenda, and SHALL provide download links for uploaded meeting minutes documents.

3. WHEN an authenticated member submits a support or complaint form, THE Member_Portal SHALL create a ticket record with a unique reference number, send an SMS acknowledgement to the member, and display the ticket status (open, in progress, resolved).

4. WHEN staff reply to a support ticket, THE Member_Portal SHALL update the ticket record and send an SMS notification to the member.

5. WHEN an authenticated member views the Documents page, THE Member_Portal SHALL list all Admin-published FAQs, policies, and bylaws with download links, scoped to the member's `sacco_id`.

6. WHERE an Admin has enabled e-voting for a specific resolution, THE Member_Portal SHALL allow each eligible member to cast exactly one vote per resolution, record the vote with the member ID, `sacco_id`, timestamp, and resolution ID in an auditable votes table, and SHALL NOT permit vote modification after submission.

7. WHEN e-voting is not enabled for a resolution, THE Member_Portal SHALL NOT display a voting option for that resolution.

### Requirement 13: Additional Member Services

**User Story:** As an authenticated member, I want to request account exit, set savings goals, use the portal in my preferred language, and upload loan-supporting documents after application, so that the portal covers the full lifecycle of my SACCO membership.

#### Acceptance Criteria

1. WHEN an authenticated member submits a membership exit request, THE Member_Portal SHALL create an exit request record with status `pending`, write an audit log entry, and notify the member by SMS that the request is under review.

2. WHEN a membership exit request is approved by staff, THE Member_Portal SHALL notify the member via SMS and update the exit request status to `approved`.

3. WHEN an authenticated member creates a savings goal, THE Member_Portal SHALL record the goal name, target amount, target date, and linked savings account, and SHALL display progress as a percentage of the target amount reached.

4. WHEN an authenticated member selects a display language, THE Member_Portal SHALL render all labels, headings, and static strings in English or Luganda according to the selection and SHALL persist the choice in the member's session and profile.

5. WHEN an authenticated member uploads a supporting document for an existing loan application (status `draft` or `awaiting_guarantors` or `submitted`), THE Member_Portal SHALL accept the file under the same upload rules as Requirement 3 criterion 6, link it to the loan application record, and confirm the upload via in-app notification.

---

## Non-Functional Requirements

### Requirement 14: Security

**User Story:** As the SACCO operator, I want the Member Portal to meet baseline web application security standards, so that member data and funds are protected against common attacks.

#### Acceptance Criteria

1. THE Member_Portal SHALL operate exclusively over HTTPS; any HTTP request SHALL be redirected to HTTPS with a 301 status.

2. THE Member_Portal SHALL apply rate limiting on login, OTP verification, and payment initiation endpoints, with a maximum of 5 attempts per minute per IP for login and OTP and 10 initiations per 15-minute window per member for payments.

3. THE Member_Portal SHALL escape all user-supplied output with `htmlspecialchars` before rendering in HTML templates to prevent Cross-Site Scripting.

4. THE Member_Portal SHALL use PDO prepared statements for all database queries and SHALL NEVER concatenate user input into SQL strings.

5. THE Member_Portal SHALL store all secrets (database credentials, API keys, SMS credentials, aggregator keys) in environment variables or a non-committed config file and SHALL NOT expose them in source code, error messages, or HTTP responses.

6. THE Member_Portal SHALL enforce role isolation such that a Member_Session can only access routes under `/member`, and any request to `/admin` or non-member routes with a Member_Session SHALL return a 403 response.

7. THE Member_Portal SHALL apply OWASP Top 10 mitigations including: parameterised queries (injection), CSRF tokens (CSRF), output escaping (XSS), secure session configuration (broken authentication), and input validation on all POST parameters.

### Requirement 15: Financial Integrity

**User Story:** As the SACCO operator, I want every financial operation in the portal to be atomic, auditable, and recoverable, so that member balances are always accurate and traceable.

#### Acceptance Criteria

1. THE Member_Portal SHALL post every money movement as a row in `journal_entries` / `journal_lines` using a double-entry format where `SUM(debit) = SUM(credit)` per entry.

2. THE Member_Portal SHALL wrap every balance-changing database operation in a transaction using `BEGIN … COMMIT` with `SELECT … FOR UPDATE` on the affected account rows to prevent race conditions.

3. THE Member_Portal SHALL NEVER delete or update a posted Ledger row; corrections SHALL be new reversal entries that reference the original `journal_entries.id`.

4. THE Member_Portal SHALL use an Idempotency_Key on every payment-initiated Ledger entry so that replayed or duplicate gateway callbacks cannot create duplicate credits or debits.

5. THE Member_Portal SHALL ensure that all member savings balances remain derivable by replaying `journal_lines` for the member's `member_account_id`, and the `scripts/recalc_balances.php` script SHALL produce the same result as the cached balance column.

6. THE Member_Portal SHALL write an audit log entry to the `audit_logs` table for every financial transaction, profile change, and loan action, recording: `sacco_id`, `user_id` (or member ID), action, entity, entity ID, old values (JSON), new values (JSON), IP address, and timestamp.

### Requirement 16: Performance and Usability

**User Story:** As a member on a slow mobile connection, I want the portal to load quickly and display correctly on my phone screen, so that I can use the SACCO portal on any device.

#### Acceptance Criteria

1. THE Member_Portal SHALL render all pages within 3 seconds on a simulated 3G connection (approximately 1.5 Mbps) for pages with up to 50 Ledger rows fetched.

2. THE Member_Portal SHALL paginate all transaction history and statement views server-side with a default page size of 20 rows, and SHALL NOT load the full transaction history into memory at once.

3. THE Member_Portal SHALL use the single shared CSS file (`public/assets/css/app.css`) from the admin system as its only stylesheet, with no additional CSS libraries or inline style blocks that deviate from the established design system.

4. THE Member_Portal SHALL use server-rendered PHP templates for all page content and SHALL limit JavaScript to AJAX fetch calls and progressive-enhancement interactions; no SPA framework and no build step are permitted.

5. THE Member_Portal SHALL render correctly on viewport widths from 320 px to 1920 px, applying a mobile-first layout that collapses the navigation to a hamburger menu on screens narrower than 768 px.

### Requirement 17: Multi-Tenancy and Extensibility

**User Story:** As the SACCOPLUS product operator, I want the portal to be multi-SACCO ready and to expose its business logic through shared Services so that other channels (USSD, API) can reuse the same logic in the future.

#### Acceptance Criteria

1. THE Member_Portal SHALL scope every database query to the authenticated member's `sacco_id`, and a member of one SACCO SHALL NEVER be able to view or modify data belonging to another SACCO.

2. THE Member_Portal SHALL delegate all loan balance, arrears, schedule, and eligibility calculations to LoanService and SHALL NOT duplicate these formulas in views or controllers.

3. THE Member_Portal SHALL delegate all statement data assembly and PDF rendering to StatementService, and SHALL NOT duplicate statement logic in views or controllers.

4. THE Member_Portal SHALL delegate all SMS sending to SmsService, and SHALL NOT make direct HTTP calls to the EgoSMS API from controllers or views.

5. WHERE a business rule (eligibility check, repayment allocation, lien calculation) is used by both the admin system and the Member_Portal, THE Member_Portal SHALL call the shared Service class rather than re-implementing the rule.

6. THE Member_Portal SHALL use clean URLs under the `/member` prefix with no `.php` file extension, and SHALL route all requests through the existing front controller (`public/index.php`) with `.htaccess` rewrite rules.

7. THE Member_Portal SHALL include `Africa/Kampala` timezone handling for all date/time display and storage, format all phone numbers to Uganda's `+256XXXXXXXXX` standard, and display all monetary amounts in UGX.

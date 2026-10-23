-- SACCOPLUS Multi-Tenant Schema (MySQL 8, InnoDB)
-- Professional double-entry accounting system
-- Rules: every business table carries sacco_id; branch-scoped tables carry branch_id.
-- Money = DECIMAL(18,2). Ledger is append-only: corrections are reversals, never edits.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- Drop existing tables if they exist
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS loan_repayments;
DROP TABLE IF EXISTS loan_schedule;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS loan_products;
DROP TABLE IF EXISTS journal_lines;
DROP TABLE IF EXISTS journal_entries;
DROP TABLE IF EXISTS member_accounts;
DROP TABLE IF EXISTS gl_accounts;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS api_tokens;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS branches;
DROP TABLE IF EXISTS saccos;

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS saccoplus_v2 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE saccoplus_v2;

-- ---------- TENANTS & BRANCHES ----------

CREATE TABLE saccos (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  code VARCHAR(20) NOT NULL UNIQUE,
  phone VARCHAR(30), 
  email VARCHAR(150), 
  address VARCHAR(255),
  currency CHAR(3) NOT NULL DEFAULT 'UGX',
  status ENUM('active','suspended') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE branches (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  code VARCHAR(20) NOT NULL,
  is_head_office TINYINT(1) NOT NULL DEFAULT 0,
  status ENUM('active','closed') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_branch_code (sacco_id, code),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- USERS & ROLES ----------
-- role: super_admin (sacco_id NULL), sacco_admin (all branches), branch_manager, teller, loan_officer, auditor, member

CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NULL,
  branch_id BIGINT UNSIGNED NULL,           -- NULL = access to all branches of the sacco
  name VARCHAR(120) NOT NULL,
  email VARCHAR(150) NOT NULL,
  phone VARCHAR(30),
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('super_admin','sacco_admin','branch_manager','teller','loan_officer','auditor','member') NOT NULL,
  member_id BIGINT UNSIGNED NULL,           -- set when role = member (mobile app login)
  status ENUM('active','disabled') NOT NULL DEFAULT 'active',
  last_login_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_email (email),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE api_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  device VARCHAR(120),
  expires_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- MEMBERS ----------

CREATE TABLE members (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NOT NULL,       -- home branch
  member_no VARCHAR(30) NOT NULL,
  full_name VARCHAR(150) NOT NULL,
  national_id VARCHAR(40),
  phone VARCHAR(30),
  email VARCHAR(150),
  gender ENUM('M','F'),
  date_of_birth DATE,
  address VARCHAR(255),
  next_of_kin_name VARCHAR(150), 
  next_of_kin_phone VARCHAR(30),
  status ENUM('active','dormant','exited') NOT NULL DEFAULT 'active',
  joined_on DATE NOT NULL,
  created_by BIGINT UNSIGNED,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- For Firestore migration
  legacy_id VARCHAR(100) UNIQUE NULL COMMENT 'Firestore document ID',
  
  UNIQUE KEY uq_member_no (sacco_id, member_no),
  KEY idx_member_branch (sacco_id, branch_id),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- CHART OF ACCOUNTS & LEDGER ----------

CREATE TABLE gl_accounts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(150) NOT NULL,
  type ENUM('asset','liability','equity','income','expense') NOT NULL,
  parent_id BIGINT UNSIGNED NULL COMMENT 'For hierarchical GL',
  is_system TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'System accounts cannot be deleted',
  status ENUM('active','inactive') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_gl_code (sacco_id, code),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (parent_id) REFERENCES gl_accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Member savings account (savings = wallet in this SACCO, one balance only)
CREATE TABLE member_accounts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NOT NULL,
  member_id BIGINT UNSIGNED NOT NULL,
  account_no VARCHAR(30) NOT NULL,
  type ENUM('savings','shares') NOT NULL DEFAULT 'savings',
  gl_account_id BIGINT UNSIGNED NOT NULL,   -- liability GL this account rolls up to
  status ENUM('active','frozen','closed') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_account_no (sacco_id, account_no),
  KEY idx_member_accounts (sacco_id, member_id, type),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (gl_account_id) REFERENCES gl_accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One journal entry = one business event (deposit, disbursement, repayment, reversal)
CREATE TABLE journal_entries (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NOT NULL,
  txn_ref VARCHAR(40) NOT NULL,
  idempotency_key VARCHAR(64) NULL,         -- stops double-posting on mobile retries
  txn_type VARCHAR(40) NOT NULL,            -- deposit, withdrawal, loan_disbursement, loan_repayment, fee, reversal...
  description VARCHAR(255),
  value_date DATE NOT NULL,
  reverses_entry_id BIGINT UNSIGNED NULL,
  posted_by BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_txn_ref (sacco_id, txn_ref),
  UNIQUE KEY uq_idem (sacco_id, idempotency_key),
  KEY idx_je_date (sacco_id, branch_id, value_date),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (branch_id) REFERENCES branches(id),
  FOREIGN KEY (reverses_entry_id) REFERENCES journal_entries(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Lines must balance: SUM(debit) = SUM(credit) per entry (enforced in the posting service)
CREATE TABLE journal_lines (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  entry_id BIGINT UNSIGNED NOT NULL,
  gl_account_id BIGINT UNSIGNED NOT NULL,
  member_account_id BIGINT UNSIGNED NULL,
  loan_id BIGINT UNSIGNED NULL,
  debit DECIMAL(18,2) NOT NULL DEFAULT 0,
  credit DECIMAL(18,2) NOT NULL DEFAULT 0,
  KEY idx_jl_entry (entry_id),
  KEY idx_jl_member_acct (sacco_id, member_account_id),
  KEY idx_jl_loan (sacco_id, loan_id),
  FOREIGN KEY (entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE,
  FOREIGN KEY (gl_account_id) REFERENCES gl_accounts(id),
  FOREIGN KEY (member_account_id) REFERENCES member_accounts(id),
  CHECK (debit >= 0 AND credit >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- LOANS ----------

CREATE TABLE loan_products (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  interest_rate DECIMAL(6,3) NOT NULL,                     -- % per period
  interest_method ENUM('flat','reducing') NOT NULL DEFAULT 'reducing',
  rate_period ENUM('month','year') NOT NULL DEFAULT 'month',
  min_amount DECIMAL(18,2) DEFAULT 0, 
  max_amount DECIMAL(18,2),
  max_term_months INT,
  penalty_rate DECIMAL(6,3) DEFAULT 0,
  processing_fee_pct DECIMAL(6,3) DEFAULT 0,
  status ENUM('active','retired') NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sacco_id) REFERENCES saccos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE loans (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NOT NULL,
  member_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  loan_no VARCHAR(30) NOT NULL,
  principal DECIMAL(18,2) NOT NULL,
  term_months INT NOT NULL,
  interest_rate DECIMAL(6,3) NOT NULL,                     -- frozen at approval
  interest_method ENUM('flat','reducing') NOT NULL,
  status ENUM('pending','approved','active','cleared','written_off','rejected') NOT NULL DEFAULT 'pending',
  applied_on DATE NOT NULL,
  approved_by BIGINT UNSIGNED NULL,
  approved_on DATE NULL,
  disbursed_on DATE NULL,
  first_due_date DATE NULL,
  is_migrated TINYINT(1) NOT NULL DEFAULT 0,               -- imported from old system
  migrated_balance DECIMAL(18,2) NULL COMMENT 'Opening balance for migrated loans',
  migrated_date DATE NULL COMMENT 'Date balance was imported',
  purpose TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  -- For Firestore migration
  legacy_id VARCHAR(100) UNIQUE NULL COMMENT 'Firestore document ID',
  
  UNIQUE KEY uq_loan_no (sacco_id, loan_no),
  KEY idx_loan_branch (sacco_id, branch_id, status),
  KEY idx_loan_member (member_id, status),
  FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  FOREIGN KEY (member_id) REFERENCES members(id),
  FOREIGN KEY (product_id) REFERENCES loan_products(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE loan_schedule (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  loan_id BIGINT UNSIGNED NOT NULL,
  installment_no INT NOT NULL,
  due_date DATE NOT NULL,
  principal_due DECIMAL(18,2) NOT NULL,
  interest_due DECIMAL(18,2) NOT NULL,
  principal_paid DECIMAL(18,2) NOT NULL DEFAULT 0,
  interest_paid DECIMAL(18,2) NOT NULL DEFAULT 0,
  penalty_accrued DECIMAL(18,2) NOT NULL DEFAULT 0,
  penalty_paid DECIMAL(18,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_sched (loan_id, installment_no),
  KEY idx_sched_due (sacco_id, due_date),
  FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE loan_repayments (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  branch_id BIGINT UNSIGNED NOT NULL,
  loan_id BIGINT UNSIGNED NOT NULL,
  journal_entry_id BIGINT UNSIGNED NOT NULL,
  paid_on DATE NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  to_principal DECIMAL(18,2) NOT NULL DEFAULT 0,
  to_interest DECIMAL(18,2) NOT NULL DEFAULT 0,
  to_penalty DECIMAL(18,2) NOT NULL DEFAULT 0,
  source ENUM('cash','savings','mobile_money','migrated') NOT NULL DEFAULT 'savings',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_repay_loan (loan_id, paid_on),
  FOREIGN KEY (loan_id) REFERENCES loans(id),
  FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Loan charges (fees, penalties - manually applied)
CREATE TABLE loan_charges (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NOT NULL,
  loan_id BIGINT UNSIGNED NOT NULL,
  charge_type ENUM('late_payment_fee','processing_fee','insurance','appraisal_fee','other') NOT NULL,
  amount DECIMAL(18,2) NOT NULL,
  reason TEXT NOT NULL,
  status ENUM('pending','applied','waived') NOT NULL DEFAULT 'applied',
  journal_entry_id BIGINT UNSIGNED NULL,
  added_by BIGINT UNSIGNED NOT NULL,
  waived_by BIGINT UNSIGNED NULL,
  waiver_reason TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  waived_at TIMESTAMP NULL,
  KEY idx_charges_loan (loan_id),
  FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
  FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- AUDIT ----------

CREATE TABLE audit_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id BIGINT UNSIGNED NULL,
  user_id BIGINT UNSIGNED NULL,
  action VARCHAR(60) NOT NULL,
  entity VARCHAR(40), 
  entity_id BIGINT UNSIGNED,
  old_values JSON,
  new_values JSON,
  ip VARCHAR(45),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_audit (sacco_id, created_at),
  KEY idx_audit_entity (entity, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- Balance of a member savings account (always derived from the ledger):
--   SELECT SUM(credit - debit) FROM journal_lines
--   WHERE sacco_id = ? AND member_account_id = ?;

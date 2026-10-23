-- Run all migrations in order
-- Usage: mysql -u root -p < database/migrations/run_migrations.sql

SOURCE schema.sql;
SOURCE migrations/001_create_members.sql;
SOURCE migrations/002_create_ledger.sql;
SOURCE migrations/003_create_loans.sql;

-- Seed test member
USE saccoplus_v2;

-- Get the SACCO ID (assuming one SACCO exists after running create_admin.php)
SET @sacco_id = (SELECT id FROM saccos LIMIT 1);

-- Insert test member
INSERT INTO members (
  sacco_id, legacy_id, account_number, membership_number, 
  full_name, phone, email, gender, savings_balance, shares_balance, 
  status, district, village, joined_date
) VALUES (
  @sacco_id, 'test_001', '920300001', 'MEM001',
  'Test Member One', '256700123456', 'test@example.com', 'Male',
  500000, 100000, 'active', 'Kampala', 'Test Village', '2024-01-01'
) ON DUPLICATE KEY UPDATE full_name=VALUES(full_name);

-- Insert test transactions
SET @member_id = LAST_INSERT_ID();

INSERT INTO ledger (sacco_id, member_id, type, description, debit, credit, transaction_date, recorded_by)
VALUES 
  (@sacco_id, @member_id, 'deposit', 'Opening balance', 0, 500000, '2024-01-01', 1),
  (@sacco_id, @member_id, 'shares_purchase', 'Shares purchase', 100000, 0, '2024-01-15', 1),
  (@sacco_id, @member_id, 'deposit', 'Monthly savings', 0, 50000, '2024-02-01', 1),
  (@sacco_id, @member_id, 'withdrawal', 'Cash withdrawal', 30000, 0, '2024-02-15', 1),
  (@sacco_id, @member_id, 'deposit', 'Monthly savings', 0, 50000, '2024-03-01', 1);

SELECT 'Migrations complete! Test member and transactions created.' AS Status;

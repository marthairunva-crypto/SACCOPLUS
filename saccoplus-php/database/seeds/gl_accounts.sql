-- Standard Chart of Accounts for SACCO
-- Executed after schema creation for each SACCO

USE saccoplus_v2;

-- Get the SACCO ID (pass as parameter or use first SACCO)
SET @sacco_id = (SELECT id FROM saccos LIMIT 1);

-- ASSETS (1000-1999)
INSERT INTO gl_accounts (sacco_id, code, name, type, is_system) VALUES
(@sacco_id, '1010', 'Cash on Hand', 'asset', 1),
(@sacco_id, '1020', 'Cash at Bank - Operating Account', 'asset', 1),
(@sacco_id, '1030', 'Cash at Bank - Savings Account', 'asset', 1),
(@sacco_id, '1100', 'Loans Receivable - Principal', 'asset', 1),
(@sacco_id, '1110', 'Loans Receivable - Interest', 'asset', 1),
(@sacco_id, '1120', 'Loans Receivable - Penalties', 'asset', 1),
(@sacco_id, '1200', 'Office Equipment', 'asset', 0),
(@sacco_id, '1210', 'Furniture & Fixtures', 'asset', 0),
(@sacco_id, '1300', 'Prepaid Expenses', 'asset', 0);

-- LIABILITIES (2000-2999)
INSERT INTO gl_accounts (sacco_id, code, name, type, is_system) VALUES
(@sacco_id, '2010', 'Member Savings Deposits', 'liability', 1),
(@sacco_id, '2020', 'Member Shares', 'liability', 1),
(@sacco_id, '2100', 'Bank Loans Payable', 'liability', 0),
(@sacco_id, '2200', 'Interest Payable on Deposits', 'liability', 1),
(@sacco_id, '2300', 'Accounts Payable', 'liability', 0);

-- EQUITY (3000-3999)
INSERT INTO gl_accounts (sacco_id, code, name, type, is_system) VALUES
(@sacco_id, '3010', 'Retained Earnings', 'equity', 1),
(@sacco_id, '3020', 'Current Year Surplus/Deficit', 'equity', 1),
(@sacco_id, '3100', 'Reserve Fund', 'equity', 1);

-- INCOME (4000-4999)
INSERT INTO gl_accounts (sacco_id, code, name, type, is_system) VALUES
(@sacco_id, '4010', 'Interest Income - Loans', 'income', 1),
(@sacco_id, '4020', 'Penalty Income', 'income', 1),
(@sacco_id, '4030', 'Loan Processing Fees', 'income', 1),
(@sacco_id, '4040', 'Membership Fees', 'income', 1),
(@sacco_id, '4050', 'Other Income', 'income', 0);

-- EXPENSES (5000-5999)
INSERT INTO gl_accounts (sacco_id, code, name, type, is_system) VALUES
(@sacco_id, '5010', 'Interest Expense on Deposits', 'expense', 1),
(@sacco_id, '5020', 'Salaries & Wages', 'expense', 0),
(@sacco_id, '5030', 'Rent Expense', 'expense', 0),
(@sacco_id, '5040', 'Office Supplies', 'expense', 0),
(@sacco_id, '5050', 'Utilities', 'expense', 0),
(@sacco_id, '5060', 'Bank Charges', 'expense', 0),
(@sacco_id, '5070', 'Loan Loss Provision', 'expense', 1),
(@sacco_id, '5080', 'Audit & Legal Fees', 'expense', 0),
(@sacco_id, '5090', 'Training & Development', 'expense', 0),
(@sacco_id, '5100', 'Marketing & Promotion', 'expense', 0),
(@sacco_id, '5110', 'Depreciation', 'expense', 0),
(@sacco_id, '5999', 'Miscellaneous Expenses', 'expense', 0);

SELECT 'GL Accounts seeded successfully' AS Status;

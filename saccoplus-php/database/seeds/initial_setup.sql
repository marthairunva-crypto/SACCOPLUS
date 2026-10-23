-- Initial setup: Create first SACCO, branch, and admin user
USE saccoplus_v2;

-- Create MBADIFA SACCO
INSERT INTO saccos (name, code, phone, email, address, currency, status) VALUES
('MBADIFA SACCO', 'MBADIFA', '256700000000', 'info@mbadifa.co.ug', 'Kampala, Uganda', 'UGX', 'active')
ON DUPLICATE KEY UPDATE name=VALUES(name);

SET @sacco_id = LAST_INSERT_ID();
IF @sacco_id = 0 THEN
  SET @sacco_id = (SELECT id FROM saccos WHERE code = 'MBADIFA' LIMIT 1);
END IF;

-- Create Head Office branch
INSERT INTO branches (sacco_id, name, code, is_head_office, status) VALUES
(@sacco_id, 'Head Office', 'HQ', 1, 'active')
ON DUPLICATE KEY UPDATE name=VALUES(name);

SET @branch_id = LAST_INSERT_ID();
IF @branch_id = 0 THEN
  SET @branch_id = (SELECT id FROM branches WHERE sacco_id = @sacco_id AND code = 'HQ' LIMIT 1);
END IF;

-- Create admin user (password: admin123 - CHANGE IN PRODUCTION!)
-- Password hash for 'admin123' using PHP password_hash (bcrypt)
INSERT INTO users (sacco_id, branch_id, name, email, password_hash, role, status) VALUES
(@sacco_id, NULL, 'Admin User', 'admin@mbadifa.co.ug', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'sacco_admin', 'active')
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Seed GL accounts for this SACCO
SOURCE seeds/gl_accounts.sql;

SELECT 
  'Setup complete!' AS Status,
  @sacco_id AS SACCO_ID,
  @branch_id AS Branch_ID,
  'Login: admin@mbadifa.co.ug / admin123 (CHANGE THIS!)' AS Credentials;

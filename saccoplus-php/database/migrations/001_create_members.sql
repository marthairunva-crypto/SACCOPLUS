-- Members table (imported from Firestore saccoplus-members collection)
USE saccoplus_v2;

CREATE TABLE IF NOT EXISTS members (
  id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id           INT UNSIGNED NOT NULL,
  legacy_id          VARCHAR(100) NOT NULL UNIQUE COMMENT 'Firestore document ID',
  account_number     VARCHAR(50) NOT NULL,
  membership_number  VARCHAR(50) NULL,
  
  -- Personal info
  full_name          VARCHAR(150) NOT NULL,
  phone              VARCHAR(20) NULL,
  email              VARCHAR(190) NULL,
  gender             ENUM('Male','Female','Other') NULL,
  date_of_birth      DATE NULL,
  
  -- Financial balances (cached, recalculated from ledger)
  savings_balance    BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX whole shillings',
  shares_balance     BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX whole shillings',
  
  -- Status
  status             ENUM('active','inactive','suspended') NOT NULL DEFAULT 'active',
  
  -- KYC / Address
  district           VARCHAR(100) NULL,
  village            VARCHAR(100) NULL,
  
  -- Timestamps
  joined_date        DATE NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_members_sacco FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  INDEX idx_account_number (sacco_id, account_number),
  INDEX idx_phone (phone),
  INDEX idx_status (status),
  INDEX idx_name (full_name)
) ENGINE=InnoDB;

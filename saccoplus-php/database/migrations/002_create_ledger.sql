-- Ledger/transactions table (append-only, source of truth for all money movements)
USE saccoplus_v2;

CREATE TABLE IF NOT EXISTS ledger (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sacco_id       INT UNSIGNED NOT NULL,
  member_id      INT UNSIGNED NOT NULL,
  
  -- Transaction details
  type           VARCHAR(50) NOT NULL COMMENT 'deposit, withdrawal, loan_disbursement, loan_repayment, etc',
  description    VARCHAR(255) NOT NULL,
  
  -- Money breakdown (UGX whole shillings)
  debit          BIGINT NOT NULL DEFAULT 0 COMMENT 'Money out',
  credit         BIGINT NOT NULL DEFAULT 0 COMMENT 'Money in',
  
  -- Related entities
  loan_id        INT UNSIGNED NULL,
  reference_no   VARCHAR(100) NULL,
  
  -- Who recorded it
  recorded_by    INT UNSIGNED NULL,
  transaction_date DATE NOT NULL,
  
  -- Timestamps
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_ledger_sacco FOREIGN KEY (sacco_id) REFERENCES saccos(id),
  CONSTRAINT fk_ledger_member FOREIGN KEY (member_id) REFERENCES members(id),
  CONSTRAINT fk_ledger_user FOREIGN KEY (recorded_by) REFERENCES users(id),
  INDEX idx_member_date (member_id, transaction_date),
  INDEX idx_type (type),
  INDEX idx_transaction_date (transaction_date)
) ENGINE=InnoDB;

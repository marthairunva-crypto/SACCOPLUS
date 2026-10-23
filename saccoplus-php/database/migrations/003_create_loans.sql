-- Loans table
CREATE TABLE IF NOT EXISTS loans (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    loan_number VARCHAR(50) UNIQUE NOT NULL,
    member_id BIGINT UNSIGNED NOT NULL,
    
    -- Loan details
    loan_type ENUM('emergency', 'development', 'school_fees', 'agriculture', 'business', 'other') NOT NULL,
    purpose TEXT,
    amount_requested BIGINT NOT NULL COMMENT 'UGX',
    amount_approved BIGINT NOT NULL COMMENT 'UGX',
    amount_disbursed BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    
    -- Terms
    interest_rate DECIMAL(5,2) NOT NULL COMMENT 'Annual %',
    term_months INT NOT NULL,
    repayment_frequency ENUM('monthly', 'weekly', 'daily') NOT NULL DEFAULT 'monthly',
    
    -- Balances
    principal_balance BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    interest_balance BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    penalties_balance BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    total_paid BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    
    -- Status
    status ENUM('pending', 'approved', 'rejected', 'disbursed', 'active', 'closed', 'written_off') NOT NULL DEFAULT 'pending',
    
    -- Dates
    application_date DATE NOT NULL,
    approval_date DATE NULL,
    disbursement_date DATE NULL,
    first_payment_date DATE NULL,
    maturity_date DATE NULL,
    closed_date DATE NULL,
    
    -- Migrated loans (from old system)
    is_migrated BOOLEAN DEFAULT FALSE,
    opening_balance BIGINT NULL COMMENT 'UGX - balance when imported',
    opening_date DATE NULL COMMENT 'Date balance was imported',
    legacy_id VARCHAR(100) UNIQUE NULL COMMENT 'Firestore document ID',
    
    -- Guarantors & collateral
    guarantor_1_id BIGINT UNSIGNED NULL,
    guarantor_1_amount BIGINT NULL COMMENT 'UGX',
    guarantor_2_id BIGINT UNSIGNED NULL,
    guarantor_2_amount BIGINT NULL COMMENT 'UGX',
    collateral_type VARCHAR(100) NULL,
    collateral_value BIGINT NULL COMMENT 'UGX',
    collateral_description TEXT NULL,
    
    -- Workflow
    applied_by BIGINT UNSIGNED NOT NULL COMMENT 'User who created application',
    approved_by BIGINT UNSIGNED NULL,
    disbursed_by BIGINT UNSIGNED NULL,
    approval_notes TEXT NULL,
    rejection_reason TEXT NULL,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (member_id) REFERENCES members(id),
    FOREIGN KEY (guarantor_1_id) REFERENCES members(id),
    FOREIGN KEY (guarantor_2_id) REFERENCES members(id),
    
    INDEX idx_member (member_id),
    INDEX idx_status (status),
    INDEX idx_loan_number (loan_number),
    INDEX idx_legacy (legacy_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Loan repayment schedule
CREATE TABLE IF NOT EXISTS loan_schedules (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT UNSIGNED NOT NULL,
    
    installment_number INT NOT NULL,
    due_date DATE NOT NULL,
    
    -- Amounts due
    principal_due BIGINT NOT NULL COMMENT 'UGX',
    interest_due BIGINT NOT NULL COMMENT 'UGX',
    total_due BIGINT NOT NULL COMMENT 'UGX',
    
    -- Amounts paid
    principal_paid BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    interest_paid BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    total_paid BIGINT NOT NULL DEFAULT 0 COMMENT 'UGX',
    
    -- Status
    status ENUM('pending', 'partial', 'paid', 'overdue') NOT NULL DEFAULT 'pending',
    paid_date DATE NULL,
    days_overdue INT NOT NULL DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
    
    INDEX idx_loan (loan_id),
    INDEX idx_due_date (due_date),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Loan charges (penalties, fees - MANUAL ONLY)
CREATE TABLE IF NOT EXISTS loan_charges (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT UNSIGNED NOT NULL,
    member_id BIGINT UNSIGNED NOT NULL,
    
    charge_type ENUM('late_payment_fee', 'processing_fee', 'insurance', 'appraisal_fee', 'other') NOT NULL,
    amount BIGINT NOT NULL COMMENT 'UGX',
    reason TEXT NOT NULL,
    
    -- Status
    status ENUM('pending', 'applied', 'waived') NOT NULL DEFAULT 'applied',
    
    -- Who & when
    added_by BIGINT UNSIGNED NOT NULL COMMENT 'User who added charge',
    waived_by BIGINT UNSIGNED NULL,
    waiver_reason TEXT NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    waived_at TIMESTAMP NULL,
    
    FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
    FOREIGN KEY (member_id) REFERENCES members(id),
    
    INDEX idx_loan (loan_id),
    INDEX idx_member (member_id),
    INDEX idx_type (charge_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Loan comments/notes
CREATE TABLE IF NOT EXISTS loan_notes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    loan_id BIGINT UNSIGNED NOT NULL,
    
    note TEXT NOT NULL,
    note_type ENUM('general', 'collection', 'approval', 'disbursement', 'correction') NOT NULL DEFAULT 'general',
    
    created_by BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (loan_id) REFERENCES loans(id) ON DELETE CASCADE,
    
    INDEX idx_loan (loan_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

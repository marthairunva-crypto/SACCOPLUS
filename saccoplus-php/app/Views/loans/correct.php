<?php $title = "Correct Loan Data - " . $loan['loan_number']; ?>

<div class="page-header">
    <h1>Correct Loan Data</h1>
    <span class="badge badge-danger" style="font-size: 14px;">Admin Only</span>
</div>

<div class="alert alert-danger">
    <strong>⚠ WARNING:</strong> This screen allows correction of loan data for migrated or erroneous loans. 
    All changes are fully audit logged. Use with caution.
</div>

<!-- Current Loan Data -->
<div class="card">
    <h3>Current Loan Data: <?= htmlspecialchars($loan['loan_number']) ?></h3>
    
    <div class="info-grid">
        <div>
            <strong>Member:</strong>
            <span><?= htmlspecialchars($loan['member_name']) ?> (<?= htmlspecialchars($loan['account_number']) ?>)</span>
        </div>
        <div>
            <strong>Loan Type:</strong>
            <span><?= ucwords(str_replace('_', ' ', $loan['loan_type'])) ?></span>
        </div>
        <div>
            <strong>Status:</strong>
            <span><?= ucfirst($loan['status']) ?></span>
        </div>
    </div>
    
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-top: 20px;">
        <div class="summary-card">
            <div class="label">Principal Balance</div>
            <div class="value">UGX <?= number_format($loan['principal_balance']) ?></div>
        </div>
        <div class="summary-card">
            <div class="label">Interest Balance</div>
            <div class="value">UGX <?= number_format($loan['interest_balance']) ?></div>
        </div>
        <div class="summary-card">
            <div class="label">Penalties Balance</div>
            <div class="value">UGX <?= number_format($loan['penalties_balance']) ?></div>
        </div>
        <div class="summary-card">
            <div class="label">Amount Approved</div>
            <div class="value">UGX <?= number_format($loan['amount_approved']) ?></div>
        </div>
        <div class="summary-card">
            <div class="label">Interest Rate</div>
            <div class="value"><?= $loan['interest_rate'] ?>%</div>
        </div>
        <div class="summary-card">
            <div class="label">Term</div>
            <div class="value"><?= $loan['term_months'] ?> months</div>
        </div>
    </div>
    
    <?php if ($loan['is_migrated']): ?>
        <div style="margin-top: 15px; padding: 12px; background: #fef3c7; border-left: 3px solid #f59e0b; border-radius: 4px;">
            <strong>Migrated Loan</strong><br>
            Opening Balance: UGX <?= number_format($loan['opening_balance']) ?><br>
            Opening Date: <?= $loan['opening_date'] ? date('d M Y', strtotime($loan['opening_date'])) : 'Not set' ?>
        </div>
    <?php endif; ?>
</div>

<!-- Correction Form -->
<form method="POST" action="<?= url('/loans/store-correction') ?>">
    <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
    <input type="hidden" name="loan_id" value="<?= $loan['id'] ?>">
    
    <div class="card">
        <h3>Correct Balances</h3>
        
        <div class="form-row">
            <div class="form-group">
                <label>Principal Balance (UGX)</label>
                <input type="number" name="principal_balance" min="0" step="1000" 
                       value="<?= $loan['principal_balance'] ?>"
                       placeholder="Leave empty to keep current">
            </div>
            
            <div class="form-group">
                <label>Interest Balance (UGX)</label>
                <input type="number" name="interest_balance" min="0" step="1000" 
                       value="<?= $loan['interest_balance'] ?>"
                       placeholder="Leave empty to keep current">
            </div>
        </div>
        
        <div class="form-row">
            <div class="form-group">
                <label>Penalties Balance (UGX)</label>
                <input type="number" name="penalties_balance" min="0" step="1000" 
                       value="<?= $loan['penalties_balance'] ?>"
                       placeholder="Leave empty to keep current">
            </div>
            
            <div class="form-group">
                <label>Amount Approved (UGX)</label>
                <input type="number" name="amount_approved" min="0" step="1000" 
                       value="<?= $loan['amount_approved'] ?>"
                       placeholder="Leave empty to keep current">
            </div>
        </div>
    </div>
    
    <div class="card">
        <h3>Correct Terms</h3>
        
        <div class="form-row">
            <div class="form-group">
                <label>Interest Rate (% per year)</label>
                <input type="number" name="interest_rate" min="0" max="50" step="0.1" 
                       value="<?= $loan['interest_rate'] ?>"
                       placeholder="Leave empty to keep current">
            </div>
            
            <div class="form-group">
                <label>Term (Months)</label>
                <input type="number" name="term_months" min="1" max="60" 
                       value="<?= $loan['term_months'] ?>"
                       placeholder="Leave empty to keep current">
            </div>
        </div>
    </div>
    
    <div class="card">
        <h3>Migrated Loan Settings</h3>
        
        <div class="form-group">
            <label style="display: flex; align-items: center; gap: 10px;">
                <input type="checkbox" name="is_migrated" value="1" 
                       <?= $loan['is_migrated'] ? 'checked' : '' ?>>
                <span>This is a migrated loan (imported from old system)</span>
            </label>
        </div>
        
        <div class="form-row">
            <div class="form-group">
                <label>Opening Balance (UGX)</label>
                <input type="number" name="opening_balance" min="0" step="1000" 
                       value="<?= $loan['opening_balance'] ?? '' ?>"
                       placeholder="Balance when imported">
                <small>Set this for migrated loans without full history</small>
            </div>
            
            <div class="form-group">
                <label>Opening Date</label>
                <input type="date" name="opening_date" 
                       value="<?= $loan['opening_date'] ?? '' ?>"
                       placeholder="Date when imported">
                <small>Used to calculate arrears correctly</small>
            </div>
        </div>
        
        <div style="padding: 15px; background: #fef3c7; border-left: 3px solid #f59e0b; border-radius: 4px;">
            <strong>Why set opening balance/date?</strong><br>
            For loans migrated from the old system, we don't have the full repayment history. 
            Setting the opening balance and date allows arrears calculations to start from the import date 
            rather than assuming a full schedule of missed payments.
        </div>
    </div>
    
    <div class="card">
        <h3>Correction Reason *</h3>
        
        <div class="form-group">
            <label>Explain why these corrections are being made *</label>
            <textarea name="reason" rows="4" required 
                      placeholder="e.g., Correcting migrated loan balances, fixing data entry error, adjusting for manual payment..."><?= old('reason') ?></textarea>
            <small>This will be permanently logged in the audit trail</small>
        </div>
    </div>
    
    <div class="form-actions">
        <button type="submit" class="btn btn-danger">Save Corrections</button>
        <a href="<?= url('/loans/view?id=' . $loan['id']) ?>" class="btn">Cancel</a>
    </div>
</form>

<style>
.alert-danger {
    padding: 15px;
    background: #fee;
    border-left: 4px solid #dc2626;
    border-radius: 4px;
    margin-bottom: 20px;
}
</style>

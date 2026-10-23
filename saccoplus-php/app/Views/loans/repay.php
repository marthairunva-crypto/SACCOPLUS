<?php $title = "Record Loan Repayment"; ?>

<div class="page-header">
    <h1>Record Loan Repayment</h1>
</div>

<!-- Loan Summary -->
<div class="card">
    <h3>Loan: <?= htmlspecialchars($loan['loan_number']) ?></h3>
    
    <div class="info-grid">
        <div>
            <strong>Member:</strong>
            <span><?= htmlspecialchars($loan['member_name']) ?></span>
        </div>
        <div>
            <strong>Account:</strong>
            <span><?= htmlspecialchars($loan['account_number']) ?></span>
        </div>
        <div>
            <strong>Phone:</strong>
            <span><?= htmlspecialchars($loan['phone']) ?></span>
        </div>
    </div>
    
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-top: 20px;">
        <div class="summary-card">
            <div class="label">Principal Balance</div>
            <div class="value">UGX <?= number_format($loan['principal_balance']) ?></div>
        </div>
        <div class="summary-card">
            <div class="label">Interest Balance</div>
            <div class="value">UGX <?= number_format($loan['interest_balance']) ?></div>
        </div>
        <?php if ($loan['penalties_balance'] > 0): ?>
        <div class="summary-card" style="border-left: 3px solid #dc2626;">
            <div class="label">Penalties</div>
            <div class="value" style="color: #dc2626;">UGX <?= number_format($loan['penalties_balance']) ?></div>
        </div>
        <?php endif; ?>
        <div class="summary-card" style="border-left: 3px solid #0284c7;">
            <div class="label">Total Outstanding</div>
            <div class="value" style="color: #0284c7;">UGX <?= number_format($loan['total_balance']) ?></div>
        </div>
    </div>
    
    <?php if (!$loan_status['is_current'] && $loan_status['days_overdue'] > 0): ?>
        <div style="margin-top: 15px; padding: 12px; background: #fee; border-left: 3px solid #dc2626; border-radius: 4px;">
            <strong>⚠ Overdue:</strong> <?= $loan_status['days_overdue'] ?> day(s)<br>
            <strong>Arrears:</strong> UGX <?= number_format($loan_status['arrears_amount']) ?>
        </div>
    <?php endif; ?>
    
    <?php if ($loan_status['next_payment_date']): ?>
        <div style="margin-top: 15px; padding: 12px; background: #f0f9ff; border-left: 3px solid #0284c7; border-radius: 4px;">
            <strong>Next Payment Due:</strong> <?= date('d M Y', strtotime($loan_status['next_payment_date'])) ?><br>
            <strong>Amount:</strong> UGX <?= number_format($loan_status['next_payment_amount']) ?>
        </div>
    <?php endif; ?>
</div>

<!-- Payment Form -->
<form method="POST" action="<?= url('/loans/repay') ?>">
    <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
    <input type="hidden" name="loan_id" value="<?= $loan['id'] ?>">
    
    <div class="card">
        <h3>Payment Details</h3>
        
        <div class="form-row">
            <div class="form-group">
                <label>Payment Amount (UGX) *</label>
                <input type="number" name="amount" min="1000" step="1000" 
                       value="<?= old('amount', $loan_status['next_payment_amount'] ?? '') ?>" 
                       required autofocus>
                <small>Minimum: UGX 1,000. Applied in order: Penalties → Interest → Principal</small>
            </div>
            
            <div class="form-group">
                <label>Payment Date *</label>
                <input type="date" name="payment_date" 
                       max="<?= date('Y-m-d') ?>" 
                       min="<?= date('Y-m-d', strtotime('-48 hours')) ?>"
                       value="<?= old('payment_date', date('Y-m-d')) ?>" required>
                <small>Can backdate up to 48 hours</small>
            </div>
        </div>
        
        <div class="form-group">
            <label>Notes (Optional)</label>
            <textarea name="notes" rows="3" placeholder="Additional notes about this payment..."><?= old('notes') ?></textarea>
        </div>
        
        <div style="padding: 15px; background: #fef3c7; border-left: 3px solid #f59e0b; border-radius: 4px; margin: 15px 0;">
            <strong>⚠ Payment Source:</strong><br>
            Payment will be deducted from member's savings account. Current savings balance should be sufficient.
        </div>
    </div>
    
    <div class="form-actions">
        <button type="submit" class="btn btn-primary">Record Payment</button>
        <a href="<?= url('/loans/view?id=' . $loan['id']) ?>" class="btn">Cancel</a>
    </div>
</form>

<script>
// Calculate payment breakdown preview
const amountInput = document.querySelector('input[name="amount"]');
amountInput.addEventListener('input', function() {
    const amount = parseInt(this.value) || 0;
    const penalties = <?= $loan['penalties_balance'] ?>;
    const interest = <?= $loan['interest_balance'] ?>;
    const principal = <?= $loan['principal_balance'] ?>;
    
    let remaining = amount;
    let penaltiesPaid = Math.min(remaining, penalties);
    remaining -= penaltiesPaid;
    
    let interestPaid = Math.min(remaining, interest);
    remaining -= interestPaid;
    
    let principalPaid = Math.min(remaining, principal);
    
    console.log('Payment Breakdown:', {
        penalties: penaltiesPaid,
        interest: interestPaid,
        principal: principalPaid
    });
});
</script>

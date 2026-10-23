<?php $title = "Loan Details - " . $loan['loan_number']; ?>

<div class="page-header">
    <div>
        <h1>Loan <?= htmlspecialchars($loan['loan_number']) ?></h1>
        <p style="margin: 5px 0 0 0; color: #666;">
            <?= htmlspecialchars($loan['member_name']) ?> - <?= htmlspecialchars($loan['account_number']) ?>
        </p>
    </div>
    <div>
        <span class="badge badge-<?= 
            $loan['status'] === 'active' || $loan['status'] === 'disbursed' ? 'success' : 
            ($loan['status'] === 'pending' ? 'warning' : 
            ($loan['status'] === 'approved' ? 'info' : 
            ($loan['status'] === 'closed' ? 'secondary' : 'danger'))) 
        ?>" style="font-size: 16px; padding: 8px 16px;">
            <?= ucfirst($loan['status']) ?>
        </span>
    </div>
</div>

<!-- Tabs -->
<div class="tabs">
    <a href="<?= url('/loans/view?id=' . $loan['id'] . '&tab=summary') ?>" 
       class="<?= $tab === 'summary' ? 'active' : '' ?>">Summary</a>
    <a href="<?= url('/loans/view?id=' . $loan['id'] . '&tab=schedule') ?>" 
       class="<?= $tab === 'schedule' ? 'active' : '' ?>">Repayment Schedule</a>
    <a href="<?= url('/loans/view?id=' . $loan['id'] . '&tab=card') ?>" 
       class="<?= $tab === 'card' ? 'active' : '' ?>">Loan Card</a>
</div>

<?php if ($tab === 'summary'): ?>
    <!-- Summary Tab -->
    
    <!-- Status Alert for Arrears -->
    <?php if (!$loan_status['is_current'] && $loan_status['days_overdue'] > 0): ?>
        <div class="alert alert-danger">
            <strong>⚠ Loan Overdue!</strong> 
            This loan is <?= $loan_status['days_overdue'] ?> day(s) overdue. 
            Arrears: UGX <?= number_format($loan_status['arrears_amount']) ?>
        </div>
    <?php endif; ?>
    
    <!-- Quick Actions -->
    <?php if ($loan['status'] === 'pending'): ?>
        <div class="card">
            <h3>Pending Approval</h3>
            <div style="display: flex; gap: 15px;">
                <button onclick="showApprovalForm()" class="btn btn-success">Approve Loan</button>
                <button onclick="showRejectionForm()" class="btn btn-danger">Reject Loan</button>
            </div>
        </div>
    <?php elseif ($loan['status'] === 'approved'): ?>
        <div class="card">
            <h3>Ready to Disburse</h3>
            <button onclick="showDisbursementForm()" class="btn btn-primary">Disburse Loan</button>
        </div>
    <?php elseif (in_array($loan['status'], ['active', 'disbursed'])): ?>
        <div class="card">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3>Active Loan</h3>
                <div style="display: flex; gap: 10px;">
                    <a href="<?= url('/loans/repay?loan_id=' . $loan['id']) ?>" class="btn btn-primary">Record Payment</a>
                    <button onclick="showAddChargeForm()" class="btn">Add Charge</button>
                </div>
            </div>
        </div>
    <?php endif; ?>
    
    <!-- Balance Cards -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px;">
        <div class="summary-card">
            <div class="label">Approved Amount</div>
            <div class="value">UGX <?= number_format($loan['amount_approved']) ?></div>
        </div>
        
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
        
        <div class="summary-card" style="border-left: 3px solid #059669;">
            <div class="label">Total Paid</div>
            <div class="value" style="color: #059669;">UGX <?= number_format($loan['total_paid']) ?></div>
        </div>
        
        <div class="summary-card" style="border-left: 3px solid #0284c7;">
            <div class="label">Total Outstanding</div>
            <div class="value" style="color: #0284c7;">UGX <?= number_format($loan['total_balance']) ?></div>
        </div>
    </div>
    
    <!-- Loan Information -->
    <div class="card">
        <h3>Loan Information</h3>
        <div class="info-grid">
            <div>
                <strong>Loan Type:</strong>
                <span><?= ucwords(str_replace('_', ' ', $loan['loan_type'])) ?></span>
            </div>
            <div>
                <strong>Interest Rate:</strong>
                <span><?= $loan['interest_rate'] ?>% per year</span>
            </div>
            <div>
                <strong>Term:</strong>
                <span><?= $loan['term_months'] ?> months</span>
            </div>
            <div>
                <strong>Repayment Frequency:</strong>
                <span><?= ucfirst($loan['repayment_frequency']) ?></span>
            </div>
            <div>
                <strong>Application Date:</strong>
                <span><?= date('d M Y', strtotime($loan['application_date'])) ?></span>
            </div>
            <?php if ($loan['approval_date']): ?>
            <div>
                <strong>Approval Date:</strong>
                <span><?= date('d M Y', strtotime($loan['approval_date'])) ?></span>
            </div>
            <?php endif; ?>
            <?php if ($loan['disbursement_date']): ?>
            <div>
                <strong>Disbursement Date:</strong>
                <span><?= date('d M Y', strtotime($loan['disbursement_date'])) ?></span>
            </div>
            <?php endif; ?>
            <?php if ($loan['maturity_date']): ?>
            <div>
                <strong>Maturity Date:</strong>
                <span><?= date('d M Y', strtotime($loan['maturity_date'])) ?></span>
            </div>
            <?php endif; ?>
            <?php if ($loan_status['next_payment_date']): ?>
            <div>
                <strong>Next Payment Due:</strong>
                <span><?= date('d M Y', strtotime($loan_status['next_payment_date'])) ?> 
                      (UGX <?= number_format($loan_status['next_payment_amount']) ?>)</span>
            </div>
            <?php endif; ?>
        </div>
        
        <?php if ($loan['purpose']): ?>
            <div style="margin-top: 15px;">
                <strong>Purpose:</strong>
                <p style="margin: 5px 0 0 0;"><?= nl2br(htmlspecialchars($loan['purpose'])) ?></p>
            </div>
        <?php endif; ?>
        
        <?php if ($loan['is_migrated']): ?>
            <div style="margin-top: 15px; padding: 10px; background: #fef3c7; border-left: 3px solid #f59e0b; border-radius: 4px;">
                <strong>⚠ Migrated Loan</strong><br>
                Opening Balance: UGX <?= number_format($loan['opening_balance']) ?><br>
                Opening Date: <?= date('d M Y', strtotime($loan['opening_date'])) ?><br>
                <small>This loan was imported from the old system. Historical repayments are not available.</small>
            </div>
        <?php endif; ?>
    </div>
    
    <!-- Guarantors & Collateral -->
    <?php if ($loan['guarantor_1_id'] || $loan['collateral_type']): ?>
    <div class="card">
        <h3>Security</h3>
        
        <?php if ($loan['guarantor_1_id']): ?>
            <div style="margin-bottom: 15px;">
                <strong>Guarantor 1:</strong> <?= htmlspecialchars($loan['guarantor_1_name']) ?> 
                (UGX <?= number_format($loan['guarantor_1_amount']) ?>)<br>
                <small><?= htmlspecialchars($loan['guarantor_1_phone']) ?></small>
            </div>
        <?php endif; ?>
        
        <?php if ($loan['guarantor_2_id']): ?>
            <div style="margin-bottom: 15px;">
                <strong>Guarantor 2:</strong> <?= htmlspecialchars($loan['guarantor_2_name']) ?> 
                (UGX <?= number_format($loan['guarantor_2_amount']) ?>)<br>
                <small><?= htmlspecialchars($loan['guarantor_2_phone']) ?></small>
            </div>
        <?php endif; ?>
        
        <?php if ($loan['collateral_type']): ?>
            <div>
                <strong>Collateral:</strong> <?= htmlspecialchars($loan['collateral_type']) ?> 
                (Value: UGX <?= number_format($loan['collateral_value']) ?>)<br>
                <?php if ($loan['collateral_description']): ?>
                    <p style="margin: 5px 0 0 0; color: #666;">
                        <?= nl2br(htmlspecialchars($loan['collateral_description'])) ?>
                    </p>
                <?php endif; ?>
            </div>
        <?php endif; ?>
    </div>
    <?php endif; ?>
    
    <!-- Admin Actions -->
    <?php if (hasRole(['admin'])): ?>
    <div class="card">
        <h3>Admin Actions</h3>
        <a href="<?= url('/loans/correct?loan_id=' . $loan['id']) ?>" class="btn">Correct Loan Data</a>
    </div>
    <?php endif; ?>

<?php elseif ($tab === 'schedule'): ?>
    <!-- Schedule Tab -->
    <div class="card">
        <h3>Repayment Schedule</h3>
        
        <?php if (empty($schedule)): ?>
            <p style="color: #666; text-align: center; padding: 20px 0;">
                No repayment schedule available. Schedule is generated when loan is disbursed.
            </p>
        <?php else: ?>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Due Date</th>
                        <th>Principal Due</th>
                        <th>Interest Due</th>
                        <th>Total Due</th>
                        <th>Paid</th>
                        <th>Balance</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($schedule as $inst): ?>
                        <tr class="<?= $inst['status'] === 'overdue' ? 'row-danger' : '' ?>">
                            <td><?= $inst['installment_number'] ?></td>
                            <td><?= date('d M Y', strtotime($inst['due_date'])) ?></td>
                            <td>UGX <?= number_format($inst['principal_due']) ?></td>
                            <td>UGX <?= number_format($inst['interest_due']) ?></td>
                            <td><strong>UGX <?= number_format($inst['total_due']) ?></strong></td>
                            <td>UGX <?= number_format($inst['total_paid']) ?></td>
                            <td>UGX <?= number_format($inst['total_due'] - $inst['total_paid']) ?></td>
                            <td>
                                <span class="badge badge-<?= 
                                    $inst['status'] === 'paid' ? 'success' : 
                                    ($inst['status'] === 'partial' ? 'warning' : 
                                    ($inst['status'] === 'overdue' ? 'danger' : 'secondary')) 
                                ?>">
                                    <?= ucfirst($inst['status']) ?>
                                </span>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
                <tfoot>
                    <tr style="font-weight: bold; background: #f9fafb;">
                        <td colspan="2">TOTAL</td>
                        <td>UGX <?= number_format(array_sum(array_column($schedule, 'principal_due'))) ?></td>
                        <td>UGX <?= number_format(array_sum(array_column($schedule, 'interest_due'))) ?></td>
                        <td>UGX <?= number_format(array_sum(array_column($schedule, 'total_due'))) ?></td>
                        <td>UGX <?= number_format(array_sum(array_column($schedule, 'total_paid'))) ?></td>
                        <td colspan="2"></td>
                    </tr>
                </tfoot>
            </table>
        <?php endif; ?>
    </div>

<?php elseif ($tab === 'card'): ?>
    <!-- Loan Card Tab -->
    
    <!-- Charges/Penalties -->
    <div class="card">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
            <h3>Charges & Penalties</h3>
            <?php if (hasRole(['admin', 'manager'])): ?>
                <button onclick="showAddChargeForm()" class="btn btn-sm">+ Add Charge</button>
            <?php endif; ?>
        </div>
        
        <?php if (empty($charges)): ?>
            <p style="color: #666; text-align: center; padding: 20px 0;">No charges or penalties applied.</p>
        <?php else: ?>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Date</th>
                        <th>Type</th>
                        <th>Amount</th>
                        <th>Reason</th>
                        <th>Added By</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($charges as $charge): ?>
                        <tr>
                            <td><?= date('d M Y', strtotime($charge['created_at'])) ?></td>
                            <td><?= ucwords(str_replace('_', ' ', $charge['charge_type'])) ?></td>
                            <td>UGX <?= number_format($charge['amount']) ?></td>
                            <td><?= htmlspecialchars($charge['reason']) ?></td>
                            <td><?= htmlspecialchars($charge['added_by_name']) ?></td>
                            <td>
                                <span class="badge badge-<?= $charge['status'] === 'applied' ? 'success' : 'secondary' ?>">
                                    <?= ucfirst($charge['status']) ?>
                                </span>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
    
    <!-- Notes -->
    <div class="card">
        <h3>Notes & Activity Log</h3>
        
        <?php if (empty($notes)): ?>
            <p style="color: #666; text-align: center; padding: 20px 0;">No notes or activity logged.</p>
        <?php else: ?>
            <div style="display: flex; flex-direction: column; gap: 10px;">
                <?php foreach ($notes as $note): ?>
                    <div style="padding: 12px; background: #f9fafb; border-left: 3px solid #0284c7; border-radius: 4px;">
                        <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                            <strong><?= htmlspecialchars($note['created_by_name']) ?></strong>
                            <small style="color: #666;"><?= date('d M Y H:i', strtotime($note['created_at'])) ?></small>
                        </div>
                        <p style="margin: 0;"><?= nl2br(htmlspecialchars($note['note'])) ?></p>
                    </div>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </div>
<?php endif; ?>

<!-- Approval Form Modal (hidden) -->
<div id="approval-form" style="display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; padding: 20px; overflow: auto;">
    <div style="max-width: 500px; margin: 50px auto; background: white; padding: 30px; border-radius: 8px;">
        <h3>Approve Loan</h3>
        <form method="POST" action="<?= url('/loans/approve') ?>">
            <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
            <input type="hidden" name="loan_id" value="<?= $loan['id'] ?>">
            
            <div class="form-group">
                <label>Approved Amount (UGX) *</label>
                <input type="number" name="approved_amount" min="10000" step="1000" 
                       value="<?= $loan['amount_requested'] ?>" required>
            </div>
            
            <div class="form-group">
                <label>Approval Notes</label>
                <textarea name="notes" rows="3"></textarea>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-success">Approve</button>
                <button type="button" onclick="hideForm('approval-form')" class="btn">Cancel</button>
            </div>
        </form>
    </div>
</div>

<!-- Rejection Form Modal (hidden) -->
<div id="rejection-form" style="display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; padding: 20px; overflow: auto;">
    <div style="max-width: 500px; margin: 50px auto; background: white; padding: 30px; border-radius: 8px;">
        <h3>Reject Loan</h3>
        <form method="POST" action="<?= url('/loans/reject') ?>">
            <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
            <input type="hidden" name="loan_id" value="<?= $loan['id'] ?>">
            
            <div class="form-group">
                <label>Rejection Reason *</label>
                <textarea name="reason" rows="4" required></textarea>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-danger">Reject</button>
                <button type="button" onclick="hideForm('rejection-form')" class="btn">Cancel</button>
            </div>
        </form>
    </div>
</div>

<!-- Disbursement Form Modal (hidden) -->
<div id="disbursement-form" style="display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; padding: 20px; overflow: auto;">
    <div style="max-width: 500px; margin: 50px auto; background: white; padding: 30px; border-radius: 8px;">
        <h3>Disburse Loan</h3>
        <form method="POST" action="<?= url('/loans/disburse') ?>">
            <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
            <input type="hidden" name="loan_id" value="<?= $loan['id'] ?>">
            
            <div class="form-group">
                <label>Disbursement Date *</label>
                <input type="date" name="disbursement_date" 
                       max="<?= date('Y-m-d') ?>" 
                       min="<?= date('Y-m-d', strtotime('-7 days')) ?>"
                       value="<?= date('Y-m-d') ?>" required>
                <small>Can backdate up to 7 days</small>
            </div>
            
            <div style="padding: 15px; background: #f0f9ff; border-left: 3px solid #0284c7; margin: 15px 0;">
                <strong>Amount to disburse:</strong> UGX <?= number_format($loan['amount_approved']) ?><br>
                <small>This will credit the member's savings account and create a repayment schedule.</small>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Disburse Now</button>
                <button type="button" onclick="hideForm('disbursement-form')" class="btn">Cancel</button>
            </div>
        </form>
    </div>
</div>

<!-- Add Charge Form Modal (hidden) -->
<div id="charge-form" style="display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 1000; padding: 20px; overflow: auto;">
    <div style="max-width: 500px; margin: 50px auto; background: white; padding: 30px; border-radius: 8px;">
        <h3>Add Charge/Penalty</h3>
        <form method="POST" action="<?= url('/loans/add-charge') ?>">
            <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
            <input type="hidden" name="loan_id" value="<?= $loan['id'] ?>">
            
            <div class="form-group">
                <label>Charge Type *</label>
                <select name="charge_type" required>
                    <option value="">Select type...</option>
                    <option value="late_payment_fee">Late Payment Fee</option>
                    <option value="processing_fee">Processing Fee</option>
                    <option value="insurance">Insurance</option>
                    <option value="appraisal_fee">Appraisal Fee</option>
                    <option value="other">Other</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>Amount (UGX) *</label>
                <input type="number" name="amount" min="0" step="1000" required>
            </div>
            
            <div class="form-group">
                <label>Reason *</label>
                <textarea name="reason" rows="3" required placeholder="Explain why this charge is being added..."></textarea>
            </div>
            
            <div style="padding: 15px; background: #fef3c7; border-left: 3px solid #f59e0b; margin: 15px 0;">
                <strong>⚠ Manual Charge</strong><br>
                <small>This charge will be added manually and fully audit logged. It will NOT be applied automatically.</small>
            </div>
            
            <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Charge</button>
                <button type="button" onclick="hideForm('charge-form')" class="btn">Cancel</button>
            </div>
        </form>
    </div>
</div>

<script>
function showApprovalForm() {
    document.getElementById('approval-form').style.display = 'block';
}

function showRejectionForm() {
    document.getElementById('rejection-form').style.display = 'block';
}

function showDisbursementForm() {
    document.getElementById('disbursement-form').style.display = 'block';
}

function showAddChargeForm() {
    document.getElementById('charge-form').style.display = 'block';
}

function hideForm(formId) {
    document.getElementById(formId).style.display = 'none';
}

// Close modals on background click
document.querySelectorAll('[id$="-form"]').forEach(form => {
    form.addEventListener('click', function(e) {
        if (e.target === this) {
            this.style.display = 'none';
        }
    });
});
</script>

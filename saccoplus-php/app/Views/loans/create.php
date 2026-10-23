<?php $title = "New Loan Application"; ?>

<div class="page-header">
    <h1>New Loan Application</h1>
</div>

<form method="POST" action="<?= url('/loans/store') ?>">
    <input type="hidden" name="csrf_token" value="<?= $csrf_token ?>">
    
    <!-- Member Selection -->
    <div class="card">
        <h3>Member Information</h3>
        
        <?php if ($member): ?>
            <input type="hidden" name="member_id" value="<?= $member['id'] ?>">
            <div class="info-grid">
                <div>
                    <strong>Name:</strong>
                    <span><?= htmlspecialchars($member['full_name']) ?></span>
                </div>
                <div>
                    <strong>Account:</strong>
                    <span><?= htmlspecialchars($member['account_number']) ?></span>
                </div>
                <div>
                    <strong>Phone:</strong>
                    <span><?= htmlspecialchars($member['phone']) ?></span>
                </div>
                <div>
                    <strong>Savings Balance:</strong>
                    <span>UGX <?= number_format($member['savings_balance']) ?></span>
                </div>
            </div>
        <?php else: ?>
            <div class="form-group">
                <label>Search Member *</label>
                <input type="text" id="member-search" placeholder="Search by name or account number..." required>
                <input type="hidden" name="member_id" id="member-id" required>
                <div id="member-results" style="margin-top: 10px;"></div>
            </div>
        <?php endif; ?>
    </div>
    
    <!-- Loan Details -->
    <div class="card">
        <h3>Loan Details</h3>
        
        <div class="form-row">
            <div class="form-group">
                <label>Loan Type *</label>
                <select name="loan_type" required>
                    <option value="">Select type...</option>
                    <option value="emergency">Emergency</option>
                    <option value="development">Development</option>
                    <option value="school_fees">School Fees</option>
                    <option value="agriculture">Agriculture</option>
                    <option value="business">Business</option>
                    <option value="other">Other</option>
                </select>
            </div>
            
            <div class="form-group">
                <label>Repayment Frequency *</label>
                <select name="repayment_frequency" required>
                    <option value="monthly" selected>Monthly</option>
                    <option value="weekly">Weekly</option>
                    <option value="daily">Daily</option>
                </select>
            </div>
        </div>
        
        <div class="form-group">
            <label>Purpose</label>
            <textarea name="purpose" rows="3" placeholder="Purpose of loan..."><?= old('purpose') ?></textarea>
        </div>
        
        <div class="form-row">
            <div class="form-group">
                <label>Amount Requested (UGX) *</label>
                <input type="number" name="amount_requested" min="10000" step="1000" 
                       value="<?= old('amount_requested') ?>" required>
            </div>
            
            <div class="form-group">
                <label>Amount Approved (UGX) *</label>
                <input type="number" name="amount_approved" min="10000" step="1000" 
                       value="<?= old('amount_approved') ?>" required>
            </div>
        </div>
        
        <div class="form-row">
            <div class="form-group">
                <label>Interest Rate (% per year) *</label>
                <input type="number" name="interest_rate" min="0" max="50" step="0.1" 
                       value="<?= old('interest_rate', '12') ?>" required>
            </div>
            
            <div class="form-group">
                <label>Term (Months) *</label>
                <input type="number" name="term_months" min="1" max="60" 
                       value="<?= old('term_months', '12') ?>" required>
            </div>
        </div>
    </div>
    
    <!-- Guarantors -->
    <div class="card">
        <h3>Guarantors (Optional)</h3>
        
        <div class="form-row">
            <div class="form-group">
                <label>Guarantor 1 (Member ID)</label>
                <input type="number" name="guarantor_1_id" value="<?= old('guarantor_1_id') ?>">
            </div>
            
            <div class="form-group">
                <label>Guarantee Amount (UGX)</label>
                <input type="number" name="guarantor_1_amount" min="0" step="1000" 
                       value="<?= old('guarantor_1_amount') ?>">
            </div>
        </div>
        
        <div class="form-row">
            <div class="form-group">
                <label>Guarantor 2 (Member ID)</label>
                <input type="number" name="guarantor_2_id" value="<?= old('guarantor_2_id') ?>">
            </div>
            
            <div class="form-group">
                <label>Guarantee Amount (UGX)</label>
                <input type="number" name="guarantor_2_amount" min="0" step="1000" 
                       value="<?= old('guarantor_2_amount') ?>">
            </div>
        </div>
    </div>
    
    <!-- Collateral -->
    <div class="card">
        <h3>Collateral (Optional)</h3>
        
        <div class="form-row">
            <div class="form-group">
                <label>Collateral Type</label>
                <input type="text" name="collateral_type" placeholder="e.g., Land, Vehicle, Equipment..." 
                       value="<?= old('collateral_type') ?>">
            </div>
            
            <div class="form-group">
                <label>Estimated Value (UGX)</label>
                <input type="number" name="collateral_value" min="0" step="1000" 
                       value="<?= old('collateral_value') ?>">
            </div>
        </div>
        
        <div class="form-group">
            <label>Description</label>
            <textarea name="collateral_description" rows="3" 
                      placeholder="Detailed description of collateral..."><?= old('collateral_description') ?></textarea>
        </div>
    </div>
    
    <div class="form-actions">
        <button type="submit" class="btn btn-primary">Submit Application</button>
        <a href="<?= url('/loans') ?>" class="btn">Cancel</a>
    </div>
</form>

<?php if (!$member): ?>
<script>
// Member search
let searchTimeout;
const memberSearch = document.getElementById('member-search');
const memberResults = document.getElementById('member-results');
const memberIdInput = document.getElementById('member-id');

memberSearch.addEventListener('input', function() {
    clearTimeout(searchTimeout);
    const query = this.value.trim();
    
    if (query.length < 2) {
        memberResults.innerHTML = '';
        return;
    }
    
    searchTimeout = setTimeout(() => {
        fetch(`<?= url('/api/members/search') ?>?q=${encodeURIComponent(query)}`)
            .then(r => r.json())
            .then(data => {
                if (data.members && data.members.length > 0) {
                    memberResults.innerHTML = data.members.map(m => `
                        <div class="member-result" onclick="selectMember(${m.id}, '${m.full_name}', '${m.account_number}')" 
                             style="padding: 10px; border: 1px solid #ddd; margin-bottom: 5px; cursor: pointer; border-radius: 4px;">
                            <strong>${m.full_name}</strong> - ${m.account_number}<br>
                            <small>Balance: UGX ${Number(m.savings_balance).toLocaleString()}</small>
                        </div>
                    `).join('');
                } else {
                    memberResults.innerHTML = '<p style="color: #666;">No members found</p>';
                }
            });
    }, 300);
});

function selectMember(id, name, account) {
    memberIdInput.value = id;
    memberSearch.value = `${name} - ${account}`;
    memberResults.innerHTML = '';
}
</script>
<?php endif; ?>

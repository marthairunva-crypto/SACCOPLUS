<?php
$title = 'Record Withdrawal';
$page = 'teller';
?>

<div class="wrap narrow">
    <div class="page-header">
        <h1>Record Withdrawal</h1>
        <a href="<?= url('teller') ?>" class="btn-secondary">← Back</a>
    </div>

    <div class="card">
        <form method="post" action="<?= url('teller/withdraw') ?>" id="withdrawForm">
            <?= Csrf::field() ?>
            
            <!-- Member Search -->
            <label for="memberSearch">Search Member *</label>
            <input type="text" id="memberSearch" placeholder="Type name, account number, or phone..." autocomplete="off" required>
            <input type="hidden" name="member_id" id="memberId" required>
            <div id="searchResults" class="search-results"></div>
            <div id="selectedMember" class="selected-member"></div>
            
            <!-- Amount -->
            <label for="amount">Amount (UGX) *</label>
            <input type="number" name="amount" id="amount" min="1" step="1" required>
            <p class="help-text" id="balanceCheck"></p>
            
            <!-- Destination -->
            <label for="destination">Destination *</label>
            <select name="destination" id="destination" required>
                <option value="Cash">Cash</option>
                <option value="Mobile Money">Mobile Money</option>
                <option value="Bank Transfer">Bank Transfer</option>
                <option value="Member Account">Transfer to Member Account</option>
            </select>
            
            <!-- Reference Number -->
            <label for="reference_no">Reference Number</label>
            <input type="text" name="reference_no" id="reference_no" placeholder="Optional">
            
            <!-- Transaction Date Override -->
            <label for="transaction_date">Transaction Date *</label>
            <input type="date" name="transaction_date" id="transaction_date" value="<?= date('Y-m-d') ?>" max="<?= date('Y-m-d') ?>" min="<?= date('Y-m-d', strtotime('-48 hours')) ?>" required>
            <p class="help-text">Max 48 hours back for power outage scenarios</p>
            
            <!-- Notes -->
            <label for="notes">Notes / Reason *</label>
            <input type="text" name="notes" id="notes" placeholder="Required for audit trail" required>
            
            <button type="submit" class="btn btn-primary btn-block">Record Withdrawal</button>
        </form>
    </div>
</div>

<style>
.search-results {
    position: absolute;
    background: #fff;
    border: 1px solid var(--line);
    border-radius: 8px;
    max-height: 300px;
    overflow-y: auto;
    display: none;
    z-index: 10;
    width: 100%;
    margin-top: 4px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
.search-result-item {
    padding: 12px;
    cursor: pointer;
    border-bottom: 1px solid var(--line);
}
.search-result-item:hover {
    background: var(--bg);
}
.selected-member {
    padding: 12px;
    background: var(--brand-soft);
    border-radius: 8px;
    margin-top: 8px;
    display: none;
}
.help-text {
    font-size: 0.85rem;
    color: var(--muted);
    margin-top: -8px;
}
.help-text.warning {
    color: var(--danger);
}
select {
    width: 100%;
    padding: 11px 12px;
    border: 1px solid var(--line);
    border-radius: 10px;
    font: inherit;
}
</style>

<script>
let searchTimeout;
let memberBalance = 0;
const searchInput = document.getElementById('memberSearch');
const searchResults = document.getElementById('searchResults');
const memberIdInput = document.getElementById('memberId');
const selectedMemberDiv = document.getElementById('selectedMember');
const amountInput = document.getElementById('amount');
const balanceCheck = document.getElementById('balanceCheck');

searchInput.addEventListener('input', function(e) {
    clearTimeout(searchTimeout);
    const query = e.target.value.trim();
    
    if (query.length < 2) {
        searchResults.style.display = 'none';
        return;
    }
    
    searchTimeout = setTimeout(() => {
        fetch('<?= url('members/search') ?>?q=' + encodeURIComponent(query))
            .then(r => r.json())
            .then(results => {
                if (results.length === 0) {
                    searchResults.innerHTML = '<div class="search-result-item">No members found</div>';
                    searchResults.style.display = 'block';
                    return;
                }
                
                searchResults.innerHTML = results.map(m => `
                    <div class="search-result-item" onclick="selectMember(${m.id}, '${m.full_name}', '${m.account_number}', ${m.savings_balance})">
                        <strong>${m.full_name}</strong><br>
                        <small>Account: ${m.account_number} | Balance: UGX ${Number(m.savings_balance).toLocaleString()}</small>
                    </div>
                `).join('');
                searchResults.style.display = 'block';
            });
    }, 300);
});

function selectMember(id, name, account, balance) {
    memberIdInput.value = id;
    searchInput.value = name;
    searchResults.style.display = 'none';
    memberBalance = balance;
    
    selectedMemberDiv.innerHTML = `
        <strong>${name}</strong><br>
        <small>Account: ${account} | Available Balance: UGX ${Number(balance).toLocaleString()}</small>
    `;
    selectedMemberDiv.style.display = 'block';
    
    // Check amount
    checkAmount();
}

amountInput.addEventListener('input', checkAmount);

function checkAmount() {
    const amount = parseInt(amountInput.value) || 0;
    if (amount > 0 && memberBalance > 0) {
        if (amount > memberBalance) {
            balanceCheck.textContent = `⚠️ Insufficient balance! Available: UGX ${Number(memberBalance).toLocaleString()}`;
            balanceCheck.className = 'help-text warning';
        } else {
            const remaining = memberBalance - amount;
            balanceCheck.textContent = `Balance after withdrawal: UGX ${Number(remaining).toLocaleString()}`;
            balanceCheck.className = 'help-text';
        }
    } else {
        balanceCheck.textContent = '';
    }
}

// Hide results when clicking outside
document.addEventListener('click', function(e) {
    if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
        searchResults.style.display = 'none';
    }
});
</script>

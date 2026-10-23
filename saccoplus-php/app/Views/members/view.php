<?php
$title = $member['full_name'] . ' - Member 360';
$page = 'members';
?>

<div class="page-header">
    <h1>Member 360° View</h1>
    <div class="header-actions">
        <a href="<?= url('members') ?>" class="btn-secondary">← Back to Members</a>
    </div>
</div>

<!-- Personal Information Card -->
<div class="card">
    <div class="card-header">
        <h2>Personal Information</h2>
    </div>
    <div class="info-grid">
        <div class="info-row">
            <span class="label">Full Name</span>
            <span class="value"><?= h($member['full_name']) ?></span>
        </div>
        <div class="info-row">
            <span class="label">Account Number</span>
            <span class="value"><?= h($member['account_number']) ?></span>
        </div>
        <div class="info-row">
            <span class="label">Membership Number</span>
            <span class="value"><?= h($member['membership_number'] ?? 'N/A') ?></span>
        </div>
        <div class="info-row">
            <span class="label">Phone</span>
            <span class="value"><?= h($member['phone'] ?? 'N/A') ?></span>
        </div>
        <div class="info-row">
            <span class="label">Email</span>
            <span class="value"><?= h($member['email'] ?? 'N/A') ?></span>
        </div>
        <div class="info-row">
            <span class="label">Gender</span>
            <span class="value"><?= h($member['gender'] ?? 'N/A') ?></span>
        </div>
        <div class="info-row">
            <span class="label">Date of Birth</span>
            <span class="value"><?= $member['date_of_birth'] ? date('d M Y', strtotime($member['date_of_birth'])) : 'N/A' ?></span>
        </div>
        <div class="info-row">
            <span class="label">Status</span>
            <span class="value">
                <span class="badge badge-<?= $member['status'] ?>">
                    <?= ucfirst($member['status']) ?>
                </span>
            </span>
        </div>
        <div class="info-row">
            <span class="label">District</span>
            <span class="value"><?= h($member['district'] ?? 'N/A') ?></span>
        </div>
        <div class="info-row">
            <span class="label">Village</span>
            <span class="value"><?= h($member['village'] ?? 'N/A') ?></span>
        </div>
        <div class="info-row">
            <span class="label">Joined Date</span>
            <span class="value"><?= $member['joined_date'] ? date('d M Y', strtotime($member['joined_date'])) : 'N/A' ?></span>
        </div>
    </div>
</div>

<!-- Financial Summary Cards -->
<div class="summary-cards">
    <div class="summary-card">
        <div class="summary-icon savings">💰</div>
        <div class="summary-details">
            <span class="summary-label">Savings Balance</span>
            <span class="summary-value">UGX <?= number_format($member['savings_balance']) ?></span>
        </div>
    </div>
    
    <div class="summary-card">
        <div class="summary-icon shares">📊</div>
        <div class="summary-details">
            <span class="summary-label">Shares Balance</span>
            <span class="summary-value">UGX <?= number_format($member['shares_balance']) ?></span>
        </div>
    </div>
    
    <div class="summary-card">
        <div class="summary-icon loans">🏦</div>
        <div class="summary-details">
            <span class="summary-label">Active Loans</span>
            <span class="summary-value"><?= $member['active_loans'] ?></span>
        </div>
    </div>
    
    <div class="summary-card">
        <div class="summary-icon balance">💳</div>
        <div class="summary-details">
            <span class="summary-label">Loan Balance</span>
            <span class="summary-value">UGX <?= number_format($member['total_loan_balance']) ?></span>
        </div>
    </div>
</div>

<!-- Recent Transactions -->
<div class="card">
    <div class="card-header">
        <h2>Recent Transactions</h2>
        <a href="<?= url('members/statement?id=' . $member['id']) ?>" class="btn-link">View Full Statement</a>
    </div>
    
    <?php if (empty($member['recent_transactions'])): ?>
        <div class="empty-state">No transactions yet</div>
    <?php else: ?>
        <table class="data-table">
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Type</th>
                    <th>Description</th>
                    <th>Debit</th>
                    <th>Credit</th>
                    <th>Reference</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($member['recent_transactions'] as $txn): ?>
                    <tr>
                        <td><?= date('d M Y', strtotime($txn['transaction_date'])) ?></td>
                        <td><span class="badge"><?= h($txn['type']) ?></span></td>
                        <td><?= h($txn['description']) ?></td>
                        <td class="amount debit"><?= $txn['debit'] > 0 ? 'UGX ' . number_format($txn['debit']) : '-' ?></td>
                        <td class="amount credit"><?= $txn['credit'] > 0 ? 'UGX ' . number_format($txn['credit']) : '-' ?></td>
                        <td><?= h($txn['reference_no'] ?? '-') ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    <?php endif; ?>
</div>

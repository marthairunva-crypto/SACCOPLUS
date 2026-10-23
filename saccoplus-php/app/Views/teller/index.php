<?php
$title = 'Teller Operations';
$page = 'teller';
?>

<div class="wrap">
    <div class="page-header">
        <h1>Teller Operations</h1>
        <div class="header-actions">
            <a href="<?= url('teller/deposit') ?>" class="btn btn-primary">+ Deposit</a>
            <a href="<?= url('teller/withdraw') ?>" class="btn btn-light">Withdraw</a>
        </div>
    </div>

    <!-- Today's Summary -->
    <div class="summary-cards">
        <div class="summary-card">
            <div class="summary-icon savings">📥</div>
            <div class="summary-details">
                <span class="summary-label">Total Deposits</span>
                <span class="summary-value">UGX <?= number_format($summary['total_deposits']) ?></span>
            </div>
        </div>
        
        <div class="summary-card">
            <div class="summary-icon loans">📤</div>
            <div class="summary-details">
                <span class="summary-label">Total Withdrawals</span>
                <span class="summary-value">UGX <?= number_format($summary['total_withdrawals']) ?></span>
            </div>
        </div>
        
        <div class="summary-card">
            <div class="summary-icon balance">💰</div>
            <div class="summary-details">
                <span class="summary-label">Net Cash Flow</span>
                <span class="summary-value">UGX <?= number_format($summary['net_cash_flow']) ?></span>
            </div>
        </div>
        
        <div class="summary-card">
            <div class="summary-icon shares">📊</div>
            <div class="summary-details">
                <span class="summary-label">Transactions</span>
                <span class="summary-value"><?= $summary['transaction_count'] ?></span>
            </div>
        </div>
    </div>

    <!-- Recent Transactions -->
    <div class="card">
        <div class="card-header">
            <h2>Today's Transactions (<?= date('d M Y', strtotime($date)) ?>)</h2>
        </div>
        
        <?php if (empty($recent)): ?>
            <div class="empty-state">No transactions yet today</div>
        <?php else: ?>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Time</th>
                        <th>Type</th>
                        <th>Member</th>
                        <th>Account No.</th>
                        <th>Description</th>
                        <th>Debit</th>
                        <th>Credit</th>
                        <th>Reference</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($recent as $txn): ?>
                        <tr>
                            <td><?= date('H:i', strtotime($txn['created_at'])) ?></td>
                            <td>
                                <span class="badge badge-<?= $txn['type'] === 'deposit' ? 'active' : 'inactive' ?>">
                                    <?= ucfirst($txn['type']) ?>
                                </span>
                            </td>
                            <td class="name-cell">
                                <a href="<?= url('members/view?id=' . $txn['member_id']) ?>">
                                    <?= h($txn['member_name']) ?>
                                </a>
                            </td>
                            <td><?= h($txn['account_number']) ?></td>
                            <td><?= h($txn['description']) ?></td>
                            <td class="amount debit">
                                <?= $txn['debit'] > 0 ? 'UGX ' . number_format($txn['debit']) : '-' ?>
                            </td>
                            <td class="amount credit">
                                <?= $txn['credit'] > 0 ? 'UGX ' . number_format($txn['credit']) : '-' ?>
                            </td>
                            <td><?= h($txn['reference_no'] ?? '-') ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
</div>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reconciliation - Teller Center</title>
    <link rel="stylesheet" href="<?= asset('css/style.css') ?>">
    <style>
        .reconciliation-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem;
            border-radius: 12px;
            margin-bottom: 2rem;
        }

        .reconciliation-header h2 {
            margin: 0 0 0.5rem 0;
            font-size: 1.75rem;
        }

        .reconciliation-header p {
            margin: 0;
            opacity: 0.95;
        }

        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .summary-card {
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            border-left: 4px solid #667eea;
        }

        .summary-card.cash {
            border-left-color: #10b981;
        }

        .summary-card.mobile {
            border-left-color: #f59e0b;
        }

        .summary-card.bank {
            border-left-color: #3b82f6;
        }

        .summary-card.variance {
            border-left-color: #ef4444;
        }

        .summary-card h4 {
            margin: 0 0 0.5rem 0;
            font-size: 0.875rem;
            color: #6b7280;
            text-transform: uppercase;
            letter-spacing: 0.05em;
        }

        .summary-card .amount {
            font-size: 1.75rem;
            font-weight: 700;
            color: #111827;
            margin: 0;
        }

        .summary-card .label {
            font-size: 0.75rem;
            color: #9ca3af;
            margin-top: 0.25rem;
        }

        .reconciliation-table {
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            overflow: hidden;
            margin-bottom: 2rem;
        }

        .reconciliation-table h3 {
            padding: 1.5rem;
            margin: 0;
            border-bottom: 2px solid #f3f4f6;
            font-size: 1.25rem;
            color: #111827;
        }

        .reconciliation-table table {
            width: 100%;
            border-collapse: collapse;
        }

        .reconciliation-table thead th {
            background: #f9fafb;
            padding: 1rem;
            text-align: left;
            font-size: 0.875rem;
            font-weight: 600;
            color: #6b7280;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-bottom: 2px solid #e5e7eb;
        }

        .reconciliation-table tbody td {
            padding: 1rem;
            border-bottom: 1px solid #f3f4f6;
            font-size: 0.9375rem;
        }

        .reconciliation-table tbody tr:hover {
            background: #f9fafb;
        }

        .reconciliation-table tbody tr:last-child td {
            border-bottom: none;
        }

        .payment-method-badge {
            display: inline-flex;
            align-items: center;
            padding: 0.375rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.8125rem;
            font-weight: 600;
        }

        .payment-method-badge.cash {
            background: #d1fae5;
            color: #065f46;
        }

        .payment-method-badge.mobile {
            background: #fef3c7;
            color: #92400e;
        }

        .payment-method-badge.bank {
            background: #dbeafe;
            color: #1e40af;
        }

        .variance-indicator {
            display: inline-flex;
            align-items: center;
            padding: 0.375rem 0.75rem;
            border-radius: 6px;
            font-size: 0.875rem;
            font-weight: 600;
        }

        .variance-indicator.balanced {
            background: #d1fae5;
            color: #065f46;
        }

        .variance-indicator.short {
            background: #fee2e2;
            color: #991b1b;
        }

        .variance-indicator.over {
            background: #fef3c7;
            color: #92400e;
        }

        .amount-cell {
            font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Fira Code', monospace;
            font-weight: 600;
        }

        .filters {
            display: flex;
            gap: 1rem;
            align-items: center;
            margin-bottom: 1.5rem;
            flex-wrap: wrap;
        }

        .filter-group {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .filter-group label {
            font-size: 0.875rem;
            font-weight: 500;
            color: #374151;
        }

        .filter-group input,
        .filter-group select {
            padding: 0.5rem 0.75rem;
            border: 1px solid #d1d5db;
            border-radius: 6px;
            font-size: 0.875rem;
        }

        .btn-export {
            margin-left: auto;
            padding: 0.625rem 1.25rem;
            background: #667eea;
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 0.875rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }

        .btn-export:hover {
            background: #5568d3;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }

        .no-data {
            text-align: center;
            padding: 3rem;
            color: #9ca3af;
        }

        .no-data svg {
            width: 64px;
            height: 64px;
            margin: 0 auto 1rem;
            opacity: 0.5;
        }
    </style>
</head>
<body>
    <?php include __DIR__ . '/../partials/sidebar.php'; ?>
    
    <div class="main-content">
        <?php include __DIR__ . '/../partials/topbar.php'; ?>
        
        <div class="content-area">
            <div class="reconciliation-header">
                <h2>📊 Daily Reconciliation</h2>
                <p>Reconcile all payment methods and verify cash position</p>
            </div>

            <!-- Summary Cards -->
            <div class="summary-cards">
                <div class="summary-card cash">
                    <h4>Total Cash</h4>
                    <p class="amount">UGX <?= number_format($summary['total_cash']) ?></p>
                    <p class="label"><?= $summary['cash_count'] ?> transactions</p>
                </div>

                <div class="summary-card mobile">
                    <h4>Total Mobile Money</h4>
                    <p class="amount">UGX <?= number_format($summary['total_mobile']) ?></p>
                    <p class="label"><?= $summary['mobile_count'] ?> transactions</p>
                </div>

                <div class="summary-card bank">
                    <h4>Total Bank Transfers</h4>
                    <p class="amount">UGX <?= number_format($summary['total_bank']) ?></p>
                    <p class="label"><?= $summary['bank_count'] ?> transactions</p>
                </div>

                <div class="summary-card variance">
                    <h4>Till Variance</h4>
                    <p class="amount">UGX <?= number_format(abs($summary['till_variance'])) ?></p>
                    <p class="label">
                        <?php if ($summary['till_variance'] == 0): ?>
                            ✓ Balanced
                        <?php elseif ($summary['till_variance'] < 0): ?>
                            ↓ Short
                        <?php else: ?>
                            ↑ Over
                        <?php endif; ?>
                    </p>
                </div>
            </div>

            <!-- Filters -->
            <div class="filters">
                <div class="filter-group">
                    <label>Date:</label>
                    <input type="date" id="filterDate" value="<?= date('Y-m-d') ?>">
                </div>

                <div class="filter-group">
                    <label>Teller:</label>
                    <select id="filterTeller">
                        <option value="">All Tellers</option>
                        <?php foreach ($tellers as $teller): ?>
                            <option value="<?= $teller['id'] ?>"><?= htmlspecialchars($teller['name']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <button class="btn-export" onclick="exportReconciliation()">
                    📥 Export Report
                </button>
            </div>

            <!-- Payment Method Breakdown -->
            <div class="reconciliation-table">
                <h3>Payment Method Breakdown</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Payment Method</th>
                            <th>Deposits</th>
                            <th>Withdrawals</th>
                            <th>Net Amount</th>
                            <th>Transaction Count</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (!empty($breakdown)): ?>
                            <?php foreach ($breakdown as $method => $data): ?>
                                <tr>
                                    <td>
                                        <span class="payment-method-badge <?= strtolower($method) ?>">
                                            <?php if ($method === 'cash'): ?>
                                                💵 Cash
                                            <?php elseif ($method === 'mobile_money'): ?>
                                                📱 Mobile Money
                                            <?php else: ?>
                                                🏦 Bank Transfer
                                            <?php endif; ?>
                                        </span>
                                    </td>
                                    <td class="amount-cell">UGX <?= number_format($data['deposits']) ?></td>
                                    <td class="amount-cell">UGX <?= number_format($data['withdrawals']) ?></td>
                                    <td class="amount-cell">UGX <?= number_format($data['net']) ?></td>
                                    <td><?= $data['count'] ?></td>
                                    <td>
                                        <span class="variance-indicator balanced">✓ Verified</span>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <tr>
                                <td colspan="6">
                                    <div class="no-data">
                                        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                                        </svg>
                                        <p>No transactions found for today</p>
                                    </div>
                                </td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>

            <!-- Till Sessions -->
            <?php if (!empty($tillSessions)): ?>
            <div class="reconciliation-table">
                <h3>Till Sessions Today</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Teller</th>
                            <th>Opening Cash</th>
                            <th>Closing Cash</th>
                            <th>Expected Cash</th>
                            <th>Variance</th>
                            <th>Status</th>
                            <th>Session Time</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($tillSessions as $session): ?>
                            <tr>
                                <td><?= htmlspecialchars($session['teller_name']) ?></td>
                                <td class="amount-cell">UGX <?= number_format($session['opening_cash']) ?></td>
                                <td class="amount-cell">
                                    <?= $session['closing_cash'] ? 'UGX ' . number_format($session['closing_cash']) : '-' ?>
                                </td>
                                <td class="amount-cell">
                                    <?= $session['expected_cash'] ? 'UGX ' . number_format($session['expected_cash']) : '-' ?>
                                </td>
                                <td class="amount-cell">
                                    <?php if ($session['variance'] !== null): ?>
                                        UGX <?= number_format($session['variance']) ?>
                                    <?php else: ?>
                                        -
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <?php if ($session['status'] === 'open'): ?>
                                        <span class="variance-indicator over">🔓 Open</span>
                                    <?php else: ?>
                                        <?php if ($session['variance'] == 0): ?>
                                            <span class="variance-indicator balanced">✓ Balanced</span>
                                        <?php elseif ($session['variance'] < 0): ?>
                                            <span class="variance-indicator short">↓ Short</span>
                                        <?php else: ?>
                                            <span class="variance-indicator over">↑ Over</span>
                                        <?php endif; ?>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <?= date('H:i', strtotime($session['opened_at'])) ?>
                                    <?php if ($session['closed_at']): ?>
                                        - <?= date('H:i', strtotime($session['closed_at'])) ?>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <?php endif; ?>

            <!-- Recent Transactions -->
            <?php if (!empty($recentTransactions)): ?>
            <div class="reconciliation-table">
                <h3>Recent Transactions</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Time</th>
                            <th>Type</th>
                            <th>Member</th>
                            <th>Payment Method</th>
                            <th>Amount</th>
                            <th>Teller</th>
                            <th>Receipt</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($recentTransactions as $txn): ?>
                            <tr>
                                <td><?= date('H:i:s', strtotime($txn['created_at'])) ?></td>
                                <td>
                                    <?php if ($txn['type'] === 'deposit'): ?>
                                        <span style="color: #10b981; font-weight: 600;">↓ Deposit</span>
                                    <?php else: ?>
                                        <span style="color: #ef4444; font-weight: 600;">↑ Withdrawal</span>
                                    <?php endif; ?>
                                </td>
                                <td><?= htmlspecialchars($txn['member_name']) ?></td>
                                <td>
                                    <span class="payment-method-badge <?= strtolower($txn['payment_method']) ?>">
                                        <?php
                                        $methodLabels = [
                                            'cash' => '💵 Cash',
                                            'mobile_money' => '📱 Mobile Money',
                                            'bank_transfer' => '🏦 Bank'
                                        ];
                                        echo $methodLabels[$txn['payment_method']] ?? $txn['payment_method'];
                                        ?>
                                    </span>
                                </td>
                                <td class="amount-cell">UGX <?= number_format($txn['amount']) ?></td>
                                <td><?= htmlspecialchars($txn['teller_name']) ?></td>
                                <td><?= htmlspecialchars($txn['receipt_number']) ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <?php endif; ?>

        </div>
    </div>

    <script>
        // Filter by date
        document.getElementById('filterDate').addEventListener('change', function() {
            const date = this.value;
            const teller = document.getElementById('filterTeller').value;
            window.location.href = `<?= url('teller/reconciliation') ?>?date=${date}&teller=${teller}`;
        });

        // Filter by teller
        document.getElementById('filterTeller').addEventListener('change', function() {
            const teller = this.value;
            const date = document.getElementById('filterDate').value;
            window.location.href = `<?= url('teller/reconciliation') ?>?date=${date}&teller=${teller}`;
        });

        // Export reconciliation report
        function exportReconciliation() {
            const date = document.getElementById('filterDate').value;
            const teller = document.getElementById('filterTeller').value;
            window.location.href = `<?= url('teller/reconciliation/export') ?>?date=${date}&teller=${teller}`;
        }
    </script>
</body>
</html>

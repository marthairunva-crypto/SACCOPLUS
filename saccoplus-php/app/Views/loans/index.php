<?php $title = "Loans"; ?>

<div class="page-header">
    <h1>Loans</h1>
    <div>
        <a href="<?= url('/loans/create') ?>" class="btn btn-primary">
            <span class="icon">+</span> New Loan Application
        </a>
    </div>
</div>

<!-- Filters -->
<div class="card" style="margin-bottom: 20px;">
    <form method="GET" action="<?= url('/loans') ?>" style="display: flex; gap: 15px; align-items: end;">
        <div style="flex: 1;">
            <label>Search</label>
            <input type="text" name="search" placeholder="Loan number, member name, account..." 
                   value="<?= htmlspecialchars($filters['search']) ?>">
        </div>
        
        <div style="width: 200px;">
            <label>Status</label>
            <select name="status">
                <option value="">All Status</option>
                <option value="pending" <?= $filters['status'] === 'pending' ? 'selected' : '' ?>>Pending</option>
                <option value="approved" <?= $filters['status'] === 'approved' ? 'selected' : '' ?>>Approved</option>
                <option value="disbursed" <?= $filters['status'] === 'disbursed' ? 'selected' : '' ?>>Disbursed</option>
                <option value="active" <?= $filters['status'] === 'active' ? 'selected' : '' ?>>Active</option>
                <option value="closed" <?= $filters['status'] === 'closed' ? 'selected' : '' ?>>Closed</option>
                <option value="rejected" <?= $filters['status'] === 'rejected' ? 'selected' : '' ?>>Rejected</option>
            </select>
        </div>
        
        <button type="submit" class="btn">Filter</button>
        <?php if ($filters['search'] || $filters['status']): ?>
            <a href="<?= url('/loans') ?>" class="btn">Clear</a>
        <?php endif; ?>
    </form>
</div>

<?php if (empty($loans)): ?>
    <div class="card">
        <p style="text-align: center; color: #666; padding: 40px 0;">
            No loans found. <?= $filters['search'] || $filters['status'] ? 'Try adjusting your filters.' : 'Start by creating a new loan application.' ?>
        </p>
    </div>
<?php else: ?>
    <div class="card">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Loan #</th>
                    <th>Member</th>
                    <th>Type</th>
                    <th>Amount</th>
                    <th>Balance</th>
                    <th>Status</th>
                    <th>Application Date</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($loans as $loan): ?>
                    <tr>
                        <td><strong><?= htmlspecialchars($loan['loan_number']) ?></strong></td>
                        <td>
                            <?= htmlspecialchars($loan['member_name']) ?><br>
                            <small style="color: #666;"><?= htmlspecialchars($loan['account_number']) ?></small>
                        </td>
                        <td><?= ucwords(str_replace('_', ' ', $loan['loan_type'])) ?></td>
                        <td>UGX <?= number_format($loan['amount_approved']) ?></td>
                        <td>
                            <?php if ($loan['status'] === 'closed'): ?>
                                <span style="color: #059669;">Paid</span>
                            <?php else: ?>
                                UGX <?= number_format($loan['total_balance']) ?>
                            <?php endif; ?>
                        </td>
                        <td>
                            <span class="badge badge-<?= 
                                $loan['status'] === 'active' || $loan['status'] === 'disbursed' ? 'success' : 
                                ($loan['status'] === 'pending' ? 'warning' : 
                                ($loan['status'] === 'approved' ? 'info' : 
                                ($loan['status'] === 'closed' ? 'secondary' : 'danger'))) 
                            ?>">
                                <?= ucfirst($loan['status']) ?>
                            </span>
                        </td>
                        <td><?= date('d M Y', strtotime($loan['application_date'])) ?></td>
                        <td>
                            <a href="<?= url('/loans/view?id=' . $loan['id']) ?>" class="btn btn-sm">View</a>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    
    <div style="margin-top: 15px; text-align: center; color: #666;">
        Showing <?= count($loans) ?> loan(s)
    </div>
<?php endif; ?>

<?php
$title = 'Members';
$page = 'members';
?>

<div class="page-header">
    <h1>Members</h1>
    <div class="header-actions">
        <input type="search" id="memberSearch" placeholder="Search by name, phone, account..." class="search-input">
        <span class="member-count"><?= number_format($totalMembers) ?> members</span>
    </div>
</div>

<div class="card">
    <table class="data-table">
        <thead>
            <tr>
                <th>Account No.</th>
                <th>Name</th>
                <th>Phone</th>
                <th>Savings Balance</th>
                <th>Shares Balance</th>
                <th>Status</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            <?php if (empty($members)): ?>
                <tr>
                    <td colspan="7" class="empty-state">No members found</td>
                </tr>
            <?php else: ?>
                <?php foreach ($members as $member): ?>
                    <tr>
                        <td><?= h($member['account_number']) ?></td>
                        <td class="name-cell"><?= h($member['full_name']) ?></td>
                        <td><?= h($member['phone'] ?? '-') ?></td>
                        <td class="amount">UGX <?= number_format($member['savings_balance']) ?></td>
                        <td class="amount">UGX <?= number_format($member['shares_balance']) ?></td>
                        <td>
                            <span class="badge badge-<?= $member['status'] ?>">
                                <?= ucfirst($member['status']) ?>
                            </span>
                        </td>
                        <td>
                            <a href="<?= url('members/view?id=' . $member['id']) ?>" class="btn-link">View</a>
                        </td>
                    </tr>
                <?php endforeach; ?>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php if ($totalPages > 1): ?>
    <div class="pagination">
        <?php if ($currentPage > 1): ?>
            <a href="<?= url('members?page=' . ($currentPage - 1)) ?>" class="btn-secondary">Previous</a>
        <?php endif; ?>
        
        <span class="page-info">Page <?= $currentPage ?> of <?= $totalPages ?></span>
        
        <?php if ($currentPage < $totalPages): ?>
            <a href="<?= url('members?page=' . ($currentPage + 1)) ?>" class="btn-secondary">Next</a>
        <?php endif; ?>
    </div>
<?php endif; ?>

<script>
// Live search with debounce
let searchTimeout;
document.getElementById('memberSearch').addEventListener('input', function(e) {
    clearTimeout(searchTimeout);
    const query = e.target.value.trim();
    
    if (query.length < 2) return;
    
    searchTimeout = setTimeout(() => {
        fetch('<?= url('members/search') ?>?q=' + encodeURIComponent(query))
            .then(r => r.json())
            .then(results => {
                // Update table with search results
                console.log('Search results:', results);
                // TODO: Update table rows
            });
    }, 300);
});
</script>

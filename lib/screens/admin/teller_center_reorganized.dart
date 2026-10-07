import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/teller_service.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import 'till_reports_screen.dart';
import 'till_management_screen.dart';

/// Professional Teller Center - Organized like Wakanji SACCO
class TellerCenterReorganized extends StatefulWidget {
  final Function(String loanId, Map<String, dynamic>? loanData)? onLoanTap;
  
  const TellerCenterReorganized({super.key, this.onLoanTap});

  @override
  State<TellerCenterReorganized> createState() => _TellerCenterReorganizedState();
}

class _TellerCenterReorganizedState extends State<TellerCenterReorganized> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  int _selectedTab = 0;
  String? _selectedCategory;

  // ---------------------------------------------------------------------------
  // Responsive helpers
  // ---------------------------------------------------------------------------

  /// Small coloured info chip (used for Branch Status / Balance)
  Widget _statusChip(String label, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade700),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// Status chips shown under the app bar on phones
  Widget _buildStatusStrip() {
    return FutureBuilder<Map<String, dynamic>>(
      future: TellerService.getDailySummary(tellerId: FirebaseService.sessionUid),
      builder: (context, snapshot) {
        final summary = snapshot.data ?? {};
        
        // Fix: Access nested deposits/withdrawals structure
        final deposits = summary['deposits'] as Map<String, dynamic>? ?? {};
        final withdrawals = summary['withdrawals'] as Map<String, dynamic>? ?? {};
        
        final totalDeposits = (deposits['amount'] as num?)?.toInt() ?? 0;
        final totalWithdrawals = (withdrawals['amount'] as num?)?.toInt() ?? 0;
        final balance = totalDeposits - totalWithdrawals;
        
        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _statusChip(
                  'Deposits',
                  'UGX ${_currencyFormat.format(totalDeposits)}',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statusChip(
                  'Withdrawals',
                  'UGX ${_currencyFormat.format(totalWithdrawals)}',
                  Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Grid that adapts its column count to the available width and uses a
  /// fixed tile height, so tile content never overflows.
  Widget _buildResponsiveGrid({
    required List<Widget> children,
    double minTileWidth = 150,
    double tileHeight = 130,
    int maxColumns = 4,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols =
            (constraints.maxWidth / minTileWidth).floor().clamp(1, maxColumns);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: tileHeight,
          ),
          children: children,
        );
      },
    );
  }

  /// "Back to Categories / Current" row (wraps instead of overflowing)
  Widget _buildBreadcrumb(String current) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _selectedCategory = null),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: Text('Back to Categories', style: GoogleFonts.inter(fontSize: 13)),
        ),
        Text(' / ', style: GoogleFonts.inter(color: Colors.grey)),
        Text(current, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ],
    );
  }

  /// Centered "Processing..." / "Loading..." card for blocking dialogs
  Widget _loadingCard(String message) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message, style: GoogleFonts.inter()),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teller Transaction',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Open • ${DateFormat('yMMMMd').format(DateTime.now())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
        // On phones the chips move below the app bar
        actions: isNarrow
            ? null
            : [
                FutureBuilder<Map<String, dynamic>>(
                  future: TellerService.getDailySummary(tellerId: FirebaseService.sessionUid),
                  builder: (context, snapshot) {
                    final summary = snapshot.data ?? {};
                    final totalDeposits = (summary['totalDeposits'] as num?)?.toInt() ?? 0;
                    final totalWithdrawals = (summary['totalWithdrawals'] as num?)?.toInt() ?? 0;
                    final balance = totalDeposits - totalWithdrawals;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _statusChip('BALANCE', 'UGX ${_currencyFormat.format(balance)}', Colors.green),
                    );
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          if (isNarrow) _buildStatusStrip(),

          // Horizontal navigation tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHorizontalTab(0, 'New Transaction', Icons.add_circle_outline),
                  const SizedBox(width: 16),
                  _buildHorizontalTab(1, 'History', Icons.history),
                  const SizedBox(width: 16),
                  _buildHorizontalTab(2, 'Requests', Icons.inbox),
                ],
              ),
            ),
          ),

          // Main content area
          Expanded(
            child: _selectedTab == 0
                ? _buildNewTransactionView()
                : _selectedTab == 1
                    ? _buildHistoryView()
                    : _buildRequestsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedTab = index;
        _selectedCategory = null;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewTransactionView() {
    if (_selectedCategory == null) {
      return _buildCategorySelection();
    }

    switch (_selectedCategory) {
      case 'client':
        return _buildClientTransactionTypes();
      case 'general':
        return _buildGeneralLedgerTypes();
      case 'till':
        return _buildTillAdminTypes();
      case 'bulk':
        return _buildBulkTransactionTypes();
      default:
        return _buildCategorySelection();
    }
  }

  Widget _buildCategorySelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.category, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Choose Category',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 1 column on phones, 2 on wider screens
          _buildResponsiveGrid(
            minTileWidth: 320,
            tileHeight: 110,
            maxColumns: 2,
            children: [
              _buildCategoryCard(
                'client',
                'Client Transaction',
                'Record transactions related to an individual client.',
                Icons.person_outline,
                Colors.blue,
              ),
              _buildCategoryCard(
                'general',
                'General Ledger',
                'Record internal entries such as expenses or journal postings.',
                Icons.account_balance_wallet_outlined,
                Colors.purple,
              ),
              _buildCategoryCard(
                'till',
                'Till Administration',
                'Manage teller till operations like open, close and transfers.',
                Icons.point_of_sale_outlined,
                Colors.orange,
              ),
              _buildCategoryCard(
                'bulk',
                'Bulk Transaction',
                'Process multiple client transactions in a single operation.',
                Icons.cloud_upload_outlined,
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    String id,
    String title,
    String description,
    IconData icon,
    MaterialColor color,
  ) {
    return InkWell(
      onTap: () => setState(() => _selectedCategory = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color.shade700, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTransactionTypes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb('Client Transaction'),
          const SizedBox(height: 24),

          Text(
            'Choose Type',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          _buildResponsiveGrid(
            children: [
              _buildTransactionTypeCard(
                'Shares Deposit',
                'Add funds to a members share account.',
                Icons.add_circle_outline,
                Colors.green,
                () => _showSharesDepositDialog(),
              ),
              _buildTransactionTypeCard(
                'Shares Withdrawal',
                'Withdraw funds from a members share account.',
                Icons.remove_circle_outline,
                Colors.red,
                () => _showSharesWithdrawalDialog(),
              ),
              _buildTransactionTypeCard(
                'Savings Deposit',
                'Add funds to a members savings account.',
                Icons.savings_outlined,
                Colors.blue,
                () => _showSavingsDepositDialog(),
              ),
              _buildTransactionTypeCard(
                'Savings Withdrawal',
                'Withdraw funds from a members savings account.',
                Icons.money_off_outlined,
                Colors.orange,
                () => _showSavingsWithdrawalDialog(),
              ),
              _buildTransactionTypeCard(
                'Fixed Deposit',
                'Create a fixed deposit account with maturity date.',
                Icons.account_balance_outlined,
                Colors.cyan,
                () => _showFixedDepositDialog(),
              ),
              _buildTransactionTypeCard(
                'Mature Fixed Deposit',
                'Mature a fixed deposit and transfer to savings.',
                Icons.check_circle_outline,
                Colors.lightGreen,
                () => _showMatureFixedDepositDialog(),
              ),
              _buildTransactionTypeCard(
                'Loan Repayment',
                'Record a payment made towards a loan.',
                Icons.payment_outlined,
                Colors.purple,
                () => _showLoanRepaymentDialog(),
              ),
              _buildTransactionTypeCard(
                'Disburse Loan',
                'Release funds for an approved loan.',
                Icons.send_outlined,
                Colors.teal,
                () => _showDisburseLoanDialog(),
              ),
              _buildTransactionTypeCard(
                'Apply Fee / Penalty',
                'Apply a fee, penalty or application charge.',
                Icons.receipt_outlined,
                Colors.brown,
                () => _showApplyFeeDialog(),
              ),
              _buildTransactionTypeCard(
                'Reverse Fee/Penalty',
                'Reverse a previously applied charge.',
                Icons.undo_outlined,
                Colors.indigo,
                () => _showReverseFeeDialog(),
              ),
              _buildTransactionTypeCard(
                'Loan Application Fee',
                'Pay fees for granting loan applications.',
                Icons.request_page_outlined,
                Colors.pink,
                () => _showLoanApplicationFeeDialog(),
              ),
              _buildTransactionTypeCard(
                'Error Correction',
                'Correct a previously recorded transaction.',
                Icons.edit_outlined,
                Colors.deepOrange,
                () => _showErrorCorrectionDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeCard(
    String title,
    String description,
    IconData icon,
    MaterialColor color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color.shade700, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralLedgerTypes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb('General Ledger'),
          const SizedBox(height: 24),

          Text(
            'Choose Type',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          _buildResponsiveGrid(
            children: [
              _buildTransactionTypeCard(
                'Journal Entry',
                'Record general journal entries for accounting.',
                Icons.book_outlined,
                Colors.purple,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Journal Entry - Feature available in next update', style: GoogleFonts.inter())),
                ),
              ),
              _buildTransactionTypeCard(
                'Expense Payment',
                'Record organizational expenses and bills.',
                Icons.receipt_long_outlined,
                Colors.red,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Expense Payment - Feature available in next update', style: GoogleFonts.inter())),
                ),
              ),
              _buildTransactionTypeCard(
                'Revenue Entry',
                'Record non-member income and revenues.',
                Icons.trending_up_outlined,
                Colors.green,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Revenue Entry - Feature available in next update', style: GoogleFonts.inter())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTillAdminTypes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb('Till Administration'),
          const SizedBox(height: 24),

          // Till Summary Card
          FutureBuilder<Map<String, dynamic>>(
            future: TellerService.getDailySummary(tellerId: FirebaseService.sessionUid),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? {};
              final totalDeposits = (summary['totalDeposits'] as num?)?.toInt() ?? 0;
              final totalWithdrawals = (summary['totalWithdrawals'] as num?)?.toInt() ?? 0;
              final tillBalance = totalDeposits - totalWithdrawals;

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Till Balance',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'UGX ${_currencyFormat.format(tillBalance)}',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 24,
                            runSpacing: 8,
                            children: [
                              _buildMiniStat('Deposits', totalDeposits, Colors.green.shade300),
                              _buildMiniStat('Withdrawals', totalWithdrawals, Colors.red.shade300),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          Text(
            'Choose Type',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          _buildResponsiveGrid(
            children: [
              _buildTransactionTypeCard(
                'Open/Close Till',
                'Open till for the day or close at end of shift.',
                Icons.vpn_key_outlined,
                Colors.blue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TillManagementScreen()),
                  );
                },
              ),
              _buildTransactionTypeCard(
                'View Summary',
                'View detailed till summary and transactions.',
                Icons.summarize_outlined,
                Colors.cyan,
                () => _showTillSummaryDialog(),
              ),
              _buildTransactionTypeCard(
                'Reconcile Till',
                'Reconcile your till balance at end of day.',
                Icons.checklist_outlined,
                Colors.green,
                () => _showReconcileTillDialog(),
              ),
              _buildTransactionTypeCard(
                'Till Report',
                'Generate and print till report.',
                Icons.print_outlined,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TillReportsScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
        const SizedBox(height: 4),
        Text(
          'UGX ${_currencyFormat.format(value)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showTillSummaryDialog() async {
    final summary = await TellerService.getDailySummary(tellerId: FirebaseService.sessionUid);

    if (!mounted) return;

    // Extract values with null safety
    final totalDeposits = (summary['totalDeposits'] as num?)?.toInt() ?? 0;
    final totalWithdrawals = (summary['totalWithdrawals'] as num?)?.toInt() ?? 0;
    final depositCount = (summary['depositCount'] as num?)?.toInt() ?? 0;
    final withdrawalCount = (summary['withdrawalCount'] as num?)?.toInt() ?? 0;
    final netBalance = totalDeposits - totalWithdrawals;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.summarize, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Text('Till Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow('Total Deposits', totalDeposits, Colors.green),
              _buildSummaryRow('Total Withdrawals', totalWithdrawals, Colors.red),
              _buildSummaryRow('Deposit Count', depositCount, Colors.blue, isAmount: false),
              _buildSummaryRow('Withdrawal Count', withdrawalCount, Colors.orange, isAmount: false),
              const Divider(height: 32),
              _buildSummaryRow(
                'Net Balance',
                netBalance,
                Colors.blue.shade700,
                isBold: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int value, Color color, {bool isAmount = true, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAmount ? 'UGX ${_currencyFormat.format(value)}' : value.toString(),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showReconcileTillDialog() {
    final actualCashCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.checklist, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Text('Reconcile Till', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Count the physical cash in your till and enter the amount below for reconciliation.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: actualCashCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Actual Cash in Till',
                      prefixText: 'UGX ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: TellerService.getDailySummary(tellerId: FirebaseService.sessionUid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();

                      final summary = snapshot.data!;
                      final totalDeposits = (summary['totalDeposits'] as num?)?.toInt() ?? 0;
                      final totalWithdrawals = (summary['totalWithdrawals'] as num?)?.toInt() ?? 0;
                      final expectedBalance = totalDeposits - totalWithdrawals;
                      final actualCash = int.tryParse(actualCashCtrl.text) ?? 0;
                      final difference = actualCash - expectedBalance;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: difference == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: difference == 0 ? Colors.green.shade200 : Colors.orange.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Expected', expectedBalance, Colors.blue.shade700),
                            _buildSummaryRow('Actual', actualCash, Colors.green.shade700),
                            const Divider(),
                            _buildSummaryRow(
                              'Difference',
                              difference,
                              difference == 0 ? Colors.green.shade700 : Colors.red.shade700,
                              isBold: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: actualCashCtrl.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Till reconciled successfully', style: GoogleFonts.inter()),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('Reconcile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkTransactionTypes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBreadcrumb('Bulk Transaction'),
          const SizedBox(height: 24),

          Text(
            'Choose Type',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          _buildResponsiveGrid(
            children: [
              _buildTransactionTypeCard(
                'Bulk Deposits',
                'Process multiple member deposits from CSV file.',
                Icons.upload_file_outlined,
                Colors.green,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bulk Deposits - Feature available in next update', style: GoogleFonts.inter())),
                ),
              ),
              _buildTransactionTypeCard(
                'Bulk Loan Repayments',
                'Process multiple loan payments from CSV file.',
                Icons.payment_outlined,
                Colors.purple,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bulk Loan Repayments - Feature available in next update', style: GoogleFonts.inter())),
                ),
              ),
              _buildTransactionTypeCard(
                'Bulk Dividends',
                'Distribute dividends to multiple members.',
                Icons.money_outlined,
                Colors.blue,
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bulk Dividends - Feature available in next update', style: GoogleFonts.inter())),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TellerService.getTransactionHistory(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Transactions Yet',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Start processing transactions to see history here',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];
            final isDeposit = txn['type'] == 'deposit';
            final source = txn['source'] ?? 'teller';
            final paymentMethod = txn['paymentMethod'] ?? 'Cash';
            final telecomProvider = txn['telecomProvider'];
            final phoneNumber = txn['phoneNumber'];
            final isMobileApp = source == 'mobile_app';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDeposit ? Colors.green.shade50 : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isDeposit ? Colors.green.shade700 : Colors.red.shade700,
                    size: 20,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${txn['memberName']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isMobileApp)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_android, size: 12, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Mobile App',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${txn['accountType']} • ${DateFormat('MMM d, y h:mm a').format(txn['timestamp'])}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (paymentMethod != 'Cash')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.payment, size: 12, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                paymentMethod,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'UGX ${_currencyFormat.format(txn['amount'])}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: isDeposit ? Colors.green.shade700 : Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      txn['receiptNumber'] ?? '',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Source', isMobileApp ? 'Mobile App' : 'Teller', Icons.source),
                        _buildDetailRow('Payment Method', paymentMethod, Icons.payment),
                        if (telecomProvider != null)
                          _buildDetailRow('Telecom Provider', telecomProvider, Icons.phone_android),
                        if (phoneNumber != null)
                          _buildDetailRow('Phone Number', phoneNumber, Icons.phone),
                        _buildDetailRow('Member Phone', txn['memberPhone'] ?? 'N/A', Icons.contact_phone),
                        if (!isMobileApp && txn['tellerName'] != null)
                          _buildDetailRow('Teller', txn['tellerName'], Icons.person),
                        if (txn['notes'] != null && txn['notes'].toString().isNotEmpty)
                          _buildDetailRow('Notes', txn['notes'], Icons.note),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Approval requests will appear here',
            style: GoogleFonts.inter(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog implementations
  // ---------------------------------------------------------------------------

  void _showSharesDepositDialog() async {
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    Map<String, dynamic>? selectedMember;
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    // Capture parent context
    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_circle_outline, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text('Shares Deposit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member search
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 3) {
                        setState(() => isSearching = true);
                        searchResults = await TellerService.searchMembers(value);
                        setState(() => isSearching = false);
                      } else {
                        setState(() {
                          searchResults = [];
                          selectedMember = null;
                        });
                      }
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final member = searchResults[index];
                          return ListTile(
                            title: Text(member['name'], style: GoogleFonts.inter(fontSize: 14)),
                            subtitle: Text(member['phone'], style: GoogleFonts.inter(fontSize: 12)),
                            trailing: Text(
                              'Shares: UGX ${_currencyFormat.format((member['sharesValue'] ?? 0).toInt())}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            onTap: () {
                              setState(() {
                                selectedMember = member;
                                memberController.text = member['name'];
                                searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (selectedMember != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 14)),
                          Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                          Text('Current Shares: UGX ${_currencyFormat.format(((selectedMember!['sharesValue'] ?? 0) as num).toInt())}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (UGX)',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}), // Trigger rebuild to enable button
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: selectedMember == null || amountController.text.isEmpty
                  ? null
                  : () async {
                      final amount = int.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid amount', style: GoogleFonts.inter())),
                        );
                        return;
                      }

                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text('Confirm Transaction', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Please confirm this shares deposit:', style: GoogleFonts.inter(fontSize: 14)),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Member: ${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const SizedBox(height: 4),
                                    Text('Account: Shares', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const Divider(height: 16),
                                    Text('Deposit Amount: UGX ${_currencyFormat.format(amount)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel', style: GoogleFonts.inter()),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Confirm & Process', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      Navigator.pop(dialogContext);

                      await Future.delayed(const Duration(milliseconds: 100));
                      if (!mounted) return;

                      // Show loading
                      showDialog(
                        context: parentContext,
                        barrierDismissible: false,
                        builder: (loadingContext) => _loadingCard('Processing...'),
                      );

                      try {
                        final result = await TellerService.processDeposit(
                          memberId: selectedMember!['id'],
                          memberName: selectedMember!['name'],
                          memberPhone: selectedMember!['phone'],
                          amount: amount,
                          accountType: 'shares',
                          tellerName: 'Admin',
                          tellerId: FirebaseService.sessionUid,
                          tillSession: null, // TODO: Pass actual till session in Phase 3
                        );

                        if (!mounted) return;
                        Navigator.pop(parentContext); // Close loading

                        if (!mounted) return;
                        
                        // Show bank-style transaction alert dialog
                        if (result['success']) {
                          _showTransactionAlertDialog(
                            context: parentContext,
                            type: 'Deposit',
                            amount: amount!,
                            memberName: selectedMember!['name'],
                            accountNumber: selectedMember!['accountNumber'] ?? selectedMember!['phone'] ?? '',
                            accountType: 'savings', // Fixed: use string literal
                            receiptNumber: result['receiptNumber'] ?? '',
                          );
                          // Switch to history tab
                          this.setState(() => _selectedTab = 1);
                        } else {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(result['message'], style: GoogleFonts.inter()),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(parentContext); // Close loading even on error
                        if (!mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e', style: GoogleFonts.inter()),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('Process Deposit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSharesWithdrawalDialog() {
    _showWithdrawalDialog('shares', 'Shares Withdrawal');
  }

  void _showSavingsDepositDialog() {
    _showDepositDialog('savings', 'Savings Deposit');
  }

  void _showSavingsWithdrawalDialog() {
    _showWithdrawalDialog('savings', 'Savings Withdrawal');
  }

  void _showDepositDialog(String accountType, String title) async {
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    Map<String, dynamic>? selectedMember;
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    // Capture parent context
    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.savings_outlined, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 3) {
                        setState(() => isSearching = true);
                        searchResults = await TellerService.searchMembers(value);
                        setState(() => isSearching = false);
                      } else {
                        setState(() {
                          searchResults = [];
                          selectedMember = null;
                        });
                      }
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final member = searchResults[index];
                          return ListTile(
                            title: Text(member['name'], style: GoogleFonts.inter(fontSize: 14)),
                            subtitle: Text(member['phone'], style: GoogleFonts.inter(fontSize: 12)),
                            trailing: Text(
                              '$accountType: UGX ${_currencyFormat.format(((member['${accountType}Balance'] ?? 0) as num).toInt())}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            onTap: () {
                              setState(() {
                                selectedMember = member;
                                memberController.text = member['name'];
                                searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (selectedMember != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 14)),
                          Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                          Text('Current Balance: UGX ${_currencyFormat.format(((selectedMember!['${accountType}Balance'] ?? 0) as num).toInt())}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (UGX)',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}), // Trigger rebuild to enable button
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: selectedMember == null || amountController.text.isEmpty
                  ? null
                  : () async {
                      final amount = int.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid amount', style: GoogleFonts.inter())),
                        );
                        return;
                      }

                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text('Confirm Transaction', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Please confirm this $accountType deposit:', style: GoogleFonts.inter(fontSize: 14)),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Member: ${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const SizedBox(height: 4),
                                    Text('Account: ${accountType[0].toUpperCase()}${accountType.substring(1)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const Divider(height: 16),
                                    Text('Deposit Amount: UGX ${_currencyFormat.format(amount)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel', style: GoogleFonts.inter()),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Confirm & Process', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      Navigator.pop(dialogContext);

                      await Future.delayed(const Duration(milliseconds: 100));
                      if (!mounted) return;

                      showDialog(
                        context: parentContext,
                        barrierDismissible: false,
                        builder: (loadingContext) => _loadingCard('Processing...'),
                      );

                      try {
                        final result = await TellerService.processDeposit(
                          memberId: selectedMember!['id'],
                          memberName: selectedMember!['name'],
                          memberPhone: selectedMember!['phone'],
                          amount: amount,
                          accountType: accountType,
                          tellerName: 'Admin',
                          tellerId: FirebaseService.sessionUid,
                          tillSession: null, // TODO: Pass actual till session in Phase 3
                        );

                        if (!mounted) return;
                        Navigator.pop(parentContext);

                        if (!mounted) return;
                        
                        // Show bank-style transaction alert dialog
                        if (result['success']) {
                          _showTransactionAlertDialog(
                            context: parentContext,
                            type: 'Deposit',
                            amount: amount!,
                            memberName: selectedMember!['name'],
                            accountNumber: selectedMember!['accountNumber'] ?? selectedMember!['phone'] ?? '',
                            accountType: accountType, // This is the function parameter
                            receiptNumber: result['receiptNumber'] ?? '',
                          );
                          this.setState(() => _selectedTab = 1);
                        } else {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(result['message'], style: GoogleFonts.inter()),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(parentContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e', style: GoogleFonts.inter()),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('Process Deposit', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawalDialog(String accountType, String title) async {
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    Map<String, dynamic>? selectedMember;
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    // Capture parent context
    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.remove_circle_outline, color: Colors.red.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 3) {
                        setState(() => isSearching = true);
                        searchResults = await TellerService.searchMembers(value);
                        setState(() => isSearching = false);
                      } else {
                        setState(() {
                          searchResults = [];
                          selectedMember = null;
                        });
                      }
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final member = searchResults[index];
                          return ListTile(
                            title: Text(member['name'], style: GoogleFonts.inter(fontSize: 14)),
                            subtitle: Text(member['phone'], style: GoogleFonts.inter(fontSize: 12)),
                            trailing: Text(
                              '$accountType: UGX ${_currencyFormat.format(((member['${accountType}Balance'] ?? 0) as num).toInt())}',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            onTap: () {
                              setState(() {
                                selectedMember = member;
                                memberController.text = member['name'];
                                searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (selectedMember != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 14)),
                          Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                          Text('Available Balance: UGX ${_currencyFormat.format(((selectedMember!['${accountType}Balance'] ?? 0) as num).toInt())}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (UGX)',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => setState(() {}), // Trigger rebuild to enable button
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: selectedMember == null || amountController.text.isEmpty
                  ? null
                  : () async {
                      final amount = int.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please enter a valid amount', style: GoogleFonts.inter())),
                        );
                        return;
                      }

                      // Check balance
                      final availableBalance = ((selectedMember!['${accountType}Balance'] ?? 0) as num).toInt();
                      if (amount > availableBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Insufficient balance. Available: UGX ${_currencyFormat.format(availableBalance)}', style: GoogleFonts.inter()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text('Confirm Withdrawal', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Please confirm this $accountType withdrawal:', style: GoogleFonts.inter(fontSize: 14)),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Member: ${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const SizedBox(height: 4),
                                    Text('Account: ${accountType[0].toUpperCase()}${accountType.substring(1)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const Divider(height: 16),
                                    Text('Available Balance: UGX ${_currencyFormat.format(availableBalance)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
                                    const SizedBox(height: 4),
                                    Text('Withdrawal Amount: UGX ${_currencyFormat.format(amount)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                                    const SizedBox(height: 4),
                                    Text('New Balance: UGX ${_currencyFormat.format(availableBalance - amount)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel', style: GoogleFonts.inter()),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Confirm & Withdraw', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      Navigator.pop(dialogContext);

                      await Future.delayed(const Duration(milliseconds: 100));
                      if (!mounted) return;

                      showDialog(
                        context: parentContext,
                        barrierDismissible: false,
                        builder: (loadingContext) => _loadingCard('Processing...'),
                      );

                      try {
                        final result = await TellerService.processWithdrawal(
                          memberId: selectedMember!['id'],
                          memberName: selectedMember!['name'],
                          memberPhone: selectedMember!['phone'],
                          amount: amount,
                          accountType: accountType,
                          tellerName: 'Admin',
                          tellerId: FirebaseService.sessionUid,
                          tillSession: null, // TODO: Pass actual till session in Phase 3
                        );

                        if (!mounted) return;
                        Navigator.pop(parentContext);

                        if (!mounted) return;
                        
                        // Show bank-style transaction alert dialog
                        if (result['success']) {
                          _showTransactionAlertDialog(
                            context: parentContext,
                            type: 'Deposit',
                            amount: amount!,
                            memberName: selectedMember!['name'],
                            accountNumber: selectedMember!['accountNumber'] ?? selectedMember!['phone'] ?? '',
                            accountType: accountType, // This is the function parameter
                            receiptNumber: result['receiptNumber'] ?? '',
                          );
                          this.setState(() => _selectedTab = 1);
                        } else {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(result['message'], style: GoogleFonts.inter()),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(parentContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e', style: GoogleFonts.inter()),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('Process Withdrawal', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoanRepaymentDialog() async {
    final memberController = TextEditingController();
    Map<String, dynamic>? selectedMember;
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    // Capture parent context before dialog
    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.payment_outlined, color: Colors.purple.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text('Loan Repayment', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search for member to view their active loans',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  // Member search
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 3) {
                        setState(() => isSearching = true);
                        searchResults = await TellerService.searchMembers(value);
                        setState(() => isSearching = false);
                      } else {
                        setState(() {
                          searchResults = [];
                          selectedMember = null;
                        });
                      }
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final member = searchResults[index];
                          return ListTile(
                            title: Text(member['name'], style: GoogleFonts.inter(fontSize: 14)),
                            subtitle: Text(member['phone'], style: GoogleFonts.inter(fontSize: 12)),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                            onTap: () async {
                              // Close the dialog first using dialogContext
                              Navigator.pop(dialogContext);

                              // Small delay to ensure dialog is closed
                              await Future.delayed(const Duration(milliseconds: 100));

                              // Check if widget is still mounted
                              if (!mounted) return;

                              // Show loading while fetching loans using parentContext
                              showDialog(
                                context: parentContext,
                                barrierDismissible: false,
                                builder: (loadingContext) => _loadingCard('Loading loans...'),
                              );

                              // Get member's active loans (Active, Ongoing, Disbursed, Overdue)
                              print('🔍 Searching loans for member: ${member['id']}');
                              print('🔍 Member name: ${member['name']}');
                              print('🔍 Member accountNumber: ${member['accountNumber']}');
                              print('🔍 Tenant ID: ${FirebaseService.sessionTenantId}');
                              
                              // First, let's check ALL loans in the system to see what farmerId values exist
                              final allSystemLoans = await FirebaseFirestore.instance
                                  .collection(AppConstants.loansCol)
                                  .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                                  .limit(10)
                                  .get();
                              
                              print('🔍 Sample loans in system:');
                              for (var doc in allSystemLoans.docs) {
                                final data = doc.data();
                                print('  - Loan ${doc.id}: memberName=${data['memberName']}, farmerId=${data['farmerId']}, accountNumber=${data['accountNumber']}');
                              }
                              
                              final loansQuery = await FirebaseFirestore.instance
                                  .collection(AppConstants.loansCol)
                                  .where('farmerId', isEqualTo: member['id'])
                                  .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                                  .where('status', whereIn: [
                                    AppConstants.statusActive,     // 'Active'
                                    AppConstants.statusDisbursed,  // 'Disbursed'
                                    AppConstants.statusOverdue,    // 'Overdue'
                                    AppConstants.statusApproved,   // 'Approved' (not yet disbursed)
                                  ])
                                  .get();

                              print('🔍 Found ${loansQuery.docs.length} loans with member ID');
                              
                              // Try searching by memberName if member ID search fails and farmerId is commonly null
                              QuerySnapshot<Map<String, dynamic>>? finalLoansQuery = loansQuery;
                              
                              if (loansQuery.docs.isEmpty) {
                                print('🔍 Trying search by memberName: ${member['name']}');
                                
                                // Search by exact member name (case-insensitive)
                                final loansByName = await FirebaseFirestore.instance
                                    .collection(AppConstants.loansCol)
                                    .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                                    .where('status', whereIn: [
                                      AppConstants.statusActive,     // 'Active'
                                      AppConstants.statusDisbursed,  // 'Disbursed'
                                      AppConstants.statusOverdue,    // 'Overdue'
                                      AppConstants.statusApproved,   // 'Approved'
                                    ])
                                    .get();
                                
                                // Filter by name (case-insensitive comparison)
                                final memberNameLower = member['name'].toString().toLowerCase();
                                final matchingLoans = loansByName.docs.where((doc) {
                                  final loanName = (doc.data()['memberName'] ?? '').toString().toLowerCase();
                                  return loanName == memberNameLower;
                                }).toList();
                                
                                print('🔍 Found ${matchingLoans.length} loans by memberName');
                                
                                if (matchingLoans.isNotEmpty) {
                                  finalLoansQuery = loansByName; // Use the full query but we'll filter below
                                  
                                  // Close loading dialog
                                  if (!mounted) return;
                                  Navigator.pop(parentContext);
                                  
                                  // If only one loan, go directly to it
                                  if (matchingLoans.length == 1) {
                                    final loanDoc = matchingLoans.first;
                                    final loanData = {'id': loanDoc.id, ...loanDoc.data()};
                                    
                                    if (widget.onLoanTap != null) {
                                      widget.onLoanTap!(loanDoc.id, loanData);
                                    } else {
                                      Navigator.pushNamed(
                                        parentContext,
                                        '/loan-details',
                                        arguments: {
                                          'loanId': loanDoc.id,
                                          'loanData': loanData,
                                        },
                                      );
                                    }
                                    return;
                                  } else {
                                    // Multiple loans - show selection dialog
                                    final selectedLoan = await showDialog<Map<String, dynamic>>(
                                      context: parentContext,
                                      builder: (context) => AlertDialog(
                                        title: Text('Select Loan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                        content: SizedBox(
                                          width: 400,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: matchingLoans.map((doc) {
                                              final data = doc.data();
                                              return ListTile(
                                                title: Text(
                                                  'A/C: ${data['accountNumber']}',
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                                ),
                                                subtitle: Text(
                                                  'Amount: UGX ${_currencyFormat.format((data['loanAmount'] ?? 0).round())}\nStatus: ${data['status']}',
                                                  style: GoogleFonts.inter(fontSize: 12),
                                                ),
                                                onTap: () => Navigator.pop(context, {'id': doc.id, ...data}),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    );
                                    
                                    if (selectedLoan != null && mounted) {
                                      if (widget.onLoanTap != null) {
                                        widget.onLoanTap!(selectedLoan['id'], selectedLoan);
                                      } else {
                                        Navigator.pushNamed(
                                          parentContext,
                                          '/loan-details',
                                          arguments: {
                                            'loanId': selectedLoan['id'],
                                            'loanData': selectedLoan,
                                          },
                                        );
                                      }
                                    }
                                    return;
                                  }
                                }
                              }
                              
                              // Try searching by accountNumber if member ID search fails
                              if (loansQuery.docs.isEmpty && member['accountNumber'] != null) {
                                print('🔍 Trying search by accountNumber: ${member['accountNumber']}');
                                final loansByAccount = await FirebaseFirestore.instance
                                    .collection(AppConstants.loansCol)
                                    .where('accountNumber', isEqualTo: member['accountNumber'])
                                    .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                                    .where('status', whereIn: [
                                      AppConstants.statusActive,
                                      AppConstants.statusDisbursed,
                                      AppConstants.statusOverdue,
                                      AppConstants.statusApproved,
                                    ])
                                    .get();
                                
                                print('🔍 Found ${loansByAccount.docs.length} loans by accountNumber');
                                
                                if (loansByAccount.docs.isNotEmpty) {
                                  // Use the account-based search results
                                  if (!mounted) return;
                                  Navigator.pop(parentContext); // Close loading
                                  
                                  if (loansByAccount.docs.length == 1) {
                                    final loanDoc = loansByAccount.docs.first;
                                    final loanData = {'id': loanDoc.id, ...loanDoc.data()};
                                    
                                    if (widget.onLoanTap != null) {
                                      widget.onLoanTap!(loanDoc.id, loanData);
                                    }
                                  }
                                  return;
                                }
                              }
                              
                              if (loansQuery.docs.isNotEmpty) {
                                for (var doc in loansQuery.docs) {
                                  final data = doc.data();
                                  print('  - Loan ${doc.id}: status=${data['status']}, farmerId=${data['farmerId']}');
                                }
                              }

                              // Try without status filter to see all loans
                              final allLoans = await FirebaseFirestore.instance
                                  .collection(AppConstants.loansCol)
                                  .where('farmerId', isEqualTo: member['id'])
                                  .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                                  .get();
                              
                              print('🔍 Total loans for this member (all statuses): ${allLoans.docs.length}');
                              for (var doc in allLoans.docs) {
                                final data = doc.data();
                                print('  - Loan ${doc.id}: status=${data['status']}');
                              }

                              // Check if still mounted before closing loading
                              if (!mounted) return;
                              Navigator.pop(parentContext); // Close loading

                              if (loansQuery.docs.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text('No active loans found for ${member['name']}', style: GoogleFonts.inter()),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              // If only one loan, go directly to it
                              if (loansQuery.docs.length == 1) {
                                if (!mounted) return;
                                final loanDoc = loansQuery.docs.first;
                                final loanData = {'id': loanDoc.id, ...loanDoc.data()};
                                
                                // Use callback if available, otherwise push route
                                if (widget.onLoanTap != null) {
                                  widget.onLoanTap!(loanDoc.id, loanData);
                                } else {
                                  Navigator.pushNamed(
                                    parentContext,
                                    '/loan-details',
                                    arguments: {
                                      'loanId': loanDoc.id,
                                      'initialLoanData': loanData,
                                    },
                                  );
                                }
                                return;
                              }

                              // If multiple loans, show selection dialog
                              if (!mounted) return;
                              final selectedLoan = await showDialog<String>(
                                context: parentContext,
                                builder: (loanSelectContext) => AlertDialog(
                                  title: Text('Select Loan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  content: SizedBox(
                                    width: 400,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${member['name']} has ${loansQuery.docs.length} active loans',
                                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                                          ),
                                          const SizedBox(height: 16),
                                          ...loansQuery.docs.map((doc) {
                                            final loan = doc.data();
                                            final amount = ((loan['loanAmount'] ?? loan['amount'] ?? 0) as num).toInt();
                                            final outstanding = ((loan['principalOutstanding'] ?? 0) as num).toInt();
                                            final refNumber = loan['referenceNumber'] ?? doc.id;

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              child: ListTile(
                                                leading: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.account_balance, color: Colors.blue.shade700, size: 20),
                                                ),
                                                title: Text('Loan $refNumber', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                                subtitle: Text(
                                                  'Amount: UGX ${_currencyFormat.format(amount)}\nOutstanding: UGX ${_currencyFormat.format(outstanding)}',
                                                  style: GoogleFonts.inter(fontSize: 12),
                                                ),
                                                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                                                onTap: () => Navigator.pop(loanSelectContext, doc.id),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(loanSelectContext),
                                      child: Text('Cancel', style: GoogleFonts.inter()),
                                    ),
                                  ],
                                ),
                              );

                              if (selectedLoan != null && mounted) {
                                final loanDoc = loansQuery.docs.firstWhere((doc) => doc.id == selectedLoan);
                                final loanData = {'id': loanDoc.id, ...loanDoc.data()};
                                
                                // Use callback if available, otherwise push route
                                if (widget.onLoanTap != null) {
                                  widget.onLoanTap!(loanDoc.id, loanData);
                                } else {
                                  Navigator.pushNamed(
                                    parentContext,
                                    '/loan-details',
                                    arguments: {
                                      'loanId': loanDoc.id,
                                      'initialLoanData': loanData,
                                    },
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  if (selectedMember != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('${selectedMember!['name']}', style: GoogleFonts.inter(fontSize: 14)),
                          Text('Phone: ${selectedMember!['phone']}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisburseLoanDialog() async {
    final memberController = TextEditingController();
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];

    // Capture parent context before dialog
    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_outlined, color: Colors.teal.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text('Disburse Loan', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search for member to view their approved loans',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) async {
                      if (value.length >= 3) {
                        setState(() => isSearching = true);
                        searchResults = await TellerService.searchMembers(value);
                        setState(() => isSearching = false);
                      } else {
                        setState(() => searchResults = []);
                      }
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final member = searchResults[index];
                          return ListTile(
                            title: Text(member['name'], style: GoogleFonts.inter(fontSize: 14)),
                            subtitle: Text(member['phone'], style: GoogleFonts.inter(fontSize: 12)),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                            onTap: () async {
                              Navigator.pop(dialogContext);

                              // Small delay to ensure dialog is closed
                              await Future.delayed(const Duration(milliseconds: 100));

                              if (!mounted) return;

                              showDialog(
                                context: parentContext,
                                barrierDismissible: false,
                                builder: (loadingContext) => _loadingCard('Loading loans...'),
                              );

                              final loansQuery = await FirebaseFirestore.instance
                                  .collection(AppConstants.loansCol)
                                  .where('farmerId', isEqualTo: member['id'])
                                  .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                                  .where('status', isEqualTo: 'approved')
                                  .get();

                              if (!mounted) return;
                              Navigator.pop(parentContext);

                              if (loansQuery.docs.isEmpty) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text('No approved loans found for ${member['name']}', style: GoogleFonts.inter()),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              if (loansQuery.docs.length == 1) {
                                if (!mounted) return;
                                final loanDoc = loansQuery.docs.first;
                                Navigator.pushNamed(
                                  parentContext,
                                  '/loan-details',
                                  arguments: {
                                    'loanId': loanDoc.id,
                                    'initialLoanData': {'id': loanDoc.id, ...loanDoc.data()},
                                  },
                                );
                                return;
                              }

                              if (!mounted) return;
                              final selectedLoan = await showDialog<String>(
                                context: parentContext,
                                builder: (loanSelectContext) => AlertDialog(
                                  title: Text('Select Loan to Disburse', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  content: SizedBox(
                                    width: 400,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${member['name']} has ${loansQuery.docs.length} approved loans',
                                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                                          ),
                                          const SizedBox(height: 16),
                                          ...loansQuery.docs.map((doc) {
                                            final loan = doc.data();
                                            final amount = ((loan['loanAmount'] ?? loan['amount'] ?? 0) as num).toInt();
                                            final refNumber = loan['referenceNumber'] ?? doc.id;

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              child: ListTile(
                                                leading: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                                                ),
                                                title: Text('Loan $refNumber', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                                subtitle: Text(
                                                  'Amount: UGX ${_currencyFormat.format(amount)}\nStatus: Approved',
                                                  style: GoogleFonts.inter(fontSize: 12),
                                                ),
                                                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade600),
                                                onTap: () => Navigator.pop(loanSelectContext, doc.id),
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(loanSelectContext),
                                      child: Text('Cancel', style: GoogleFonts.inter()),
                                    ),
                                  ],
                                ),
                              );

                              if (selectedLoan != null && mounted) {
                                final loanDoc = loansQuery.docs.firstWhere((doc) => doc.id == selectedLoan);
                                final loanData = {'id': loanDoc.id, ...loanDoc.data()};
                                
                                // Use callback if available, otherwise push route
                                if (widget.onLoanTap != null) {
                                  widget.onLoanTap!(loanDoc.id, loanData);
                                } else {
                                  Navigator.pushNamed(
                                    parentContext,
                                    '/loan-details',
                                    arguments: {
                                      'loanId': loanDoc.id,
                                      'initialLoanData': loanData,
                                    },
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplyFeeDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Apply Fee - Feature available in next update', style: GoogleFonts.inter())),
    );
  }

  void _showReverseFeeDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reverse Fee - Feature available in next update', style: GoogleFonts.inter())),
    );
  }

  void _showLoanApplicationFeeDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loan Application Fee - Feature available in next update', style: GoogleFonts.inter())),
    );
  }

  void _showErrorCorrectionDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error Correction - Feature available in next update', style: GoogleFonts.inter())),
    );
  }

  // ─── Fixed Deposit Dialog ─────────────────────────────────────────────────
  void _showFixedDepositDialog() async {
    final memberController = TextEditingController();
    final amountController = TextEditingController();
    final monthsController = TextEditingController(text: '12');
    Map<String, dynamic>? selectedMember;
    bool isSearching = false;
    List<Map<String, dynamic>> searchResults = [];
    DateTime maturityDate = DateTime.now().add(const Duration(days: 365));

    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance_outlined, color: Colors.cyan.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Create Fixed Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (query) async {
                      if (query.length < 2) {
                        setState(() {
                          searchResults = [];
                          isSearching = false;
                        });
                        return;
                      }
                      setState(() => isSearching = true);
                      final results = await TellerService.searchMembers(query);
                      setState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty && selectedMember == null)
                    ...searchResults.map((member) => ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(member['name'] ?? 'Unknown'),
                          subtitle: Text(member['phone'] ?? ''),
                          onTap: () {
                            setState(() {
                              selectedMember = member;
                              searchResults = [];
                              memberController.text = member['name'] ?? '';
                            });
                          },
                        )),
                  if (selectedMember != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Member:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan.shade900)),
                          Text(selectedMember!['name'] ?? ''),
                          Text('Phone: ${selectedMember!['phone']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Deposit Amount (UGX)',
                        prefixIcon: Icon(Icons.money),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: monthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Term (Months)',
                        prefixIcon: Icon(Icons.calendar_today),
                        helperText: 'Interest: 10% per annum',
                      ),
                      onChanged: (value) {
                        final months = int.tryParse(value) ?? 12;
                        setState(() {
                          maturityDate = DateTime.now().add(Duration(days: months * 30));
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Maturity Date: ${DateFormat('MMM dd, yyyy').format(maturityDate)}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (selectedMember != null)
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  final months = int.tryParse(monthsController.text) ?? 12;

                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Show loading
                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (c) => _loadingCard('Creating fixed deposit...'),
                  );

                  try {
                    await TellerService.createFixedDeposit(
                      memberId: selectedMember!['id'],
                      memberName: selectedMember!['name'],
                      amount: amount,
                      months: months,
                    );

                    if (parentContext.mounted) {
                      Navigator.pop(parentContext); // Close loading
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Fixed deposit created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (parentContext.mounted) {
                      Navigator.pop(parentContext); // Close loading
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Fixed Deposit'),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Mature Fixed Deposit Dialog ──────────────────────────────────────────
  void _showMatureFixedDepositDialog() async {
    final memberController = TextEditingController();
    Map<String, dynamic>? selectedMember;
    List<Map<String, dynamic>> memberFixedDeposits = [];
    Map<String, dynamic>? selectedDeposit;
    bool isSearching = false;
    bool isLoadingDeposits = false;
    List<Map<String, dynamic>> searchResults = [];

    final parentContext = context;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.lightGreen.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: Colors.lightGreen.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text('Mature Fixed Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: memberController,
                    decoration: const InputDecoration(
                      labelText: 'Search Member (Name or Phone)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (query) async {
                      if (query.length < 2) {
                        setState(() {
                          searchResults = [];
                          isSearching = false;
                        });
                        return;
                      }
                      setState(() => isSearching = true);
                      final results = await TellerService.searchMembers(query);
                      setState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    },
                  ),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (searchResults.isNotEmpty && selectedMember == null)
                    ...searchResults.map((member) => ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(member['name'] ?? 'Unknown'),
                          subtitle: Text(member['phone'] ?? ''),
                          onTap: () async {
                            setState(() {
                              selectedMember = member;
                              searchResults = [];
                              memberController.text = member['name'] ?? '';
                              isLoadingDeposits = true;
                            });

                            // Load member's fixed deposits
                            final deposits = await TellerService.getMemberFixedDeposits(member['id']);
                            setState(() {
                              memberFixedDeposits = deposits;
                              isLoadingDeposits = false;
                            });
                          },
                        )),
                  if (selectedMember != null) ...[
                    const SizedBox(height: 16),
                    if (isLoadingDeposits)
                      const Center(child: CircularProgressIndicator())
                    else if (memberFixedDeposits.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No active fixed deposits found for this member.'),
                      )
                    else ...[
                      const Text('Select Fixed Deposit to Mature:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...memberFixedDeposits.map((deposit) {
                        final amount = (deposit['amount'] ?? 0).toDouble();
                        final interest = (deposit['interestEarned'] ?? 0).toDouble();
                        final maturityDate = deposit['maturityDate'] != null
                            ? (deposit['maturityDate'] as Timestamp).toDate()
                            : DateTime.now();
                        final isMatured = DateTime.now().isAfter(maturityDate);

                        return Card(
                          color: selectedDeposit?['id'] == deposit['id']
                              ? Colors.lightGreen.shade50
                              : Colors.white,
                          child: ListTile(
                            leading: Icon(
                              isMatured ? Icons.check_circle : Icons.schedule,
                              color: isMatured ? Colors.green : Colors.orange,
                            ),
                            title: Text('UGX ${_currencyFormat.format(amount)}'),
                            subtitle: Text(
                              'Maturity: ${DateFormat('MMM dd, yyyy').format(maturityDate)}\n'
                              'Interest: UGX ${_currencyFormat.format(interest)}',
                            ),
                            trailing: Text(
                              isMatured ? 'Matured' : 'Pending',
                              style: TextStyle(
                                color: isMatured ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              setState(() => selectedDeposit = deposit);
                            },
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (selectedDeposit != null)
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  // Show loading
                  showDialog(
                    context: parentContext,
                    barrierDismissible: false,
                    builder: (c) => _loadingCard('Maturing fixed deposit...'),
                  );

                  try {
                    await TellerService.matureFixedDeposit(
                      fixedDepositId: selectedDeposit!['id'],
                      tellerId: FirebaseService.sessionUid,
                      tellerName: FirebaseService.sessionProfile?['name'] as String? ?? 
                                  FirebaseService.sessionProfile?['fullName'] as String? ?? 'Teller',
                    );

                    if (parentContext.mounted) {
                      Navigator.pop(parentContext); // Close loading
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(
                          content: Text('Fixed deposit matured successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (parentContext.mounted) {
                      Navigator.pop(parentContext); // Close loading
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Mature Deposit'),
              ),
          ],
        ),
      ),
    );
  }
}

  // Bank-style transaction alert dialog
  void _showTransactionAlertDialog({
    required BuildContext context,
    required String type,
    required int amount,
    required String memberName,
    required String accountNumber,
    required String accountType,
    required String receiptNumber,
  }) {
    // Get last 3 digits of account number
    final accountLast3 = accountNumber.length >= 3 
        ? accountNumber.substring(accountNumber.length - 3) 
        : accountNumber;
    
    final accountTypeText = accountType == 'savings' ? 'Savings' : 'Shares';
    final isDeposit = type == 'Deposit';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              
              // Transaction type
              Text(
                '$type Successful',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              
              // Transaction details - Bank style
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildAlertDetailRow('Amount', 'UGX ${NumberFormat('#,###', 'en_US').format(amount)}', bold: true),
                    const Divider(height: 20),
                    _buildAlertDetailRow('Account', '$accountTypeText A/C ending xxx$accountLast3'),
                    const Divider(height: 20),
                    _buildAlertDetailRow('Member', memberName),
                    const Divider(height: 20),
                    _buildAlertDetailRow('Receipt No.', receiptNumber),
                    const Divider(height: 20),
                    _buildAlertDetailRow('Date', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Message
              Text(
                isDeposit 
                    ? 'Your deposit has been processed successfully.'
                    : 'Your withdrawal has been processed successfully.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertDetailRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

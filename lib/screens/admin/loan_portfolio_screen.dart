import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/loan_portfolio_service.dart';
import '../../theme/modern_theme.dart';
import '../../widgets/app_widgets.dart';
import 'loan_360_screen.dart';

class LoanPortfolioScreen extends StatefulWidget {
  final bool embedded;
  const LoanPortfolioScreen({super.key, this.embedded = false});

  @override
  State<LoanPortfolioScreen> createState() => _LoanPortfolioScreenState();
}

class _LoanPortfolioScreenState extends State<LoanPortfolioScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Loan Portfolio', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: ModernTheme.primary,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Overdue Loans'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(fmt: _fmt),
          _OverdueLoansTab(fmt: _fmt),
          _PerformanceTab(fmt: _fmt),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  final NumberFormat fmt;
  const _OverviewTab({required this.fmt});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _summary;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    final summary = await LoanPortfolioService.getPortfolioSummary();
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build with AutomaticKeepAliveClientMixin
    
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Portfolio Overview',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_summary != null) ...[
            // Key metrics grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMetricCard(
                  'Total Loans',
                  '${_summary!['totalLoans']}',
                  Icons.assignment,
                  ModernTheme.info,
                  fullWidth: false,
                ),
                _buildMetricCard(
                  'Active Loans',
                  '${_summary!['activeLoans']}',
                  Icons.schedule,
                  ModernTheme.primary,
                  fullWidth: false,
                ),
                _buildMetricCard(
                  'Overdue Loans',
                  '${_summary!['overdueLoans']}',
                  Icons.warning,
                  ModernTheme.error,
                  fullWidth: false,
                ),
                _buildMetricCard(
                  'Completed',
                  '${_summary!['completedLoans']}',
                  Icons.check_circle,
                  ModernTheme.success,
                  fullWidth: false,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Financial summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ModernTheme.primary, ModernTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ModernTheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFinancialRow('Total Disbursed', 'UGX ${widget.fmt.format(_summary!['totalDisbursed'])}', true),
                  const Divider(color: Colors.white24, height: 24),
                  _buildFinancialRow('Total Repaid', 'UGX ${widget.fmt.format(_summary!['totalRepaid'])}', true),
                  const Divider(color: Colors.white24, height: 24),
                  _buildFinancialRow('Outstanding', 'UGX ${widget.fmt.format(_summary!['totalOutstanding'])}', true),
                  if (_summary!['totalOverdueAmount'] > 0) ...[
                    const Divider(color: Colors.white24, height: 24),
                    _buildFinancialRow(
                      'Overdue Amount',
                      'UGX ${widget.fmt.format(_summary!['totalOverdueAmount'])}',
                      true,
                      color: ModernTheme.error,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Performance indicators
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceCard(
                    'Repayment Rate',
                    '${_summary!['repaymentRate'].toStringAsFixed(1)}%',
                    _summary!['repaymentRate'] >= 80 ? ModernTheme.success : ModernTheme.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPerformanceCard(
                    'Portfolio at Risk',
                    '${_summary!['portfolioAtRisk'].toStringAsFixed(1)}%',
                    _summary!['portfolioAtRisk'] <= 5 ? ModernTheme.success : ModernTheme.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : 165,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  Widget _buildFinancialRow(String label, String value, bool isWhite, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: color ?? (isWhite ? Colors.white70 : ModernTheme.textSecondary),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color ?? (isWhite ? Colors.white : ModernTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: ModernTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overdue Loans Tab ────────────────────────────────────────────────────────
class _OverdueLoansTab extends StatefulWidget {
  final NumberFormat fmt;
  const _OverdueLoansTab({required this.fmt});

  @override
  State<_OverdueLoansTab> createState() => _OverdueLoansTabState();
}

class _OverdueLoansTabState extends State<_OverdueLoansTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _overdueLoans = [];
  bool _loading = false;
  bool _sendingReminders = false;

  @override
  void initState() {
    super.initState();
    _loadOverdueLoans();
  }

  Future<void> _loadOverdueLoans() async {
    setState(() => _loading = true);
    final loans = await LoanPortfolioService.getOverdueLoans();
    if (mounted) {
      setState(() {
        _overdueLoans = loans;
        _loading = false;
      });
    }
  }

  Future<void> _sendReminders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Reminders', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Send payment reminder notifications to all ${_overdueLoans.length} members with overdue loans?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.primary),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _sendingReminders = true);
    
    try {
      final result = await LoanPortfolioService.sendOverdueReminders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['success']
                  ? 'Sent ${result['remindersSent']} reminders successfully!'
                  : 'Failed to send reminders: ${result['error']}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: result['success'] ? ModernTheme.success : ModernTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReminders = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build with AutomaticKeepAliveClientMixin
    
    return Column(
      children: [
        // Header with action button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overdue Loans',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${_overdueLoans.length} loans requiring attention',
                      style: GoogleFonts.poppins(fontSize: 13, color: ModernTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _overdueLoans.isEmpty || _sendingReminders ? null : _sendReminders,
                icon: _sendingReminders
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.notifications_active, size: 18),
                label: const Text('Send Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.warning,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Loans list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _overdueLoans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 64, color: ModernTheme.success.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No overdue loans!',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: ModernTheme.success,
                            ),
                          ),
                          Text(
                            'All loans are on track',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOverdueLoans,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _overdueLoans.length,
                        itemBuilder: (context, index) {
                          return _buildOverdueLoanCard(_overdueLoans[index], index);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildOverdueLoanCard(Map<String, dynamic> loan, int index) {
    final daysOverdue = loan['daysOverdue'] as int;
    final severity = daysOverdue <= 30
        ? ModernTheme.warning
        : daysOverdue <= 60
            ? ModernTheme.error
            : const Color(0xFF8B0000); // Dark red

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Loan360Screen(
              loanId: loan['id'],
              loanData: loan,
            ),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severity.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: severity.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: severity.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning, color: severity, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan['farmerName'],
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      loan['farmerPhone'],
                      style: GoogleFonts.poppins(fontSize: 13, color: ModernTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: severity.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$daysOverdue days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: severity,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildLoanDetail('Loan Amount', 'UGX ${widget.fmt.format(loan['amount'])}'),
              ),
              Expanded(
                child: _buildLoanDetail('Repaid', 'UGX ${widget.fmt.format(loan['totalRepaid'])}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildLoanDetail('Outstanding', 'UGX ${widget.fmt.format(loan['outstanding'])}', severity),
              ),
              Expanded(
                child: _buildLoanDetail('Penalty', 'UGX ${widget.fmt.format(loan['penalty'])}', ModernTheme.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: severity.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Due (with penalty):',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'UGX ${widget.fmt.format(loan['outstanding'] + loan['penalty'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: severity,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildLoanDetail(String label, String value, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: ModernTheme.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? ModernTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Performance Tab ──────────────────────────────────────────────────────────
class _PerformanceTab extends StatefulWidget {
  final NumberFormat fmt;
  const _PerformanceTab({required this.fmt});

  @override
  State<_PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<_PerformanceTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _metrics;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _loading = true);
    final metrics = await LoanPortfolioService.getLoanPerformanceMetrics();
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build with AutomaticKeepAliveClientMixin
    
    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Performance Metrics',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_metrics != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overdue Loans by Age',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ..._buildOverdueBreakdown(_metrics!['overdueBreakdown'] as Map<String, dynamic>),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Key performance indicators
            _buildKPICard(
              'Repayment Rate',
              '${_metrics!['repaymentRate'].toStringAsFixed(1)}%',
              _metrics!['repaymentRate'] >= 80 ? ModernTheme.success : ModernTheme.warning,
              'Target: 80%+',
            ),
            const SizedBox(height: 12),
            _buildKPICard(
              'Portfolio at Risk',
              '${_metrics!['portfolioAtRisk'].toStringAsFixed(1)}%',
              _metrics!['portfolioAtRisk'] <= 5 ? ModernTheme.success : ModernTheme.error,
              'Target: <5%',
            ),
            const SizedBox(height: 12),
            _buildKPICard(
              'Active Loan Recovery Rate',
              _metrics!['activeLoans'] > 0
                  ? '${((_metrics!['activeLoans'] - _metrics!['overdueLoans']) / _metrics!['activeLoans'] * 100).toStringAsFixed(1)}%'
                  : '0%',
              ModernTheme.info,
              'Non-overdue active loans',
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildOverdueBreakdown(Map<String, dynamic> breakdown) {
    return breakdown.entries.map((entry) {
      final count = entry.value as int;
      Color color;
      
      if (entry.key.contains('1-30')) {
        color = ModernTheme.warning;
      } else if (entry.key.contains('31-60')) {
        color = ModernTheme.error;
      } else if (entry.key.contains('61-90')) {
        color = const Color(0xFFFF4500);
      } else {
        color = const Color(0xFF8B0000);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.key,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count loans',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildKPICard(String title, String value, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0);
  }
}

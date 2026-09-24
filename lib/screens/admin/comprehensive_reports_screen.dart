import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/report_service.dart';
import '../../theme/modern_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../utils/file_saver.dart';

class ComprehensiveReportsScreen extends StatefulWidget {
  final bool embedded;
  const ComprehensiveReportsScreen({super.key, this.embedded = false});

  @override
  State<ComprehensiveReportsScreen> createState() => _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState extends State<ComprehensiveReportsScreen> {
  int _selectedReportIndex = 0;
  
  final List<Map<String, dynamic>> _reports = [
    {'icon': Icons.calendar_month, 'title': 'Monthly Report', 'subtitle': 'Income & Expenses'},
    {'icon': Icons.account_balance_wallet, 'title': 'Trial Balance', 'subtitle': 'Debits & Credits'},
    {'icon': Icons.account_balance, 'title': 'Balance Sheet', 'subtitle': 'Assets & Liabilities'},
    {'icon': Icons.verified_user, 'title': 'KYC Report', 'subtitle': 'Member Verification'},
    {'icon': Icons.credit_card, 'title': 'Loan Report', 'subtitle': 'Loan Portfolio'},
    {'icon': Icons.wallet, 'title': 'Wallet Report', 'subtitle': 'Transactions'},
    {'icon': Icons.people, 'title': 'Member Report', 'subtitle': 'Member Directory'},
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: widget.embedded ? null : AppBar(
        title: Text('Financial Reports', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: ModernTheme.primary,
        elevation: 0,
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ModernTheme.primary, ModernTheme.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.assessment, color: Colors.white, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Financial Reports',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Comprehensive Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) => _buildSidebarItem(index),
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: List.generate(
                _reports.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildMobileTab(index),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSidebarItem(int index) {
    final report = _reports[index];
    final isSelected = _selectedReportIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: isSelected ? ModernTheme.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? ModernTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? ModernTheme.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                report['icon'],
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
            ),
            title: Text(
              report['title'],
              style: GoogleFonts.poppins(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
                color: isSelected ? ModernTheme.primary : ModernTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              report['subtitle'],
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: ModernTheme.textSecondary,
              ),
            ),
            onTap: () => setState(() => _selectedReportIndex = index),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTab(int index) {
    final report = _reports[index];
    final isSelected = _selectedReportIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedReportIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ModernTheme.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              report['icon'],
              size: 18,
              color: isSelected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              report['title'],
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final fmt = NumberFormat('#,###', 'en_US');
    
    switch (_selectedReportIndex) {
      case 0:
        return _MonthlyReportTab(fmt: fmt);
      case 1:
        return _TrialBalanceTab(fmt: fmt);
      case 2:
        return _BalanceSheetTab(fmt: fmt);
      case 3:
        return _KYCReportTab(fmt: fmt);
      case 4:
        return _LoanReportTab(fmt: fmt);
      case 5:
        return _WalletReportTab(fmt: fmt);
      case 6:
        return _MemberReportTab(fmt: fmt);
      default:
        return const Center(child: Text('Select a report'));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Monthly Report Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _MonthlyReportTab extends StatefulWidget {
  final NumberFormat fmt;
  const _MonthlyReportTab({required this.fmt});

  @override
  State<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<_MonthlyReportTab> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final report = await ReportService.generateMonthlyReport(
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _exportCSV() async {
    if (_report == null) return;
    
    final csv = StringBuffer();
    csv.writeln('Monthly Report - ${_report!['period']}');
    csv.writeln('Generated: ${DateFormat.yMMMd().add_jm().format(_report!['generatedAt'])}');
    csv.writeln('');
    csv.writeln('Category,Count,Amount (UGX)');
    csv.writeln('Loans Disbursed,${_report!['loans']['count']},${_report!['loans']['amount']}');
    csv.writeln('Loan Repayments,${_report!['repayments']['count']},${_report!['repayments']['amount']}');
    csv.writeln('Savings Deposits,${_report!['savings']['count']},${_report!['savings']['amount']}');
    csv.writeln('Share Purchases,${_report!['shares']['count']},${_report!['shares']['amount']}');
    csv.writeln('');
    csv.writeln('Net Cash Flow,,${_report!['netCashFlow']}');
    
    // Save file (works on web and desktop)
    await FileSaver.saveFile(
      fileName: 'monthly_report_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv',
      content: csv.toString(),
      mimeType: 'text/csv',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Report exported successfully'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Report',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Income and expense summary',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildMonthYearSelector(),
                    const SizedBox(width: 12),
                    if (_report != null && !_loading)
                      ElevatedButton.icon(
                        onPressed: () => _exportCSV(),
                        icon: const Icon(Icons.file_download, size: 18),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModernTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
                            const SizedBox(height: 16),
                            Text('Error loading report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(_error!, style: GoogleFonts.poppins(color: ModernTheme.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadReport,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _report == null
                        ? const Center(child: Text('No data available'))
                        : RefreshIndicator(
                            onRefresh: _loadReport,
                            child: ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                // Summary cards grid
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final crossAxisCount = constraints.maxWidth > 1200 ? 4 : constraints.maxWidth > 800 ? 2 : 1;
                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 2,
                                      children: [
                                        _buildStatCard(
                                          'Loans Disbursed',
                                          'UGX ${widget.fmt.format(_report!['loans']['amount'])}',
                                          '${_report!['loans']['count']} transactions',
                                          Icons.credit_card,
                                          ModernTheme.primary,
                                        ),
                                        _buildStatCard(
                                          'Loan Repayments',
                                          'UGX ${widget.fmt.format(_report!['repayments']['amount'])}',
                                          '${_report!['repayments']['count']} transactions',
                                          Icons.payment,
                                          ModernTheme.success,
                                        ),
                                        _buildStatCard(
                                          'Savings Deposits',
                                          'UGX ${widget.fmt.format(_report!['savings']['amount'])}',
                                          '${_report!['savings']['count']} transactions',
                                          Icons.savings,
                                          ModernTheme.info,
                                        ),
                                        _buildStatCard(
                                          'Share Purchases',
                                          'UGX ${widget.fmt.format(_report!['shares']['amount'])}',
                                          '${_report!['shares']['count']} transactions',
                                          Icons.pie_chart,
                                          ModernTheme.accent,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                // Net cash flow
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _report!['netCashFlow'] >= 0
                                          ? [ModernTheme.success, ModernTheme.success.withOpacity(0.8)]
                                          : [ModernTheme.error, ModernTheme.error.withOpacity(0.8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_report!['netCashFlow'] >= 0 ? ModernTheme.success : ModernTheme.error).withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _report!['netCashFlow'] >= 0 ? Icons.trending_up : Icons.trending_down,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Net Cash Flow',
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'UGX ${widget.fmt.format(_report!['netCashFlow'])}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _report!['netCashFlow'] >= 0 ? 'Positive cash flow' : 'Negative cash flow',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<int>(
            value: _selectedMonth,
            underline: const SizedBox(),
            items: List.generate(12, (i) => i + 1).map((month) {
              return DropdownMenuItem(
                value: month,
                child: Text(
                  DateFormat.MMMM().format(DateTime(2024, month)),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedMonth = value);
                _loadReport();
              }
            },
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedYear,
            underline: const SizedBox(),
            items: List.generate(5, (i) => DateTime.now().year - i).map((year) {
              return DropdownMenuItem(
                value: year,
                child: Text('$year', style: GoogleFonts.poppins(fontSize: 14)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedYear = value);
                _loadReport();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String amount, String subtitle, IconData icon, Color color) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ModernTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Trial Balance Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _TrialBalanceTab extends StatefulWidget {
  final NumberFormat fmt;
  const _TrialBalanceTab({required this.fmt});

  @override
  State<_TrialBalanceTab> createState() => _TrialBalanceTabState();
}

class _TrialBalanceTabState extends State<_TrialBalanceTab> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final report = await ReportService.generateTrialBalance();
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            const SizedBox(height: 16),
            Text('Error loading report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.poppins(color: ModernTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trial Balance',
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'As of ${DateFormat.yMMMd().format(_report!['asOfDate'])}',
                      style: GoogleFonts.poppins(fontSize: 14, color: ModernTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              // Balance indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _report!['balanced'] ? ModernTheme.success.withOpacity(0.1) : ModernTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _report!['balanced'] ? ModernTheme.success : ModernTheme.error,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _report!['balanced'] ? Icons.check_circle : Icons.error,
                      color: _report!['balanced'] ? ModernTheme.success : ModernTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _report!['balanced'] ? 'Balanced ✓' : 'Not Balanced',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: _report!['balanced'] ? ModernTheme.success : ModernTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Trial Balance Table
          Container(
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
                // Table Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ModernTheme.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Account',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Debit (UGX)',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Credit (UGX)',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                // Assets Section
                _buildSection('ASSETS', [
                  _AccountLine('Loans Receivable - Principal', widget.fmt.format(_report!['assets']['loansReceivable']['principal']), ''),
                  _AccountLine('Loans Receivable - Interest', widget.fmt.format(_report!['assets']['loansReceivable']['interest']), ''),
                  _AccountLine('Total Assets', widget.fmt.format(_report!['assets']['total']), '', isBold: true),
                ]),
                const Divider(height: 1),
                // Liabilities Section
                _buildSection('LIABILITIES', [
                  _AccountLine('Member Savings', '', widget.fmt.format(_report!['liabilities']['memberSavings'])),
                  _AccountLine('Member Shares', '', widget.fmt.format(_report!['liabilities']['memberShares'])),
                  _AccountLine('Fixed Deposits', '', widget.fmt.format(_report!['liabilities']['fixedDeposits'])),
                  _AccountLine('Total Liabilities', '', widget.fmt.format(_report!['liabilities']['total']), isBold: true),
                ]),
                const Divider(height: 1),
                // Equity Section
                _buildSection('EQUITY', [
                  _AccountLine('Retained Earnings', '', widget.fmt.format(_report!['equity']['retainedEarnings'])),
                  _AccountLine('Total Equity', '', widget.fmt.format(_report!['equity']['total']), isBold: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_AccountLine> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ModernTheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...lines.map((line) => _buildAccountRow(line)),
      ],
    );
  }

  Widget _buildAccountRow(_AccountLine line) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: line.isBold ? Colors.grey.shade50 : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              line.account,
              style: GoogleFonts.poppins(
                fontWeight: line.isBold ? FontWeight.w600 : FontWeight.w500,
                fontSize: line.isBold ? 14 : 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.debit,
              textAlign: TextAlign.right,
              style: GoogleFonts.robotoMono(
                fontWeight: line.isBold ? FontWeight.w600 : FontWeight.w500,
                fontSize: line.isBold ? 14 : 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.credit,
              textAlign: TextAlign.right,
              style: GoogleFonts.robotoMono(
                fontWeight: line.isBold ? FontWeight.w600 : FontWeight.w500,
                fontSize: line.isBold ? 14 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountLine {
  final String account;
  final String debit;
  final String credit;
  final bool isBold;

  _AccountLine(this.account, this.debit, this.credit, {this.isBold = false});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Balance Sheet Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _BalanceSheetTab extends StatefulWidget {
  final NumberFormat fmt;
  const _BalanceSheetTab({required this.fmt});

  @override
  State<_BalanceSheetTab> createState() => _BalanceSheetTabState();
}

class _BalanceSheetTabState extends State<_BalanceSheetTab> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final report = await ReportService.generateBalanceSheet();
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (_report == null) return;

    final csv = StringBuffer();
    csv.writeln('SACCO PLUS PRO');
    csv.writeln('BALANCE SHEET');
    csv.writeln('As of ${DateFormat('MMMM d, yyyy').format(_report!['asOfDate'])}');
    csv.writeln('');
    
    final assets = _report!['assets'];
    final currentAssets = assets['currentAssets'];
    final liabilities = _report!['liabilities'];
    final currentLiabilities = liabilities['currentLiabilities'];
    final equity = _report!['equity'];
    
    csv.writeln('ASSETS');
    csv.writeln('Current Assets');
    csv.writeln('Cash in Hand,${currentAssets['cashInHand']}');
    csv.writeln('Loans Receivable - Principal,${currentAssets['loansReceivable']}');
    csv.writeln('Total Current Assets,${currentAssets['total']}');
    csv.writeln('Total Assets,${assets['total']}');
    csv.writeln('');
    
    csv.writeln('LIABILITIES & EQUITY');
    csv.writeln('Current Liabilities,${currentLiabilities['total']}');
    csv.writeln('Total Liabilities,${liabilities['total']}');
    csv.writeln('');
    csv.writeln('EQUITY');
    csv.writeln('Owner\'s Investments,${equity['retainedEarnings']}');
    csv.writeln('Total Equity,${equity['total']}');
    csv.writeln('');
    csv.writeln('Total Liabilities & Equity,${_report!['totalLiabilitiesAndEquity']}');

    // Save file (works on web and desktop)
    await FileSaver.saveFile(
      fileName: 'balance_sheet_${DateFormat('yyyyMMdd').format(_report!['asOfDate'])}.csv',
      content: csv.toString(),
      mimeType: 'text/csv',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ CSV exported successfully'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _exportToPDF() async {
    if (_report == null) return;

    final pdf = pw.Document();
    final assets = _report!['assets'];
    final currentAssets = assets['currentAssets'];
    final liabilities = _report!['liabilities'];
    final currentLiabilities = liabilities['currentLiabilities'];
    final equity = _report!['equity'];
    final fmt = NumberFormat('#,###', 'en_US');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SACCO PLUS PRO',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'BALANCE SHEET',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'As of ${DateFormat('MMMM d, yyyy').format(_report!['asOfDate'])}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Assets
              pw.Text(
                'ASSETS',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),
              
              pw.Text('Current Assets', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _pdfLineItem('Cash in Hand', currentAssets['cashInHand'], fmt),
              _pdfLineItem('Loans Receivable - Principal', currentAssets['loansReceivable'], fmt),
              pw.Divider(),
              _pdfLineItem('Total Current Assets', currentAssets['total'], fmt, bold: true),
              pw.SizedBox(height: 12),
              _pdfLineItem('Total Assets', assets['total'], fmt, bold: true, fontSize: 14),
              
              pw.SizedBox(height: 24),

              // Liabilities & Equity
              pw.Text(
                'LIABILITIES & EQUITY',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),
              
              pw.Text('Current Liabilities', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              _pdfLineItem('Total Current Liabilities', currentLiabilities['total'], fmt),
              pw.Divider(),
              _pdfLineItem('Total Liabilities', liabilities['total'], fmt, bold: true),
              
              pw.SizedBox(height: 12),
              
              pw.Text('EQUITY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              _pdfLineItem('Owner\'s Investments', equity['retainedEarnings'], fmt),
              pw.Divider(),
              _pdfLineItem('Total Equity', equity['total'], fmt, bold: true),
              
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 2),
              _pdfLineItem('Total Liabilities & Equity', _report!['totalLiabilitiesAndEquity'], fmt, bold: true, fontSize: 14),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ PDF exported successfully'), backgroundColor: Colors.green),
      );
    }
  }

  pw.Widget _pdfLineItem(String label, int amount, NumberFormat fmt, {bool bold = false, double fontSize = 12}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text('UGX ${fmt.format(amount)}', style: pw.TextStyle(fontSize: fontSize, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            const SizedBox(height: 16),
            Text('Error loading report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Export Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _exportToCSV,
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ModernTheme.success,
                  side: BorderSide(color: ModernTheme.success),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _exportToPDF,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Header with Company Name
          Center(
            child: Column(
              children: [
                Text(
                  'SACCO PLUS PRO',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'BALANCE SHEET',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'As of ${DateFormat('MMMM d, yyyy').format(_report!['asOfDate'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Two-Column Layout (Desktop) or Stacked (Mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - ASSETS
                    Expanded(
                      child: _buildAssetsColumn(),
                    ),
                    const SizedBox(width: 24),
                    // Right Column - LIABILITIES & EQUITY
                    Expanded(
                      child: _buildLiabilitiesEquityColumn(),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildAssetsColumn(),
                    const SizedBox(height: 24),
                    _buildLiabilitiesEquityColumn(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // Assets Column (Left Side)
  Widget _buildAssetsColumn() {
    final assets = _report!['assets'];
    final currentAssets = assets['currentAssets'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
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
          // ASSETS Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
            child: Text(
              'ASSETS',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current Assets
          _buildSubHeader('Current Assets'),
          const SizedBox(height: 8),
          _buildLineItem('Cash in Hand', currentAssets['cashInHand']),
          _buildLineItem('Loans Receivable - Principal', currentAssets['loansReceivable']),
          _buildLineItem('Accounts Receivable - net', 0),
          _buildLineItem('Other receivables', 0),
          _buildLineItem('Inventory', 0),
          _buildLineItem('Supplies', 0),
          _buildLineItem('Prepaid expenses', 0),
          _buildLineItem('Other', 0),
          const SizedBox(height: 8),
          _buildTotalLine('Total Current Assets', currentAssets['total']),
          
          const SizedBox(height: 24),

          // Non-Current Assets (if any)
          _buildSubHeader('Non-Current Assets'),
          const SizedBox(height: 8),
          _buildLineItem('Other Investments', 0),
          _buildLineItem('Land', 0),
          _buildLineItem('Land Improvements', 0),
          _buildLineItem('Buildings', 0),
          _buildLineItem('Equipment', 0),
          _buildLineItem('Less: Accumulated Depreciation', 0, isNegative: true),
          const SizedBox(height: 8),
          _buildTotalLine('Total Non-Current Assets', 0),

          const SizedBox(height: 24),

          // Other Assets
          _buildSubHeader('Other Assets'),
          const SizedBox(height: 8),
          _buildLineItem('Goodwill', 0),
          _buildLineItem('Other Assets', 0),
          const SizedBox(height: 8),
          _buildTotalLine('Total Other Assets', 0),

          const SizedBox(height: 24),

          // TOTAL ASSETS
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF1E3A5F), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildGrandTotalLine('Total Assets', assets['total']),
          ),
        ],
      ),
    );
  }

  // Liabilities & Equity Column (Right Side)
  Widget _buildLiabilitiesEquityColumn() {
    final liabilities = _report!['liabilities'];
    final currentLiabilities = liabilities['currentLiabilities'];
    final equity = _report!['equity'];
    final total = _report!['totalLiabilitiesAndEquity'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
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
          // LIABILITIES & EQUITY Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 2),
              ),
            ),
            child: Text(
              'LIABILITIES & EQUITY',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E3A5F),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current Liabilities
          _buildSubHeader('Current Liabilities'),
          const SizedBox(height: 8),
          _buildLineItem('Short-term loans payable', 0),
          _buildLineItem('Current portion of long-term debt', 0),
          _buildLineItem('Accounts payable', 0),
          _buildLineItem('Accrued compensation and benefits', 0),
          _buildLineItem('Income taxes payable', 0),
          _buildLineItem('Other accrued liabilities', 0),
          _buildLineItem('Unearned revenues', 0),
          _buildLineItem('Other', 0),
          const SizedBox(height: 8),
          _buildTotalLine('Total Current Liabilities', currentLiabilities['total']),
          
          const SizedBox(height: 24),

          // Non-Current Liabilities
          _buildSubHeader('Non-Current Liabilities'),
          const SizedBox(height: 8),
          _buildLineItem('Notes payable', 0),
          _buildLineItem('Loan Payable', 0),
          _buildLineItem('Other', 0),
          const SizedBox(height: 8),
          _buildTotalLine('Total Non-Current Liabilities', 0),

          const SizedBox(height: 16),

          // Total Liabilities
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade400, width: 1),
                bottom: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
            ),
            child: _buildTotalLine('Total Liabilities', liabilities['total'], isBold: true),
          ),

          const SizedBox(height: 24),

          // EQUITY
          _buildSubHeader('EQUITY'),
          const SizedBox(height: 8),
          _buildLineItem('Owner\'s Investments', equity['retainedEarnings']),
          _buildLineItem('Net Profit from Business', 0),
          _buildLineItem('Other', 0),
          const SizedBox(height: 8),
          _buildTotalLine('Total Equity', equity['total']),

          const SizedBox(height: 24),

          // TOTAL LIABILITIES & EQUITY
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF1E3A5F), width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildGrandTotalLine('Total Liabilities & Equity', total),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildSubHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildLineItem(String label, int amount, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ModernTheme.textSecondary,
              ),
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}UGX ${widget.fmt.format(amount)}',
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              color: ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalLine(String label, int amount, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
          Text(
            'UGX ${widget.fmt.format(amount)}',
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotalLine(String label, int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E3A5F),
          ),
        ),
        Text(
          'UGX ${widget.fmt.format(amount)}',
          style: GoogleFonts.robotoMono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E3A5F),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KYC Report Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _KYCReportTab extends StatefulWidget {
  final NumberFormat fmt;
  const _KYCReportTab({required this.fmt});

  @override
  State<_KYCReportTab> createState() => _KYCReportTabState();
}

class _KYCReportTabState extends State<_KYCReportTab> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final report = await ReportService.generateKYCReport();
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            const SizedBox(height: 16),
            Text('Error loading report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'KYC Compliance Report',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Summary cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildKYCCard('Total Members', '${_report!['summary']['total']}', Icons.people, ModernTheme.info),
              _buildKYCCard('Verified', '${_report!['summary']['verified']}', Icons.verified_user, ModernTheme.success),
              _buildKYCCard('Pending', '${_report!['summary']['pending']}', Icons.pending, ModernTheme.warning),
              _buildKYCCard('Rejected', '${_report!['summary']['rejected']}', Icons.cancel, ModernTheme.error),
            ],
          ),
          const SizedBox(height: 24),

          // Verification rate
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ModernTheme.success, ModernTheme.success.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ModernTheme.success.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.verified, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Verification Rate',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_report!['summary']['verificationRate'].toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Pending verifications
          if ((_report!['pendingVerifications'] as List).isNotEmpty) ...[
            Text(
              'Pending Verifications (${(_report!['pendingVerifications'] as List).length})',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...(_report!['pendingVerifications'] as List).map((member) {
              return _buildMemberCard(
                member['name'],
                member['phone'],
                'Submitted: ${DateFormat.yMMMd().format(member['submittedAt'])}',
                ModernTheme.warning,
              );
            }).toList(),
            const SizedBox(height: 24),
          ],

          // Rejected verifications
          if ((_report!['rejectedVerifications'] as List).isNotEmpty) ...[
            Text(
              'Rejected Verifications (${(_report!['rejectedVerifications'] as List).length})',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...(_report!['rejectedVerifications'] as List).map((member) {
              return _buildMemberCard(
                member['name'],
                member['phone'],
                'Reason: ${member['reason']}',
                ModernTheme.error,
              );
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildKYCCard(String title, String value, IconData icon, Color color) {
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: ModernTheme.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale();
  }

  Widget _buildMemberCard(String name, String phone, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  phone,
                  style: GoogleFonts.poppins(fontSize: 12, color: ModernTheme.textSecondary),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loan Report Tab  
// ═══════════════════════════════════════════════════════════════════════════════
class _LoanReportTab extends StatefulWidget {
  final NumberFormat fmt;
  const _LoanReportTab({required this.fmt});

  @override
  State<_LoanReportTab> createState() => _LoanReportTabState();
}

class _LoanReportTabState extends State<_LoanReportTab> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final report = await ReportService.generateLoanReport();
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            const SizedBox(height: 16),
            Text('Error loading report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Loan Portfolio Report',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Summary cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total Requested', 'UGX ${widget.fmt.format(_report!['financials']['totalAmountRequested'])}', Icons.request_quote, ModernTheme.info),
              _buildStatCard('Disbursed', 'UGX ${widget.fmt.format(_report!['financials']['totalAmountDisbursed'])}', Icons.payments, ModernTheme.primary),
              _buildStatCard('Repaid', 'UGX ${widget.fmt.format(_report!['financials']['totalRepaid'])}', Icons.check_circle, ModernTheme.success),
              _buildStatCard('Outstanding', 'UGX ${widget.fmt.format(_report!['financials']['totalOutstanding'])}', Icons.pending, ModernTheme.warning),
              _buildStatCard('Approval Rate', '${_report!['summary']['approvalRate'].toStringAsFixed(1)}%', Icons.thumb_up, ModernTheme.success),
              _buildStatCard('Repayment Rate', '${_report!['summary']['repaymentRate'].toStringAsFixed(1)}%', Icons.trending_up, ModernTheme.success),
            ],
          ),
          const SizedBox(height: 24),

          // Status breakdown
          Container(
            padding: const EdgeInsets.all(24),
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
                  'Loan Status Breakdown',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildStatusRow('Total Loans', _report!['summary']['totalLoans'], ModernTheme.textPrimary),
                _buildStatusRow('Pending', _report!['summary']['pending'], ModernTheme.warning),
                _buildStatusRow('Approved', _report!['summary']['approved'], ModernTheme.success),
                _buildStatusRow('Rejected', _report!['summary']['rejected'], ModernTheme.error),
                _buildStatusRow('Paid', _report!['summary']['paid'], ModernTheme.info),
                _buildStatusRow('Overdue', _report!['summary']['overdue'], Colors.deepOrange),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overdue loans
          if ((_report!['overdueLoans'] as List).isNotEmpty) ...[
            Text(
              'Overdue Loans (${(_report!['overdueLoans'] as List).length})',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...(_report!['overdueLoans'] as List).take(10).map((loan) {
              return _buildLoanCard(loan, true);
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, color: ModernTheme.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale();
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan, bool isOverdue) {
    final daysOverdue = isOverdue ? loan['daysOverdue'] as int : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOverdue ? ModernTheme.error.withOpacity(0.3) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isOverdue ? ModernTheme.error : ModernTheme.success).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOverdue ? Icons.warning : Icons.check_circle,
              color: isOverdue ? ModernTheme.error : ModernTheme.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan['farmerName'],
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  'Amount: UGX ${widget.fmt.format(loan['amount'])} • Outstanding: UGX ${widget.fmt.format(loan['outstanding'])}',
                  style: GoogleFonts.poppins(fontSize: 12, color: ModernTheme.textSecondary),
                ),
                if (isOverdue)
                  Text(
                    'Overdue by $daysOverdue days',
                    style: GoogleFonts.poppins(fontSize: 11, color: ModernTheme.error, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Wallet Report Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _WalletReportTab extends StatefulWidget {
  final NumberFormat fmt;
  const _WalletReportTab({required this.fmt});

  @override
  State<_WalletReportTab> createState() => _WalletReportTabState();
}

class _WalletReportTabState extends State<_WalletReportTab> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final report = await ReportService.generateWalletReport();
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            const SizedBox(height: 16),
            Text('Error loading report', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Wallet Transaction Report',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Summary
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('Total Transactions', '${_report!['summary']['totalTransactions']}', Icons.receipt_long, ModernTheme.info),
              _buildStatCard('Deposits', 'UGX ${widget.fmt.format(_report!['financials']['totalDeposits'])}', Icons.arrow_downward, ModernTheme.success),
              _buildStatCard('Withdrawals', 'UGX ${widget.fmt.format(_report!['financials']['totalWithdrawals'])}', Icons.arrow_upward, ModernTheme.error),
              _buildStatCard('Transfers', 'UGX ${widget.fmt.format(_report!['financials']['totalTransfers'])}', Icons.swap_horiz, ModernTheme.primary),
              _buildStatCard('Airtime/Data', 'UGX ${widget.fmt.format(_report!['financials']['totalAirtime'])}', Icons.phone_android, ModernTheme.accent),
              _buildStatCard('Net Flow', 'UGX ${widget.fmt.format(_report!['financials']['netFlow'])}', Icons.account_balance_wallet, _report!['financials']['netFlow'] >= 0 ? ModernTheme.success : ModernTheme.error),
            ],
          ),
          const SizedBox(height: 24),

          // Recent transactions
          Container(
            padding: const EdgeInsets.all(24),
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
                  'Recent Transactions',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if ((_report!['recentTransactions'] as List).isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No transactions found',
                        style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ...(_report!['recentTransactions'] as List).take(20).map((txn) {
                    return _buildTransactionRow(txn);
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 11, color: ModernTheme.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale();
  }

  Widget _buildTransactionRow(Map<String, dynamic> txn) {
    final type = txn['type'] as String? ?? '';
    IconData icon;
    Color color;

    switch (type) {
      case 'deposit':
        icon = Icons.arrow_downward;
        color = ModernTheme.success;
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        color = ModernTheme.error;
        break;
      case 'transfer':
        icon = Icons.swap_horiz;
        color = ModernTheme.primary;
        break;
      case 'airtime':
      case 'data':
        icon = Icons.phone_android;
        color = ModernTheme.accent;
        break;
      default:
        icon = Icons.receipt;
        color = ModernTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  DateFormat.yMMMd().add_jm().format(txn['timestamp']),
                  style: GoogleFonts.poppins(fontSize: 11, color: ModernTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            'UGX ${widget.fmt.format(txn['amount'])}',
            style: GoogleFonts.robotoMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Member Report Tab
// ═══════════════════════════════════════════════════════════════════════════════
class _MemberReportTab extends StatefulWidget {
  final NumberFormat fmt;
  const _MemberReportTab({required this.fmt});

  @override
  State<_MemberReportTab> createState() => _MemberReportTabState();
}

class _MemberReportTabState extends State<_MemberReportTab> {
  List<Map<String, dynamic>>? _members;
  bool _loading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final members = await ReportService.generateMemberReport();
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredMembers {
    if (_members == null || _searchQuery.isEmpty) return _members ?? [];
    
    final query = _searchQuery.toLowerCase();
    return _members!.where((m) {
      final name = (m['name'] as String? ?? '').toLowerCase();
      final phone = (m['phone'] as String? ?? '').toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: ModernTheme.error),
            const SizedBox(height: 16),
            Text('Error loading members', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMembers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredMembers = _filteredMembers;

    return Column(
      children: [
        // Header with search
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Member Directory',
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${_members?.length ?? 0} members registered',
                          style: GoogleFonts.poppins(fontSize: 14, color: ModernTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_members != null) {
                        final csv = ReportService.exportMembersToCSV(_members!);
                        // Save CSV
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${_members!.length} members exported')),
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search members by name or phone...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
          ),
        ),
        // Member list
        Expanded(
          child: filteredMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No members found' : 'No members match your search',
                        style: GoogleFonts.poppins(fontSize: 16, color: ModernTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMembers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      return _buildMemberCard(member);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ModernTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: ModernTheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member['name'],
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      member['phone'],
                      style: GoogleFonts.poppins(fontSize: 13, color: ModernTheme.textSecondary),
                    ),
                    if (member['email'].isNotEmpty)
                      Text(
                        member['email'],
                        style: GoogleFonts.poppins(fontSize: 12, color: ModernTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              _buildStatusBadge(member['idStatus']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile('Savings', 'UGX ${widget.fmt.format(member['savingsBalance'])}', Icons.savings),
              ),
              Expanded(
                child: _buildInfoTile('Shares', 'UGX ${widget.fmt.format(member['sharesValue'])}', Icons.pie_chart),
              ),
              Expanded(
                child: _buildInfoTile('Wallet', 'UGX ${widget.fmt.format(member['walletBalance'])}', Icons.account_balance_wallet),
              ),
              Expanded(
                child: _buildInfoTile('Loans', '${member['activeLoans']}/${member['totalLoans']}', Icons.credit_card),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'approved':
        color = ModernTheme.success;
        label = 'Verified';
        break;
      case 'pending':
        color = ModernTheme.warning;
        label = 'Pending';
        break;
      case 'rejected':
        color = ModernTheme.error;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Not Submitted';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: ModernTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: ModernTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

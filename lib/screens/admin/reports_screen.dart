import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';

class ReportsScreen extends StatefulWidget {
  final bool embedded;
  const ReportsScreen({super.key, this.embedded = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final fmt = NumberFormat('#,###', 'en_US');

  Map<String, dynamic> _summary = {
    'totalFarmers': 0, 'totalLoans': 0, 'pendingLoans': 0,
    'approvedLoans': 0, 'rejectedLoans': 0, 'paidLoans': 0,
    'totalDisbursed': 0, 'totalRepaid': 0, 'outstanding': 0,
  };
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _repayments = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        FirebaseService.getAllLoansOnce(),
        FirebaseService.getAllRepaymentsOnce(),
        FirebaseService.getAllFarmersOnce(),
      ]);
      final loans = results[0] as List<Map<String, dynamic>>;
      final repayments = results[1] as List<Map<String, dynamic>>;
      final farmers = results[2] as List<Map<String, dynamic>>;

      int pending = 0, approved = 0, rejected = 0, paid = 0;
      int totalDisbursed = 0, totalRepaid = 0;
      for (final d in loans) {
        final status = d['status'] as String? ?? '';
        final amount = (d['amount'] as num?)?.toInt() ?? 0;
        if (status == AppConstants.statusPending) pending++;
        if (status == AppConstants.statusApproved) { approved++; totalDisbursed += amount; }
        if (status == AppConstants.statusRejected) rejected++;
        if (status == AppConstants.statusPaid) { paid++; totalDisbursed += amount; }
      }
      for (final d in repayments) {
        totalRepaid += (d['amount'] as num?)?.toInt() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _summary = {
          'totalFarmers': farmers.length,
          'totalLoans': loans.length,
          'pendingLoans': pending,
          'approvedLoans': approved,
          'rejectedLoans': rejected,
          'paidLoans': paid,
          'totalDisbursed': totalDisbursed,
          'totalRepaid': totalRepaid,
          'outstanding': totalDisbursed - totalRepaid,
        };
        _loans = loans;
        _repayments = repayments;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Loans'),
            Tab(text: 'Repayments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(summary: _summary, fmt: fmt),
          _LoansTab(summary: _summary, fmt: fmt, loans: _loans),
          _RepaymentsTab(summary: _summary, fmt: fmt, repayments: _repayments),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> summary;
  final NumberFormat fmt;
  const _OverviewTab({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final disbursed = summary['totalDisbursed'] as int;
    final repaid = summary['totalRepaid'] as int;
    final outstanding = summary['outstanding'] as int;
    final totalLoans = summary['totalLoans'] as int;
    final approved = summary['approvedLoans'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinanceCard(label: 'Total Disbursed', value: 'UGX ${fmt.format(disbursed)}',
              icon: Icons.trending_up_rounded, color: AppTheme.primary),
          const SizedBox(height: 10),
          _FinanceCard(label: 'Total Repaid', value: 'UGX ${fmt.format(repaid)}',
              icon: Icons.check_circle_rounded, color: AppTheme.success),
          const SizedBox(height: 10),
          _FinanceCard(label: 'Outstanding Balance',
              value: 'UGX ${fmt.format(outstanding < 0 ? 0 : outstanding)}',
              icon: Icons.account_balance_rounded, color: AppTheme.warning),
          const SizedBox(height: 20),
          SectionHeader(title: 'Key Metrics'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: StatCard(title: 'Total Farmers', value: '${summary['totalFarmers']}',
                icon: Icons.people_rounded, color: AppTheme.info)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(title: 'Total Loans', value: '$totalLoans',
                icon: Icons.account_balance_wallet_rounded, color: AppTheme.primary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: StatCard(
                title: 'Repayment Rate',
                value: disbursed > 0 ? '${((repaid / disbursed) * 100).toStringAsFixed(1)}%' : '0%',
                icon: Icons.pie_chart_rounded, color: AppTheme.success)),
            const SizedBox(width: 12),
            Expanded(child: StatCard(
                title: 'Approval Rate',
                value: totalLoans > 0 ? '${((approved / totalLoans) * 100).toStringAsFixed(1)}%' : '0%',
                icon: Icons.verified_rounded, color: AppTheme.accent)),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Loans Tab ────────────────────────────────────────────────────────────────
class _LoansTab extends StatelessWidget {
  final Map<String, dynamic> summary;
  final NumberFormat fmt;
  final List<Map<String, dynamic>> loans;
  const _LoansTab({required this.summary, required this.fmt, required this.loans});

  @override
  Widget build(BuildContext context) {
    final approved = summary['approvedLoans'] as int;
    final pending = summary['pendingLoans'] as int;
    final rejected = summary['rejectedLoans'] as int;
    final paid = summary['paidLoans'] as int;
    final total = summary['totalLoans'] as int;

    final sections = [
      _PieSection(AppTheme.success, approved, 'Approved'),
      _PieSection(AppTheme.warning, pending, 'Pending'),
      _PieSection(AppTheme.error, rejected, 'Rejected'),
      _PieSection(AppTheme.info, paid, 'Paid'),
    ].where((s) => s.value > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Loan Status Distribution'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: total == 0
                ? const EmptyState(message: 'No loan data yet.', icon: Icons.bar_chart_rounded)
                : Column(children: [
                    SizedBox(
                      height: 200,
                      child: PieChart(PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 50,
                        sections: sections.map((s) => PieChartSectionData(
                          color: s.color, value: s.value.toDouble(),
                          title: '${((s.value / total) * 100).toStringAsFixed(0)}%',
                          radius: 55,
                          titleStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        )).toList(),
                      )),
                    ),
                    const SizedBox(height: 16),
                    Wrap(spacing: 16, runSpacing: 8,
                      children: sections.map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('${s.label}: ${s.value}', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                      ])).toList(),
                    ),
                  ]),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Recent Loan Applications'),
          const SizedBox(height: 12),
          ...loans.take(5).map((data) {
            final name = data['memberName'] as String? ?? data['farmerName'] as String? ?? data['memberId'] as String? ?? data['farmerId'] as String? ?? 'Member';
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final status = data['status'] as String? ?? '-';
            final ts = data['createdAt'];
            String dateStr = '-';
            if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('UGX ${fmt.format(amount)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primary)),
                  StatusBadge(status: status),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Repayments Tab ───────────────────────────────────────────────────────────
class _RepaymentsTab extends StatelessWidget {
  final Map<String, dynamic> summary;
  final NumberFormat fmt;
  final List<Map<String, dynamic>> repayments;
  const _RepaymentsTab({required this.summary, required this.fmt, required this.repayments});

  @override
  Widget build(BuildContext context) {
    final totalRepaid = summary['totalRepaid'] as int;
    final outstanding = summary['outstanding'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FinanceCard(label: 'Total Repaid', value: 'UGX ${fmt.format(totalRepaid)}',
              icon: Icons.payments_rounded, color: AppTheme.success),
          const SizedBox(height: 10),
          _FinanceCard(label: 'Outstanding', value: 'UGX ${fmt.format(outstanding < 0 ? 0 : outstanding)}',
              icon: Icons.hourglass_bottom_rounded, color: AppTheme.warning),
          const SizedBox(height: 20),
          SectionHeader(title: 'Recent Repayments'),
          const SizedBox(height: 12),
          repayments.isEmpty
              ? const EmptyState(message: 'No repayments recorded yet.', icon: Icons.payments_outlined)
              : Column(children: repayments.take(10).map((data) {
                  final name = data['memberName'] as String? ?? data['farmerName'] as String? ?? data['memberId'] as String? ?? data['farmerId'] as String? ?? 'Member';
                  final amount = (data['amount'] as num?)?.toInt() ?? 0;
                  final ts = data['paidAt'];
                  String dateStr = '-';
                  if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                    child: Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.payments_rounded, color: AppTheme.success, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                      ])),
                      Text('UGX ${fmt.format(amount)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.success)),
                    ]),
                  );
                }).toList()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _FinanceCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _FinanceCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
      ]),
    );
  }
}

class _PieSection {
  final Color color;
  final int value;
  final String label;
  const _PieSection(this.color, this.value, this.label);
}

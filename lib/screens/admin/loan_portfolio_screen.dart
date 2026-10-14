import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/loan_portfolio_service.dart';
import '../../theme/modern_theme.dart';
import 'loan_360_screen.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────
double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

Color _severityColor(int days) {
  if (days <= 30) return const Color(0xFFF59E0B);
  if (days <= 60) return const Color(0xFFEF4444);
  return const Color(0xFF9B1C1C);
}

String _severityLabel(int days) {
  if (days <= 30) return 'Mild';
  if (days <= 60) return 'Serious';
  return 'Critical';
}

BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor ?? const Color(0xFFE8ECF2)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1F2937).withOpacity(0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

// ─── Screen ───────────────────────────────────────────────────────────────────
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
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(128),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [ModernTheme.primary, ModernTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: ModernTheme.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      if (!widget.embedded)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Loan Portfolio',
                                style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            Text('Monitor repayments & risk',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    labelColor: ModernTheme.primary,
                    unselectedLabelColor: Colors.white,
                    labelStyle: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                    unselectedLabelStyle:
                        GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(height: 38, text: 'Overview'),
                      Tab(height: 38, text: 'Overdue'),
                      Tab(height: 38, text: 'Performance'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(fmt: _fmt, onViewAll: () => _tabController.animateTo(1)),
          _OverdueLoansTab(fmt: _fmt),
          _PerformanceTab(fmt: _fmt),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: ModernTheme.textPrimary)),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.primary)),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const _Avatar({required this.name, required this.color, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withOpacity(0.85), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: GoogleFonts.poppins(
            fontSize: size * 0.34, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: ModernTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _OverdueBorrowerCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final NumberFormat fmt;
  final int index;
  final bool compact;
  const _OverdueBorrowerCard({
    required this.loan,
    required this.fmt,
    required this.index,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final days = (loan['daysOverdue'] as num?)?.toInt() ?? 0;
    final color = _severityColor(days);
    final name = (loan['farmerName'] ?? 'Unknown').toString();
    final phone = (loan['farmerPhone'] ?? '').toString();
    final amount = _n(loan['amount']);
    final repaid = _n(loan['totalRepaid']);
    final outstanding = _n(loan['outstanding']);
    final penalty = _n(loan['penalty']);
    final progress = amount > 0 ? (repaid / amount).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Loan360Screen(loanId: loan['id'], loanData: loan),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _cardDecoration(borderColor: color.withOpacity(0.25)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Avatar(name: name, color: color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: ModernTheme.textPrimary)),
                                if (phone.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(Icons.phone_rounded,
                                          size: 12, color: ModernTheme.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(phone,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              color: ModernTheme.textSecondary)),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Text('$days days',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: color)),
                                Text(_severityLabel(days),
                                    style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: color)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFEDF0F5),
                            valueColor: AlwaysStoppedAnimation(ModernTheme.success),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('${(progress * 100).toStringAsFixed(0)}% repaid',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: ModernTheme.textSecondary)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _detail('Loan Amount', 'UGX ${fmt.format(amount)}')),
                            Expanded(child: _detail('Repaid', 'UGX ${fmt.format(repaid)}')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                                child: _detail(
                                    'Outstanding', 'UGX ${fmt.format(outstanding)}', color)),
                            Expanded(
                                child: _detail('Penalty', 'UGX ${fmt.format(penalty)}',
                                    ModernTheme.error)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total due (incl. penalty)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12.5, fontWeight: FontWeight.w500)),
                              Text('UGX ${fmt.format(outstanding + penalty)}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total due',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: ModernTheme.textSecondary)),
                            Text('UGX ${fmt.format(outstanding + penalty)}',
                                style: GoogleFonts.poppins(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _detail(String label, String value, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(fontSize: 11, color: ModernTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: color ?? ModernTheme.textPrimary)),
      ],
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  final NumberFormat fmt;
  final VoidCallback onViewAll;
  const _OverviewTab({required this.fmt, required this.onViewAll});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _overdue = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      LoanPortfolioService.getPortfolioSummary(),
      LoanPortfolioService.getOverdueLoans(),
    ]);
    if (mounted) {
      setState(() {
        _summary = results[0] as Map<String, dynamic>?;
        _overdue = List<Map<String, dynamic>>.from(results[1] as List);
        _overdue.sort((a, b) =>
            ((b['daysOverdue'] as num?) ?? 0).compareTo((a['daysOverdue'] as num?) ?? 0));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = _summary;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (_loading && s == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (s != null) ...[
            _heroCard(s),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _metric('Total Loans', '${s['totalLoans']}', Icons.assignment_rounded,
                    ModernTheme.info, 0),
                _metric('Active', '${s['activeLoans']}', Icons.trending_up_rounded,
                    ModernTheme.primary, 1),
                _metric('Overdue', '${s['overdueLoans']}', Icons.warning_amber_rounded,
                    ModernTheme.error, 2),
                _metric('Completed', '${s['completedLoans']}', Icons.check_circle_rounded,
                    ModernTheme.success, 3),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ratioCard(
                    'Repayment Rate',
                    _n(s['repaymentRate']),
                    _n(s['repaymentRate']) >= 80 ? ModernTheme.success : ModernTheme.warning,
                    'Target 80%+',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ratioCard(
                    'Portfolio at Risk',
                    _n(s['portfolioAtRisk']),
                    _n(s['portfolioAtRisk']) <= 5 ? ModernTheme.success : ModernTheme.error,
                    'Target <5%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              'Borrowers with Overdue Loans',
              action: _overdue.length > 5 ? 'View all (${_overdue.length})' : null,
              onAction: widget.onViewAll,
            ),
            const SizedBox(height: 10),
            if (_overdue.isEmpty)
              Container(
                decoration: _cardDecoration(),
                child: const _EmptyState(
                  icon: Icons.verified_rounded,
                  title: 'All clear!',
                  subtitle: 'No borrowers are overdue right now.',
                  color: Color(0xFF16A34A),
                ),
              )
            else
              ...List.generate(
                _overdue.length > 5 ? 5 : _overdue.length,
                (i) => _OverdueBorrowerCard(
                    loan: _overdue[i], fmt: widget.fmt, index: i, compact: true),
              ),
          ],
        ],
      ),
    );
  }

  Widget _heroCard(Map<String, dynamic> s) {
    final overdueAmt = _n(s['totalOverdueAmount']);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ModernTheme.primary, ModernTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outstanding Balance',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 4),
          Text('UGX ${widget.fmt.format(_n(s['totalOutstanding']))}',
              style: GoogleFonts.poppins(
                  fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _heroStat('Disbursed', _n(s['totalDisbursed']))),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _heroStat('Repaid', _n(s['totalRepaid'])),
              )),
            ],
          ),
          if (overdueAmt > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB4B4), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Overdue amount',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
                  ),
                  Text('UGX ${widget.fmt.format(overdueAmt)}',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFB4B4))),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _heroStat(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 2),
        Text('UGX ${widget.fmt.format(value)}',
            style: GoogleFonts.poppins(
                fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color, int i) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.w800, color: color, height: 1.1)),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: ModernTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: (i * 70).ms).scale(
        begin: const Offset(0.92, 0.92), end: const Offset(1, 1));
  }

  Widget _ratioCard(String label, double value, Color color, String target) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (value / 100).clamp(0.0, 1.0),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('${value.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(target,
              style: GoogleFonts.poppins(fontSize: 11, color: ModernTheme.textSecondary)),
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
  String _query = '';
  int _filter = 0; // 0 all, 1 = 1-30, 2 = 31-60, 3 = 60+

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
        _overdueLoans.sort((a, b) =>
            ((b['daysOverdue'] as num?) ?? 0).compareTo((a['daysOverdue'] as num?) ?? 0));
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _overdueLoans.where((l) {
      final days = (l['daysOverdue'] as num?)?.toInt() ?? 0;
      final okFilter = switch (_filter) {
        1 => days <= 30,
        2 => days > 30 && days <= 60,
        3 => days > 60,
        _ => true,
      };
      final q = _query.toLowerCase();
      final okQuery = q.isEmpty ||
          (l['farmerName'] ?? '').toString().toLowerCase().contains(q) ||
          (l['farmerPhone'] ?? '').toString().contains(q);
      return okFilter && okQuery;
    }).toList();
  }

  Future<void> _sendReminders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Send Reminders',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Send payment reminder notifications to all ${_overdueLoans.length} members with overdue loans?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    super.build(context);
    final list = _filtered;
    final totalDue = _overdueLoans.fold<double>(
        0, (sum, l) => sum + _n(l['outstanding']) + _n(l['penalty']));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_overdueLoans.length} borrowers overdue',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Total due: UGX ${widget.fmt.format(totalDue)}',
                          style: GoogleFonts.poppins(
                              fontSize: 12.5, color: ModernTheme.textSecondary)),
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
                      : const Icon(Icons.notifications_active_rounded, size: 18),
                  label: Text('Remind', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.warning,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by name or phone',
              hintStyle: GoogleFonts.poppins(fontSize: 14, color: ModernTheme.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8ECF2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8ECF2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ModernTheme.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // Filter chips
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              for (final e in const [
                (0, 'All'),
                (1, '1–30 days'),
                (2, '31–60 days'),
                (3, '60+ days'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.$2,
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _filter == e.$1 ? Colors.white : ModernTheme.textPrimary)),
                    selected: _filter == e.$1,
                    selectedColor: ModernTheme.primary,
                    backgroundColor: Colors.white,
                    showCheckmark: false,
                    side: BorderSide(
                        color: _filter == e.$1 ? ModernTheme.primary : const Color(0xFFE0E5EC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) => setState(() => _filter = e.$1),
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _overdueLoans.isEmpty
                  ? const _EmptyState(
                      icon: Icons.verified_rounded,
                      title: 'No overdue loans!',
                      subtitle: 'All loans are on track',
                      color: Color(0xFF16A34A),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOverdueLoans,
                      child: list.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 60),
                              _EmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No matches',
                                subtitle: 'Try a different name or filter.',
                                color: Color(0xFF6B7280),
                              ),
                            ])
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: list.length,
                              itemBuilder: (context, i) => _OverdueBorrowerCard(
                                  loan: list[i], fmt: widget.fmt, index: i),
                            ),
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
    super.build(context);
    final m = _metrics;

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (_loading && m == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (m != null) ...[
            const _SectionTitle('Overdue Loans by Age'),
            const SizedBox(height: 12),
            _agingCard(m['overdueBreakdown'] as Map<String, dynamic>),
            const SizedBox(height: 24),
            const _SectionTitle('Key Indicators'),
            const SizedBox(height: 12),
            _kpiCard(
              'Repayment Rate',
              _n(m['repaymentRate']),
              _n(m['repaymentRate']) >= 80 ? ModernTheme.success : ModernTheme.warning,
              'Target: 80%+',
              Icons.payments_rounded,
              0,
            ),
            const SizedBox(height: 12),
            _kpiCard(
              'Portfolio at Risk',
              _n(m['portfolioAtRisk']),
              _n(m['portfolioAtRisk']) <= 5 ? ModernTheme.success : ModernTheme.error,
              'Target: <5%',
              Icons.shield_rounded,
              1,
            ),
            const SizedBox(height: 12),
            _kpiCard(
              'Active Loan Recovery',
              _n(m['activeLoans']) > 0
                  ? (_n(m['activeLoans']) - _n(m['overdueLoans'])) / _n(m['activeLoans']) * 100
                  : 0,
              ModernTheme.info,
              'Share of active loans not overdue',
              Icons.replay_circle_filled_rounded,
              2,
            ),
          ],
        ],
      ),
    );
  }

  Color _bucketColor(String key) {
    if (key.contains('1-30')) return const Color(0xFFF59E0B);
    if (key.contains('31-60')) return const Color(0xFFEF4444);
    if (key.contains('61-90')) return const Color(0xFFFF4500);
    return const Color(0xFF9B1C1C);
  }

  Widget _agingCard(Map<String, dynamic> breakdown) {
    final total = breakdown.values.fold<int>(0, (s, v) => s + ((v as num?)?.toInt() ?? 0));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: breakdown.entries.where((e) => ((e.value as num?) ?? 0) > 0).map((e) {
                    return Expanded(
                      flex: (e.value as num).toInt(),
                      child: Container(color: _bucketColor(e.key)),
                    );
                  }).toList(),
                ),
              ),
            ),
          if (total > 0) const SizedBox(height: 18),
          ...breakdown.entries.map((entry) {
            final count = (entry.value as num?)?.toInt() ?? 0;
            final color = _bucketColor(entry.key);
            final pct = total > 0 ? count / total * 100 : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(entry.key, style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: ModernTheme.textSecondary)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$count loans',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _kpiCard(
      String title, double value, Color color, String subtitle, IconData icon, int i) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11.5, color: ModernTheme.textSecondary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (value / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text('${value.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (i * 80).ms).slideX(begin: 0.1, end: 0);
  }
}
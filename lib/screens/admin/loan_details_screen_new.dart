import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../services/loan_disbursement_service.dart';
import '../../services/loan_actions_service.dart';
import '../../services/arrears_service.dart';
import '../../services/teller_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static const navy = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const text = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF1F5F9);
  static const bg = Color(0xFFF8FAFC);
  static const green = Color(0xFF059669);
  static const red = Color(0xFFDC2626);
  static const amber = Color(0xFFD97706);
  static const purple = Color(0xFF7C3AED);
  static const teal = Color(0xFF0F766E);
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
}

class _LedgerRow {
  final Map<String, dynamic> txn;
  final bool isPay;
  final double p, i, c;
  final double balP, balI, balC;
  _LedgerRow(this.txn, this.isPay, this.p, this.i, this.c, this.balP, this.balI, this.balC);
}

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic>? initialLoanData;

  const LoanDetailsScreen({
    Key? key,
    required this.loanId,
    this.initialLoanData,
  }) : super(key: key);

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  late TabController _tabController;
  final ScrollController _cardScroll = ScrollController();
  Map<String, dynamic>? _loanData;
  Map<String, dynamic>? _arrearsData;
  Future<List<Map<String, dynamic>>>? _cardFuture;
  bool _isLoading = true;

  // Loan-card column flex: disbursements(5) | repayments(5) | balance(3 + action)
  static const _lf = [3, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 1];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loanData = widget.initialLoanData;
    _loadLoanData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cardScroll.dispose();
    super.dispose();
  }

  // ─── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadLoanData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // Always fetch fresh data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.loansCol)
          .doc(widget.loanId)
          .get();

      if (doc.exists) {
        _loanData = {'id': doc.id, ...doc.data()!};
      }

      Map<String, dynamic>? arrears;
      try {
        arrears = await ArrearsService.calculateLoanArrears(widget.loanId);
      } catch (e) {
        print('Arrears calculation failed: $e');
      }

      if (!mounted) return;
      setState(() {
        _arrearsData = arrears;
        _cardFuture = _loanData == null ? null : _loadLoanCardTransactions();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading loan: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Small helpers ──────────────────────────────────────────────────────────
  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _C.text, double? ls}) {
    return GoogleFonts.inter(
        fontSize: size, fontWeight: w, color: c, letterSpacing: ls);
  }

  double _n(String key, [double fallback = 0]) {
    final v = _loanData?[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  double _toD(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _s(String key, [String fallback = 'N/A']) {
    final v = _loanData?[key];
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  String _money(double v) => _currencyFormat.format(v.round());

  String get _uid => FirebaseService.sessionUid;

  String get _actorName =>
      (FirebaseService.sessionProfile?['name'] ?? 'Teller').toString();

  String get _status => _s('status');

  bool get _isActive {
    final s = _status.toLowerCase();
    return s == 'disbursed' || s == 'active' || s == 'overdue';
  }

  bool get _isApproved => _status.toLowerCase() == 'approved';

  DateTime? _toDate(dynamic d) {
    if (d is Timestamp) return d.toDate();
    if (d is DateTime) return d;
    return null;
  }

  String _formatDate(dynamic date) {
    final d = _toDate(date);
    return d == null ? 'N/A' : DateFormat('MMM dd, yyyy').format(d);
  }

  String _getTenureLabel() {
    final frequency = (_loanData?['paymentFrequency'] ?? 'monthly').toString();
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 'Days';
      case 'weekly':
        return 'Weeks';
      case 'monthly':
      default:
        return 'Months';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.blue;
      case 'disbursed':
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'overdue':
        return Colors.red;
      case 'paid':
      case 'closed':
        return Colors.teal;
      case 'written off':
      case 'written_off':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? _C.green : _C.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Controllers can't be disposed while a dialog is still animating out.
  void _disposeLater(List<TextEditingController> ctrls) {
    Future.delayed(const Duration(milliseconds: 500), () {
      for (final c in ctrls) {
        c.dispose();
      }
    });
  }

  Widget _statusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: _t(11, w: FontWeight.w700, c: Colors.white, ls: 0.6),
      ),
    );
  }

  Widget _card({
    String? title,
    IconData? icon,
    Widget? trailing,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: _C.navy),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title,
                        style: _t(15, w: FontWeight.w700, c: _C.ink)),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            const Divider(height: 1, color: _C.line),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  Widget _kv(String label, String value,
      {Color? valueColor, bool bold = false, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: _t(13, c: _C.muted)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: _t(13,
                  w: bold ? FontWeight.w700 : FontWeight.w500,
                  c: valueColor ?? _C.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, [String? subtitle]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: _C.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: _C.muted),
            ),
            const SizedBox(height: 16),
            Text(title, style: _t(16, w: FontWeight.w600, c: _C.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center, style: _t(13, c: _C.muted)),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loanData == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _C.navy,
          foregroundColor: Colors.white,
          title: const Text('Loan Details'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _emptyState(Icons.search_off_rounded, 'Loan not found',
                'This loan may have been removed.'),
      );
    }

    final memberName = _s('memberName');
    final accountNumber = _s('accountNumber');
    final wide = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _C.navy,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(16, w: FontWeight.w700, c: Colors.white),
            ),
            Text(
              'A/C: $accountNumber',
              style: _t(12, c: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_isApproved)
            wide
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: _showDisburseLoanDialog,
                      icon: const Icon(Icons.attach_money, size: 18),
                      label: Text('DISBURSE LOAN',
                          style: _t(13, w: FontWeight.w700, c: Colors.white)),
                      style: _primaryBtn(),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.attach_money),
                    tooltip: 'Disburse Loan',
                    onPressed: _showDisburseLoanDialog,
                  ),
          if (_isActive) ...[
            wide
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ElevatedButton.icon(
                      onPressed: () => _showRecordPaymentDialog(),
                      icon: const Icon(Icons.payment, size: 18),
                      label: Text('RECORD PAYMENT',
                          style: _t(13, w: FontWeight.w700, c: Colors.white)),
                      style: _primaryBtn(),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.payment),
                    tooltip: 'Record Payment',
                    onPressed: () => _showRecordPaymentDialog(),
                  ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'reschedule':
                    _showRescheduleLoanDialog();
                    break;
                  case 'topup':
                    _showTopUpDialog();
                    break;
                  case 'waive':
                    _showWaiveInterestDialog();
                    break;
                  case 'writeoff':
                    _showWriteOffDialog();
                    break;
                  case 'close':
                    _showCloseLoanDialog();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'reschedule',
                  child: Row(children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 12),
                    Text('Reschedule Loan'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'topup',
                  child: Row(children: [
                    Icon(Icons.arrow_upward, size: 20),
                    SizedBox(width: 12),
                    Text('Loan Top-Up'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'waive',
                  child: Row(children: [
                    Icon(Icons.money_off, size: 20),
                    SizedBox(width: 12),
                    Text('Waive Interest'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'writeoff',
                  child: Row(children: [
                    Icon(Icons.cancel, size: 20),
                    SizedBox(width: 12),
                    Text('Write Off'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'close',
                  child: Row(children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 12),
                    Text('Close Loan'),
                  ]),
                ),
              ],
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: _t(14, w: FontWeight.w600, c: Colors.white),
          unselectedLabelStyle: _t(14, c: Colors.white70),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Transactions'),
            Tab(text: 'Schedule'),
            Tab(text: 'Repayments'),
            Tab(text: 'Charges'),
            Tab(text: 'Guarantors'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildTransactionsTab(),
                _buildScheduleTab(),
                _buildTransactionsTab(), // Repayments (same data for now)
                _buildChargesTab(),
                _buildGuarantorsTab(),
                _buildDocumentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _primaryBtn() => ElevatedButton.styleFrom(
        backgroundColor: _C.green,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSummaryTab() {
    final principal = _n('loanAmount', _n('amount'));
    final interest = _n('interestAmount');
    final charges = _n('charges');
    final total = principal + interest + charges;

    final principalPaid = _n('principalPaid');
    final interestPaid = _n('interestPaid');
    final chargesPaid = _n('chargesPaid');
    final totalPaid = principalPaid + interestPaid + chargesPaid;

    final principalOut = _n('principalOutstanding', principal - principalPaid);
    final interestOut = _n('interestOutstanding', interest - interestPaid);
    final chargesOut = charges - chargesPaid;
    final totalOut = principalOut + interestOut + chargesOut;

    final arrears = _n('arrears',
        (_arrearsData?['arrearsAmount'] as num?)?.toDouble() ?? 0);

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        final pad = c.maxWidth >= 700 ? 24.0 : 12.0;

        final left = Column(
          children: [
            _buildDetailsCard(principal),
            if (_loanData!['purpose'] != null ||
                _loanData!['description'] != null) ...[
              const SizedBox(height: 16),
              _buildAdditionalCard(),
            ],
          ],
        );

        final right = Column(
          children: [
            _buildBreakdownCard(
              principal, interest, charges,
              principalPaid, interestPaid, chargesPaid,
              principalOut, interestOut, chargesOut, totalOut, arrears,
            ),
            if (_loanData!['disbursedAt'] != null ||
                _loanData!['disbursementDate'] != null) ...[
              const SizedBox(height: 16),
              _buildDisbursementCard(),
            ],
          ],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(totalOut, total, totalPaid),
                  const SizedBox(height: 16),
                  _buildKpis([
                    _Kpi('Loan Amount', 'UGX ${_money(principal)}',
                        Icons.account_balance_wallet_outlined, _C.blue),
                    _Kpi('Total Repaid', 'UGX ${_money(totalPaid)}',
                        Icons.task_alt_rounded, _C.green),
                    _Kpi('Outstanding', 'UGX ${_money(totalOut)}',
                        Icons.hourglass_bottom_rounded, _C.amber),
                    _Kpi(
                        'Arrears',
                        'UGX ${_money(arrears)}',
                        Icons.warning_amber_rounded,
                        arrears > 0 ? _C.red : _C.muted),
                  ]),
                  if (_isActive || _isApproved) ...[
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                  ],
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: right),
                      ],
                    )
                  else ...[
                    left,
                    const SizedBox(height: 16),
                    right,
                  ],
                  const SizedBox(height: 16),
                  _buildLoanCardSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(double outstanding, double total, double totalPaid) {
    final name = _s('memberName');
    final progress =
        total > 0 ? (totalPaid / total).clamp(0.0, 1.0).toDouble() : 0.0;

    final member = Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white24,
          child: Text(_initials(name),
              style: _t(18, w: FontWeight.w700, c: Colors.white)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(20, w: FontWeight.w700, c: Colors.white)),
              const SizedBox(height: 4),
              Text(
                'A/C: ${_s('accountNumber')}  •  Member ID: ${_s('memberId')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(12.5, c: Colors.white70),
              ),
              const SizedBox(height: 8),
              _statusPill(_status),
            ],
          ),
        ),
      ],
    );

    final balance = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('OUTSTANDING BALANCE',
            style: _t(11, w: FontWeight.w600, c: Colors.white70, ls: 1)),
        const SizedBox(height: 4),
        Text('UGX ${_money(outstanding)}',
            style: _t(28, w: FontWeight.w800, c: Colors.white)),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth >= 640) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [Expanded(child: member), const SizedBox(width: 16), balance],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  member,
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerLeft, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('OUTSTANDING BALANCE',
                          style: _t(11, w: FontWeight.w600, c: Colors.white70, ls: 1)),
                      const SizedBox(height: 4),
                      Text('UGX ${_money(outstanding)}',
                          style: _t(26, w: FontWeight.w800, c: Colors.white)),
                    ],
                  )),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Repayment progress', style: _t(12, c: Colors.white70)),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: _t(12, w: FontWeight.w700, c: Colors.white)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis(List<_Kpi> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((k) {
            return SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: k.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(k.icon, size: 20, color: k.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.label, style: _t(12, c: _C.muted)),
                          const SizedBox(height: 3),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(k.value,
                                style: _t(17,
                                    w: FontWeight.w700,
                                    c: k.color == _C.muted ? _C.ink : k.color)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: _t(13, w: FontWeight.w600, c: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildQuickActions() {
    final buttons = <Widget>[
      if (_isApproved)
        _actionBtn('Disburse Loan', Icons.attach_money, _C.green,
            _showDisburseLoanDialog),
      if (_isActive) ...[
        _actionBtn('Online Repayment', Icons.credit_card, _C.green,
            () => _showRecordPaymentDialog(initialMethod: 'Mobile Money')),
        _actionBtn('Loan Top-Up', Icons.arrow_upward, _C.blue, _showTopUpDialog),
        _actionBtn('Reschedule Loan', Icons.schedule, _C.amber,
            _showRescheduleLoanDialog),
        _actionBtn('Interest Waive Off', Icons.money_off, _C.purple,
            _showWaiveInterestDialog),
        _actionBtn('Write Off', Icons.cancel_outlined, _C.red, _showWriteOffDialog),
        _actionBtn('Close Loan', Icons.check_circle_outline, _C.teal,
            _showCloseLoanDialog),
      ],
    ];
    return _card(
      title: 'Quick Actions',
      icon: Icons.bolt_rounded,
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 10, runSpacing: 10, children: buttons),
    );
  }

  Widget _buildDetailsCard(double principal) {
    return _card(
      title: 'Loan Details',
      icon: Icons.description_outlined,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        children: [
          _kv('Client / Member', _s('memberName')),
          _kv('Member ID', _s('memberId')),
          _kv('Account Number', _s('accountNumber')),
          _kv('Status', _status,
              valueColor: _getStatusColor(_status), bold: true),
          _kv('Disbursement Date',
              _formatDate(_loanData!['disbursementDate'] ?? _loanData!['disbursedAt'])),
          _kv('Branch', _s('branch', 'Main Branch')),
          _kv('Loan Amount (UGX)', _money(principal), bold: true),
          _kv('Nominal Interest Rate',
              '${_s('interestRate', '0')}% per ${_s('paymentFrequency', 'month')}'),
          _kv('Loan Officer',
              _loanData!['loanOfficer']?.toString() ?? _s('approvedBy')),
          _kv('Tenure', '${_s('duration', '0')} ${_getTenureLabel()}'),
          _kv('Loan Type', _s('loanType'), last: true),
        ],
      ),
    );
  }

  Widget _buildAdditionalCard() {
    return _card(
      title: 'Additional Information',
      icon: Icons.notes_rounded,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        children: [
          if (_loanData!['purpose'] != null) _kv('Purpose', _s('purpose')),
          _kv('Description', _s('description'), last: true),
        ],
      ),
    );
  }

  Widget _buildDisbursementCard() {
    final dest = _s('destinationType', 'Cash');
    return _card(
      title: 'Disbursement Details',
      icon: Icons.outbox_rounded,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Column(
        children: [
          _kv('Destination',
              dest.isEmpty ? dest : dest[0].toUpperCase() + dest.substring(1)),
          _kv('Reference', _s('referenceNumber')),
          _kv('Disbursed By', _s('disbursedBy')),
          _kv('Date',
              _formatDate(_loanData!['disbursedAt'] ?? _loanData!['disbursementDate']),
              last: true),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    double principal, double interest, double charges,
    double pPaid, double iPaid, double cPaid,
    double pOut, double iOut, double cOut, double tOut, double arrears,
  ) {
    TableRow header() => TableRow(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.line))),
          children: ['', 'Expected', 'Paid', 'Outstanding']
              .map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(h,
                        textAlign: h.isEmpty ? TextAlign.left : TextAlign.right,
                        style: _t(11.5, w: FontWeight.w600, c: _C.muted)),
                  ))
              .toList(),
        );

    TableRow row(String label, double exp, double paid, double out,
        {bool bold = false, bool top = false}) {
      TextStyle st(Color c) =>
          _t(13, w: bold ? FontWeight.w700 : FontWeight.w500, c: c);
      Widget cell(String text, Color c, {bool left = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(text,
                textAlign: left ? TextAlign.left : TextAlign.right,
                style: st(c)),
          );
      return TableRow(
        decoration: BoxDecoration(
          border: top ? const Border(top: BorderSide(color: _C.line)) : null,
        ),
        children: [
          cell(label, _C.ink, left: true),
          cell(_money(exp), _C.ink),
          cell(_money(paid), _C.green),
          cell(_money(out), out > 0 ? _C.red : _C.ink),
        ],
      );
    }

    return _card(
      title: 'Balance Breakdown',
      icon: Icons.account_balance_outlined,
      child: Column(
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.3),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.1),
              3: FlexColumnWidth(1.3),
            },
            children: [
              header(),
              row('Principal', principal, pPaid, pOut),
              row('Interest', interest, iPaid, iOut),
              row('Charges', charges, cPaid, cOut),
              row('Total', principal + interest + charges,
                  pPaid + iPaid + cPaid, tOut,
                  bold: true, top: true),
            ],
          ),
          if (arrears > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: _C.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Arrear Balance',
                        style: _t(13, w: FontWeight.w600, c: _C.red)),
                  ),
                  Text('UGX ${_money(arrears)}',
                      style: _t(15, w: FontWeight.w800, c: _C.red)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Loan card (ledger) ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _loadLoanCardTransactions() async {
    final List<Map<String, dynamic>> transactions = [];
    final loan = _loanData!;

    // 1. Disbursement
    if (loan['disbursedAt'] != null || loan['disbursementDate'] != null) {
      transactions.add({
        'date': loan['disbursedAt'] ?? loan['disbursementDate'],
        'type': 'Disbursement',
        'principal': loan['loanAmount'] ?? loan['amount'] ?? 0,
        'interest': loan['interestAmount'] ?? 0,
        'charges': loan['charges'] ?? 0,
      });
    }

    // 2. Repayments
    final paymentsSnapshot = await FirebaseFirestore.instance
        .collection(AppConstants.repaymentsCol)
        .where('loanId', isEqualTo: widget.loanId)
        .get();

    for (var doc in paymentsSnapshot.docs) {
      final data = doc.data();
      transactions.add({
        'date': data['paymentDate'],
        'type': 'Payment',
        'principal': data['principalAmount'] ?? 0,
        'interest': data['interestAmount'] ?? 0,
        'charges': data['chargesAmount'] ?? 0,
        'paymentMethod': data['paymentMethod'] ?? 'Cash',
        'transactionId': data['mobileMoneyTransactionId'],
      });
    }

    // 3. Top-ups
    final topupsSnapshot = await FirebaseFirestore.instance
        .collection('loan-transactions')
        .where('loanId', isEqualTo: widget.loanId)
        .where('type', isEqualTo: 'Top-up')
        .get();

    for (var doc in topupsSnapshot.docs) {
      final data = doc.data();
      transactions.add({
        'date': data['createdAt'],
        'type': 'Top-up',
        'principal': data['amount'] ?? 0,
        'interest': data['interestAmount'] ?? 0,
        'charges': data['charges'] ?? 0,
      });
    }

    transactions.sort((a, b) {
      final aDate = _toDate(a['date']) ?? DateTime.now();
      final bDate = _toDate(b['date']) ?? DateTime.now();
      return aDate.compareTo(bDate);
    });

    return transactions;
  }

  Widget _buildLoanCardSection() {
    return _card(
      title: 'Loan Card',
      icon: Icons.receipt_long_outlined,
      trailing: _isActive
          ? ElevatedButton.icon(
              onPressed: () => _showRecordPaymentDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('ADD PAYMENT',
                  style: _t(12.5, w: FontWeight.w700, c: Colors.white)),
              style: _primaryBtn(),
            )
          : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Complete transaction history with running balances',
              style: _t(12.5, c: _C.muted)),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _cardFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load transactions: ${snap.error}',
                      style: _t(13, c: _C.red)),
                );
              }
              return _ledgerTable(snap.data ?? []);
            },
          ),
        ],
      ),
    );
  }

  // One ledger cell. idx = column index in _lf
  Widget _lc(int idx, String text,
      {bool isNum = false,
      bool bold = false,
      Color? color,
      Color? bg,
      Widget? child,
      double height = 46,
      TextStyle? style}) {
    final sectionStart = idx == 0 || idx == 5 || idx == 10;
    return Expanded(
      flex: _lf[idx],
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: isNum ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: bg,
          border: sectionStart
              ? const Border(left: BorderSide(color: Color(0xFFCBD5E1), width: 1.5))
              : null,
        ),
        child: child ??
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: style ??
                  _t(12.5,
                      w: bold ? FontWeight.w700 : FontWeight.w500,
                      c: color ?? _C.ink),
            ),
      ),
    );
  }

  Widget _ledgerTable(List<Map<String, dynamic>> txns) {
    double bp = 0, bi = 0, bc = 0;
    double dP = 0, dI = 0, dC = 0;
    double rP = 0, rI = 0, rC = 0;
    final rows = <_LedgerRow>[];

    for (final t in txns) {
      final isPay = (t['type'] ?? '').toString() == 'Payment';
      final p = _toD(t['principal']);
      final i = _toD(t['interest']);
      final c = _toD(t['charges']);
      if (isPay) {
        bp -= p; bi -= i; bc -= c;
        rP += p; rI += i; rC += c;
      } else {
        bp += p; bi += i; bc += c;
        dP += p; dI += i; dC += c;
      }
      rows.add(_LedgerRow(t, isPay, p, i, c, bp, bi, bc));
    }

    String m(double v) => v > 0 ? _money(v) : '';

    Widget balCell(int idx, double v) {
      final owing = v > 0.5;
      return _lc(
        idx,
        owing ? _money(v) : '0',
        isNum: true,
        bold: true,
        color: owing ? _C.red : _C.green,
        bg: owing ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
      );
    }

    Widget groupHeader(String label, int flex, Color bg, Color fg) {
      return Expanded(
        flex: flex,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: const Border(left: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
          ),
          child: Text(label,
              style: _t(12, w: FontWeight.w800, c: fg, ls: 1.2)),
        ),
      );
    }

    final titles = [
      'Date', 'Principal', 'Interest', 'Charges', 'Total',
      'Date', 'Principal', 'Interest', 'Charges', 'Total',
      'Principal', 'Interest', 'Charges', '',
    ];

    final body = <Widget>[
      // Group header
      Row(children: [
        groupHeader('DISBURSEMENTS', 11, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
        groupHeader('REPAYMENTS', 11, const Color(0xFFECFDF5), const Color(0xFF047857)),
        groupHeader('BALANCE', 7, const Color(0xFFFFFBEB), const Color(0xFFB45309)),
      ]),
      // Column header
      Container(
        color: _C.bg,
        decoration: null,
        child: Row(
          children: List.generate(titles.length, (i) {
            return _lc(i, titles[i],
                isNum: i != 0 && i != 5 && i != 13,
                height: 38,
                style: _t(11.5, w: FontWeight.w700, c: _C.muted));
          }),
        ),
      ),
      const Divider(height: 1, color: _C.line),
    ];

    if (rows.isEmpty) {
      body.add(Padding(
        padding: const EdgeInsets.all(28),
        child: Text('No transactions recorded yet',
            style: _t(13, c: _C.muted)),
      ));
    }

    for (var n = 0; n < rows.length; n++) {
      final r = rows[n];
      body.add(Container(
        decoration: BoxDecoration(
          color: n.isEven ? Colors.white : const Color(0xFFFAFBFD),
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          _lc(0, r.isPay ? '' : _formatDate(r.txn['date'])),
          _lc(1, r.isPay ? '' : m(r.p), isNum: true),
          _lc(2, r.isPay ? '' : m(r.i), isNum: true),
          _lc(3, r.isPay ? '' : m(r.c), isNum: true),
          _lc(4, r.isPay ? '' : m(r.p + r.i + r.c), isNum: true, bold: true),
          _lc(5, r.isPay ? _formatDate(r.txn['date']) : ''),
          _lc(6, r.isPay ? m(r.p) : '', isNum: true),
          _lc(7, r.isPay ? m(r.i) : '', isNum: true),
          _lc(8, r.isPay ? m(r.c) : '', isNum: true),
          _lc(9, r.isPay ? m(r.p + r.i + r.c) : '', isNum: true, bold: true),
          balCell(10, r.balP),
          balCell(11, r.balI),
          balCell(12, r.balC),
          _lc(
            13,
            '',
            child: r.isPay
                ? IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.receipt_outlined, size: 18, color: _C.blue),
                    tooltip: 'View receipt',
                    onPressed: () => _showPaymentDetails(r.txn),
                  )
                : const SizedBox(),
          ),
        ]),
      ));
    }

    if (rows.isNotEmpty) {
      body.add(Container(
        color: _C.soft,
        child: Row(children: [
          _lc(0, 'TOTAL', bold: true),
          _lc(1, m(dP), isNum: true, bold: true),
          _lc(2, m(dI), isNum: true, bold: true),
          _lc(3, m(dC), isNum: true, bold: true),
          _lc(4, m(dP + dI + dC), isNum: true, bold: true),
          _lc(5, ''),
          _lc(6, m(rP), isNum: true, bold: true),
          _lc(7, m(rI), isNum: true, bold: true),
          _lc(8, m(rC), isNum: true, bold: true),
          _lc(9, m(rP + rI + rC), isNum: true, bold: true),
          balCell(10, bp),
          balCell(11, bi),
          balCell(12, bc),
          _lc(13, ''),
        ]),
      ));
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth < 1100 ? 1100.0 : c.maxWidth;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Scrollbar(
            controller: _cardScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _cardScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: w,
                child: Column(children: body),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final p = _toD(payment['principal']);
    final i = _toD(payment['interest']);
    final c = _toD(payment['charges']);

    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: _t(13, c: _C.muted)),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: _t(13,
                        w: bold ? FontWeight.w700 : FontWeight.w500,
                        c: _C.ink)),
              ),
            ],
          ),
        );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: _C.green),
            const SizedBox(width: 10),
            Text('Payment Receipt', style: _t(18, w: FontWeight.w700, c: _C.ink)),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row('Date', _formatDate(payment['date'])),
                const Divider(),
                row('Principal Paid', 'UGX ${_money(p)}'),
                row('Interest Paid', 'UGX ${_money(i)}'),
                row('Charges Paid', 'UGX ${_money(c)}'),
                const Divider(),
                row('Total Paid', 'UGX ${_money(p + i + c)}', bold: true),
                const Divider(),
                row('Payment Method', (payment['paymentMethod'] ?? 'N/A').toString()),
                if (payment['transactionId'] != null)
                  row('Transaction ID', payment['transactionId'].toString()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 / 4: TRANSACTIONS & REPAYMENTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      // Same collection the loan card and "Record Payment" use.
      // No orderBy: avoids needing a composite index; sorted below.
      stream: FirebaseFirestore.instance
          .collection(AppConstants.repaymentsCol)
          .where('loanId', isEqualTo: widget.loanId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _emptyState(Icons.error_outline, 'Could not load payments',
              snapshot.error.toString());
        }

        final docs = snapshot.data?.docs.toList() ?? [];
        if (docs.isEmpty) {
          return _emptyState(Icons.receipt_long, 'No transactions recorded',
              'Payments recorded against this loan will appear here.');
        }

        docs.sort((a, b) {
          final ad = _toDate((a.data() as Map<String, dynamic>)['paymentDate']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = _toDate((b.data() as Map<String, dynamic>)['paymentDate']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final txn = docs[index].data() as Map<String, dynamic>;
                final amount = _toD(txn['amount']);
                final p = _toD(txn['principalAmount']);
                final i = _toD(txn['interestAmount']);
                final c = _toD(txn['chargesAmount']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _C.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.payment, color: _C.green),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Loan payment',
                                style: _t(14, w: FontWeight.w600, c: _C.ink)),
                            const SizedBox(height: 3),
                            Text(
                              '${_formatDate(txn['paymentDate'])}  •  ${txn['paymentMethod'] ?? 'Cash'}',
                              style: _t(12, c: _C.muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Principal ${_money(p)}  ·  Interest ${_money(i)}  ·  Charges ${_money(c)}',
                              style: _t(11.5, c: _C.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('UGX ${_money(amount)}',
                          style: _t(16, w: FontWeight.w800, c: _C.green)),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABS 3, 5, 6, 7
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScheduleTab() => _emptyState(Icons.event_note_outlined,
      'Repayment schedule', 'Coming soon.');

  Widget _buildChargesTab() =>
      _emptyState(Icons.request_quote_outlined, 'Charges', 'Coming soon.');

  Widget _buildDocumentsTab() =>
      _emptyState(Icons.folder_open_outlined, 'Documents', 'Coming soon.');

  Widget _buildGuarantorsTab() {
    final guarantors = _loanData!['guarantors'] as List? ?? [];

    if (guarantors.isEmpty) {
      return _emptyState(Icons.people_outline, 'No guarantors added',
          'Guarantors attached to this loan will appear here.');
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: guarantors.length,
          itemBuilder: (context, index) {
            final g = Map<String, dynamic>.from(guarantors[index] as Map);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _C.navy.withOpacity(0.1),
                    child: Text('${index + 1}',
                        style: _t(14, w: FontWeight.w700, c: _C.navy)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((g['name'] ?? 'N/A').toString(),
                            style: _t(14, w: FontWeight.w600, c: _C.ink)),
                        const SizedBox(height: 3),
                        Text('A/C: ${g['account'] ?? 'N/A'}',
                            style: _t(12, c: _C.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Savings', style: _t(11, c: _C.muted)),
                      Text('UGX ${_money(_toD(g['savings']))}',
                          style: _t(14, w: FontWeight.w700, c: _C.ink)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG INFRASTRUCTURE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Runs a service call behind a loading overlay, then shows the result
  /// and refreshes the screen.
  Future<void> _runAction({
    required Future<Map<String, dynamic>> Function() action,
    required String successMessage,
    bool closeScreenOnSuccess = false,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic> result;
    try {
      result = await action();
    } catch (e) {
      result = {'success': false, 'message': 'Error: $e'};
    }

    if (!mounted) return;
    Navigator.pop(context); // close loading overlay

    final ok = result['success'] == true;
    _toast(
      (result['message'] ?? (ok ? successMessage : 'Action failed')).toString(),
      ok,
    );

    if (ok) {
      if (closeScreenOnSuccess) {
        Navigator.of(context).maybePop();
      } else {
        _loadLoanData();
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool number = false,
    int maxLines = 1,
    bool readOnly = false,
    bool enabled = true,
    Color? fill,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    TextStyle? style,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _t(13, w: FontWeight.w600, c: _C.ink)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            readOnly: readOnly,
            enabled: enabled,
            onChanged: onChanged,
            style: style ?? _t(14, c: _C.ink),
            keyboardType: keyboard ?? (number ? TextInputType.number : null),
            inputFormatters: formatters ??
                (number
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                    : null),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: fill != null,
              fillColor: fill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _C.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _C.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _C.blue, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: _t(13, w: FontWeight.w600, c: _C.ink)),
      );

  InputDecoration _dropDecoration({String? hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.line),
        ),
      );

  /// Shared, consistently styled form dialog.
  Future<void> _showFormDialog({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required String submitLabel,
    required Widget Function(StateSetter setS) bodyBuilder,
    required Future<void> Function() onSubmit,
    String? Function()? validate,
    double maxWidth = 520,
  }) {
    String? error;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                  color: color,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: _t(17, w: FontWeight.w700, c: Colors.white)),
                            if (subtitle != null)
                              Text(subtitle,
                                  style: _t(12, c: Colors.white70)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bodyBuilder(setS),
                        if (error != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 18, color: _C.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(error!,
                                      style: _t(12.5, c: _C.red)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  decoration: const BoxDecoration(
                    color: _C.bg,
                    border: Border(top: BorderSide(color: _C.line)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final err = validate?.call();
                          if (err != null) {
                            setS(() => error = err);
                            return;
                          }
                          Navigator.pop(dialogContext);
                          await onSubmit();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(submitLabel,
                            style: _t(13, w: FontWeight.w700, c: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAN ACTION DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showDisburseLoanDialog() async {
    final amountCtrl =
        TextEditingController(text: _n('loanAmount', _n('amount')).round().toString());
    final referenceCtrl = TextEditingController();
    final chequeCtrl = TextEditingController();
    final narrationCtrl =
        TextEditingController(text: 'Loan disbursement for ${_s('memberName')}');
    String destinationType = 'cash';

    await _showFormDialog(
      title: 'Disburse Loan',
      subtitle: _s('memberName'),
      icon: Icons.attach_money,
      color: _C.green,
      submitLabel: 'DISBURSE',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _C.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'A/C: ${_s('accountNumber')}  •  Ref: ${_s('referenceNumber')}',
              style: _t(12.5, c: _C.muted),
            ),
          ),
          _label('Destination Type *'),
          DropdownButtonFormField<String>(
            value: destinationType,
            decoration: _dropDecoration(),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
            ],
            onChanged: (v) {
              if (v != null) setS(() => destinationType = v);
            },
          ),
          const SizedBox(height: 14),
          _field('Amount (UGX) *', amountCtrl, readOnly: true, fill: _C.soft),
          _field('Reference Number', referenceCtrl,
              hint: 'Receipt / transaction number'),
          if (destinationType == 'bank')
            _field('Cheque Number', chequeCtrl, hint: 'Cheque number'),
          _field('Narration / Description', narrationCtrl, maxLines: 3),
        ],
      ),
      validate: () =>
          (double.tryParse(amountCtrl.text) ?? 0) <= 0 ? 'Invalid amount' : null,
      onSubmit: () async {
        final amount = double.tryParse(amountCtrl.text) ?? 0;
        final dest = destinationType;
        final ref = referenceCtrl.text.trim();
        final cheque = chequeCtrl.text.trim();
        final narration = narrationCtrl.text.trim();
        await _runAction(
          action: () => LoanDisbursementService.disburseLoan(
            loanId: widget.loanId,
            destinationType: dest,
            disbursedBy: _uid,
            amount: amount,
            referenceNumber: ref,
            chequeNumber: cheque,
            narration: narration,
          ),
          successMessage: 'Loan disbursed successfully',
        );
      },
    );
    _disposeLater([amountCtrl, referenceCtrl, chequeCtrl, narrationCtrl]);
  }

  Future<void> _showRescheduleLoanDialog() async {
    final durationCtrl =
        TextEditingController(text: (_loanData!['duration'] ?? 12).toString());
    final reasonCtrl = TextEditingController();
    final unit = _getTenureLabel().toLowerCase();

    await _showFormDialog(
      title: 'Reschedule Loan',
      subtitle: 'Current duration: ${_s('duration', '0')} $unit',
      icon: Icons.schedule,
      color: _C.blue,
      submitLabel: 'RESCHEDULE',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('New Duration ($unit) *', durationCtrl,
              number: true, hint: 'Enter new duration'),
          _field('Reason', reasonCtrl,
              maxLines: 3, hint: 'Why is this loan being rescheduled?'),
        ],
      ),
      validate: () =>
          (int.tryParse(durationCtrl.text) ?? 0) <= 0 ? 'Invalid duration' : null,
      onSubmit: () async {
        final newDuration = int.tryParse(durationCtrl.text) ?? 0;
        final reason = reasonCtrl.text.trim();
        await _runAction(
          action: () => LoanActionsService.rescheduleLoan(
            loanId: widget.loanId,
            newDuration: newDuration,
            rescheduledBy: _uid,
            reason: reason,
          ),
          successMessage: 'Loan rescheduled',
        );
      },
    );
    _disposeLater([durationCtrl, reasonCtrl]);
  }

  Future<void> _showTopUpDialog() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    await _showFormDialog(
      title: 'Loan Top-Up',
      subtitle: 'Current loan: UGX ${_money(_n('loanAmount'))}',
      icon: Icons.arrow_upward,
      color: _C.blue,
      submitLabel: 'TOP UP',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Top-Up Amount (UGX) *', amountCtrl,
              number: true, hint: 'Enter additional amount'),
          _field('Reason', reasonCtrl, maxLines: 3, hint: 'Reason for top-up'),
        ],
      ),
      validate: () =>
          (double.tryParse(amountCtrl.text) ?? 0) <= 0 ? 'Invalid amount' : null,
      onSubmit: () async {
        final amount = double.tryParse(amountCtrl.text) ?? 0;
        final reason = reasonCtrl.text.trim();
        await _runAction(
          action: () => LoanActionsService.topUpLoan(
            loanId: widget.loanId,
            topUpAmount: amount,
            approvedBy: _uid,
            reason: reason,
          ),
          successMessage: 'Loan topped up',
        );
      },
    );
    _disposeLater([amountCtrl, reasonCtrl]);
  }

  Future<void> _showWaiveInterestDialog() async {
    final interestOutstanding = _n('interestOutstanding');
    final amountCtrl =
        TextEditingController(text: interestOutstanding.round().toString());
    final reasonCtrl = TextEditingController();

    await _showFormDialog(
      title: 'Waive Interest',
      subtitle: 'Outstanding interest: UGX ${_money(interestOutstanding)}',
      icon: Icons.money_off,
      color: _C.purple,
      submitLabel: 'WAIVE',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Waive Amount (UGX) *', amountCtrl,
              number: true, hint: 'Enter amount to waive'),
          _field('Reason *', reasonCtrl,
              maxLines: 3, hint: 'Why is interest being waived?'),
        ],
      ),
      validate: () {
        if ((double.tryParse(amountCtrl.text) ?? 0) <= 0) return 'Invalid amount';
        if (reasonCtrl.text.trim().isEmpty) return 'Reason is required';
        return null;
      },
      onSubmit: () async {
        final amount = double.tryParse(amountCtrl.text) ?? 0;
        final reason = reasonCtrl.text.trim();
        await _runAction(
          action: () => LoanActionsService.waiveInterest(
            loanId: widget.loanId,
            waiveAmount: amount,
            waivedBy: _uid,
            reason: reason,
          ),
          successMessage: 'Interest waived',
        );
      },
    );
    _disposeLater([amountCtrl, reasonCtrl]);
  }

  Future<void> _showWriteOffDialog() async {
    final reasonCtrl = TextEditingController();

    await _showFormDialog(
      title: 'Write Off Loan',
      subtitle: _s('memberName'),
      icon: Icons.cancel_outlined,
      color: _C.red,
      submitLabel: 'WRITE OFF',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: _C.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This marks the loan as uncollectable bad debt. This action cannot be undone.',
                    style: _t(12.5, c: const Color(0xFF7F1D1D)),
                  ),
                ),
              ],
            ),
          ),
          _field('Reason *', reasonCtrl,
              maxLines: 4, hint: 'Explain why this loan is being written off'),
        ],
      ),
      validate: () =>
          reasonCtrl.text.trim().isEmpty ? 'Reason is required' : null,
      onSubmit: () async {
        final reason = reasonCtrl.text.trim();
        await _runAction(
          action: () => LoanActionsService.writeOffLoan(
            loanId: widget.loanId,
            writtenOffBy: _uid,
            reason: reason,
          ),
          successMessage: 'Loan written off',
          closeScreenOnSuccess: true,
        );
      },
    );
    _disposeLater([reasonCtrl]);
  }

  Future<void> _showCloseLoanDialog() async {
    final reasonCtrl = TextEditingController();

    await _showFormDialog(
      title: 'Close Loan',
      subtitle: _s('memberName'),
      icon: Icons.check_circle_outline,
      color: _C.teal,
      submitLabel: 'CLOSE LOAN',
      bodyBuilder: (setS) => _field('Reason', reasonCtrl,
          maxLines: 3, hint: 'Why is this loan being closed?'),
      onSubmit: () async {
        final reason = reasonCtrl.text.trim();
        await _runAction(
          action: () => LoanActionsService.closeLoan(
            loanId: widget.loanId,
            closedBy: _uid,
            reason: reason,
          ),
          successMessage: 'Loan closed',
        );
      },
    );
    _disposeLater([reasonCtrl]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECORD PAYMENT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showRecordPaymentDialog({String initialMethod = 'Cash'}) async {
    final principalCtrl = TextEditingController(text: '0');
    final interestCtrl = TextEditingController(text: '0');
    final chargesCtrl = TextEditingController(text: '0');
    final amountCtrl = TextEditingController(text: '0');
    final phoneCtrl = TextEditingController();

    DateTime paymentDate = DateTime.now();
    String paymentMethod = initialMethod;
    String? telecomProvider;
    String? verifiedAccountName;
    String? verifyError;
    bool isVerifying = false;

    final principalOutstanding = _n('principalOutstanding');
    final interestOutstanding = _n('interestOutstanding');

    void updateTotal() {
      final p = double.tryParse(principalCtrl.text) ?? 0;
      final i = double.tryParse(interestCtrl.text) ?? 0;
      final c = double.tryParse(chargesCtrl.text) ?? 0;
      amountCtrl.text = (p + i + c).round().toString();
    }

    Widget amountField(String label, TextEditingController ctrl) => Expanded(
          child: _field(label, ctrl,
              number: true, hint: '0', onChanged: (_) => updateTotal()),
        );

    await _showFormDialog(
      title: 'Record Loan Payment',
      subtitle:
          'Outstanding: Principal UGX ${_money(principalOutstanding)}  |  Interest UGX ${_money(interestOutstanding)}',
      icon: Icons.payment,
      color: _C.green,
      submitLabel: 'RECORD PAYMENT',
      maxWidth: 640,
      bodyBuilder: (setS) {
        Future<void> verifyPhone() async {
          if (phoneCtrl.text.trim().isEmpty || telecomProvider == null) {
            setS(() => verifyError = 'Enter phone number and select provider');
            return;
          }
          setS(() {
            isVerifying = true;
            verifiedAccountName = null;
            verifyError = null;
          });
          try {
            final result = await TellerService.verifyMobileMoneyAccount(
              phoneNumber: phoneCtrl.text.trim(),
              provider: telecomProvider!,
            );
            setS(() {
              isVerifying = false;
              if (result['success'] == true) {
                verifiedAccountName =
                    (result['accountName'] ?? result['full_name'])?.toString();
              } else {
                verifyError =
                    (result['message'] ?? 'Verification failed').toString();
              }
            });
          } catch (e) {
            setS(() {
              isVerifying = false;
              verifyError = 'Error: $e';
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Payment Date'),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setS(() => paymentDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: _C.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: _C.muted),
                    const SizedBox(width: 12),
                    Text(DateFormat('MMM dd, yyyy').format(paymentDate),
                        style: _t(14, c: _C.ink)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('Payment Method'),
            DropdownButtonFormField<String>(
              value: paymentMethod,
              decoration: _dropDecoration(),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
              ],
              onChanged: (v) => setS(() => paymentMethod = v ?? 'Cash'),
            ),
            if (paymentMethod == 'Mobile Money') ...[
              const SizedBox(height: 14),
              _label('Telecom Provider'),
              DropdownButtonFormField<String>(
                value: telecomProvider,
                decoration: _dropDecoration(hint: 'Select provider'),
                items: const [
                  DropdownMenuItem(value: 'MTN', child: Text('MTN Mobile Money')),
                  DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
                ],
                onChanged: (v) => setS(() {
                  telecomProvider = v;
                  verifiedAccountName = null;
                  verifyError = null;
                }),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _label('Customer Phone Number'),
                  if (verifiedAccountName != null)
                    TextButton.icon(
                      onPressed: () => setS(() {
                        phoneCtrl.clear();
                        verifiedAccountName = null;
                      }),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text('New Customer', style: _t(12, c: _C.blue)),
                    ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      enabled: verifiedAccountName == null,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      ],
                      style: _t(14, c: _C.ink),
                      decoration: InputDecoration(
                        hintText: '256700000000',
                        isDense: true,
                        filled: verifiedAccountName != null,
                        fillColor: const Color(0xFFECFDF5),
                        contentPadding: const EdgeInsets.all(13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _C.line),
                        ),
                      ),
                    ),
                  ),
                  if (verifiedAccountName == null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isVerifying ? null : verifyPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isVerifying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('VERIFY'),
                    ),
                  ],
                ],
              ),
              if (verifyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(verifyError!, style: _t(12, c: _C.red)),
                ),
              if (verifiedAccountName != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: _C.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Verified: $verifiedAccountName',
                            style: _t(13, w: FontWeight.w600, c: const Color(0xFF065F46))),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                amountField('Principal Amount', principalCtrl),
                const SizedBox(width: 12),
                amountField('Interest Amount', interestCtrl),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                amountField('Charges Amount', chargesCtrl),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Total Amount', amountCtrl,
                      readOnly: true,
                      fill: const Color(0xFFECFDF5),
                      style: _t(15, w: FontWeight.w800, c: _C.green)),
                ),
              ],
            ),
          ],
        );
      },
      validate: () {
        final total = (double.tryParse(principalCtrl.text) ?? 0) +
            (double.tryParse(interestCtrl.text) ?? 0) +
            (double.tryParse(chargesCtrl.text) ?? 0);
        if (total <= 0) return 'Please enter at least one amount';
        if (paymentMethod == 'Mobile Money' && verifiedAccountName == null) {
          return 'Please verify the phone number first';
        }
        return null;
      },
      onSubmit: () async {
        // Read everything before the dialog controllers are released.
        final principal = double.tryParse(principalCtrl.text) ?? 0;
        final interest = double.tryParse(interestCtrl.text) ?? 0;
        final charges = double.tryParse(chargesCtrl.text) ?? 0;
        final total = principal + interest + charges;
        final method = paymentMethod;
        final provider = telecomProvider;
        final phone = phoneCtrl.text.trim();
        final date = paymentDate;

        try {
          String? transactionId;

          if (method == 'Mobile Money') {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text('Processing Mobile Money Payment',
                    style: _t(16, w: FontWeight.w700, c: _C.ink)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Please approve the payment on the customer\'s phone...',
                        textAlign: TextAlign.center, style: _t(13)),
                    const SizedBox(height: 8),
                    Text('Amount: UGX ${_money(total)}',
                        style: _t(14, w: FontWeight.w700, c: _C.ink)),
                  ],
                ),
              ),
            );

            final paymentResult = await TellerService.requestMobileMoneyPayment(
              phoneNumber: phone,
              amount: total,
              provider: provider ?? 'MTN',
              narration: 'Loan repayment for ${_s('memberName')}',
            );

            if (!mounted) return;
            Navigator.pop(context); // close processing dialog

            if (paymentResult['success'] != true) {
              _toast((paymentResult['message'] ?? 'Payment failed').toString(), false);
              return;
            }
            transactionId = paymentResult['transactionId']?.toString();
          }

          final paymentData = <String, dynamic>{
            'loanId': widget.loanId,
            'paymentDate': Timestamp.fromDate(date),
            'principalAmount': principal,
            'interestAmount': interest,
            'chargesAmount': charges,
            'amount': total,
            'paymentMethod': method,
            'recordedBy': _actorName,
            'createdAt': FieldValue.serverTimestamp(),
          };

          if (method == 'Mobile Money') {
            paymentData['mobileMoneyProvider'] = provider;
            paymentData['mobileMoneyNumber'] = phone;
            paymentData['mobileMoneyTransactionId'] = transactionId;
          }

          await FirebaseFirestore.instance
              .collection(AppConstants.repaymentsCol)
              .add(paymentData);

          // Update loan totals
          await FirebaseFirestore.instance
              .collection(AppConstants.loansCol)
              .doc(widget.loanId)
              .update({
            'principalPaid': FieldValue.increment(principal),
            'interestPaid': FieldValue.increment(interest),
            'chargesPaid': FieldValue.increment(charges),
            'principalOutstanding': FieldValue.increment(-principal),
            'interestOutstanding': FieldValue.increment(-interest),
          });

          // Refresh arrears (non-critical)
          try {
            await ArrearsService.updateLoanArrears(widget.loanId);
          } catch (e) {
            print('Arrears update failed: $e');
          }

          _toast('Payment recorded successfully', true);
          _loadLoanData();
        } catch (e) {
          _toast('Error: $e', false);
        }
      },
    );

    _disposeLater([principalCtrl, interestCtrl, chargesCtrl, amountCtrl, phoneCtrl]);
  }
}
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../models/till_session.dart';
import '../../models/till_entry.dart';
import '../../services/loan_disbursement_service.dart';
import '../../services/loan_actions_service.dart';
import '../../services/arrears_service.dart';
import '../../services/till_service.dart';
import '../../widgets/loan_payment_mobile_money_dialog.dart';
import '../../widgets/loan_payment_cash_dialog.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
// One brand colour (navy). Green / red / amber are used ONLY to carry meaning
// (paid, owing, warning). Everything else is neutral.
class _C {
  static const brand = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const text = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE2E8F0);
  static const soft = Color(0xFFF1F5F9);
  static const bg = Color(0xFFF6F8FB);
  static const green = Color(0xFF047857);
  static const red = Color(0xFFB91C1C);
  static const amber = Color(0xFFB45309);
  static const purple = Color(0xFF6D28D9);
  static const teal = Color(0xFF0F766E);

  static Color tint(Color c, [double a = 0.10]) =>
      c.withAlpha((a * 255).round());
}

/// Breakpoints (by available width, not device type).
class _Bp {
  static const compact = 600.0; // phones
  static const medium = 900.0; // tablets / small windows
  static const maxContent = 1200.0;
}

class _Stat {
  final String label;
  final double value;
  final Color color;
  const _Stat(this.label, this.value, [this.color = _C.ink]);
}

class _Act {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const _Act(this.label, this.icon, this.onTap, {this.destructive = false});
}

class _LedgerRow {
  final Map<String, dynamic> txn;
  final bool isPay;
  final double p, i, c;
  final double balP, balI, balC;
  _LedgerRow(this.txn, this.isPay, this.p, this.i, this.c, this.balP, this.balI,
      this.balC);
}

class _Ledger {
  final rows = <_LedgerRow>[];
  double dP = 0, dI = 0, dC = 0; // disbursed totals
  double rP = 0, rI = 0, rC = 0; // repaid totals
  double bp = 0, bi = 0, bc = 0; // closing balance
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
  Map<String, dynamic>? _member;
  String? _memberDocId;
  String? _memberPhone;
  List<Map<String, dynamic>> _txns = [];
  String? _txnError;
  bool _isLoading = true;

  // Loan-card column flex: disbursements(5) | repayments(5) | balance(3) + action(1)
  // The last column (actions) is wider so both icon buttons always fit.
  static const _lf = [3, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3];

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

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA LOADING (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadLoanData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection(AppConstants.loansCol)
          .doc(widget.loanId);
      
      print('🔍 Loading loan data for ID: ${widget.loanId}');
      print('🔍 Initial loan data passed: ${widget.initialLoanData}');
      
      final doc = await ref.get();

      if (doc.exists) {
        final data = <String, dynamic>{'id': doc.id, ...doc.data()!};
        
        print('📊 Loaded from Firestore:');
        print('   - Amount: ${data['loanAmount'] ?? data['amount']}');
        print('   - Interest Rate: ${data['interestRate']}');
        print('   - Outstanding: ${data['principalOutstanding']}');
        print('   - Status: ${data['status']}');
        print('   - Disbursement: ${data['disbursementDate'] ?? data['disbursedAt']}');

        // Auto-correct: has disbursement date but status still "approved"
        final st = (data['status'] ?? '').toString().toLowerCase();
        if (st == 'approved' && data['disbursementDate'] != null) {
          data['status'] = 'Disbursed';
          try {
            await ref.update({'status': 'Disbursed'});
          } catch (e) {
            debugPrint('Failed to auto-correct status: $e');
          }
        }
        _loanData = data;
      }

      if (_loanData != null) {
        await _loadMember();

        try {
          _txns = await _loadTransactions();
          _txnError = null;
        } catch (e) {
          _txnError = e.toString();
        }
      }

      Map<String, dynamic>? arrears;
      try {
        arrears = await ArrearsService.calculateLoanArrears(widget.loanId);
      } catch (e) {
        debugPrint('Arrears calculation failed: $e');
      }

      if (!mounted) return;
      setState(() {
        _arrearsData = arrears;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading loan: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMember() async {
    try {
      final col = FirebaseFirestore.instance.collection('saccoplus-members');
      final rawId = _loanData!['memberId'] ?? _loanData!['farmerId'];
      DocumentSnapshot<Map<String, dynamic>>? found;

      if (rawId != null && rawId.toString().isNotEmpty) {
        final d = await col.doc(rawId.toString()).get();
        if (d.exists) found = d;
      }

      if (found == null) {
        final name = _loanData!['memberName']?.toString();
        if (name != null && name.isNotEmpty) {
          final tenant = FirebaseService.sessionTenantId;
          final exact = await col
              .where('name', isEqualTo: name)
              .where('tenantId', isEqualTo: tenant)
              .limit(1)
              .get();
          if (exact.docs.isNotEmpty) {
            found = exact.docs.first;
          } else {
            final all = await col.where('tenantId', isEqualTo: tenant).get();
            final lower = name.toLowerCase();
            for (final d in all.docs) {
              if ((d.data()['name'] ?? '').toString().toLowerCase() == lower) {
                found = d;
                break;
              }
            }
          }
        }
      }

      _memberDocId = found?.id;
      _member = found?.data();
      _memberPhone = _member?['phone']?.toString();
    } catch (e) {
      debugPrint('Error loading member: $e');
    }
  }

  double _pick(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final x = double.tryParse(v);
        if (x != null) return x;
      }
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> _loadTransactions() async {
    final out = <Map<String, dynamic>>[];
    final loan = _loanData!;
    final db = FirebaseFirestore.instance;

    if (loan['disbursedAt'] != null || loan['disbursementDate'] != null) {
      out.add({
        'date': loan['disbursedAt'] ?? loan['disbursementDate'],
        'type': 'Disbursement',
        'principal': _principal,
        'interest': _interest,
        'charges': _n('charges'),
      });
    }

    final pay = await db
        .collection(AppConstants.repaymentsCol)
        .where('loanId', isEqualTo: widget.loanId)
        .get();

    for (final doc in pay.docs) {
      final d = doc.data();
      var p = _pick(d, ['principalAmount', 'principalPaid', 'principal']);
      final i = _pick(d, ['interestAmount', 'interestPaid', 'interest']);
      final c = _pick(d, ['chargesAmount', 'chargesPaid', 'charges']);
      final total = _pick(d, ['amount', 'totalAmount']);
      if (p + i + c == 0 && total > 0) p = total;
      out.add({
        'docId': doc.id,
        'date': d['paymentDate'] ?? d['createdAt'],
        'type': 'Payment',
        'principal': p,
        'interest': i,
        'charges': c,
        'paymentMethod': (d['paymentMethod'] ?? 'Cash').toString(),
        'transactionId': d['mobileMoneyTransactionId'],
        'recordedBy': d['recordedBy'],
      });
    }

    try {
      final tops = await db
          .collection('loan-transactions')
          .where('loanId', isEqualTo: widget.loanId)
          .where('type', isEqualTo: 'Top-up')
          .get();
      for (final doc in tops.docs) {
        final d = doc.data();
        out.add({
          'date': d['createdAt'],
          'type': 'Top-up',
          'principal': d['amount'] ?? 0,
          'interest': d['interestAmount'] ?? 0,
          'charges': d['charges'] ?? 0,
        });
      }
    } catch (e) {
      debugPrint('Top-ups unavailable: $e');
    }

    out.sort((a, b) {
      final ad = _toDate(a['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _toDate(b['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });
    return out;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAN MATHS (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  double get _principal => _n('loanAmount', _n('amount'));

  double get _interest {
    final calc = ArrearsService.calculateInterest(
      principal: _principal,
      ratePerPeriod: _n('interestRate'),
      periods: _n('duration').round(),
      method: _s('interestMethod', 'flat').toLowerCase(),
    );
    return calc > 0 ? calc : _n('interestAmount');
  }

  double get _waived => _n('interestWaived', _n('waivedInterest'));

  double _paid(String key) => _txns
      .where((t) => t['type'] == 'Payment')
      .fold(0.0, (s, t) => s + _toD(t[key]));

  // Use stored outstanding values if available (from data correction),
  // otherwise calculate from original amounts
  double get _principalOut {
    // Check if principalOutstanding field exists in the loan data
    if (_loanData!.containsKey('principalOutstanding')) {
      final stored = _n('principalOutstanding');
      print('💰 Using stored principalOutstanding: $stored');
      return stored;
    }
    final calculated = math.max(0.0, _principal - _paid('principal'));
    print('💰 Calculated principalOutstanding: $calculated');
    return calculated;
  }

  double get _interestOut {
    // Check if interestOutstanding field exists in the loan data
    if (_loanData!.containsKey('interestOutstanding')) {
      final stored = _n('interestOutstanding');
      print('💰 Using stored interestOutstanding: $stored');
      return stored;
    }
    final calculated = math.max(0.0, _interest - _waived - _paid('interest'));
    print('💰 Calculated interestOutstanding: $calculated');
    return calculated;
  }

  double get _chargesOut => math.max(0.0, _n('charges') - _paid('charges'));

  double get _arrears {
    final a = _arrearsData?['arrearsAmount'];
    if (a is num) return a.toDouble();
    return _n('arrears');
  }

  double get _instalment {
    final d = _n('duration');
    return d > 0 ? (_principal + _interest) / d : 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _C.text, double? ls}) {
    return GoogleFonts.inter(
        fontSize: size, fontWeight: w, color: c, letterSpacing: ls);
  }

  /// Numeric style: tabular figures so digits line up in columns.
  TextStyle _num(double size,
      {FontWeight w = FontWeight.w600, Color c = _C.ink}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: w,
      color: c,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
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

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  String get _actor => FirebaseAuth.instance.currentUser?.email ?? 'admin';

  String get _status => _s('status');
  bool get _isActive {
    final s = _status.toLowerCase();
    return s == 'disbursed' || s == 'active' || s == 'overdue';
  }

  bool get _isApproved => _status.toLowerCase() == 'approved';

  String get _freq =>
      (_loanData?['paymentFrequency'] ?? 'monthly').toString().toLowerCase();

  String get _periodWord {
    switch (_freq) {
      case 'daily':
        return 'day';
      case 'weekly':
        return 'week';
      default:
        return 'month';
    }
  }

  String _getTenureLabel() {
    switch (_freq) {
      case 'daily':
        return 'Days';
      case 'weekly':
        return 'Weeks';
      default:
        return 'Months';
    }
  }

  DateTime? _toDate(dynamic d) {
    if (d is Timestamp) return d.toDate();
    if (d is DateTime) return d;
    return null;
  }

  String _formatDate(dynamic date) {
    final d = _toDate(date);
    return d == null ? 'N/A' : DateFormat('d MMM yyyy').format(d);
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return _C.blue;
      case 'disbursed':
      case 'active':
        return _C.green;
      case 'pending':
        return _C.amber;
      case 'rejected':
      case 'overdue':
        return _C.red;
      case 'paid':
      case 'closed':
        return _C.teal;
      default:
        return _C.muted;
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  bool get _isCompact => MediaQuery.sizeOf(context).width < _Bp.compact;

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    final wide = MediaQuery.sizeOf(context).width >= _Bp.medium;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: _t(13.5, c: Colors.white)),
          backgroundColor: ok ? _C.ink : _C.red,
          behavior: SnackBarBehavior.floating,
          width: wide ? 440 : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  void _disposeLater(List<TextEditingController> ctrls) {
    Future.delayed(const Duration(milliseconds: 500), () {
      for (final c in ctrls) {
        c.dispose();
      }
    });
  }

  double _dialogWidth(BuildContext ctx, [double max = 400]) =>
      math.min(max, MediaQuery.sizeOf(ctx).width - 96);

  // ─── Reusable building blocks ──────────────────────────────────────────────

  /// "UGX" in a quiet prefix, figure in tabular numerals.
  Widget _amount(double v,
      {double size = 15,
      FontWeight w = FontWeight.w700,
      Color c = _C.ink,
      bool prefix = true,
      TextAlign align = TextAlign.start}) {
    return Text.rich(
      TextSpan(children: [
        if (prefix)
          TextSpan(
              text: 'UGX ',
              style: _num(size * 0.72, w: FontWeight.w500, c: _C.muted)),
        TextSpan(text: _money(v), style: _num(size, w: w, c: c)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _C.tint(color, 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(_cap(status), style: _t(12, w: FontWeight.w600, c: color)),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _C.tint(color, 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: _t(11.5, w: FontWeight.w600, c: color)),
      );

  /// Plain surface – used by every section so the screen has one visual rhythm.
  Widget _surface({required Widget child, EdgeInsets? margin}) => Container(
        width: double.infinity,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _card({
    String? title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: _t(14.5, w: FontWeight.w600, c: _C.ink)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, style: _t(12, c: _C.muted)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
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
      {Color? valueColor, bool bold = false, bool last = false, Widget? custom}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: _t(13, c: _C.muted)),
          const SizedBox(width: 16),
          Expanded(
            child: custom != null
                ? Align(alignment: Alignment.centerRight, child: custom)
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: _num(13,
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
              width: 56,
              height: 56,
              decoration:
                  const BoxDecoration(color: _C.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 26, color: _C.muted),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: _t(15, w: FontWeight.w600, c: _C.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(subtitle,
                    textAlign: TextAlign.center,
                    style: _t(13, c: _C.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Scrollable, centred, width-constrained page body with responsive gutters.
  Widget _page({required Widget child, double maxWidth = _Bp.maxContent}) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = c.maxWidth >= _Bp.medium
            ? 32.0
            : c.maxWidth >= _Bp.compact
                ? 24.0
                : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 8),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _filledStyle([Color color = _C.brand]) => FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _t(13.5, w: FontWeight.w600),
      );

  ButtonStyle _outlinedStyle() => OutlinedButton.styleFrom(
        foregroundColor: _C.ink,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: const BorderSide(color: _C.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _t(13.5, w: FontWeight.w600),
      );

  // ─── Actions (one source of truth for app bar, bottom bar and sheet) ───────
  VoidCallback? get _primaryAction => _isApproved
      ? _showDisburseLoanDialog
      : _isActive
          ? _showRecordPaymentDialog
          : null;

  String get _primaryLabel => _isApproved ? 'Disburse loan' : 'Record payment';
  IconData get _primaryIcon =>
      _isApproved ? Icons.north_east_rounded : Icons.add_card_outlined;

  List<_Act> get _moreActions => !_isActive
      ? const []
      : [
          _Act('Loan top-up', Icons.add_circle_outline, _showTopUpDialog),
          _Act('Reschedule loan', Icons.schedule, _showRescheduleLoanDialog),
          _Act('Waive interest', Icons.money_off, _showWaiveInterestDialog),
          _Act('Close loan', Icons.check_circle_outline, _showCloseLoanDialog),
          _Act('Write off', Icons.block, _showWriteOffDialog,
              destructive: true),
        ];

  void _showActionSheet() {
    final acts = _moreActions;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in acts)
              ListTile(
                leading: Icon(a.icon,
                    size: 22, color: a.destructive ? _C.red : _C.text),
                title: Text(a.label,
                    style: _t(14.5,
                        w: FontWeight.w500,
                        c: a.destructive ? _C.red : _C.ink)),
                onTap: () {
                  Navigator.pop(ctx);
                  a.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _moreMenuButton() {
    final acts = _moreActions;
    return PopupMenuButton<int>(
      tooltip: 'More actions',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _C.line),
      ),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      onSelected: (i) => acts[i].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < acts.length; i++) ...[
          if (acts[i].destructive) const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(acts[i].icon,
                    size: 18,
                    color: acts[i].destructive ? _C.red : _C.muted),
                const SizedBox(width: 12),
                Text(acts[i].label,
                    style: _t(13.5,
                        w: FontWeight.w500,
                        c: acts[i].destructive ? _C.red : _C.ink)),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: _C.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('More actions',
                style: _t(13.5, w: FontWeight.w600, c: _C.ink)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: _C.muted),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loanData == null) {
      return Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: _C.ink,
          elevation: 0,
          titleSpacing: 24,
          title: Text('Loan details',
              style: _t(16, w: FontWeight.w600, c: _C.ink)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _emptyState(Icons.search_off_rounded, 'Loan not found',
                'This loan may have been removed.'),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < _Bp.compact;
    final primary = _primaryAction;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _C.ink,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        // Breathing room so the title never sits flush against the sidebar.
        titleSpacing: compact ? 16 : 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan account',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(16, w: FontWeight.w600, c: _C.ink)),
            Text(_s('accountNumber'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _num(12, w: FontWeight.w400, c: _C.muted)),
          ],
        ),
        actions: [
          if (!compact && primary != null) ...[
            FilledButton.icon(
              onPressed: primary,
              icon: Icon(_primaryIcon, size: 18),
              label: Text(_primaryLabel),
              style: _filledStyle(),
            ),
            if (_moreActions.isNotEmpty) ...[
              const SizedBox(width: 8),
              _moreMenuButton(),
            ],
          ],
          SizedBox(width: compact ? 4 : 24),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.line)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              // Align the first tab label with the title above it.
              padding: EdgeInsets.only(left: compact ? 0 : 8),
              dividerColor: Colors.transparent,
              indicatorColor: _C.brand,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: _C.brand,
              unselectedLabelColor: _C.muted,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              labelStyle: _t(13.5, w: FontWeight.w600, c: _C.brand),
              unselectedLabelStyle: _t(13.5, w: FontWeight.w500, c: _C.muted),
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
                _buildTransactionsTab(),
                _buildChargesTab(),
                _buildGuarantorsTab(),
                _buildDocumentsTab(),
              ],
            ),
          ),
        ],
      ),
      // Phones: primary action lives in a thumb-reachable bar.
      bottomNavigationBar: compact && primary != null
          ? Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _C.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: primary,
                          icon: Icon(_primaryIcon, size: 18),
                          label: Text(_primaryLabel),
                          style: _filledStyle(),
                        ),
                      ),
                      if (_moreActions.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _showActionSheet,
                          style: _outlinedStyle(),
                          child: const Icon(Icons.more_horiz, size: 22),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: SUMMARY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSummaryTab() {
    final principal = _principal;
    final interest = _interest;
    final charges = _n('charges');

    final pPaid = _paid('principal');
    final iPaid = _paid('interest');
    final cPaid = _paid('charges');
    final totalPaid = pPaid + iPaid + cPaid;

    final pOut = _principalOut;
    final iOut = _interestOut;
    final cOut = _chargesOut;
    final totalOut = pOut + iOut + cOut;
    final total = principal + interest - _waived + charges;
    final arrears = _arrears;

    final hasDisb = _loanData!['disbursedAt'] != null ||
        _loanData!['disbursementDate'] != null;
    final hasExtra =
        _loanData!['purpose'] != null || _loanData!['description'] != null;

    return LayoutBuilder(
      builder: (context, c) {
        final twoCol = c.maxWidth >= 1000;

        final left = Column(
          children: [
            _buildDetailsCard(principal, interest),
            if (hasExtra) ...[
              const SizedBox(height: 16),
              _buildAdditionalCard(),
            ],
          ],
        );

        final right = Column(
          children: [
            _buildBreakdownCard(principal, interest - _waived, charges, pPaid,
                iPaid, cPaid, pOut, iOut, cOut, totalOut, arrears),
            if (hasDisb) ...[
              const SizedBox(height: 16),
              _buildDisbursementCard(),
            ],
          ],
        );

        return _page(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                outstanding: totalOut,
                total: total,
                paid: totalPaid,
                stats: [
                  _Stat('Loan amount', principal),
                  _Stat('Total repaid', totalPaid,
                      totalPaid > 0 ? _C.green : _C.ink),
                  _Stat('Instalment', _instalment),
                  _Stat('Arrears', arrears, arrears > 0 ? _C.red : _C.ink),
                ],
              ),
              const SizedBox(height: 16),
              _buildMemberAccounts(),
              const SizedBox(height: 16),
              if (twoCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: right),
                  ],
                )
              else ...[
                right,
                const SizedBox(height: 16),
                left,
              ],
              const SizedBox(height: 16),
              _buildLoanCardSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required double outstanding,
    required double total,
    required double paid,
    required List<_Stat> stats,
  }) {
    final name = _s('memberName');
    final progress =
        total > 0 ? (paid / total).clamp(0.0, 1.0).toDouble() : 0.0;

    Widget meta(String label, String value) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label  ', style: _t(12, c: _C.muted)),
            TextSpan(
                text: value, style: _num(12, w: FontWeight.w500, c: _C.text)),
          ]),
        );

    final identity = Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _C.tint(_C.brand, 0.10),
          child: Text(_initials(name),
              style: _t(15, w: FontWeight.w700, c: _C.brand)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t(19, w: FontWeight.w700, c: _C.ink)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _statusChip(_status),
                  meta('Member ID', _s('memberId', _memberDocId ?? 'N/A')),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    Widget balance(bool right) => Flexible(
          child: Column(
            crossAxisAlignment:
                right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text('Outstanding balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12.5, w: FontWeight.w500, c: _C.muted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: right ? Alignment.centerRight : Alignment.centerLeft,
                child: _amount(outstanding,
                    size: right ? 30 : 28, w: FontWeight.w700, c: _C.ink),
              ),
            ],
          ),
        );

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth >= 640) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 24),
                      balance(true),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 20),
                    balance(false),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Repaid', style: _t(12, c: _C.muted)),
                    Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: _num(12, w: FontWeight.w600, c: _C.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: _C.soft,
                    valueColor: const AlwaysStoppedAnimation<Color>(_C.green),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.line),
          _statStrip(stats),
        ],
      ),
    );
  }

  /// Figures separated by hairlines. 1 row on wide, 2 columns on phones.
  Widget _statStrip(List<_Stat> items) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols =
            c.maxWidth >= 640 ? items.length : math.min(2, items.length);
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i += cols) {
          final slice = items.skip(i).take(cols).toList();
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const VerticalDivider(width: 1, color: _C.line),
                  Expanded(
                    child: j < slice.length
                        ? _statCell(slice[j])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ));
          if (i + cols < items.length) {
            rows.add(const Divider(height: 1, color: _C.line));
          }
        }
        return Column(children: rows);
      },
    );
  }

  Widget _statCell(_Stat s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.label, style: _t(12, c: _C.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _amount(s.value, size: 16, c: s.color),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAccounts() {
    final savings = _toD(_member?['savingsBalance']);
    final shares = _toD(_member?['sharesValue'] ?? _member?['sharesBalance']);
    final compact = _isCompact;
    return _card(
      title: 'Member accounts',
      padding: EdgeInsets.zero,
      trailing: _isActive
          ? TextButton.icon(
              onPressed: _showTransferFromSavingsDialog,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(compact ? 'Transfer' : 'Transfer from savings'),
              style: TextButton.styleFrom(
                foregroundColor: _C.blue,
                textStyle: _t(13, w: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            )
          : null,
      child: _statStrip([
        _Stat('Savings balance', savings),
        _Stat('Shares balance', shares),
      ]),
    );
  }

  Widget _buildDetailsCard(double principal, double interest) {
    final inst = _instalment;
    return _card(
      title: 'Loan details',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          _kv('Member', _s('memberName')),
          _kv('Phone number', _memberPhone ?? 'N/A'),
          _kv('Member ID', _s('memberId', _memberDocId ?? 'N/A')),
          _kv('Account number', _s('accountNumber')),
          _kv('Status', _status, custom: _statusChip(_status)),
          _kv(
              'Disbursement date',
              _formatDate(
                  _loanData!['disbursementDate'] ?? _loanData!['disbursedAt'])),
          _kv('Branch', _s('branch', 'Main Branch')),
          _kv('Loan amount', 'UGX ${_money(principal)}', bold: true),
          _kv('Interest rate', '${_s('interestRate', '0')}% per $_periodWord'),
          _kv('Total interest', 'UGX ${_money(interest)}'),
          _kv('Instalment',
              inst > 0 ? 'UGX ${_money(inst)} per $_periodWord' : 'N/A'),
          _kv('Loan officer',
              _loanData!['loanOfficer']?.toString() ?? _s('approvedBy')),
          _kv('Tenure', '${_s('duration', '0')} ${_getTenureLabel()}'),
          _kv('Loan type', _s('loanType'), last: true),
        ],
      ),
    );
  }

  Widget _buildAdditionalCard() {
    return _card(
      title: 'Additional information',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          if (_loanData!['purpose'] != null) _kv('Purpose', _s('purpose')),
          _kv('Description', _s('description'), last: true),
        ],
      ),
    );
  }

  Widget _buildDisbursementCard() {
    final dest = _s('destinationType', 'Cash').replaceAll('_', ' ');
    return _card(
      title: 'Disbursement',
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          _kv('Destination', _cap(dest)),
          _kv('Reference', _s('referenceNumber')),
          _kv('Disbursed by', _s('disbursedBy')),
          _kv(
              'Date',
              _formatDate(
                  _loanData!['disbursedAt'] ?? _loanData!['disbursementDate']),
              last: true),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    double principal,
    double interest,
    double charges,
    double pPaid,
    double iPaid,
    double cPaid,
    double pOut,
    double iOut,
    double cOut,
    double tOut,
    double arrears,
  ) {
    Widget head(String h, {bool left = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(h,
              textAlign: left ? TextAlign.left : TextAlign.right,
              style: _t(12, w: FontWeight.w500, c: _C.muted)),
        );

    TableRow row(String label, double exp, double paid, double out,
        {bool bold = false, bool top = false}) {
      Widget cell(String text, Color c, {bool left = false}) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: left ? Alignment.centerLeft : Alignment.centerRight,
              child: Text(text,
                  style: left
                      ? _t(13,
                          w: bold ? FontWeight.w700 : FontWeight.w500, c: c)
                      : _num(13,
                          w: bold ? FontWeight.w700 : FontWeight.w500, c: c)),
            ),
          );
      return TableRow(
        decoration: BoxDecoration(
          border: top
              ? const Border(top: BorderSide(color: _C.line))
              : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        children: [
          cell(label, _C.ink, left: true),
          cell(_money(exp), _C.ink),
          cell(_money(paid), paid > 0 ? _C.green : _C.muted),
          cell(_money(out), out > 0 ? _C.red : _C.muted),
        ],
      );
    }

    return _card(
      title: 'Balance breakdown',
      subtitle: 'Amounts in UGX',
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.25),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.0),
              3: FlexColumnWidth(1.25),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _C.line))),
                children: [
                  head('', left: true),
                  head('Expected'),
                  head('Paid'),
                  head('Outstanding'),
                ],
              ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _C.tint(_C.red, 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: _C.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Arrears',
                        style: _t(13, w: FontWeight.w600, c: _C.red)),
                  ),
                  _amount(arrears, size: 14, c: _C.red),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Loan card (ledger) ─────────────────────────────────────────────────────
  Widget _buildLoanCardSection() {
    return _card(
      title: 'Loan card',
      subtitle: 'Every disbursement and repayment, with running balances',
      padding: EdgeInsets.zero,
      child: _txnError != null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Could not load transactions: $_txnError',
                  style: _t(13, c: _C.red)),
            )
          : _ledger(_txns),
    );
  }

  _Ledger _buildLedger(List<Map<String, dynamic>> txns) {
    final l = _Ledger();

    // Process all transactions to build the ledger rows
    for (final t in txns) {
      final isPay = (t['type'] ?? '').toString() == 'Payment';
      final p = _toD(t['principal']);
      final i = _toD(t['interest']);
      final c = _toD(t['charges']);
      if (isPay) {
        l.bp -= p;
        l.bi -= i;
        l.bc -= c;
        l.rP += p;
        l.rI += i;
        l.rC += c;
      } else {
        l.bp += p;
        l.bi += i;
        l.bc += c;
        l.dP += p;
        l.dI += i;
        l.dC += c;
      }
      l.rows.add(_LedgerRow(t, isPay, p, i, c, l.bp, l.bi, l.bc));
    }

    // If we have stored outstanding values (from data correction), override the calculated balances
    if (_loanData!.containsKey('principalOutstanding') &&
        _loanData!.containsKey('interestOutstanding')) {
      print(
          '💳 Overriding ledger balances with stored outstanding: P=${_n('principalOutstanding')}, I=${_n('interestOutstanding')}');
      l.bp = _n('principalOutstanding');
      l.bi = _n('interestOutstanding');
      l.bc = _n('chargesOutstanding', 0);

      // Update the last row's balances to match the corrected values
      if (l.rows.isNotEmpty) {
        final lastRow = l.rows.last;
        l.rows[l.rows.length - 1] = _LedgerRow(
          lastRow.txn,
          lastRow.isPay,
          lastRow.p,
          lastRow.i,
          lastRow.c,
          l.bp, // Use corrected balance
          l.bi, // Use corrected balance
          l.bc, // Use corrected balance
        );
      }
    }

    return l;
  }

  Widget _ledger(List<Map<String, dynamic>> txns) {
    final l = _buildLedger(txns);
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth < 760 ? _ledgerList(l) : _ledgerTable(l, c.maxWidth),
    );
  }

  // Phones: one tile per transaction instead of a 1200px-wide spreadsheet.
  Widget _ledgerList(_Ledger l) {
    if (l.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
            child: Text('No transactions yet', style: _t(13, c: _C.muted))),
      );
    }
    final items = l.rows.reversed.toList();
    return Column(
      children: [
        for (var n = 0; n < items.length; n++)
          _ledgerTile(items[n], last: false),
        Container(
          color: _C.soft,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Text('Balance', style: _t(13, w: FontWeight.w600, c: _C.ink)),
              const Spacer(),
              _amount(l.bp + l.bi + l.bc,
                  size: 15,
                  c: (l.bp + l.bi + l.bc) > 0.5 ? _C.red : _C.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ledgerTile(_LedgerRow r, {required bool last}) {
    final total = r.p + r.i + r.c;
    final bal = r.balP + r.balI + r.balC;
    final label =
        r.isPay ? 'Payment' : (r.txn['type'] ?? 'Disbursement').toString();

    Widget part(String l, double v) => Text.rich(TextSpan(children: [
          TextSpan(text: '$l ', style: _t(11.5, c: _C.muted)),
          TextSpan(
              text: _money(v),
              style: _num(11.5, w: FontWeight.w500, c: _C.text)),
        ]));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _t(14, w: FontWeight.w600, c: _C.ink)),
                    const SizedBox(height: 2),
                    Text(_formatDate(r.txn['date']),
                        style: _t(12, c: _C.muted)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${r.isPay ? '−' : '+'} ${_money(total)}',
                      style: _num(15,
                          w: FontWeight.w700, c: r.isPay ? _C.green : _C.ink),
                    ),
                    const SizedBox(height: 2),
                    Text('Bal ${_money(bal)}',
                        style: _num(11.5, w: FontWeight.w400, c: _C.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Wrap(spacing: 14, runSpacing: 2, children: [
                  part('Principal', r.p),
                  part('Interest', r.i),
                  part('Charges', r.c),
                ]),
              ),
              if (r.isPay) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.receipt_long_outlined,
                      size: 20, color: _C.muted),
                  tooltip: 'View receipt',
                  onPressed: () => _showPaymentDetails(r.txn),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.undo_rounded, size: 20, color: _C.red),
                  tooltip: 'Reverse payment',
                  onPressed: () => _confirmReverse(r.txn),
                ),
              ] else
                const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lc(int idx, String text,
      {bool isNum = false,
      bool bold = false,
      Color? color,
      Widget? child,
      double height = 46,
      double hPad = 10,
      TextStyle? style}) {
    final sectionStart = idx == 0 || idx == 5 || idx == 10;
    return Expanded(
      flex: _lf[idx],
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        alignment: isNum ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          border: sectionStart
              ? const Border(left: BorderSide(color: _C.line))
              : null,
        ),
        child: child ??
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: style ??
                  (isNum
                      ? _num(12.5,
                          w: bold ? FontWeight.w700 : FontWeight.w500,
                          c: color ?? _C.ink)
                      : _t(12.5,
                          w: bold ? FontWeight.w700 : FontWeight.w500,
                          c: color ?? _C.ink)),
            ),
      ),
    );
  }

  Widget _ledgerTable(_Ledger l, double available) {
    String m(double v) => v > 0 ? _money(v) : '';

    Widget balCell(int idx, double v) {
      final owing = v > 0.5;
      return _lc(idx, owing ? _money(v) : '0',
          isNum: true, bold: owing, color: owing ? _C.red : _C.muted);
    }

    Widget groupHeader(String label, int flex) => Expanded(
          flex: flex,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _C.soft,
              border: Border(left: BorderSide(color: _C.line)),
            ),
            child: Text(label, style: _t(12, w: FontWeight.w600, c: _C.ink)),
          ),
        );

    const titles = [
      'Date', 'Principal', 'Interest', 'Charges', 'Total',
      'Date', 'Principal', 'Interest', 'Charges', 'Total',
      'Principal', 'Interest', 'Charges', '',
    ];

    final body = <Widget>[
      Row(children: [
        groupHeader('Disbursements', 11),
        groupHeader('Repayments', 11),
        // Balance (3 cols = 6) + action column (3) = 9
        groupHeader('Balance', 9),
      ]),
      const Divider(height: 1, color: _C.line),
      Row(
        children: List.generate(titles.length, (i) {
          return _lc(i, titles[i],
              isNum: i != 0 && i != 5 && i != 13,
              height: 38,
              style: _t(12, w: FontWeight.w500, c: _C.muted));
        }),
      ),
      const Divider(height: 1, color: _C.line),
    ];

    if (l.rows.isEmpty) {
      body.add(Padding(
        padding: const EdgeInsets.all(28),
        child: Text('No transactions yet', style: _t(13, c: _C.muted)),
      ));
    }

    for (var n = 0; n < l.rows.length; n++) {
      final r = l.rows[n];
      body.add(Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
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
          // Action column: zero side padding + wider flex so both icons fit.
          _lc(
            13,
            '',
            hPad: 0,
            child: r.isPay
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.receipt_long_outlined,
                            size: 16, color: _C.muted),
                        tooltip: 'View receipt',
                        onPressed: () => _showPaymentDetails(r.txn),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.undo_rounded,
                            size: 16, color: _C.red),
                        tooltip: 'Reverse payment',
                        onPressed: () => _confirmReverse(r.txn),
                      ),
                    ],
                  )
                : const SizedBox(),
          ),
        ]),
      ));
    }

    if (l.rows.isNotEmpty) {
      body.add(Container(
        color: _C.soft,
        child: Row(children: [
          _lc(0, 'Total', bold: true),
          _lc(1, m(l.dP), isNum: true, bold: true),
          _lc(2, m(l.dI), isNum: true, bold: true),
          _lc(3, m(l.dC), isNum: true, bold: true),
          _lc(4, m(l.dP + l.dI + l.dC), isNum: true, bold: true),
          _lc(5, ''),
          _lc(6, m(l.rP), isNum: true, bold: true),
          _lc(7, m(l.rI), isNum: true, bold: true),
          _lc(8, m(l.rC), isNum: true, bold: true),
          _lc(9, m(l.rP + l.rI + l.rC), isNum: true, bold: true),
          balCell(10, l.bp),
          balCell(11, l.bi),
          balCell(12, l.bc),
          _lc(13, '', hPad: 0),
        ]),
      ));
    }

    final w = available < 1100 ? 1100.0 : available;
    return Scrollbar(
      controller: _cardScroll,
      thumbVisibility: available < 1100,
      child: SingleChildScrollView(
        controller: _cardScroll,
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: w, child: Column(children: body)),
      ),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final p = _toD(payment['principal']);
    final i = _toD(payment['interest']);
    final c = _toD(payment['charges']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Payment receipt',
            style: _t(17, w: FontWeight.w700, c: _C.ink)),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _receiptLine('Member', _s('memberName')),
                _receiptLine('Date', _formatDate(payment['date'])),
                const Divider(height: 20, color: _C.line),
                _receiptLine('Principal', 'UGX ${_money(p)}'),
                _receiptLine('Interest', 'UGX ${_money(i)}'),
                _receiptLine('Charges', 'UGX ${_money(c)}'),
                const Divider(height: 20, color: _C.line),
                _receiptLine('Total paid', 'UGX ${_money(p + i + c)}',
                    bold: true),
                const Divider(height: 20, color: _C.line),
                _receiptLine(
                    'Method', (payment['paymentMethod'] ?? 'N/A').toString()),
                if (payment['transactionId'] != null &&
                    payment['transactionId'].toString().isNotEmpty)
                  _receiptLine(
                      'Transaction ID', payment['transactionId'].toString()),
                if (payment['recordedBy'] != null)
                  _receiptLine('Recorded by', payment['recordedBy'].toString()),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Close', style: _t(13.5, w: FontWeight.w600, c: _C.brand)),
          ),
        ],
      ),
    );
  }

  Widget _receiptLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _t(13, c: _C.muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.end,
                style: _num(13,
                    w: bold ? FontWeight.w700 : FontWeight.w500, c: _C.ink)),
          ),
        ],
      ),
    );
  }

  // ─── Reverse a payment ──────────────────────────────────────────────────────
  Future<void> _confirmReverse(Map<String, dynamic> t) async {
    final p = _toD(t['principal']);
    final i = _toD(t['interest']);
    final c = _toD(t['charges']);
    final total = p + i + c;
    final method = (t['paymentMethod'] ?? '').toString();
    final fromSavings = method == 'Transfer from Savings';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reverse this payment?',
            style: _t(17, w: FontWeight.w700, c: _C.ink)),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The payment is deleted and the loan balance is restored.',
                    style: _t(13.5)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _receiptLine('Date', _formatDate(t['date'])),
                      _receiptLine('Principal', 'UGX ${_money(p)}'),
                      _receiptLine('Interest', 'UGX ${_money(i)}'),
                      _receiptLine('Charges', 'UGX ${_money(c)}'),
                      const Divider(height: 16, color: _C.line),
                      _receiptLine('Total', 'UGX ${_money(total)}', bold: true),
                    ],
                  ),
                ),
                if (fromSavings) ...[
                  const SizedBox(height: 12),
                  Text(
                      'UGX ${_money(total)} will be returned to the member\'s savings.',
                      style: _t(12.5, c: _C.blue)),
                ],
                const SizedBox(height: 12),
                Text('This can\'t be undone.',
                    style: _t(12.5, w: FontWeight.w600, c: _C.red)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: _t(13.5, w: FontWeight.w600, c: _C.muted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: _filledStyle(_C.red),
            child: const Text('Reverse payment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runAction(
      successMessage: 'Payment reversed',
      action: () async {
        final docId = t['docId']?.toString();
        if (docId == null) throw Exception('Transaction document ID not found');
        final db = FirebaseFirestore.instance;

        await db.collection(AppConstants.repaymentsCol).doc(docId).delete();
        await db.collection(AppConstants.loansCol).doc(widget.loanId).update({
          'principalPaid': FieldValue.increment(-p),
          'interestPaid': FieldValue.increment(-i),
          'chargesPaid': FieldValue.increment(-c),
          'principalOutstanding': FieldValue.increment(p),
          'interestOutstanding': FieldValue.increment(i),
          'chargesOutstanding': FieldValue.increment(c),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (fromSavings && _memberDocId != null) {
          await db
              .collection('saccoplus-members')
              .doc(_memberDocId)
              .update({'savingsBalance': FieldValue.increment(total)});
        }

        try {
          await ArrearsService.updateLoanArrears(widget.loanId);
        } catch (e) {
          debugPrint('Arrears update failed: $e');
        }
        return {'success': true, 'message': 'Payment reversed'};
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 / 4: TRANSACTIONS & REPAYMENTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTransactionsTab() {
    if (_txnError != null) {
      return _emptyState(
          Icons.error_outline, 'Could not load payments', _txnError);
    }

    final pays =
        _txns.where((t) => t['type'] == 'Payment').toList().reversed.toList();

    if (pays.isEmpty) {
      return _emptyState(Icons.receipt_long_outlined, 'No payments yet',
          'Payments recorded against this loan will appear here.');
    }

    Widget part(String l, double v) => Text.rich(TextSpan(children: [
          TextSpan(text: '$l ', style: _t(12, c: _C.muted)),
          TextSpan(
              text: _money(v),
              style: _num(12, w: FontWeight.w500, c: _C.text)),
        ]));

    return _page(
      maxWidth: 880,
      child: Column(
        children: [
          for (final t in pays)
            Builder(builder: (context) {
              final p = _toD(t['principal']);
              final i = _toD(t['interest']);
              final c = _toD(t['charges']);
              final method = (t['paymentMethod'] ?? 'Cash').toString();
              return _surface(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _C.tint(_C.green, 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                                method == 'Mobile Money'
                                    ? Icons.smartphone_outlined
                                    : Icons.payments_outlined,
                                size: 20,
                                color: _C.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Loan payment',
                                    style: _t(14,
                                        w: FontWeight.w600, c: _C.ink)),
                                const SizedBox(height: 2),
                                Text('${_formatDate(t['date'])} · $method',
                                    style: _t(12, c: _C.muted)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _amount(p + i + c, size: 15, c: _C.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(spacing: 14, runSpacing: 2, children: [
                              part('Principal', p),
                              part('Interest', i),
                              part('Charges', c),
                            ]),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showPaymentDetails(t),
                            icon: const Icon(Icons.receipt_long_outlined,
                                size: 16),
                            label: const Text('Receipt'),
                            style: TextButton.styleFrom(
                              foregroundColor: _C.brand,
                              textStyle: _t(12.5, w: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _confirmReverse(t),
                            icon: const Icon(Icons.undo_rounded, size: 16),
                            label: const Text('Reverse'),
                            style: TextButton.styleFrom(
                              foregroundColor: _C.red,
                              textStyle: _t(12.5, w: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: SCHEDULE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildScheduleTab() {
    final disb =
        _toDate(_loanData!['disbursementDate'] ?? _loanData!['disbursedAt']);
    final duration = _n('duration').round();

    if (disb == null || duration <= 0) {
      return _emptyState(Icons.event_note_outlined, 'No schedule yet',
          'The schedule is created when the loan is disbursed.');
    }

    final principal = _principal;
    final interest = _interest;
    final totalRepayable = principal + interest;
    final inst = totalRepayable / duration;
    final totalPaid = _paid('principal') + _paid('interest') + _paid('charges');
    final now = DateTime.now();

    DateTime due(int n) {
      switch (_freq) {
        case 'daily':
          return disb.add(Duration(days: n));
        case 'weekly':
          return disb.add(Duration(days: 7 * n));
        default:
          return DateTime(disb.year, disb.month + n, disb.day);
      }
    }

    return _page(
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            title: 'Repayment schedule',
            subtitle: '$duration ${_getTenureLabel().toLowerCase()}',
            padding: EdgeInsets.zero,
            child: _statStrip([
              _Stat('Instalment', inst),
              _Stat('Total interest', interest),
              _Stat('Total repayable', totalRepayable),
            ]),
          ),
          const SizedBox(height: 16),
          _surface(
            child: Column(
              children: [
                for (var n = 1; n <= duration; n++)
                  Builder(builder: (context) {
                    final dueDate = due(n);
                    final cumulative = inst * n;
                    final previous = inst * (n - 1);

                    String label;
                    Color color;
                    if (totalPaid >= cumulative - 0.5) {
                      label = 'Paid';
                      color = _C.green;
                    } else if (dueDate.isBefore(now)) {
                      label =
                          totalPaid > previous + 0.5 ? 'Partial' : 'Overdue';
                      color = _C.red;
                    } else if (totalPaid > previous + 0.5) {
                      label = 'Partial';
                      color = _C.amber;
                    } else {
                      label = 'Upcoming';
                      color = _C.muted;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: n == duration
                            ? null
                            : const Border(
                                bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text('$n',
                                style: _num(13,
                                    w: FontWeight.w500, c: _C.muted)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('d MMM yyyy').format(dueDate),
                                    style: _t(14,
                                        w: FontWeight.w600, c: _C.ink)),
                                const SizedBox(height: 2),
                                Text(
                                  'Principal ${_money(principal / duration)} · Interest ${_money(interest / duration)}',
                                  style: _t(11.5, c: _C.muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_money(inst),
                                  style: _num(14,
                                      w: FontWeight.w700, c: _C.ink)),
                              const SizedBox(height: 4),
                              _tag(label, color),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABS 5, 6, 7
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildChargesTab() {
    final charges = _n('charges');
    final paid = _paid('charges');
    final out = _chargesOut;

    Widget chargeRow(String title, double amount, String desc,
        {bool last = false}) {
      if (amount <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _t(14, w: FontWeight.w600, c: _C.ink)),
                  const SizedBox(height: 2),
                  Text(desc, style: _t(12, c: _C.muted)),
                ],
              ),
            ),
            _amount(amount, size: 14),
          ],
        ),
      );
    }

    final items = <Widget>[
      chargeRow('Processing fee', _n('processingFee'), 'One-time charge'),
      chargeRow('Application fee', _n('applicationFee'), 'One-time charge'),
      chargeRow('Insurance', _n('insurance'), 'Loan insurance premium'),
      chargeRow('Late payment penalty', _n('lateFee'),
          'Penalty on overdue instalments',
          last: true),
    ];

    return _page(
      maxWidth: 880,
      child: Column(
        children: [
          _card(
            title: 'Charges summary',
            padding: EdgeInsets.zero,
            child: _statStrip([
              _Stat('Total charges', charges),
              _Stat('Paid', paid, paid > 0 ? _C.green : _C.ink),
              _Stat('Outstanding', out, out > 0 ? _C.red : _C.ink),
            ]),
          ),
          const SizedBox(height: 16),
          if (charges > 0)
            _card(
              title: 'Breakdown',
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Column(children: items),
            )
          else
            _surface(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _emptyState(
                    Icons.check_circle_outline, 'No charges on this loan'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() => _emptyState(Icons.folder_open_outlined,
      'No documents', 'Document uploads are coming soon.');

  Widget _buildGuarantorsTab() {
    final guarantors = _loanData!['guarantors'] as List? ?? [];

    if (guarantors.isEmpty) {
      return _emptyState(Icons.people_outline, 'No guarantors',
          'Guarantors attached to this loan will appear here.');
    }

    return _page(
      maxWidth: 880,
      child: _surface(
        child: Column(
          children: [
            for (var index = 0; index < guarantors.length; index++)
              Builder(builder: (context) {
                final g = Map<String, dynamic>.from(guarantors[index] as Map);
                final gName = (g['name'] ?? 'N/A').toString();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: index == guarantors.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _C.tint(_C.brand, 0.10),
                        child: Text(_initials(gName),
                            style: _t(13, w: FontWeight.w700, c: _C.brand)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(gName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _t(14, w: FontWeight.w600, c: _C.ink)),
                            const SizedBox(height: 2),
                            Text('A/C ${g['account'] ?? 'N/A'}',
                                style:
                                    _num(12, w: FontWeight.w400, c: _C.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Savings', style: _t(11.5, c: _C.muted)),
                          const SizedBox(height: 2),
                          _amount(_toD(g['savings']), size: 14),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG INFRASTRUCTURE
  // ═══════════════════════════════════════════════════════════════════════════
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
    Color? fill,
    ValueChanged<String>? onChanged,
    TextStyle? style,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _t(13, w: FontWeight.w600, c: _C.ink)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            readOnly: readOnly,
            onChanged: onChanged,
            style: style ?? _t(14, c: _C.ink),
            keyboardType: number ? TextInputType.number : null,
            inputFormatters: number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
            decoration: _inputDecoration(hint: hint, fill: fill),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Color? fill}) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: _t(14, c: const Color(0xFF94A3B8)),
      isDense: true,
      filled: true,
      fillColor: fill ?? Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: b(_C.line),
      enabledBorder: b(_C.line),
      focusedBorder: b(_C.brand, 1.5),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: _t(13, w: FontWeight.w600, c: _C.ink)),
      );

  InputDecoration _dropDecoration({String? hint}) =>
      _inputDecoration(hint: hint);

  /// Shared form dialog: neutral header, colour only on the confirm button.
  Future<void> _showFormDialog({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required String submitLabel,
    required Widget Function(StateSetter setS) bodyBuilder,
    required Future<void> Function() onSubmit,
    String? Function()? validate,
    double maxWidth = 480,
  }) {
    String? error;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _C.tint(color, 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: _t(16, w: FontWeight.w700, c: _C.ink)),
                            if (subtitle != null)
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _t(12.5, c: _C.muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: _C.muted, size: 20),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _C.line),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _C.tint(_C.red, 0.06),
                              borderRadius: BorderRadius.circular(8),
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
                const Divider(height: 1, color: _C.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text('Cancel',
                            style: _t(13.5, w: FontWeight.w600, c: _C.muted)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final err = validate?.call();
                          if (err != null) {
                            setS(() => error = err);
                            return;
                          }
                          Navigator.pop(dialogContext);
                          await onSubmit();
                        },
                        style: _filledStyle(color),
                        child: Text(submitLabel),
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

  Widget _infoBanner(String text, Color color, {IconData? icon}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _C.tint(color, 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(text, style: _t(12.5, c: _C.text))),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAN ACTION DIALOGS (logic unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showDisburseLoanDialog() async {
    final amountCtrl =
        TextEditingController(text: _principal.round().toString());
    final referenceCtrl = TextEditingController();
    final chequeCtrl = TextEditingController();
    final narrationCtrl = TextEditingController(
        text: 'Loan disbursement for ${_s('memberName')}');
    String destinationType = 'cash';

    await _showFormDialog(
      title: 'Disburse loan',
      subtitle: _s('memberName'),
      icon: Icons.north_east_rounded,
      color: _C.brand,
      submitLabel: 'Disburse',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBanner(
              'Account ${_s('accountNumber')} · Ref ${_s('referenceNumber')}',
              _C.muted),
          _label('Destination'),
          DropdownButtonFormField<String>(
            value: destinationType,
            decoration: _dropDecoration(),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
              DropdownMenuItem(
                  value: 'mobile_money', child: Text('Mobile money')),
            ],
            onChanged: (v) {
              if (v != null) setS(() => destinationType = v);
            },
          ),
          const SizedBox(height: 16),
          _field('Amount (UGX)', amountCtrl, readOnly: true, fill: _C.soft),
          _field('Reference number', referenceCtrl,
              hint: 'Receipt or transaction number'),
          if (destinationType == 'bank')
            _field('Cheque number', chequeCtrl, hint: 'Cheque number'),
          _field('Narration', narrationCtrl, maxLines: 3),
        ],
      ),
      validate: () => (double.tryParse(amountCtrl.text) ?? 0) <= 0
          ? 'Enter a valid amount'
          : null,
      onSubmit: () async {
        final amount = double.tryParse(amountCtrl.text) ?? 0;
        final dest = destinationType;
        final ref = referenceCtrl.text.trim();
        final cheque = chequeCtrl.text.trim();
        final narration = narrationCtrl.text.trim();
        
        // Get the open till session if disbursing cash
        TillSession? openTill;
        if (dest == 'cash') {
          try {
            openTill = await TillService.getOpenSession(_uid);
            if (openTill == null) {
              _toast('No open till session. Cash disbursement will be recorded but not posted to till.', false);
            }
          } catch (e) {
            debugPrint('Error getting till session: $e');
          }
        }
        
        await _runAction(
          action: () => LoanDisbursementService.disburseLoan(
            loanId: widget.loanId,
            disbursedBy: _uid,
            amount: amount,
            narration: narration.isEmpty ? 'Loan disbursement credited to savings' : narration,
          ),
          successMessage: 'Loan disbursed and credited to member savings',
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
      title: 'Reschedule loan',
      subtitle: 'Current duration: ${_s('duration', '0')} $unit',
      icon: Icons.schedule,
      color: _C.brand,
      submitLabel: 'Reschedule',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('New duration ($unit)', durationCtrl,
              number: true, hint: 'Enter new duration'),
          _field('Reason', reasonCtrl,
              maxLines: 3, hint: 'Why is this loan being rescheduled?'),
        ],
      ),
      validate: () => (int.tryParse(durationCtrl.text) ?? 0) <= 0
          ? 'Enter a valid duration'
          : null,
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
      title: 'Loan top-up',
      subtitle: 'Current loan: UGX ${_money(_principal)}',
      icon: Icons.add_circle_outline,
      color: _C.brand,
      submitLabel: 'Top up',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Top-up amount (UGX)', amountCtrl,
              number: true, hint: 'Enter additional amount'),
          _field('Reason', reasonCtrl, maxLines: 3, hint: 'Reason for top-up'),
        ],
      ),
      validate: () => (double.tryParse(amountCtrl.text) ?? 0) <= 0
          ? 'Enter a valid amount'
          : null,
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
    final interestOutstanding = _interestOut;
    final amountCtrl =
        TextEditingController(text: interestOutstanding.round().toString());
    final reasonCtrl = TextEditingController();

    await _showFormDialog(
      title: 'Waive interest',
      subtitle: 'Outstanding interest: UGX ${_money(interestOutstanding)}',
      icon: Icons.money_off,
      color: _C.brand,
      submitLabel: 'Waive',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('Amount to waive (UGX)', amountCtrl,
              number: true, hint: 'Enter amount to waive'),
          _field('Reason', reasonCtrl,
              maxLines: 3, hint: 'Why is interest being waived?'),
        ],
      ),
      validate: () {
        final a = double.tryParse(amountCtrl.text) ?? 0;
        if (a <= 0) return 'Enter a valid amount';
        if (a > interestOutstanding + 0.5) {
          return 'Amount is more than the outstanding interest';
        }
        if (reasonCtrl.text.trim().isEmpty) return 'Enter a reason';
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
      title: 'Write off loan',
      subtitle: _s('memberName'),
      icon: Icons.block,
      color: _C.red,
      submitLabel: 'Write off',
      bodyBuilder: (setS) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBanner(
              'This marks the loan as uncollectable bad debt and can\'t be undone.',
              _C.red,
              icon: Icons.warning_amber_rounded),
          _field('Reason', reasonCtrl,
              maxLines: 4, hint: 'Why is this loan being written off?'),
        ],
      ),
      validate: () => reasonCtrl.text.trim().isEmpty ? 'Enter a reason' : null,
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
      title: 'Close loan',
      subtitle: _s('memberName'),
      icon: Icons.check_circle_outline,
      color: _C.brand,
      submitLabel: 'Close loan',
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
  // TRANSFER FROM SAVINGS (logic unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showTransferFromSavingsDialog() async {
    final memberId = _memberDocId;
    if (memberId == null) {
      _toast('Member not found. Check that the member name matches exactly.',
          false);
      return;
    }

    final savings = _toD(_member?['savingsBalance']);
    if (savings <= 0) {
      _toast('This member has no savings to transfer', false);
      return;
    }

    final memberName =
        (_member?['name'] ?? _member?['fullName'] ?? _s('memberName'))
            .toString();
    final principalOut = _principalOut;
    final amountCtrl = TextEditingController();

    await _showFormDialog(
      title: 'Transfer from savings',
      subtitle: memberName,
      icon: Icons.swap_horiz,
      color: _C.brand,
      submitLabel: 'Transfer',
      bodyBuilder: (setS) {
        final amt = double.tryParse(amountCtrl.text) ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _C.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('Available savings', style: _t(13, c: _C.muted)),
                  const Spacer(),
                  _amount(savings, size: 15),
                ],
              ),
            ),
            _field('Amount to transfer (UGX)', amountCtrl,
                number: true,
                hint: 'Applied to loan principal',
                onChanged: (_) => setS(() {})),
            if (amt > 0 && amt <= savings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('New savings balance: UGX ${_money(savings - amt)}',
                    style: _t(12.5, c: _C.muted)),
              ),
            Text('Outstanding principal: UGX ${_money(principalOut)}',
                style: _t(12.5, c: _C.muted)),
          ],
        );
      },
      validate: () {
        final a = double.tryParse(amountCtrl.text.trim()) ?? 0;
        if (a <= 0) return 'Enter a valid amount';
        if (a > savings) {
          return 'Amount is more than available savings (UGX ${_money(savings)})';
        }
        if (a > principalOut + 0.5) {
          return 'Amount is more than outstanding principal (UGX ${_money(principalOut)})';
        }
        return null;
      },
      onSubmit: () async {
        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
        await _runAction(
          successMessage: 'Transfer completed',
          action: () async {
            final db = FirebaseFirestore.instance;

            await db
                .collection('saccoplus-members')
                .doc(memberId)
                .update({'savingsBalance': FieldValue.increment(-amount)});

            await db.collection(AppConstants.savingsCol).add({
              'tenantId': FirebaseService.sessionTenantId,
              'farmerId': memberId,
              'farmerName': memberName,
              'type': 'withdrawal',
              'amount': amount,
              'status': 'approved',
              'timestamp': Timestamp.now(),
              'approvedBy': _actor,
              'notes': 'Transfer to loan payment - Loan ID: ${widget.loanId}',
              'loanId': widget.loanId,
            });

            await db.collection(AppConstants.repaymentsCol).add({
              'loanId': widget.loanId,
              'memberId': memberId,
              'memberName': memberName,
              'tenantId': FirebaseService.sessionTenantId,
              'paymentDate': Timestamp.now(),
              'principalAmount': amount,
              'interestAmount': 0.0,
              'chargesAmount': 0.0,
              'amount': amount,
              'principalPaid': amount,
              'interestPaid': 0.0,
              'chargesPaid': 0.0,
              'totalAmount': amount,
              'paymentMethod': 'Transfer from Savings',
              'recordedBy': _actor,
              'createdAt': FieldValue.serverTimestamp(),
              'notes': 'Transferred from member savings account',
            });

            await db
                .collection(AppConstants.loansCol)
                .doc(widget.loanId)
                .update({
              'principalPaid': FieldValue.increment(amount),
              'principalOutstanding': FieldValue.increment(-amount),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            try {
              await ArrearsService.updateLoanArrears(widget.loanId);
            } catch (e) {
              debugPrint('Arrears update failed: $e');
            }

            return {
              'success': true,
              'message':
                  'Transfer completed. UGX ${_money(amount)} applied to the loan'
            };
          },
        );
      },
    );
    _disposeLater([amountCtrl]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECORD PAYMENT (logic unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showRecordPaymentDialog() async {
    final principalOutstanding = _principalOut;
    final interestOutstanding = _interestOut;
    final chargesOutstanding = _chargesOut;

    Widget methodTile(IconData icon, String title, String sub, String value) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(context, value),
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: _C.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.tint(_C.brand, 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _C.brand, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(14, w: FontWeight.w600, c: _C.ink)),
                    const SizedBox(height: 2),
                    Text(sub, style: _t(12, c: _C.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _C.muted),
            ],
          ),
        ),
      );
    }

    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Payment method',
            style: _t(17, w: FontWeight.w700, c: _C.ink)),
        content: SizedBox(
          width: _dialogWidth(ctx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              methodTile(Icons.payments_outlined, 'Cash',
                  'Record a cash payment received', 'cash'),
              methodTile(
                  Icons.smartphone_outlined,
                  'Mobile money',
                  'Send a payment request to the member\'s phone',
                  'mobile_money'),
            ],
          ),
        ),
      ),
    );

    if (method == null) return;

    if (method == 'mobile_money') {
      await showDialog(
        context: context,
        builder: (context) => LoanPaymentMobileMoneyDialog(
          principalOutstanding: principalOutstanding,
          interestOutstanding: interestOutstanding,
          chargesOutstanding: chargesOutstanding,
          memberName: _s('memberName', 'Member'),
          memberPhone: _memberPhone,
          onPaymentComplete: (paymentData) async {
            await _recordPayment(
              principalPaid: _toD(paymentData['principalPaid']),
              interestPaid: _toD(paymentData['interestPaid']),
              chargesPaid: _toD(paymentData['chargesPaid']),
              paymentMethod: 'Mobile Money',
              paymentDate: DateTime.now(),
              transactionId: paymentData['transactionId']?.toString(),
              provider: paymentData['provider']?.toString(),
              phoneNumber: paymentData['phoneNumber']?.toString(),
              tillSession: null, // Mobile money doesn't affect till
            );
          },
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => LoanPaymentCashDialog(
          principalOutstanding: principalOutstanding,
          interestOutstanding: interestOutstanding,
          chargesOutstanding: chargesOutstanding,
          memberName: _s('memberName', 'Member'),
          memberPhone: _memberPhone, // Pass member's phone to show in dialog
          onPaymentComplete: (paymentData) async {
            // Get the open till session for the current user
            TillSession? openTill;
            try {
              openTill = await TillService.getOpenSession(FirebaseService.sessionUid);
              if (openTill == null) {
                _toast('No open till session. Cash payment will be recorded but not posted to till.', false);
              }
            } catch (e) {
              debugPrint('Error getting till session: $e');
            }

            await _recordPayment(
              principalPaid: _toD(paymentData['principalPaid']),
              interestPaid: _toD(paymentData['interestPaid']),
              chargesPaid: _toD(paymentData['chargesPaid']),
              paymentMethod: 'Cash',
              paymentDate:
                  _toDate(paymentData['paymentDate']) ?? DateTime.now(),
              tillSession: openTill, // Pass the actual till session
              alternativePhone: paymentData['alternativePhone']?.toString(), // Pass alternative phone for SMS
            );
          },
        ),
      );
    }
  }

  Future<void> _recordPayment({
    required double principalPaid,
    required double interestPaid,
    required double chargesPaid,
    required String paymentMethod,
    required DateTime paymentDate,
    String? transactionId,
    String? provider,
    String? phoneNumber,
    TillSession? tillSession, // Optional till session for cash payments
    String? alternativePhone, // Optional alternative phone for SMS
  }) async {
    try {
      final total = principalPaid + interestPaid + chargesPaid;
      final db = FirebaseFirestore.instance;

      final paymentData = <String, dynamic>{
        'loanId': widget.loanId,
        'memberId':
            _loanData!['memberId'] ?? _loanData!['farmerId'] ?? _memberDocId,
        'memberName': _loanData!['memberName'],
        'tenantId': FirebaseService.sessionTenantId,
        'principalAmount': principalPaid,
        'interestAmount': interestPaid,
        'chargesAmount': chargesPaid,
        'amount': total,
        'principalPaid': principalPaid,
        'interestPaid': interestPaid,
        'chargesPaid': chargesPaid,
        'totalAmount': total,
        'paymentMethod': paymentMethod,
        'paymentDate': Timestamp.fromDate(paymentDate),
        'createdAt': FieldValue.serverTimestamp(),
        'recordedBy': _actor,
      };

      if (paymentMethod == 'Mobile Money') {
        paymentData['mobileMoneyProvider'] = provider ?? '';
        paymentData['mobileMoneyNumber'] = phoneNumber ?? '';
        paymentData['mobileMoneyTransactionId'] = transactionId ?? '';
      }

      // Save repayment record
      final repaymentRef =
          await db.collection(AppConstants.repaymentsCol).add(paymentData);
      final repaymentId = repaymentRef.id;

      // Post till entry if till session provided and payment is cash
      if (tillSession != null && paymentMethod == 'Cash') {
        try {
          final tillEntryInput = TillEntryInput.loanRepayment(
            amount: total.toInt(),
            memberId: _loanData!['memberId'] ??
                _loanData!['farmerId'] ??
                _memberDocId ??
                '',
            memberName: _loanData!['memberName'] ?? 'Unknown',
            memberPhone: _memberPhone, // Add member phone
            repaymentId: repaymentId,
            paymentMethod: 'Cash',
            notes:
                'Loan repayment - Principal: UGX ${_money(principalPaid)}, Interest: UGX ${_money(interestPaid)}',
          );

          await TillService.postEntry(
            tillSessionId: tillSession.id,
            tellerId: FirebaseService.sessionUid,
            tellerName: FirebaseService.sessionProfile?['name'] ?? 'Teller',
            input: tillEntryInput,
          );

          debugPrint('✅ Till entry posted for loan repayment $repaymentId');
        } catch (tillError) {
          // Till entry failure is non-critical - repayment already recorded
          debugPrint(
              '⚠️ Failed to post till entry for loan repayment: $tillError');
        }
      }

      await db.collection(AppConstants.loansCol).doc(widget.loanId).update({
        'principalPaid': FieldValue.increment(principalPaid),
        'interestPaid': FieldValue.increment(interestPaid),
        'chargesPaid': FieldValue.increment(chargesPaid),
        'principalOutstanding': FieldValue.increment(-principalPaid),
        'interestOutstanding': FieldValue.increment(-interestPaid),
        'chargesOutstanding': FieldValue.increment(-chargesPaid),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send SMS notification (non-critical)
      if (paymentMethod == 'Cash') {
        try {
          final memberName = _loanData!['memberName'] ?? 'Member';
          final memberPhone = _memberPhone ?? ''; // Handle null
          final altPhone = alternativePhone ?? '';
          
          // Get updated loan data for balances
          final updatedLoan = await db.collection(AppConstants.loansCol).doc(widget.loanId).get();
          final updatedData = updatedLoan.data();
          final principalOut = (updatedData?['principalOutstanding'] ?? 0).toInt();
          final interestOut = (updatedData?['interestOutstanding'] ?? 0).toInt();
          final chargesOut = (updatedData?['chargesOutstanding'] ?? 0).toInt();
          final totalOut = principalOut + interestOut + chargesOut;
          
          final smsMessage = 'MBADIFA SACCO\n'
              'Dear $memberName, your loan payment of UGX ${_money(total)} has been received. '
              'Principal: UGX ${_money(principalPaid)}, '
              'Interest: UGX ${_money(interestPaid)}. '
              'Outstanding balance: UGX ${_money(totalOut)}. '
              'Thank you.';
          
          // Send to member's phone if exists
          if (memberPhone.isNotEmpty) {
            await FirebaseService.sendSmsToPhone(memberPhone, smsMessage);
            debugPrint('✅ SMS sent to member phone: $memberPhone');
          }
          
          // Send to alternative phone if provided (can be in addition to member phone)
          if (altPhone.isNotEmpty) {
            await FirebaseService.sendSmsToPhone(altPhone, smsMessage);
            debugPrint('✅ SMS sent to alternative phone: $altPhone');
          }
          
          // Warn if no phone numbers available
          if (memberPhone.isEmpty && altPhone.isEmpty) {
            debugPrint('⚠️ No phone number available for SMS');
          }
        } catch (smsError) {
          debugPrint('⚠️ Failed to send SMS: $smsError');
        }
      }

      try {
        await ArrearsService.updateLoanArrears(widget.loanId);
      } catch (e) {
        debugPrint('Arrears update failed: $e');
      }

      await _loadLoanData();
      _toast('Payment of UGX ${_money(total)} recorded', true);
    } catch (e) {
      debugPrint('Error recording payment: $e');
      _toast('Couldn\'t record payment: $e', false);
    }
  }
}
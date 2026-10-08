import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/arrears_service.dart';
import 'loan_details_screen.dart';

/// Palette tuned to the navy sidebar. Red is reserved for money that is
/// actually overdue / high risk, so it carries meaning instead of decorating.
class _C {
  static const surface = Color(0xFFF6F7F9);
  static const card = Colors.white;
  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF6B7686);
  static const line = Color(0xFFE3E6EB);
  static const navy = Color(0xFF16243B);
  static const ok = Color(0xFF2F855A); // low risk
  static const warn = Color(0xFFB7791F); // 1 month / moderate risk
  static const high = Color(0xFFC2410C); // 2 months / high risk
  static const critical = Color(0xFFB42318); // 3+ months / critical risk
}

// ═════════════════════════════════════════════════════════════════════════
// Default-risk model
//
// A transparent, rule-based scorecard (logistic form) that uses ONLY the data
// on this screen. It is an early-warning estimate, NOT a statistically
// trained model or a credit-bureau score. Once you have enough historical
// outcomes (which loans really defaulted) the weights below can be re-fitted.
// ═════════════════════════════════════════════════════════════════════════

enum _RiskBand { low, moderate, high, critical }

class _Factor {
  final String label;
  final String value;
  final double effect; // contribution to the log-odds of default
  const _Factor(this.label, this.value, this.effect);
}

class _Risk {
  final double probability; // 0..1 chance of default
  final int score; // 0..100 repayment score (higher = safer)
  final _RiskBand band;
  final List<_Factor> factors;
  const _Risk(this.probability, this.score, this.band, this.factors);

  int get percent => (probability * 100).round();

  String get bandLabel {
    switch (band) {
      case _RiskBand.low:
        return 'Low risk';
      case _RiskBand.moderate:
        return 'Moderate risk';
      case _RiskBand.high:
        return 'High risk';
      case _RiskBand.critical:
        return 'Critical risk';
    }
  }

  Color get color {
    switch (band) {
      case _RiskBand.low:
        return _C.ok;
      case _RiskBand.moderate:
        return _C.warn;
      case _RiskBand.high:
        return _C.high;
      case _RiskBand.critical:
        return _C.critical;
    }
  }
}

class _RiskModel {
  static const _intercept = -2.2;
  static const _wMonths = 0.85; // each month overdue
  static const _wDue = 1.6; // total due as a share of the loan balance
  static const _wPenalty = 0.8; // penalties as a share of arrears
  static const _wPaid = -1.4; // share of the loan already repaid (protective)

  static double _n(Map<String, dynamic> l, String k) {
    final v = l[k];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  static _Risk assess(Map<String, dynamic> l) {
    final months = _n(l, 'monthsOverdue').clamp(0.0, 6.0).toDouble();
    final totalDue = _n(l, 'totalDue');
    final arrears = _n(l, 'arrears');
    final penalties = _n(l, 'penalties');

    final balance = _n(l, 'balance') > 0 ? _n(l, 'balance') : _n(l, 'totalAmount');
    final hasBalance = balance > 0;
    final dueRatio = hasBalance ? (totalDue / balance).clamp(0.0, 1.5).toDouble() : 0.3;

    final penaltyRatio = arrears > 0 ? (penalties / arrears).clamp(0.0, 1.0).toDouble() : 0.0;

    final loanTotal = _n(l, 'totalAmount');
    final paid = _n(l, 'amountPaid');
    final double? paidRatio =
        loanTotal > 0 ? (paid / loanTotal).clamp(0.0, 1.0).toDouble() : null;

    final fMonths = _wMonths * months;
    final fDue = _wDue * dueRatio;
    final fPenalty = _wPenalty * penaltyRatio;
    final fPaid = _wPaid * (paidRatio ?? 0);

    final z = _intercept + fMonths + fDue + fPenalty + fPaid;
    final p = 1 / (1 + math.exp(-z));

    final band = p < 0.25
        ? _RiskBand.low
        : p < 0.50
            ? _RiskBand.moderate
            : p < 0.75
                ? _RiskBand.high
                : _RiskBand.critical;

    return _Risk(
      p,
      ((1 - p) * 100).round(),
      band,
      [
        _Factor(
          'Months overdue',
          months.toInt() == 1 ? '1 month' : '${months.toInt()} months',
          fMonths,
        ),
        _Factor(
          'Amount due vs loan balance',
          hasBalance ? '${(dueRatio * 100).round()}% of balance' : 'Balance not available',
          fDue,
        ),
        _Factor(
          'Penalties vs arrears',
          '${(penaltyRatio * 100).round()}% of arrears',
          fPenalty,
        ),
        _Factor(
          'Repayment progress',
          paidRatio == null ? 'Not available' : '${(paidRatio * 100).round()}% repaid',
          fPaid,
        ),
      ],
    );
  }
}

enum _SortKey { totalDue, risk }

class ArrearsManagementScreen extends StatefulWidget {
  const ArrearsManagementScreen({Key? key}) : super(key: key);

  @override
  State<ArrearsManagementScreen> createState() =>
      _ArrearsManagementScreenState();
}

class _ArrearsManagementScreenState extends State<ArrearsManagementScreen> {
  // ── Responsive breakpoints (measured on the space AFTER the sidebar) ──
  static const double _wideBreakpoint = 860; // table + 4-up stats
  static const double _midBreakpoint = 560; // 2x2 stats
  static const double _maxContentWidth = 2000; // only caps ultra-wide monitors

  final _money = NumberFormat('#,###', 'en_US');
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  DateTime? _lastChecked;
  List<Map<String, dynamic>> _loans = [];
  _SortKey _sortKey = _SortKey.totalDue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _num(Map<String, dynamic> l, String k) {
    final v = l[k];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  int _months(Map<String, dynamic> l) => _num(l, 'monthsOverdue').toInt();

  String _fmt(double v) => _money.format(v.round());

  _Risk _risk(Map<String, dynamic> l) => _RiskModel.assess(l);

  List<Map<String, dynamic>> get _sorted {
    final list = List<Map<String, dynamic>>.from(_loans);
    if (_sortKey == _SortKey.risk) {
      list.sort((a, b) => _risk(b).probability.compareTo(_risk(a).probability));
    } else {
      list.sort((a, b) => _num(b, 'totalDue').compareTo(_num(a, 'totalDue')));
    }
    return list;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final loans = await ArrearsService.getLoansWithArrears();
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _lastChecked = DateTime.now();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not load loans in arrears. Check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _recalculate() async {
    if (!mounted) return;
    setState(() => _isUpdating = true);
    final result = await ArrearsService.updateAllLoansArrears();
    if (!mounted) return;
    setState(() => _isUpdating = false);

    final failed = result['failed'] ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _C.navy,
        width: 420,
        content: Text(
          failed == 0
              ? 'Arrears recalculated for ${result['success']} loans'
              : 'Recalculated ${result['success']} loans, $failed failed',
          style: GoogleFonts.inter(fontSize: 13),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AppBar(
        backgroundColor: _C.card,
        foregroundColor: _C.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 24,
        title: Text(
          'Arrears management',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _C.ink,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _C.line),
        ),
      ),
      body: _isLoading && _loans.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _Notice(
                  title: 'Something went wrong',
                  body: _error!,
                  actionLabel: 'Try again',
                  onAction: _load,
                )
              : _loans.isEmpty
                  ? _Notice(
                      title: 'No loans are in arrears',
                      body: _lastChecked == null
                          ? 'Every active loan is up to date.'
                          : 'Every active loan is up to date. Last checked at ${DateFormat('HH:mm').format(_lastChecked!)}.',
                      actionLabel: 'Check again',
                      onAction: _load,
                    )
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final totalArrears =
        _loans.fold<double>(0, (s, l) => s + _num(l, 'arrears'));
    final totalPenalties =
        _loans.fold<double>(0, (s, l) => s + _num(l, 'penalties'));
    // Same field the table's "Total due" column uses, so card and table agree.
    final totalDue = _loans.fold<double>(0, (s, l) => s + _num(l, 'totalDue'));

    // Expected loss = sum of (chance of default x amount due) per loan.
    final expectedLoss = _loans.fold<double>(
        0, (s, l) => s + _risk(l).probability * _num(l, 'totalDue'));
    final avgRisk = totalDue > 0
        ? expectedLoss / totalDue
        : _loans.fold<double>(0, (s, l) => s + _risk(l).probability) /
            _loans.length;

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final wide = w >= _wideBreakpoint;
      final pad = w < 360 ? 12.0 : (w < _midBreakpoint ? 16.0 : (wide ? 28.0 : 20.0));

      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(narrow: w < _midBreakpoint),
                    SizedBox(height: wide ? 22 : 16),
                    _stats(w, totalDue, totalArrears, totalPenalties,
                        expectedLoss, avgRisk),
                    SizedBox(height: wide ? 22 : 16),
                    if (wide)
                      _table()
                    else ...[
                      _sortBar(),
                      const SizedBox(height: 12),
                      _stackedList(),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Default risk is an estimate from arrears data on this page '
                      '(months overdue, amount due vs balance, penalties, repayment '
                      'progress). It is an early-warning guide, not a credit-bureau score.',
                      style: GoogleFonts.inter(
                          fontSize: 11.5, height: 1.5, color: _C.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _header({required bool narrow}) {
    final n = _loans.length;
    final noun = n == 1 ? 'loan is' : 'loans are';
    final sub = _lastChecked == null
        ? '$n $noun past the due date'
        : '$n $noun past the due date, as of ${DateFormat('d MMM, HH:mm').format(_lastChecked!)}';

    final refresh = OutlinedButton(
      onPressed: _isLoading ? null : _load,
      style: _outlined,
      child: const Text('Refresh list'),
    );
    final recalc = FilledButton(
      onPressed: _isUpdating ? null : _recalculate,
      style: FilledButton.styleFrom(
        backgroundColor: _C.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: _isUpdating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Text('Recalculate arrears'),
    );

    final text = Text(sub, style: GoogleFonts.inter(fontSize: 13, color: _C.muted));

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: refresh),
            const SizedBox(width: 8),
            Expanded(child: recalc),
          ]),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 12),
        refresh,
        const SizedBox(width: 8),
        recalc,
      ],
    );
  }

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
        foregroundColor: _C.ink,
        side: const BorderSide(color: _C.line),
        backgroundColor: _C.card,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      );

  // One bordered strip with dividers instead of separate coloured cards.
  // >= 860: four across.  560-860: 2x2 grid.  Below: stacked.
  Widget _stats(double w, double due, double arrears, double penalties,
      double expectedLoss, double avgRisk) {
    final cells = [
      _stat('Total due', 'UGX ${_fmt(due)}', emphasis: true),
      _stat('Arrears', 'UGX ${_fmt(arrears)}'),
      _stat('Penalties', 'UGX ${_fmt(penalties)}'),
      _stat(
        'Estimated expected loss',
        'UGX ${_fmt(expectedLoss)}',
        note: 'Average default risk ${(avgRisk * 100).round()}%',
      ),
    ];

    Widget body;
    if (w >= _wideBreakpoint) {
      body = IntrinsicHeight(
        child: Row(children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1, color: _C.line),
            Expanded(child: cells[i]),
          ]
        ]),
      );
    } else if (w >= _midBreakpoint) {
      body = Column(children: [
        IntrinsicHeight(
          child: Row(children: [
            Expanded(child: cells[0]),
            const VerticalDivider(width: 1, color: _C.line),
            Expanded(child: cells[1]),
          ]),
        ),
        const Divider(height: 1, color: _C.line),
        IntrinsicHeight(
          child: Row(children: [
            Expanded(child: cells[2]),
            const VerticalDivider(width: 1, color: _C.line),
            Expanded(child: cells[3]),
          ]),
        ),
      ]);
    } else {
      body = Column(children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: _C.line),
          cells[i],
        ]
      ]);
    }

    return Container(decoration: _boxed, clipBehavior: Clip.antiAlias, child: body);
  }

  Widget _stat(String label, String value, {bool emphasis = false, String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: _figures(
                size: emphasis ? 22 : 18,
                weight: FontWeight.w600,
                color: emphasis ? _C.critical : _C.ink,
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note, style: GoogleFonts.inter(fontSize: 11.5, color: _C.muted)),
          ],
        ],
      ),
    );
  }

  BoxDecoration get _boxed => BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.line),
      );

  TextStyle _figures({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = _C.ink,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  Color _severity(int months) =>
      months >= 3 ? _C.critical : (months == 2 ? _C.high : _C.warn);

  void _open(Map<String, dynamic> loan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LoanDetailsScreen(loanId: loan['loanId'], initialLoanData: loan),
      ),
    );
  }

  // ---- Risk widgets --------------------------------------------------------

  /// Percent, band label and a thin bar. Tap for the full breakdown.
  Widget _riskCell(Map<String, dynamic> loan) {
    final r = _risk(loan);
    return InkWell(
      onTap: () => _showRisk(loan),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 2, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('${r.percent}%',
                  style: _figures(size: 14, weight: FontWeight.w600, color: r.color)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(r.bandLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: r.probability,
                minHeight: 5,
                backgroundColor: _C.line,
                valueColor: AlwaysStoppedAnimation(r.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskChip(Map<String, dynamic> loan) {
    final r = _risk(loan);
    return InkWell(
      onTap: () => _showRisk(loan),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: r.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${r.percent}% default risk',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: r.color)),
          const SizedBox(width: 4),
          Icon(Icons.info_outline_rounded, size: 14, color: r.color),
        ]),
      ),
    );
  }

  void _showRisk(Map<String, dynamic> loan) {
    final r = _risk(loan);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
        title: Text(
          loan['memberName'] ?? 'Unknown member',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: _C.ink),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: r.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: r.color.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimated chance of default',
                              style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
                          const SizedBox(height: 4),
                          Text('${r.percent}%',
                              style: _figures(size: 30, weight: FontWeight.w700, color: r.color)),
                          Text(r.bandLabel,
                              style: GoogleFonts.inter(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: r.color)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Repayment score',
                            style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: _figures(size: 26, weight: FontWeight.w700),
                            children: [
                              TextSpan(text: '${r.score}'),
                              TextSpan(
                                text: ' / 100',
                                style: _figures(size: 13, color: _C.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                Text('What drives this score',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _C.ink)),
                const SizedBox(height: 8),
                for (final f in r.factors) _factorRow(f),
                const SizedBox(height: 10),
                Text(
                  'Based only on arrears data. It guides who to follow up first; '
                  'it is not a credit-bureau score or a final decision.',
                  style: GoogleFonts.inter(fontSize: 11.5, height: 1.5, color: _C.muted),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _open(loan);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _C.navy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Open loan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _factorRow(_Factor f) {
    final raises = f.effect > 0.05;
    final lowers = f.effect < -0.05;
    final strength = f.effect.abs() >= 2
        ? 'strongly'
        : f.effect.abs() >= 0.8
            ? 'moderately'
            : 'slightly';
    final text = raises
        ? 'Raises risk $strength'
        : lowers
            ? 'Lowers risk $strength'
            : 'Little effect';
    final color = raises ? _C.high : (lowers ? _C.ok : _C.muted);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.label,
                    style: GoogleFonts.inter(fontSize: 13, color: _C.ink)),
                Text(f.value,
                    style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  /// Sort control for the narrow (card) layout.
  Widget _sortBar() {
    Widget chip(String label, _SortKey k) => ChoiceChip(
          label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
          selected: _sortKey == k,
          selectedColor: _C.navy.withOpacity(0.12),
          backgroundColor: _C.card,
          side: const BorderSide(color: _C.line),
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => _sortKey = k),
        );
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Sort by', style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
        chip('Highest due', _SortKey.totalDue),
        chip('Highest risk', _SortKey.risk),
      ],
    );
  }

  // ---- Wide layout: a real table, numbers right-aligned -------------------

  // member, ref, overdue, risk, arrears, penalties, total
  static const _flex = [21, 17, 12, 15, 11, 11, 13];

  Widget _table() {
    final rows = _sorted;
    final arrears = _loans.fold<double>(0, (s, l) => s + _num(l, 'arrears'));
    final penalties = _loans.fold<double>(0, (s, l) => s + _num(l, 'penalties'));
    final due = _loans.fold<double>(0, (s, l) => s + _num(l, 'totalDue'));

    return Container(
      decoration: _boxed,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(children: [
              _th('Member', _flex[0]),
              _th('Account / reference', _flex[1]),
              _th('Overdue', _flex[2]),
              _th('Default risk', _flex[3], sort: _SortKey.risk),
              _th('Arrears', _flex[4], right: true),
              _th('Penalties', _flex[5], right: true),
              _th('Total due', _flex[6], right: true, sort: _SortKey.totalDue),
            ]),
          ),
          for (final loan in rows) ...[
            const Divider(height: 1, color: _C.line),
            _row(loan),
          ],
          const Divider(height: 1, color: _C.line),
          // Totals line, aligned to the same columns as the rows above.
          Container(
            color: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(children: [
              Expanded(
                flex: _flex[0] + _flex[1] + _flex[2] + _flex[3],
                child: Text(
                  _loans.length == 1 ? 'Total (1 loan)' : 'Total (${_loans.length} loans)',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: _C.ink),
                ),
              ),
              Expanded(
                flex: _flex[4],
                child: Text(_fmt(arrears),
                    textAlign: TextAlign.right,
                    style: _figures(weight: FontWeight.w600)),
              ),
              Expanded(
                flex: _flex[5],
                child: Text(_fmt(penalties),
                    textAlign: TextAlign.right,
                    style: _figures(weight: FontWeight.w600)),
              ),
              Expanded(
                flex: _flex[6],
                child: Text(_fmt(due),
                    textAlign: TextAlign.right,
                    style: _figures(weight: FontWeight.w700, color: _C.critical)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _th(String t, int flex, {bool right = false, _SortKey? sort}) {
    final active = sort != null && _sortKey == sort;
    final label = Text(
      t,
      style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? _C.ink : _C.muted),
    );
    final child = sort == null
        ? label
        : InkWell(
            onTap: () => setState(() => _sortKey = sort),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                label,
                if (active)
                  const Padding(
                    padding: EdgeInsets.only(left: 3),
                    child: Icon(Icons.arrow_downward_rounded, size: 13, color: _C.ink),
                  ),
              ],
            ),
          );
    return Expanded(
      flex: flex,
      child: Align(
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }

  Widget _row(Map<String, dynamic> loan) {
    final months = _months(loan);
    final phone = (loan['phoneNumber'] ?? '').toString();
    return InkWell(
      onTap: () => _open(loan),
      hoverColor: _C.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            flex: _flex[0],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loan['memberName'] ?? 'Unknown member',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.ink)),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(phone, style: _figures(size: 12, color: _C.muted)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: _flex[1],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${loan['accountNumber'] ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _figures(size: 13)),
                const SizedBox(height: 2),
                Text('${loan['referenceNumber'] ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _figures(size: 12, color: _C.muted)),
              ],
            ),
          ),
          Expanded(flex: _flex[2], child: _overdue(months)),
          Expanded(flex: _flex[3], child: _riskCell(loan)),
          Expanded(
            flex: _flex[4],
            child: Text(_fmt(_num(loan, 'arrears')),
                textAlign: TextAlign.right, style: _figures()),
          ),
          Expanded(
            flex: _flex[5],
            child: Text(_fmt(_num(loan, 'penalties')),
                textAlign: TextAlign.right, style: _figures()),
          ),
          Expanded(
            flex: _flex[6],
            child: Text(_fmt(_num(loan, 'totalDue')),
                textAlign: TextAlign.right,
                style: _figures(weight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _overdue(int months) {
    final c = _severity(months);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Text(
        months == 1 ? '1 month' : '$months months',
        style: GoogleFonts.inter(fontSize: 13, color: _C.ink),
      ),
    ]);
  }

  // ---- Narrow layout: compact rows ----------------------------------------

  Widget _stackedList() {
    final rows = _sorted;
    return Container(
      decoration: _boxed,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _C.line),
            _compact(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _compact(Map<String, dynamic> loan) {
    final months = _months(loan);
    return InkWell(
      onTap: () => _open(loan),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(loan['memberName'] ?? 'Unknown member',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.ink)),
              ),
              const SizedBox(width: 8),
              _overdue(months),
            ]),
            const SizedBox(height: 2),
            Text(
              'A/C ${loan['accountNumber'] ?? '-'}   Ref ${loan['referenceNumber'] ?? '-'}',
              style: _figures(size: 12, color: _C.muted),
            ),
            const SizedBox(height: 10),
            _riskChip(loan),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              runSpacing: 6,
              spacing: 12,
              children: [
                Text(
                  'Arrears ${_fmt(_num(loan, 'arrears'))}  Penalties ${_fmt(_num(loan, 'penalties'))}',
                  style: _figures(size: 12, color: _C.muted),
                ),
                Text('UGX ${_fmt(_num(loan, 'totalDue'))}',
                    style: _figures(weight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared empty / error state: plain text, one action, no hero icon.
class _Notice extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _Notice({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600, color: _C.ink)),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, height: 1.5, color: _C.muted)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.ink,
                  side: const BorderSide(color: _C.line),
                  backgroundColor: _C.card,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  textStyle: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
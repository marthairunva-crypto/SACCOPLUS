import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/arrears_service.dart';
import 'loan_details_screen.dart';

/// Palette tuned to the navy sidebar. Red is reserved for money that is
/// actually overdue, so it carries meaning instead of decorating the page.
class _C {
  static const surface = Color(0xFFF6F7F9);
  static const card = Colors.white;
  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF6B7686);
  static const line = Color(0xFFE3E6EB);
  static const navy = Color(0xFF16243B);
  static const warn = Color(0xFFB7791F); // 1 month
  static const high = Color(0xFFC2410C); // 2 months
  static const critical = Color(0xFFB42318); // 3+ months
}

class ArrearsManagementScreen extends StatefulWidget {
  const ArrearsManagementScreen({Key? key}) : super(key: key);

  @override
  State<ArrearsManagementScreen> createState() =>
      _ArrearsManagementScreenState();
}

class _ArrearsManagementScreenState extends State<ArrearsManagementScreen> {
  final _money = NumberFormat('#,###', 'en_US');
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  DateTime? _lastChecked;
  List<Map<String, dynamic>> _loans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _num(Map<String, dynamic> l, String k) => (l[k] ?? 0).toDouble();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final loans = await ArrearsService.getLoansWithArrears();
      loans.sort((a, b) => _num(b, 'totalDue').compareTo(_num(a, 'totalDue')));
      if (!mounted) return;
      setState(() {
        _loans = loans;
        _lastChecked = DateTime.now();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load loans in arrears. Check your connection and try again.';
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
    final totalArrears = _loans.fold<double>(0, (s, l) => s + _num(l, 'arrears'));
    final totalPenalties =
        _loans.fold<double>(0, (s, l) => s + _num(l, 'penalties'));
    final totalDue = totalArrears + totalPenalties;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 860;
          return ListView(
            padding: EdgeInsets.all(wide ? 24 : 16),
            children: [
              _header(),
              const SizedBox(height: 20),
              _stats(wide, totalDue, totalArrears, totalPenalties),
              const SizedBox(height: 20),
              wide ? _table() : _stackedList(),
            ],
          );
        }),
      ),
    );
  }

  Widget _header() {
    final sub = _lastChecked == null
        ? '${_loans.length} loans past their due date'
        : '${_loans.length} loans past their due date, as of ${DateFormat('d MMM, HH:mm').format(_lastChecked!)}';
    return Row(
      children: [
        Expanded(
          child: Text(sub,
              style: GoogleFonts.inter(fontSize: 13, color: _C.muted)),
        ),
        OutlinedButton(
          onPressed: _isLoading ? null : _load,
          style: _outlined,
          child: const Text('Refresh list'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _isUpdating ? null : _recalculate,
          style: FilledButton.styleFrom(
            backgroundColor: _C.navy,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle:
                GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Recalculate arrears'),
        ),
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

  // One bordered strip with dividers instead of three separate coloured cards.
  Widget _stats(bool wide, double due, double arrears, double penalties) {
    final cells = [
      _stat('Total due', 'UGX ${_money.format(due.round())}', emphasis: true),
      _stat('Arrears', 'UGX ${_money.format(arrears.round())}'),
      _stat('Penalties', 'UGX ${_money.format(penalties.round())}'),
      _stat('Loans affected', '${_loans.length}'),
    ];
    return Container(
      decoration: _boxed,
      child: wide
          ? IntrinsicHeight(
              child: Row(children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) const VerticalDivider(width: 1, color: _C.line),
                  Expanded(child: cells[i]),
                ]
              ]),
            )
          : Column(children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _C.line),
                cells[i],
              ]
            ]),
    );
  }

  Widget _stat(String label, String value, {bool emphasis = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: _C.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: _figures(
              size: emphasis ? 20 : 17,
              weight: FontWeight.w600,
              color: emphasis ? _C.critical : _C.ink,
            ),
          ),
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

  // ---- Wide layout: a real table, numbers right-aligned -------------------

  static const _flex = [26, 22, 14, 13, 13, 14]; // member, ref, overdue, arrears, penalties, total

  Widget _table() {
    return Container(
      decoration: _boxed,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _C.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              _th('Member', _flex[0]),
              _th('Account / reference', _flex[1]),
              _th('Overdue', _flex[2]),
              _th('Arrears', _flex[3], right: true),
              _th('Penalties', _flex[4], right: true),
              _th('Total due', _flex[5], right: true),
            ]),
          ),
          for (final loan in _loans) ...[
            const Divider(height: 1, color: _C.line),
            _row(loan),
          ],
        ],
      ),
    );
  }

  Widget _th(String t, int flex, {bool right = false}) => Expanded(
        flex: flex,
        child: Text(
          t,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: _C.muted),
        ),
      );

  Widget _row(Map<String, dynamic> loan) {
    final months = (loan['monthsOverdue'] ?? 0) as int;
    final phone = (loan['phoneNumber'] ?? '').toString();
    return InkWell(
      onTap: () => _open(loan),
      hoverColor: _C.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
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
                    child: Text(phone,
                        style: _figures(size: 12, color: _C.muted)),
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
                    style: _figures(size: 13)),
                const SizedBox(height: 2),
                Text('${loan['referenceNumber'] ?? '-'}',
                    style: _figures(size: 12, color: _C.muted)),
              ],
            ),
          ),
          Expanded(flex: _flex[2], child: _overdue(months)),
          Expanded(
            flex: _flex[3],
            child: Text(_money.format(_num(loan, 'arrears').round()),
                textAlign: TextAlign.right, style: _figures()),
          ),
          Expanded(
            flex: _flex[4],
            child: Text(_money.format(_num(loan, 'penalties').round()),
                textAlign: TextAlign.right, style: _figures()),
          ),
          Expanded(
            flex: _flex[5],
            child: Text(_money.format(_num(loan, 'totalDue').round()),
                textAlign: TextAlign.right,
                style: _figures(weight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _overdue(int months) {
    final c = _severity(months);
    return Row(children: [
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
    return Container(
      decoration: _boxed,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _loans.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _C.line),
            _compact(_loans[i]),
          ],
        ],
      ),
    );
  }

  Widget _compact(Map<String, dynamic> loan) {
    final months = (loan['monthsOverdue'] ?? 0) as int;
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
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.ink)),
              ),
              _overdue(months),
            ]),
            const SizedBox(height: 2),
            Text(
              'A/C ${loan['accountNumber'] ?? '-'}   Ref ${loan['referenceNumber'] ?? '-'}',
              style: _figures(size: 12, color: _C.muted),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Arrears ${_money.format(_num(loan, 'arrears').round())}  Penalties ${_money.format(_num(loan, 'penalties').round())}',
                  style: _figures(size: 12, color: _C.muted),
                ),
                Text('UGX ${_money.format(_num(loan, 'totalDue').round())}',
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
    );
  }
}
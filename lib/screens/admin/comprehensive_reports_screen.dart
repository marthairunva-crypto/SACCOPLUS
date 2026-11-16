import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/report_service.dart';
import '../../utils/file_saver.dart';
import '../../core/firebase_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Design tokens & helpers
// ═══════════════════════════════════════════════════════════════════════════════
class _C {
  static const navy = Color(0xFF0B2545);
  static const blue = Color(0xFF1D4ED8);
  static const bg = Color(0xFFF4F6FA);
  static const border = Color(0xFFE3E8EF);
  static const text = Color(0xFF111827);
  static const ink = Color(0xFF111827); // Alias for text
  static const muted = Color(0xFF6B7280);
  static const green = Color(0xFF15803D);
  static const red = Color(0xFFB91C1C);
  static const amber = Color(0xFFB45309);
  static const teal = Color(0xFF0F766E);
  static const purple = Color(0xFF6D28D9);
}

const List<Color> _palette = [_C.blue, _C.teal, _C.purple, _C.amber, _C.green, _C.red];

TextStyle _ps(double size, {FontWeight w = FontWeight.w400, Color c = _C.text, double? ls}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);

num _n(dynamic v) => v is num ? v : (num.tryParse('${v ?? ''}') ?? 0);
Map _m(dynamic v) => v is Map ? v : const {};

DateTime? _dt(dynamic v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _cap(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}

final NumberFormat _nf = NumberFormat('#,##0', 'en_US');

/// Accounting style: negatives in brackets, zero as a dash.
String _money(num v, {bool dash = true}) {
  if (v == 0) return dash ? '–' : '0';
  final s = _nf.format(v.abs().round());
  return v < 0 ? '($s)' : s;
}

/// Currency in running text: negatives get a minus sign (no double brackets).
String _ugx(num v) => v < 0 ? '-UGX ${_nf.format(v.abs().round())}' : 'UGX ${_nf.format(v.round())}';

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.border),
    );

/// Page gutters grow with the screen; content may use up to [_maxContentWidth].
const double _maxContentWidth = 1800;
double _padFor(double w) => w < 600 ? 12 : (w < 1024 ? 16 : 24);

void _toast(BuildContext context, String msg, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? _C.red : _C.green,
    behavior: SnackBarBehavior.floating,
  ));
}

Future<void> _saveCsv(BuildContext context, String name, String csv) async {
  try {
    await FileSaver.saveFile(fileName: name, content: csv, mimeType: 'text/csv');
    _toast(context, 'Exported $name');
  } catch (e) {
    _toast(context, 'Export failed: $e', error: true);
  }
}

String _q(String s) => '"${s.replaceAll('"', '""')}"';

// ═══════════════════════════════════════════════════════════════════════════════
// Accounting position (single source of truth for Trial Balance & Balance Sheet)
// ═══════════════════════════════════════════════════════════════════════════════
class _Issue {
  final String title;
  final String body;
  final bool critical;
  const _Issue(this.title, this.body, {this.critical = false});
}

class _Position {
  final DateTime asOf;
  final num cash, principal, interest, savings, shares, fixedDeposits;

  _Position({
    required this.asOf,
    required this.cash,
    required this.principal,
    required this.interest,
    required this.savings,
    required this.shares,
    required this.fixedDeposits,
  });

  factory _Position.fromTrialBalance(Map tb) {
    final a = _m(tb['assets']);
    final lr = _m(a['loansReceivable']);
    final l = _m(tb['liabilities']);
    final e = _m(tb['equity']);
    final d = tb['asOfDate'];
    return _Position(
      asOf: d is DateTime ? d : DateTime.now(),
      cash: a.containsKey('liquid') ? _n(a['liquid']) : _n(a['cashInHand']),
      principal: _n(lr['principal']),
      interest: _n(lr['interest']),
      savings: _n(l['memberSavings']), // includes wallets
      fixedDeposits: _n(l['fixedDeposits']),
      shares: _n(e['shareCapital']), // shares live under equity
    );
  }

  num get assets => cash + principal + interest;

  /// Member savings (incl. wallets) & fixed deposits are liabilities. Shares are EQUITY.
  num get liabilities => savings + fixedDeposits;

  /// Balancing figure. Negative = deficit / unreconciled.
  num get retained => assets - liabilities - shares;
  num get equity => shares + retained;

  /// Member money that is not out on loan - should exist as cash / bank / mobile money.
  num get expectedLiquid => savings + shares + fixedDeposits - principal;

  bool get cashMissing => cash == 0 && expectedLiquid > 0;

  String get balancingLabel => cashMissing
      ? 'Unreconciled balance (cash not recorded)'
      : (retained < 0 ? 'Accumulated deficit' : 'Retained earnings');

  List<_Issue> get issues {
    final out = <_Issue>[];
    if (cashMissing) {
      out.add(_Issue(
        'Cash, bank and mobile money not recorded',
        'Members hold ${_ugx(savings + shares + fixedDeposits)} in savings and share capital, and ${_ugx(principal)} is out on loan. '
            'About ${_ugx(expectedLiquid)} should therefore be held as cash, bank or mobile money, but none is recorded. '
            'Add your account balances under Finance > Cash & Bank. Until then the balancing line is unreconciled, not a real loss.',
        critical: true,
      ));
    } else if (retained < 0) {
      out.add(_Issue(
        'Accumulated deficit',
        'Retained earnings is the balancing figure (assets - liabilities - share capital). A deficit of ${_ugx(-retained)} '
            'means expenses or losses exceed recorded income, or entries are missing.',
      ));
    }
    return out;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Statement rows (shared by screen, CSV and PDF)
// ═══════════════════════════════════════════════════════════════════════════════
enum _K { header, sub, item, total, grand, warning }

class _Row {
  final _K kind;
  final String label;
  final num? amount;
  final String? hint;
  final bool showZero;
  final bool isFirst;
  final bool isGrand;
  const _Row(this.kind, this.label, [this.amount, this.hint, this.showZero = false, this.isFirst = false, this.isGrand = false]);
  const _Row.header(String label) : this(_K.header, label);
  const _Row.sub(String label) : this(_K.sub, label);
  const _Row.item(String label, num amount, {String? hint, bool showZero = false, bool isFirst = false, bool isGrand = false})
      : this(_K.item, label, amount, hint, showZero, isFirst, isGrand);
  const _Row.total(String label, num amount) : this(_K.total, label, amount);
  const _Row.grand(String label, num amount) : this(_K.grand, label, amount);
  const _Row.warning(String label, String hint) : this(_K.warning, label, null, hint);
}

String _rowsToCsv(String title, DateTime asOf, List<_Row> rows) {
  final b = StringBuffer()
    ..writeln('MBADIFA SACCO')
    ..writeln(title)
    ..writeln('As at ${DateFormat('d MMMM yyyy').format(asOf)}')
    ..writeln('Amounts in UGX')
    ..writeln('');
  for (final r in rows) {
    if (r.kind == _K.header) {
      b.writeln('');
      b.writeln(_q(r.label));
    } else {
      b.writeln('${_q(r.label)},${r.amount ?? ''}');
    }
  }
  return b.toString();
}

pw.Widget _pdfRow(_Row r) {
  final amt = r.amount == null ? '' : _money(r.amount!, dash: false);
  if (r.kind == _K.header) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
      child: pw.Text(r.label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
    );
  }
  if (r.kind == _K.sub) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
      child: pw.Text(r.label, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
    );
  }
  final bold = r.kind == _K.total || r.kind == _K.grand;
  return pw.Container(
    padding: pw.EdgeInsets.symmetric(vertical: bold ? 5 : 3),
    decoration: bold ? pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.6))) : null,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(r.label,
            style: pw.TextStyle(
                fontSize: r.kind == _K.grand ? 12 : 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(amt,
            style: pw.TextStyle(
                fontSize: r.kind == _K.grand ? 12 : 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    ),
  );
}

Future<void> _printStatement(String title, DateTime asOf, List<_Row> rows) async {
  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Center(
        child: pw.Column(children: [
          pw.Text('MBADIFA SACCO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          pw.Text('As at ${DateFormat('d MMMM yyyy').format(asOf)}   |   Amounts in UGX',
              style: const pw.TextStyle(fontSize: 9)),
        ]),
      ),
      pw.SizedBox(height: 18),
      ...rows.map(_pdfRow),
    ],
  ));
  await Printing.layoutPdf(onLayout: (PdfPageFormat f) async => pdf.save());
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════════════════════
Widget _amount(num v, {bool bold = false, double size = 13, bool showZero = false}) {
  final color = v < 0 ? _C.red : (v == 0 ? _C.muted : _C.text);
  return Text(
    _money(v, dash: !showZero),
    style: GoogleFonts.robotoMono(
        fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color),
  );
}

class _PageHeader extends StatelessWidget {
  final String title, subtitle;
  final Widget? trailing;
  const _PageHeader({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final pad = _padFor(box.maxWidth);
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _C.border)),
        ),
        padding: EdgeInsets.symmetric(horizontal: pad + 4, vertical: 14),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _ps(20, w: FontWeight.w700, c: _C.navy)),
                Text(subtitle, style: _ps(12, c: _C.muted)),
              ],
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
    });
  }
}

/// Loads a report and lays its widgets out using the full available width.
class _ReportLoader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final List<Widget> Function(BuildContext context, T data) builder;
  const _ReportLoader({super.key, required this.load, required this.builder});

  @override
  State<_ReportLoader<T>> createState() => _ReportLoaderState<T>();
}

class _ReportLoaderState<T> extends State<_ReportLoader<T>> {
  T? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    print('🔵 _ReportLoader initState - loading data...');
    _run();
  }
  
  @override
  void didUpdateWidget(_ReportLoader<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If key changed (which it does when refresh is triggered), reload data
    if (widget.key != oldWidget.key) {
      print('🔄 _ReportLoader didUpdateWidget - key changed, reloading...');
      _run();
    }
  }

  Future<void> _run({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final d = await widget.load().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('TimeoutException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!, onRetry: _run);
    final data = _data;
    if (data == null) {
      return const Center(child: Text('No data available'));
    }
    return RefreshIndicator(
      onRefresh: () => _run(silent: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = _padFor(constraints.maxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 32),
                children: widget.builder(context, data),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _C.red),
            const SizedBox(height: 12),
            Text('Could not load report', style: _ps(17, w: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: _ps(12.5, c: _C.muted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: _C.navy, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const _EmptyCard({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Icon(icon, size: 48, color: _C.muted.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text(title, style: _ps(16, w: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: _ps(13, c: _C.muted)),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  const _Kpi({required this.label, required this.value, required this.icon, required this.color, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _ps(11.5, w: FontWeight.w500, c: _C.muted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: _ps(18, w: FontWeight.w700, c: _C.navy)),
                ),
                if (sub != null)
                  Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ps(11, c: _C.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxCols;
  const _KpiGrid({required this.children, this.maxCols = 4});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      var cols = w >= 900 ? maxCols : (w >= 560 ? 2 : 1);
      if (cols > maxCols) cols = maxCols;
      const gap = 12.0;
      final itemW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children.map((e) => SizedBox(width: itemW, child: e)).toList(),
      );
    });
  }
}

/// Two columns on wide screens (main + side panel); stacks on narrow ones.
class _Split extends StatelessWidget {
  final Widget main, side;
  final int mainFlex, sideFlex;
  final double breakpoint;
  const _Split({
    required this.main,
    required this.side,
    this.mainFlex = 7,
    this.sideFlex = 4,
    this.breakpoint = 1100,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= breakpoint) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: mainFlex, child: main),
            const SizedBox(width: 16),
            Expanded(flex: sideFlex, child: side),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [main, const SizedBox(height: 16), side],
      );
    });
  }
}

class _BarItem {
  final String label;
  final num value;
  final Color color;
  final String? sub;
  const _BarItem(this.label, this.value, this.color, {this.sub});
}

/// Card with a labelled progress bar per item showing its share of the total.
class _BarsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<_BarItem> items;
  const _BarsCard({required this.title, required this.items, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final shown = items.where((i) => i.value > 0).toList();
    final total = shown.fold<num>(0, (s, i) => s + i.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _ps(15, w: FontWeight.w600, c: _C.navy)),
          if (subtitle != null) Text(subtitle!, style: _ps(11.5, c: _C.muted)),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Text('Nothing to show yet.', style: _ps(12.5, c: _C.muted))
          else
            for (final i in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: i.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(i.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: _ps(12.5, w: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Text(_nf.format(i.value.round()),
                            style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600)),
                        SizedBox(
                          width: 52,
                          child: Text('${(i.value / total * 100).toStringAsFixed(1)}%',
                              textAlign: TextAlign.right, style: _ps(11.5, c: _C.muted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (i.value / total).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(i.color),
                      ),
                    ),
                    if (i.sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(i.sub!, style: _ps(10.5, c: _C.muted)),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Side panel for Trial Balance / Balance Sheet.
Widget _positionSide(_Position p) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BarsCard(
        title: 'Where the money is',
        subtitle: 'Share of total assets',
        items: [
          _BarItem('Cash, bank & mobile money', p.cash, _C.green),
          _BarItem('Loans to members - principal', p.principal, _C.blue),
          _BarItem('Interest receivable', p.interest, _C.amber),
        ],
      ),
      const SizedBox(height: 16),
      _BarsCard(
        title: 'Who funds it',
        subtitle: 'Share of liabilities and equity',
        items: [
          _BarItem('Member savings (incl. wallets)', p.savings, _C.teal),
          _BarItem('Fixed deposits', p.fixedDeposits, _C.navy),
          _BarItem('Share capital', p.shares, _C.purple),
          _BarItem(p.balancingLabel, p.retained, _C.green),
        ],
      ),
    ],
  );
}

/// Headline figures shown above the Trial Balance and Balance Sheet.
class _PositionSummary extends StatelessWidget {
  final _Position p;
  const _PositionSummary(this.p);

  @override
  Widget build(BuildContext context) {
    final label = p.cashMissing ? 'Unreconciled' : (p.retained < 0 ? 'Deficit' : 'Retained earnings');
    final color = p.cashMissing ? _C.amber : (p.retained < 0 ? _C.red : _C.green);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _KpiGrid(children: [
        _Kpi(label: 'Total assets', value: _ugx(p.assets), icon: Icons.account_balance, color: _C.blue),
        _Kpi(
            label: 'Member savings',
            value: _ugx(p.liabilities),
            sub: 'Savings, wallets & fixed deposits',
            icon: Icons.savings_outlined,
            color: _C.teal),
        _Kpi(label: 'Share capital', value: _ugx(p.shares), icon: Icons.pie_chart_outline, color: _C.purple),
        _Kpi(
          label: label,
          value: _ugx(p.retained),
          icon: p.cashMissing ? Icons.warning_amber_rounded : Icons.balance,
          color: color,
        ),
      ]),
    );
  }
}

class _Alert extends StatelessWidget {
  final _Issue issue;
  const _Alert(this.issue);

  @override
  Widget build(BuildContext context) {
    final critical = issue.critical;
    final accent = critical ? _C.red : _C.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: critical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        border: Border.all(color: critical ? const Color(0xFFFECACA) : const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(critical ? Icons.error_outline : Icons.warning_amber_rounded, color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(issue.title, style: _ps(13.5, w: FontWeight.w600, c: accent)),
                const SizedBox(height: 3),
                Text(issue.body, style: _ps(12, c: _C.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: _ps(11, w: FontWeight.w600, c: color)),
    );
  }
}

Widget _btn(String label, IconData icon, VoidCallback onTap, {bool primary = false}) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 12);
  if (primary) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: _ps(12.5, w: FontWeight.w600, c: Colors.white)),
      style: ElevatedButton.styleFrom(
          backgroundColor: _C.navy, foregroundColor: Colors.white, elevation: 0, shape: shape, padding: pad),
    );
  }
  return OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label, style: _ps(12.5, w: FontWeight.w600, c: _C.navy)),
    style: OutlinedButton.styleFrom(
        foregroundColor: _C.navy, side: const BorderSide(color: _C.border), shape: shape, padding: pad),
  );
}

class _AsAtBar extends StatelessWidget {
  final DateTime asOf;
  final List<Widget> actions;
  const _AsAtBar({required this.asOf, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event, size: 16, color: _C.muted),
              const SizedBox(width: 6),
              Text('As at ${DateFormat('d MMMM yyyy').format(asOf)}  •  Amounts in UGX',
                  style: _ps(12.5, w: FontWeight.w500, c: _C.muted)),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
        ],
      ),
    );
  }
}

/// Navy statement banner: SACCO name, statement title and (optionally) the "as at" date.
class _StatementBanner extends StatelessWidget {
  final String title;
  final DateTime? asOf;
  final Widget? trailing;
  const _StatementBanner({required this.title, this.asOf, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.navy,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MBADIFA SACCO', style: _ps(10.5, c: Colors.white70, ls: 1.4)),
                const SizedBox(height: 2),
                Text(title.toUpperCase(), style: _ps(14, w: FontWeight.w600, c: Colors.white, ls: 1)),
                if (asOf != null)
                  Text('As at ${DateFormat('d MMMM yyyy').format(asOf!)}', style: _ps(11, c: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ?? Text('UGX', style: _ps(11.5, c: Colors.white70)),
        ],
      ),
    );
  }
}

/// Single-column statement card (report form).
class _StatementCard extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  final DateTime? asOf;
  const _StatementCard({required this.title, required this.rows, this.asOf});

  Widget _build(_Row r) {
    switch (r.kind) {
      case _K.header:
        return Container(
          width: double.infinity,
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Text(r.label, style: _ps(11.5, w: FontWeight.w700, c: _C.navy, ls: 0.8)),
        );
      case _K.sub:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
          child: Text(r.label, style: _ps(12.5, w: FontWeight.w600, c: _C.muted)),
        );
      case _K.item:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.label, style: _ps(13, c: _C.text)),
                    if (r.hint != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(r.hint!, style: _ps(10.5, c: _C.muted)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _amount(r.amount ?? 0, showZero: r.showZero),
            ],
          ),
        );
      case _K.total:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(top: BorderSide(color: _C.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(r.label, style: _ps(13.5, w: FontWeight.w600, c: _C.navy))),
              const SizedBox(width: 12),
              _amount(r.amount ?? 0, bold: true, size: 14),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _C.navy.withOpacity(0.06),
            border: const Border(
              top: BorderSide(color: _C.navy, width: 1.5),
              bottom: BorderSide(color: _C.navy, width: 3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(r.label, style: _ps(14.5, w: FontWeight.w700, c: _C.navy))),
              const SizedBox(width: 12),
              _amount(r.amount ?? 0, bold: true, size: 15),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatementBanner(title: title, asOf: asOf),
          ...rows.map(_build),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<List<dynamic>> rows; // [label, value, Color]
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _ps(15, w: FontWeight.w600, c: _C.navy)),
          const SizedBox(height: 8),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r[0] as String, style: _ps(13)),
                  _Badge(r[1] as String, r[2] as Color),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ListCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(title, style: _ps(13, w: FontWeight.w600, c: _C.navy)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String name, phone, note;
  final Color color;
  const _PersonTile({required this.name, required this.phone, required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _C.border))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(Icons.person, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: _ps(13.5, w: FontWeight.w600)),
                Text(phone, style: _ps(12, c: _C.muted)),
              ],
            ),
          ),
          Flexible(child: Text(note, textAlign: TextAlign.right, style: _ps(11.5, c: color))),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  const _RateCard({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: _ps(14, w: FontWeight.w600, c: _C.navy)),
              Text('${percent.toStringAsFixed(1)}%', style: _ps(22, w: FontWeight.w700, c: color)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Transaction report (shared by Income & Expense)
// ═══════════════════════════════════════════════════════════════════════════════
class _Txn {
  final DateTime? date;
  final String description, group, receipt;
  final num amount;
  const _Txn({
    required this.date,
    required this.description,
    required this.group,
    required this.receipt,
    required this.amount,
  });
}

/// Full-width transactions table. Columns flex with the screen; on narrow
/// screens each row collapses into a two-line layout.
class _TxnTable extends StatelessWidget {
  final String groupLabel, totalLabel;
  final List<_Txn> txns;
  final num total;
  const _TxnTable({
    required this.groupLabel,
    required this.totalLabel,
    required this.txns,
    required this.total,
  });

  static const _hdr = TextStyle(fontSize: 10.5);

  Widget _headCell(String t, int flex, {bool right = false, bool pad = true}) => Expanded(
        flex: flex,
        child: Padding(
          padding: EdgeInsets.only(right: pad ? 12 : 0),
          child: Text(
            t,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: _ps(_hdr.fontSize!, w: FontWeight.w600, c: _C.muted, ls: 0.8),
          ),
        ),
      );

  Widget _dateCell(_Txn t) {
    final d = t.date;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(d != null ? DateFormat('MMM d, yyyy').format(d) : 'N/A', style: _ps(13, w: FontWeight.w500)),
        if (d != null) Text(DateFormat('h:mm a').format(d), style: _ps(11.5, c: const Color(0xFF9CA3AF))),
      ],
    );
  }

  BoxDecoration _rowDeco(int i) => BoxDecoration(
        color: i.isOdd ? const Color(0xFFFAFBFC) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F3F6))),
      );

  Widget _wideRow(_Txn t, int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: _rowDeco(i),
      child: Row(
        children: [
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(right: 12), child: _dateCell(t))),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(_cap(t.description), maxLines: 2, overflow: TextOverflow.ellipsis, style: _ps(13)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(_cap(t.group),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: _ps(13, c: _C.muted)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                t.receipt.isEmpty ? '–' : t.receipt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.robotoMono(fontSize: 11.5, color: const Color(0xFF9CA3AF)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: _amount(t.amount, showZero: true)),
          ),
        ],
      ),
    );
  }

  Widget _narrowRow(_Txn t, int i) {
    final d = t.date;
    final meta = [
      if (d != null) DateFormat('MMM d, yyyy').format(d),
      _cap(t.group),
    ].where((e) => e.isNotEmpty).join('  •  ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _rowDeco(i),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_cap(t.description),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: _ps(13, w: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ps(11.5, c: _C.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _amount(t.amount, showZero: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transactions', style: _ps(15, w: FontWeight.w600, c: _C.navy)),
                  Text('${txns.length} ${txns.length == 1 ? 'entry' : 'entries'}',
                      style: _ps(12, c: _C.muted)),
                ],
              ),
            ),
            if (wide)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border.symmetric(horizontal: BorderSide(color: _C.border)),
                ),
                child: Row(
                  children: [
                    _headCell('DATE', 2),
                    _headCell('DESCRIPTION', 4),
                    _headCell(groupLabel.toUpperCase(), 3),
                    _headCell('RECEIPT', 3),
                    _headCell('AMOUNT', 2, right: true, pad: false),
                  ],
                ),
              )
            else
              const Divider(height: 1, color: _C.border),
            for (var i = 0; i < txns.length; i++) wide ? _wideRow(txns[i], i) : _narrowRow(txns[i], i),
            Container(
              padding: EdgeInsets.symmetric(horizontal: wide ? 20 : 16, vertical: 16),
              decoration: BoxDecoration(
                color: _C.navy.withOpacity(0.06),
                border: const Border(top: BorderSide(color: _C.navy, width: 1.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(totalLabel, style: _ps(13, w: FontWeight.w700, c: _C.navy, ls: 0.6)),
                  Text('UGX ${_nf.format(total.round())}',
                      style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w700, color: _C.navy)),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

List<Widget> _txnReport(
  BuildContext ctx, {
  required Map data,
  required String period,
  required int month,
  required int year,
  required String noun, // 'income' | 'expenses'
  required String groupLabel, // 'Source' | 'Category'
  required String Function(Map) groupOf,
  required Color accent,
  required IconData icon,
  required String fileStem,
}) {
  final txns = ((data['transactions'] as List?) ?? const [])
      .whereType<Map>()
      .map((t) => _Txn(
            date: t['date'] is DateTime ? t['date'] as DateTime : null,
            description: '${t['description'] ?? ''}'.trim().isEmpty ? '–' : '${t['description']}',
            group: groupOf(t),
            receipt: '${t['receiptNumber'] ?? ''}'.replaceAll('null', ''),
            amount: _n(t['amount']),
          ))
      .toList()
    ..sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

  if (txns.isEmpty) {
    return [
      _EmptyCard(
        icon: icon,
        title: 'No $noun recorded for $period',
        message: 'Pick another month or year, or post $noun entries to see them here.',
      ),
    ];
  }

  final reported = _n(data['total']);
  final total = reported != 0 ? reported : txns.fold<num>(0, (s, t) => s + t.amount);
  final avg = total / txns.length;

  final sums = <String, num>{};
  final counts = <String, int>{};
  for (final t in txns) {
    final k = _cap(t.group.isEmpty ? 'Other' : t.group);
    sums[k] = (sums[k] ?? 0) + t.amount;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final ranked = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = ranked.first;
  final topPct = total == 0 ? 0 : top.value / total * 100;
  final nounCap = _cap(noun);

  Future<void> exportCsv() async {
    final b = StringBuffer()
      ..writeln('MBADIFA SACCO')
      ..writeln('$nounCap Report - $period')
      ..writeln('Date,Description,$groupLabel,Receipt,Amount (UGX)');
    for (final t in txns) {
      final d = t.date != null ? DateFormat('yyyy-MM-dd HH:mm').format(t.date!) : '';
      b.writeln('$d,${_q(t.description)},${_q(t.group)},${_q(t.receipt)},${t.amount}');
    }
    b.writeln(',,,Total,$total');
    await _saveCsv(ctx, '${fileStem}_${year}_${month.toString().padLeft(2, '0')}.csv', b.toString());
  }

  Future<void> exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MBADIFA SACCO', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Mbarara District Farmers Association', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 10),
          pw.Text('$nounCap Report', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Period: $period', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total $nounCap:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('UGX ${_nf.format(total.round())}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          
          // Transactions Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Date', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Description', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(groupLabel, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Receipt', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Amount (UGX)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              for (final t in txns)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        t.date != null ? DateFormat('MMM d, yyyy').format(t.date!) : 'N/A',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_cap(t.description), style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_cap(t.group), style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(t.receipt.isEmpty ? '-' : t.receipt, style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        _nf.format(t.amount.round()),
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ],
                ),
              // Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      _nf.format(total.round()),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated: ${DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    try {
      final bytes = await pdf.save();
      await FileSaver.saveFile(
        fileName: '${fileStem}_${year}_${month.toString().padLeft(2, '0')}.pdf',
        content: base64Encode(bytes),
        mimeType: 'application/pdf',
      );
      _toast(ctx, 'PDF exported successfully');
    } catch (e) {
      _toast(ctx, 'PDF export failed: $e', error: true);
    }
  }

  return [
    Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn('Export CSV', Icons.file_download_outlined, exportCsv, primary: false),
          const SizedBox(width: 8),
          _btn('Export PDF', Icons.picture_as_pdf_outlined, exportPdf, primary: true),
        ],
      ),
    ),
    const SizedBox(height: 14),
    _KpiGrid(children: [
      _Kpi(label: 'Total $noun', value: _ugx(total), sub: period, icon: icon, color: accent),
      _Kpi(label: 'Transactions', value: '${txns.length}', sub: 'Recorded this period', icon: Icons.receipt_long_outlined, color: _C.blue),
      _Kpi(label: 'Average per transaction', value: _ugx(avg), icon: Icons.functions, color: _C.teal),
      _Kpi(
        label: 'Top ${groupLabel.toLowerCase()}',
        value: top.key,
        sub: '${_ugx(top.value)}  •  ${topPct.toStringAsFixed(0)}%',
        icon: Icons.emoji_events_outlined,
        color: _C.purple,
      ),
    ]),
    const SizedBox(height: 16),
    _Split(
      main: _TxnTable(
        groupLabel: groupLabel,
        totalLabel: 'TOTAL ${noun.toUpperCase()}',
        txns: txns,
        total: total,
      ),
      side: _BarsCard(
        title: 'By ${groupLabel.toLowerCase()}',
        subtitle: 'Share of total $noun',
        items: [
          for (var i = 0; i < ranked.length; i++)
            _BarItem(
              ranked[i].key,
              ranked[i].value,
              _palette[i % _palette.length],
              sub: '${counts[ranked[i].key]} ${counts[ranked[i].key] == 1 ? 'transaction' : 'transactions'}',
            ),
        ],
      ),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════
class _TabDef {
  final IconData icon;
  final String title;
  const _TabDef(this.icon, this.title);
}

class ComprehensiveReportsScreen extends StatefulWidget {
  final bool embedded;
  const ComprehensiveReportsScreen({super.key, this.embedded = false});

  @override
  State<ComprehensiveReportsScreen> createState() => _ComprehensiveReportsScreenState();
}

class _ComprehensiveReportsScreenState extends State<ComprehensiveReportsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <_TabDef>[
    _TabDef(Icons.calendar_month, 'Monthly'),
    _TabDef(Icons.assessment, 'Income Statement'),
    _TabDef(Icons.trending_up, 'Income'),
    _TabDef(Icons.trending_down, 'Expense'),
    _TabDef(Icons.account_balance_wallet, 'Trial Balance'),
    _TabDef(Icons.account_balance, 'Balance Sheet'),
    _TabDef(Icons.verified_user, 'KYC'),
    _TabDef(Icons.credit_card, 'Loans'),
    _TabDef(Icons.people, 'Members'),
  ];

  late final TabController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hideAppBar = widget.embedded && isMobile;

    final bar = TabBar(
      controller: _ctrl,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      labelStyle: _ps(12.5, w: FontWeight.w600),
      unselectedLabelStyle: _ps(12.5),
      tabs: [for (final t in _tabs) Tab(icon: Icon(t.icon, size: 18), text: t.title)],
    );

    final body = TabBarView(
      controller: _ctrl,
      children: const [
        _MonthlyTab(),
        _IncomeStatementTab(),
        _IncomeTab(),
        _ExpenseTab(),
        _TrialBalanceTab(),
        _BalanceSheetTab(),
        _KycTab(),
        _LoansTab(),
        _MembersTab(),
      ],
    );

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: hideAppBar
          ? null
          : AppBar(
              title: Text('Financial Reports', style: _ps(18, w: FontWeight.w600, c: Colors.white)),
              backgroundColor: _C.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: !widget.embedded,
              bottom: bar,
            ),
      body: hideAppBar
          ? Column(children: [
              Container(color: _C.navy, child: bar),
              Expanded(child: body),
            ])
          : body,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Period tabs (Monthly / Income / Expense)
// ═══════════════════════════════════════════════════════════════════════════════
class _PeriodTab extends StatefulWidget {
  final String title, subtitle;
  final List<Widget> Function(BuildContext, Map<String, dynamic>, int month, int year) builder;
  const _PeriodTab({required this.title, required this.subtitle, required this.builder});

  @override
  State<_PeriodTab> createState() => _PeriodTabState();
}

class _PeriodTabState extends State<_PeriodTab> {
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  int _refreshKey = 0; // Add refresh key for manual rebuilds

  Widget _picker() {
    Widget dd(int value, List<DropdownMenuItem<int>> items, ValueChanged<int> onChanged) {
      return DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: items,
          style: _ps(13, w: FontWeight.w500, c: _C.navy),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dd(
            _month,
            [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(value: m, child: Text(DateFormat.MMMM().format(DateTime(2024, m))))
            ],
            (v) => setState(() => _month = v),
          ),
          const SizedBox(width: 12),
          dd(
            _year,
            [
              for (var i = 0; i < 5; i++)
                DropdownMenuItem(value: DateTime.now().year - i, child: Text('${DateTime.now().year - i}'))
            ],
            (v) => setState(() => _year = v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PageHeader(title: widget.title, subtitle: widget.subtitle, trailing: _picker()),
        Expanded(
          child: _ReportLoader<Map<String, dynamic>>(
            key: ValueKey('$_month-$_year-${widget.title}-$_refreshKey'), // Include refresh key
            load: () => ReportService.generateMonthlyReport(year: _year, month: _month),
            builder: (ctx, r) => widget.builder(ctx, r, _month, _year),
          ),
        ),
      ],
    );
  }
  
  // Public method to trigger refresh from descendants
  void refresh() {
    setState(() {
      _refreshKey++;
    });
  }
}

class _MonthlyTab extends StatelessWidget {
  static final _db = FirebaseFirestore.instance;
  const _MonthlyTab();

  @override
  Widget build(BuildContext context) {
    return _PeriodTab(
      title: 'Monthly Report',
      subtitle: 'Complete cash movement, income, expenses and portfolio snapshot',
      builder: (ctx, r, month, year) {
        // Extract data with proper fallbacks
        final loans = _m(r['loans']);
        final rep = _m(r['repayments']);
        final sav = _m(r['savings']);
        final savWd = _m(r['savingsWithdrawals']);
        final sh = _m(r['shares']);
        final fd = _m(r['fixedDeposits']);
        final topups = _m(r['walletTopups']);
        final payouts = _m(r['walletPayouts']);
        final income = _m(r['income']);
        final expense = _m(r['expenses']);
        final cash = _m(r['cash']);
        final prev = _m(r['previous']);
        final port = _m(r['portfolio']);
        final memb = _m(r['members']);

        final totalInflows = _n(r['totalInflows']);
        final totalOutflows = _n(r['totalOutflows']);
        final net = _n(r['netCashFlow']);
        
        String tx(Map m, [String label = 'transactions']) => 
            '${_n(m['count']).toInt()} $label';
        
        String change(String key) {
          final c = _n(prev[key]);
          final cur = _n(r[key] ?? (key == 'income' ? income['total'] : (key == 'expenses' ? expense['total'] : 0)));
          if (c == 0) return '';
          final pct = ((cur - c) / c * 100);
          final sign = pct > 0 ? '+' : '';
          return '$sign${pct.toStringAsFixed(1)}% vs last month';
        }

        String changeAmt(num current, String prevKey) {
          final p = _n(prev[prevKey]);
          if (p == 0) return '';
          final pct = ((current - p) / p * 100);
          final sign = pct > 0 ? '+' : '';
          return '$sign${pct.toStringAsFixed(1)}%';
        }

        // Build cash movement statement rows
        final rows = <_Row>[
          _Row.item(
            'Opening cash balance', 
            cash['hasManualOpening'] == true ? _n(cash['opening']) : 0, 
            isFirst: true, 
            hint: cash['hasManualOpening'] == true 
              ? 'Manually set' 
              : 'Not set (auto-calculated: ${_ugx(_n(cash['opening']))})',
            showZero: true
          ),
          const _Row.header('CASH INFLOWS'),
          _Row.item('Loan repayments — principal', _n(rep['principal']), hint: tx(rep)),
          _Row.item('Loan repayments — interest', _n(rep['interest'])),
          _Row.item('Loan repayments — charges', _n(rep['charges'])),
          _Row.item('Savings deposits', _n(sav['amount']), hint: tx(sav)),
          _Row.item('Share purchases', _n(sh['amount']), hint: tx(sh)),
          _Row.item('Fixed deposits received', _n(fd['amount']), hint: tx(fd)),
          _Row.item('Mobile money deposits (MTN & Airtel)', _n(topups['amount']), hint: tx(topups, 'deposits')),
          _Row.item('Fees & penalties', _n(income['fees']) + _n(income['penalties'])),
          _Row.item('Other income', _n(income['other'])),
          _Row.total('Total inflows', totalInflows),
          const _Row.header('CASH OUTFLOWS'),
          _Row.item('Loans disbursed', _n(loans['amount']), hint: tx(loans)),
          _Row.item('Savings withdrawals', _n(savWd['amount']), hint: tx(savWd, 'withdrawals')),
          _Row.item('Mobile money withdrawals (MTN & Airtel)', _n(payouts['amount']), hint: tx(payouts, 'withdrawals')),
          _Row.item('Salaries & allowances', _n(expense['salaries'])),
          _Row.item('Utilities & transport', _n(expense['utilities'])),
          _Row.item('Office expenses', _n(expense['officeExpenses'])),
          _Row.item('Other expenses', _n(expense['other'])),
          _Row.total('Total outflows', totalOutflows),
          _Row.grand('Net cash flow', net),
          _Row.item('Closing cash balance (bank & cash)', _n(cash['closing'])),
          _Row.item('Cash with tellers', _n(cash['tillsNow'])),
          _Row.grand('Total closing cash', _n(cash['totalClosing'])),
        ];

        // Add appropriate reconciliation message
        final hasManualOpening = cash['hasManualOpening'] == true;
        final hasNoCashAccounts = cash['hasNoCashAccounts'] == true;
        final unexplained = _n(cash['unexplained']);
        
        if (!hasManualOpening) {
          rows.add(_Row.warning(
            'Opening balance not set',
            'Set the opening balance for this month to enable cash reconciliation.'
          ));
        } else if (hasNoCashAccounts) {
          rows.add(_Row.warning(
            'Cash accounts not set up',
            'Add your bank and cash accounts in Finance > Cash & Bank to track balances.'
          ));
        } else if (unexplained.abs() > 100) {
          rows.add(_Row.warning(
            'Unexplained difference: ${_ugx(unexplained)}',
            'Cash moved without being recorded (till sessions, manual adjustments, or missing entries).'
          ));
        }

        // CSV Export
        Future<void> exportCsv() async {
          final b = StringBuffer()
            ..writeln('MBADIFA SACCO')
            ..writeln('Monthly Report - ${r['period'] ?? '$month/$year'}')
            ..writeln()
            ..writeln('Category,Count,Amount (UGX)');

          // Opening balance display
          if (cash['hasNoCashAccounts'] == true) {
            b.writeln('Opening Cash Balance,,"Cash accounts not set up"');
          } else if (cash['hasManualOpening'] != true) {
            b.writeln('Opening Cash Balance,,"Opening balance not set"');
          } else {
            b.writeln('Opening Cash Balance,,${_n(cash['opening'])}');
          }

          b..writeln()
            ..writeln('CASH INFLOWS')
            ..writeln('Loan Repayments - Principal,${_n(rep['count'])},${_n(rep['principal'])}')
            ..writeln('Loan Repayments - Interest,,${_n(rep['interest'])}')
            ..writeln('Loan Repayments - Charges,,${_n(rep['charges'])}')
            ..writeln('Savings Deposits,${_n(sav['count'])},${_n(sav['amount'])}')
            ..writeln('Share Purchases,${_n(sh['count'])},${_n(sh['amount'])}')
            ..writeln('Fixed Deposits,${_n(fd['count'])},${_n(fd['amount'])}');
          
          // Only show MTN row if there are actual top-ups
          if (_n(topups['amount']) > 0) {
            b.writeln('MTN Mobile Money & Airtel Money Top-ups,${_n(topups['count'])},${_n(topups['amount'])}');
          }
          
          b..writeln('Fees & Penalties,,${_n(income['fees']) + _n(income['penalties'])}')
            ..writeln('Other Income,,${_n(income['other'])}')
            ..writeln('Total Inflows,,$totalInflows')
            ..writeln()
            ..writeln('CASH OUTFLOWS')
            ..writeln('Loans Disbursed,${_n(loans['count'])},${_n(loans['amount'])}')
            ..writeln('Savings Withdrawals,${_n(savWd['count'])},${_n(savWd['amount'])}');
          
          // Only show MTN payouts row if there are actual payouts
          if (_n(payouts['amount']) > 0) {
            b.writeln('MTN Mobile Money & Airtel Money Payouts,${_n(payouts['count'])},${_n(payouts['amount'])}');
          }
          
          b..writeln('Salaries,,${_n(expense['salaries'])}')
            ..writeln('Utilities,,${_n(expense['utilities'])}')
            ..writeln('Office Expenses,,${_n(expense['officeExpenses'])}')
            ..writeln('Other Expenses,,${_n(expense['other'])}')
            ..writeln('Total Outflows,,$totalOutflows')
            ..writeln()
            ..writeln('Net Cash Flow,,$net')
            ..writeln('Closing Cash Balance (Bank & Cash),,${_n(cash['closing'])}')
            ..writeln('Cash with Tellers,,${_n(cash['tillsNow'])}')
            ..writeln('Total Closing Cash,,${_n(cash['totalClosing'])}');

          // Unexplained difference display
          if (cash['hasNoCashAccounts'] != true && cash['hasManualOpening'] == true && unexplained.abs() > 100) {
            b.writeln('Unexplained Difference,,$unexplained');
          }

          b..writeln()
            ..writeln('PORTFOLIO SNAPSHOT')
            ..writeln('Live Loans,${_n(port['liveLoans'])},${_n(port['outstanding'])}')
            ..writeln('Overdue Loans,${_n(port['overdueLoans'])},${_n(port['overdueAmount'])}')
            ..writeln('PAR %,,${_n(port['parPercent']).toStringAsFixed(1)}%')
            ..writeln('Total Members,${_n(memb['total'])}')
            ..writeln('New Members This Month,${_n(memb['newThisMonth'])}');
          
          await _saveCsv(ctx, 'monthly_report_${year}_${month.toString().padLeft(2, '0')}.csv', b.toString());
        }

        // PDF Export
        Future<void> exportPdf() async {
          try {
            final pdf = pw.Document();
            
            // Build PDF content with professional layout
            pdf.addPage(
              pw.MultiPage(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(32),
                build: (pw.Context pdfContext) => [
                  // Header with logo area and title
                  pw.Container(
                    padding: const pw.EdgeInsets.only(bottom: 16),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.blue900)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'MBADIFA SACCO',
                              style: pw.TextStyle(
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Monthly Financial Report',
                              style: const pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              r['period'] ?? '$month/$year',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'All amounts in UGX',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // Executive Summary KPIs in colored boxes
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfKpiBox('Total Inflows', _ugx(totalInflows), PdfColors.green700),
                      _pdfKpiBox('Total Outflows', _ugx(totalOutflows), PdfColors.red700),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfKpiBox('Net Cash Flow', _ugx(net), net >= 0 ? PdfColors.blue700 : PdfColors.orange700),
                      _pdfKpiBox('Total Closing Cash', _ugx(_n(cash['totalClosing'])), PdfColors.teal700),
                    ],
                  ),
                  pw.SizedBox(height: 24),

                  // Cash Movement Statement Table
                  pw.Text(
                    'CASH MOVEMENT STATEMENT',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  
                  // Opening balance with conditional display
                  if (cash['hasNoCashAccounts'] == true)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'NOTE: Cash accounts not set up',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blue900,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    )
                  else if (cash['hasManualOpening'] != true)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'WARNING: Opening balance not set for this month',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.orange900,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Opening cash balance',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            _ugx(_n(cash['opening'])),
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  
                  pw.SizedBox(height: 8),
                  
                  // INFLOWS TABLE
                  _pdfSectionHeader('CASH INFLOWS'),
                  _pdfTable([
                    ['Loan repayments — principal', _ugx(_n(rep['principal']))],
                    ['Loan repayments — interest', _ugx(_n(rep['interest']))],
                    ['Loan repayments — charges', _ugx(_n(rep['charges']))],
                    ['Savings deposits', _ugx(_n(sav['amount']))],
                    ['Share purchases', _ugx(_n(sh['amount']))],
                    ['Fixed deposits received', _ugx(_n(fd['amount']))],
                    ['MTN Mobile Money & Airtel Money top-ups', _ugx(_n(topups['amount']))],
                    ['Fees & penalties', _ugx(_n(income['fees']) + _n(income['penalties']))],
                    ['Other income', _ugx(_n(income['other']))],
                  ]),
                  _pdfTableTotal('Total inflows', _ugx(totalInflows), PdfColors.green700),
                  pw.SizedBox(height: 16),
                  
                  // OUTFLOWS TABLE
                  _pdfSectionHeader('CASH OUTFLOWS'),
                  _pdfTable([
                    ['Loans disbursed', _ugx(_n(loans['amount']))],
                    ['Savings withdrawals', _ugx(_n(savWd['amount']))],
                    ['MTN Mobile Money & Airtel Money payouts', _ugx(_n(payouts['amount']))],
                    ['Salaries & allowances', _ugx(_n(expense['salaries']))],
                    ['Utilities & transport', _ugx(_n(expense['utilities']))],
                    ['Office expenses', _ugx(_n(expense['officeExpenses']))],
                    ['Other expenses', _ugx(_n(expense['other']))],
                  ]),
                  _pdfTableTotal('Total outflows', _ugx(totalOutflows), PdfColors.red700),
                  pw.SizedBox(height: 16),
                  
                  // NET CASH FLOW SUMMARY
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: net >= 0 ? PdfColors.green50 : PdfColors.red50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'NET CASH FLOW',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: net >= 0 ? PdfColors.green900 : PdfColors.red900,
                          ),
                        ),
                        pw.Text(
                          _ugx(net),
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: net >= 0 ? PdfColors.green900 : PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  
                  // CLOSING BALANCE TABLE
                  _pdfTable([
                    ['Closing cash balance (Bank & Cash)', _ugx(_n(cash['closing']))],
                    if (_n(cash['tillsNow']) > 0)
                      ['Cash with tellers', _ugx(_n(cash['tillsNow']))]
                    else if (_n(cash['nonTillAccounts']) == 0)
                      ['Cash with tellers', 'No open till sessions'],
                  ]),
                  
                  // Total closing cash - with helpful messages
                  if (_n(cash['hasNoCashAccounts']) == true)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.orange50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TOTAL CLOSING CASH: Not set up',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange900,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Add cash/bank/mobile money accounts in Finance > Cash & Bank',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.orange800,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL CLOSING CASH',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            _ugx(_n(cash['totalClosing'])),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Unexplained difference with conditional display
                  if (cash['hasNoCashAccounts'] != true && cash['hasManualOpening'] == true && unexplained.abs() > 100) ...[
                    pw.SizedBox(height: 12),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'Unexplained difference: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.amber900,
                            ),
                          ),
                          pw.Text(
                            _ugx(unexplained),
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.amber900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  pw.SizedBox(height: 24),

                  // Portfolio Snapshot Section
                  pw.Text(
                    'PORTFOLIO SNAPSHOT',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'As of ${DateFormat('d MMMM yyyy').format(_dt(port['asOf']) ?? DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _pdfTable([
                    ['Live loans', '${_n(port['liveLoans']).toInt()}'],
                    ['Outstanding principal', _ugx(_n(port['outstanding']))],
                    ['Overdue loans', '${_n(port['overdueLoans']).toInt()}'],
                    ['Overdue amount', _ugx(_n(port['overdueAmount']))],
                    ['Portfolio at Risk (PAR %)', '${_n(port['parPercent']).toStringAsFixed(1)}%'],
                  ]),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 0.5),
                  pw.SizedBox(height: 12),
                  _pdfTable([
                    ['Total members', '${_n(memb['total']).toInt()}'],
                    ['New members this month', '${_n(memb['newThisMonth']).toInt()}'],
                  ]),

                  // Footer
                  pw.SizedBox(height: 32),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Generated on ${DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'MBADIFA SACCO',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            );

            // Show PDF
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdf.save(),
              name: 'monthly_report_${year}_${month.toString().padLeft(2, '0')}.pdf',
            );
          } catch (e) {
            if (ctx.mounted) {
              _toast(ctx, 'PDF export failed: $e', error: true);
            }
          }
        }

        // Build the UI
        return [
          // Opening balance status - clean and professional
          if (cash['hasManualOpening'] == true)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0EA5E9).withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opening Balance',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _ugx(_n(cash['opening'])),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showDialog<int>(
                        context: ctx,
                        builder: (dialogCtx) => _SetOpeningBalanceDialog(
                          year: year,
                          month: month,
                          currentValue: cash['hasManualOpening'] == true ? _n(cash['opening']).toInt() : null,
                        ),
                      );
                      if (result != null && ctx.mounted) {
                        try {
                          final monthKey = '$year-${month.toString().padLeft(2, '0')}';
                          await _db
                              .collection('account_snapshots')
                              .doc('${FirebaseService.sessionTenantId}-$monthKey')
                              .set({
                            'tenantId': FirebaseService.sessionTenantId,
                            'month': monthKey,
                            'opening': result,
                            'hasManualOpening': true,
                            'setAt': FieldValue.serverTimestamp(),
                            'setBy': FirebaseService.currentUser?.displayName ??
                                FirebaseService.currentUser?.email ??
                                'Unknown',
                          }, SetOptions(merge: true));
                          
                          print('✅ Opening balance saved: $result for $monthKey');
                          print('📝 Document: ${FirebaseService.sessionTenantId}-$monthKey');
                          
                          _toast(ctx, 'Opening balance updated to ${_ugx(result)}');
                          // Trigger rebuild by calling refresh method on parent state
                          final periodState = ctx.findAncestorStateOfType<_PeriodTabState>();
                          if (periodState != null) {
                            print('🔄 Triggering refresh...');
                            periodState.refresh();
                          } else {
                            print('⚠️ Could not find _PeriodTabState for refresh');
                          }
                        } catch (e) {
                          print('❌ Failed to set opening balance: $e');
                          _toast(ctx, 'Failed to set opening balance: $e', error: true);
                        }
                      }
                    },
                    icon: Icon(Icons.edit, size: 16),
                    label: Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF0EA5E9),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFFDE047), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFFDE047),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.info_outline, color: Color(0xFF92400E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Opening balance not set',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set the starting cash balance for accurate reconciliation',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFFA16207)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await showDialog<int>(
                        context: ctx,
                        builder: (dialogCtx) => _SetOpeningBalanceDialog(
                          year: year,
                          month: month,
                          currentValue: null,
                        ),
                      );
                      if (result != null && ctx.mounted) {
                        try {
                          final monthKey = '$year-${month.toString().padLeft(2, '0')}';
                          await _db
                              .collection('account_snapshots')
                              .doc('${FirebaseService.sessionTenantId}-$monthKey')
                              .set({
                            'tenantId': FirebaseService.sessionTenantId,
                            'month': monthKey,
                            'opening': result,
                            'hasManualOpening': true,
                            'setAt': FieldValue.serverTimestamp(),
                            'setBy': FirebaseService.currentUser?.displayName ??
                                FirebaseService.currentUser?.email ??
                                'Unknown',
                          }, SetOptions(merge: true));
                          
                          print('✅ Opening balance saved: $result for $monthKey');
                          print('📝 Document: ${FirebaseService.sessionTenantId}-$monthKey');
                          
                          _toast(ctx, 'Opening balance set to ${_ugx(result)}');
                          // Trigger rebuild
                          final periodState = ctx.findAncestorStateOfType<_PeriodTabState>();
                          if (periodState != null) {
                            print('🔄 Triggering refresh...');
                            periodState.refresh();
                          } else {
                            print('⚠️ Could not find _PeriodTabState for refresh');
                          }
                        } catch (e) {
                          print('❌ Failed to set opening balance: $e');
                          _toast(ctx, 'Failed to set opening balance: $e', error: true);
                        }
                      }
                    },
                    icon: Icon(Icons.add_circle_outline, size: 18),
                    label: Text('Set Balance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFBBF24),
                      foregroundColor: Color(0xFF92400E),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Export buttons row
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                _btn('Export CSV', Icons.file_download_outlined, exportCsv),
                _btn('Export PDF', Icons.picture_as_pdf_outlined, exportPdf, primary: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          
          // KPI Cards with comparisons
          _KpiGrid(children: [
            _Kpi(
              label: 'Total inflows',
              value: _ugx(totalInflows),
              sub: changeAmt(totalInflows, 'totalInflows'),
              icon: Icons.arrow_downward,
              color: _C.green,
            ),
            _Kpi(
              label: 'Total outflows',
              value: _ugx(totalOutflows),
              sub: changeAmt(totalOutflows, 'totalOutflows'),
              icon: Icons.arrow_upward,
              color: _C.blue,
            ),
            _Kpi(
              label: 'Net cash flow',
              value: _ugx(net),
              sub: changeAmt(net, 'netCashFlow'),
              icon: net >= 0 ? Icons.trending_up : Icons.trending_down,
              color: net >= 0 ? _C.green : _C.red,
            ),
            _Kpi(
              label: 'Total closing cash',
              value: _n(cash['hasNoCashAccounts']) == true 
                  ? 'Not set up' 
                  : _ugx(_n(cash['totalClosing'])),
              sub: _n(cash['hasNoCashAccounts']) == true
                  ? 'Add accounts in Finance > Cash & Bank'
                  : (_n(cash['tillsNow']) > 0 
                      ? 'Incl. ${_ugx(_n(cash['tillsNow']))} with tellers'
                      : _n(cash['nonTillAccounts']) > 0
                          ? 'Bank & cash accounts'
                          : 'No open till sessions'),
              icon: Icons.account_balance_wallet,
              color: _C.navy,
            ),
          ]),
          const SizedBox(height: 16),
          
          // Charts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cash Flow Breakdown Pie Chart
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDeco(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cash flow breakdown', style: _ps(13.5, w: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Inflows vs outflows', style: _ps(10.5, c: _C.muted)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 140,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: totalInflows.toDouble(),
                                title: '${((totalInflows / (totalInflows + totalOutflows)) * 100).toStringAsFixed(1)}%',
                                color: const Color(0xFF059669), // Professional teal-green
                                radius: 50,
                                titleStyle: _ps(11, c: Colors.white, w: FontWeight.w600),
                              ),
                              PieChartSectionData(
                                value: totalOutflows.toDouble(),
                                title: '${((totalOutflows / (totalInflows + totalOutflows)) * 100).toStringAsFixed(1)}%',
                                color: const Color(0xFFDC2626), // Professional red
                                radius: 50,
                                titleStyle: _ps(11, c: Colors.white, w: FontWeight.w600),
                              ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _legendItem('Inflows', const Color(0xFF059669), _ugx(totalInflows)),
                          _legendItem('Outflows', const Color(0xFFDC2626), _ugx(totalOutflows)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Arrears Aging Bar Chart
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDeco(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arrears aging', style: _ps(13.5, w: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Outstanding by days overdue', style: _ps(10.5, c: _C.muted)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 140,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: [
                              _n(port['arrears1_30']),
                              _n(port['arrears31_60']),
                              _n(port['arrears61_90']),
                              _n(port['arrears90Plus']),
                            ].reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                            barGroups: [
                              _barGroup(0, _n(port['arrears1_30']).toDouble(), const Color(0xFFF59E0B)), // Amber
                              _barGroup(1, _n(port['arrears31_60']).toDouble(), const Color(0xFFEA580C)), // Orange  
                              _barGroup(2, _n(port['arrears61_90']).toDouble(), const Color(0xFFDC2626)), // Red
                              _barGroup(3, _n(port['arrears90Plus']).toDouble(), const Color(0xFF991B1B)), // Dark red
                            ],
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 42,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const SizedBox();
                                    return Text(
                                      '${(value / 1000000).toStringAsFixed(0)}M',
                                      style: _ps(9, c: _C.muted),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final labels = ['1-30', '31-60', '61-90', '90+'];
                                    if (value.toInt() >= 0 && value.toInt() < labels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(labels[value.toInt()], style: _ps(10, c: _C.muted)),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 1000000,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: _C.border,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text('Days overdue', style: _ps(10.5, c: _C.muted)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main content split
          _Split(
            main: _StatementCard(
              title: 'Cash movement - ${r['period'] ?? ''}',
              rows: rows,
            ),
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inflows vs Outflows
                _BarsCard(
                  title: 'Inflows vs outflows',
                  subtitle: 'Net: ${_ugx(net)}',
                  items: [
                    _BarItem('Total inflows', totalInflows, _C.green),
                    _BarItem('Total outflows', totalOutflows, _C.blue),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Portfolio snapshot
                _Panel(
                  title: 'Portfolio snapshot',
                  subtitle: 'As of ${DateFormat('d MMM yyyy').format(_dt(port['asOf']) ?? DateTime.now())}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow('Live loans', '${_n(port['liveLoans']).toInt()}'),
                      _statRow('Outstanding principal', _ugx(_n(port['outstanding']))),
                      _statRow('Overdue loans', '${_n(port['overdueLoans']).toInt()}'),
                      _statRow('Overdue amount', _ugx(_n(port['overdueAmount']))),
                      _statRow('PAR %', '${_n(port['parPercent']).toStringAsFixed(1)}%'),
                      const Divider(height: 20),
                      _statRow('Total members', '${_n(memb['total']).toInt()}'),
                      _statRow('New members this month', '${_n(memb['newThisMonth']).toInt()}'),
                      if (_n(port['overdueLoans']) > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: Migrated loans may show inaccurate arrears',
                          style: _ps(10.5, c: _C.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Complete cash movement report including all income, expenses, and portfolio metrics. '
              'Tills show current balance only (historical rollback not available).',
              style: _ps(11, c: _C.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ];
      },
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _ps(12.5, c: _C.muted)),
          Text(value, style: _ps(13, w: FontWeight.w600, c: _C.ink)),
        ],
      ),
    );
  }

}

// Set Opening Balance Dialog
class _SetOpeningBalanceDialog extends StatefulWidget {
  final int year, month;
  final int? currentValue;
  const _SetOpeningBalanceDialog({
    required this.year, 
    required this.month,
    this.currentValue,
  });
  
  @override
  State<_SetOpeningBalanceDialog> createState() => _SetOpeningBalanceDialogState();
}

class _SetOpeningBalanceDialogState extends State<_SetOpeningBalanceDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    // Pre-fill with current value if exists
    if (widget.currentValue != null) {
      _controller.text = widget.currentValue.toString();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM().format(DateTime(widget.year, widget.month));
    final isEditing = widget.currentValue != null;
    
    return AlertDialog(
      title: Text('${isEditing ? 'Edit' : 'Set'} Opening Cash Balance'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For $monthName',
              style: _ps(14, w: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isEditing 
                ? 'Update the opening cash position for this month.'
                : 'This is a one-time manual entry for the starting cash position. '
                  'Use this when migrating from another system or correcting historical data.',
              style: _ps(12, c: _C.muted),
            ),
            if (isEditing) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Current: UGX ${_nf.format(widget.currentValue!)}',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Opening Balance (UGX)',
                hintText: '0',
                prefixText: 'UGX ',
                border: const OutlineInputBorder(),
                helperText: 'Enter the total cash + bank balance at start of month',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = int.tryParse(value.trim().replaceAll(',', ''));
                if (amount == null) {
                  return 'Please enter a valid number';
                }
                if (amount < 0) {
                  return 'Amount cannot be negative';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final amount = int.parse(_controller.text.trim().replaceAll(',', ''));
              Navigator.pop(context, amount);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.navy,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Helper for _Panel widget (add if not exists)
class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  
  const _Panel({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _ps(14, w: FontWeight.w600, c: _C.ink)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: _ps(11.5, c: _C.muted)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Income Statement Tab (Professional SACCO Template)
// ═══════════════════════════════════════════════════════════════════════════════
class _IncomeStatementTab extends StatelessWidget {
  const _IncomeStatementTab();

  @override
  Widget build(BuildContext context) {
    return _PeriodTab(
      title: 'Income Statement',
      subtitle: 'Comprehensive income and expenses with comparison',
      builder: (ctx, r, month, year) {
        final income = _m(r['income']);
        final expense = _m(r['expenses']);
        final prev = _m(r['previous']);
        final port = _m(r['portfolio']);
        final loans = _m(r['loans']);
        final rep = _m(r['repayments']);
        final cash = _m(r['cash']);
        
        // Cash position
        final openingCash = _n(cash['opening']);
        final closingCash = _n(cash['closing']);
        final tillsNow = _n(cash['tillsNow']);
        final totalClosingCash = closingCash + tillsNow;
        
        // Interest income comes from loan repayments
        final interestIncome = _n(rep['interest']);
        final feesIncome = _n(income['fees']);
        final penaltiesIncome = _n(income['penalties']);
        final otherIncome = _n(income['other']);
        
        final totalIncome = interestIncome + feesIncome + penaltiesIncome + otherIncome;
        final totalExpenses = _n(expense['total']);
        final netSurplus = totalIncome - totalExpenses;
        final margin = totalIncome > 0 ? (netSurplus / totalIncome * 100) : 0.0;
        
        // Previous month values
        final prevInterest = _n(prev['repayments'] is Map ? prev['repayments']['interest'] : 0);
        final prevFees = _n(prev['feesIncome']);
        final prevPenalties = _n(prev['penaltiesIncome']);
        final prevOther = _n(prev['otherIncome']);
        final prevTotalIncome = prevInterest + prevFees + prevPenalties + prevOther;
        final prevExpenses = _n(prev['expenses']);
        
        String changePercent(num current, num previous) {
          if (previous == 0) return '-';
          final change = ((current - previous) / previous * 100);
          final sign = change > 0 ? '+' : '';
          return '$sign${change.toStringAsFixed(1)}%';
        }
        
        // PDF helper functions
        pw.TableRow _pdfIncomeRow(String label, num thisMonth, num lastMonth, String Function(num, num) changePercent) {
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(label, style: pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_nf.format(thisMonth), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(_nf.format(lastMonth), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(changePercent(thisMonth, lastMonth), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9)),
              ),
            ],
          );
        }
        
        pw.TableRow _pdfPortfolioRow(String label, String value) {
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(value, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        }
        
        // CSV Export
        Future<void> exportCsv() async {
          final b = StringBuffer()
            ..writeln('MBADIFA SACCO')
            ..writeln('Monthly Financial Report')
            ..writeln('Month: ${DateFormat.yMMMM().format(DateTime(year, month))}')
            ..writeln('Prepared by: ${FirebaseService.currentUser?.displayName ?? FirebaseService.currentUser?.email ?? ""}')
            ..writeln('Date: ${DateFormat('d MMMM yyyy').format(DateTime.now())}')
            ..writeln()
            ..writeln('Summary')
            ..writeln('Total income,${totalIncome}')
            ..writeln('Total expenses,${totalExpenses}')
            ..writeln('Net surplus / (deficit),${netSurplus}')
            ..writeln('Margin,${margin.toStringAsFixed(1)}%')
            ..writeln()
            ..writeln('1. Income')
            ..writeln('Item,This month (UGX),Last month (UGX),Change %')
            ..writeln('Interest on loans,${interestIncome},${prevInterest},${changePercent(interestIncome, prevInterest)}')
            ..writeln('Loan processing fees,${feesIncome},${prevFees},${changePercent(feesIncome, prevFees)}')
            ..writeln('Insurance and appraisal fees,0,0,-')
            ..writeln('Penalties and late fees,${penaltiesIncome},${prevPenalties},${changePercent(penaltiesIncome, prevPenalties)}')
            ..writeln('Membership and registration fees,0,0,-')
            ..writeln('Other income,${otherIncome},${prevOther},${changePercent(otherIncome, prevOther)}')
            ..writeln('Total income,${totalIncome},${prevTotalIncome},${changePercent(totalIncome, prevTotalIncome)}')
            ..writeln()
            ..writeln('2. Expenses')
            ..writeln('Item,This month (UGX),Last month (UGX),Change %')
            ..writeln('Interest paid on member savings,0,0,-')
            ..writeln('Salaries and wages,${_n(expense['salaries'])},${_n(prev['salaries'])},${changePercent(_n(expense['salaries']), _n(prev['salaries']))}')
            ..writeln('Rent and utilities,${_n(expense['utilities'])},${_n(prev['utilities'])},${changePercent(_n(expense['utilities']), _n(prev['utilities']))}')
            ..writeln('Transport and communication,0,0,-')
            ..writeln('Loan loss provisions / write-offs,0,0,-')
            ..writeln('Other operating expenses,${_n(expense['officeExpenses']) + _n(expense['other'])},${_n(prev['officeExpenses']) + _n(prev['other'])},-')
            ..writeln('Total expenses,${totalExpenses},${prevExpenses},${changePercent(totalExpenses, prevExpenses)}')
            ..writeln()
            ..writeln('NET SURPLUS / (DEFICIT),${netSurplus}')
            ..writeln()
            ..writeln('3. Cash Position')
            ..writeln('Opening cash balance,${openingCash}')
            ..writeln('Net surplus / (deficit),${netSurplus}')
            ..writeln('Closing cash (bank/safe),${closingCash}')
            ..writeln('Cash with tellers,${tillsNow}')
            ..writeln('Total closing cash,${totalClosingCash}')
            ..writeln()
            ..writeln('4. Loan portfolio snapshot')
            ..writeln('Loans disbursed this month,${_n(loans['amount'])}')
            ..writeln('Repayments collected,${_n(rep['amount'])}')
            ..writeln('Outstanding loan book (month end),${_n(port['outstanding'])}')
            ..writeln('Loans in arrears,${_n(port['overdueAmount'])}')
            ..writeln('Portfolio at risk (arrears / outstanding),${_n(port['parPercent']).toStringAsFixed(1)}%')
            ..writeln('Active borrowers,${_n(port['liveLoans'])}')
            ..writeln()
            ..writeln('Basis: cash. Interest income is counted when a repayment is recorded. Amounts in Uganda Shillings (UGX).');
          
          await _saveCsv(ctx, 'income_statement_${year}_${month.toString().padLeft(2, '0')}.csv', b.toString());
        }
        
        // PDF Export - Professional template matching
        Future<void> exportPdf() async {
          try {
            final pdf = pw.Document();
            final monthName = DateFormat.yMMMM().format(DateTime(year, month));
            
            // Load logo
            final logoData = await rootBundle.load('assets/images/mbadifa-logo.png');
            final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
            
            pdf.addPage(
              pw.MultiPage(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(40),
                build: (ctx) => [
                  // Professional Header with Logo
                  pw.Container(
                    padding: const pw.EdgeInsets.only(bottom: 20),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.grey800)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Logo and SACCO name
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 60,
                              height: 60,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                              ),
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Image(logoImage),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'MBADIFA SACCO',
                                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Mbarara District Farmers Association',
                                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Monthly Financial Report',
                                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Report details
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('Period', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text(monthName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 8),
                            pw.Text('Prepared by', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            pw.Text(
                              FirebaseService.currentUser?.displayName ?? FirebaseService.currentUser?.email ?? '__________',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text('Date: ${DateFormat('d MMM yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Summary box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(width: 1.5, color: PdfColors.grey800),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(children: [
                          pw.Text('Total income', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('UGX ${_nf.format(totalIncome)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ]),
                        pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                        pw.Column(children: [
                          pw.Text('Total expenses', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('UGX ${_nf.format(totalExpenses)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ]),
                        pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                        pw.Column(children: [
                          pw.Text(netSurplus >= 0 ? 'Net surplus' : 'Net deficit', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('UGX ${_nf.format(netSurplus.abs())}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ]),
                        pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                        pw.Column(children: [
                          pw.Text('Margin', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 2),
                          pw.Text('${margin.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  
                  // Income table
                  pw.Text('1. Income', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('This month (UGX)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Last month (UGX)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Change %', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      _pdfIncomeRow('Interest on loans', interestIncome, prevInterest, changePercent),
                      _pdfIncomeRow('Loan processing fees', feesIncome, prevFees, changePercent),
                      _pdfIncomeRow('Insurance and appraisal fees', 0, 0, changePercent),
                      _pdfIncomeRow('Penalties and late fees', penaltiesIncome, prevPenalties, changePercent),
                      _pdfIncomeRow('Membership and registration fees', 0, 0, changePercent),
                      _pdfIncomeRow('Other income', otherIncome, prevOther, changePercent),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total income', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_nf.format(totalIncome), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_nf.format(prevTotalIncome), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(changePercent(totalIncome, prevTotalIncome), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Expenses table (similar structure)
                  pw.Text('2. Expenses', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('This month (UGX)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Last month (UGX)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Change %', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      _pdfIncomeRow('Interest paid on member savings', 0, 0, changePercent),
                      _pdfIncomeRow('Salaries and wages', _n(expense['salaries']), _n(prev['salaries']), changePercent),
                      _pdfIncomeRow('Rent and utilities', _n(expense['utilities']), _n(prev['utilities']), changePercent),
                      _pdfIncomeRow('Transport and communication', 0, 0, changePercent),
                      _pdfIncomeRow('Loan loss provisions / write-offs', 0, 0, changePercent),
                      _pdfIncomeRow('Other operating expenses', _n(expense['officeExpenses']) + _n(expense['other']), _n(prev['officeExpenses']) + _n(prev['other']), changePercent),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total expenses', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_nf.format(totalExpenses), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_nf.format(prevExpenses), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(changePercent(totalExpenses, prevExpenses), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  
                  // Net surplus/deficit
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey800,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('NET SURPLUS / (DEFICIT)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        pw.Text('UGX ${_nf.format(netSurplus)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ],
                    ),
                  ),
                  
                  pw.SizedBox(height: 24),
                  
                  // Cash Position
                  pw.Text('3. Cash Position', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      _pdfPortfolioRow('Opening cash balance', 'UGX ${_nf.format(openingCash)}'),
                      _pdfPortfolioRow('Net surplus / (deficit)', 'UGX ${_nf.format(netSurplus)}'),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Container(height: 8, child: pw.SizedBox()),
                          pw.Container(height: 8, child: pw.SizedBox()),
                        ],
                      ),
                      _pdfPortfolioRow('Closing cash (bank/safe)', 'UGX ${_nf.format(closingCash)}'),
                      _pdfPortfolioRow('Cash with tellers', 'UGX ${_nf.format(tillsNow)}'),
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.green100),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('Total closing cash', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text('UGX ${_nf.format(totalClosingCash)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 24),
                  
                  // Loan portfolio snapshot
                  pw.Text('4. Loan portfolio snapshot', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    children: [
                      _pdfPortfolioRow('Loans disbursed this month', 'UGX ${_nf.format(_n(loans['amount']))}'),
                      _pdfPortfolioRow('Repayments collected', 'UGX ${_nf.format(_n(rep['amount']))}'),
                      _pdfPortfolioRow('Outstanding loan book (month end)', 'UGX ${_nf.format(_n(port['outstanding']))}'),
                      _pdfPortfolioRow('Loans in arrears', 'UGX ${_nf.format(_n(port['overdueAmount']))}'),
                      _pdfPortfolioRow('Portfolio at risk (arrears / outstanding)', '${_n(port['parPercent']).toStringAsFixed(1)}%'),
                      _pdfPortfolioRow('Active borrowers', '${_n(port['liveLoans'])} No.'),
                    ],
                  ),
                  
                  pw.SizedBox(height: 32),
                  
                  // Sign-off
                  pw.Text('5. Sign-off', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Prepared by', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                              pw.SizedBox(height: 30),
                              pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
                                child: pw.Text(
                                  FirebaseService.currentUser?.displayName ?? FirebaseService.currentUser?.email ?? '',
                                  style: pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text('Date: ${DateFormat('d/M/yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Checked by (Manager)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                              pw.SizedBox(height: 30),
                              pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
                                child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text('Date: ____________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Approved by (Chairperson)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                              pw.SizedBox(height: 30),
                              pw.Container(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
                                child: pw.Text('', style: pw.TextStyle(fontSize: 10)),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text('Date: ____________', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'Basis: cash. Interest income is counted when a repayment is recorded. Amounts in Uganda Shillings (UGX). Change % = (this month - last month) / last month.',
                      style: pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  
                  // Footer
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('MBADIFA SACCO | Monthly Report', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.Text('Page 1', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            );
            
            await Printing.layoutPdf(
              onLayout: (PdfPageFormat format) async => pdf.save(),
              name: 'income_statement_${year}_${month.toString().padLeft(2, '0')}.pdf',
            );
          } catch (e) {
            if (ctx.mounted) {
              _toast(ctx, 'PDF export failed: $e', error: true);
            }
          }
        }
        
        return [
          // Clean Professional Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 2)),
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 65,
                  height: 65,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset('assets/images/mbadifa-logo.png'),
                ),
                const SizedBox(width: 18),
                // SACCO Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MBADIFA SACCO', style: _ps(18, w: FontWeight.w700, c: _C.navy)),
                      const SizedBox(height: 2),
                      Text('Mbarara District Farmers Association', style: _ps(10.5, c: Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      Text('Monthly Financial Report', style: _ps(13, w: FontWeight.w600, c: Color(0xFF1E40AF))),
                    ],
                  ),
                ),
                // Period & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Period', style: _ps(9.5, c: Color(0xFF6B7280))),
                    Text(DateFormat.yMMMM().format(DateTime(year, month)), style: _ps(14, w: FontWeight.w700, c: _C.navy)),
                    const SizedBox(height: 8),
                    Text('Prepared: ${DateFormat('d MMM yyyy').format(DateTime.now())}', style: _ps(10, c: Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Export buttons
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                _btn('Export CSV', Icons.file_download_outlined, exportCsv),
                _btn('Export PDF', Icons.picture_as_pdf_outlined, exportPdf, primary: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Clean Summary Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryKpi('Total Income', _ugx(totalIncome), Color(0xFF059669)),
                ),
                Container(width: 1, height: 50, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: _SummaryKpi('Total Expenses', _ugx(totalExpenses), Color(0xFFDC2626)),
                ),
                Container(width: 1, height: 50, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: _SummaryKpi(
                    netSurplus >= 0 ? 'Net Surplus' : 'Net Deficit',
                    _ugx(netSurplus.abs()),
                    netSurplus >= 0 ? Color(0xFF059669) : Color(0xFFDC2626),
                  ),
                ),
                Container(width: 1, height: 50, color: Color(0xFFE5E7EB)),
                Expanded(
                  child: _SummaryKpi('Margin', '${margin.toStringAsFixed(1)}%', Color(0xFF0B2545)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Income Table
          _IncomeStatementSection(
            title: '1. Income',
            rows: [
              _IncomeStatementRow('Interest on loans', interestIncome, prevInterest),
              _IncomeStatementRow('Loan processing fees', feesIncome, prevFees),
              _IncomeStatementRow('Insurance and appraisal fees', 0, 0), // Not tracked separately
              _IncomeStatementRow('Penalties and late fees', penaltiesIncome, prevPenalties),
              _IncomeStatementRow('Membership and registration fees', 0, 0), // Not tracked
              _IncomeStatementRow('Other income', otherIncome, prevOther),
            ],
            total: _IncomeStatementRow('Total income', totalIncome, prevTotalIncome),
          ),
          const SizedBox(height: 24),
          
          // Expenses Table
          _IncomeStatementSection(
            title: '2. Expenses',
            rows: [
              _IncomeStatementRow('Interest paid on member savings', 0, 0), // Not tracked yet
              _IncomeStatementRow('Salaries and wages', _n(expense['salaries']), _n(prev['salaries'])),
              _IncomeStatementRow('Rent and utilities', _n(expense['utilities']), _n(prev['utilities'])),
              _IncomeStatementRow('Transport and communication', 0, 0), // Not separated
              _IncomeStatementRow('Loan loss provisions / write-offs', 0, 0), // Not tracked
              _IncomeStatementRow('Other operating expenses', _n(expense['officeExpenses']) + _n(expense['other']), _n(prev['officeExpenses']) + _n(prev['other'])),
            ],
            total: _IncomeStatementRow('Total expenses', totalExpenses, prevExpenses),
          ),
          const SizedBox(height: 24),
          
          // Net Surplus/Deficit
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: netSurplus >= 0 ? Color(0xFFECFDF5) : Color(0xFFFEF2F2),
              border: Border.all(
                color: netSurplus >= 0 ? Color(0xFF10B981) : Color(0xFFEF4444),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NET SURPLUS / (DEFICIT)',
                  style: _ps(15, w: FontWeight.w700, c: _C.navy),
                ),
                Text(
                  _ugx(netSurplus),
                  style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: netSurplus >= 0 ? Color(0xFF10B981) : Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Cash Position
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3. Cash Position', style: _ps(15, w: FontWeight.w700, c: _C.navy)),
                const SizedBox(height: 16),
                _PortfolioRow('Opening cash balance', _ugx(openingCash), ''),
                _PortfolioRow('Net surplus / (deficit)', _ugx(netSurplus), ''),
                const Divider(height: 24),
                _PortfolioRow('Closing cash balance (bank/safe)', _ugx(closingCash), ''),
                _PortfolioRow('Cash with tellers (open tills)', _ugx(tillsNow), ''),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    border: Border.all(color: Color(0xFF059669)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total closing cash',
                        style: _ps(14, w: FontWeight.w700, c: Color(0xFF065F46)),
                      ),
                      Text(
                        _ugx(totalClosingCash),
                        style: GoogleFonts.robotoMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Loan Portfolio Snapshot
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('4. Loan Portfolio Snapshot', style: _ps(15, w: FontWeight.w700, c: _C.navy)),
                const SizedBox(height: 16),
                _PortfolioRow('Loans disbursed this month', _ugx(_n(loans['amount'])), '${_n(loans['count'])} loans'),
                _PortfolioRow('Repayments collected', _ugx(_n(rep['amount'])), '${_n(rep['count'])} payments'),
                _PortfolioRow('Outstanding loan book (month end)', _ugx(_n(port['outstanding'])), ''),
                _PortfolioRow('Loans in arrears', _ugx(_n(port['overdueAmount'])), '${_n(port['overdueLoans'])} loans'),
                _PortfolioRow('Portfolio at risk (PAR)', '${_n(port['parPercent']).toStringAsFixed(1)}%', ''),
                _PortfolioRow('Active borrowers', '${_n(port['liveLoans'])}', 'members'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Sign-off Section
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('5. Sign-off', style: _ps(15, w: FontWeight.w700, c: _C.navy)),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SignatureBox(
                        title: 'Prepared by',
                        name: FirebaseService.currentUser?.displayName ?? 
                              FirebaseService.currentUser?.email ?? 
                              '',
                        date: DateFormat('d/M/yyyy').format(DateTime.now()),
                        showName: true,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: _SignatureBox(
                        title: 'Checked by (Manager)',
                        name: '',
                        date: '',
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: _SignatureBox(
                        title: 'Approved by (Chairperson)',
                        name: '',
                        date: '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Basis: cash. Interest income is counted when a repayment is recorded. '
                          'Amounts in Uganda Shillings (UGX). Change % = (this month - last month) / last month.',
                          style: _ps(9.5, c: Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

Widget _SummaryKpi(String label, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        Text(label, style: _ps(10.5, c: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.robotoMono(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: color,
        )),
      ],
    ),
  );
}

class _IncomeStatementRow {
  final String label;
  final num thisMonth;
  final num lastMonth;
  
  const _IncomeStatementRow(this.label, this.thisMonth, this.lastMonth);
  
  String get change {
    if (lastMonth == 0) return '-';
    final pct = ((thisMonth - lastMonth) / lastMonth * 100);
    final sign = pct > 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }
}

class _IncomeStatementSection extends StatelessWidget {
  final String title;
  final List<_IncomeStatementRow> rows;
  final _IncomeStatementRow total;
  
  const _IncomeStatementSection({
    required this.title,
    required this.rows,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Text(title, style: _ps(15, w: FontWeight.w700, c: _C.navy)),
          ),
          // Table
          Table(
            border: TableBorder.all(color: Color(0xFFD1D5DB), width: 1),
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(color: Color(0xFFF9FAFB)),
                children: [
                  _TableCell('Item', isHeader: true),
                  _TableCell('This month (UGX)', isHeader: true, alignRight: true),
                  _TableCell('Last month (UGX)', isHeader: true, alignRight: true),
                  _TableCell('Change %', isHeader: true, alignRight: true),
                ],
              ),
              // Data rows
              for (final row in rows)
                TableRow(
                  children: [
                    _TableCell(row.label),
                    _TableCell(_ugx(row.thisMonth), alignRight: true, isMono: true),
                    _TableCell(_ugx(row.lastMonth), alignRight: true, isMuted: true, isMono: true),
                    _TableCell(row.change, alignRight: true, changeColor: _getChangeColor(row.change)),
                  ],
                ),
              // Total row
              TableRow(
                decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                children: [
                  _TableCell(total.label, isBold: true),
                  _TableCell(_ugx(total.thisMonth), alignRight: true, isBold: true, isMono: true),
                  _TableCell(_ugx(total.lastMonth), alignRight: true, isMono: true),
                  _TableCell(total.change, alignRight: true, isBold: true, changeColor: _getChangeColor(total.change)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _TableHeader() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    child: Row(
      children: [
        Expanded(flex: 3, child: Text('Item', style: _ps(12, w: FontWeight.w600, c: _C.navy))),
        Expanded(flex: 2, child: Text('This month (UGX)', textAlign: TextAlign.right, style: _ps(12, w: FontWeight.w600, c: _C.navy))),
        Expanded(flex: 2, child: Text('Last month (UGX)', textAlign: TextAlign.right, style: _ps(12, w: FontWeight.w600, c: _C.navy))),
        Expanded(flex: 1, child: Text('Change %', textAlign: TextAlign.right, style: _ps(12, w: FontWeight.w600, c: _C.navy))),
      ],
    ),
  );
}

Widget _TableRow(_IncomeStatementRow row) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    child: Row(
      children: [
        Expanded(flex: 3, child: Text(row.label, style: _ps(13, c: _C.text))),
        Expanded(
          flex: 2,
          child: Text(
            _ugx(row.thisMonth),
            textAlign: TextAlign.right,
            style: GoogleFonts.robotoMono(fontSize: 13, color: _C.ink),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            _ugx(row.lastMonth),
            textAlign: TextAlign.right,
            style: GoogleFonts.robotoMono(fontSize: 12.5, color: _C.muted),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            row.change,
            textAlign: TextAlign.right,
            style: _ps(12.5, w: FontWeight.w500, c: _getChangeColor(row.change)),
          ),
        ),
      ],
    ),
  );
}

Widget _TableCell(
  String text, {
  bool isHeader = false,
  bool isBold = false,
  bool alignRight = false,
  bool isMono = false,
  bool isMuted = false,
  Color? changeColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: isMono
          ? GoogleFonts.robotoMono(
              fontSize: isHeader || isBold ? 12 : 12,
              fontWeight: isHeader || isBold ? FontWeight.w600 : FontWeight.w400,
              color: changeColor ?? (isMuted ? Color(0xFF6B7280) : _C.ink),
            )
          : _ps(
              isHeader || isBold ? 12 : 12,
              w: isHeader || isBold ? FontWeight.w600 : FontWeight.w400,
              c: changeColor ?? (isMuted ? Color(0xFF6B7280) : _C.ink),
            ),
    ),
  );
}

Color _getChangeColor(String change) {
  if (change == '-') return _C.muted;
  if (change.startsWith('+')) return Color(0xFF10B981);
  if (change.startsWith('-')) return Color(0xFFEF4444);
  return _C.muted;
}

Widget _PortfolioRow(String label, String value, String subtitle) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _ps(13, c: _C.text)),
        Row(
          children: [
            if (subtitle.isNotEmpty) ...[
              Text(subtitle, style: _ps(11, c: _C.muted)),
              const SizedBox(width: 12),
            ],
            Text(
              value,
              style: GoogleFonts.robotoMono(fontSize: 13.5, fontWeight: FontWeight.w600, color: _C.navy),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SignatureBox extends StatelessWidget {
  final String title;
  final String name;
  final String date;
  final bool showName;
  
  const _SignatureBox({
    required this.title,
    required this.name,
    required this.date,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: _ps(11, w: FontWeight.w600, c: Color(0xFF475569)),
        ),
        const SizedBox(height: 16),
        Container(
          height: 60,
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF334155), width: 1.5),
            ),
          ),
          child: showName && name.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    name,
                    style: GoogleFonts.dancingScript(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _C.navy,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          date.isNotEmpty ? 'Date: $date' : 'Date: ___________',
          style: _ps(10, c: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _IncomeTab extends StatelessWidget {
  const _IncomeTab();

  @override
  Widget build(BuildContext context) {
    return _PeriodTab(
      title: 'Income Report',
      subtitle: 'Interest, fees and penalties earned',
      builder: (ctx, r, month, year) {
        if (r['income'] is! Map) {
          return const [
            _EmptyCard(
              icon: Icons.trending_up,
              title: 'No income entries posted',
              message: 'Interest, fee and penalty income is not being posted yet. Until income is recorded, '
                  'the balance sheet cannot show a true surplus.',
            ),
          ];
        }
        return _txnReport(
          ctx,
          data: _m(r['income']),
          period: '${r['period'] ?? ''}',
          month: month,
          year: year,
          noun: 'income',
          groupLabel: 'Source',
          groupOf: (t) => '${t['source'] ?? 'Other'}',
          accent: _C.green,
          icon: Icons.trending_up,
          fileStem: 'income_report',
        );
      },
    );
  }
}

class _ExpenseTab extends StatelessWidget {
  const _ExpenseTab();

  @override
  Widget build(BuildContext context) {
    return _PeriodTab(
      title: 'Expense Report',
      subtitle: 'Operating costs and expenditure',
      builder: (ctx, r, month, year) {
        if (r['expenses'] is! Map) {
          return const [
            _EmptyCard(
              icon: Icons.trending_down,
              title: 'No expenses recorded',
              message: 'Salaries, rent, utilities and other operating costs will appear here once expense entries are posted.',
            ),
          ];
        }
        return _txnReport(
          ctx,
          data: _m(r['expenses']),
          period: '${r['period'] ?? ''}',
          month: month,
          year: year,
          noun: 'expenses',
          groupLabel: 'Category',
          groupOf: (t) => '${t['originalCategory'] ?? t['category'] ?? 'Other'}',
          accent: _C.red,
          icon: Icons.trending_down,
          fileStem: 'expense_report',
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Trial Balance
// ═══════════════════════════════════════════════════════════════════════════════
class _TbEntry {
  final String label;
  final num? debit, credit;
  const _TbEntry(this.label, {this.debit, this.credit});
}

class _TbGroup {
  final String title;
  final List<_TbEntry> entries;
  const _TbGroup(this.title, this.entries);
}

class _TrialBalanceTab extends StatelessWidget {
  const _TrialBalanceTab();

  Widget _cell(num? v, {bool bold = false}) {
    return Expanded(
      flex: 2,
      child: v == null
          ? const SizedBox.shrink()
          : Align(
              alignment: Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: _amount(v, bold: bold)),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PageHeader(title: 'Trial Balance', subtitle: 'Debit and credit balances by account'),
        Expanded(
          child: _ReportLoader<Map<String, dynamic>>(
            load: () => ReportService.generateTrialBalance(),
            builder: (ctx, tb) {
              final p = _Position.fromTrialBalance(tb);
              final deficit = p.retained < 0;
              final groups = <_TbGroup>[
                _TbGroup('ASSETS', [
                  _TbEntry('Cash, bank & mobile money', debit: p.cash),
                  _TbEntry('Loans to members - principal', debit: p.principal),
                  _TbEntry('Loans to members - interest receivable', debit: p.interest),
                ]),
                _TbGroup('LIABILITIES', [
                  _TbEntry('Member savings deposits (incl. wallets)', credit: p.savings),
                  _TbEntry('Fixed deposits', credit: p.fixedDeposits),
                ]),
                _TbGroup("MEMBERS' EQUITY", [
                  _TbEntry('Share capital', credit: p.shares),
                  deficit
                      ? _TbEntry(p.balancingLabel, debit: -p.retained)
                      : _TbEntry(p.balancingLabel, credit: p.retained),
                ]),
              ];
              num dr = 0, cr = 0;
              for (final g in groups) {
                for (final e in g.entries) {
                  dr += e.debit ?? 0;
                  cr += e.credit ?? 0;
                }
              }
              final balanced = (dr - cr).abs() < 1;
              final issues = p.issues;

              Future<void> csv() async {
                final b = StringBuffer()
                  ..writeln('MBADIFA SACCO')
                  ..writeln('TRIAL BALANCE')
                  ..writeln('As at ${DateFormat('d MMMM yyyy').format(p.asOf)}')
                  ..writeln('Account,Debit (UGX),Credit (UGX)');
                for (final g in groups) {
                  b.writeln(_q(g.title));
                  for (final e in g.entries) {
                    b.writeln('${_q(e.label)},${e.debit ?? ''},${e.credit ?? ''}');
                  }
                }
                b.writeln('Total,$dr,$cr');
                await _saveCsv(ctx, 'trial_balance_${DateFormat('yyyyMMdd').format(p.asOf)}.csv', b.toString());
              }

              Widget colHeader() => Container(
                    color: const Color(0xFF16345F),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 4, child: Text('ACCOUNT', style: _ps(11, w: FontWeight.w600, c: Colors.white, ls: 1))),
                      Expanded(flex: 2, child: Text('DEBIT', textAlign: TextAlign.right, style: _ps(11, w: FontWeight.w600, c: Colors.white, ls: 1))),
                      Expanded(flex: 2, child: Text('CREDIT', textAlign: TextAlign.right, style: _ps(11, w: FontWeight.w600, c: Colors.white, ls: 1))),
                    ]),
                  );

              final table = Container(
                decoration: _cardDeco(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatementBanner(title: 'Trial Balance', asOf: p.asOf),
                    colHeader(),
                    for (final g in groups) ...[
                      Container(
                        color: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(g.title, style: _ps(11.5, w: FontWeight.w700, c: _C.navy, ls: 0.8)),
                      ),
                      for (final e in g.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                          child: Row(children: [
                            Expanded(flex: 4, child: Text(e.label, style: _ps(13))),
                            _cell(e.debit),
                            _cell(e.credit),
                          ]),
                        ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: _C.navy.withOpacity(0.06),
                        border: const Border(
                          top: BorderSide(color: _C.navy, width: 1.5),
                          bottom: BorderSide(color: _C.navy, width: 3),
                        ),
                      ),
                      child: Row(children: [
                        Expanded(flex: 4, child: Text('TOTAL', style: _ps(14, w: FontWeight.w700, c: _C.navy))),
                        _cell(dr, bold: true),
                        _cell(cr, bold: true),
                      ]),
                    ),
                  ],
                ),
              );

              return [
                _AsAtBar(asOf: p.asOf, actions: [
                  _Badge(balanced ? 'Debits = Credits' : 'Out of balance', balanced ? _C.green : _C.red),
                  if (p.cashMissing) _Badge('Cash not recorded', _C.amber),
                  _btn('Export CSV', Icons.table_chart_outlined, csv),
                ]),
                _PositionSummary(p),
                ...issues.map((i) => _Alert(i)),
                _Split(main: table, side: _positionSide(p)),
              ];
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Balance Sheet
// ═══════════════════════════════════════════════════════════════════════════════
class _BalanceSheetTab extends StatelessWidget {
  const _BalanceSheetTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PageHeader(title: 'Balance Sheet', subtitle: 'Statement of financial position'),
        Expanded(
          child: _ReportLoader<Map<String, dynamic>>(
            // Built from the same figures as the Trial Balance so the two always agree.
            load: () => ReportService.generateTrialBalance(),
            builder: (ctx, tb) {
              final p = _Position.fromTrialBalance(tb);
              final rows = <_Row>[
                const _Row.header('ASSETS'),
                const _Row.sub('Current assets'),
                _Row.item('Cash, bank & mobile money', p.cash),
                _Row.item('Loans to members - principal', p.principal),
                _Row.item('Interest receivable', p.interest),
                _Row.total('Total assets', p.assets),
                const _Row.header('LIABILITIES'),
                _Row.item('Member savings deposits (incl. wallets)', p.savings),
                _Row.item('Fixed deposits', p.fixedDeposits),
                _Row.total('Total liabilities', p.liabilities),
                const _Row.header("MEMBERS' EQUITY"),
                _Row.item('Share capital', p.shares),
                _Row.item(p.balancingLabel, p.retained,
                    hint: 'Balancing figure (assets - liabilities - share capital)'),
                _Row.total("Total members' equity", p.equity),
                _Row.grand('Total liabilities & equity', p.liabilities + p.equity),
              ];
              final issues = p.issues;
              final date = DateFormat('yyyyMMdd').format(p.asOf);

              return [
                _AsAtBar(asOf: p.asOf, actions: [
                  _btn('Export CSV', Icons.table_chart_outlined,
                      () => _saveCsv(ctx, 'balance_sheet_$date.csv', _rowsToCsv('BALANCE SHEET', p.asOf, rows))),
                  _btn('Export PDF', Icons.picture_as_pdf_outlined,
                      () => _printStatement('Balance Sheet', p.asOf, rows),
                      primary: true),
                ]),
                _PositionSummary(p),
                ...issues.map((i) => _Alert(i)),
                _Split(
                  main: _StatementCard(title: 'Balance sheet', rows: rows, asOf: p.asOf),
                  side: _positionSide(p),
                ),
              ];
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KYC
// ═══════════════════════════════════════════════════════════════════════════════
class _KycTab extends StatelessWidget {
  const _KycTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PageHeader(title: 'KYC Compliance', subtitle: 'Member identity verification status'),
        Expanded(
          child: _ReportLoader<Map<String, dynamic>>(
            load: () => ReportService.generateKYCReport(),
            builder: (ctx, r) {
              final s = _m(r['summary']);
              final pending = (r['pendingVerifications'] as List?) ?? const [];
              final rejected = (r['rejectedVerifications'] as List?) ?? const [];
              final rate = _n(s['verificationRate']).toDouble();
              String date(dynamic d) => d is DateTime ? DateFormat.yMMMd().format(d) : '-';

              final pendingCard = pending.isEmpty
                  ? const _EmptyCard(
                      icon: Icons.check_circle_outline,
                      title: 'No pending verifications',
                      message: 'Every submitted ID has been reviewed.')
                  : _ListCard(title: 'Pending verifications (${pending.length})', children: [
                      for (final m in pending)
                        _PersonTile(
                          name: '${m['name'] ?? ''}',
                          phone: '${m['phone'] ?? ''}',
                          note: 'Submitted ${date(m['submittedAt'])}',
                          color: _C.amber,
                        ),
                    ]);

              final rejectedCard = rejected.isEmpty
                  ? const _EmptyCard(
                      icon: Icons.thumb_up_alt_outlined,
                      title: 'No rejected verifications',
                      message: 'No member IDs have been rejected.')
                  : _ListCard(title: 'Rejected verifications (${rejected.length})', children: [
                      for (final m in rejected)
                        _PersonTile(
                          name: '${m['name'] ?? ''}',
                          phone: '${m['phone'] ?? ''}',
                          note: '${m['reason'] ?? ''}',
                          color: _C.red,
                        ),
                    ]);

              return [
                _KpiGrid(children: [
                  _Kpi(label: 'Total members', value: '${_n(s['total']).toInt()}', icon: Icons.people_outline, color: _C.blue),
                  _Kpi(label: 'Verified', value: '${_n(s['verified']).toInt()}', icon: Icons.verified_user_outlined, color: _C.green),
                  _Kpi(label: 'Pending', value: '${_n(s['pending']).toInt()}', icon: Icons.hourglass_empty, color: _C.amber),
                  _Kpi(label: 'Rejected', value: '${_n(s['rejected']).toInt()}', icon: Icons.cancel_outlined, color: _C.red),
                ]),
                const SizedBox(height: 16),
                _RateCard(label: 'Verification rate', percent: rate, color: rate >= 80 ? _C.green : (rate >= 50 ? _C.amber : _C.red)),
                const SizedBox(height: 16),
                _Split(mainFlex: 1, sideFlex: 1, breakpoint: 900, main: pendingCard, side: rejectedCard),
              ];
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Loans
// ═══════════════════════════════════════════════════════════════════════════════
class _LoansTab extends StatelessWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _PageHeader(title: 'Loan Portfolio', subtitle: 'Disbursements, repayments and portfolio quality'),
        Expanded(
          child: _ReportLoader<Map<String, dynamic>>(
            load: () => ReportService.generateLoanReport(),
            builder: (ctx, r) {
              final f = _m(r['financials']);
              final s = _m(r['summary']);
              final overdue = (r['overdueLoans'] as List?) ?? const [];
              final disbursed = _n(f['totalAmountDisbursed']);
              final repaid = _n(f['totalRepaid']);
              final outstanding = _n(f['totalOutstanding']);
              final gap = disbursed - repaid - outstanding;
              final issues = <_Issue>[];
              if (disbursed > 0 && repaid == 0) {
                issues.add(_Issue('No repayments recorded',
                    '${_ugx(disbursed)} has been disbursed but total repaid is ${_ugx(0)}. Check that repayments are being posted against loans.'));
              }
              if (gap.abs() > 1) {
                issues.add(_Issue('Loan book does not reconcile',
                    'Disbursed - repaid - outstanding = ${_ugx(gap)}. After interest and fees this should be close to zero. '
                    'Check closed/written-off loans and unposted repayments.'));
              }

              return [
                ...issues.map((i) => _Alert(i)),
                _KpiGrid(maxCols: 3, children: [
                  _Kpi(label: 'Total requested', value: _ugx(_n(f['totalAmountRequested'])), icon: Icons.request_quote_outlined, color: _C.blue),
                  _Kpi(label: 'Disbursed', value: _ugx(disbursed), icon: Icons.payments_outlined, color: _C.navy),
                  _Kpi(label: 'Repaid', value: _ugx(repaid), icon: Icons.check_circle_outline, color: _C.green),
                  _Kpi(label: 'Outstanding', value: _ugx(outstanding), icon: Icons.pending_actions, color: _C.amber),
                  _Kpi(label: 'Approval rate', value: '${_n(s['approvalRate']).toDouble().toStringAsFixed(1)}%', icon: Icons.thumb_up_outlined, color: _C.teal),
                  _Kpi(label: 'Repayment rate', value: '${_n(s['repaymentRate']).toDouble().toStringAsFixed(1)}%', icon: Icons.trending_up, color: _C.green),
                ]),
                const SizedBox(height: 16),
                _Split(
                  mainFlex: 1,
                  sideFlex: 1,
                  breakpoint: 900,
                  main: _InfoCard(title: 'Loan status breakdown', rows: [
                    ['Total loans', '${_n(s['totalLoans']).toInt()}', _C.navy],
                    ['Pending', '${_n(s['pending']).toInt()}', _C.amber],
                    ['Approved', '${_n(s['approved']).toInt()}', _C.green],
                    ['Rejected', '${_n(s['rejected']).toInt()}', _C.red],
                    ['Paid', '${_n(s['paid']).toInt()}', _C.blue],
                    ['Overdue', '${_n(s['overdue']).toInt()}', Colors.deepOrange],
                  ]),
                  side: overdue.isEmpty
                      ? const _EmptyCard(
                          icon: Icons.check_circle_outline,
                          title: 'No overdue loans',
                          message: 'All active loans are up to date.')
                      : _ListCard(title: 'Overdue loans (${overdue.length})', children: [
                          for (final l in overdue.take(10))
                            _PersonTile(
                              name: '${l['farmerName'] ?? ''}',
                              phone: 'Amount ${_ugx(_n(l['amount']))}  •  Outstanding ${_ugx(_n(l['outstanding']))}',
                              note: '${_n(l['daysOverdue']).toInt()} days overdue',
                              color: _C.red,
                            ),
                        ]),
                ),
              ];
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Members
// ═══════════════════════════════════════════════════════════════════════════════
class _MembersTab extends StatefulWidget {
  const _MembersTab();

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  String _query = '';
  List<Map<String, dynamic>> _latest = const [];

  _BadgeInfo _status(String s) {
    switch (s) {
      case 'approved':
        return _BadgeInfo('Verified', _C.green);
      case 'pending':
        return _BadgeInfo('Pending', _C.amber);
      case 'rejected':
        return _BadgeInfo('Rejected', _C.red);
      default:
        return _BadgeInfo('Not submitted', _C.muted);
    }
  }

  Future<void> _export() async {
    if (_latest.isEmpty) return;
    try {
      final csv = ReportService.exportMembersToCSV(_latest);
      await _saveCsv(context, 'members_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', csv.toString());
    } catch (e) {
      _toast(context, 'Export failed: $e', error: true);
    }
  }

  /// Full-width member table. Columns flex with the screen; below 760px the
  /// table scrolls horizontally instead of squeezing.
  Widget _table(List<Map<String, dynamic>> list) {
    Widget cell(int flex, Widget child, {Alignment align = Alignment.centerLeft}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Align(alignment: align, child: child),
          ),
        );

    Widget head(int flex, String t, {bool right = false}) => cell(
          flex,
          Text(t, style: _ps(11.5, w: FontWeight.w600, c: Colors.white, ls: 0.6)),
          align: right ? Alignment.centerRight : Alignment.centerLeft,
        );

    return LayoutBuilder(builder: (context, box) {
      const minW = 760.0;
      final w = box.maxWidth < minW ? minW : box.maxWidth;

      return Container(
        decoration: _cardDeco(),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: _C.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    head(4, 'NAME'),
                    head(3, 'PHONE'),
                    head(2, 'KYC'),
                    head(3, 'SAVINGS', right: true),
                    head(3, 'SHARES', right: true),
                    head(2, 'LOANS', right: true),
                  ]),
                ),
                for (var i = 0; i < list.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: i.isOdd ? const Color(0xFFFAFBFC) : Colors.white,
                      border: const Border(bottom: BorderSide(color: Color(0xFFF1F3F6))),
                    ),
                    child: Row(children: [
                      cell(
                        4,
                        Row(children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _C.blue.withOpacity(0.1),
                            child: Text(
                              '${list[i]['name'] ?? '?'}'.trim().isEmpty
                                  ? '?'
                                  : '${list[i]['name']}'.trim()[0].toUpperCase(),
                              style: _ps(12, w: FontWeight.w600, c: _C.blue),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${list[i]['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _ps(12.5, w: FontWeight.w600)),
                          ),
                        ]),
                      ),
                      cell(
                        3,
                        Text('${list[i]['phone'] ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: _ps(12.5)),
                      ),
                      cell(2, () {
                        final b = _status('${list[i]['idStatus'] ?? ''}');
                        return _Badge(b.label, b.color);
                      }()),
                      cell(
                        3,
                        Text(_money(_n(list[i]['savingsBalance']), dash: false),
                            style: GoogleFonts.robotoMono(fontSize: 12.5)),
                        align: Alignment.centerRight,
                      ),
                      cell(
                        3,
                        Text(_money(_n(list[i]['sharesValue']), dash: false),
                            style: GoogleFonts.robotoMono(fontSize: 12.5)),
                        align: Alignment.centerRight,
                      ),
                      cell(
                        2,
                        Text('${_n(list[i]['activeLoans']).toInt()} / ${_n(list[i]['totalLoans']).toInt()}',
                            style: _ps(12.5)),
                        align: Alignment.centerRight,
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PageHeader(
          title: 'Member Directory',
          subtitle: 'Balances and verification status per member',
          trailing: _btn('Export CSV', Icons.download_outlined, _export, primary: true),
        ),
        LayoutBuilder(builder: (context, box) {
          final pad = _padFor(box.maxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
                child: TextField(
                  style: _ps(13),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone',
                    hintStyle: _ps(13, c: _C.muted),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _C.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _C.border),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
            ),
          );
        }),
        Expanded(
          child: _ReportLoader<List<Map<String, dynamic>>>(
            load: () => ReportService.generateMemberReport(),
            builder: (ctx, all) {
              _latest = all;
              final list = _query.isEmpty
                  ? all
                  : all.where((m) {
                      final name = '${m['name'] ?? ''}'.toLowerCase();
                      final phone = '${m['phone'] ?? ''}'.toLowerCase();
                      return name.contains(_query) || phone.contains(_query);
                    }).toList();

              num totSav = 0, totSh = 0;
              for (final m in all) {
                totSav += _n(m['savingsBalance']);
                totSh += _n(m['sharesValue']);
              }

              return [
                _KpiGrid(maxCols: 3, children: [
                  _Kpi(label: 'Members', value: '${all.length}', icon: Icons.people_outline, color: _C.blue),
                  _Kpi(label: 'Total savings', value: _ugx(totSav), icon: Icons.savings_outlined, color: _C.teal),
                  _Kpi(label: 'Total shares', value: _ugx(totSh), icon: Icons.pie_chart_outline, color: _C.purple),
                ]),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  _EmptyCard(
                    icon: Icons.people_outline,
                    title: _query.isEmpty ? 'No members found' : 'No members match your search',
                    message: 'Try a different name or phone number.',
                  )
                else
                  _table(list),
              ];
            },
          ),
        ),
      ],
    );
  }
}

class _BadgeInfo {
  final String label;
  final Color color;
  const _BadgeInfo(this.label, this.color);
}

// Chart helper functions
BarChartGroupData _barGroup(int x, double y, Color color) {
  return BarChartGroupData(
    x: x,
    barRods: [
      BarChartRodData(
        toY: y,
        color: color,
        width: 24,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
    ],
  );
}

Widget _legendItem(String label, Color color, String value) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _ps(10.5, c: _C.muted)),
          Text(value, style: _ps(13, w: FontWeight.w600)),
        ],
      ),
    ],
  );
}

// New PDF helper functions for professional monthly report
pw.Widget _pdfKpiBox(String label, String value, PdfColor color) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.only(right: 8),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _pdfSectionHeader(String text) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    margin: const pw.EdgeInsets.only(bottom: 4),
    decoration: const pw.BoxDecoration(
      color: PdfColors.grey200,
    ),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey800,
      ),
    ),
  );
}

pw.Widget _pdfTable(List<List<String>> rows) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: {
      0: const pw.FlexColumnWidth(3),
      1: const pw.FlexColumnWidth(2),
    },
    children: rows.map((row) {
      return pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Text(
              row[0],
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                row[1],
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }).toList(),
  );
}

pw.Widget _pdfTableTotal(String label, String value, PdfColor color) {
  // Create a lighter version of the color by mixing with white
  final lightColor = PdfColor(
    color.red + (1 - color.red) * 0.9,
    color.green + (1 - color.green) * 0.9,
    color.blue + (1 - color.blue) * 0.9,
  );
  
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    margin: const pw.EdgeInsets.only(top: 4),
    decoration: pw.BoxDecoration(
      color: lightColor,
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/report_service.dart';
import '../../utils/file_saver.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Design tokens & helpers
// ═══════════════════════════════════════════════════════════════════════════════
class _C {
  static const navy = Color(0xFF0B2545);
  static const blue = Color(0xFF1D4ED8);
  static const bg = Color(0xFFF4F6FA);
  static const border = Color(0xFFE3E8EF);
  static const text = Color(0xFF111827);
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
enum _K { header, sub, item, total, grand }

class _Row {
  final _K kind;
  final String label;
  final num? amount;
  final String? hint;
  final bool showZero;
  const _Row(this.kind, this.label, [this.amount, this.hint, this.showZero = false]);
  const _Row.header(String label) : this(_K.header, label);
  const _Row.sub(String label) : this(_K.sub, label);
  const _Row.item(String label, num amount, {String? hint, bool showZero = false})
      : this(_K.item, label, amount, hint, showZero);
  const _Row.total(String label, num amount) : this(_K.total, label, amount);
  const _Row.grand(String label, num amount) : this(_K.grand, label, amount);
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
    _run();
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

  Future<void> export() async {
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

  return [
    Align(
      alignment: Alignment.centerRight,
      child: _btn('Export CSV', Icons.file_download_outlined, export, primary: true),
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
            key: ValueKey('$_month-$_year-${widget.title}'),
            load: () => ReportService.generateMonthlyReport(year: _year, month: _month),
            builder: (ctx, r) => widget.builder(ctx, r, _month, _year),
          ),
        ),
      ],
    );
  }
}

class _MonthlyTab extends StatelessWidget {
  const _MonthlyTab();

  @override
  Widget build(BuildContext context) {
    return _PeriodTab(
      title: 'Monthly Report',
      subtitle: 'Cash movement from lending, savings and share activity',
      builder: (ctx, r, month, year) {
        final loans = _m(r['loans']);
        final rep = _m(r['repayments']);
        final sav = _m(r['savings']);
        final sh = _m(r['shares']);
        final inflow = _n(rep['amount']) + _n(sav['amount']) + _n(sh['amount']);
        final outflow = _n(loans['amount']);
        final net = inflow - outflow;
        String tx(Map m) => '${_n(m['count']).toInt()} transactions';

        final rows = <_Row>[
          const _Row.header('CASH INFLOWS'),
          _Row.item('Loan repayments received', _n(rep['amount']), hint: tx(rep)),
          _Row.item('Savings deposits', _n(sav['amount']), hint: tx(sav)),
          _Row.item('Share purchases', _n(sh['amount']), hint: tx(sh)),
          _Row.total('Total inflows', inflow),
          const _Row.header('CASH OUTFLOWS'),
          _Row.item('Loans disbursed', _n(loans['amount']), hint: tx(loans)),
          _Row.total('Total outflows', outflow),
          _Row.grand('Net cash flow', net),
        ];

        Future<void> export() async {
          final b = StringBuffer()
            ..writeln('MBADIFA SACCO')
            ..writeln('Monthly Report - ${r['period'] ?? '$month/$year'}')
            ..writeln('Category,Count,Amount (UGX)')
            ..writeln('Loans Disbursed,${_n(loans['count'])},${_n(loans['amount'])}')
            ..writeln('Loan Repayments,${_n(rep['count'])},${_n(rep['amount'])}')
            ..writeln('Savings Deposits,${_n(sav['count'])},${_n(sav['amount'])}')
            ..writeln('Share Purchases,${_n(sh['count'])},${_n(sh['amount'])}')
            ..writeln('Net Cash Flow,,$net');
          await _saveCsv(ctx, 'monthly_report_${year}_${month.toString().padLeft(2, '0')}.csv', b.toString());
        }

        return [
          Align(
            alignment: Alignment.centerRight,
            child: _btn('Export CSV', Icons.file_download_outlined, export, primary: true),
          ),
          const SizedBox(height: 14),
          _KpiGrid(children: [
            _Kpi(label: 'Loans disbursed', value: _ugx(_n(loans['amount'])), sub: tx(loans), icon: Icons.credit_card, color: _C.blue),
            _Kpi(label: 'Loan repayments', value: _ugx(_n(rep['amount'])), sub: tx(rep), icon: Icons.payments_outlined, color: _C.green),
            _Kpi(label: 'Savings deposits', value: _ugx(_n(sav['amount'])), sub: tx(sav), icon: Icons.savings_outlined, color: _C.teal),
            _Kpi(label: 'Share purchases', value: _ugx(_n(sh['amount'])), sub: tx(sh), icon: Icons.pie_chart_outline, color: _C.purple),
          ]),
          const SizedBox(height: 16),
          _Split(
            main: _StatementCard(title: 'Cash movement - ${r['period'] ?? ''}', rows: rows),
            side: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarsCard(
                  title: 'Inflow mix',
                  subtitle: 'Where the cash came from',
                  items: [
                    _BarItem('Loan repayments', _n(rep['amount']), _C.green, sub: tx(rep)),
                    _BarItem('Savings deposits', _n(sav['amount']), _C.teal, sub: tx(sav)),
                    _BarItem('Share purchases', _n(sh['amount']), _C.purple, sub: tx(sh)),
                  ],
                ),
                const SizedBox(height: 16),
                _BarsCard(
                  title: 'Inflows vs outflows',
                  subtitle: 'Net cash flow: ${_ugx(net)}',
                  items: [
                    _BarItem('Total inflows', inflow, _C.green),
                    _BarItem('Total outflows', outflow, _C.blue),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('Based on loan, repayment, savings and share transactions recorded in the period.',
                style: _ps(11, c: _C.muted), textAlign: TextAlign.center),
          ),
        ];
      },
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
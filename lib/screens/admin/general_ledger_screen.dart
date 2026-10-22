import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';

// ─── Design tokens (same palette as the loan screen) ──────────────────────────
class _C {
  static const brand = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);
  static const ink = Color(0xFF0F172A);
  static const text = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const line = Color(0xFFE5E9F0);
  static const hair = Color(0xFFF1F4F9);
  static const soft = Color(0xFFF4F6FA);
  static const bg = Color(0xFFF2F4F8);
  static const green = Color(0xFF047857);
  static const red = Color(0xFFB91C1C);
  static const amber = Color(0xFFB45309);
  static const teal = Color(0xFF0F766E);
  static Color tint(Color c, [double a = 0.10]) =>
      c.withAlpha((a * 255).round());
}

// ─── Chart of accounts ────────────────────────────────────────────────────────
class _Acct {
  final String code, name, type;
  final bool debitNormal;
  const _Acct(this.code, this.name, this.type, this.debitNormal);
}

const _coa = <_Acct>[
  _Acct('1000', 'Cash on hand', 'Asset', true),
  _Acct('1010', 'Mobile money', 'Asset', true),
  _Acct('1100', 'Loans receivable', 'Asset', true),
  _Acct('2000', 'Member savings', 'Liability', false),
  _Acct('4000', 'Interest income', 'Income', false),
  _Acct('4100', 'Loan fee income', 'Income', false),
  _Acct('4200', 'Other income', 'Income', false),
  _Acct('5000', 'Operating expenses', 'Expense', true),
];

final _coaByCode = <String, _Acct>{for (final a in _coa) a.code: a};

// ─── Journal model ────────────────────────────────────────────────────────────
class _JLine {
  final String code;
  final double dr, cr;
  const _JLine(this.code, this.dr, this.cr);
}

class _JEntry {
  final DateTime date;
  final String narration, source;
  final List<_JLine> lines;
  String ref = '';
  _JEntry(this.date, this.narration, this.source, this.lines);
  double get total => lines.fold(0.0, (s, l) => s + l.dr);
}

class _Row {
  final _JEntry e;
  final double dr, cr, bal; // bal = running balance, debit-positive
  const _Row(this.e, this.dr, this.cr, this.bal);
}

class _Sum {
  double open = 0, dr = 0, cr = 0; // open / period movement, debit-positive
  final rows = <_Row>[];
  double get net => open + dr - cr;
}

class _TbRow {
  final _Acct a;
  final double open, dr, cr, net;
  const _TbRow(this.a, this.open, this.dr, this.cr, this.net);
}

// ═════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<_JEntry> _all = [];
  String _period = 'all'; // all | month | last | year | custom
  DateTimeRange? _range;
  int _tab = 0; // 0 trial balance, 1 account ledger, 2 journal
  String _acct = '1000';
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ─── Small helpers ──────────────────────────────────────────────────────────
  TextStyle _t(double size,
          {FontWeight w = FontWeight.w400, Color c = _C.text}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);

  TextStyle _num(double size,
          {FontWeight w = FontWeight.w500, Color c = _C.ink}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

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

  DateTime? _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _d(DateTime d) => DateFormat('d MMM yyyy').format(d);
  String _m(double v) => v.abs() < 0.5 ? '-' : _fmt.format(v.round());
  String _b(double v) => _fmt.format(v.round());

  Color _typeColor(String t) {
    switch (t) {
      case 'Asset':
        return _C.blue;
      case 'Liability':
        return _C.amber;
      case 'Income':
        return _C.green;
      case 'Expense':
        return _C.red;
      default:
        return _C.teal;
    }
  }

  double _nat(_Acct a, double net) => a.debitNormal ? net : -net;

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: _t(13.5, c: Colors.white)),
        backgroundColor: ok ? _C.ink : _C.red,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ─── Period ─────────────────────────────────────────────────────────────────
  DateTime? get _from {
    final n = DateTime.now();
    switch (_period) {
      case 'month':
        return DateTime(n.year, n.month, 1);
      case 'last':
        return DateTime(n.year, n.month - 1, 1);
      case 'year':
        return DateTime(n.year, 1, 1);
      case 'custom':
        return _range?.start;
      default:
        return null;
    }
  }

  DateTime? get _to {
    final n = DateTime.now();
    switch (_period) {
      case 'month':
        return DateTime(n.year, n.month + 1, 1);
      case 'last':
        return DateTime(n.year, n.month, 1);
      case 'year':
        return DateTime(n.year + 1, 1, 1);
      case 'custom':
        final r = _range;
        return r == null
            ? null
            : DateTime(r.end.year, r.end.month, r.end.day + 1);
      default:
        return null;
    }
  }

  String get _periodLabel {
    final f = _from, t = _to;
    if (f == null && t == null) return 'All time';
    final end = t?.subtract(const Duration(days: 1));
    return '${f == null ? 'Start' : _d(f)} to ${end == null ? 'today' : _d(end)}';
  }

  bool _inPeriod(DateTime d) {
    final f = _from, t = _to;
    return (f == null || !d.isBefore(f)) && (t == null || d.isBefore(t));
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (r != null) {
      setState(() {
        _range = r;
        _period = 'custom';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA: build balanced journal entries from the real business records
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final tenant = FirebaseService.sessionTenantId;
      Future<QuerySnapshot<Map<String, dynamic>>> get(String col) =>
          db.collection(col).where('tenantId', isEqualTo: tenant).get();

      final r = await Future.wait([
        get(AppConstants.loansCol),
        get(AppConstants.repaymentsCol),
        get(AppConstants.savingsCol),
        get(AppConstants.tellerTxnCol), // Changed from 'income'
      ]);

      final out = <_JEntry>[];

      // 1. Loan disbursements: Dr Loans receivable / Cr Member savings
      for (final doc in r[0].docs) {
        final d = doc.data();
        final st = (d['status'] ?? '').toString().toLowerCase();
        if (st == 'rejected' || st == 'pending') continue;
        final date = _dt(d['disbursedAt'] ?? d['disbursementDate']);
        final amt = _pick(d, ['loanAmount', 'principal', 'amount']);
        if (date == null || amt <= 0) continue;
        final who = (d['memberName'] ?? d['borrowerName'] ?? 'Member').toString();
        out.add(_JEntry(date, 'Loan disbursement - $who', 'Loans', [
          _JLine('1100', amt, 0),
          _JLine('2000', 0, amt),
        ]));
      }

      // 2. Loan repayments
      for (final doc in r[1].docs) {
        final d = doc.data();
        var p = _pick(d, ['principalAmount', 'principalPaid', 'principal']);
        final i = _pick(d, ['interestAmount', 'interestPaid', 'interest']);
        final c = _pick(d, ['chargesAmount', 'chargesPaid', 'charges']);
        final total = _pick(d, ['amount', 'totalAmount']);
        if (p + i + c == 0 && total > 0) p = total;
        final sum = p + i + c;
        final date = _dt(d['paymentDate'] ?? d['createdAt']);
        if (sum <= 0 || date == null) continue;
        final method = (d['paymentMethod'] ?? 'Cash').toString();
        final debit = method == 'Mobile Money'
            ? '1010'
            : method == 'Transfer from Savings'
                ? '2000'
                : '1000';
        final who = (d['memberName'] ?? 'Member').toString();
        out.add(_JEntry(date, 'Loan repayment - $who ($method)', 'Repayments', [
          _JLine(debit, sum, 0),
          if (p > 0) _JLine('1100', 0, p),
          if (i > 0) _JLine('4000', 0, i),
          if (c > 0) _JLine('4100', 0, c),
        ]));
      }

      // 3. Savings deposits / withdrawals
      for (final doc in r[2].docs) {
        final d = doc.data();
        if (d['loanId'] != null) continue;
        final type = (d['type'] ?? '').toString().toLowerCase();
        if (type != 'deposit' && type != 'withdrawal') continue;
        final st = (d['status'] ?? 'approved').toString().toLowerCase();
        if (st != 'approved') continue;
        final amt = _pick(d, ['amount']);
        final date = _dt(d['timestamp'] ?? d['createdAt']);
        if (amt <= 0 || date == null) continue;
        final mobile = (d['paymentMethod'] ?? '')
            .toString()
            .toLowerCase()
            .contains('mobile');
        final cash = mobile ? '1010' : '1000';
        final who = (d['memberName'] ?? d['farmerName'] ?? 'Member').toString();
        if (type == 'deposit') {
          out.add(_JEntry(date, 'Savings deposit - $who', 'Savings',
              [_JLine(cash, amt, 0), _JLine('2000', 0, amt)]));
        } else {
          out.add(_JEntry(date, 'Savings withdrawal - $who', 'Savings',
              [_JLine('2000', amt, 0), _JLine(cash, 0, amt)]));
        }
      }

      // 4. Teller transactions (revenue and expenses)
      for (final doc in r[3].docs) {
        final d = doc.data();
        final txnType = (d['type'] ?? '').toString().toLowerCase();
        final amt = _pick(d, ['amount']);
        final date = _dt(d['timestamp'] ?? d['createdAt']);
        if (amt <= 0 || date == null) continue;
        final desc = (d['description'] ?? '').toString();
        final cat = (d['category'] ?? d['source'] ?? 'General').toString();
        
        if (txnType == 'revenue') {
          out.add(_JEntry(date, desc.isEmpty ? cat : '$cat - $desc', 'Income',
              [_JLine('1000', amt, 0), _JLine('4200', 0, amt)]));
        } else if (txnType == 'expense') {
          out.add(_JEntry(date, desc.isEmpty ? cat : '$cat - $desc', 'Expenses',
              [_JLine('5000', amt, 0), _JLine('1000', 0, amt)]));
        }
      }

      out.sort((a, b) => a.date.compareTo(b.date));
      for (var i = 0; i < out.length; i++) {
        out[i].ref = 'JV-${(i + 1).toString().padLeft(6, '0')}';
      }

      if (!mounted) return;
      setState(() {
        _all = out;
        _loading = false;
      });
    } catch (e) {
      debugPrint('General ledger load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALCULATION: opening balance + period movement per account
  // ═══════════════════════════════════════════════════════════════════════════
  Map<String, _Sum> _compute() {
    final from = _from, to = _to;
    final m = <String, _Sum>{for (final a in _coa) a.code: _Sum()};

    for (final e in _all) {
      final before = from != null && e.date.isBefore(from);
      final within = !before && (to == null || e.date.isBefore(to));
      if (!before && !within) continue;

      for (final l in e.lines) {
        final sm = m[l.code];
        if (sm == null) continue;
        if (before) {
          sm.open += l.dr - l.cr;
        } else {
          sm.dr += l.dr;
          sm.cr += l.cr;
          sm.rows.add(_Row(e, l.dr, l.cr, sm.open + sm.dr - sm.cr));
        }
      }
    }
    return m;
  }

  List<_TbRow> _tbList(Map<String, _Sum> s) => [
        for (final a in _coa)
          _TbRow(a, s[a.code]!.open, s[a.code]!.dr, s[a.code]!.cr,
              s[a.code]!.net),
      ];

  /// [period debits, period credits, closing debits, closing credits]
  List<double> _tbTotals(List<_TbRow> rows) {
    var dr = 0.0, cr = 0.0, cDr = 0.0, cCr = 0.0;
    for (final r in rows) {
      dr += r.dr;
      cr += r.cr;
      if (r.net >= 0.5) {
        cDr += r.net;
      } else if (r.net <= -0.5) {
        cCr += -r.net;
      }
    }
    return [dr, cr, cDr, cCr];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _C.ink,
        shape: const Border(bottom: BorderSide(color: _C.line)),
        titleSpacing: 20,
        title: Text('General ledger',
            style: _t(17, w: FontWeight.w700, c: _C.ink)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Print this view',
            icon: const Icon(Icons.print_outlined, size: 22),
            onPressed: _loading ? null : _print,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final gutter = w >= 900 ? 28.0 : (w >= 600 ? 20.0 : 12.0);
          final hp = math.max(gutter, (w - 1500) / 2);

          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return _message(Icons.error_outline, 'Could not load the ledger',
                _error!, retry: true);
          }

          final sums = _compute();
          final inner = w - 2 * hp;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(hp, gutter, hp, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _periodBar(),
                      const SizedBox(height: 14),
                      _kpis(sums),
                      const SizedBox(height: 18),
                      _tabs(),
                      const SizedBox(height: 14),
                      if (_tab != 0) ...[
                        _searchField(),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),
              ..._content(sums, hp, inner),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          );
        },
      ),
    );
  }

  Widget _message(IconData icon, String title, String sub,
      {bool retry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: _C.tint(_C.brand, 0.07), shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: _C.brand),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: _t(15, w: FontWeight.w600, c: _C.ink)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(sub,
                  textAlign: TextAlign.center, style: _t(13, c: _C.muted)),
            ),
            if (retry) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.line),
          boxShadow: [
            BoxShadow(
              color: _C.tint(_C.brand, 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _C.tint(color, 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: _t(11, w: FontWeight.w600, c: color)),
      );

  // ─── Period bar, KPIs, tabs, search ─────────────────────────────────────────
  Widget _chip(String label, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _C.brand : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _C.brand : _C.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : _C.muted),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: _t(12.5,
                      w: FontWeight.w600,
                      c: selected ? Colors.white : _C.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodBar() {
    const items = [
      ['all', 'All time'],
      ['month', 'This month'],
      ['last', 'Last month'],
      ['year', 'This year'],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final it in items)
                _chip(it[1], _period == it[0],
                    () => setState(() => _period = it[0])),
              _chip(
                  _period == 'custom' && _range != null
                      ? _periodLabel
                      : 'Custom range',
                  _period == 'custom',
                  _pickRange,
                  icon: Icons.date_range_outlined),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Showing $_periodLabel  -  ${_all.length} journal entries in total',
            style: _t(12, c: _C.muted)),
      ],
    );
  }

  Widget _kpis(Map<String, _Sum> s) {
    double bal(String code) => _nat(_coaByCode[code]!, s[code]!.net);
    double flow(String code) {
      final x = s[code]!;
      return _coaByCode[code]!.debitNormal ? x.dr - x.cr : x.cr - x.dr;
    }

    final income = flow('4000') + flow('4100') + flow('4200');
    final expense = flow('5000');
    final surplus = income - expense;

    final items = <List<dynamic>>[
      ['Cash and mobile money', bal('1000') + bal('1010'),
        Icons.payments_outlined, _C.ink],
      ['Loans receivable', bal('1100'), Icons.account_balance_outlined, _C.ink],
      ['Member savings', bal('2000'), Icons.savings_outlined, _C.ink],
      ['Income', income, Icons.trending_up, _C.green],
      ['Expenses', expense, Icons.trending_down, _C.red],
      ['Net surplus', surplus, Icons.insights_outlined,
        surplus >= 0 ? _C.green : _C.red],
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1200 ? 6 : (c.maxWidth >= 700 ? 3 : 2);
      const gap = 12.0;
      final cw = (c.maxWidth - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final it in items)
            SizedBox(
              width: cw,
              child: _card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _C.tint(_C.brand, 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(it[2] as IconData,
                                size: 16, color: _C.brand),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(it[0] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _t(12, c: _C.muted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                              text: 'UGX ',
                              style: _num(11,
                                  w: FontWeight.w500, c: _C.muted)),
                          TextSpan(
                              text: _b(it[1] as double),
                              style: _num(18,
                                  w: FontWeight.w700, c: it[3] as Color)),
                        ])),
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

  Widget _tabs() {
    const names = ['Trial balance', 'Account ledger', 'Journal'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < names.length; i++)
              InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? _C.brand : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(names[i],
                      style: _t(13.5,
                          w: FontWeight.w600,
                          c: _tab == i ? _C.brand : _C.muted)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = v),
          style: _t(13.5, c: _C.ink),
          decoration: InputDecoration(
            hintText: 'Search narration or reference',
            hintStyle: _t(13.5, c: const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search, size: 20, color: _C.muted),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _q = '');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.brand, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tab content ────────────────────────────────────────────────────────────
  List<Widget> _content(Map<String, _Sum> s, double hp, double width) {
    final pad = EdgeInsets.symmetric(horizontal: hp);

    if (_tab == 0) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: _trialBalance(s, width)),
        ),
      ];
    }

    if (_tab == 1) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: _ledgerView(s, width)),
        ),
      ];
    }

    final q = _q.trim().toLowerCase();
    final list = _all.reversed
        .where((e) => _inPeriod(e.date))
        .where((e) =>
            q.isEmpty ||
            e.narration.toLowerCase().contains(q) ||
            e.ref.toLowerCase().contains(q) ||
            e.source.toLowerCase().contains(q))
        .toList();

    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _message(Icons.menu_book_outlined, 'No journal entries',
              'Nothing was posted in this period.'),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: pad,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _journalCard(list[i]),
            childCount: list.length,
          ),
        ),
      ),
    ];
  }

  // ─── Trial balance ──────────────────────────────────────────────────────────
  Widget _tc(String text, int flex,
      {bool right = false,
      bool bold = false,
      bool mono = true,
      Color? color,
      TextStyle? style}) {
    final st = style ??
        (mono
            ? _num(12.5,
                w: bold ? FontWeight.w700 : FontWeight.w500, c: color ?? _C.ink)
            : _t(12.5,
                w: bold ? FontWeight.w700 : FontWeight.w500,
                c: color ?? _C.ink));
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: right ? TextAlign.right : TextAlign.left,
            style: st),
      ),
    );
  }

  Widget _hc(String text, int flex, {bool right = false}) => _tc(text, flex,
      right: right,
      style: _t(11.5, w: FontWeight.w600, c: _C.muted));

  Widget _balancedChip(bool ok, double diff) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _C.tint(ok ? _C.green : _C.red, 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 15, color: ok ? _C.green : _C.red),
            const SizedBox(width: 6),
            Text(
                ok
                    ? 'Debits equal credits'
                    : 'Out of balance by UGX ${_b(diff.abs())}',
                style: _t(12, w: FontWeight.w600, c: ok ? _C.green : _C.red)),
          ],
        ),
      );

  Widget _trialBalance(Map<String, _Sum> s, double width) {
    final rows = _tbList(s);
    final t = _tbTotals(rows);
    final balanced = (t[2] - t[3]).abs() < 1;
    final wide = width >= 820;

    void open(_Acct a) => setState(() {
          _acct = a.code;
          _tab = 1;
        });

    if (wide) {
      return _card(
        child: Column(
          children: [
            Container(
              color: _C.soft,
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                _hc('Code', 1),
                _hc('Account', 3),
                _hc('Type', 2),
                _hc('Opening', 2, right: true),
                _hc('Debits', 2, right: true),
                _hc('Credits', 2, right: true),
                _hc('Closing Dr', 2, right: true),
                _hc('Closing Cr', 2, right: true),
              ]),
            ),
            for (final r in rows)
              InkWell(
                onTap: () => open(r.a),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _C.hair)),
                  ),
                  child: Row(children: [
                    _tc(r.a.code, 1, color: _C.muted),
                    _tc(r.a.name, 3, mono: false, bold: true),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _tag(r.a.type, _typeColor(r.a.type)),
                        ),
                      ),
                    ),
                    _tc(_m(_nat(r.a, r.open)), 2, right: true, color: _C.muted),
                    _tc(_m(r.dr), 2, right: true),
                    _tc(_m(r.cr), 2, right: true),
                    _tc(r.net >= 0.5 ? _b(r.net) : '-', 2,
                        right: true, bold: true),
                    _tc(r.net <= -0.5 ? _b(-r.net) : '-', 2,
                        right: true, bold: true),
                  ]),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: const BoxDecoration(
                color: _C.soft,
                border: Border(top: BorderSide(color: _C.line)),
              ),
              child: Row(children: [
                _tc('', 1),
                _tc('Total', 3, mono: false, bold: true),
                _tc('', 2),
                _tc('', 2),
                _tc(_b(t[0]), 2, right: true, bold: true),
                _tc(_b(t[1]), 2, right: true, bold: true),
                _tc(_b(t[2]), 2, right: true, bold: true),
                _tc(_b(t[3]), 2, right: true, bold: true),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                _balancedChip(balanced, t[2] - t[3]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Tap an account to open its ledger.',
                      style: _t(12, c: _C.muted)),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        children: [
          for (final r in rows)
            InkWell(
              onTap: () => open(r.a),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _C.hair)),
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
                              Text(r.a.name,
                                  style: _t(14, w: FontWeight.w600, c: _C.ink)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text(r.a.code, style: _num(12, c: _C.muted)),
                                const SizedBox(width: 8),
                                _tag(r.a.type, _typeColor(r.a.type)),
                              ]),
                            ],
                          ),
                        ),
                        Text(
                          '${_b(r.net.abs())} ${r.net >= 0.5 ? 'Dr' : (r.net <= -0.5 ? 'Cr' : '')}'
                              .trim(),
                          style: _num(15, w: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Debits ${_m(r.dr)}    Credits ${_m(r.cr)}',
                        style: _num(11.5, c: _C.muted)),
                  ],
                ),
              ),
            ),
          Container(
            color: _C.soft,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(children: [
                  Text('Total debits', style: _t(13, c: _C.muted)),
                  const Spacer(),
                  Text(_b(t[2]), style: _num(14, w: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Text('Total credits', style: _t(13, c: _C.muted)),
                  const Spacer(),
                  Text(_b(t[3]), style: _num(14, w: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _balancedChip(balanced, t[2] - t[3]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Account ledger ─────────────────────────────────────────────────────────
  Widget _ledgerView(Map<String, _Sum> s, double width) {
    final a = _coaByCode[_acct]!;
    final sm = s[_acct]!;
    final q = _q.trim().toLowerCase();

    var rows = sm.rows
        .where((r) =>
            q.isEmpty ||
            r.e.narration.toLowerCase().contains(q) ||
            r.e.ref.toLowerCase().contains(q))
        .toList();

    final hidden = math.max(0, rows.length - 600);
    if (hidden > 0) rows = rows.sublist(hidden);

    final wide = width >= 760;

    final picker = SizedBox(
      width: 320,
      child: DropdownButtonFormField<String>(
        value: _acct,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Account',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: [
          for (final x in _coa)
            DropdownMenuItem(
              value: x.code,
              child: Text('${x.code}  ${x.name}', style: _t(13.5, c: _C.ink)),
            ),
        ],
        onChanged: (v) => setState(() => _acct = v ?? _acct),
      ),
    );

    final head = Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 20,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          picker,
          _tag(a.type, _typeColor(a.type)),
          Text('Normal balance: ${a.debitNormal ? 'Debit' : 'Credit'}',
              style: _t(12.5, c: _C.muted)),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Closing balance  ', style: _t(12.5, c: _C.muted)),
            TextSpan(
                text: 'UGX ${_b(_nat(a, sm.net))}',
                style: _num(14, w: FontWeight.w700)),
          ])),
        ],
      ),
    );

    final body = <Widget>[];

    if (wide) {
      body.add(Container(
        color: _C.soft,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          _hc('Date', 2),
          _hc('Reference', 2),
          _hc('Narration', 6),
          _hc('Debit', 2, right: true),
          _hc('Credit', 2, right: true),
          _hc('Balance', 3, right: true),
        ]),
      ));

      body.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _C.hair)),
        ),
        child: Row(children: [
          _tc('', 2),
          _tc('', 2),
          _tc('Opening balance', 6, mono: false, color: _C.muted),
          _tc('', 2),
          _tc('', 2),
          _tc(_b(_nat(a, sm.open)), 3, right: true, bold: true),
        ]),
      ));

      for (final r in rows) {
        body.add(Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _C.hair)),
          ),
          child: Row(children: [
            _tc(_d(r.e.date), 2, mono: false),
            _tc(r.e.ref, 2, color: _C.brand),
            _tc(r.e.narration, 6, mono: false),
            _tc(_m(r.dr), 2, right: true),
            _tc(_m(r.cr), 2, right: true),
            _tc(_b(_nat(a, r.bal)), 3, right: true, bold: true),
          ]),
        ));
      }

      body.add(Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          color: _C.soft,
          border: Border(top: BorderSide(color: _C.line)),
        ),
        child: Row(children: [
          _tc('', 2),
          _tc('', 2),
          _tc('Closing balance', 6, mono: false, bold: true),
          _tc(_b(sm.dr), 2, right: true, bold: true),
          _tc(_b(sm.cr), 2, right: true, bold: true),
          _tc(_b(_nat(a, sm.net)), 3, right: true, bold: true),
        ]),
      ));
    } else {
      body.add(Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: _C.soft,
        child: Row(children: [
          Text('Opening balance', style: _t(13, c: _C.muted)),
          const Spacer(),
          Text(_b(_nat(a, sm.open)), style: _num(14, w: FontWeight.w700)),
        ]),
      ));

      for (final r in rows) {
        final isDr = r.dr > 0;
        body.add(Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _C.hair)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.e.narration,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _t(13.5, w: FontWeight.w600, c: _C.ink)),
                    const SizedBox(height: 3),
                    Text('${_d(r.e.date)}  -  ${r.e.ref}',
                        style: _t(11.5, c: _C.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isDr ? 'Dr' : 'Cr'} ${_b(isDr ? r.dr : r.cr)}',
                      style: _num(14, w: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('Bal ${_b(_nat(a, r.bal))}',
                      style: _num(11.5, c: _C.muted)),
                ],
              ),
            ],
          ),
        ));
      }

      body.add(Container(
        padding: const EdgeInsets.all(16),
        color: _C.soft,
        child: Row(children: [
          Text('Closing balance',
              style: _t(13, w: FontWeight.w600, c: _C.ink)),
          const Spacer(),
          Text(_b(_nat(a, sm.net)), style: _num(15, w: FontWeight.w700)),
        ]),
      ));
    }

    if (rows.isEmpty) {
      body.insert(
        wide ? 2 : 1,
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('No transactions on this account in this period',
                style: _t(13, c: _C.muted)),
          ),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const Divider(height: 1, color: _C.line),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  'Showing the latest 600 lines. $hidden earlier lines are included in the balances.',
                  style: _t(12, c: _C.amber)),
            ),
          ...body,
        ],
      ),
    );
  }

  // ─── Journal ────────────────────────────────────────────────────────────────
  Widget _journalCard(_JEntry e) {
    Widget amt(String text, {bool bold = false}) => SizedBox(
          width: 92,
          child: Text(text,
              textAlign: TextAlign.right,
              style: _num(12.5, w: bold ? FontWeight.w700 : FontWeight.w500)),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Text(e.ref,
                      style: _num(13, w: FontWeight.w700, c: _C.brand)),
                  const SizedBox(width: 10),
                  _tag(e.source, _C.blue),
                  const Spacer(),
                  Text(_d(e.date), style: _t(12, c: _C.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Text(e.narration,
                  style: _t(14, w: FontWeight.w600, c: _C.ink)),
            ),
            Container(
              color: _C.soft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(child: Text('Account', style: _t(11.5, c: _C.muted))),
                SizedBox(
                  width: 92,
                  child: Text('Debit',
                      textAlign: TextAlign.right,
                      style: _t(11.5, c: _C.muted)),
                ),
                SizedBox(
                  width: 92,
                  child: Text('Credit',
                      textAlign: TextAlign.right,
                      style: _t(11.5, c: _C.muted)),
                ),
              ]),
            ),
            for (final l in e.lines)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: Row(children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: l.cr > 0 ? 18 : 0),
                      child: Text(
                          '${l.code}  ${_coaByCode[l.code]?.name ?? l.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(13, c: _C.ink)),
                    ),
                  ),
                  amt(l.dr > 0 ? _b(l.dr) : ''),
                  amt(l.cr > 0 ? _b(l.cr) : ''),
                ]),
              ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _C.hair)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(children: [
                Expanded(
                    child: Text('Total',
                        style: _t(12.5, w: FontWeight.w600, c: _C.muted))),
                amt(_b(e.total), bold: true),
                amt(_b(e.total), bold: true),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRINT (PDF) - prints whichever tab is open
  // ═══════════════════════════════════════════════════════════════════════════
  static final _pBrand = PdfColor.fromInt(0xFF1E3A8A);
  static final _pLine = PdfColor.fromInt(0xFFE2E8F0);
  static final _pSoft = PdfColor.fromInt(0xFFF4F6FA);
  static final _pMuted = PdfColor.fromInt(0xFF64748B);
  static final _pInk = PdfColor.fromInt(0xFF0F172A);

  Future<void> _print() async {
    try {
      final s = _compute();
      final R = pw.Alignment.centerRight;
      final L = pw.Alignment.centerLeft;
      late String title;
      String? sub;
      late List<String> headers;
      late List<List<String>> data;
      late Map<int, pw.Alignment> aligns;

      if (_tab == 0) {
        final rows = _tbList(s);
        final t = _tbTotals(rows);
        title = 'Trial balance';
        headers = [
          'Code', 'Account', 'Type', 'Opening', 'Debits', 'Credits',
          'Closing Dr', 'Closing Cr'
        ];
        data = [
          for (final r in rows)
            [
              r.a.code,
              r.a.name,
              r.a.type,
              _m(_nat(r.a, r.open)),
              _m(r.dr),
              _m(r.cr),
              r.net >= 0.5 ? _b(r.net) : '-',
              r.net <= -0.5 ? _b(-r.net) : '-',
            ],
          ['', 'TOTAL', '', '', _b(t[0]), _b(t[1]), _b(t[2]), _b(t[3])],
        ];
        aligns = {0: L, 1: L, 2: L, 3: R, 4: R, 5: R, 6: R, 7: R};
      } else if (_tab == 1) {
        final a = _coaByCode[_acct]!;
        final sm = s[_acct]!;
        title = 'Account ledger';
        sub = '${a.code} ${a.name}';
        headers = ['Date', 'Reference', 'Narration', 'Debit', 'Credit', 'Balance'];
        data = [
          ['', '', 'Opening balance', '', '', _b(_nat(a, sm.open))],
          for (final r in sm.rows)
            [
              _d(r.e.date),
              r.e.ref,
              r.e.narration,
              _m(r.dr),
              _m(r.cr),
              _b(_nat(a, r.bal)),
            ],
          ['', '', 'Closing balance', _b(sm.dr), _b(sm.cr), _b(_nat(a, sm.net))],
        ];
        aligns = {0: L, 1: L, 2: L, 3: R, 4: R, 5: R};
      } else {
        final list = _all.where((e) => _inPeriod(e.date)).toList();
        if (list.isEmpty) {
          _toast('No journal entries to print in this period', false);
          return;
        }
        title = 'Journal';
        headers = ['Date', 'Reference', 'Narration', 'Account', 'Debit', 'Credit'];
        data = [
          for (final e in list)
            for (var i = 0; i < e.lines.length; i++)
              [
                i == 0 ? _d(e.date) : '',
                i == 0 ? e.ref : '',
                i == 0 ? e.narration : '',
                '${e.lines[i].code} ${_coaByCode[e.lines[i].code]?.name ?? ''}',
                e.lines[i].dr > 0 ? _b(e.lines[i].dr) : '',
                e.lines[i].cr > 0 ? _b(e.lines[i].cr) : '',
              ],
        ];
        aligns = {0: L, 1: L, 2: L, 3: L, 4: R, 5: R};
      }

      final printed = DateFormat('d MMM yyyy, HH:mm').format(DateTime.now());
      final doc = pw.Document();

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _pMuted)),
        ),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MBADIFA SACCO',
                      style: pw.TextStyle(
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                          color: _pBrand)),
                  pw.SizedBox(height: 3),
                  pw.Text('General ledger - $title',
                      style: pw.TextStyle(fontSize: 12, color: _pMuted)),
                  if (sub != null)
                    pw.Text(sub,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _pInk)),
                  pw.Text('Period: $_periodLabel',
                      style: pw.TextStyle(fontSize: 9, color: _pMuted)),
                ],
              ),
              pw.Text('Printed $printed',
                  style: pw.TextStyle(fontSize: 9, color: _pMuted)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(height: 2, color: _pBrand),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _pLine, width: 0.5),
              bottom: pw.BorderSide(color: _pLine, width: 0.5),
            ),
            headerDecoration: pw.BoxDecoration(color: _pBrand),
            headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white),
            cellStyle: pw.TextStyle(fontSize: 9, color: _pInk),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration: pw.BoxDecoration(color: _pSoft),
            headerAlignments: aligns,
            cellAlignments: aligns,
          ),
          pw.SizedBox(height: 10),
          pw.Text('All amounts in UGX.',
              style: pw.TextStyle(fontSize: 8, color: _pMuted)),
        ],
      ));

      await Printing.layoutPdf(
        name: 'General_Ledger_$title'.replaceAll(' ', '_'),
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } catch (e) {
      debugPrint('Print general ledger failed: $e');
      _toast('Could not print: $e', false);
    }
  }
}

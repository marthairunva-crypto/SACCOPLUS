import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/firebase_service.dart';
import '../../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (match the other tabs in comprehensive_reports_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _Pal {
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
  static const band = Color(0xFFF1F5F9);
}

const _palette = [_Pal.blue, _Pal.teal, _Pal.purple, _Pal.amber, _Pal.green, _Pal.red];

TextStyle _ps(double size, {FontWeight w = FontWeight.w400, Color c = _Pal.text, double? ls}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);

TextStyle _mono(double size, {FontWeight w = FontWeight.w500, Color c = _Pal.text}) =>
    GoogleFonts.robotoMono(fontSize: size, fontWeight: w, color: c);

final NumberFormat _nf = NumberFormat('#,##0', 'en_US');

String _money(num v) => v == 0 ? '-' : (v < 0 ? '(${_nf.format(v.abs().round())})' : _nf.format(v.round()));
String _ugx(num v) => v < 0 ? '-UGX ${_nf.format(v.abs().round())}' : 'UGX ${_nf.format(v.round())}';

String _prettyLabel(String s) {
  final t = s.replaceAll('_', ' ').trim();
  if (t.isEmpty) return 'Other';
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

String _ordinal(int d) {
  if (d >= 11 && d <= 13) return 'th';
  switch (d % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

BoxDecoration _card() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _Pal.border),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _Line {
  final String label;
  final double amount;
  const _Line(this.label, this.amount);
}

class _Statement {
  final int year, month;
  final List<_Line> income;
  final List<_Line> expenses;
  const _Statement(this.year, this.month, this.income, this.expenses);

  double get totalIncome => income.fold(0.0, (s, l) => s + l.amount);
  double get totalExpenses => expenses.fold(0.0, (s, l) => s + l.amount);
  double get balance => totalIncome - totalExpenses;

  DateTime get asAt => DateTime(year, month + 1, 0);
  String get asAtLabel =>
      '${asAt.day}${_ordinal(asAt.day)} ${DateFormat('MMMM yyyy').format(asAt)}';
}

/// Income lines in the same order as the SACCO paper statement.
const _incomeLabels = <String, String>{
  'balBF': 'Balance b/f',
  'principle': 'Principle',
  'interest': 'Interest',
  'savings': 'Savings',
  'loanForms': 'Loan forms',
  'membership': 'Membership',
  'stationery': 'Stationery',
  'shares': 'Shares',
  'penalties': 'Penalties',
};

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class IncomeStatementSACCO extends StatefulWidget {
  const IncomeStatementSACCO({super.key});

  @override
  State<IncomeStatementSACCO> createState() => _IncomeStatementSACCOState();
}

class _IncomeStatementSACCOState extends State<IncomeStatementSACCO> {
  DateTime selectedDate = DateTime(DateTime.now().year, DateTime.now().month);
  bool isLoading = false;
  bool _hideZero = false;
  String? _error;
  _Statement? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data ───────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final data = await _fetch(selectedDate.year, selectedDate.month);
      if (!mounted) return;
      setState(() {
        _data = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Income statement load failed: $e');
      final s = e.toString();
      final i = s.indexOf('https://console.firebase');
      if (i != -1) {
        var end = s.indexOf(' ', i);
        if (end == -1) end = s.length;
        debugPrint('Firestore index required. Open: ${s.substring(i, end)}');
      }
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = s.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<_Statement> _fetch(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    final db = FirebaseFirestore.instance;
    final tenantId = FirebaseService.sessionTenantId;

    final income = <String, double>{for (final k in _incomeLabels.keys) k: 0.0};
    final expenses = <String, double>{};

    // ── 1. LOAN REPAYMENTS (PRINCIPAL + INTEREST) ──
    final repaymentsSnap = await db
        .collection(AppConstants.repaymentsCol)
        .where('tenantId', isEqualTo: tenantId)
        .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('paidAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    debugPrint('📊 Loaded ${repaymentsSnap.docs.length} repayments for $year-$month');
    for (final doc in repaymentsSnap.docs) {
      final data = doc.data();
      final principal = ((data['principalPaid'] ?? 0) as num).toDouble();
      final interest = ((data['interestPaid'] ?? 0) as num).toDouble();
      income['principal'] = (income['principal'] ?? 0) + principal;
      income['interest'] = (income['interest'] ?? 0) + interest;
    }

    // ── 2. SAVINGS DEPOSITS ──
    final savingsSnap = await db
        .collection(AppConstants.savingsTxnCol)
        .where('tenantId', isEqualTo: tenantId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('type', isEqualTo: 'deposit')
        .get();

    debugPrint('📊 Loaded ${savingsSnap.docs.length} savings deposits for $year-$month');
    for (final doc in savingsSnap.docs) {
      final amount = ((doc.data()['amount'] ?? 0) as num).toDouble();
      income['savings'] = (income['savings'] ?? 0) + amount;
    }

    // ── 3. SHARE PURCHASES ──
    final sharesSnap = await db
        .collection(AppConstants.sharesCol)
        .where('tenantId', isEqualTo: tenantId)
        .where('purchaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('purchaseDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    debugPrint('📊 Loaded ${sharesSnap.docs.length} share purchases for $year-$month');
    for (final doc in sharesSnap.docs) {
      final amount = ((doc.data()['totalAmount'] ?? 0) as num).toDouble();
      income['shares'] = (income['shares'] ?? 0) + amount;
    }

    // ── 4. TELLER TRANSACTIONS (for fees, penalties, etc.) ──
    final tellerSnap = await db
        .collection(AppConstants.tellerTxnCol)
        .where('tenantId', isEqualTo: tenantId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    debugPrint('📊 Loaded ${tellerSnap.docs.length} teller transactions for $year-$month');
    for (final doc in tellerSnap.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final source = (data['source'] ?? '').toString().toLowerCase();
      final amount = ((data['amount'] ?? 0) as num).toDouble();

      void add(String k) => income[k] = (income[k] ?? 0) + amount;

      if (type == 'income' || type == 'credit') {
        if (source.contains('loan application') ||
            source.contains('loan form') ||
            category.contains('loan forms')) {
          add('loanForms');
        } else if (source.contains('membership') || category.contains('membership')) {
          add('membership');
        } else if (source.contains('stationery') || category.contains('stationery')) {
          add('stationery');
        } else if (source.contains('penalty') ||
            source.contains('penalties') ||
            category.contains('penalty')) {
          add('penalties');
        } else if (type.contains('deposit') || category.contains('savings')) {
          add('savings');
        }
      } else if (type == 'expense' || type == 'debit') {
        final key = category.isNotEmpty ? category : 'other';
        expenses[key] = (expenses[key] ?? 0) + amount;
      }
    }

    // Opening balance: set to 0 for now. In production, fetch the previous
    // month's closing balance.
    income['balBF'] = 0.0;

    final loansSnapshot = await db
        .collection('saccoplus-loans')
        .where('tenantId', isEqualTo: tenantId)
        .where('disbursedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('disbursedDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('status', isEqualTo: 'Active')
        .get();

    var totalDisbursed = 0.0;
    for (final doc in loansSnapshot.docs) {
      totalDisbursed += ((doc.data()['amount'] ?? 0) as num).toDouble();
    }
    income['principle'] = totalDisbursed;

    final expenseLines = expenses.entries.map((e) => _Line(_prettyLabel(e.key), e.value)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return _Statement(
      year,
      month,
      [for (final e in _incomeLabels.entries) _Line(e.value, income[e.key] ?? 0)],
      expenseLines,
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _shiftMonth(int delta) {
    setState(() => selectedDate = DateTime(selectedDate.year, selectedDate.month + delta));
    _loadData();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      final next = DateTime(picked.year, picked.month);
      if (next != selectedDate) {
        setState(() => selectedDate = next);
        _loadData();
      }
    }
  }

  Future<void> _exportPDF() async {
    final d = _data;
    if (d == null) return;
    try {
      final pdf = pw.Document();

      pw.Widget row(String label, String amount, {bool bold = false, bool shaded = false}) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: shaded ? PdfColors.grey200 : null,
              border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
                pw.Text(amount,
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              ],
            ),
          );

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Center(
            child: pw.Column(children: [
              pw.Text('MBADIFA SACCO', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('INCOME STATEMENT AS AT ${d.asAtLabel.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('Amounts in UGX', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ]),
          ),
          pw.SizedBox(height: 18),
          row('INCOME', '', bold: true, shaded: true),
          ...d.income.map((l) => row(l.label, _money(l.amount))),
          row('Total income', _nf.format(d.totalIncome.round()), bold: true, shaded: true),
          pw.SizedBox(height: 12),
          row('EXPENDITURE', '', bold: true, shaded: true),
          if (d.expenses.isEmpty) row('No expenses recorded', '-'),
          ...d.expenses.map((l) => row(l.label, _money(l.amount))),
          row('Total expenditure', _nf.format(d.totalExpenses.round()), bold: true, shaded: true),
          pw.SizedBox(height: 12),
          row(d.balance >= 0 ? 'BALANCE C/D (surplus)' : 'BALANCE C/D (deficit)', _ugx(d.balance), bold: true, shaded: true),
          pw.SizedBox(height: 20),
          pw.Text('Generated ${DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ));

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat f) async => pdf.save(),
        name: 'income_statement_${d.year}_${d.month.toString().padLeft(2, '0')}.pdf',
      );
    } catch (e) {
      _showError('PDF export failed: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: _Pal.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Pal.bg,
      child: Column(
        children: [
          _toolbar(),
          if (isLoading) const LinearProgressIndicator(minHeight: 2, color: _Pal.blue, backgroundColor: _Pal.band),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final now = DateTime.now();
    final canNext = DateTime(selectedDate.year, selectedDate.month + 1)
        .isBefore(DateTime(now.year, now.month + 1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _Pal.border)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: _Pal.band,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _Pal.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _pickMonth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: _Pal.navy),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMMM yyyy').format(selectedDate),
                            style: _ps(13.5, w: FontWeight.w600, c: _Pal.navy)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: canNext ? () => _shiftMonth(1) : null,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _hideZero,
                    activeColor: _Pal.navy,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => setState(() => _hideZero = v),
                  ),
                  Text('Hide zero lines', style: _ps(12.5, c: _Pal.muted)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Refresh', style: _ps(12.5, w: FontWeight.w600, c: _Pal.navy)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _Pal.navy,
                  side: const BorderSide(color: _Pal.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _data == null ? null : _exportPDF,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text('Export PDF', style: _ps(12.5, w: FontWeight.w600, c: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Pal.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_data == null && isLoading) return const Center(child: CircularProgressIndicator());
    if (_data == null && _error != null) return _errorView();
    final d = _data;
    if (d == null) {
      return Center(child: Text('No data available', style: _ps(13, c: _Pal.muted)));
    }

    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final pad = w < 600 ? 12.0 : (w < 1024 ? 16.0 : 24.0);
      final wide = w >= 1100;

      final statement = _statementCard(d, compact: w < 700);
      final side = _sidePanel(d);

      return RefreshIndicator(
        onRefresh: _loadData,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1800),
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 32),
              children: [
                if (_error != null) _inlineError(),
                _kpis(d, w),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: statement),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: side),
                    ],
                  )
                else ...[
                  statement,
                  const SizedBox(height: 16),
                  side,
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────
  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: _Pal.red),
            const SizedBox(height: 12),
            Text('Could not load the income statement', style: _ps(17, w: FontWeight.w600)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(_error ?? '', textAlign: TextAlign.center, style: _ps(12.5, c: _Pal.muted)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(backgroundColor: _Pal.navy, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: _Pal.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Could not refresh. Showing the last loaded figures.',
                style: _ps(12.5, c: _Pal.red)),
          ),
          TextButton(onPressed: _loadData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _kpis(_Statement d, double w) {
    final ratio = d.totalIncome == 0 ? 0.0 : d.totalExpenses / d.totalIncome * 100;
    final surplus = d.balance >= 0;
    final cards = [
      _Kpi('Total income', _ugx(d.totalIncome), Icons.south_west_rounded, _Pal.green,
          sub: DateFormat('MMMM yyyy').format(selectedDate)),
      _Kpi('Total expenditure', _ugx(d.totalExpenses), Icons.north_east_rounded, _Pal.blue,
          sub: '${d.expenses.length} ${d.expenses.length == 1 ? 'category' : 'categories'}'),
      _Kpi(surplus ? 'Surplus' : 'Deficit', _ugx(d.balance), surplus ? Icons.trending_up : Icons.trending_down,
          surplus ? _Pal.green : _Pal.red,
          sub: 'Balance c/d'),
      _Kpi('Expenses vs income', '${ratio.toStringAsFixed(1)}%', Icons.percent_rounded, _Pal.purple,
          sub: d.totalIncome == 0 ? 'No income recorded' : 'Share of income spent'),
    ];
    final cols = w >= 1000 ? 4 : (w >= 560 ? 2 : 1);
    const gap = 12.0;
    final itemW = (w - (w < 600 ? 24 : (w < 1024 ? 32 : 48)) - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final c in cards) SizedBox(width: itemW.clamp(160, 1000).toDouble(), child: c)],
    );
  }

  Widget _statementCard(_Statement d, {required bool compact}) {
    final incomeShown = _hideZero ? d.income.where((l) => l.amount != 0).toList() : d.income;
    final expenseShown = _hideZero ? d.expenses.where((l) => l.amount != 0).toList() : d.expenses;
    final surplus = d.balance >= 0;

    return Container(
      decoration: _card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            color: _Pal.navy,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Text('MBADIFA SACCO', style: _ps(18, w: FontWeight.w700, c: Colors.white, ls: 1.2)),
                const SizedBox(height: 4),
                Text('Income statement as at ${d.asAtLabel}',
                    textAlign: TextAlign.center, style: _ps(12, c: Colors.white70)),
                const SizedBox(height: 2),
                Text('Amounts in UGX', style: _ps(11, c: Colors.white54)),
              ],
            ),
          ),

          _sectionHeader('Income', d.totalIncome),
          if (incomeShown.isEmpty)
            _note('All income lines are zero for this month.')
          else
            for (var i = 0; i < incomeShown.length; i++)
              _lineRow(incomeShown[i], d.totalIncome, i, _Pal.green, compact),
          _totalRow('Total income', d.totalIncome),

          const SizedBox(height: 8),
          _sectionHeader('Expenditure', d.totalExpenses),
          if (d.expenses.isEmpty)
            _note('No expenses were recorded for ${DateFormat('MMMM yyyy').format(selectedDate)}.')
          else if (expenseShown.isEmpty)
            _note('All expenditure lines are zero for this month.')
          else
            for (var i = 0; i < expenseShown.length; i++)
              _lineRow(expenseShown[i], d.totalExpenses, i, _Pal.blue, compact),
          _totalRow('Total expenditure', d.totalExpenses),

          // Net result
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: (surplus ? _Pal.green : _Pal.red).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (surplus ? _Pal.green : _Pal.red).withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(surplus ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    color: surplus ? _Pal.green : _Pal.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance c/d', style: _ps(15, w: FontWeight.w700, c: _Pal.navy)),
                      Text(surplus ? 'Surplus for the period' : 'Deficit for the period',
                          style: _ps(11.5, c: _Pal.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(_ugx(d.balance),
                    style: _mono(18, w: FontWeight.w700, c: surplus ? _Pal.green : _Pal.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, double total) {
    return Container(
      color: _Pal.band,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
      child: Text(title, style: _ps(13.5, w: FontWeight.w700, c: _Pal.navy)),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: _Pal.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _ps(12.5, c: _Pal.muted))),
        ],
      ),
    );
  }

  Widget _lineRow(_Line l, double total, int i, Color color, bool compact) {
    final isZero = l.amount == 0;
    final pct = total == 0 ? 0.0 : (l.amount / total).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24, vertical: 11),
      decoration: BoxDecoration(
        color: i.isOdd ? const Color(0xFFFAFBFC) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F3F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(l.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ps(13.5, w: FontWeight.w500, c: isZero ? _Pal.muted : _Pal.text)),
          ),
          if (!compact) ...[
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(isZero ? Colors.transparent : color),
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(isZero ? '' : '${(pct * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right, style: _ps(11.5, c: _Pal.muted)),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: compact ? 110 : 130,
            child: Text(_money(l.amount),
                textAlign: TextAlign.right, style: _mono(13, c: isZero ? _Pal.muted : _Pal.text)),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: _Pal.navy.withOpacity(0.05),
        border: const Border(top: BorderSide(color: _Pal.navy, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _ps(14, w: FontWeight.w700, c: _Pal.navy)),
          Text('UGX ${_nf.format(total.round())}', style: _mono(15, w: FontWeight.w700, c: _Pal.navy)),
        ],
      ),
    );
  }

  Widget _sidePanel(_Statement d) {
    final inc = d.income.where((l) => l.amount > 0).toList()..sort((a, b) => b.amount.compareTo(a.amount));
    final exp = d.expenses.where((l) => l.amount > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BarsCard(
          title: 'Income mix',
          subtitle: 'Share of total income',
          items: [for (var i = 0; i < inc.length; i++) _Bar(inc[i].label, inc[i].amount, _palette[i % _palette.length])],
          empty: 'No income recorded yet.',
        ),
        const SizedBox(height: 16),
        _BarsCard(
          title: 'Where the money went',
          subtitle: 'Share of total expenditure',
          items: [for (var i = 0; i < exp.length; i++) _Bar(exp[i].label, exp[i].amount, _palette[i % _palette.length])],
          empty: 'No expenses recorded for this month.',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Kpi extends StatelessWidget {
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color, {this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
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
                Text(label, style: _ps(11.5, w: FontWeight.w500, c: _Pal.muted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: _ps(18, w: FontWeight.w700, c: _Pal.navy)),
                ),
                if (sub != null)
                  Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: _ps(11, c: _Pal.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar {
  final String label;
  final double value;
  final Color color;
  const _Bar(this.label, this.value, this.color);
}

class _BarsCard extends StatelessWidget {
  final String title, subtitle, empty;
  final List<_Bar> items;
  const _BarsCard({required this.title, required this.subtitle, required this.items, required this.empty});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, i) => s + i.value);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _ps(15, w: FontWeight.w600, c: _Pal.navy)),
          Text(subtitle, style: _ps(11.5, c: _Pal.muted)),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(empty, style: _ps(12.5, c: _Pal.muted))
          else
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        Text(_nf.format(i.value.round()), style: _mono(12, w: FontWeight.w600)),
                        SizedBox(
                          width: 52,
                          child: Text('${(i.value / total * 100).toStringAsFixed(1)}%',
                              textAlign: TextAlign.right, style: _ps(11.5, c: _Pal.muted)),
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
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
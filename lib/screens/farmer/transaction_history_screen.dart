import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import 'farmer_scaffold.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

enum _TxnCategory { wallet, airtime, all }

class _Txn {
  final String id;
  final String type;
  final int amount;
  final String status;
  final String description;
  final String phone;
  final String network;
  final DateTime? date;
  final String category;
  final int? _runningBalance;
  // Multi-country fields — defaults to UG/UGX for legacy records
  final String country;
  final String currency;
  int get runningBalance => _runningBalance ?? 0;

  const _Txn({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.description,
    required this.phone,
    required this.network,
    this.date,
    required this.category,
    int runningBalance = 0,
    this.country = 'UG',
    this.currency = 'UGX',
  }) : _runningBalance = runningBalance;

  bool get isCredit => type == 'deposit';
  bool get isDebit  => !isCredit;

  _Txn withBalance(int bal) => _Txn(
    id: id, type: type, amount: amount, status: status,
    description: description, phone: phone, network: network,
    date: date, category: category, runningBalance: bal,
    country: country, currency: currency,
  );

  static _Txn fromWallet(Map<String, dynamic> d) {
    final ts = d['createdAt'] ?? d['timestamp'];
    final type = d['type'] as String? ?? 'debit';
    final desc = d['description'] as String?
        ?? (type == 'deposit' ? 'Wallet Deposit' : 'Wallet Withdrawal');
    return _Txn(
      id: d['id'] as String? ?? '',
      type: type,
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? 'completed',
      description: desc,
      phone: d['phone'] as String? ?? '',
      network: d['provider'] as String? ?? '',
      date: ts is Timestamp ? ts.toDate() : null,
      category: 'wallet',
      runningBalance: 0,
      country: d['country'] as String? ?? 'UG',
      currency: d['currency'] as String? ?? 'UGX',
    );
  }

  static _Txn fromAirtime(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    final isBundle = d['purchaseType'] == 'bundle';
    final network = d['network'] as String? ?? '';
    final product = d['productName'] as String? ?? '';
    final desc = isBundle
        ? '$network Bundle${product.isNotEmpty ? ' — $product' : ''}'
        : '$network Airtime';
    return _Txn(
      id: d['id'] as String? ?? '',
      type: isBundle ? 'bundle' : 'airtime',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      status: d['status'] as String? ?? 'completed',
      description: desc,
      phone: d['phoneNumber'] as String? ?? '',
      network: network,
      date: ts is Timestamp ? ts.toDate() : null,
      category: 'airtime',
      runningBalance: 0,
      // Airtime is Uganda-only currently
      country: 'UG',
      currency: 'UGX',
    );
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});
  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _fmt    = NumberFormat('#,###', 'en_US');
  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');

  List<_Txn> _all = [];
  bool _loading = true;
  bool _exporting = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _wallet;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tab.dispose(); _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = FirebaseService.sessionUid;
    try {
      final results = await Future.wait([
        FirebaseService.getUserProfile(uid),
        FirebaseService.getWallet(uid),
        FirebaseService.getWalletTransactions(uid),
        FirebaseService.getAirtimeTransactions(uid),
      ]);
      final walletTxns  = (results[2] as List<Map<String, dynamic>>)
          .map(_Txn.fromWallet).toList();
      final airtimeTxns = (results[3] as List<Map<String, dynamic>>)
          .map(_Txn.fromAirtime).toList();
      final merged = [...walletTxns, ...airtimeTxns]
        ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));

      // Compute running balance — start from current balance and work backwards
      final currentBalance = ((results[1] as Map<String, dynamic>)['balance'] as num?)?.toInt() ?? 0;
      int bal = currentBalance;
      final withBalances = merged.map((t) {
        final b = bal;
        bal = t.isCredit ? bal - t.amount : bal + t.amount;
        return t.withBalance(b);
      }).toList();
      if (mounted) setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _wallet  = results[1] as Map<String, dynamic>;
        _all     = withBalances;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Txn> _filtered(_TxnCategory cat) {
    var list = _all.where((t) {
      if (cat == _TxnCategory.wallet)  return t.category == 'wallet';
      if (cat == _TxnCategory.airtime) return t.category == 'airtime';
      return true;
    }).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) =>
        t.description.toLowerCase().contains(q) ||
        t.phone.contains(q) ||
        t.network.toLowerCase().contains(q) ||
        t.status.toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  int _totalCredits(List<_Txn> list) =>
      list.where((t) => t.isCredit).fold(0, (s, t) => s + t.amount);
  int _totalDebits(List<_Txn> list) =>
      list.where((t) => t.isDebit).fold(0, (s, t) => s + t.amount);

  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'Transaction History',
      showBack: true,
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load,
            tooltip: 'Refresh'),
        IconButton(
          icon: _exporting
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded),
          tooltip: 'Export Statement',
          onPressed: _exporting ? null : _exportPdf,
        ),
      ],
      bottom: TabBar(
        controller: _tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: AppTheme.accent,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Wallet'),
          Tab(text: 'Airtime'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _TxnList(txns: _filtered(_TxnCategory.all),    fmt: _fmt, dateFmt: _dateFmt, onSummary: _showSummary),
                    _TxnList(txns: _filtered(_TxnCategory.wallet),  fmt: _fmt, dateFmt: _dateFmt, onSummary: _showSummary),
                    _TxnList(txns: _filtered(_TxnCategory.airtime), fmt: _fmt, dateFmt: _dateFmt, onSummary: _showSummary),
                  ],
                ),
              ),
            ]),
    );
  }

  void _showSummary(_Txn t) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            _TxnIcon(t),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.description,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(t.date != null ? _dateFmt.format(t.date!) : '—',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),
          Center(child: Text(
            '${t.isCredit ? '+' : '-'} ${t.currency} ${_fmt.format(t.amount)}',
            style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800,
                color: t.isCredit ? AppTheme.success : AppTheme.error),
          )),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _detailRow('Category', t.category == 'wallet' ? 'Wallet' : 'Airtime & Data'),
          _detailRow('Type', t.type),
          _detailRow('Status', t.status.toUpperCase()),
          if (t.country.isNotEmpty && t.country != 'UG')
            _detailRow('Country', t.country),
          if (t.currency.isNotEmpty)
            _detailRow('Currency', t.currency),
          if (t.phone.isNotEmpty) _detailRow('Phone', t.phone),
          if (t.network.isNotEmpty) _detailRow('Network', t.network.toUpperCase()),
          _detailRow('Balance After', '${t.currency} ${_fmt.format(t.runningBalance)}'),
          _detailRow('Transaction ID', t.id, small: true),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool small = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label,
          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary))),
      Expanded(child: Text(value,
          style: GoogleFonts.poppins(
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
    ]),
  );

  // ─── PDF Export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final bytes = await _buildPdf();
      final filename =
          'SACCOPLUS_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

      if (kIsWeb) {
        // On web: open in browser's built-in PDF viewer / download dialog
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: filename,
        );
      } else {
        // On mobile: system share sheet (save to Files, WhatsApp, email…)
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _buildPdf() async {
    final doc = pw.Document();
    final name      = _profile?['name'] as String? ?? 'SACCO Member';
    final phone     = _profile?['phone'] as String? ?? '';
    final membNo    = _profile?['memberNumber'] as String? ?? '';
    final balance   = (_wallet?['balance']      as num?)?.toInt() ?? 0;
    final deposited = (_wallet?['totalDeposited'] as num?)?.toInt() ?? 0;
    final withdrawn = (_wallet?['totalWithdrawn'] as num?)?.toInt() ?? 0;
    final imgUrl    = _profile?['profileImage'] as String? ?? '';
    final txns      = _filtered(_TxnCategory.all);
    final generated = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

    // ── Load Unicode-capable fonts (Roboto via Google Fonts) ───────────────
    // On web or if font download fails, fall back to basic built-in fonts
    pw.Font? robotoRegular;
    pw.Font? robotoBold;
    pw.Font? robotoLight;
    try {
      robotoRegular = await PdfGoogleFonts.robotoRegular();
      robotoBold    = await PdfGoogleFonts.robotoBold();
      robotoLight   = await PdfGoogleFonts.robotoLight();
    } catch (e) {
      print('Warning: Could not load PdfGoogleFonts: $e. Using default fonts.');
      // Leave as null — we'll use built-in fonts
    }

    // ── Try to load profile image ──────────────────────────────────────────
    pw.ImageProvider? avatarImg;
    if (imgUrl.isNotEmpty) {
      try { avatarImg = await networkImage(imgUrl); } catch (_) {}
    }

    // ── Try to load app logo ───────────────────────────────────────────────
    pw.ImageProvider? logoImg;
    try {
      final logoData = await rootBundle.load(AppConstants.logoPath);
      logoImg = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final navy   = PdfColor.fromHex('#0D2B6B');
    final orange = PdfColor.fromHex('#F47920');
    final green  = PdfColor.fromHex('#22C55E');
    final red    = PdfColor.fromHex('#EF4444');
    final grey   = PdfColor.fromHex('#6B7A99');
    final light  = PdfColor.fromHex('#F4F6FA');

    final fonts = _PdfFonts(
      regular: robotoRegular ?? pw.Font.helvetica(),
      bold:    robotoBold    ?? pw.Font.helveticaBold(),
      light:   robotoLight   ?? pw.Font.helvetica(),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(
        base: robotoRegular ?? pw.Font.helvetica(),
        bold: robotoBold    ?? pw.Font.helveticaBold(),
      ),
      header: (ctx) => _pdfHeader(ctx, logoImg, name, phone, membNo,
          avatarImg, generated, navy, orange, fonts),
      footer: (ctx) => _pdfFooter(ctx, grey, fonts),
      build: (ctx) => [
        _pdfSummaryCards(balance, deposited, withdrawn, navy, orange, green, red, light, fonts),
        pw.SizedBox(height: 20),
        _pdfTxnTable(txns, navy, orange, green, red, light, grey, fonts),
      ],
    ));

    return doc.save();
  }

  pw.Widget _pdfHeader(
    pw.Context ctx,
    pw.ImageProvider? logo,
    String name,
    String phone,
    String membNo,
    pw.ImageProvider? avatar,
    String generated,
    PdfColor navy,
    PdfColor orange,
    _PdfFonts fonts,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: navy,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo
          if (logo != null)
            pw.Container(width: 48, height: 48,
                decoration: pw.BoxDecoration(color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                child: pw.Image(logo, fit: pw.BoxFit.contain))
          else
            pw.Container(width: 48, height: 48,
                decoration: pw.BoxDecoration(color: orange,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                child: pw.Center(child: pw.Text('S',
                    style: pw.TextStyle(font: fonts.bold, color: PdfColors.white,
                        fontSize: 24)))),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SACCOPLUS Pro',
                  style: pw.TextStyle(font: fonts.bold, color: PdfColors.white, fontSize: 18)),
              pw.Text('Account Statement',
                  style: pw.TextStyle(font: fonts.regular, color: PdfColor.fromHex('#FFFFFF99'), fontSize: 11)),
              pw.SizedBox(height: 6),
              pw.Text('Generated: $generated',
                  style: pw.TextStyle(font: fonts.light, color: PdfColor.fromHex('#FFFFFF80'), fontSize: 9)),
            ],
          )),
          pw.SizedBox(width: 14),
          // Member info
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            if (avatar != null)
              pw.Container(width: 44, height: 44,
                  decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: orange, width: 2)),
                  child: pw.ClipOval(child: pw.Image(avatar, fit: pw.BoxFit.cover))),
            pw.SizedBox(height: 4),
            pw.Text(name,
                style: pw.TextStyle(font: fonts.bold, color: PdfColors.white, fontSize: 12)),
            if (phone.isNotEmpty)
              pw.Text(phone,
                  style: pw.TextStyle(font: fonts.regular, color: PdfColor.fromHex('#FFFFFF99'), fontSize: 10)),
            if (membNo.isNotEmpty)
              pw.Text('Member No: $membNo',
                  style: pw.TextStyle(font: fonts.regular, color: orange, fontSize: 9)),
          ]),
        ],
      ),
    );
  }

  pw.Widget _pdfSummaryCards(
    int balance, int deposited, int withdrawn,
    PdfColor navy, PdfColor orange, PdfColor green, PdfColor red, PdfColor light,
    _PdfFonts fonts,
  ) {
    final f = NumberFormat('#,###', 'en_US');
    return pw.Row(children: [
      _pdfCard('Wallet Balance',  'UGX ${f.format(balance)}',   navy,  light, fonts),
      pw.SizedBox(width: 8),
      _pdfCard('Total Deposited', 'UGX ${f.format(deposited)}', green, light, fonts),
      pw.SizedBox(width: 8),
      _pdfCard('Total Withdrawn', 'UGX ${f.format(withdrawn)}', red,   light, fonts),
    ]);
  }

  pw.Widget _pdfCard(String label, String value, PdfColor color, PdfColor light, _PdfFonts fonts) =>
    pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
          color: light, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: color, width: 1)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(width: 3, height: 14,
            decoration: pw.BoxDecoration(color: color,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
        pw.SizedBox(height: 6),
        pw.Text(value, style: pw.TextStyle(font: fonts.bold, color: color, fontSize: 13)),
        pw.Text(label, style: pw.TextStyle(font: fonts.regular, color: PdfColor.fromHex('#6B7A99'), fontSize: 9)),
      ]),
    ));

  pw.Widget _pdfTxnTable(
    List<_Txn> txns,
    PdfColor navy, PdfColor orange, PdfColor green, PdfColor red,
    PdfColor light, PdfColor grey,
    _PdfFonts fonts,
  ) {
    final f  = NumberFormat('#,###', 'en_US');
    final df = DateFormat('dd/MM/yy HH:mm');
    if (txns.isEmpty) {
      return pw.Text('No transactions found.',
          style: pw.TextStyle(font: fonts.regular, color: grey, fontSize: 12));
    }
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Description', 'Phone', 'Type', 'Country', 'Amount', 'Balance', 'Status'],
      data: txns.map((t) => [
        t.date != null ? df.format(t.date!) : '-',
        t.description.replaceAll('\u2014', '-'),
        t.phone.isNotEmpty ? t.phone : '-',
        t.type,
        t.country,
        '${t.isCredit ? '+' : '-'} ${t.currency} ${f.format(t.amount)}',
        '${t.currency} ${f.format(t.runningBalance)}',
        t.status.toUpperCase(),
      ]).toList(),
      headerStyle: pw.TextStyle(font: fonts.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: pw.BoxDecoration(color: navy),
      cellStyle: pw.TextStyle(font: fonts.regular, fontSize: 8),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.center,
      },
      rowDecoration: pw.BoxDecoration(color: light),
      oddRowDecoration: pw.BoxDecoration(color: PdfColors.white),
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E4E8F0'), width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(62),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(65),
        3: const pw.FixedColumnWidth(46),
        4: const pw.FixedColumnWidth(72),
        5: const pw.FixedColumnWidth(72),
        6: const pw.FixedColumnWidth(46),
      },
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx, PdfColor grey, _PdfFonts fonts) => pw.Column(children: [
    pw.Divider(color: grey),
    pw.SizedBox(height: 4),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(AppConstants.companyCopyright,
          style: pw.TextStyle(font: fonts.light, color: grey, fontSize: 8)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(font: fonts.regular, color: grey, fontSize: 8)),
    ]),
  ]);
}

// ─── Transaction List Widget ─────────────────────────────────────────────────

class _TxnList extends StatelessWidget {
  final List<_Txn> txns;
  final NumberFormat fmt;
  final DateFormat dateFmt;
  final void Function(_Txn) onSummary;
  const _TxnList({required this.txns, required this.fmt,
      required this.dateFmt, required this.onSummary});

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('No transactions found',
            style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textSecondary)),
      ]));
    }
    // Group by date
    final groups = <String, List<_Txn>>{};
    for (final t in txns) {
      final key = t.date != null
          ? DateFormat('EEEE, d MMM yyyy').format(t.date!)
          : 'Unknown Date';
      groups.putIfAbsent(key, () => []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: groups.entries.expand((entry) => [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(entry.key,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary, letterSpacing: 0.5)),
        ),
        ...entry.value.map((t) => _TxnTile(t: t, fmt: fmt, onTap: () => onSummary(t))),
      ]).toList(),
    );
  }
}

// ─── Single Tile ─────────────────────────────────────────────────────────────

class _TxnTile extends StatelessWidget {
  final _Txn t;
  final NumberFormat fmt;
  final VoidCallback onTap;
  const _TxnTile({required this.t, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = t.isCredit ? AppTheme.success : AppTheme.error;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          _TxnIcon(t),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.description,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (t.phone.isNotEmpty)
              Text(t.phone, style: GoogleFonts.poppins(fontSize: 11,
                  color: AppTheme.textSecondary)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${t.isCredit ? '+' : '-'} ${t.currency} ${fmt.format(t.amount)}',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Text('Bal: ${t.currency} ${fmt.format(t.runningBalance)}',
                style: GoogleFonts.poppins(fontSize: 10,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            _StatusBadge(t.status),
          ]),
        ]),
      ),
    );
  }
}

// ─── Icon ─────────────────────────────────────────────────────────────────────

class _TxnIcon extends StatelessWidget {
  final _Txn t;
  const _TxnIcon(this.t);

  IconData get _icon {
    switch (t.type) {
      case 'deposit': return Icons.arrow_downward_rounded;
      case 'withdrawal': return Icons.arrow_upward_rounded;
      case 'airtime': return Icons.phone_android_rounded;
      case 'bundle': return Icons.wifi_rounded;
      default: return Icons.swap_horiz_rounded;
    }
  }

  Color get _color => t.isCredit ? AppTheme.success : AppTheme.error;

  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: _color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(_icon, color: _color, size: 22),
  );
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final color = status == 'completed' ? AppTheme.success
        : status == 'failed' ? AppTheme.error : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(status.toUpperCase(),
          style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}

// ─── PDF Font Helper ──────────────────────────────────────────────────────────

class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font light;
  const _PdfFonts({required this.regular, required this.bold, required this.light});
}

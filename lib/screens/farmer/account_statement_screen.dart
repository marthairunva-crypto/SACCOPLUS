import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/sacco_service.dart';
import '../../core/theme.dart';
import 'farmer_scaffold.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class _Entry {
  final String   id;
  final DateTime date;
  final String   description;
  final int      debit;
  final int      credit;
  final int      balance;
  final String   category;
  final String   ref;

  const _Entry({
    required this.id,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.category,
    required this.ref,
  });

  bool get isCredit => credit > 0;

  _Entry withBalance(int bal) => _Entry(
    id: id, date: date, description: description,
    debit: debit, credit: credit, balance: bal,
    category: category, ref: ref,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 – Statement Setup Screen  (date range + generate button)
// ─────────────────────────────────────────────────────────────────────────────

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});
  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to   = DateTime.now();
  bool     _loading = false;

  final _dateFmt = DateFormat('dd MMM yyyy');

  // Quick-preset buttons
  void _setPreset(int days) => setState(() {
    _from = DateTime.now().subtract(Duration(days: days));
    _to   = DateTime.now();
  });

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      setState(() { _from = range.start; _to = range.end; });
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      final results = await Future.wait([
        FirebaseService.getUserProfile(uid),
        FirebaseService.getSavingsAccount(uid),
        FirebaseService.getWallet(uid),
        _fetchAllTransactions(uid),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final savings = results[1] as Map<String, dynamic>?;
      final wallet  = results[2] as Map<String, dynamic>;
      var   entries = results[3] as List<_Entry>;

      // Sort newest first
      entries.sort((a, b) => b.date.compareTo(a.date));

      // Filter to selected range
      entries = entries.where((e) =>
          !e.date.isBefore(_from) &&
          !e.date.isAfter(_to.add(const Duration(days: 1)))).toList();

      // Running balance backwards from current totals
      final savBal = (savings?['totalBalance'] as num?)?.toInt() ?? 0;
      final walBal = (wallet['balance']        as num?)?.toInt() ?? 0;
      int bal = savBal + walBal;
      final withBal = entries.map((e) {
        final b = bal;
        bal = e.isCredit ? bal - e.credit : bal + e.debit;
        return e.withBalance(b);
      }).toList();

      if (!mounted) return;

      // Navigate to preview
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _StatementPreviewScreen(
            profile : profile,
            savings : savings,
            wallet  : wallet,
            entries : withBal,
            from    : _from,
            to      : _to,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e', style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Data fetching ──────────────────────────────────────────────────────────
  Future<List<_Entry>> _fetchAllTransactions(String uid) async {
    final entries = <_Entry>[];

    // 1. Teller transactions
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.tellerTxnCol)
          .where('memberId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final d    = doc.data();
        final ts   = d['timestamp'] ?? d['createdAt'];
        final date = ts is Timestamp ? ts.toDate() : null;
        if (date == null) continue;
        final type    = (d['type'] as String? ?? '').toLowerCase();
        final amt     = (d['amount'] as num?)?.toInt() ?? 0;
        final acc     = (d['accountType'] as String? ?? type);
        final receipt = d['receiptNumber'] as String? ??
                        doc.id.substring(0, 8).toUpperCase();
        bool isDebit;
        String desc, cat;
        if (type == 'deposit') {
          isDebit = false;
          cat  = acc.contains('share') ? 'share' : 'savings';
          desc = 'Deposit – ${_cap(acc)} account';
        } else if (type == 'withdrawal') {
          isDebit = true;  cat = 'savings';
          desc = 'Withdrawal – ${_cap(acc)} account';
        } else if (type == 'loan_payment') {
          isDebit = true;  cat = 'repayment';
          desc = 'Loan Repayment – ${d['loanReference'] ?? '—'}';
        } else {
          isDebit = true;  cat = 'savings';
          desc = _cap(type.replaceAll('_', ' '));
        }
        entries.add(_Entry(id: doc.id, date: date, description: desc,
            debit: isDebit ? amt : 0, credit: isDebit ? 0 : amt,
            balance: 0, category: cat, ref: receipt));
      }
    } catch (_) {}

    // 2. Savings transactions
    try {
      final txns = await FirebaseService.getSavingsTransactions(uid);
      for (final d in txns) {
        final ts   = d['createdAt'] ?? d['timestamp'];
        final date = ts is Timestamp ? ts.toDate() : null;
        if (date == null) continue;
        final type    = (d['type'] as String? ?? '').toLowerCase();
        final amt     = (d['amount'] as num?)?.toInt() ?? 0;
        final savType = d['savingsType'] as String? ?? 'Savings';
        final eid     = d['id'] as String? ?? ts.toString();
        entries.add(_Entry(
          id: eid, date: date,
          description: type == 'deposit'
              ? 'Savings Deposit – $savType'
              : 'Savings Withdrawal – $savType',
          debit:   type == 'withdrawal' ? amt : 0,
          credit:  type == 'deposit'    ? amt : 0,
          balance: 0, category: 'savings',
          ref: (d['receiptNumber'] as String?) ??
               eid.substring(0, eid.length.clamp(0, 8)).toUpperCase(),
        ));
      }
    } catch (_) {}

    // 3. Loan repayments
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.repaymentsCol)
          .where('memberId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final d    = doc.data();
        final ts   = d['paidAt'] ?? d['createdAt'];
        final date = ts is Timestamp ? ts.toDate() : null;
        if (date == null) continue;
        final amt = (d['amount'] as num?)?.toInt() ?? 0;
        entries.add(_Entry(
          id: doc.id, date: date,
          description: 'Loan Repayment – ${d['loanReference'] ?? d['loanId'] ?? '—'}',
          debit: amt, credit: 0, balance: 0, category: 'repayment',
          ref: d['receiptNumber'] as String? ??
               doc.id.substring(0, 8).toUpperCase(),
        ));
      }
    } catch (_) {}

    // 4. Loan disbursements
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.loansCol)
          .where('memberId', isEqualTo: uid)
          .where('status', whereIn: ['Approved', 'Active', 'Disbursed', 'Paid'])
          .get();
      for (final doc in snap.docs) {
        final d  = doc.data();
        final ts = d['disbursedAt'] ?? d['approvedAt'] ?? d['createdAt'];
        if (ts == null) continue;
        final date = ts is Timestamp ? ts.toDate() : null;
        if (date == null) continue;
        final amt = (d['amount'] as num?)?.toInt() ?? 0;
        entries.add(_Entry(
          id: 'loan_${doc.id}', date: date,
          description: 'Loan Disbursement – ${d['purpose'] ?? d['loanType'] ?? '—'}',
          debit: 0, credit: amt, balance: 0, category: 'loan',
          ref: d['referenceNumber'] as String? ??
               doc.id.substring(0, 8).toUpperCase(),
        ));
      }
    } catch (_) {}

    // 5. Wallet transactions
    try {
      final txns = await FirebaseService.getWalletTransactions(uid);
      for (final d in txns) {
        final ts   = d['createdAt'] ?? d['timestamp'];
        final date = ts is Timestamp ? ts.toDate() : null;
        if (date == null) continue;
        final type = (d['type'] as String? ?? '').toLowerCase();
        final amt  = (d['amount'] as num?)?.toInt() ?? 0;
        final eid  = d['id'] as String? ?? ts.toString();
        final isC  = type == 'deposit' || type == 'credit';
        entries.add(_Entry(
          id: eid, date: date,
          description: d['description'] as String? ?? 'Wallet ${_cap(type)}',
          debit:  isC ? 0 : amt,
          credit: isC ? amt : 0,
          balance: 0, category: 'wallet',
          ref: d['marzReference'] as String? ??
               eid.substring(0, eid.length.clamp(0, 8)).toUpperCase(),
        ));
      }
    } catch (_) {}

    // Deduplicate
    final seen = <String>{};
    return entries.where((e) => seen.add(e.id)).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'Account Statement',
      showBack: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Hero card ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.description_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text('STATEMENT OF ACCOUNT',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              ]),
              const SizedBox(height: 12),
              Text(SaccoService.current.saccoName,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Select a period to generate your official account statement.',
                  style: GoogleFonts.poppins(
                      color: Colors.white60, fontSize: 12)),
            ]),
          ),

          const SizedBox(height: 28),

          // ── Quick presets ──────────────────────────────────────────────────
          Text('Quick Select', style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _PresetChip(label: 'Last 7 days',   onTap: () => _setPreset(7)),
            _PresetChip(label: 'Last 30 days',  onTap: () => _setPreset(30)),
            _PresetChip(label: 'Last 3 months', onTap: () => _setPreset(90)),
            _PresetChip(label: 'Last 6 months', onTap: () => _setPreset(180)),
            _PresetChip(label: 'Last 1 year',   onTap: () => _setPreset(365)),
          ]),

          const SizedBox(height: 24),

          // ── Custom date range ──────────────────────────────────────────────
          Text('Or choose custom range', style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8, offset: const Offset(0, 2))
                  ]),
              child: Row(children: [
                const Icon(Icons.calendar_month_rounded,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Statement Period',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text('${_dateFmt.format(_from)}  →  ${_dateFmt.format(_to)}',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('Change',
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Duration badge
          _DurationBadge(from: _from, to: _to),

          const SizedBox(height: 32),

          // ── What's included info ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.15))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Statement Includes',
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
              const SizedBox(height: 10),
              Wrap(spacing: 16, runSpacing: 8, children: [
                _IncludeItem(icon: Icons.savings_outlined,
                    label: 'Savings', color: AppTheme.primary),
                _IncludeItem(icon: Icons.payments_outlined,
                    label: 'Loan Repayments',
                    color: AppTheme.success),
                _IncludeItem(icon: Icons.account_balance_rounded,
                    label: 'Loan Disbursements',
                    color: const Color(0xFF8B5CF6)),
                _IncludeItem(icon: Icons.pie_chart_rounded,
                    label: 'Shares', color: AppTheme.accent),
                _IncludeItem(icon: Icons.account_balance_wallet_rounded,
                    label: 'Wallet', color: const Color(0xFF06B6D4)),
              ]),
            ]),
          ),

          const SizedBox(height: 32),

          // ── Generate button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.remove_red_eye_rounded, size: 20),
              label: Text(_loading ? 'Generating…' : 'Preview Statement',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              'You\'ll see a full preview before downloading.',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets for setup screen
// ─────────────────────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final String   label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE1EC)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4, offset: const Offset(0, 1))
            ]),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppTheme.primary)),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final DateTime from, to;
  const _DurationBadge({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final days = to.difference(from).inDays + 1;
    return Row(children: [
      const Icon(Icons.info_outline_rounded,
          size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 6),
      Text('$days day${days == 1 ? '' : 's'} selected',
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppTheme.textSecondary)),
    ]);
  }
}

class _IncludeItem extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _IncludeItem(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 – PDF Preview Screen
// ─────────────────────────────────────────────────────────────────────────────

class _StatementPreviewScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? savings;
  final Map<String, dynamic>  wallet;
  final List<_Entry>          entries;
  final DateTime from, to;

  const _StatementPreviewScreen({
    required this.profile,
    required this.savings,
    required this.wallet,
    required this.entries,
    required this.from,
    required this.to,
  });

  @override
  State<_StatementPreviewScreen> createState() =>
      _StatementPreviewScreenState();
}

class _StatementPreviewScreenState extends State<_StatementPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final filename =
        'Statement_${DateFormat('yyyyMMdd').format(widget.from)}'
        '_${DateFormat('yyyyMMdd').format(widget.to)}.pdf';

    return Scaffold(
      backgroundColor: const Color(0xFFE8EAEE),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Statement Preview',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(
            '${DateFormat('dd MMM yyyy').format(widget.from)} '
            '– ${DateFormat('dd MMM yyyy').format(widget.to)}',
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11),
          ),
        ]),
        actions: [
          // Share / Download button
          TextButton.icon(
            icon: const Icon(Icons.download_rounded,
                color: Colors.white, size: 18),
            label: Text('Download',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            onPressed: () async {
              final bytes = await _buildPdf();
              await Printing.sharePdf(bytes: bytes, filename: filename);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Info bar under the appbar ──────────────────────────────────────────
      body: Column(children: [
        _InfoBar(
          entries: widget.entries,
          savings: widget.savings,
          wallet : widget.wallet,
        ),

        // ── PdfPreview fills the rest ──────────────────────────────────────
        Expanded(
          child: PdfPreview(
            // Build the PDF bytes on demand
            build: (_) => _buildPdf(),

            // Styling
            pdfFileName  : filename,
            canChangePageFormat: false,
            canDebug     : false,
            allowSharing : true,
            allowPrinting: true,

            // Action bar customisation
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.share_rounded),
                onPressed: (ctx, build, pageFormat) async {
                  final bytes = await build(pageFormat);
                  await Printing.sharePdf(
                      bytes: bytes, filename: filename);
                },
              ),
            ],

            // Error widget
            loadingWidget: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Rendering statement…'),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── PDF Builder ─────────────────────────────────────────────────────────────
  Future<Uint8List> _buildPdf() async {
    final doc     = pw.Document();
    final sacco   = SaccoService.current.saccoName;
    final profile = widget.profile;
    final savings = widget.savings;
    final wallet  = widget.wallet;
    final entries = widget.entries;
    final from    = widget.from;
    final to      = widget.to;

    // Member info
    final name    = profile?['name']          as String? ?? '—';
    final phone   = profile?['phone']         as String? ?? '—';
    final accNo   = profile?['accountNumber'] as String? ??
                    profile?['memberNumber']  as String? ?? '—';
    final addr    = profile?['address']       as String? ?? 'N/A, UGANDA';
    final genDate = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    // Balances
    final savBal  = (savings?['totalBalance']      as num?)?.toInt() ?? 0;
    final volBal  = (savings?['voluntaryBalance']  as num?)?.toInt() ?? 0;
    final compBal = (savings?['compulsoryBalance'] as num?)?.toInt() ?? 0;
    final walBal  = (wallet['balance']             as num?)?.toInt() ?? 0;
    final openBal = entries.isNotEmpty ? entries.last.balance  : savBal + walBal;
    final closeBal= entries.isNotEmpty ? entries.first.balance : savBal + walBal;
    final totalDeb  = entries.fold(0, (s, e) => s + e.debit);
    final totalCred = entries.fold(0, (s, e) => s + e.credit);
    final f = NumberFormat('#,###', 'en_US');

    // Fonts
    pw.Font fReg = pw.Font.helvetica();
    pw.Font fBold= pw.Font.helveticaBold();
    pw.Font fLite= pw.Font.helvetica();
    try {
      fReg  = await PdfGoogleFonts.robotoRegular();
      fBold = await PdfGoogleFonts.robotoBold();
      fLite = await PdfGoogleFonts.robotoLight();
    } catch (_) {}

    // Logo
    pw.ImageProvider? logo;
    try {
      final data = await rootBundle.load(AppConstants.logoPath);
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    // ── Color palette (matches dfcu look) ──────────────────────────────────
    final cNavy   = PdfColor.fromHex('#0D2B6B');
    final cOrange = PdfColor.fromHex('#F47920');
    final cGreen  = PdfColor.fromHex('#22C55E');
    final cRed    = PdfColor.fromHex('#EF4444');
    final cGrey   = PdfColor.fromHex('#6B7A99');
    final cLight  = PdfColor.fromHex('#F9FAFB');
    final cBorder = PdfColor.fromHex('#E4E8F0');
    final cWhite  = PdfColors.white;
    final cBlack  = PdfColor.fromHex('#071A45');

    // ── Cell alignments ────────────────────────────────────────────────────

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin    : const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        theme     : pw.ThemeData.withFont(base: fReg, bold: fBold),

        // ── Continuation header (page 2+) ──────────────────────────────────
        header: (ctx) {
          if (ctx.pageNumber == 1) return pw.SizedBox();
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(sacco,
                    style: pw.TextStyle(font: fBold, color: cNavy, fontSize: 9)),
                pw.Text('STATEMENT OF ACCOUNT',
                    style: pw.TextStyle(
                        font: fBold, color: cOrange, fontSize: 9,
                        letterSpacing: 0.8)),
                pw.Text(
                    'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                    style: pw.TextStyle(font: fReg, color: cGrey, fontSize: 8)),
              ],
            ),
          );
        },

        // ── Footer ─────────────────────────────────────────────────────────
        footer: (ctx) => pw.Column(children: [
          pw.Divider(color: cBorder, thickness: 0.8),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Text(
                '$sacco — Member Account Statement',
                style: pw.TextStyle(font: fLite, color: cGrey, fontSize: 7.5)),
            pw.Text('Generated: $genDate',
                style: pw.TextStyle(font: fLite, color: cGrey, fontSize: 7.5)),
            pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                    font: fBold, color: cNavy, fontSize: 7.5)),
          ]),
        ]),

        build: (ctx) => [

          // ══════════════════════════════════════════════════════════════════
          // HEADER — exact dfcu layout: logo+title left, details right
          // ══════════════════════════════════════════════════════════════════
          pw.Center(
            child: pw.Text('STATEMENT OF ACCOUNT',
                style: pw.TextStyle(
                    font: fBold, fontSize: 15, color: cBlack,
                    letterSpacing: 0.5)),
          ),
          pw.SizedBox(height: 14),

          // Logo + account details two-column grid
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left column – member info
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  logo != null
                      ? pw.Container(
                          width: 72, height: 36,
                          child: pw.Image(logo, fit: pw.BoxFit.contain))
                      : pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: pw.BoxDecoration(color: cNavy,
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(6))),
                          child: pw.Text(sacco,
                              style: pw.TextStyle(
                                  font: fBold, color: cWhite, fontSize: 13))),
                  pw.SizedBox(height: 12),
                  _hRow('Account Name', name,  fReg, fBold, cBlack, cGrey),
                  _hRow('Address',      addr,  fReg, fBold, cBlack, cGrey),
                ]),
              ),
              pw.SizedBox(width: 20),
              // Right column – account metadata
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                  _hRow('Account Number',   accNo,            fReg, fBold, cBlack, cGrey),
                  _hRow('Account Currency', 'UGX',            fReg, fBold, cBlack, cGrey),
                  _hRow('Branch',           'Main Branch',    fReg, fBold, cBlack, cGrey),
                  _hRow('Type of Account',  'Savings Account',fReg, fBold, cBlack, cGrey),
                  _hRow('Phone',            phone,            fReg, fBold, cBlack, cGrey),
                  _hRow('Statement Period',
                      '${DateFormat('dd-MM-yyyy').format(from)}'
                      ' To ${DateFormat('dd-MM-yyyy').format(to)}',
                      fReg, fBold, cBlack, cGrey),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          // ── Balance bar (BOOK BALANCE / CLEARED BALANCE etc.) ─────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: cBorder, width: 0.8)),
            child: pw.Row(children: [
              _bCell('Opening Bal.',  f.format(openBal),   fReg, fBold, cBlack),
              _bDiv(cBorder),
              _bCell('Closing Bal.',  f.format(closeBal),  fReg, fBold, cBlack),
              _bDiv(cBorder),
              _bCell('Un-Cleared',    '0.00',              fReg, fBold, cBlack),
              _bDiv(cBorder),
              _bCell('Total Debits',  f.format(totalDeb),  fReg, fBold, cRed),
              _bDiv(cBorder),
              _bCell('Total Credits', f.format(totalCred), fReg, fBold, cGreen),
            ]),
          ),
          pw.SizedBox(height: 16),

          // ══════════════════════════════════════════════════════════════════
          // TRANSACTION TABLE — exact dfcu column widths
          // ══════════════════════════════════════════════════════════════════
          entries.isEmpty
              ? pw.Container(
                  padding: const pw.EdgeInsets.all(30),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: cBorder)),
                  child: pw.Center(
                      child: pw.Text(
                          'No transactions found for the selected period.',
                          style: pw.TextStyle(
                              font: fReg, color: cGrey, fontSize: 10))))

              : _buildTable(entries, fReg, fBold, cNavy, cLight, cBorder,
                            cRed, cGreen, cBlack, cOrange, cWhite, f),

          pw.SizedBox(height: 14),

          // ══════════════════════════════════════════════════════════════════
          // TOTALS FOOTER  (exact dfcu style)
          // ══════════════════════════════════════════════════════════════════
          if (entries.isNotEmpty) ...[
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(
                    text: 'Total No. of Debits: ',
                    style: pw.TextStyle(font: fReg, fontSize: 8.5, color: cGrey)),
                pw.TextSpan(
                    text: '${entries.where((e) => e.debit > 0).length}  ',
                    style: pw.TextStyle(font: fBold, fontSize: 8.5, color: cBlack)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(
                    text: 'Total No. of Credits: ',
                    style: pw.TextStyle(font: fReg, fontSize: 8.5, color: cGrey)),
                pw.TextSpan(
                    text: '${entries.where((e) => e.credit > 0).length}',
                    style: pw.TextStyle(font: fBold, fontSize: 8.5, color: cBlack)),
              ])),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(
                    text: 'Total Debits amount: ',
                    style: pw.TextStyle(font: fReg, fontSize: 8.5, color: cGrey)),
                pw.TextSpan(
                    text: f.format(totalDeb),
                    style: pw.TextStyle(font: fBold, fontSize: 8.5, color: cRed)),
              ])),
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(
                    text: 'Total Credit Amount: ',
                    style: pw.TextStyle(font: fReg, fontSize: 8.5, color: cGrey)),
                pw.TextSpan(
                    text: f.format(totalCred),
                    style: pw.TextStyle(font: fBold, fontSize: 8.5, color: cGreen)),
              ])),
            ]),
            pw.SizedBox(height: 18),
          ],

          // ══════════════════════════════════════════════════════════════════
          // SAVINGS SUMMARY BOX
          // ══════════════════════════════════════════════════════════════════
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: cLight,
                border: pw.Border.all(color: cBorder, width: 0.8)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
              pw.Text('SAVINGS SUMMARY',
                  style: pw.TextStyle(
                      font: fBold, fontSize: 8, color: cNavy,
                      letterSpacing: 1.0)),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                _sumCell('Voluntary Savings',  'UGX ${f.format(volBal)}',
                    fReg, fBold, cGreen),
                pw.SizedBox(width: 12),
                _sumCell('Compulsory Savings', 'UGX ${f.format(compBal)}',
                    fReg, fBold, cNavy),
                pw.SizedBox(width: 12),
                _sumCell('Total Savings',      'UGX ${f.format(savBal)}',
                    fReg, fBold, cOrange),
                pw.SizedBox(width: 12),
                _sumCell('Wallet Balance',     'UGX ${f.format(walBal)}',
                    fReg, fBold, cNavy),
              ]),
            ]),
          ),
          pw.SizedBox(height: 18),

          // ══════════════════════════════════════════════════════════════════
          // LEGAL FOOTER (like dfcu bottom text)
          // ══════════════════════════════════════════════════════════════════
          pw.Divider(color: cBorder, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Text(
              '$sacco is a registered SACCO governed by Ugandan Cooperative '
              'Societies legislation. Member deposits are protected. '
              'This is a system-generated statement and does not require a '
              'signature or stamp. For enquiries, contact $sacco.',
              style: pw.TextStyle(font: fLite, fontSize: 7, color: cGrey)),
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  // ── Table builder ──────────────────────────────────────────────────────────
  pw.Widget _buildTable(
    List<_Entry> entries,
    pw.Font fReg, pw.Font fBold,
    PdfColor cNavy, PdfColor cLight, PdfColor cBorder,
    PdfColor cRed,  PdfColor cGreen, PdfColor cBlack,
    PdfColor cOrange, PdfColor cWhite,
    NumberFormat f,
  ) {
    final df = DateFormat('dd-MM-yyyy');
    final hPad = const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6);
    final cPad = const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4);

    return pw.Table(
      border: pw.TableBorder.all(color: cBorder, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(56),   // TRAN DATE
        1: const pw.FixedColumnWidth(56),   // VALUE DATE
        2: const pw.FlexColumnWidth(3.2),   // DESCRIPTION
        3: const pw.FixedColumnWidth(58),   // DEBIT
        4: const pw.FixedColumnWidth(58),   // CREDIT
        5: const pw.FixedColumnWidth(62),   // BALANCE
      },
      children: [
        // ── Header row ──
        pw.TableRow(
          decoration: pw.BoxDecoration(color: cNavy),
          children: [
            _th('TRAN DATE',   fBold, cWhite, hPad),
            _th('VALUE DATE',  fBold, cWhite, hPad),
            _th('DESCRIPTION', fBold, cWhite, hPad),
            _th('DEBIT',       fBold, cWhite, hPad, right: true),
            _th('CREDIT',      fBold, cWhite, hPad, right: true),
            _th('BALANCE',     fBold, cWhite, hPad, right: true),
          ],
        ),
        // ── Data rows ──
        for (int i = 0; i < entries.length; i++) ...[
          pw.TableRow(
            decoration: pw.BoxDecoration(
                color: i.isOdd ? cLight : PdfColors.white),
            children: [
              // Date
              pw.Padding(padding: cPad,
                  child: pw.Text(df.format(entries[i].date),
                      style: pw.TextStyle(
                          font: fReg, fontSize: 7.5, color: cBlack))),
              // Value date (same as tran date)
              pw.Padding(padding: cPad,
                  child: pw.Text(df.format(entries[i].date),
                      style: pw.TextStyle(
                          font: fReg, fontSize: 7.5, color: cBlack))),
              // Description
              pw.Padding(padding: cPad,
                  child: pw.Text(
                      entries[i].description.length > 58
                          ? '${entries[i].description.substring(0, 58)}…'
                          : entries[i].description,
                      style: pw.TextStyle(
                          font: fReg, fontSize: 7.5, color: cBlack))),
              // Debit (red)
              pw.Padding(padding: cPad,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                          entries[i].debit > 0
                              ? f.format(entries[i].debit)
                              : '',
                          style: pw.TextStyle(
                              font: entries[i].debit > 0 ? fBold : fReg,
                              fontSize: 7.5,
                              color: entries[i].debit > 0
                                  ? cRed
                                  : cBlack)))),
              // Credit (green)
              pw.Padding(padding: cPad,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                          entries[i].credit > 0
                              ? f.format(entries[i].credit)
                              : '',
                          style: pw.TextStyle(
                              font: entries[i].credit > 0 ? fBold : fReg,
                              fontSize: 7.5,
                              color: entries[i].credit > 0
                                  ? cGreen
                                  : cBlack)))),
              // Balance
              pw.Padding(padding: cPad,
                  child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                          f.format(entries[i].balance),
                          style: pw.TextStyle(
                              font: fBold, fontSize: 7.5,
                              color: cNavy)))),
            ],
          ),
        ],
      ],
    );
  }

  // ── Header detail row (label : value) ────────────────────────────────────
  static pw.Widget _hRow(String label, String value,
      pw.Font fReg, pw.Font fBold, PdfColor cBlack, PdfColor cGrey) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(children: [
        pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: pw.TextStyle(
                    font: fReg, fontSize: 9, color: cGrey))),
        pw.Text(':  ',
            style: pw.TextStyle(font: fReg, fontSize: 9, color: cGrey)),
        pw.Flexible(
          child: pw.Text(value,
              style: pw.TextStyle(
                  font: fBold, fontSize: 9, color: cBlack)),
        ),
      ]),
    );
  }

  // ── Balance summary cell ───────────────────────────────────────────────────
  static pw.Widget _bCell(String label, String value,
      pw.Font fReg, pw.Font fBold, PdfColor color) {
    return pw.Expanded(child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label,
          style: pw.TextStyle(font: fReg, fontSize: 7, color: PdfColor.fromHex('#6B7A99'))),
      pw.SizedBox(height: 2),
      pw.Text(value,
          style: pw.TextStyle(font: fBold, fontSize: 8.5, color: color)),
    ]));
  }

  static pw.Widget _bDiv(PdfColor c) =>
      pw.Container(width: 0.6, height: 28, color: c,
          margin: const pw.EdgeInsets.symmetric(horizontal: 6));

  // ── Summary cell (savings breakdown) ──────────────────────────────────────
  static pw.Widget _sumCell(String label, String value,
      pw.Font fReg, pw.Font fBold, PdfColor color) {
    return pw.Expanded(child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label,
          style: pw.TextStyle(
              font: fReg, fontSize: 7.5,
              color: PdfColor.fromHex('#6B7A99'))),
      pw.SizedBox(height: 2),
      pw.Text(value,
          style: pw.TextStyle(font: fBold, fontSize: 9, color: color)),
    ]));
  }

  // ── Table header cell ──────────────────────────────────────────────────────
  static pw.Widget _th(String text, pw.Font fBold, PdfColor color,
      pw.EdgeInsets pad, {bool right = false}) {
    return pw.Padding(
      padding: pad,
      child: pw.Align(
        alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text,
            style: pw.TextStyle(
                font: fBold, fontSize: 8, color: color,
                letterSpacing: 0.3)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info bar shown above the PDF preview
// ─────────────────────────────────────────────────────────────────────────────
class _InfoBar extends StatelessWidget {
  final List<_Entry>          entries;
  final Map<String, dynamic>? savings;
  final Map<String, dynamic>  wallet;

  const _InfoBar({
    required this.entries,
    required this.savings,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    final fmt      = NumberFormat('#,###', 'en_US');
    final savBal   = (savings?['totalBalance'] as num?)?.toInt() ?? 0;
    final walBal   = (wallet['balance']        as num?)?.toInt() ?? 0;
    final totalDeb = entries.fold(0, (s, e) => s + e.debit);
    final totalCr  = entries.fold(0, (s, e) => s + e.credit);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        _chip('Savings', 'UGX ${fmt.format(savBal)}', AppTheme.primary),
        const SizedBox(width: 8),
        _chip('Wallet',  'UGX ${fmt.format(walBal)}',  const Color(0xFF06B6D4)),
        const Spacer(),
        _chip('Debits',  fmt.format(totalDeb),  AppTheme.error),
        const SizedBox(width: 8),
        _chip('Credits', fmt.format(totalCr),   AppTheme.success),
        const SizedBox(width: 8),
        _chip('Txns',    '${entries.length}',   AppTheme.textSecondary),
      ]),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 9, color: AppTheme.textSecondary)),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

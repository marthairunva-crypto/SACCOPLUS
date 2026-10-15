import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/firebase_service.dart';

class StatementResult {
  final Uint8List bytes;
  final String filename;
  const StatementResult({required this.bytes, required this.filename});
}

/// One money movement on the member's single savings/wallet account.
class LedgerEntry {
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  double balance = 0;
  LedgerEntry(this.date, this.description, this.debit, this.credit);

  bool get isDebit => debit > 0;
  double get amount => isDebit ? debit : credit;
}

/// Builds a clean, bank-style (DFCU-like) account statement.
///
/// In a SACCO, "savings" and "wallet" are the same money, so everything is
/// merged into ONE running balance on ONE account.
class MemberStatementService {
  // ── Branding (change once, used everywhere) ───────────────────────────────
  static const String _saccoName = 'MBADIFA SACCO';
  static const String _tagline = 'Poverty Must Go';
  static const String _logoAsset = 'assets/images/mbadifa-logo.png';
  static const PdfColor _navy = PdfColor.fromInt(0xFF0B2A5B);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1F2937);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _line = PdfColor.fromInt(0xFFD1D5DB);
  static const PdfColor _zebra = PdfColor.fromInt(0xFFF5F7FA);

  // Every collection that holds money movements for the member's single
  // savings/wallet account. CONFIRM the wallet collection name below.
  static const List<_Source> _sources = [
    _Source('saccoplus-savings', 'farmerId', tenantScoped: true),
    _Source('saccoplus-savings-transactions', 'memberId'),
    _Source('saccoplus-wallet-transactions', 'memberId'), // <-- confirm name
  ];

  static final _money = NumberFormat('#,##0.00');
  static final _day = DateFormat('dd-MM-yyyy');

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<StatementResult> generateForAdmin({
    required String memberId,
    required DateTime from,
    required DateTime to,
  }) async {
    final memberDoc = await FirebaseFirestore.instance
        .collection('saccoplus-members')
        .doc(memberId)
        .get();
    if (!memberDoc.exists) throw Exception('Member not found');
    final member = memberDoc.data()!;

    // ── Fetch shares and loans data ─────────────────────────────────────────
    final sharesBalance = _num(member['sharesBalance'] ?? 0);
    
    // Fetch active loans with proper outstanding calculation
    double totalLoans = 0;
    int loanCount = 0;
    final processedLoanIds = <String>{}; // Track processed loans to avoid duplicates
    
    try {
      final loansQuery = await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .get();
      
      final accountNumber = member['accountNumber'] ?? '';
      final memberNumber = member['memberNumber'] ?? '';
      
      print('🔍 Looking for loans for member: $memberId, account: $accountNumber, memberNum: $memberNumber');
      
      final memberName = (member['name'] ?? member['fullName'] ?? '').toString().toLowerCase();
      print('🔍 Member name: $memberName');
      
      int checkedLoans = 0;
      int matchedLoans = 0;
      
      for (final loanDoc in loansQuery.docs) {
        checkedLoans++;
        final loan = loanDoc.data();
        final loanMemberId = loan['memberId'] ?? loan['farmerId'] ?? '';
        final loanAccountNo = loan['accountNumber'] ?? '';
        final loanMemberNo = loan['memberNumber'] ?? '';
        final loanMemberName = (loan['memberName'] ?? '').toString().toLowerCase();
        
        // Strict matching (same logic as Member 360 screen)
        // 1. memberId must match exactly (no empty strings)
        final memberIdMatch = loanMemberId.isNotEmpty && loanMemberId == memberId;
            
        // 2. Account number must match exactly (no partial matches)
        final accountMatch = accountNumber.isNotEmpty && 
            loanAccountNo.isNotEmpty &&
            loanAccountNo == accountNumber;
             
        // 3. Member number must match exactly
        final memberNumMatch = memberNumber.isNotEmpty && 
            loanMemberNo.isNotEmpty &&
            loanMemberNo == memberNumber;
            
        // 4. Member name must match (fallback - same as Member 360)
        final nameMatch = memberName.isNotEmpty && 
            loanMemberName.isNotEmpty &&
            loanMemberName == memberName;
        
        // Check if loan belongs to this member (same logic as Member 360 screen)
        final belongsToMember = memberIdMatch || accountMatch || memberNumMatch || nameMatch;
        
        // Debug log for troubleshooting
        if (checkedLoans <= 5 || belongsToMember) {
          print('🔎 Loan ${loanDoc.id}: loanMemberId="$loanMemberId", loanName="$loanMemberName", loanAcct="$loanAccountNo", match=$belongsToMember (id:$memberIdMatch, name:$nameMatch, acct:$accountMatch)');
        }
        
        if (belongsToMember) {
          matchedLoans++;
          print('✅ MATCHED loan ${loanDoc.id}');
          
          // Skip if we've already processed this loan
          if (processedLoanIds.contains(loanDoc.id)) {
            print('⚠️ Skipping duplicate loan: ${loanDoc.id}');
            continue;
          }
          processedLoanIds.add(loanDoc.id);
          
          final status = (loan['status'] ?? '').toString().toLowerCase();
          
          // PRIORITY ORDER for outstanding balance:
          // 1. totalOutstanding (from Loan Data Correction - most accurate)
          // Priority order (same as Member 360, Loan Details):
          // 1. totalOutstanding (from Loan Data Correction - manual corrections, most accurate)
          // 2. remainingBalance (from ArrearsService - auto-calculated)
          // 3. principalOutstanding (legacy field, principal only)
          double outstanding = _num(loan['totalOutstanding'] ?? 0);
          if (outstanding == 0) {
            outstanding = _num(loan['remainingBalance'] ?? 0);
          }
          if (outstanding == 0) {
            outstanding = _num(loan['principalOutstanding'] ?? 0);
          }
          
          print('📋 Loan ${loanDoc.id}: outstanding=$outstanding, status=$status, totalOut=${loan['totalOutstanding']}, principalOut=${loan['principalOutstanding']}, remaining=${loan['remainingBalance']}');
          
          // Count active loans with outstanding balance
          if (outstanding > 0 && 
              status != 'cleared' && 
              status != 'rejected' && 
              status != 'cancelled' &&
              status != 'paid') {
            totalLoans += outstanding;
            loanCount++;
            print('✅ Added loan to total: $outstanding (total now: $totalLoans)');
          } else {
            print('⏭️ Skipped loan: outstanding=$outstanding, status=$status');
          }
        }
      }
      
      print('🎯 Final loan totals for member $memberId: $loanCount loan(s), total: $totalLoans (checked $checkedLoans loans, matched $matchedLoans)');
    } catch (e) {
      print('❌ Error fetching loans: $e');
    }

    // Inclusive day range (the date picker returns midnight for `to`)
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    // ── Opening balance ─────────────────────────────────────────────────────
    // 1. Try the stored migration record first (most accurate).
    //    The migration screen writes a doc to saccoplus-savings with
    //    description == 'Opening balance from migration' and openingBalance
    //    (or totalBalance) for that member.
    double migrationBalance = 0;
    try {
      final migQ = await FirebaseFirestore.instance
          .collection('saccoplus-savings')
          .where('memberId', isEqualTo: memberId)
          .where('description', isEqualTo: 'Opening balance from migration')
          .limit(1)
          .get();
      if (migQ.docs.isNotEmpty) {
        final d = migQ.docs.first.data();
        migrationBalance = _num(d['openingBalance'] ?? d['amount'] ?? 0);
      }
    } catch (_) {}

    // 2. Also try farmerId key (migration uses both)
    if (migrationBalance == 0) {
      try {
        final migQ = await FirebaseFirestore.instance
            .collection('saccoplus-savings')
            .where('farmerId', isEqualTo: memberId)
            .where('description', isEqualTo: 'Opening balance from migration')
            .limit(1)
            .get();
        if (migQ.docs.isNotEmpty) {
          final d = migQ.docs.first.data();
          migrationBalance = _num(d['openingBalance'] ?? d['amount'] ?? 0);
        }
      } catch (_) {}
    }

    final all = await loadLedger(memberId); // oldest → newest
    
    // Use the migration balance from ledger if the query didn't find it
    if (migrationBalance == 0 && _lastMigrationBalance > 0) {
      migrationBalance = _lastMigrationBalance;
    }

    // Opening = migration balance + everything that happened BEFORE the period
    // (so the statement's opening balance is always correct regardless of
    // whether the migration transaction itself appears in the ledger)
    double opening = migrationBalance;
    for (final e in all.where((e) => e.date.isBefore(start))) {
      opening += e.credit - e.debit;
    }
    // If migration balance is already included as a ledger entry, avoid
    // double-counting: the loadLedger deduplication key handles exact
    // duplicates, but the migration record may differ in timestamp.
    // Simple guard: don't go below 0.
    if (opening < 0) opening = 0;

    final inRange =
        all.where((e) => !e.date.isBefore(start) && !e.date.isAfter(end)).toList();

    // Running balance, oldest → newest. Guarantees:
    // opening + credits − debits = closing
    double running = opening;
    for (final e in inRange) {
      running += e.credit - e.debit;
      e.balance = running;
    }
    final closing = running;

    // IMPORTANT: The statement closing balance MUST match the actual member balance
    // when the statement period ends today or in the future.
    final currentBalance = _num(member['savingsBalance'] ?? 0) + _num(member['walletBalance'] ?? 0);
    final now = DateTime.now();
    final endsToday = end.year == now.year && end.month == now.month && end.day >= now.day;
    
    if (endsToday && (closing - currentBalance).abs() > 0.01) {
      // Recalculate opening so that: opening + credits - debits = actual balance
      final adjustment = currentBalance - closing;
      opening += adjustment;
      
      // Don't allow negative opening
      if (opening < 0) {
        opening = 0;
      }
      
      // Recalculate all running balances
      running = opening;
      for (final e in inRange) {
        running += e.credit - e.debit;
        e.balance = running;
      }
    }
    
    final finalClosing = running;

    final totalDebit = inRange.fold<double>(0, (s, e) => s + e.debit);
    final totalCredit = inRange.fold<double>(0, (s, e) => s + e.credit);
    final debitCount = inRange.where((e) => e.debit > 0).length;
    final creditCount = inRange.where((e) => e.credit > 0).length;

    // Bank style: newest first
    final rows = inRange.reversed.toList();

    final bytes = await _buildPdf(
      member: member,
      from: start,
      to: end,
      opening: opening,
      closing: finalClosing,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      debitCount: debitCount,
      creditCount: creditCount,
      rows: rows,
      sharesBalance: sharesBalance,
      totalLoans: totalLoans,
      loanCount: loanCount,
    );

    final acc = (member['accountNumber'] ?? memberId).toString();
    final f = DateFormat('yyyyMMdd');
    return StatementResult(
      bytes: bytes,
      filename: 'Statement_${acc}_${f.format(start)}_${f.format(end)}.pdf',
    );
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  /// Single source of truth for savings + wallet movements.
  /// Used by the statement PDF AND the Member 360 screen so they always agree.
  /// Returned oldest → newest.
  static double _lastMigrationBalance = 0;
  
  static Future<List<LedgerEntry>> loadLedger(String memberId) async {
    final db = FirebaseFirestore.instance;
    final tenant = FirebaseService.sessionTenantId;
    final seen = <String>{};
    final out = <LedgerEntry>[];
    _lastMigrationBalance = 0;

    for (final s in _sources) {
      Query q = db.collection(s.collection).where(s.field, isEqualTo: memberId);
      if (s.tenantScoped) q = q.where('tenantId', isEqualTo: tenant);

      QuerySnapshot snap;
      try {
        snap = await q.get();
      } catch (_) {
        continue; // collection missing / no access: skip, don't kill the PDF
      }

      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final ts = d['createdAt'];
        if (ts is! Timestamp) continue;
        final raw = _num(d['amount']);
        if (raw == 0) continue;

        final desc = (d['description'] ?? '').toString().trim();
        
        // Skip migration balance transaction BUT capture its amount for opening balance
        if (desc == 'Opening balance from migration') {
          _lastMigrationBalance = raw.abs();
          continue;
        }

        final type =
            '${d['type'] ?? d['transactionType'] ?? ''}'.toLowerCase();
        final isDebit = raw < 0 || type.contains('withdraw') || type == 'debit';
        final amt = raw.abs();
        final date = ts.toDate();

        // Same deposit written to two collections must count once
        final key = '${date.millisecondsSinceEpoch}_${amt}_$isDebit';
        if (!seen.add(key)) continue;

        out.add(LedgerEntry(
          date,
          desc.isNotEmpty ? desc : (isDebit ? 'Withdrawal' : 'Deposit'),
          isDebit ? amt : 0,
          isDebit ? 0 : amt,
        ));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

  // ── PDF ───────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> member,
    required DateTime from,
    required DateTime to,
    required double opening,
    required double closing,
    required double totalDebit,
    required double totalCredit,
    required int debitCount,
    required int creditCount,
    required List<LedgerEntry> rows,
    required double sharesBalance,
    required double totalLoans,
    required int loanCount,
  }) async {
    pw.ThemeData theme;
    try {
      theme = pw.ThemeData.withFont(
        base: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interSemiBold(),
      );
    } catch (_) {
      theme = pw.ThemeData.base();
    }

    pw.MemoryImage? logo;
    try {
      logo = pw.MemoryImage((await rootBundle.load(_logoAsset)).buffer.asUint8List());
    } catch (_) {}

    String s(String k, [String fb = 'N/A']) {
      final v = (member[k] ?? '').toString().trim();
      return v.isEmpty ? fb : v;
    }

    final name = (member['name'] ?? member['fullName'] ?? '').toString().trim();
    final accountNo = s('accountNumber');
    final address = [s('village', ''), s('district', '')]
        .where((e) => e.isNotEmpty)
        .join(', ');
    final period = '${_day.format(from)} To ${_day.format(to)}';
    final generatedDate = DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now());

    // Member details (left column)
    final memberDetails = <List<String>>[
      ['Account Name', name.isEmpty ? 'N/A' : name.toUpperCase()],
      ['Account Number', accountNo],
      ['Phone', s('phone')],
      ['Address', address.isEmpty ? 'N/A' : address],
    ];

    // Account details (right column)
    final accountDetails = <List<String>>[
      ['Account Type', 'Savings Account'],
      ['Currency', 'UGX'],
      ['Branch', s('branch', 'Main Branch')],
      ['Statement Period', period],
      ['Generated On', generatedDate],
    ];

    // Other accounts summary (separate section)
    final otherAccounts = <List<String>>[
      ['Total Shares', 'UGX ${_money.format(sharesBalance)}'],
      ['Loan Outstanding', totalLoans > 0 ? 'UGX ${_money.format(totalLoans)} ($loanCount loan${loanCount > 1 ? 's' : ''})' : 'No active loans'],
    ];

    final doc = pw.Document(
      title: 'Account Statement - $accountNo',
      author: _saccoName,
    );

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        theme: theme,
      ),
      header: (ctx) => ctx.pageNumber == 1
          ? _fullHeader(logo, memberDetails, accountDetails, otherAccounts)
          : _compactHeader(logo, name, accountNo, period),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _summary(opening, closing, totalDebit, totalCredit),
        pw.SizedBox(height: 14),
        if (rows.isEmpty)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 28),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _line, width: .6)),
            child: pw.Center(
              child: pw.Text('No transactions in this period',
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ),
          )
        else
          _table(rows),
        pw.SizedBox(height: 12),
        _totals(debitCount, creditCount, totalDebit, totalCredit),
      ],
    ));

    return doc.save();
  }

  static pw.Widget _fullHeader(
      pw.MemoryImage? logo,
      List<List<String>> memberDetails,
      List<List<String>> accountDetails,
      List<List<String>> otherAccounts) {
    pw.Widget kv(List<String> p) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(
              width: 84,
              child: pw.Text(p[0],
                  style: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _ink)),
            ),
            pw.Text(': ', style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            pw.Expanded(
              child: pw.Text(p[1],
                  style: const pw.TextStyle(fontSize: 8.5, color: _ink)),
            ),
          ]),
        );

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Centered Logo and SACCO Name
      pw.Center(
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) ...[
              pw.Container(width: 46, height: 46, child: pw.Image(logo)),
              pw.SizedBox(width: 10),
            ],
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_saccoName,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.Text(_tagline,
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            ]),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      // Centered Title
      pw.Center(
        child: pw.Text('STATEMENT OF ACCOUNT',
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
      ),
      pw.SizedBox(height: 12),
      // Member and Account Details (Two Columns)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(children: memberDetails.map(kv).toList())),
        pw.SizedBox(width: 24),
        pw.Expanded(child: pw.Column(children: accountDetails.map(kv).toList())),
      ]),
      pw.SizedBox(height: 10),
      // Other Accounts Summary Section
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _zebra,
          border: pw.Border.all(color: _line, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Other Accounts Summary',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 6),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Column(children: [kv(otherAccounts[0])])),
                pw.SizedBox(width: 24),
                pw.Expanded(child: pw.Column(children: [kv(otherAccounts[1])])),
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  static pw.Widget _compactHeader(
      pw.MemoryImage? logo, String name, String acc, String period) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line, width: .6))),
      child: pw.Row(children: [
        if (logo != null) ...[
          pw.Container(width: 24, height: 24, child: pw.Image(logo)),
          pw.SizedBox(width: 8),
        ],
        pw.Expanded(
          child: pw.Text('STATEMENT OF ACCOUNT',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navy)),
        ),
        pw.Text('${name.toUpperCase()}  |  $acc  |  $period',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ]),
    );
  }

  static pw.Widget _summary(double open, double close, double dr, double cr) {
    pw.Widget cell(String label, double v, {PdfColor color = _ink, bool last = false}) =>
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: pw.BoxDecoration(
              border: last
                  ? null
                  : const pw.Border(
                      right: pw.BorderSide(color: _line, width: .6)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
              pw.SizedBox(height: 3),
              pw.Text(_money.format(v),
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            ]),
          ),
        );

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _zebra,
        border: pw.Border.all(color: _line, width: .6),
      ),
      child: pw.Row(children: [
        cell('Opening Balance', open),
        cell('Total Debits', dr),
        cell('Total Credits', cr),
        cell('Closing Balance', close, color: _navy, last: true),
      ]),
    );
  }

  static pw.Widget _table(List<LedgerEntry> rows) {
    const headers = ['TRAN DATE', 'DESCRIPTION', 'DEBIT', 'CREDIT', 'BALANCE'];
    final data = rows
        .map((e) => [
              _day.format(e.date),
              e.description,
              e.debit > 0 ? _money.format(e.debit) : '',
              e.credit > 0 ? _money.format(e.credit) : '',
              _money.format(e.balance),
            ])
        .toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
          fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      oddRowDecoration: const pw.BoxDecoration(color: _zebra),
      border: pw.TableBorder(
        bottom: const pw.BorderSide(color: _line, width: .6),
        horizontalInside: const pw.BorderSide(color: _line, width: .3),
        left: const pw.BorderSide(color: _line, width: .6),
        right: const pw.BorderSide(color: _line, width: .6),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(66),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FixedColumnWidth(76),
        3: const pw.FixedColumnWidth(76),
        4: const pw.FixedColumnWidth(84),
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _totals(int dc, int cc, double dr, double cr) {
    pw.Widget line(String a, String b) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            pw.Text(a, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            pw.Text(b,
                style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
          ]),
        );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          line('Total No. of Debits: ', '$dc'),
          line('Total Debits amount: ', _money.format(dr)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          line('Total No. of Credits: ', '$cc'),
          line('Total Credit Amount: ', _money.format(cr)),
        ]),
      ],
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _line, width: .6))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Text(
              '$_saccoName. This statement is system-generated and does not '
              'require a signature. For enquiries, please contact $_saccoName.',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
    );
  }
}

class _Source {
  final String collection;
  final String field;
  final bool tenantScoped;
  const _Source(this.collection, this.field, {this.tenantScoped = false});
}

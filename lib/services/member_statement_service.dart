import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants.dart';
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';

class MemberStatementService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;
  static final _moneyFormat = NumberFormat('#,###', 'en_US');

  static String _money(num amount) => _moneyFormat.format(amount.round());

  /// Generate and print/save member statement PDF
  static Future<void> generateMemberStatement({
    required String memberId,
    required Map<String, dynamic> memberData,
    bool printDirectly = false,
  }) async {
    try {
      // Fetch all member financial data
      final loans = await _getMemberLoans(memberId);
      final savingsTxns = await _getSavingsTransactions(memberId);
      final sharesTxns = await _getSharesTransactions(memberId);
      final loanRepayments = await _getLoanRepayments(memberId);

      // Generate PDF
      final pdf = await _buildStatementPDF(
        memberData: memberData,
        loans: loans,
        savingsTxns: savingsTxns,
        sharesTxns: sharesTxns,
        loanRepayments: loanRepayments,
      );

      if (printDirectly) {
        // Print directly
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
        );
      } else {
        // Save to file and share
        await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'statement_${memberData['accountNumber']}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );
      }
    } catch (e) {
      print('❌ Error generating member statement: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> _getMemberLoans(String memberId) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('memberId', isEqualTo: memberId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      print('⚠️ Error fetching member loans: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getSavingsTransactions(String memberId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _db
          .collection(AppConstants.savingsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('memberId', isEqualTo: memberId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('⚠️ Error fetching savings transactions: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getSharesTransactions(String memberId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _db
          .collection(AppConstants.sharesCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('memberId', isEqualTo: memberId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('⚠️ Error fetching shares transactions: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getLoanRepayments(String memberId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await _db
          .collection(AppConstants.repaymentsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('memberId', isEqualTo: memberId)
          .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('paymentDate', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'paymentDate': (data['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('⚠️ Error fetching loan repayments: $e');
      return [];
    }
  }

  static Future<pw.Document> _buildStatementPDF({
    required Map<String, dynamic> memberData,
    required List<Map<String, dynamic>> loans,
    required List<Map<String, dynamic>> savingsTxns,
    required List<Map<String, dynamic>> sharesTxns,
    required List<Map<String, dynamic>> loanRepayments,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final saccoName = SaccoService.current.saccoName;

    // Load fonts for better text rendering
    final boldFont = await PdfGoogleFonts.interBold();
    final regularFont = await PdfGoogleFonts.interRegular();

    // Calculate totals
    final savingsBalance = (memberData['savingsBalance'] ?? 0).toDouble();
    final sharesBalance = (memberData['sharesBalance'] ?? 0).toDouble();
    final walletBalance = (memberData['walletBalance'] ?? 0).toDouble();
    
    final activeLoans = loans.where((l) => l['status'] == 'active').toList();
    final totalLoanOutstanding = activeLoans.fold<double>(
      0,
      (sum, loan) => sum + ((loan['principalOutstanding'] ?? 0) as num).toDouble() +
          ((loan['interestOutstanding'] ?? 0) as num).toDouble(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          _buildHeader(saccoName, boldFont, regularFont),
          pw.SizedBox(height: 20),

          // Member Details
          _buildMemberDetails(memberData, regularFont, boldFont),
          pw.SizedBox(height: 20),

          // Account Summary
          _buildAccountSummary(
            savingsBalance,
            sharesBalance,
            walletBalance,
            activeLoans.length,
            totalLoanOutstanding,
            regularFont,
            boldFont,
          ),
          pw.SizedBox(height: 20),

          // Active Loans
          if (activeLoans.isNotEmpty) ...[
            _buildSectionTitle('ACTIVE LOANS', boldFont),
            pw.SizedBox(height: 10),
            _buildLoansTable(activeLoans, regularFont, boldFont),
            pw.SizedBox(height: 20),
          ],

          // Recent Transactions
          _buildSectionTitle('RECENT TRANSACTIONS (Last 30 Days)', boldFont),
          pw.SizedBox(height: 10),
          _buildTransactionsTable(
            savingsTxns,
            sharesTxns,
            loanRepayments,
            regularFont,
            boldFont,
          ),
          pw.SizedBox(height: 30),

          // Footer
          _buildFooter(now, regularFont),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildHeader(String saccoName, pw.Font boldFont, pw.Font regularFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#059669'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            saccoName.toUpperCase(),
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 24,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'MEMBER ACCOUNT STATEMENT',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 14,
              color: PdfColor.fromHex('#FFFFFF99'),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMemberDetails(
    Map<String, dynamic> memberData,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Member Name:', memberData['name'] ?? 'N/A', regularFont, boldFont),
              pw.SizedBox(height: 5),
              _buildDetailRow('Account Number:', memberData['accountNumber'] ?? 'N/A', regularFont, boldFont),
              pw.SizedBox(height: 5),
              _buildDetailRow('Member Number:', memberData['memberNumber'] ?? 'N/A', regularFont, boldFont),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Phone:', memberData['phone'] ?? 'N/A', regularFont, boldFont),
              pw.SizedBox(height: 5),
              _buildDetailRow('Email:', memberData['email'] ?? 'N/A', regularFont, boldFont),
              pw.SizedBox(height: 5),
              _buildDetailRow('Statement Date:', DateFormat('MMM dd, yyyy').format(DateTime.now()), regularFont, boldFont),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value, pw.Font regularFont, pw.Font boldFont) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColor.fromHex('#6B7280')),
        ),
        pw.SizedBox(width: 5),
        pw.Text(
          value,
          style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColor.fromHex('#111827')),
        ),
      ],
    );
  }

  static pw.Widget _buildAccountSummary(
    double savingsBalance,
    double sharesBalance,
    double walletBalance,
    int activeLoansCount,
    double totalLoanOutstanding,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F3F4F6'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ACCOUNT SUMMARY',
            style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColor.fromHex('#111827')),
          ),
          pw.Divider(color: PdfColor.fromHex('#D1D5DB'), thickness: 1),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Savings Balance', 'UGX ${_money(savingsBalance)}', regularFont, boldFont, PdfColor.fromHex('#059669')),
              _buildSummaryItem('Shares Balance', 'UGX ${_money(sharesBalance)}', regularFont, boldFont, PdfColor.fromHex('#2563EB')),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Wallet Balance', 'UGX ${_money(walletBalance)}', regularFont, boldFont, PdfColor.fromHex('#7C3AED')),
              _buildSummaryItem('Active Loans', activeLoansCount.toString(), regularFont, boldFont, PdfColor.fromHex('#DC2626')),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FEE2E2'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Loan Outstanding',
                  style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColor.fromHex('#DC2626')),
                ),
                pw.Text(
                  'UGX ${_money(totalLoanOutstanding)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColor.fromHex('#DC2626')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value, pw.Font regularFont, pw.Font boldFont, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: regularFont, fontSize: 9, color: PdfColor.fromHex('#6B7280')),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(font: boldFont, fontSize: 11, color: color),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 2)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColor.fromHex('#111827')),
      ),
    );
  }

  static pw.Widget _buildLoansTable(List<Map<String, dynamic>> loans, pw.Font regularFont, pw.Font boldFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
          children: [
            _buildTableHeader('Loan Type', boldFont),
            _buildTableHeader('Reference', boldFont),
            _buildTableHeader('Disbursed', boldFont),
            _buildTableHeader('Outstanding', boldFont),
            _buildTableHeader('Status', boldFont),
          ],
        ),
        // Rows
        ...loans.map((loan) => pw.TableRow(
              children: [
                _buildTableCell(loan['loanType']?.toString() ?? 'N/A', regularFont),
                _buildTableCell(loan['referenceNumber']?.toString() ?? 'N/A', regularFont),
                _buildTableCell('UGX ${_money((loan['principalDisbursed'] ?? 0) as num)}', regularFont),
                _buildTableCell(
                  'UGX ${_money((loan['principalOutstanding'] ?? 0) as num + (loan['interestOutstanding'] ?? 0) as num)}',
                  regularFont,
                ),
                _buildTableCell(loan['status']?.toString().toUpperCase() ?? 'N/A', regularFont),
              ],
            )),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable(
    List<Map<String, dynamic>> savingsTxns,
    List<Map<String, dynamic>> sharesTxns,
    List<Map<String, dynamic>> loanRepayments,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    // Combine all transactions
    final allTxns = <Map<String, dynamic>>[];

    for (final txn in savingsTxns) {
      allTxns.add({
        'date': txn['timestamp'],
        'type': txn['type'] == 'deposit' ? 'Savings Deposit' : 'Savings Withdrawal',
        'amount': txn['amount'],
        'isCredit': txn['type'] == 'deposit',
      });
    }

    for (final txn in sharesTxns) {
      allTxns.add({
        'date': txn['timestamp'],
        'type': 'Shares Purchase',
        'amount': txn['amount'],
        'isCredit': true,
      });
    }

    for (final txn in loanRepayments) {
      allTxns.add({
        'date': txn['paymentDate'],
        'type': 'Loan Payment',
        'amount': txn['amount'],
        'isCredit': true,
      });
    }

    // Sort by date
    allTxns.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    if (allTxns.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text(
            'No transactions in the last 30 days',
            style: pw.TextStyle(font: regularFont, fontSize: 10, color: PdfColor.fromHex('#6B7280')),
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.5),
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F9FAFB')),
          children: [
            _buildTableHeader('Date', boldFont),
            _buildTableHeader('Transaction Type', boldFont),
            _buildTableHeader('Amount', boldFont),
          ],
        ),
        // Rows
        ...allTxns.take(30).map((txn) {
          final isCredit = txn['isCredit'] as bool;
          return pw.TableRow(
            children: [
              _buildTableCell(DateFormat('MMM dd, yyyy').format(txn['date'] as DateTime), regularFont),
              _buildTableCell(txn['type'] as String, regularFont),
              _buildTableCell(
                '${isCredit ? '+' : '-'} UGX ${_money((txn['amount'] ?? 0) as num)}',
                regularFont,
                color: isCredit ? PdfColor.fromHex('#059669') : PdfColor.fromHex('#DC2626'),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColor.fromHex('#111827')),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font regularFont, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: regularFont,
          fontSize: 9,
          color: color ?? PdfColor.fromHex('#374151'),
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(DateTime date, pw.Font regularFont) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromHex('#E5E7EB')),
        pw.SizedBox(height: 10),
        pw.Text(
          'This statement was generated on ${DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(date)}',
          style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColor.fromHex('#6B7280')),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'For inquiries, please contact your SACCO office.',
          style: pw.TextStyle(font: regularFont, fontSize: 8, color: PdfColor.fromHex('#6B7280')),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
}

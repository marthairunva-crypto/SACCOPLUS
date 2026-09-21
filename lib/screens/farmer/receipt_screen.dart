import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> repayment;
  final String farmerName;

  const ReceiptScreen({
    super.key,
    required this.repayment,
    required this.farmerName,
  });

  String get _transactionId => repayment['marzUuid'] as String? ?? repayment['id'] as String? ?? '—';
  String get _reference => repayment['marzReference'] as String? ?? '—';
  String get _phone => repayment['phone'] as String? ?? '—';
  String get _purpose => repayment['purpose'] as String? ?? '—';
  String get _provider {
    final p = repayment['provider'] as String?;
    if (p == 'mtn') return 'MTN Mobile Money';
    if (p == 'airtel') return 'Airtel Money';
    return 'Mobile Money';
  }
  String get _date => repayment['dateStr'] as String? ?? DateFormat('MMM d, yyyy').format(DateTime.now());
  int get _amount => (repayment['amount'] as num?)?.toInt() ?? 0;

  String get _qrData =>
      'TXN:$_transactionId|REF:$_reference|AMT:UGX $_amount|PHONE:$_phone|DATE:$_date';

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Colors.white),
            tooltip: 'Print / Save PDF',
            onPressed: () => _printReceipt(context, fmt),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Receipt card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryDark, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 10),
                        Text('Payment Successful',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(AppConstants.appName,
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),

                  // Amount
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Text('Amount Paid',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text('UGX ${fmt.format(_amount)}',
                            style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary)),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1),
                  ),

                  // Details
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _receiptRow('Member', farmerName),
                        _receiptRow('Purpose', _purpose),
                        _receiptRow('Network', _provider),
                        _receiptRow('Phone', _phone),
                        _receiptRow('Date', _date),
                        _receiptRow('Transaction ID', _transactionId,
                            small: true),
                        _receiptRow('Reference', _reference, small: true),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1),
                  ),

                  // QR Code
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Scan to Verify',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 160,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${AppConstants.appName} • ${AppConstants.companyName}',
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: Colors.grey.shade400),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Print button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _printReceipt(context, fmt),
                icon: const Icon(Icons.print_rounded),
                label: Text('Print / Save as PDF',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: small ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context, NumberFormat fmt) async {
    final pdf = pw.Document();

    // Generate QR code bytes
    final qrImage = await QrPainter(
      data: _qrData,
      version: QrVersions.auto,
      gapless: true,
    ).toImageData(200);
    final qrBytes = qrImage?.buffer.asUint8List() ?? Uint8List(0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm, // 80mm thermal width
          double.infinity,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(AppConstants.appName,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppConstants.appSubtitle,
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Text('PAYMENT RECEIPT',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('UGX ${fmt.format(_amount)}',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 4),
              _pdfRow('Member', farmerName),
              _pdfRow('Purpose', _purpose),
              _pdfRow('Network', _provider),
              _pdfRow('Phone', _phone),
              _pdfRow('Date', _date),
              _pdfRow('Txn ID', _transactionId),
              _pdfRow('Reference', _reference),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (qrBytes.isNotEmpty)
                pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(qrBytes),
                    width: 100,
                    height: 100,
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text('Scan to verify transaction',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Text('Thank you for your payment!',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(AppConstants.appSubtitle,
                  style: const pw.TextStyle(fontSize: 7)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Receipt_${_transactionId.length >= 8 ? _transactionId.substring(0, 8) : _transactionId}.pdf',
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 55,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

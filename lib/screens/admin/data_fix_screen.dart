import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../scripts/fix_loan_outstanding_fields.dart';

/// Admin screen for running data fixes and migrations
class DataFixScreen extends StatefulWidget {
  const DataFixScreen({Key? key}) : super(key: key);

  @override
  State<DataFixScreen> createState() => _DataFixScreenState();
}

class _DataFixScreenState extends State<DataFixScreen> {
  bool _isRunning = false;
  String _status = 'Ready to fix loan outstanding fields';
  Map<String, int>? _results;

  Future<void> _runFix() async {
    setState(() {
      _isRunning = true;
      _status = 'Running fix... Please wait...';
      _results = null;
    });

    try {
      final results = await FixLoanOutstandingFields.fixAllLoans();
      
      setState(() {
        _isRunning = false;
        _status = 'Fix completed successfully!';
        _results = results;
      });
    } catch (e) {
      setState(() {
        _isRunning = false;
        _status = 'Error: $e';
        _results = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Fixes', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF059669),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Outstanding Fields Fix',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This tool fixes inconsistent outstanding balance calculations across all loans.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'What it does:',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _bulletPoint('Recalculates principalOutstanding, interestOutstanding, chargesOutstanding'),
            _bulletPoint('Sets remainingBalance, totalOutstanding, outstanding'),
            _bulletPoint('Ensures all payment fields are consistent'),
            _bulletPoint('Safe to run multiple times'),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isRunning 
                    ? Colors.blue[50]
                    : (_results != null 
                        ? Colors.green[50] 
                        : Colors.grey[100]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isRunning 
                      ? Colors.blue[200]! 
                      : (_results != null 
                          ? Colors.green[200]! 
                          : Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isRunning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          _results != null ? Icons.check_circle : Icons.info_outline,
                          color: _results != null ? Colors.green : Colors.blue,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_results != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _resultRow('Total Loans', _results!['total'].toString()),
                    _resultRow('Fixed', _results!['fixed'].toString(), Colors.green),
                    _resultRow('Already Correct', _results!['skipped'].toString(), Colors.blue),
                    if (_results!['errors']! > 0)
                      _resultRow('Errors', _results!['errors'].toString(), Colors.red),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isRunning ? null : _runFix,
              icon: const Icon(Icons.build),
              label: Text(
                'Run Fix',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

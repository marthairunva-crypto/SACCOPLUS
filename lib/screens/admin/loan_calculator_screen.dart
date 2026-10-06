import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';
import '../../theme/modern_theme.dart';
import '../../utils/file_saver.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amountController = TextEditingController();
  final _interestController = TextEditingController(text: '15');
  final _durationController = TextEditingController(text: '12');
  
  String _interestType = 'yearly'; // 'yearly' or 'monthly'
  
  double _monthlyPayment = 0;
  double _totalPayment = 0;
  double _totalInterest = 0;
  List<Map<String, dynamic>> _amortizationSchedule = [];
  
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  void _calculate() {
    final principal = double.tryParse(_amountController.text) ?? 0;
    final interestInput = double.tryParse(_interestController.text) ?? 0;
    final months = int.tryParse(_durationController.text) ?? 0;

    if (principal <= 0 || months <= 0) {
      setState(() {
        _monthlyPayment = 0;
        _totalPayment = 0;
        _totalInterest = 0;
        _amortizationSchedule = [];
      });
      return;
    }

    // Calculate monthly interest rate based on type
    double monthlyRate;
    if (_interestType == 'monthly') {
      monthlyRate = interestInput / 100;
    } else {
      monthlyRate = interestInput / 100 / 12;
    }
    
    // Calculate monthly payment using amortization formula
    double monthlyPayment;
    if (monthlyRate == 0) {
      monthlyPayment = principal / months;
    } else {
      final powValue = pow(1 + monthlyRate, months).toDouble();
      monthlyPayment = principal * (monthlyRate * powValue) / (powValue - 1);
    }

    final totalPayment = monthlyPayment * months;
    final totalInterest = totalPayment - principal;

    // Generate amortization schedule
    final schedule = <Map<String, dynamic>>[];
    double balance = principal;

    for (int i = 1; i <= months; i++) {
      final interestPayment = balance * monthlyRate;
      final principalPayment = monthlyPayment - interestPayment;
      balance -= principalPayment;

      schedule.add({
        'month': i,
        'payment': monthlyPayment,
        'principal': principalPayment,
        'interest': interestPayment,
        'balance': balance > 0 ? balance : 0,
      });
    }

    setState(() {
      _monthlyPayment = monthlyPayment;
      _totalPayment = totalPayment;
      _totalInterest = totalInterest;
      _amortizationSchedule = schedule;
    });
  }

  Future<void> _exportToPDF() async {
    // Create CSV content for download
    final csvContent = _generateCSV();
    await FileSaver.saveFile(
      fileName: 'loan_amortization_${DateTime.now().millisecondsSinceEpoch}.csv',
      content: csvContent,
      mimeType: 'text/csv',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exported as CSV'), backgroundColor: Colors.green),
    );
  }

  Future<void> _exportToExcel() async {
    // Export as CSV which can be opened in Excel
    final csvContent = _generateCSV();
    await FileSaver.saveFile(
      fileName: 'loan_schedule_${DateTime.now().millisecondsSinceEpoch}.csv',
      content: csvContent,
      mimeType: 'text/csv',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exported for Excel'), backgroundColor: Colors.green),
    );
  }

  String _generateCSV() {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Loan Amortization Schedule');
    buffer.writeln('Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln('Loan Amount,${_amountController.text}');
    buffer.writeln('Interest Rate,${_interestController.text}% ${_interestType == "monthly" ? "per month" : "per year"}');
    buffer.writeln('Duration,${_durationController.text} months');
    buffer.writeln('Monthly Payment,${_monthlyPayment.toStringAsFixed(2)}');
    buffer.writeln('Total Payment,${_totalPayment.toStringAsFixed(2)}');
    buffer.writeln('Total Interest,${_totalInterest.toStringAsFixed(2)}');
    buffer.writeln('');
    
    // Schedule table
    buffer.writeln('Month,Payment,Principal,Interest,Balance');
    for (var item in _amortizationSchedule) {
      buffer.writeln('${item['month']},'
          '${item['payment'].toStringAsFixed(2)},'
          '${item['principal'].toStringAsFixed(2)},'
          '${item['interest'].toStringAsFixed(2)},'
          '${item['balance'].toStringAsFixed(2)}');
    }
    
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Loan Calculator', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_amortizationSchedule.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportToPDF,
              tooltip: 'Export as CSV',
            ),
            IconButton(
              icon: const Icon(Icons.table_chart),
              onPressed: _exportToExcel,
              tooltip: 'Export for Excel',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loan Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Loan Amount (UGX)',
                      prefixIcon: const Icon(Icons.money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _interestController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Interest Rate (%)',
                            prefixIcon: const Icon(Icons.percent),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => _calculate(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _interestType,
                          decoration: InputDecoration(
                            labelText: 'Period',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'yearly', child: Text('Per Year', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'monthly', child: Text('Per Month', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (value) {
                            setState(() => _interestType = value!);
                            _calculate();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (Months)',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'For short-term loans, use 1-6 months',
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Calculate'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_monthlyPayment > 0) ...[
              const SizedBox(height: 24),

              // Results Summary
              Text(
                'Calculation Results',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildResultCard(
                      'Monthly Payment',
                      _currencyFormat.format(_monthlyPayment),
                      Icons.payments,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildResultCard(
                      'Total Payment',
                      _currencyFormat.format(_totalPayment),
                      Icons.account_balance_wallet,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                'Total Interest',
                _currencyFormat.format(_totalInterest),
                Icons.trending_up,
                Colors.orange,
                fullWidth: true,
              ),

              const SizedBox(height: 24),

              // Amortization Schedule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amortization Schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportToPDF,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('CSV'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _exportToExcel,
                        icon: const Icon(Icons.table_chart, size: 18),
                        label: const Text('Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ModernTheme.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Month',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Payment',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Principal',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Interest',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Balance',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Schedule rows
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _amortizationSchedule.length,
                      itemBuilder: (context, index) {
                        final item = _amortizationSchedule[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  '${item['month']}',
                                  style: GoogleFonts.poppins(fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currencyFormat.format(item['payment']),
                                  style: GoogleFonts.poppins(fontSize: 11),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currencyFormat.format(item['principal']),
                                  style: GoogleFonts.poppins(fontSize: 11),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currencyFormat.format(item['interest']),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.orange,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _currencyFormat.format(item['balance']),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

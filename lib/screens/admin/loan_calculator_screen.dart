import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../theme/modern_theme.dart';

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amountController = TextEditingController();
  final _interestController = TextEditingController(text: '15');
  final _durationController = TextEditingController(text: '12');
  
  double _monthlyPayment = 0;
  double _totalPayment = 0;
  double _totalInterest = 0;
  List<Map<String, dynamic>> _amortizationSchedule = [];
  
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  void _calculate() {
    final principal = double.tryParse(_amountController.text) ?? 0;
    final annualRate = double.tryParse(_interestController.text) ?? 0;
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

    // Monthly interest rate
    final monthlyRate = annualRate / 100 / 12;
    
    // Calculate monthly payment using amortization formula
    double monthlyPayment;
    if (monthlyRate == 0) {
      monthlyPayment = principal / months;
    } else {
      monthlyPayment = principal * (monthlyRate * pow(1 + monthlyRate, months)) / 
                      (pow(1 + monthlyRate, months) - 1);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Loan Calculator', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
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
                  TextField(
                    controller: _interestController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Annual Interest Rate (%)',
                      prefixIcon: const Icon(Icons.percent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (Months)',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              Text(
                'Amortization Schedule',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
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

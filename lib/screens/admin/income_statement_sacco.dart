import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';

/// Professional Income Statement matching SACCO paper format
/// 
/// Format:
/// INCOME
///   - BAL B/F, PRINCIPLE, INTEREST, SAVINGS, LOAN FORMS, MEMBERSHIP, 
///     STATIONERY, SHARES, PENALTIES
///   - TOTAL
/// EXPENDITURE  
///   - All expense line items
///   - TOTAL
/// BALANCE C/D (Surplus/Deficit)
class IncomeStatementSACCO extends StatefulWidget {
  const IncomeStatementSACCO({super.key});

  @override
  State<IncomeStatementSACCO> createState() => _IncomeStatementSACCOState();
}

class _IncomeStatementSACCOState extends State<IncomeStatementSACCO> {
  final fmt = NumberFormat('#,###', 'en_US');
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  Map<String, dynamic>? reportData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final data = await _fetchIncomeStatementData(
        selectedDate.year,
        selectedDate.month,
      );
      setState(() {
        reportData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load data: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchIncomeStatementData(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    
    final db = FirebaseFirestore.instance;
    final tenantId = FirebaseService.sessionTenantId;

    // Get all transactions for the month
    final txnSnapshot = await db
        .collection('saccoplus-transactions')
        .where('tenantId', isEqualTo: tenantId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    // Initialize income and expense maps
    final income = <String, double>{
      'balBF': 0.0,
      'principle': 0.0,
      'interest': 0.0,
      'savings': 0.0,
      'loanForms': 0.0,
      'membership': 0.0,
      'stationery': 0.0,
      'shares': 0.0,
      'penalties': 0.0,
    };

    final expenses = <String, double>{};

    // Process transactions
    for (final doc in txnSnapshot.docs) {
      final data = doc.data();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final source = (data['source'] ?? '').toString().toLowerCase();
      final amount = (data['amount'] ?? 0).toDouble();

      // Income categorization
      if (type == 'income' || type == 'credit') {
        // Interest from loan repayments
        if (category.contains('interest') || source.contains('interest')) {
          income['interest'] = (income['interest'] ?? 0) + amount;
        }
        // Loan forms/application fees
        else if (source.contains('loan application') || source.contains('loan form') || 
                 category.contains('loan forms')) {
          income['loanForms'] = (income['loanForms'] ?? 0) + amount;
        }
        // Membership fees
        else if (source.contains('membership') || category.contains('membership')) {
          income['membership'] = (income['membership'] ?? 0) + amount;
        }
        // Stationery fees
        else if (source.contains('stationery') || category.contains('stationery')) {
          income['stationery'] = (income['stationery'] ?? 0) + amount;
        }
        // Share purchases
        else if (source.contains('share') || category.contains('share')) {
          income['shares'] = (income['shares'] ?? 0) + amount;
        }
        // Penalties
        else if (source.contains('penalty') || source.contains('penalties') || 
                 category.contains('penalty')) {
          income['penalties'] = (income['penalties'] ?? 0) + amount;
        }
        // Savings deposits
        else if (type.contains('deposit') || category.contains('savings')) {
          income['savings'] = (income['savings'] ?? 0) + amount;
        }
      }
      
      // Expense categorization
      else if (type == 'expense' || type == 'debit') {
        final expenseCategory = category.isNotEmpty ? category : 'Other';
        expenses[expenseCategory] = (expenses[expenseCategory] ?? 0) + amount;
      }
    }

    // Get opening balance (previous month's closing balance)
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    // For now, set to 0. In production, this should be fetched from previous month's statement
    income['balBF'] = 0.0;

    // Get principle (loans disbursed)
    final loansSnapshot = await db
        .collection('saccoplus-loans')
        .where('tenantId', isEqualTo: tenantId)
        .where('disbursedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('disbursedDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('status', isEqualTo: 'Active')
        .get();

    double totalDisbursed = 0.0;
    for (final doc in loansSnapshot.docs) {
      totalDisbursed += (doc.data()['amount'] ?? 0).toDouble();
    }
    income['principle'] = totalDisbursed;

    return {
      'income': income,
      'expenses': expenses,
      'month': month,
      'year': year,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          'Income Statement',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: reportData != null ? _exportPDF : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Period:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(selectedDate),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Statement content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : reportData == null
                    ? Center(
                        child: Text(
                          'No data available',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : _buildStatement(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatement() {
    final income = reportData!['income'] as Map<String, double>;
    final expenses = reportData!['expenses'] as Map<String, double>;

    final totalIncome = income.values.fold<double>(0.0, (sum, val) => sum + val);
    final totalExpenses = expenses.values.fold<double>(0.0, (sum, val) => sum + val);
    final balance = totalIncome - totalExpenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Text(
                    'MBADIFA SACCO',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'INCOME STATEMENT AS AT ${DateFormat('d').format(DateTime(reportData!['year'], reportData!['month'] + 1, 0))}${_getOrdinal(int.parse(DateFormat('d').format(DateTime(reportData!['year'], reportData!['month'] + 1, 0))))} ${DateFormat('MMMM yyyy').format(DateTime(reportData!['year'], reportData!['month']))} '.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Income section
            _buildSection('INCOME', [
              _LineItem('BAL B/F', income['balBF']!),
              _LineItem('PRINCIPLE', income['principle']!),
              _LineItem('INTEREST', income['interest']!),
              _LineItem('SAVINGS', income['savings']!),
              _LineItem('LOAN FORMS', income['loanForms']!),
              _LineItem('MEMBERSHIP', income['membership']!),
              _LineItem('STATIONERY', income['stationery']!),
              _LineItem('SHARES', income['shares']!),
              _LineItem('PENALTIES', income['penalties']!),
            ], totalIncome),

            const Divider(height: 1, thickness: 2),

            // Expenditure section
            _buildSection('EXPENDITURE', 
              expenses.entries.map((e) => _LineItem(e.key.toUpperCase(), e.value)).toList(),
              totalExpenses,
            ),

            const Divider(height: 1, thickness: 2),

            // Balance
            Container(
              padding: const EdgeInsets.all(16),
              color: balance >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BALANCE C/D',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'UGX ${fmt.format(balance.abs())}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: balance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<_LineItem> items, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey.shade200,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...items.map((item) => _buildLineItem(item.label, item.amount)),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: const Border(
              top: BorderSide(width: 2, color: Colors.black),
              bottom: BorderSide(width: 2, color: Colors.black),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'UGX ${fmt.format(total)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineItem(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          Text(
            fmt.format(amount),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month);
      });
      _loadData();
    }
  }

  Future<void> _exportPDF() async {
    // Implementation similar to other PDF exports
    _showError('PDF export coming soon');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _getOrdinal(int day) {
    if (day >= 11 && day <= 13) return 'TH';
    switch (day % 10) {
      case 1:
        return 'ST';
      case 2:
        return 'ND';
      case 3:
        return 'RD';
      default:
        return 'TH';
    }
  }
}

class _LineItem {
  final String label;
  final double amount;
  _LineItem(this.label, this.amount);
}

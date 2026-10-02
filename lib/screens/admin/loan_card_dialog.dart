import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' show pow;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/arrears_service.dart';
import '../../core/firebase_service.dart';

class LoanCardDialog extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic> loanData;

  const LoanCardDialog({
    Key? key,
    required this.loanId,
    required this.loanData,
  }) : super(key: key);

  @override
  State<LoanCardDialog> createState() => _LoanCardDialogState();
}

class _LoanCardDialogState extends State<LoanCardDialog> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  bool _isEditing = false;
  bool _isLoadingArrears = true;
  bool _showPenaltyManager = false;
  Map<String, dynamic>? _arrearsData;
  String _selectedFeeType = 'application';
  
  late TextEditingController _principalCtrl;
  late TextEditingController _interestRateCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _disbursementDateCtrl;
  late TextEditingController _manualArrearsCtrl;
  late TextEditingController _manualPenaltyCtrl;
  late TextEditingController _penaltyReasonCtrl;
  late TextEditingController _feeAmountCtrl;
  late TextEditingController _feeRateCtrl;
  late TextEditingController _customFeeTypeCtrl;
  late TextEditingController _paymentAmountCtrl;
  late TextEditingController _principalOutstandingCtrl;
  late TextEditingController _interestOutstandingCtrl;
  String _interestMethod = 'flat';
  String _paymentFrequency = 'monthly';
  DateTime? _disbursementDate;
  
  // Guarantor controllers
  final List<Map<String, TextEditingController>> _guarantors = [];
  
  @override
  void initState() {
    super.initState();
    
    // Debug logging
    print('=== LOAN CARD DIALOG INIT ===');
    print('Received LoanID: ${widget.loanId}');
    print('Received Member Name: ${widget.loanData['memberName']}');
    print('Received Amount: ${widget.loanData['loanAmount']}');
    print('Received Outstanding: ${widget.loanData['principalOutstanding']}');
    print('============================');
    
    _principalCtrl = TextEditingController(
      text: (widget.loanData['loanAmount'] ?? 0).toString()
    );
    _interestRateCtrl = TextEditingController(
      text: (widget.loanData['interestRate'] ?? 0).toString()
    );
    _durationCtrl = TextEditingController(
      text: (widget.loanData['duration'] ?? 12).toString()
    );
    _interestMethod = widget.loanData['interestMethod'] ?? 'flat';
    _paymentFrequency = widget.loanData['paymentFrequency'] ?? 'monthly';
    
    // Initialize outstanding balance controllers
    _principalOutstandingCtrl = TextEditingController(
      text: (widget.loanData['principalOutstanding'] ?? 0).toString()
    );
    _interestOutstandingCtrl = TextEditingController(
      text: (widget.loanData['interestOutstanding'] ?? widget.loanData['interestOriginalBalance'] ?? 0).toString()
    );
    
    // Initialize fee controllers
    _feeAmountCtrl = TextEditingController();
    _feeRateCtrl = TextEditingController();
    _customFeeTypeCtrl = TextEditingController();
    
    // Calculate and auto-fill expected payment based on frequency
    final expectedPayment = _calculateExpectedPayment();
    _paymentAmountCtrl = TextEditingController(
      text: expectedPayment > 0 ? expectedPayment.round().toString() : ''
    );
    
    // Initialize manual penalty controllers
    _manualArrearsCtrl = TextEditingController(
      text: (widget.loanData['manualArrears'] ?? 0).toString()
    );
    _manualPenaltyCtrl = TextEditingController(
      text: (widget.loanData['manualPenalty'] ?? 0).toString()
    );
    _penaltyReasonCtrl = TextEditingController(
      text: widget.loanData['penaltyReason'] ?? ''
    );
    
    // Parse disbursement date
    if (widget.loanData['disbursementDate'] is Timestamp) {
      _disbursementDate = (widget.loanData['disbursementDate'] as Timestamp).toDate();
    } else if (widget.loanData['disbursedAt'] is Timestamp) {
      _disbursementDate = (widget.loanData['disbursedAt'] as Timestamp).toDate();
    }
    
    _disbursementDateCtrl = TextEditingController(
      text: _disbursementDate != null 
        ? DateFormat('MMM dd, yyyy').format(_disbursementDate!)
        : 'Not set'
    );
    
    // Initialize guarantors
    final guarantorsList = widget.loanData['guarantors'] as List? ?? [];
    if (guarantorsList.isEmpty) {
      // Add 2 empty guarantor slots
      for (int i = 0; i < 2; i++) {
        _guarantors.add({
          'name': TextEditingController(),
          'account': TextEditingController(),
          'savings': TextEditingController(),
        });
      }
    } else {
      for (var g in guarantorsList) {
        _guarantors.add({
          'name': TextEditingController(text: g['name'] ?? ''),
          'account': TextEditingController(text: g['account'] ?? ''),
          'savings': TextEditingController(text: g['savings']?.toString() ?? ''),
        });
      }
    }
    
    // Load arrears data
    _loadArrearsData();
  }
  
  Future<void> _loadArrearsData() async {
    setState(() => _isLoadingArrears = true);
    final arrearsData = await ArrearsService.calculateLoanArrears(widget.loanId);
    setState(() {
      _arrearsData = arrearsData;
      _isLoadingArrears = false;
    });
  }
  
  /// Calculate expected payment based on loan amount, interest, duration, and payment frequency
  double _calculateExpectedPayment() {
    try {
      final principal = (widget.loanData['loanAmount'] ?? widget.loanData['amount'] ?? 0).toDouble();
      final interestRate = (widget.loanData['interestRate'] ?? 0).toDouble();
      final duration = (widget.loanData['duration'] ?? 12).toInt();
      final interestMethod = widget.loanData['interestMethod'] ?? 'flat';
      final paymentFrequency = widget.loanData['paymentFrequency'] ?? 'monthly';
      
      if (principal <= 0 || duration <= 0) return 0;
      
      double totalInterest = 0;
      
      // Calculate interest based on method
      if (interestMethod == 'reducing') {
        // Reducing balance: use amortization formula
        final r = interestRate / 100;
        if (r > 0) {
          final powValue = pow(1.0 + r, duration);
          final monthlyPayment = principal * r * powValue / (powValue - 1);
          totalInterest = (monthlyPayment * duration) - principal;
        }
      } else {
        // Flat rate: simple interest
        totalInterest = principal * (interestRate / 100) * duration;
      }
      
      final totalLoanAmount = principal + totalInterest;
      
      // Calculate payment based on frequency
      switch (paymentFrequency.toLowerCase()) {
        case 'daily':
          return totalLoanAmount / duration; // duration in days
        case 'weekly':
          return totalLoanAmount / duration; // duration in weeks
        case 'biweekly':
          return totalLoanAmount / (duration / 2); // duration in bi-weeks
        case 'monthly':
        default:
          return totalLoanAmount / duration; // duration in months
      }
    } catch (e) {
      print('Error calculating expected payment: $e');
      return 0;
    }
  }
  
  /// Get payment recording title based on frequency
  String _getPaymentRecordingTitle() {
    final frequency = widget.loanData['paymentFrequency'] ?? 'monthly';
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 'Record Daily Payment';
      case 'weekly':
        return 'Record Weekly Payment';
      case 'biweekly':
        return 'Record Bi-Weekly Payment';
      case 'monthly':
      default:
        return 'Record Monthly Payment';
    }
  }
  
  /// Get payment frequency label for badge
  String _getPaymentFrequencyLabel() {
    final frequency = widget.loanData['paymentFrequency'] ?? 'monthly';
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 'DAILY';
      case 'weekly':
        return 'WEEKLY';
      case 'biweekly':
        return 'BI-WEEKLY';
      case 'monthly':
      default:
        return 'MONTHLY';
    }
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _interestRateCtrl.dispose();
    _durationCtrl.dispose();
    _disbursementDateCtrl.dispose();
    _manualArrearsCtrl.dispose();
    _manualPenaltyCtrl.dispose();
    _penaltyReasonCtrl.dispose();
    _feeAmountCtrl.dispose();
    _feeRateCtrl.dispose();
    _customFeeTypeCtrl.dispose();
    _paymentAmountCtrl.dispose();
    _principalOutstandingCtrl.dispose();
    _interestOutstandingCtrl.dispose();
    for (var g in _guarantors) {
      g['name']?.dispose();
      g['account']?.dispose();
      g['savings']?.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDisbursementDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _disbursementDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      setState(() {
        _disbursementDate = date;
        _disbursementDateCtrl.text = DateFormat('MMM dd, yyyy').format(date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.loanData['memberName'] ?? 'N/A';
    final accountNumber = widget.loanData['accountNumber'] ?? 'N/A';
    final referenceNumber = widget.loanData['referenceNumber'] ?? 'N/A';
    
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    final interestRate = double.tryParse(_interestRateCtrl.text) ?? 0;
    final duration = int.tryParse(_durationCtrl.text) ?? 12;
    
    // Calculate interest based on method
    double interest;
    if (_interestMethod == 'reducing') {
      final r = interestRate / (100 * 12);
      final n = duration.toDouble();
      if (r > 0) {
        final powValue = pow(1 + r, n).toDouble();
        final monthlyPayment = principal * r * powValue / (powValue - 1);
        interest = (monthlyPayment * n) - principal;
      } else {
        interest = 0;
      }
    } else {
      interest = (principal * interestRate * duration) / (100 * 12);
    }
    
    final totalAmount = principal + interest;
    final monthlyPayment = duration > 0 ? (totalAmount / duration).toDouble() : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA69E), Color(0xFFFFB89F)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        memberName.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2C1810),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'P.O. BOX 1592, MBARARA',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF4A3428),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C1810),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOAN CARD',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF2C1810)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Card Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFB89F), Color(0xFFFFC7A0)],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Member Particulars with Passport Photo
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Member Details
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('MEMBER PARTICULARS'),
                              _buildInfoRow('NAME:', memberName),
                              _buildInfoRow('ADDRESS:', 'MBARARA'),
                              _buildInfoRow('A/C No:', accountNumber),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right: Passport Photo
                        Container(
                          width: 100,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFF2C1810), width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: widget.loanData['memberPhoto'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    widget.loanData['memberPhoto'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                                  ),
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Arrears & Penalties Section (if applicable)
                    if (_arrearsData != null && !_arrearsData!.containsKey('error'))
                      _buildArrearsSection(),
                    
                    if (_arrearsData != null && !_arrearsData!.containsKey('error'))
                      const SizedBox(height: 16),
                    
                    // Penalties Management (Teller Function)
                    _buildPenaltiesManagementSection(),
                    const SizedBox(height: 16),
                    
                    // Guarantors Section (Placeholder)
                    _buildSectionHeader('GUARANTORS PARTICULARS'),
                    _buildGuarantorsTable(),
                    
                    const SizedBox(height: 16),
                    
                    // Disbursements Table
                    _buildSectionHeader('DISBURSEMENTS'),
                    _buildDisbursementsTable(
                      principal, 
                      interest, 
                      totalAmount,
                      duration,
                      monthlyPayment,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Repayments Table
                    _buildSectionHeader('REPAYMENTS'),
                    _buildRepaymentsTable(duration, monthlyPayment, totalAmount),
                    
                    const SizedBox(height: 20),
                    
                    // Edit/Save/Print Buttons
                    if (_isEditing)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _isEditing = false),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2C1810),
                                side: const BorderSide(color: Color(0xFF2C1810)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveChanges,
                              icon: const Icon(Icons.save, size: 18),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C1810),
                                foregroundColor: Colors.white,
                              ),
                              label: const Text('Save Changes'),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit Loan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C1810),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 45),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _printLoanCard,
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('Print Card'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2C1810),
                                side: const BorderSide(color: Color(0xFF2C1810), width: 2),
                                minimumSize: const Size(double.infinity, 45),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810).withOpacity(0.1),
        border: Border.all(color: const Color(0xFF2C1810), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C1810),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2C1810),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF1A0D08),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuarantorsTable() {
    return Column(
      children: [
        Table(
          border: TableBorder.all(color: const Color(0xFF2C1810), width: 1.5),
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.2),
          },
          children: [
            _buildTableHeaderRow(['No.', 'NAME', 'A/C No.', 'SAVINGS']),
            ..._guarantors.asMap().entries.map((entry) {
              final index = entry.key;
              final g = entry.value;
              
              if (_isEditing) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextFormField(
                        controller: g['name'],
                        style: GoogleFonts.poppins(fontSize: 10),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(6),
                          border: OutlineInputBorder(),
                          hintText: 'Name',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextFormField(
                        controller: g['account'],
                        style: GoogleFonts.poppins(fontSize: 10),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(6),
                          border: OutlineInputBorder(),
                          hintText: 'A/C No.',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextFormField(
                        controller: g['savings'],
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 10),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(6),
                          border: OutlineInputBorder(),
                          hintText: 'Amount',
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                final name = g['name']!.text;
                final account = g['account']!.text;
                final savings = g['savings']!.text;
                
                return _buildTableDataRow([
                  '${index + 1}',
                  name.isEmpty ? 'Missing' : name,
                  account.isEmpty ? '-' : account,
                  savings.isEmpty ? '-' : savings,
                ]);
              }
            }).toList(),
          ],
        ),
        if (_isEditing && _guarantors.length < 4)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _guarantors.add({
                    'name': TextEditingController(),
                    'account': TextEditingController(),
                    'savings': TextEditingController(),
                  });
                });
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Guarantor'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2C1810),
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildDefaultAvatar() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_outline,
          size: 50,
          color: Colors.grey.shade400,
        ),
        Text(
          'PHOTO',
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDisbursementsTable(
    double principal,
    double interest,
    double total,
    int duration,
    double monthlyPayment,
  ) {
    // Calculate due date (disbursement date + duration months)
    DateTime? dueDate;
    int? daysOverdue;
    
    if (_disbursementDate != null) {
      dueDate = DateTime(
        _disbursementDate!.year,
        _disbursementDate!.month + duration,
        _disbursementDate!.day,
      );
      
      // Calculate days overdue if past due date
      final now = DateTime.now();
      if (now.isAfter(dueDate)) {
        daysOverdue = now.difference(dueDate).inDays;
      }
    }
    
    // Get actual outstanding from editable controllers or database
    final principalOutstanding = _isEditing 
        ? (double.tryParse(_principalOutstandingCtrl.text) ?? 0)
        : (widget.loanData['principalOutstanding'] ?? 0).toDouble();
    final interestOutstanding = _isEditing
        ? (double.tryParse(_interestOutstandingCtrl.text) ?? 0)
        : (widget.loanData['interestOutstanding'] ?? widget.loanData['interestOriginalBalance'] ?? 0).toDouble();
    final totalOutstanding = principalOutstanding + interestOutstanding;
    final totalPaid = total - totalOutstanding;
    
    return Column(
      children: [
        // Input fields when editing
        if (_isEditing) ...[
          _buildEditField('Principal (UGX):', _principalCtrl),
          _buildEditField('Interest Rate (%):', _interestRateCtrl),
          _buildEditField('Duration (months):', _durationCtrl),
          _buildEditField('Principal Outstanding (UGX):', _principalOutstandingCtrl),
          _buildEditField('Interest Outstanding (UGX):', _interestOutstandingCtrl),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Interest Method:',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _interestMethod,
                    isDense: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'flat', child: Text('Flat Rate')),
                      DropdownMenuItem(value: 'reducing', child: Text('Reducing Balance')),
                    ],
                    onChanged: (v) => setState(() => _interestMethod = v!),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment Frequency:',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _paymentFrequency,
                    isDense: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily (Emergency Loan)')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    ],
                    onChanged: (v) => setState(() => _paymentFrequency = v!),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              onTap: _pickDisbursementDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Disbursement Date',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(
                  _disbursementDateCtrl.text,
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
            ),
          ),
        ],
        
        // Outstanding Balance Summary Card (showing actual database values)
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade700, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Loan:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(total),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const Divider(height: 12, thickness: 1),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Principal Out:',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(principalOutstanding),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Interest Out:',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(interestOutstanding),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 12, thickness: 1),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOTAL OUTSTANDING:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(totalOutstanding),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 12, thickness: 1),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Paid:',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  Text(
                    _currencyFormat.format(totalPaid),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Date Information Banner (if dates exist)
        if (_disbursementDate != null && dueDate != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: daysOverdue != null && daysOverdue > 0 
                ? Colors.red.shade50 
                : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: daysOverdue != null && daysOverdue > 0 
                  ? Colors.red.shade700 
                  : Colors.green.shade700,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  daysOverdue != null && daysOverdue > 0 
                    ? Icons.error_outline 
                    : Icons.check_circle_outline,
                  color: daysOverdue != null && daysOverdue > 0 
                    ? Colors.red.shade700 
                    : Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Disbursed:',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yy').format(_disbursementDate!),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Due Date:',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yy').format(dueDate),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: daysOverdue != null && daysOverdue > 0 
                                ? Colors.red.shade700 
                                : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (daysOverdue != null && daysOverdue > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Overdue:',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$daysOverdue days',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Summary Table
        Table(
          border: TableBorder.all(color: Colors.transparent, width: 0),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1.5),
          },
          children: [
            _buildTableHeaderRow(['Date', 'Principal', 'Interest', 'TOTAL']),
            _buildTableDataRow([
              _disbursementDate != null 
                ? DateFormat('dd/MM/yy').format(_disbursementDate!)
                : 'N/A',
              _currencyFormat.format(principal),
              _currencyFormat.format(interest),
              _currencyFormat.format(total),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _buildRepaymentsTable(int duration, double monthlyPayment, double total) {
    return Table(
      border: TableBorder.all(color: const Color(0xFF2C1810), width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(2),
      },
      children: [
        _buildTableHeaderRow(['Date', 'Principal', 'Interest', 'TOTAL', 'BALANCE']),
        // Sample rows showing repayment schedule
        for (int i = 0; i < (duration < 5 ? duration : 5); i++)
          _buildTableDataRow([
            _disbursementDate != null
                ? DateFormat('dd/MM/yy').format(
                    _disbursementDate!.add(Duration(days: 30 * (i + 1))))
                : '',
            _currencyFormat.format(monthlyPayment * 0.7), // Approx principal
            _currencyFormat.format(monthlyPayment * 0.3), // Approx interest
            _currencyFormat.format(monthlyPayment),
            _currencyFormat.format(total - (monthlyPayment * (i + 1))),
          ]),
      ],
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 11),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.all(8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onChanged: (_) => setState(() {}), // Trigger recalculation
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableHeaderRow(List<String> headers) {
    return TableRow(
      decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
      children: headers.map((h) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        child: Text(
          h,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      )).toList(),
    );
  }

  TableRow _buildTableDataRow(List<String> data) {
    return TableRow(
      children: data.map((d) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 0.5),
        ),
        child: Text(
          d,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.black87,
          ),
        ),
      )).toList(),
    );
  }

  Future<void> _saveChanges() async {
    try {
      final principal = double.parse(_principalCtrl.text);
      final interestRate = double.parse(_interestRateCtrl.text);
      final duration = int.parse(_durationCtrl.text);
      final principalOutstanding = double.parse(_principalOutstandingCtrl.text);
      final interestOutstanding = double.parse(_interestOutstandingCtrl.text);
      
      // Calculate interest
      double interest;
      if (_interestMethod == 'reducing') {
        final r = interestRate / (100 * 12);
        final n = duration.toDouble();
        if (r > 0) {
          final powValue = pow(1 + r, n).toDouble();
          final monthlyPayment = principal * r * powValue / (powValue - 1);
          interest = (monthlyPayment * n) - principal;
        } else {
          interest = 0;
        }
      } else {
        interest = (principal * interestRate * duration) / (100 * 12);
      }
      
      final totalAmount = principal + interest;
      
      // Prepare guarantors data
      final guarantorsData = _guarantors.map((g) => {
        'name': g['name']!.text,
        'account': g['account']!.text,
        'savings': double.tryParse(g['savings']!.text) ?? 0,
      }).where((g) => (g['name'] as String).isNotEmpty).toList();

      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .update({
        'loanAmount': principal,
        'interestRate': interestRate,
        'interestMethod': _interestMethod,
        'paymentFrequency': _paymentFrequency,
        'duration': duration,
        'interest': interest,
        'totalAmount': totalAmount,
        'principalOutstanding': principalOutstanding,
        'interestOutstanding': interestOutstanding,
        'interestOriginalBalance': interestOutstanding,
        'disbursementDate': _disbursementDate,
        'guarantors': guarantorsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isEditing = false);
        
        // Show success dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Success',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loan card updated successfully',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Show error dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.red.shade700,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to update loan card: $e',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }
  
  Future<void> _printLoanCard() async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat('#,###', 'en_US');
    
    final memberName = widget.loanData['memberName'] ?? 'N/A';
    final accountNumber = widget.loanData['accountNumber'] ?? 'N/A';
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    final interestRate = double.tryParse(_interestRateCtrl.text) ?? 0;
    final duration = int.tryParse(_durationCtrl.text) ?? 12;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'MBADIFA SACCO',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text('P.O. BOX 1592, MBARARA', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(),
                        ),
                        child: pw.Text('LOAN CARD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Member Particulars
                pw.Text('MEMBER PARTICULARS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 8),
                pw.Text('NAME: $memberName'),
                pw.Text('A/C No: $accountNumber'),
                pw.SizedBox(height: 16),
                
                // Guarantors
                pw.Text('GUARANTORS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(),
                  headers: ['No.', 'NAME', 'A/C No.', 'SAVINGS'],
                  data: _guarantors.asMap().entries.map((e) => [
                    '${e.key + 1}',
                    e.value['name']!.text.isEmpty ? 'Missing' : e.value['name']!.text,
                    e.value['account']!.text,
                    e.value['savings']!.text,
                  ]).toList(),
                ),
                pw.SizedBox(height: 16),
                
                // Financial Details
                pw.Text('DISBURSEMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(),
                  headers: ['Principal', 'Interest Rate', 'Duration', 'Total'],
                  data: [[
                    currencyFormat.format(principal),
                    '$interestRate%',
                    '$duration months',
                    currencyFormat.format(principal * (1 + interestRate / 100)),
                  ]],
                ),
              ],
            ),
          );
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
  
  // Build Arrears Section
  Widget _buildArrearsSection() {
    if (_isLoadingArrears) {
      return const SizedBox.shrink();
    }
    
    if (_arrearsData == null || _arrearsData!.containsKey('error')) {
      return const SizedBox.shrink();
    }
    
    // Calculate due date and days overdue
    final duration = (widget.loanData['duration'] ?? 12) as int;
    DateTime? dueDate;
    int daysOverdue = 0;
    String status = 'Active';
    
    if (_disbursementDate != null) {
      dueDate = DateTime(
        _disbursementDate!.year,
        _disbursementDate!.month + duration,
        _disbursementDate!.day,
      );
      
      final now = DateTime.now();
      final difference = now.difference(dueDate).inDays;
      
      if (difference > 0) {
        daysOverdue = difference;
        status = 'Overdue';
      } else if (difference == -1) {
        status = 'Due Tomorrow';
      } else if (difference >= 0 && difference <= 7) {
        status = 'Due Soon';
      }
      
      // Check if cleared
      final totalPaid = (_arrearsData!['totalPaid'] ?? 0).toDouble();
      final totalLoanAmount = (_arrearsData!['totalLoanAmount'] ?? 0).toDouble();
      if (totalPaid >= totalLoanAmount) {
        status = 'Cleared/Settled';
      }
    }
    
    final arrearsAmount = (_arrearsData!['arrearsAmount'] ?? 0).toDouble();
    final penaltyAmount = (_arrearsData!['penaltyAmount'] ?? 0).toDouble();
    final totalDue = (_arrearsData!['totalDue'] ?? 0).toDouble();
    
    // Only show if overdue or important status
    if (status == 'Active') {
      return const SizedBox.shrink();
    }
    
    // Color based on status
    Color statusColor = Colors.green;
    Color bgColor = Colors.green.shade50;
    if (status == 'Overdue') {
      statusColor = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    } else if (status == 'Due Tomorrow' || status == 'Due Soon') {
      statusColor = Colors.orange.shade700;
      bgColor = Colors.orange.shade50;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status == 'Cleared/Settled' ? Icons.check_circle : Icons.warning,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Table with clean borders
          Table(
            border: TableBorder.all(color: Colors.transparent, width: 0),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
            },
            children: [
              if (dueDate != null) ...[
                _buildInfoTableRow('Due Date:', DateFormat('dd MMM yyyy').format(dueDate)),
                if (daysOverdue > 0)
                  _buildInfoTableRow('Days Overdue:', '$daysOverdue days', isRed: true),
              ],
              if (arrearsAmount > 0)
                _buildInfoTableRow('Arrears:', 'UGX ${_currencyFormat.format(arrearsAmount.round())}'),
              if (penaltyAmount > 0)
                _buildInfoTableRow('Penalties:', 'UGX ${_currencyFormat.format(penaltyAmount.round())}'),
              if (totalDue > 0)
                _buildInfoTableRow('Total Due:', 'UGX ${_currencyFormat.format(totalDue.round())}', isBold: true),
            ],
          ),
        ],
      ),
    );
  }
  
  TableRow _buildInfoTableRow(String label, String value, {bool isBold = false, bool isRed = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isRed ? Colors.red.shade700 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
  
  // Build Penalties Management Section
  Widget _buildPenaltiesManagementSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _showPenaltyManager = !_showPenaltyManager),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.grey.shade700, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Record Payment & Manage Fees',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    _showPenaltyManager ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Content
          if (_showPenaltyManager) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Recording Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getPaymentRecordingTitle(),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                _getPaymentFrequencyLabel(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _paymentAmountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Expected: ${_currencyFormat.format(_calculateExpectedPayment().round())}',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                            prefixText: 'UGX ',
                            prefixStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _recordPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              elevation: 0,
                            ),
                            child: Text('Record Payment', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade300, height: 1),
                  const SizedBox(height: 16),
                  
                  // Fee Type Dropdown
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fee Type', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              value: _selectedFeeType,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(value: 'application', child: Text('Application Fee', style: GoogleFonts.inter(fontSize: 12))),
                                DropdownMenuItem(value: 'insurance', child: Text('Insurance', style: GoogleFonts.inter(fontSize: 12))),
                                DropdownMenuItem(value: 'processing', child: Text('Processing Fee', style: GoogleFonts.inter(fontSize: 12))),
                                DropdownMenuItem(value: 'late_penalty', child: Text('Late Penalty', style: GoogleFonts.inter(fontSize: 12))),
                                DropdownMenuItem(value: 'default', child: Text('Default Penalty', style: GoogleFonts.inter(fontSize: 12))),
                                DropdownMenuItem(value: 'others', child: Text('Others', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
                              ],
                              onChanged: (v) => setState(() => _selectedFeeType = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rate %', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _feeRateCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: '%',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  if (_selectedFeeType == 'others') ...[
                    const SizedBox(height: 12),
                    Text('Specify Fee', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _customFeeTypeCtrl,
                      style: GoogleFonts.inter(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'e.g., Valuation Fee',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  Text('Amount', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _feeAmountCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      prefixText: 'UGX ',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text('Notes', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _penaltyReasonCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Optional notes',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _applyFeeCharge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: Text('Apply Fee', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Future<void> _applyFeeCharge() async {
    try {
      final feeAmount = double.tryParse(_feeAmountCtrl.text) ?? 0;
      final feeType = _selectedFeeType == 'others' ? _customFeeTypeCtrl.text.trim() : _selectedFeeType;
      final notes = _penaltyReasonCtrl.text.trim();
      
      if (feeAmount <= 0) {
        await _showErrorDialog('Please enter a valid fee amount');
        return;
      }
      
      if (_selectedFeeType == 'others' && _customFeeTypeCtrl.text.trim().isEmpty) {
        await _showErrorDialog('Please specify the fee type');
        return;
      }
      
      // Get fee label
      String feeLabel = '';
      switch (_selectedFeeType) {
        case 'application':
          feeLabel = 'Application Fee';
          break;
        case 'insurance':
          feeLabel = 'Insurance';
          break;
        case 'processing':
          feeLabel = 'Processing Fee';
          break;
        case 'late_penalty':
          feeLabel = 'Late Payment Penalty';
          break;
        case 'default':
          feeLabel = 'Default Penalty';
          break;
        case 'others':
          feeLabel = _customFeeTypeCtrl.text.trim();
          break;
        default:
          feeLabel = _selectedFeeType;
      }
      
      // Get existing fees or create empty array
      final loanDoc = await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .get();
      
      final existingFees = List<Map<String, dynamic>>.from(
        loanDoc.data()?['additionalFees'] ?? []
      );
      
      // Add new fee
      existingFees.add({
        'type': feeType,
        'label': feeLabel,
        'amount': feeAmount,
        'notes': notes,
        'appliedAt': Timestamp.now(),
        'appliedBy': FirebaseService.sessionProfile?['fullName'] ?? 'Admin',
      });
      
      // Update Firebase with all fees
      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .update({
        'additionalFees': existingFees,
        'totalFees': existingFees.fold<double>(0, (sum, fee) => sum + (fee['amount'] as num).toDouble()),
      });
      
      // Reload arrears data
      await _loadArrearsData();
      
      // Clear form
      _feeAmountCtrl.clear();
      _customFeeTypeCtrl.clear();
      _penaltyReasonCtrl.clear();
      setState(() => _selectedFeeType = 'application');
      
      // Show success dialog
      await _showSuccessDialog('Fee applied successfully');
      
    } catch (e) {
      await _showErrorDialog('Failed to apply fee: $e');
    }
  }
  
  Future<void> _showSuccessDialog(String message) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Success',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.red.shade600,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _recordPayment() async {
    try {
      final amount = double.tryParse(_paymentAmountCtrl.text) ?? 0;
      
      if (amount <= 0) {
        await _showErrorDialog('Please enter a valid payment amount');
        return;
      }
      
      // Add payment to subcollection
      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .collection('repayments')
          .add({
        'amount': amount,
        'timestamp': Timestamp.now(),
        'recordedBy': FirebaseService.sessionProfile?['fullName'] ?? 'Admin',
        'method': 'teller',
      });
      
      // Clear form
      _paymentAmountCtrl.clear();
      
      // Reload arrears
      await _loadArrearsData();
      
      await _showSuccessDialog('Payment recorded successfully');
      
    } catch (e) {
      await _showErrorDialog('Failed to record payment: $e');
    }
  }
}

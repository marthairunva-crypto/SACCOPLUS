import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' show pow;

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
  
  late TextEditingController _principalCtrl;
  late TextEditingController _interestRateCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _disbursementDateCtrl;
  String _interestMethod = 'flat';
  DateTime? _disbursementDate;
  
  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _interestRateCtrl.dispose();
    _durationCtrl.dispose();
    _disbursementDateCtrl.dispose();
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
        final monthlyPayment = principal * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
        interest = (monthlyPayment * n) - principal;
      } else {
        interest = 0;
      }
    } else {
      interest = (principal * interestRate * duration) / (100 * 12);
    }
    
    final totalAmount = principal + interest;
    final monthlyPayment = duration > 0 ? totalAmount / duration : 0;

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
                        'MBADIFA SACCO',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2C1810),
                        ),
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
                    // Member Particulars
                    _buildSectionHeader('MEMBER PARTICULARS'),
                    _buildInfoRow('NAME:', memberName),
                    _buildInfoRow('ADDRESS:', 'MBARARA'),
                    _buildInfoRow('A/C No:', accountNumber),
                    
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
                    
                    // Edit/Save Buttons
                    if (_isEditing)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _isEditing = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2C1810),
                              ),
                              child: const Text('Save Changes'),
                            ),
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Loan Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2C1810),
                          minimumSize: const Size(double.infinity, 45),
                        ),
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
    return Table(
      border: TableBorder.all(color: const Color(0xFF2C1810), width: 1),
      columnWidths: const {
        0: FlexColumnWidth(0.5),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        _buildTableHeaderRow(['No.', 'NAME', 'A/C No.', 'SAVINGS']),
        _buildTableDataRow(['1', '', '', '']),
        _buildTableDataRow(['2', '', '', '']),
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
    return Column(
      children: [
        // Input fields when editing
        if (_isEditing) ...[
          _buildEditField('Principal (UGX):', _principalCtrl),
          _buildEditField('Interest Rate (%):', _interestRateCtrl),
          _buildEditField('Duration (months):', _durationCtrl),
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
        
        // Summary Table
        Table(
          border: TableBorder.all(color: const Color(0xFF2C1810), width: 1),
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
      decoration: BoxDecoration(color: const Color(0xFF2C1810).withOpacity(0.15)),
      children: headers.map((h) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          h,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C1810),
          ),
        ),
      )).toList(),
    );
  }

  TableRow _buildTableDataRow(List<String> data) {
    return TableRow(
      children: data.map((d) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          d,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: const Color(0xFF1A0D08),
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
      
      // Calculate interest
      double interest;
      if (_interestMethod == 'reducing') {
        final r = interestRate / (100 * 12);
        final n = duration.toDouble();
        if (r > 0) {
          final monthlyPayment = principal * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
          interest = (monthlyPayment * n) - principal;
        } else {
          interest = 0;
        }
      } else {
        interest = (principal * interestRate * duration) / (100 * 12);
      }
      
      final totalAmount = principal + interest;

      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .update({
        'loanAmount': principal,
        'interestRate': interestRate,
        'interestMethod': _interestMethod,
        'duration': duration,
        'interest': interest,
        'totalAmount': totalAmount,
        'disbursementDate': _disbursementDate,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Loan updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

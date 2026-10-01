import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' show pow;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
  
  // Guarantor controllers
  final List<Map<String, TextEditingController>> _guarantors = [];
  
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
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _interestRateCtrl.dispose();
    _durationCtrl.dispose();
    _disbursementDateCtrl.dispose();
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
        final monthlyPayment = principal * r * pow(1 + r, n) / (pow(1 + r, n) - 1);
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
        'duration': duration,
        'interest': interest,
        'totalAmount': totalAmount,
        'disbursementDate': _disbursementDate,
        'guarantors': guarantorsData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Loan card updated successfully'),
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
}

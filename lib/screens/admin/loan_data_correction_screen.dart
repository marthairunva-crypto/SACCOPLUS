import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../services/audit_service.dart';

/// Comprehensive Loan Data Correction Screen
/// Allows editing ALL loan fields including interest rate, principal, tenure, etc.
class LoanDataCorrectionScreenEnhanced extends StatefulWidget {
  const LoanDataCorrectionScreenEnhanced({super.key});

  @override
  State<LoanDataCorrectionScreenEnhanced> createState() => _LoanDataCorrectionScreenEnhancedState();
}

class _LoanDataCorrectionScreenEnhancedState extends State<LoanDataCorrectionScreenEnhanced> {
  final _db = FirebaseFirestore.instance;
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _loans;
  List<Map<String, dynamic>>? _filteredLoans;
  bool _isLoading = true;
  String? _selectedLoanId;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .orderBy('createdAt', descending: true)
          .get();

      final newLoans = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'memberName': data['memberName'] ?? 'N/A',
          'accountNumber': data['accountNumber'] ?? 'N/A',
          'status': data['status'] ?? 'N/A',
          'loanAmount': (data['loanAmount'] ?? data['amount'] ?? 0).toDouble(),
          'interestRate': (data['interestRate'] ?? 0).toDouble(),
          'principalOutstanding': (data['principalOutstanding'] ?? 0).toDouble(),
          ...data,
        };
      }).toList();

      setState(() {
        _loans = newLoans;
        _filteredLoans = List.from(newLoans);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading loans: $e');
      setState(() {
        _loans = [];
        _filteredLoans = [];
        _isLoading = false;
      });
    }
  }

  void _filterLoans(String query) {
    if (_loans == null) return;
    setState(() {
      if (query.isEmpty) {
        _filteredLoans = List.from(_loans!);
      } else {
        final q = query.toLowerCase();
        _filteredLoans = _loans!.where((loan) {
          return loan['memberName'].toString().toLowerCase().contains(q) ||
              loan['accountNumber'].toString().toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Loan Data Correction'),
          ],
        ),
      ),
      body: Row(
        children: [
          // Left sidebar - loan list
          SizedBox(
            width: 400,
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildLoanList()),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel - edit form
          Expanded(
            child: _selectedLoanId == null
                ? _buildEmptyState()
                : _buildEditForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search loans...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: _filterLoans,
      ),
    );
  }

  Widget _buildLoanList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredLoans == null || _filteredLoans!.isEmpty) {
      return const Center(child: Text('No loans found'));
    }

    return ListView.builder(
      itemCount: _filteredLoans!.length,
      itemBuilder: (context, index) {
        final loan = _filteredLoans![index];
        final isSelected = loan['id'] == _selectedLoanId;
        
        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.blue.shade50,
          title: Text(
            loan['memberName'],
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'UGX ${_currencyFormat.format(loan['loanAmount'].round())} • ${loan['status']}',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
          onTap: () {
            setState(() => _selectedLoanId = loan['id']);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Select a loan to edit',
            style: GoogleFonts.inter(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final loan = _loans!.firstWhere((l) => l['id'] == _selectedLoanId);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: _LoanEditForm(
          key: ValueKey(_selectedLoanId), // Force rebuild when loan changes!
          loan: loan,
          onSave: () => _loadLoans(),
        ),
      ),
    );
  }
}

class _LoanEditForm extends StatefulWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onSave;

  const _LoanEditForm({Key? key, required this.loan, required this.onSave}) : super(key: key);

  @override
  State<_LoanEditForm> createState() => _LoanEditFormState();
}

class _LoanEditFormState extends State<_LoanEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;
  late TextEditingController _loanAmountCtrl;
  late TextEditingController _interestRateCtrl;
  late TextEditingController _tenureCtrl;
  late TextEditingController _installmentCtrl;
  late TextEditingController _principalOutCtrl;
  late TextEditingController _interestOutCtrl;
  late TextEditingController _arrearsCtrl;
  late TextEditingController _loanTypeCtrl;
  DateTime? _disbursementDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupCalculationListeners();
  }

  void _initializeControllers() {
    final loan = widget.loan;
    _loanAmountCtrl = TextEditingController(
      text: (loan['loanAmount'] ?? loan['amount'] ?? 0).toString(),
    );
    _interestRateCtrl = TextEditingController(
      text: (loan['interestRate'] ?? 0).toString(),
    );
    _tenureCtrl = TextEditingController(
      text: (loan['tenure'] ?? loan['loanTenure'] ?? 0).toString(),
    );
    _installmentCtrl = TextEditingController(
      text: (loan['installment'] ?? loan['monthlyInstallment'] ?? 0).toString(),
    );
    _principalOutCtrl = TextEditingController(
      text: (loan['principalOutstanding'] ?? 0).toString(),
    );
    _interestOutCtrl = TextEditingController(
      text: (loan['interestOutstanding'] ?? 0).toString(),
    );
    _arrearsCtrl = TextEditingController(
      text: (loan['arrears'] ?? 0).toString(),
    );
    _loanTypeCtrl = TextEditingController(
      text: loan['loanType'] ?? loan['loanProduct'] ?? '',
    );

    // Parse disbursement date
    final disbDate = loan['disbursementDate'] ?? loan['disbursedAt'];
    if (disbDate != null && disbDate is Timestamp) {
      _disbursementDate = disbDate.toDate();
    }
  }

  void _setupCalculationListeners() {
    // Auto-calculate installment when amount, rate, or tenure changes
    _loanAmountCtrl.addListener(_calculateInstallment);
    _interestRateCtrl.addListener(_calculateInstallment);
    _tenureCtrl.addListener(_calculateInstallment);
  }

  void _calculateInstallment() {
    try {
      final principal = double.tryParse(_loanAmountCtrl.text) ?? 0;
      final ratePercent = double.tryParse(_interestRateCtrl.text) ?? 0;
      final months = int.tryParse(_tenureCtrl.text) ?? 0;

      if (principal > 0 && months > 0) {
        // Calculate total interest (flat rate per period)
        // Rate is already per month/period, not annual
        final totalInterest = principal * (ratePercent / 100) * months;
        
        // Calculate monthly installment
        final totalLoan = principal + totalInterest;
        final installment = totalLoan / months;

        // Update installment field
        if (installment.isFinite && installment > 0) {
          _installmentCtrl.text = installment.toStringAsFixed(0);
        }
      }
    } catch (e) {
      // Ignore calculation errors while typing
    }
  }

  @override
  void dispose() {
    _loanAmountCtrl.dispose();
    _interestRateCtrl.dispose();
    _tenureCtrl.dispose();
    _installmentCtrl.dispose();
    _principalOutCtrl.dispose();
    _interestOutCtrl.dispose();
    _arrearsCtrl.dispose();
    _loanTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final loanAmount = double.parse(_loanAmountCtrl.text);
      final interestRate = double.parse(_interestRateCtrl.text);
      final tenure = int.parse(_tenureCtrl.text);
      final installment = double.parse(_installmentCtrl.text);
      final principalOut = double.parse(_principalOutCtrl.text);
      final interestOut = double.parse(_interestOutCtrl.text);
      final arrears = double.parse(_arrearsCtrl.text);
      
      // Calculate total interest (rate is per period, not annual)
      final totalInterest = loanAmount * (interestRate / 100) * tenure;
      
      // Calculate paid amounts
      final principalPaid = loanAmount - principalOut;
      final interestPaid = totalInterest - interestOut;
      final totalOut = principalOut + interestOut;

      final updateData = {
        'loanAmount': loanAmount,
        'amount': loanAmount,
        'interestRate': interestRate,
        'tenure': tenure,
        'loanTenure': tenure,
        'installment': installment,
        'monthlyInstallment': installment,
        'principalOutstanding': principalOut,
        'interestOutstanding': interestOut,
        'totalOutstanding': totalOut,
        'arrears': arrears,
        'loanType': _loanTypeCtrl.text.trim(),
        'loanProduct': _loanTypeCtrl.text.trim(),
        'interest': totalInterest,
        'interestOriginalBalance': totalInterest,
        'principalPaid': principalPaid > 0 ? principalPaid : 0,
        'interestPaid': interestPaid > 0 ? interestPaid : 0,
        'totalRepaid': principalPaid + interestPaid,
        'correctionDate': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_disbursementDate != null) {
        updateData['disbursementDate'] = Timestamp.fromDate(_disbursementDate!);
        updateData['disbursedAt'] = Timestamp.fromDate(_disbursementDate!);
        
        // Calculate due date (disbursement + tenure months)
        final dueDate = DateTime(
          _disbursementDate!.year,
          _disbursementDate!.month + tenure,
          _disbursementDate!.day,
        );
        updateData['dueDate'] = Timestamp.fromDate(dueDate);
      }

      await _db.collection(AppConstants.loansCol).doc(widget.loan['id']).update(updateData);

      // Log audit trail
      await AuditService.log(
        action: 'loan_data_correction',
        details: 'Updated loan data for ${widget.loan['memberName']} - Loan Amount: UGX $loanAmount, Interest Rate: $interestRate%, Corrected fields: ${updateData.keys.join(', ')}',
        userId: FirebaseService.sessionUid,
        affectedUserId: widget.loan['farmerId'] ?? widget.loan['memberId'],
        metadata: {
          'loanId': widget.loan['id'],
          'memberName': widget.loan['memberName'],
          'loanAmount': loanAmount,
          'interestRate': interestRate,
          'correctedFields': updateData.keys.toList(),
        },
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onSave();
    } catch (e) {
      debugPrint('❌ Error saving loan: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.loan['memberName'],
                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Account: ${widget.loan['accountNumber']}',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              _statusChip(widget.loan['status']),
            ],
          ),
          const SizedBox(height: 32),

          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Caution: Editing loan data affects financial reports. Changes are logged in the audit trail.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Loan Basic Info
          Text('Loan Information', style: _sectionHeader()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _textField('Loan Amount (UGX)', _loanAmountCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _textField('Interest Rate (%)', _interestRateCtrl, isNumber: true)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _textField('Tenure (Months)', _tenureCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _textField('Monthly Installment (UGX)', _installmentCtrl, isNumber: true)),
            ],
          ),
          const SizedBox(height: 16),
          _textField('Loan Type/Product', _loanTypeCtrl),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 32),

          // Outstanding Balances
          Text('Outstanding Balances', style: _sectionHeader()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _textField('Principal Outstanding (UGX)', _principalOutCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _textField('Interest Outstanding (UGX)', _interestOutCtrl, isNumber: true)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _textField('Arrears (UGX)', _arrearsCtrl, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Outstanding',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _calculateTotalOutstanding(),
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => _initializeControllers(),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveLoan,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        if (isNumber && double.tryParse(value) == null) {
          return 'Enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _disbursementDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _disbursementDate = picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Disbursement Date',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _disbursementDate != null
                  ? DateFormat('yyyy-MM-dd').format(_disbursementDate!)
                  : 'Select date',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _disbursementDate != null ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  String _calculateTotalOutstanding() {
    final principal = double.tryParse(_principalOutCtrl.text) ?? 0;
    final interest = double.tryParse(_interestOutCtrl.text) ?? 0;
    final total = principal + interest;
    return 'UGX ${NumberFormat('#,###').format(total.round())}';
  }

  TextStyle _sectionHeader() {
    return GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold);
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
      case 'disbursed':
        color = Colors.green;
        break;
      case 'overdue':
        color = Colors.red;
        break;
      case 'paid':
        color = Colors.teal;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../theme/modern_theme.dart';

class LoanCardScreen extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic> loanData;

  const LoanCardScreen({
    Key? key,
    required this.loanId,
    required this.loanData,
  }) : super(key: key);

  @override
  State<LoanCardScreen> createState() => _LoanCardScreenState();
}

class _LoanCardScreenState extends State<LoanCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  bool _isEditing = false;
  bool _isSaving = false;

  // Editable fields
  late TextEditingController _principalController;
  late TextEditingController _interestRateController;
  late TextEditingController _durationController;
  late TextEditingController _purposeController;

  @override
  void initState() {
    super.initState();
    _principalController = TextEditingController(
      text: widget.loanData['loanAmount']?.toString() ?? '0'
    );
    _interestRateController = TextEditingController(
      text: widget.loanData['interestRate']?.toString() ?? '0'
    );
    _durationController = TextEditingController(
      text: widget.loanData['duration']?.toString() ?? '12'
    );
    _purposeController = TextEditingController(
      text: widget.loanData['purpose']?.toString() ?? 'N/A'
    );
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestRateController.dispose();
    _durationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _saveLoanChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final principal = double.parse(_principalController.text);
      final interestRate = double.parse(_interestRateController.text);
      final duration = int.parse(_durationController.text);

      // Recalculate interest and total
      final interest = (principal * interestRate * duration) / (100 * 12);
      final totalAmount = principal + interest;

      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .update({
        'loanAmount': principal,
        'interestRate': interestRate,
        'duration': duration,
        'purpose': _purposeController.text,
        'interest': interest,
        'totalAmount': totalAmount,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseService.sessionProfile?['fullName'] ?? 'Admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan details updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isEditing = false;
        widget.loanData['loanAmount'] = principal;
        widget.loanData['interestRate'] = interestRate;
        widget.loanData['duration'] = duration;
        widget.loanData['purpose'] = _purposeController.text;
        widget.loanData['interest'] = interest;
        widget.loanData['totalAmount'] = totalAmount;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating loan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.loanData['memberName'] ?? 'N/A';
    final accountNumber = widget.loanData['accountNumber'] ?? 'N/A';
    final referenceNumber = widget.loanData['referenceNumber'] ?? 'N/A';
    final loanProduct = widget.loanData['loanProduct'] ?? 'Agriculture loan';
    final principal = (widget.loanData['loanAmount'] ?? 0).toDouble();
    final interestRate = (widget.loanData['interestRate'] ?? 0).toDouble();
    final interest = (widget.loanData['interest'] ?? 0).toDouble();
    final totalAmount = (widget.loanData['totalAmount'] ?? 0).toDouble();
    final outstanding = (widget.loanData['outstandingBalance'] ?? totalAmount).toDouble();
    final status = widget.loanData['status'] ?? 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Loan Card', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: ModernTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Loan Details',
            ),
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: 'Cancel',
            ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveLoanChanges,
              tooltip: 'Save Changes',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Loan Card - Matches physical card design
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFA69E), // Peach/coral pink
                      Color(0xFFFFB89F),
                      Color(0xFFFFC7A0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'MBADIFA SACCO',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2C1810),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'P.O. BOX 1592, MBARARA',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF4A3428),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C1810),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LOAN CARD',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card Content
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Member Details Section
                          _buildCardSection(
                            title: 'MEMBER PARTICULARS',
                            children: [
                              _buildCardRow('NAME:', memberName),
                              _buildCardRow('ADDRESS:', 'MBARARA'),
                              _buildCardRow('A/C No:', accountNumber),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Loan Details Section
                          _buildCardSection(
                            title: 'LOAN INFORMATION',
                            children: [
                              _buildCardRow('Reference No:', referenceNumber),
                              _buildCardRow('Loan Product:', loanProduct),
                              _buildEditableRow(
                                'Purpose:',
                                _purposeController,
                                _isEditing,
                              ),
                              _buildCardRow('Status:', status.toUpperCase(),
                                  valueColor: status == 'approved'
                                      ? Colors.green.shade700
                                      : status == 'overdue'
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Financial Details Section
                          _buildCardSection(
                            title: 'DISBURSEMENTS',
                            children: [
                              _buildEditableAmountRow(
                                'Principal:',
                                _principalController,
                                _isEditing,
                              ),
                              _buildEditablePercentageRow(
                                'Interest Rate:',
                                _interestRateController,
                                _isEditing,
                              ),
                              _buildCardRow(
                                'Interest Amount:',
                                'UGX ${_currencyFormat.format(interest)}',
                              ),
                              _buildCardRow(
                                'Total Amount:',
                                'UGX ${_currencyFormat.format(totalAmount)}',
                                valueStyle: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A0D08),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Repayment Terms Section
                          _buildCardSection(
                            title: 'REPAYMENTS',
                            children: [
                              _buildEditableRow(
                                'Duration (months):',
                                _durationController,
                                _isEditing,
                                isNumber: true,
                              ),
                              _buildCardRow(
                                'Outstanding Principal:',
                                'UGX ${_currencyFormat.format(outstanding)}',
                                valueStyle: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800,
                                  color: outstanding > 0
                                      ? Colors.red.shade800
                                      : Colors.green.shade800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => setState(() => _isEditing = false),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveLoanChanges,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: ModernTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2C1810).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C1810),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCardRow(
    String label,
    String value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3428),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? const Color(0xFF1A0D08),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(
    String label,
    TextEditingController controller,
    bool isEditing, {
    bool isNumber = false,
  }) {
    if (!isEditing) {
      return _buildCardRow(label, controller.text);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3428),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF2C1810)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                if (isNumber && double.tryParse(value) == null) {
                  return 'Invalid number';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableAmountRow(
    String label,
    TextEditingController controller,
    bool isEditing,
  ) {
    if (!isEditing) {
      final amount = double.tryParse(controller.text) ?? 0;
      return _buildCardRow(label, 'UGX ${_currencyFormat.format(amount)}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3428),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixText: 'UGX ',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF2C1810)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (double.tryParse(value) == null) return 'Invalid amount';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditablePercentageRow(
    String label,
    TextEditingController controller,
    bool isEditing,
  ) {
    if (!isEditing) {
      return _buildCardRow(label, '${controller.text}%');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3428),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                suffixText: '%',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Color(0xFF2C1810)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                final rate = double.tryParse(value);
                if (rate == null) return 'Invalid rate';
                if (rate < 0 || rate > 100) return '0-100%';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';

/// Admin screen to create and disburse loans to members
class CreateLoanScreen extends StatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController(text: '15');
  final _durationController = TextEditingController(text: '12');
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedMemberId;
  String? _selectedMemberName;
  String? _selectedMemberPhone;
  String _loanType = 'personal';
  String _paymentFrequency = 'monthly';
  bool _isLoading = false;
  bool _autoApprove = true;

  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  void dispose() {
    _amountController.dispose();
    _interestRateController.dispose();
    _durationController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Create & Disburse Loan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 16),
              _buildMemberSelector(),
              const SizedBox(height: 16),
              _buildLoanDetails(),
              const SizedBox(height: 16),
              _buildLoanTypeSection(),
              const SizedBox(height: 16),
              _buildCalculatedDetails(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Create and instantly disburse loans to members with custom interest rates',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Member', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('saccoplus-members')
                .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data!.docs;
              
              return DropdownButtonFormField<String>(
                value: _selectedMemberId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Choose a member',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null ? 'Please select a member' : null,
                items: members.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? data['fullName'] ?? 'Unknown';
                  final phone = data['phone'] ?? data['phoneNumber'] ?? '';
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text('$name ($phone)', style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (value) {
                  final memberDoc = members.firstWhere((doc) => doc.id == value);
                  final data = memberDoc.data() as Map<String, dynamic>;
                  setState(() {
                    _selectedMemberId = value;
                    _selectedMemberName = data['name'] ?? data['fullName'] ?? 'Unknown';
                    _selectedMemberPhone = data['phone'] ?? data['phoneNumber'] ?? '';
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoanDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loan Details', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Loan Amount (UGX)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.money),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter loan amount';
              if (int.tryParse(value) == null) return 'Enter valid amount';
              if (int.parse(value) < 10000) return 'Minimum loan is UGX 10,000';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _interestRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Interest Rate (%)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter rate';
                    final rate = double.tryParse(value);
                    if (rate == null || rate < 0 || rate > 100) return 'Invalid rate';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (months)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter duration';
                    final months = int.tryParse(value);
                    if (months == null || months < 1 || months > 60) return 'Invalid duration';
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _purposeController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Loan Purpose',
              border: OutlineInputBorder(),
              hintText: 'e.g., Business expansion, School fees',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter loan purpose';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Admin Notes (Optional)',
              border: OutlineInputBorder(),
              hintText: 'Internal notes about this loan',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTypeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loan Configuration', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _loanType,
            decoration: const InputDecoration(
              labelText: 'Loan Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: [
              DropdownMenuItem(value: 'personal', child: Text('Personal Loan', style: GoogleFonts.poppins())),
              DropdownMenuItem(value: 'business', child: Text('Business Loan', style: GoogleFonts.poppins())),
              DropdownMenuItem(value: 'emergency', child: Text('Emergency Loan', style: GoogleFonts.poppins())),
              DropdownMenuItem(value: 'education', child: Text('Education Loan', style: GoogleFonts.poppins())),
              DropdownMenuItem(value: 'agriculture', child: Text('Agriculture Loan', style: GoogleFonts.poppins())),
            ],
            onChanged: (value) => setState(() => _loanType = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentFrequency,
            decoration: const InputDecoration(
              labelText: 'Payment Frequency',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.schedule),
            ),
            items: [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly', style: GoogleFonts.poppins())),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: GoogleFonts.poppins())),
              DropdownMenuItem(value: 'biweekly', child: Text('Bi-Weekly', style: GoogleFonts.poppins())),
            ],
            onChanged: (value) => setState(() => _paymentFrequency = value!),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text('Auto-Approve & Disburse', style: GoogleFonts.poppins(fontSize: 14)),
            subtitle: Text(
              'Loan will be approved and disbursed immediately',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: _autoApprove,
            onChanged: (value) => setState(() => _autoApprove = value),
            activeColor: AppTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatedDetails() {
    if (_amountController.text.isEmpty || _interestRateController.text.isEmpty || _durationController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final principal = int.tryParse(_amountController.text) ?? 0;
    final rate = double.tryParse(_interestRateController.text) ?? 0;
    final months = int.tryParse(_durationController.text) ?? 0;

    if (principal == 0 || months == 0) return const SizedBox.shrink();

    final interest = (principal * rate * months) / 100;
    final total = principal + interest;
    final monthlyPayment = total / months;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.success.withOpacity(0.1), AppTheme.success.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: AppTheme.success),
              const SizedBox(width: 8),
              Text('Loan Summary', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow('Principal Amount', _currencyFormat.format(principal)),
          _buildSummaryRow('Interest ($rate% for $months months)', _currencyFormat.format(interest)),
          const Divider(height: 16),
          _buildSummaryRow('Total Repayment', _currencyFormat.format(total), isTotal: true),
          _buildSummaryRow('${_paymentFrequency.capitalize()} Payment', _currencyFormat.format(monthlyPayment), isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: isHighlight ? AppTheme.success : AppTheme.textPrimary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isTotal ? AppTheme.success : (isHighlight ? AppTheme.success : AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createLoan,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(
              _autoApprove ? 'Create & Disburse Loan' : 'Create Loan (Pending Approval)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
    );
  }

  Future<void> _createLoan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberId == null) {
      _showError('Please select a member');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final principal = int.parse(_amountController.text);
      final rate = double.parse(_interestRateController.text);
      final months = int.parse(_durationController.text);
      final interest = (principal * rate * months) / 100;
      final total = principal + interest;

      final loanData = {
        'tenantId': FirebaseService.sessionTenantId,
        'farmerId': _selectedMemberId,
        'farmerName': _selectedMemberName,
        'farmerPhone': _selectedMemberPhone,
        'amount': principal,
        'interestRate': rate,
        'duration': months,
        'purpose': _purposeController.text.trim(),
        'loanType': _loanType,
        'paymentFrequency': _paymentFrequency,
        'interestAmount': interest.round(),
        'totalAmount': total.round(),
        'status': _autoApprove ? 'approved' : 'pending',
        'balance': total.round(),
        'amountPaid': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseService.sessionUid,
        'createdByAdmin': true,
        'adminNotes': _notesController.text.trim(),
      };

      if (_autoApprove) {
        loanData['approvedAt'] = FieldValue.serverTimestamp();
        loanData['approvedBy'] = FirebaseService.sessionUid;
        loanData['disbursedAt'] = FieldValue.serverTimestamp();
        loanData['disbursedBy'] = FirebaseService.sessionUid;
      }

      await FirebaseFirestore.instance
          .collection(AppConstants.loanCol)
          .add(loanData);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _autoApprove ? 'Loan created and disbursed successfully!' : 'Loan created, pending approval',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      _showError('Failed to create loan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.error,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

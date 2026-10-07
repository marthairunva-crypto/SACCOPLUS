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
  String? _selectedMemberAccount;
  String _loanType = 'personal';
  String _paymentFrequency = 'monthly';
  String _interestMethod = 'flat';
  bool _isLoading = false;
  bool _autoApprove = true;

  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  // ── Responsive breakpoints (measured on the space the page actually gets,
  //    i.e. AFTER the sidebar, because we use LayoutBuilder) ──
  static const double _wideBreakpoint = 900; // >= this -> two columns
  static const double _maxWidthWide = 1100; // content cap on desktop / web
  static const double _maxWidthNarrow = 720; // content cap for single column
  static const double _columnGap = 20;

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
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: canPop
          ? AppBar(
              title: Text(
                'Create & Disburse Loan',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final wide = w >= _wideBreakpoint;
              final hPad = w < 360 ? 12.0 : (wide ? 24.0 : 16.0);
              final vPad = wide ? 24.0 : 16.0;
              final maxW = wide ? _maxWidthWide : _maxWidthNarrow;

              // Scroll view spans the full width so the scrollbar sits at the
              // window edge; content is centred and capped inside it.
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
                      child: Form(
                        key: _formKey,
                        child: wide ? _buildWideBody() : _buildNarrowBody(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Layouts ─────────────────────────

  /// Phones / small windows: everything in one column.
  Widget _buildNarrowBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildMemberSelector(),
        const SizedBox(height: 16),
        _buildLoanDetails(),
        const SizedBox(height: 16),
        _buildLoanTypeSection(),
        if (_hasSummary) ...[
          const SizedBox(height: 16),
          _buildCalculatedDetails(),
        ],
        const SizedBox(height: 24),
        _buildSubmitButton(),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Desktop / web / tablets landscape: two balanced columns.
  ///   Left : member + loan details
  ///   Right: configuration + live summary
  Widget _buildWideBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMemberSelector(),
                  const SizedBox(height: 20),
                  _buildLoanDetails(),
                ],
              ),
            ),
            const SizedBox(width: _columnGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLoanTypeSection(),
                  if (_hasSummary) ...[
                    const SizedBox(height: 20),
                    _buildCalculatedDetails(),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSubmitButton(),
        const SizedBox(height: 8),
      ],
    );
  }

  // ───────────────────────── Shared helpers ─────────────────────────

  Widget _card({required Widget child}) {
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
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  /// Two fields side by side, stacked only when the CARD itself is very narrow
  /// (so it also behaves correctly inside a two-column desktop layout).
  Widget _responsiveRow(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  DropdownMenuItem<String> _item(String value, String label) {
    return DropdownMenuItem(
      value: value,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(),
      ),
    );
  }

  // ───────────────────────── Sections ─────────────────────────

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
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Select Member'),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(AppConstants.usersCol)
                .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                .where('role', isEqualTo: AppConstants.roleMember)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data!.docs;

              String labelFor(QueryDocumentSnapshot doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? data['fullName'] ?? 'Unknown';
                final phone = data['phone'] ?? data['phoneNumber'] ?? '';
                return phone.toString().isEmpty ? '$name' : '$name ($phone)';
              }

              final validValue =
                  members.any((d) => d.id == _selectedMemberId) ? _selectedMemberId : null;

              return DropdownButtonFormField<String>(
                value: validValue,
                isExpanded: true,
                menuMaxHeight: 360, // scrolls instead of covering the screen
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Choose a member',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null ? 'Please select a member' : null,
                selectedItemBuilder: (context) => members
                    .map((doc) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            labelFor(doc),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(),
                          ),
                        ))
                    .toList(),
                items: members
                    .map((doc) => DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            labelFor(doc),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final memberDoc = members.firstWhere((doc) => doc.id == value);
                  final data = memberDoc.data() as Map<String, dynamic>;
                  setState(() {
                    _selectedMemberId = value;
                    _selectedMemberName = data['name'] ?? data['fullName'] ?? 'Unknown';
                    _selectedMemberPhone = data['phone'] ?? data['phoneNumber'] ?? '';
                    _selectedMemberAccount = data['accountNumber'] ?? 'N/A';
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
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Loan Details'),
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
          _responsiveRow(
            TextFormField(
              controller: _interestRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Interest (%)',
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
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Months',
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
              if (value == null || value.trim().isEmpty) return 'Enter loan purpose';
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
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Loan Configuration'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _loanType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Loan Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: [
              _item('personal', 'Personal Loan'),
              _item('business', 'Business Loan'),
              _item('emergency', 'Emergency Loan'),
              _item('education', 'Education Loan'),
              _item('agriculture', 'Agriculture Loan'),
            ],
            onChanged: (value) => setState(() => _loanType = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentFrequency,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Payment Frequency',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.schedule),
            ),
            items: [
              _item('daily', 'Daily (Emergency)'),
              _item('weekly', 'Weekly'),
              _item('biweekly', 'Bi-Weekly'),
              _item('monthly', 'Monthly'),
            ],
            onChanged: (value) => setState(() => _paymentFrequency = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _interestMethod,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Interest Method',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calculate),
            ),
            items: [
              _item('flat', 'Flat Rate (Simple Interest)'),
              _item('reducing', 'Reducing Balance (Amortized)'),
            ],
            onChanged: (value) => setState(() => _interestMethod = value!),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
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

  /// True when the live summary has enough valid input to be shown.
  bool get _hasSummary {
    if (_amountController.text.isEmpty ||
        _interestRateController.text.isEmpty ||
        _durationController.text.isEmpty) {
      return false;
    }
    final principal = int.tryParse(_amountController.text) ?? 0;
    final months = int.tryParse(_durationController.text) ?? 0;
    return principal != 0 && months != 0;
  }

  Widget _buildCalculatedDetails() {
    if (!_hasSummary) return const SizedBox.shrink();

    final principal = int.tryParse(_amountController.text) ?? 0;
    final rate = double.tryParse(_interestRateController.text) ?? 0;
    final months = int.tryParse(_durationController.text) ?? 0;

    final calc = _calculate(principal, rate, months);

    String paymentLabel;
    switch (_paymentFrequency) {
      case 'daily':
        paymentLabel = 'Daily Payment';
        break;
      case 'weekly':
        paymentLabel = 'Weekly Payment';
        break;
      case 'biweekly':
        paymentLabel = 'Bi-Weekly Payment';
        break;
      case 'monthly':
      default:
        paymentLabel = 'Monthly Payment';
        break;
    }

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
              Expanded(child: _sectionTitle('Loan Summary')),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow('Principal Amount', _currencyFormat.format(principal)),
          _buildSummaryRow(
            'Interest (${_interestMethod == 'reducing' ? 'Reducing' : 'Flat'} $rate% for $months months)',
            _currencyFormat.format(calc.interest),
          ),
          const Divider(height: 16),
          _buildSummaryRow('Total Repayment', _currencyFormat.format(calc.total), isTotal: true),
          _buildSummaryRow(paymentLabel, _currencyFormat.format(calc.periodic), isHighlight: true),
        ],
      ),
    );
  }

  /// Single place for loan maths (used by the summary AND by _createLoan)
  ({double interest, double total, double periodic}) _calculate(
      int principal, double rate, int months) {
    double interest;
    double total;
    double periodic;

    if (_interestMethod == 'reducing') {
      final monthlyRate = rate / (100 * 12);
      if (monthlyRate > 0) {
        double powN = 1;
        for (int i = 0; i < months; i++) {
          powN *= (1 + monthlyRate);
        }
        periodic = (principal * monthlyRate * powN) / (powN - 1);
        total = periodic * months;
        interest = total - principal;
      } else {
        interest = 0;
        total = principal.toDouble();
        periodic = principal / months;
      }
    } else {
      // Flat: rate is per month
      interest = (principal * rate / 100) * months;
      total = principal + interest;
      periodic = total / months;
    }
    return (interest: interest, total: total, periodic: periodic);
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isTotal = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isTotal ? 15 : 14,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
                color: isHighlight ? AppTheme.success : AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isTotal || isHighlight ? AppTheme.success : AppTheme.textPrimary,
                ),
              ),
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
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _autoApprove ? 'Create & Disburse Loan' : 'Create Loan (Pending Approval)',
                maxLines: 1,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  void _resetForm() {
    _formKey.currentState?.reset();
    _amountController.clear();
    _purposeController.clear();
    _notesController.clear();
    _interestRateController.text = '15';
    _durationController.text = '12';
    setState(() {
      _selectedMemberId = null;
      _selectedMemberName = null;
      _selectedMemberPhone = null;
      _selectedMemberAccount = null;
      _loanType = 'personal';
      _paymentFrequency = 'monthly';
      _interestMethod = 'flat';
      _autoApprove = true;
    });
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

      final calc = _calculate(principal, rate, months);
      final interest = calc.interest;
      final totalAmount = calc.total;

      final loanData = <String, dynamic>{
        'tenantId': FirebaseService.sessionTenantId,
        'farmerId': _selectedMemberId,
        'memberId': _selectedMemberId, // Also save as memberId for consistency
        'farmerName': _selectedMemberName,
        'memberName': _selectedMemberName, // Also save as memberName
        'farmerPhone': _selectedMemberPhone,
        'accountNumber': _selectedMemberAccount ?? 'N/A', // Save account number
        'amount': principal,
        'loanAmount': principal,
        'interestRate': rate,
        'interestMethod': _interestMethod,
        'duration': months,
        'purpose': _purposeController.text.trim(),
        'loanType': _loanType,
        'paymentFrequency': _paymentFrequency,
        'interestAmount': interest.round(),
        'interest': interest.round(),
        'totalAmount': totalAmount.round(),
        'status': _autoApprove ? 'approved' : 'pending',
        'balance': totalAmount.round(),
        'principalOutstanding': principal.toDouble(),
        'interestOutstanding': interest,
        'interestOriginalBalance': interest,
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

      await FirebaseFirestore.instance.collection(AppConstants.loansCol).add(loanData);

      if (!mounted) return;
      final message =
          _autoApprove ? 'Loan created and disbursed successfully!' : 'Loan created, pending approval';

      // When opened as a tab (no back stack) don't pop the root route
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      } else {
        _resetForm();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
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
    if (!mounted) return;
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
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Clean Cash Loan Payment Dialog
/// Features:
/// - Clear outstanding breakdown
/// - Payment options: Pay All, Partial, Interest Only, Principal Only
/// - Simple, non-confusing UI
class LoanPaymentCashDialog extends StatefulWidget {
  final double principalOutstanding;
  final double interestOutstanding;
  final double chargesOutstanding;
  final String memberName;
  final String? memberPhone; // Member's registered phone
  final Function(Map<String, dynamic> paymentData) onPaymentComplete;

  const LoanPaymentCashDialog({
    Key? key,
    required this.principalOutstanding,
    required this.interestOutstanding,
    required this.chargesOutstanding,
    required this.memberName,
    this.memberPhone,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<LoanPaymentCashDialog> createState() => _LoanPaymentCashDialogState();
}

class _LoanPaymentCashDialogState extends State<LoanPaymentCashDialog> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  final _altPhoneController = TextEditingController();
  
  String _paymentType = 'full'; // full, partial, interest_only, principal_only
  DateTime _paymentDate = DateTime.now();
  
  double _principalAmount = 0;
  double _interestAmount = 0;
  double _chargesAmount = 0;

  @override
  void initState() {
    super.initState();
    _updateAmounts();
  }

  @override
  void dispose() {
    _altPhoneController.dispose();
    super.dispose();
  }

  void _updateAmounts() {
    setState(() {
      switch (_paymentType) {
        case 'full':
          _principalAmount = widget.principalOutstanding;
          _interestAmount = widget.interestOutstanding;
          _chargesAmount = widget.chargesOutstanding;
          break;
        case 'interest_only':
          _principalAmount = 0;
          _interestAmount = widget.interestOutstanding;
          _chargesAmount = widget.chargesOutstanding;
          break;
        case 'principal_only':
          _principalAmount = widget.principalOutstanding;
          _interestAmount = 0;
          _chargesAmount = 0;
          break;
        case 'partial':
          // Keep custom amounts as is
          break;
      }
    });
  }

  double get _totalAmount => _principalAmount + _interestAmount + _chargesAmount;

  void _recordPayment() {
    if (_totalAmount <= 0) {
      _showError('Payment amount must be greater than zero');
      return;
    }

    final paymentData = {
      'principalPaid': _principalAmount,
      'interestPaid': _interestAmount,
      'chargesPaid': _chargesAmount,
      'totalPaid': _totalAmount,
      'paymentMethod': 'Cash',
      'paymentDate': _paymentDate,
      'paymentType': _paymentType,
      'alternativePhone': _altPhoneController.text.trim(), // Additional SMS recipient
    };

    widget.onPaymentComplete(paymentData);
    Navigator.pop(context);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.money, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash Payment',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.memberName,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Date
                    _buildPaymentDateSection(),
                    const SizedBox(height: 24),
                    
                    // Alternative Phone for SMS
                    _buildAlternativePhoneSection(),
                    const SizedBox(height: 24),

                    // Outstanding Breakdown
                    _buildOutstandingSection(),
                    const SizedBox(height: 24),

                    // Payment Options
                    _buildPaymentOptionsSection(),
                    const SizedBox(height: 24),

                    // Payment Summary
                    _buildPaymentSummary(),
                  ],
                ),
              ),
            ),

            // Footer with action button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _recordPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Record Payment',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  Widget _buildPaymentDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Date',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _paymentDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _paymentDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMMM dd, yyyy').format(_paymentDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutstandingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Outstanding Balance',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              _buildOutstandingRow(
                'Principal',
                widget.principalOutstanding,
                Icons.account_balance,
              ),
              const Divider(height: 16),
              _buildOutstandingRow(
                'Interest',
                widget.interestOutstanding,
                Icons.percent,
              ),
              const Divider(height: 16),
              _buildOutstandingRow(
                'Charges',
                widget.chargesOutstanding,
                Icons.receipt_long,
              ),
              const Divider(height: 16, thickness: 2),
              _buildOutstandingRow(
                'Total Outstanding',
                widget.principalOutstanding +
                    widget.interestOutstanding +
                    widget.chargesOutstanding,
                Icons.account_balance_wallet,
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutstandingRow(String label, double amount, IconData icon,
      {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.red.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Text(
          'UGX ${_currencyFormat.format(amount.round())}',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Type',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          'Pay All Outstanding',
          'full',
          'Pay the complete outstanding balance',
          Icons.check_circle,
          Colors.green,
        ),
        const SizedBox(height: 8),
        _buildPaymentOption(
          'Interest + Charges Only',
          'interest_only',
          'Pay interest and charges, skip principal',
          Icons.percent,
          Colors.orange,
        ),
        const SizedBox(height: 8),
        _buildPaymentOption(
          'Principal Only',
          'principal_only',
          'Pay principal amount only',
          Icons.account_balance,
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildPaymentOption(
          'Custom Partial Payment',
          'partial',
          'Enter custom amounts',
          Icons.edit,
          Colors.purple,
        ),
        
        // Custom amount fields (show only if partial is selected)
        if (_paymentType == 'partial') ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              children: [
                _buildAmountField('Principal Amount', _principalAmount, widget.principalOutstanding, (value) {
                  setState(() => _principalAmount = value);
                }),
                const SizedBox(height: 12),
                _buildAmountField('Interest Amount', _interestAmount, widget.interestOutstanding, (value) {
                  setState(() => _interestAmount = value);
                }),
                const SizedBox(height: 12),
                _buildAmountField('Charges Amount', _chargesAmount, widget.chargesOutstanding, (value) {
                  setState(() => _chargesAmount = value);
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentOption(
    String title,
    String value,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = _paymentType == value;
    return InkWell(
      onTap: () {
        setState(() {
          _paymentType = value;
          _updateAmounts();
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24)
            else
              Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(
    String label,
    double currentValue,
    double maxValue,
    Function(double) onChanged,
  ) {
    final controller = TextEditingController(text: currentValue.round().toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Max: ${_currencyFormat.format(maxValue.round())}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: 'UGX ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (value) {
            final amount = double.tryParse(value) ?? 0;
            if (amount <= maxValue) {
              onChanged(amount);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Summary',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildSummaryRow('Principal Payment', _principalAmount),
          const SizedBox(height: 8),
          _buildSummaryRow('Interest Payment', _interestAmount),
          const SizedBox(height: 8),
          _buildSummaryRow('Charges Payment', _chargesAmount),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                'UGX ${_currencyFormat.format(_totalAmount.round())}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          'UGX ${_currencyFormat.format(amount.round())}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativePhoneSection() {
    final hasMemberPhone = widget.memberPhone != null && widget.memberPhone!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sms, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              'SMS Notification',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Show member's phone if exists
        if (hasMemberPhone) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SMS will be sent to member\'s phone',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.memberPhone!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Alternative phone field (always show but with different helper text)
        const SizedBox(height: 12),
        TextField(
          controller: _altPhoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: hasMemberPhone 
                ? 'Additional SMS Recipient (Optional)' 
                : 'Alternative Phone for SMS (Required)',
            hintText: '256XXXXXXXXX',
            helperText: hasMemberPhone
                ? 'Send SMS to an additional number (e.g., spouse, guarantor)'
                : 'Member has no phone. Provide a number to send SMS receipt',
            helperMaxLines: 2,
            prefixIcon: Icon(
              hasMemberPhone ? Icons.person_add : Icons.warning,
              color: hasMemberPhone ? Colors.blue : Colors.orange,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: hasMemberPhone ? Colors.blue.shade50 : Colors.orange.shade50,
          ),
        ),
      ],
    );
  }
}
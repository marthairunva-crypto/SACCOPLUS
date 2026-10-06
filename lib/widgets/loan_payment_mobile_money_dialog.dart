import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/teller_service.dart';
import '../core/firebase_service.dart';

/// Clean Mobile Money Loan Payment Dialog
/// Features:
/// - Phone verification showing account holder name
/// - Clear outstanding breakdown
/// - Payment options: Pay All, Partial, Interest Only, Principal Only
/// - Simple, non-confusing UI
class LoanPaymentMobileMoneyDialog extends StatefulWidget {
  final double principalOutstanding;
  final double interestOutstanding;
  final double chargesOutstanding;
  final String memberName;
  final String? memberPhone;
  final Function(Map<String, dynamic> paymentData) onPaymentComplete;

  const LoanPaymentMobileMoneyDialog({
    Key? key,
    required this.principalOutstanding,
    required this.interestOutstanding,
    required this.chargesOutstanding,
    required this.memberName,
    this.memberPhone,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<LoanPaymentMobileMoneyDialog> createState() => _LoanPaymentMobileMoneyDialogState();
}

class _LoanPaymentMobileMoneyDialogState extends State<LoanPaymentMobileMoneyDialog> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  final _phoneController = TextEditingController();
  
  String _paymentType = 'full'; // full, partial, interest_only, principal_only
  String _provider = 'MTN';
  String? _verifiedAccountName;
  bool _isVerifying = false;
  bool _isProcessing = false;
  
  double _principalAmount = 0;
  double _interestAmount = 0;
  double _chargesAmount = 0;
  double _customAmount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.memberPhone != null) {
      _phoneController.text = widget.memberPhone!;
    }
    _updateAmounts();
  }

  @override
  void dispose() {
    _phoneController.dispose();
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

  Future<void> _verifyPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter phone number');
      return;
    }

    // Validate phone number format - must be 12 digits (256XXXXXXXXX)
    if (phone.length != 12 || !phone.startsWith('256')) {
      _showError('Invalid phone number. Uganda numbers must be 256 followed by 9 digits (e.g., 256777123456)');
      return;
    }

    // Check if all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      _showError('Phone number must contain only digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifiedAccountName = null;
    });

    try {
      final result = await TellerService.verifyMobileMoneyAccount(
        phoneNumber: phone,
        provider: _provider,
      );

      setState(() {
        _isVerifying = false;
        if (result['success'] == true) {
          _verifiedAccountName = result['accountName'] ?? result['full_name'] ?? 'Account Verified';
        } else {
          // Check if we can skip verification
          final canSkip = result['canSkip'] == true;
          final message = result['message'] ?? 'Verification failed';
          
          if (canSkip) {
            // Show option to proceed without verification
            _showSkipVerificationDialog(message);
          } else {
            _showError(message);
          }
        }
      });
    } catch (e) {
      setState(() => _isVerifying = false);
      _showSkipVerificationDialog('Unable to connect to verification service. You can proceed without verification.');
    }
  }

  void _showSkipVerificationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Text('Verification Unavailable', style: GoogleFonts.inter(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'You can proceed with the payment without verification, or wait and try verifying again.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _verifiedAccountName = 'Unverified - ${_phoneController.text}';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Proceed Without Verification', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    // Verification is now optional - warn if not verified but allow proceeding
    if (_verifiedAccountName == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Confirm Payment', style: GoogleFonts.inter(fontSize: 16)),
          content: Text(
            'Phone number has not been verified. Are you sure you want to send a payment request to ${_phoneController.text}?',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              child: Text('Yes, Send Payment', style: GoogleFonts.inter()),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }

    if (_totalAmount <= 0) {
      _showError('Payment amount must be greater than zero');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Use the same method as farmer screen - FirebaseService.walletDeposit
      final result = await FirebaseService.walletDeposit(
        uid: FirebaseService.sessionUid,
        amount: _totalAmount.round(),
        phoneNumber: _phoneController.text.trim(),
        countryCode: 'UG',
        currencyCode: 'UGX',
      );

      if (!mounted) return;

      final uuid = result['uuid'] as String?;
      final txnId = result['txnId'] as String?;

      if (uuid == null || txnId == null) {
        throw Exception('Payment request failed to initialize');
      }

      // Show processing dialog with polling (same as farmer screen)
      if (!mounted) return;
      Navigator.pop(context); // Close payment dialog
      
      final paymentSuccess = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _PollingDialog(
          uuid: uuid,
          phoneNumber: _phoneController.text.trim(),
        ),
      );

      if (paymentSuccess == true) {
        // Payment completed - record it
        final paymentData = {
          'principalPaid': _principalAmount,
          'interestPaid': _interestAmount,
          'chargesPaid': _chargesAmount,
          'totalPaid': _totalAmount,
          'paymentMethod': 'Mobile Money',
          'provider': _provider,
          'phoneNumber': _phoneController.text.trim(),
          'transactionId': txnId,
          'accountName': _verifiedAccountName,
          'paymentType': _paymentType,
          'timestamp': DateTime.now(),
        };

        widget.onPaymentComplete(paymentData);
        _showSuccess('Payment of UGX ${_currencyFormat.format(_totalAmount.round())} completed successfully!');
      } else {
        _showError('Payment was cancelled or failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      _showError('Error: $e');
    }
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
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
                    child: const Icon(Icons.phone_android, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mobile Money Payment',
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

            // Body - Two Column Layout
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Outstanding Breakdown
                          _buildOutstandingSection(),
                          const SizedBox(height: 24),

                          // Payment Options
                          _buildPaymentOptionsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Right Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Phone Verification
                          _buildPhoneVerificationSection(),
                          const SizedBox(height: 24),

                          // Payment Summary
                          _buildPaymentSummary(),
                        ],
                      ),
                    ),
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
                      onPressed: _isProcessing ? null : _initiatePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Send Payment Request',
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

  Widget _buildOutstandingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Outstanding Balance',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              _buildOutstandingRow('Principal', widget.principalOutstanding, Icons.account_balance),
              const Divider(height: 12),
              _buildOutstandingRow('Interest', widget.interestOutstanding, Icons.percent),
              const Divider(height: 12),
              _buildOutstandingRow('Charges', widget.chargesOutstanding, Icons.receipt_long),
              const Divider(height: 12, thickness: 2),
              _buildOutstandingRow(
                'Total',
                widget.principalOutstanding + widget.interestOutstanding + widget.chargesOutstanding,
                Icons.account_balance_wallet,
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutstandingRow(String label, double amount, IconData icon, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.red.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Text(
          'UGX ${_currencyFormat.format(amount.round())}',
          style: GoogleFonts.inter(
            fontSize: 13,
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
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        _buildPaymentOption('Pay All', 'full', 'Complete balance', Icons.check_circle, Colors.green),
        const SizedBox(height: 6),
        _buildPaymentOption('Interest + Charges', 'interest_only', 'Skip principal', Icons.percent, Colors.orange),
        const SizedBox(height: 6),
        _buildPaymentOption('Principal Only', 'principal_only', 'Principal amount', Icons.account_balance, Colors.blue),
        const SizedBox(height: 6),
        _buildPaymentOption('Custom Partial', 'partial', 'Enter amounts', Icons.edit, Colors.purple),
        
        // Custom amount fields (show only if partial is selected)
        if (_paymentType == 'partial') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              children: [
                _buildAmountField('Principal', _principalAmount, widget.principalOutstanding, (value) {
                  setState(() => _principalAmount = value);
                }),
                const SizedBox(height: 10),
                _buildAmountField('Interest', _interestAmount, widget.interestOutstanding, (value) {
                  setState(() => _interestAmount = value);
                }),
                const SizedBox(height: 10),
                _buildAmountField('Charges', _chargesAmount, widget.chargesOutstanding, (value) {
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : Colors.grey.shade400,
              size: 20,
            ),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Max: ${_currencyFormat.format(maxValue.round())}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: 'UGX ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
          ),
          style: GoogleFonts.inter(fontSize: 13),
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

  Widget _buildPhoneVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Money Details',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 10),
        
        // Provider selection
        DropdownButtonFormField<String>(
          value: _provider,
          decoration: InputDecoration(
            labelText: 'Provider',
            prefixIcon: const Icon(Icons.sim_card, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          style: GoogleFonts.inter(fontSize: 13, color: Colors.black),
          items: const [
            DropdownMenuItem(value: 'MTN', child: Text('MTN Mobile Money')),
            DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
          ],
          onChanged: (value) {
            setState(() {
              _provider = value!;
              _verifiedAccountName = null;
            });
          },
        ),
        const SizedBox(height: 12),
        
        // Phone number with verify button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '256XXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                style: GoogleFonts.inter(fontSize: 13),
                onChanged: (_) {
                  setState(() => _verifiedAccountName = null);
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isVerifying ? null : _verifyPhoneNumber,
                icon: _isVerifying
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.verified_user, size: 16),
                label: Text(
                  'Verify',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0891B2),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // Verification result
        if (_verifiedAccountName != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered in names of',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        _verifiedAccountName!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Icon(Icons.receipt, color: Colors.blue.shade700, size: 18),
              const SizedBox(width: 6),
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
          const Divider(height: 14),
          _buildSummaryRow('Principal', _principalAmount),
          const SizedBox(height: 6),
          _buildSummaryRow('Interest', _interestAmount),
          const SizedBox(height: 6),
          _buildSummaryRow('Charges', _chargesAmount),
          const Divider(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              Text(
                'UGX ${_currencyFormat.format(_totalAmount.round())}',
                style: GoogleFonts.inter(
                  fontSize: 16,
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}


// Polling Dialog - exactly like farmer screen
class _PollingDialog extends StatefulWidget {
  final String uuid;
  final String phoneNumber;

  const _PollingDialog({
    required this.uuid,
    required this.phoneNumber,
  });

  @override
  State<_PollingDialog> createState() => _PollingDialogState();
}

class _PollingDialogState extends State<_PollingDialog> {
  double _progress = 0.0;
  String _status = 'processing';

  @override
  void initState() {
    super.initState();
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    // Poll up to 3 minutes (36 × 5s) - same as farmer screen
    for (int i = 0; i < 36; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      setState(() => _progress = (i + 1) / 36);

      try {
        _status = await FirebaseService.marzPayCheckStatus(widget.uuid);
        debugPrint('Payment status: $_status');
      } catch (e) {
        debugPrint('Error checking status: $e');
        // Continue polling
      }

      if (_status == 'completed') {
        if (mounted) Navigator.pop(context, true); // Success
        return;
      } else if (_status == 'failed' || _status == 'cancelled') {
        if (mounted) Navigator.pop(context, false); // Failed
        return;
      }
    }

    // Timeout after 3 minutes
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text(
              'Payment request sent to ${widget.phoneNumber}',
              style: GoogleFonts.inter(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please enter PIN on your phone to complete payment',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).round()}% • Checking status...',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

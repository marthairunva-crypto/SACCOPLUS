import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/teller_service.dart';
import '../core/firebase_service.dart';

/// Mobile money loan payment dialog.
///
/// Public API and payment flow are unchanged (drop-in replacement).
/// Fixes included:
/// - Responsive: two columns on wide screens, single column on phones.
/// - Custom amount fields keep their cursor while typing.
/// - Amounts above the outstanding balance show an inline error.
/// - Success/failure messages still show after the dialog closes
///   (the messenger is captured before the dialog is popped).
/// - The Send button re-enables if the user cancels or the payment fails.
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
  State<LoanPaymentMobileMoneyDialog> createState() =>
      _LoanPaymentMobileMoneyDialogState();
}

/// Design tokens: one brand colour, neutral greys, status colours used sparingly.
class _C {
  static const brand = Color(0xFF047857);
  static const brandSoft = Color(0xFFECFDF5);
  static const brandLine = Color(0xFFA7F3D0);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF9FAFB);
  static const error = Color(0xFFB91C1C);
  static const warn = Color(0xFFB45309);
  static const warnSoft = Color(0xFFFFFBEB);
}

class _Option {
  final String value;
  final String title;
  final String subtitle;
  const _Option(this.value, this.title, this.subtitle);
}

class _LoanPaymentMobileMoneyDialogState
    extends State<LoanPaymentMobileMoneyDialog> {
  final _fmt = NumberFormat('#,###', 'en_US');
  final _phoneController = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _chargesCtrl = TextEditingController();

  String _paymentType = 'full'; // full, partial, interest_only, principal_only
  String _provider = 'MTN';
  String? _verifiedAccountName;
  bool _isVerified = false; // true = verified by service, false = skipped
  bool _isVerifying = false;
  bool _isProcessing = false;

  double _principalAmount = 0;
  double _interestAmount = 0;
  double _chargesAmount = 0;

  static const _options = [
    _Option('full', 'Pay full balance', 'Principal, interest and charges'),
    _Option('interest_only', 'Interest and charges', 'Leave principal unpaid'),
    _Option('principal_only', 'Principal only',
        'Leave interest and charges unpaid'),
    _Option('partial', 'Custom amounts', 'Choose how much goes to each part'),
  ];

  // ---------------------------------------------------------------- logic

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
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _chargesCtrl.dispose();
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
          // Keep current amounts as the starting point.
          break;
      }
      _principalCtrl.text = _principalAmount.round().toString();
      _interestCtrl.text = _interestAmount.round().toString();
      _chargesCtrl.text = _chargesAmount.round().toString();
    });
  }

  double get _totalAmount =>
      _principalAmount + _interestAmount + _chargesAmount;

  double get _totalOutstanding =>
      widget.principalOutstanding +
      widget.interestOutstanding +
      widget.chargesOutstanding;

  bool get _hasAmountError =>
      _principalAmount > widget.principalOutstanding ||
      _interestAmount > widget.interestOutstanding ||
      _chargesAmount > widget.chargesOutstanding;

  Future<void> _verifyPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Enter a phone number.');
      return;
    }
    if (phone.length != 12 || !phone.startsWith('256')) {
      _showError(
          'Invalid number. Use 256 followed by 9 digits, for example 256777123456.');
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      _showError('Phone number must contain digits only.');
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
      if (!mounted) return;

      setState(() => _isVerifying = false);

      if (result['success'] == true) {
        setState(() {
          _isVerified = true;
          _verifiedAccountName =
              result['accountName'] ?? result['full_name'] ?? 'Account verified';
        });
      } else {
        final message = result['message'] ?? 'Verification failed';
        if (result['canSkip'] == true) {
          _showSkipVerificationDialog(message);
        } else {
          _showError(message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      _showSkipVerificationDialog(
          'Unable to reach the verification service. You can continue without verifying.');
    }
  }

  void _showSkipVerificationDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Verification unavailable',
            style: _t(16, weight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: _t(14)),
            const SizedBox(height: 12),
            Text(
              'You can continue without verification, or cancel and try again later.',
              style: _t(13, color: _C.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: _t(14, color: _C.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isVerified = false;
                _verifiedAccountName = 'Unverified - ${_phoneController.text}';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.brand,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Continue without verifying',
                style: _t(14, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    if (_verifiedAccountName == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Send without verifying?',
              style: _t(16, weight: FontWeight.w600)),
          content: Text(
            'This number has not been verified. Send a payment request to ${_phoneController.text}?',
            style: _t(14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: _t(14, color: _C.muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.brand,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Send request',
                  style: _t(14, weight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (_totalAmount <= 0) {
      _showError('Enter an amount greater than zero.');
      return;
    }
    if (_hasAmountError) {
      _showError('One or more amounts exceed the outstanding balance.');
      return;
    }

    setState(() => _isProcessing = true);

    // Capture before the dialog is popped, so messages still show afterwards.
    final messenger = ScaffoldMessenger.of(context);
    final navContext = context;

    try {
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

      final phone = _phoneController.text.trim();
      final paymentData = {
        'principalPaid': _principalAmount,
        'interestPaid': _interestAmount,
        'chargesPaid': _chargesAmount,
        'totalPaid': _totalAmount,
        'paymentMethod': 'Mobile Money',
        'provider': _provider,
        'phoneNumber': phone,
        'transactionId': txnId,
        'accountName': _verifiedAccountName,
        'paymentType': _paymentType,
        'timestamp': DateTime.now(),
      };
      final totalLabel = 'UGX ${_fmt.format(_totalAmount.round())}';

      Navigator.pop(navContext); // Close payment dialog

      final paymentSuccess = await showDialog<bool>(
        context: navContext,
        barrierDismissible: false,
        builder: (ctx) => _PollingDialog(uuid: uuid, phoneNumber: phone),
      );

      if (paymentSuccess == true) {
        widget.onPaymentComplete(paymentData);
        messenger.showSnackBar(SnackBar(
          content: Text('Payment of $totalLabel received.'),
          backgroundColor: _C.brand,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        messenger.showSnackBar(SnackBar(
          content: const Text('Payment was cancelled or failed.'),
          backgroundColor: _C.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _C.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------- styles

  TextStyle _t(double size,
          {FontWeight weight = FontWeight.w400, Color color = _C.ink}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  String _ugx(double v) => 'UGX ${_fmt.format(v.round())}';

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1, color: _C.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: LayoutBuilder(builder: (context, c) {
                  final left = _leftColumn();
                  final right = _rightColumn();
                  if (c.maxWidth >= 640) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 32),
                        Expanded(child: right),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [right, const SizedBox(height: 28), left],
                  );
                }),
              ),
            ),
            const Divider(height: 1, color: _C.line),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _leftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _outstandingCard(),
        const SizedBox(height: 28),
        _sectionTitle('Payment type'),
        for (var i = 0; i < _options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _typeTile(_options[i]),
        ],
        if (_paymentType == 'partial') ...[
          const SizedBox(height: 16),
          _amountField('Principal', _principalCtrl,
              widget.principalOutstanding,
              (v) => setState(() => _principalAmount = v)),
          const SizedBox(height: 14),
          _amountField('Interest', _interestCtrl, widget.interestOutstanding,
              (v) => setState(() => _interestAmount = v)),
          const SizedBox(height: 14),
          _amountField('Charges', _chargesCtrl, widget.chargesOutstanding,
              (v) => setState(() => _chargesAmount = v)),
        ],
      ],
    );
  }

  Widget _rightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Mobile money account'),
        _accountSection(),
        const SizedBox(height: 28),
        _summaryCard(),
      ],
    );
  }

  // ---------------------------------------------------------------- header

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smartphone_outlined,
                color: _C.brand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mobile money payment',
                    style: _t(17, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(widget.memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(13, color: _C.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: _C.muted, size: 20),
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: _t(14, weight: FontWeight.w600)),
      );

  // ----------------------------------------------------------- outstanding

  Widget _outstandingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        children: [
          _kv('Principal', _ugx(widget.principalOutstanding)),
          const SizedBox(height: 10),
          _kv('Interest', _ugx(widget.interestOutstanding)),
          const SizedBox(height: 10),
          _kv('Charges', _ugx(widget.chargesOutstanding)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: _C.line),
          ),
          _kv('Total outstanding', _ugx(_totalOutstanding), strong: true),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {bool strong = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: _t(strong ? 14 : 13,
                weight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? _C.ink : _C.muted)),
        Text(value,
            style: _t(strong ? 15 : 13,
                weight: strong ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
  }

  // ---------------------------------------------------------- payment type

  Widget _typeTile(_Option o) {
    final selected = _paymentType == o.value;
    return Material(
      color: selected ? _C.brandSoft : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _paymentType = o.value;
          _updateAmounts();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _C.brand : _C.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? _C.brand : _C.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title, style: _t(14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(o.subtitle, style: _t(12, color: _C.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountField(String label, TextEditingController ctrl, double max,
      ValueChanged<double> onChanged) {
    final over = (double.tryParse(ctrl.text) ?? 0) > max;
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: _t(14, weight: FontWeight.w500),
      onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
      decoration: _inputDecoration(
        label: label,
        prefixText: 'UGX ',
        helper: 'Outstanding: ${_ugx(max)}',
        error: over ? 'Cannot exceed ${_ugx(max)}' : null,
      ),
    );
  }

  // --------------------------------------------------------------- account

  Widget _accountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _provider,
          icon: const Icon(Icons.expand_more, color: _C.muted),
          style: _t(14, weight: FontWeight.w500),
          decoration:
              _inputDecoration(label: 'Provider', prefixIcon: Icons.sim_card_outlined),
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
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: _t(14, weight: FontWeight.w500),
                onChanged: (_) => setState(() => _verifiedAccountName = null),
                decoration: _inputDecoration(
                  label: 'Phone number',
                  hint: '256XXXXXXXXX',
                  prefixIcon: Icons.phone_outlined,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _isVerifying ? null : _verifyPhoneNumber,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.brand,
                  side: const BorderSide(color: _C.brand),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isVerifying
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _C.brand),
                      )
                    : Text('Verify', style: _t(14, weight: FontWeight.w600, color: _C.brand)),
              ),
            ),
          ],
        ),
        if (_verifiedAccountName != null) ...[
          const SizedBox(height: 12),
          _verificationResult(),
        ],
      ],
    );
  }

  Widget _verificationResult() {
    final ok = _isVerified;
    final fg = ok ? _C.brand : _C.warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? _C.brandSoft : _C.warnSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ok ? _C.brandLine : const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.info_outline,
              size: 20, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ok ? 'Registered to' : 'Not verified',
                    style: _t(12, color: fg)),
                const SizedBox(height: 2),
                Text(_verifiedAccountName!,
                    style: _t(14, weight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- summary

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.brandSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _kv('Principal', _ugx(_principalAmount)),
          const SizedBox(height: 10),
          _kv('Interest', _ugx(_interestAmount)),
          const SizedBox(height: 10),
          _kv('Charges', _ugx(_chargesAmount)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: _C.brandLine),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Amount to request',
                  style: _t(14, weight: FontWeight.w600)),
              Text(_ugx(_totalAmount),
                  style: _t(20, weight: FontWeight.w700, color: _C.brand)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- footer

  Widget _footer() {
    final canSubmit = !_isProcessing && _totalAmount > 0 && !_hasAmountError;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.ink,
                side: const BorderSide(color: _C.line),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Cancel', style: _t(14, weight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canSubmit ? _initiatePayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.brand,
                disabledBackgroundColor: _C.line,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _C.brand),
                    )
                  : Text('Send payment request',
                      style: _t(14,
                          weight: FontWeight.w600,
                          color: canSubmit ? Colors.white : _C.muted)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- helpers

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? helper,
    String? error,
    String? prefixText,
    IconData? prefixIcon,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      errorText: error,
      prefixText: prefixText,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, size: 18, color: _C.muted),
      labelStyle: _t(13, color: _C.muted),
      helperStyle: _t(12, color: _C.muted),
      errorStyle: _t(12, color: _C.error),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(_C.line),
      focusedBorder: border(_C.brand, 1.5),
      errorBorder: border(_C.error),
      focusedErrorBorder: border(_C.error, 1.5),
    );
  }
}

// ---------------------------------------------------------------------------
// Polling dialog: waits for the member to approve the request on their phone.
// Polls every 5s for up to 3 minutes (unchanged behaviour).
// ---------------------------------------------------------------------------
class _PollingDialog extends StatefulWidget {
  final String uuid;
  final String phoneNumber;

  const _PollingDialog({required this.uuid, required this.phoneNumber});

  @override
  State<_PollingDialog> createState() => _PollingDialogState();
}

class _PollingDialogState extends State<_PollingDialog> {
  static const _totalChecks = 36;
  double _progress = 0.0;
  String _status = 'processing';

  @override
  void initState() {
    super.initState();
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    for (int i = 0; i < _totalChecks; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      setState(() => _progress = (i + 1) / _totalChecks);

      try {
        _status = await FirebaseService.marzPayCheckStatus(widget.uuid);
        debugPrint('Payment status: $_status');
      } catch (e) {
        debugPrint('Error checking status: $e');
      }

      if (_status == 'completed') {
        if (mounted) Navigator.pop(context, true);
        return;
      } else if (_status == 'failed' || _status == 'cancelled') {
        if (mounted) Navigator.pop(context, false);
        return;
      }
    }
    if (mounted) Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = ((1 - _progress) * _totalChecks * 5).round();
    final mins = remainingSeconds ~/ 60;
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _C.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smartphone_outlined,
                    color: _C.brand, size: 28),
              ),
              const SizedBox(height: 20),
              Text('Waiting for approval',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _C.ink)),
              const SizedBox(height: 8),
              Text(
                'A payment request was sent to ${widget.phoneNumber}. Ask the member to enter their PIN to approve it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _C.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 6,
                  backgroundColor: _C.line,
                  color: _C.brand,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Checking status. Times out in $mins:$secs',
                style: GoogleFonts.inter(fontSize: 12, color: _C.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
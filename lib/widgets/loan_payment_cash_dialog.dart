import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Cash loan payment dialog.
///
/// Public API is unchanged from the previous version, so it is a drop-in
/// replacement. Behaviour fixes included:
/// - Custom amount fields keep their cursor while typing (controllers are
///   created once instead of on every rebuild).
/// - Amounts above the outstanding balance show an inline error instead of
///   being silently ignored.
/// - A phone number is validated when the member has none on file.
class LoanPaymentCashDialog extends StatefulWidget {
  final double principalOutstanding;
  final double interestOutstanding;
  final double chargesOutstanding;
  final String memberName;
  final String? memberPhone;
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

/// Design tokens: one brand colour, neutral greys, one error colour.
class _C {
  static const brand = Color(0xFF047857);
  static const brandSoft = Color(0xFFECFDF5);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF9FAFB);
  static const error = Color(0xFFB91C1C);
}

enum _PaymentType { full, interestOnly, principalOnly, partial }

class _LoanPaymentCashDialogState extends State<LoanPaymentCashDialog> {
  final _fmt = NumberFormat('#,###', 'en_US');

  final _altPhoneCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _chargesCtrl = TextEditingController();

  _PaymentType _type = _PaymentType.full;
  DateTime _paymentDate = DateTime.now();

  double _principal = 0;
  double _interest = 0;
  double _charges = 0;

  String? _phoneError;

  bool get _hasMemberPhone =>
      widget.memberPhone != null && widget.memberPhone!.trim().isNotEmpty;

  double get _totalOutstanding =>
      widget.principalOutstanding +
      widget.interestOutstanding +
      widget.chargesOutstanding;

  double get _total => _principal + _interest + _charges;

  @override
  void initState() {
    super.initState();
    _applyType(_PaymentType.full);
  }

  @override
  void dispose() {
    _altPhoneCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    _chargesCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- logic

  void _applyType(_PaymentType type) {
    setState(() {
      _type = type;
      switch (type) {
        case _PaymentType.full:
          _principal = widget.principalOutstanding;
          _interest = widget.interestOutstanding;
          _charges = widget.chargesOutstanding;
          break;
        case _PaymentType.interestOnly:
          _principal = 0;
          _interest = widget.interestOutstanding;
          _charges = widget.chargesOutstanding;
          break;
        case _PaymentType.principalOnly:
          _principal = widget.principalOutstanding;
          _interest = 0;
          _charges = 0;
          break;
        case _PaymentType.partial:
          // Keep whatever amounts are currently set as the starting point.
          break;
      }
      _principalCtrl.text = _principal.round().toString();
      _interestCtrl.text = _interest.round().toString();
      _chargesCtrl.text = _charges.round().toString();
    });
  }

  bool get _hasAmountError =>
      _principal > widget.principalOutstanding ||
      _interest > widget.interestOutstanding ||
      _charges > widget.chargesOutstanding;

  String get _typeValue {
    switch (_type) {
      case _PaymentType.full:
        return 'full';
      case _PaymentType.interestOnly:
        return 'interest_only';
      case _PaymentType.principalOnly:
        return 'principal_only';
      case _PaymentType.partial:
        return 'partial';
    }
  }

  void _recordPayment() {
    if (_total <= 0) {
      _showError('Enter an amount greater than zero.');
      return;
    }
    if (_hasAmountError) {
      _showError('One or more amounts exceed the outstanding balance.');
      return;
    }

    final alt = _altPhoneCtrl.text.trim();
    if (!_hasMemberPhone && alt.isEmpty) {
      setState(() => _phoneError = 'Enter a phone number to send the receipt.');
      return;
    }

    widget.onPaymentComplete({
      'principalPaid': _principal,
      'interestPaid': _interest,
      'chargesPaid': _charges,
      'totalPaid': _total,
      'paymentMethod': 'Cash',
      'paymentDate': _paymentDate,
      'paymentType': _typeValue,
      'alternativePhone': alt,
    });
    Navigator.pop(context);
  }

  void _showError(String message) {
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

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(height: 1, color: _C.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _outstandingCard(),
                    const SizedBox(height: 28),
                    _sectionTitle('Payment type'),
                    _paymentTypeList(),
                    if (_type == _PaymentType.partial) ...[
                      const SizedBox(height: 16),
                      _customAmounts(),
                    ],
                    const SizedBox(height: 28),
                    _sectionTitle('Payment date'),
                    _dateField(),
                    const SizedBox(height: 28),
                    _sectionTitle('SMS receipt'),
                    _smsSection(),
                    const SizedBox(height: 28),
                    _summaryCard(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: _C.line),
            _footer(),
          ],
        ),
      ),
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
            child: const Icon(Icons.payments_outlined,
                color: _C.brand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Record cash payment',
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
            onPressed: () => Navigator.pop(context),
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
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.line),
      ),
      padding: const EdgeInsets.all(16),
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

  Widget _paymentTypeList() {
    final options = <_Option>[
      _Option(_PaymentType.full, 'Pay full balance',
          'Principal, interest and charges'),
      _Option(_PaymentType.interestOnly, 'Interest and charges',
          'Leave principal unpaid'),
      _Option(_PaymentType.principalOnly, 'Principal only',
          'Leave interest and charges unpaid'),
      _Option(_PaymentType.partial, 'Custom amounts',
          'Choose how much goes to each part'),
    ];

    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _typeTile(options[i]),
        ],
      ],
    );
  }

  Widget _typeTile(_Option o) {
    final selected = _type == o.type;
    return Material(
      color: selected ? _C.brandSoft : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _applyType(o.type),
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

  // --------------------------------------------------------- custom amounts

  Widget _customAmounts() {
    return Column(
      children: [
        _amountField('Principal', _principalCtrl, widget.principalOutstanding,
            (v) => setState(() => _principal = v)),
        const SizedBox(height: 14),
        _amountField('Interest', _interestCtrl, widget.interestOutstanding,
            (v) => setState(() => _interest = v)),
        const SizedBox(height: 14),
        _amountField('Charges', _chargesCtrl, widget.chargesOutstanding,
            (v) => setState(() => _charges = v)),
      ],
    );
  }

  Widget _amountField(String label, TextEditingController ctrl, double max,
      ValueChanged<double> onChanged) {
    final value = double.tryParse(ctrl.text) ?? 0;
    final over = value > max;
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

  // ------------------------------------------------------------------ date

  Widget _dateField() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _paymentDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _paymentDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: _C.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('EEEE, d MMMM yyyy').format(_paymentDate),
                style: _t(14, weight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.expand_more, size: 20, color: _C.muted),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- sms

  Widget _smsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasMemberPhone)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 18, color: _C.brand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: _t(13, color: _C.muted),
                      children: [
                        const TextSpan(text: 'Receipt will be sent to '),
                        TextSpan(
                          text: widget.memberPhone!,
                          style: _t(13, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_hasMemberPhone) const SizedBox(height: 12),
        TextField(
          controller: _altPhoneCtrl,
          keyboardType: TextInputType.phone,
          style: _t(14, weight: FontWeight.w500),
          onChanged: (_) {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
          decoration: _inputDecoration(
            label: _hasMemberPhone
                ? 'Additional recipient (optional)'
                : 'Phone number',
            hint: '256XXXXXXXXX',
            helper: _hasMemberPhone
                ? 'For example a spouse or guarantor'
                : 'No phone on file for this member',
            error: _phoneError,
            prefixIcon: Icons.phone_outlined,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- summary

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.brandSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _kv('Principal', _ugx(_principal)),
          const SizedBox(height: 10),
          _kv('Interest', _ugx(_interest)),
          const SizedBox(height: 10),
          _kv('Charges', _ugx(_charges)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFA7F3D0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Amount received',
                  style: _t(14, weight: FontWeight.w600)),
              Text(_ugx(_total),
                  style: _t(20, weight: FontWeight.w700, color: _C.brand)),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- footer

  Widget _footer() {
    final canSubmit = _total > 0 && !_hasAmountError;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
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
              onPressed: canSubmit ? _recordPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.brand,
                disabledBackgroundColor: _C.line,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Record payment',
                style: _t(14,
                    weight: FontWeight.w600,
                    color: canSubmit ? Colors.white : _C.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- helpers

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
      prefixIcon:
          prefixIcon == null ? null : Icon(prefixIcon, size: 18, color: _C.muted),
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

class _Option {
  final _PaymentType type;
  final String title;
  final String subtitle;
  const _Option(this.type, this.title, this.subtitle);
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/payment_countries.dart';
import '../../widgets/centered_loader.dart';
import '../../widgets/country_selector.dart';

enum _SendState { form, otp, processing, success, error }

const _purple = Color(0xFF7C3AED);

class ModernSendMoneyModal extends StatefulWidget {
  final int balance;
  final String registeredPhone;
  final VoidCallback onSuccess;

  const ModernSendMoneyModal({
    super.key,
    required this.balance,
    required this.registeredPhone,
    required this.onSuccess,
  });

  @override
  State<ModernSendMoneyModal> createState() => _ModernSendMoneyModalState();
}

class _ModernSendMoneyModalState extends State<ModernSendMoneyModal> {
  final fmt = NumberFormat('#,###', 'en_US');
  final _amountCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _otpCtrl    = TextEditingController();

  // ── Country / currency state ──────────────────────────────────────────────
  PaymentCountry _country  = PaymentCountries.uganda;
  String _currency = 'UGX';

  // ── Forex state ───────────────────────────────────────────────────────────
  double? _forexRate;        // rate: 1 UGX = X target currency
  bool   _fetchingRate = false;
  String? _rateError;

  Map<String, dynamic>? _verified;
  bool _verifying = false;

  _SendState _state = _SendState.form;
  String _errorMsg   = '';
  String _successMsg = '';

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get _charge => (_amount * AppConstants.walletWithdrawChargePercent)
      .ceil()
      .clamp(AppConstants.walletMinCharge, 999999);
  int get _total => _amount + _charge;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _phoneCtrl.addListener(() {
      if (_verified != null) setState(() => _verified = null);
    });
  }

  void _onCountryChanged(PaymentCountry country) {
    setState(() {
      _country  = country;
      _currency = country.currency;
      _verified = null;
      _phoneCtrl.text = country.dialCode + ' ';
      _forexRate  = null;
      _rateError  = null;
    });
    // Fetch live rate for non-Uganda countries
    if (country.code != 'UG') {
      _fetchForexRate(country.currency);
    }
  }

  Future<void> _fetchForexRate(String targetCurrency) async {
    setState(() { _fetchingRate = true; _rateError = null; });
    try {
      final rates = await FirebaseService.getForexRates(baseCurrency: 'UGX');
      final rate = rates[targetCurrency];
      if (!mounted) return;
      setState(() {
        _forexRate   = rate;
        _fetchingRate = false;
        if (rate == null) _rateError = 'Rate unavailable';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _fetchingRate = false; _rateError = 'Rate unavailable'; });
    }
  }

  /// Recipient amount in target currency (converted from UGX amount)
  String get _recipientAmountDisplay {
    if (_country.code == 'UG') return '${_country.currencySymbol} ${fmt.format(_amount)}';
    if (_forexRate == null) return '...';
    final converted = (_amount * _forexRate!).round();
    return '${_country.currencySymbol} ${fmt.format(converted)}';
  }

  /// Exchange rate display string
  String get _rateDisplay {
    if (_country.code == 'UG' || _forexRate == null) return '';
    final rate = _forexRate!;
    if (rate >= 1) return '1 UGX = ${rate.toStringAsFixed(2)} ${_country.currencySymbol}';
    return '1 ${_country.currencySymbol} = ${(1 / rate).toStringAsFixed(2)} UGX';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (!PaymentCountries.isValidPhone(phone, _country)) {
      _snack('Enter a valid ${_country.dialCode} number', AppTheme.warning);
      return;
    }
    if (_country.code != 'UG') {
      _snack('Phone verification not available in ${_country.name} yet — you can still proceed', AppTheme.warning);
      return;
    }
    setState(() => _verifying = true);
    try {
      final r = await FirebaseService.verifyPhoneNumber(phone, countryCode: _country.code);
      setState(() {
        _verifying = false;
        _verified  = r['verified'] == true ? r : null;
      });
      if (r['verified'] != true) {
        _snack('Name not found — you can still proceed', AppTheme.warning);
      }
    } catch (_) {
      setState(() => _verifying = false);
      _snack('Verification unavailable', AppTheme.warning);
    }
  }

  void _onSendTapped() {
    if (_amount < _country.minAmount) {
      _snack('Minimum is ${_country.currencySymbol} ${fmt.format(_country.minAmount)}', AppTheme.warning);
      return;
    }
    if (_total > widget.balance) {
      setState(() {
        _state    = _SendState.error;
        _errorMsg = 'Insufficient balance.\n\nYou need ${_country.currencySymbol} ${fmt.format(_total)} but have ${_country.currencySymbol} ${fmt.format(widget.balance)}.';
      });
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (!PaymentCountries.isValidPhone(phone, _country)) {
      _snack('Enter a valid ${_country.dialCode} number', AppTheme.warning);
      return;
    }
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    setState(() => _state = _SendState.processing);
    final sent = await FirebaseService.generateAndSendOtp(widget.registeredPhone);
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _state    = _SendState.error;
        _errorMsg = 'Could not send OTP. Please try again.';
      });
      return;
    }
    setState(() => _state = _SendState.otp);
  }

  Future<void> _confirmOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) { _snack('Enter the 6-digit code', AppTheme.warning); return; }
    if (!FirebaseService.verifyEgoOtp(widget.registeredPhone, code)) {
      _snack('Incorrect code', AppTheme.error);
      return;
    }
    _doSend();
  }

  Future<void> _doSend() async {
    setState(() => _state = _SendState.processing);
    try {
      final phone = PaymentCountries.formatPhone(_phoneCtrl.text.trim(), _country);
      await FirebaseService.walletWithdraw(
        uid: FirebaseService.sessionUid,
        amount: _amount,
        chargeAmount: _charge,
        phoneNumber: phone,
        recipientName: _verified?['full_name'] ?? phone,
        countryCode: _country.code,
        currencyCode: _currency,
      );
      if (!mounted) return;
      setState(() {
        _state      = _SendState.success;
        _successMsg = '${_country.currencySymbol} ${fmt.format(_amount)} sent to ${_verified?['full_name'] ?? phone}.\n\nCharge: ${_country.currencySymbol} ${fmt.format(_charge)}\nTotal deducted: ${_country.currencySymbol} ${fmt.format(_total)}';
      });
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _state    = _SendState.error;
        _errorMsg = _friendlyError(msg);
      });
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient') || lower.contains('balance')) {
      return 'You don\'t have enough balance for this transfer.\n\nPlease top up your wallet and try again.';
    }
    if (lower.contains('whitelist') || lower.contains('ip')) {
      return 'Send Money is only available on the Android app due to network restrictions.';
    }
    if (lower.contains('timeout') || lower.contains('network')) {
      return 'Network timeout. Please check your connection and try again.';
    }
    if (lower.contains('invalid') && lower.contains('phone')) {
      return 'The phone number is invalid. Please check and try again.';
    }
    return raw.isNotEmpty ? raw : 'Transfer could not be completed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_state) {
              _SendState.form       => _buildForm(),
              _SendState.otp        => _buildOtp(),
              _SendState.processing => _buildProcessing(),
              _SendState.success    => _buildResult(success: true),
              _SendState.error      => _buildResult(success: false),
            },
          ),
        ),
      ),
    );
  }

  // ── FORM ───────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    final hasAmount = _amount >= _country.minAmount;

    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, color: _purple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Send Money',
                        style: GoogleFonts.poppins(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(
                      _country.code == 'UG' || _forexRate == null
                          ? 'Balance: UGX ${fmt.format(widget.balance)}'
                          : 'Balance: UGX ${fmt.format(widget.balance)} ≈ ${_country.currencySymbol} ${fmt.format((widget.balance * _forexRate!).round())}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded,
                    color: Colors.grey.shade400, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Country Selector ──────────────────────────────────────────────
          Text('Country',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          CountrySelector(
            selected: _country,
            selectedCurrency: _currency,
            onCountryChanged: _onCountryChanged,
            onCurrencyChanged: (cur) => setState(() => _currency = cur),
          ),

          const SizedBox(height: 16),

          // Amount label
          Text('Amount (${_country.currencySymbol})',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),

          // Amount input — clean single row
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasAmount ? _purple.withOpacity(0.4) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: hasAmount
                        ? _purple.withOpacity(0.08)
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(11)),
                    border: Border(
                        right: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Text(_country.currencySymbol,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: hasAmount ? _purple : Colors.grey.shade500)),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Quick amounts
          Row(
            children: [5000, 10000, 20000, 50000].map((v) {
              final sel = _amount == v;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _amountCtrl.text = v.toString()),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: v != 50000 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _purple : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? _purple : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      v >= 1000 ? '${v ~/ 1000}K' : '$v',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.textSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Phone label
          Text('Recipient\'s Number',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),

          // Phone + verify in one row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: _country.phoneHint,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      prefixIcon: Icon(Icons.phone_android,
                          color: _purple.withOpacity(0.7), size: 18),
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_country.code == 'UG')
              GestureDetector(
                onTap: _verifying ? null : _verifyPhone,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: _verified != null ? AppTheme.success : _purple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _verified != null ? '✓ Verified' : 'Verify',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),

          // Verified name card
          if (_verified != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recipient Verified',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600)),
                        Text(_verified!['full_name'] ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Charges breakdown
          if (hasAmount) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _row('Amount to send', '${_country.currencySymbol} ${fmt.format(_amount)}'),
                  const SizedBox(height: 6),
                  _row('Service charge (3.5%)',
                      '${_country.currencySymbol} ${fmt.format(_charge)}',
                      valueColor: AppTheme.warning),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Colors.grey.shade200),
                  ),
                  _row('Total deducted', '${_country.currencySymbol} ${fmt.format(_total)}',
                      bold: true, valueColor: _purple),
                  const SizedBox(height: 6),
                  // Forex-aware recipient amount
                  if (_country.code == 'UG')
                    _row('Recipient gets', '${_country.currencySymbol} ${fmt.format(_amount)}',
                        valueColor: AppTheme.success)
                  else ...[
                    _row(
                      'Recipient gets',
                      _fetchingRate
                          ? 'Fetching rate...'
                          : _rateError != null
                              ? _rateError!
                              : _recipientAmountDisplay,
                      valueColor: _fetchingRate || _rateError != null
                          ? AppTheme.textSecondary
                          : AppTheme.success,
                    ),
                    if (_rateDisplay.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.currency_exchange_rounded,
                              size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(_rateDisplay,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary)),
                          const SizedBox(width: 4),
                          Text('• exchangerate-api.com',
                              style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasAmount ? _onSendTapped : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                hasAmount
                    ? 'Send ${_country.currencySymbol} ${fmt.format(_amount)}'
                    : 'Enter amount to continue',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── OTP ────────────────────────────────────────────────────────────────────
  Widget _buildOtp() {
    return Padding(
      key: const ValueKey('otp'),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: _purple, size: 32),
          ),
          const SizedBox(height: 14),
          Text('Enter Security Code',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'A 6-digit code was sent to\n${widget.registeredPhone}',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 26, fontWeight: FontWeight.w800,
                letterSpacing: 10),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 26, color: Colors.grey.shade300,
                  letterSpacing: 10),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Confirm & Send',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _state = _SendState.form),
            child: Text('← Back',
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── PROCESSING ─────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return SizedBox(
      key: const ValueKey('processing'),
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _handle(),
          const Expanded(
            child: CenteredLoader(
              color: _purple,
              message: "Sending Your Money",
              subMessage: "Money is on the way!\nPlease wait, do not close this screen.",
            ),
          ),
        ],
      ),
    );
  }

  // ── RESULT ─────────────────────────────────────────────────────────────────
  Widget _buildResult({required bool success}) {
    final color = success ? AppTheme.success : AppTheme.error;
    final icon  = success ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Padding(
      key: ValueKey(success),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const SizedBox(height: 16),
          Text(success ? 'Money Sent!' : 'Transfer Failed',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(success ? _successMsg : _errorMsg,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(success ? 'Done' : 'Close',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          if (!success) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _state = _SendState.form;
                _errorMsg = '';
              }),
              child: Text('Try Again',
                  style: GoogleFonts.poppins(
                      color: _purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _row(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/payment_countries.dart';
import '../../widgets/centered_loader.dart';
import '../../widgets/country_selector.dart';

class ModernWithdrawModal extends StatefulWidget {
  final int balance;
  final String registeredPhone;
  final VoidCallback onSuccess;

  const ModernWithdrawModal({
    super.key,
    required this.balance,
    required this.registeredPhone,
    required this.onSuccess,
  });

  @override
  State<ModernWithdrawModal> createState() => _ModernWithdrawModalState();
}

class _ModernWithdrawModalState extends State<ModernWithdrawModal> {
  final fmt = NumberFormat('#,###', 'en_US');
  final _amountCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _otpCtrl    = TextEditingController();

  // ── Country / currency state ──────────────────────────────────────────────
  PaymentCountry _country  = PaymentCountries.uganda;
  String _currency = 'UGX';

  // ── Forex state ───────────────────────────────────────────────────────────
  double? _forexRate;
  bool   _fetchingRate = false;
  String? _rateError;

  Map<String, dynamic>? _verified;
  bool _verifying = false;

  _ModalState _state = _ModalState.form;
  String _errorMsg  = '';
  String _successMsg = '';

  // computed
  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get _charge => (_amount * AppConstants.walletWithdrawChargePercent)
      .ceil()
      .clamp(AppConstants.walletMinCharge, 999999);
  int get _total  => _amount + _charge;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.text = FirebaseService.formatPhoneForMarzPay(widget.registeredPhone);
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
      _forexRate = null;
      _rateError = null;
    });
    if (country.code != 'UG') _fetchForexRate(country.currency);
  }

  Future<void> _fetchForexRate(String targetCurrency) async {
    setState(() { _fetchingRate = true; _rateError = null; });
    try {
      final rates = await FirebaseService.getForexRates(baseCurrency: 'UGX');
      final rate  = rates[targetCurrency];
      if (!mounted) return;
      setState(() {
        _forexRate    = rate;
        _fetchingRate = false;
        if (rate == null) _rateError = 'Rate unavailable';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _fetchingRate = false; _rateError = 'Rate unavailable'; });
    }
  }

  String get _recipientAmountDisplay {
    if (_country.code == 'UG') return '${_country.currencySymbol} ${fmt.format(_amount)}';
    if (_forexRate == null) return '...';
    final converted = (_amount * _forexRate!).round();
    return '${_country.currencySymbol} ${fmt.format(converted)}';
  }

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

  // ── Verify phone name ──────────────────────────────────────────────────────
  Future<void> _verifyPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (!PaymentCountries.isValidPhone(phone, _country)) {
      _snack('Enter a valid ${_country.dialCode} phone number', AppTheme.warning);
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
      _snack('Verification unavailable — you can still proceed', AppTheme.warning);
    }
  }

  // ── Validate form then show OTP ────────────────────────────────────────────
  void _onWithdrawTapped() {
    if (_amount < _country.minAmount) {
      _snack('Minimum withdrawal is ${_country.currencySymbol} ${fmt.format(_country.minAmount)}', AppTheme.warning);
      return;
    }
    if (_total > widget.balance) {
      setState(() {
        _state    = _ModalState.error;
        _errorMsg = 'Your balance (${_country.currencySymbol} ${fmt.format(widget.balance)}) is not enough.\n\n'
            'You need ${_country.currencySymbol} ${fmt.format(_total)} '
            '(${_country.currencySymbol} ${fmt.format(_amount)} + ${_country.currencySymbol} ${fmt.format(_charge)} charge).';
      });
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (!PaymentCountries.isValidPhone(phone, _country)) {
      _snack('Enter a valid ${_country.dialCode} phone number', AppTheme.warning);
      return;
    }
    _sendOtp();
  }

  // ── Send OTP ───────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    setState(() => _state = _ModalState.processing);
    final sent = await FirebaseService.generateAndSendOtp(widget.registeredPhone);
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _state    = _ModalState.error;
        _errorMsg = 'Could not send OTP to your registered number.\nPlease try again.';
      });
      return;
    }
    setState(() => _state = _ModalState.otp);
  }

  // ── Confirm OTP then withdraw ──────────────────────────────────────────────
  Future<void> _confirmOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      _snack('Enter the 6-digit code', AppTheme.warning);
      return;
    }
    final ok = FirebaseService.verifyEgoOtp(widget.registeredPhone, code);
    if (!ok) {
      _snack('Incorrect code. Please try again.', AppTheme.error);
      return;
    }
    _doWithdraw();
  }

  // ── Execute withdrawal ─────────────────────────────────────────────────────
  Future<void> _doWithdraw() async {
    setState(() => _state = _ModalState.processing);
    try {
      final uid  = FirebaseService.sessionUid;
      final name = FirebaseService.sessionProfile?['name'] ?? 'Member';
      final phone = PaymentCountries.formatPhone(_phoneCtrl.text.trim(), _country);
      await FirebaseService.walletWithdraw(
        uid: uid,
        amount: _amount,
        chargeAmount: _charge,
        phoneNumber: phone,
        recipientName: _verified?['full_name'] ?? name,
        countryCode: _country.code,
        currencyCode: _currency,
      );
      if (!mounted) return;
      final recipientDisplay = _verified != null
          ? _verified!['full_name'] as String
          : phone;
      setState(() {
        _state      = _ModalState.success;
        _successMsg = '${_country.currencySymbol} ${fmt.format(_amount)} sent to $recipientDisplay.\n\n'
            'Charge: ${_country.currencySymbol} ${fmt.format(_charge)}\n'
            'Total deducted: ${_country.currencySymbol} ${fmt.format(_total)}';
      });
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _state    = _ModalState.error;
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
      return 'You don\'t have enough balance for this withdrawal.\n\nPlease deposit more funds and try again.';
    }
    if (lower.contains('whitelist') || lower.contains('ip')) {
      return 'Withdrawals are only available on the Android app due to network restrictions.';
    }
    if (lower.contains('timeout') || lower.contains('network')) {
      return 'Network timeout. Please check your connection and try again.';
    }
    if (lower.contains('invalid') && lower.contains('phone')) {
      return 'The phone number is invalid. Please check and try again.';
    }
    return raw.isNotEmpty ? raw : 'Withdrawal could not be completed. Please try again.';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_state) {
              _ModalState.form       => _buildForm(),
              _ModalState.otp        => _buildOtp(),
              _ModalState.processing => _buildProcessing(),
              _ModalState.success    => _buildResult(success: true),
              _ModalState.error      => _buildResult(success: false),
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
        left: 24, right: 24, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppTheme.error, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Withdraw Money',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(
                        _country.code == 'UG' || _forexRate == null
                            ? 'Available: ${_country.currencySymbol} ${fmt.format(widget.balance)}'
                            : 'Available: UGX ${fmt.format(widget.balance)} ≈ ${_country.currencySymbol} ${fmt.format((widget.balance * _forexRate!).round())}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: Colors.grey.shade500, size: 22),
                ),
              ],
            ),
          ),

          // ── Country Selector ──────────────────────────────────────────
          Text('Country',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          CountrySelector(
            selected: _country,
            selectedCurrency: _currency,
            onCountryChanged: _onCountryChanged,
            onCurrencyChanged: (cur) => setState(() => _currency = cur),
          ),

          const SizedBox(height: 20),

          // ── Amount ────────────────────────────────────────────────────────
          Text('Amount',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasAmount
                    ? AppTheme.primary.withOpacity(0.5)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(_country.currencySymbol,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.w800,
                          color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick amounts
          Wrap(
            spacing: 8,
            children: [10000, 20000, 50000, 100000].map((v) {
              final selected = _amount == v;
              return GestureDetector(
                onTap: () => setState(() => _amountCtrl.text = v.toString()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(fmt.format(v),
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppTheme.textPrimary)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // ── Phone + Verify ────────────────────────────────────────────────
          Text('Mobile Money Number',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_android,
                        color: AppTheme.primary, size: 20),
                    hintText: _country.phoneHint,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_country.code == 'UG')
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verifyPhone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verified != null
                        ? AppTheme.success
                        : AppTheme.info,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _verified != null ? 'Verified ✓' : 'Verify Name',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),

          // ── Verified Name Card ────────────────────────────────────────────
          if (_verified != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppTheme.success, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recipient Verified',
                            style: GoogleFonts.poppins(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.85))),
                        const SizedBox(height: 2),
                        Text(_verified!['full_name'] ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Charges Summary ───────────────────────────────────────────────
          if (hasAmount) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _row('Amount', '${_country.currencySymbol} ${fmt.format(_amount)}'),
                  const SizedBox(height: 8),
                  _row('Service Charge (3.5%)', '${_country.currencySymbol} ${fmt.format(_charge)}',
                      valueColor: AppTheme.warning),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _row('Total Deducted', '${_country.currencySymbol} ${fmt.format(_total)}',
                      bold: true, valueColor: AppTheme.error),
                  const SizedBox(height: 8),
                  if (_country.code == 'UG')
                    _row('Recipient receives', '${_country.currencySymbol} ${fmt.format(_amount)}',
                        valueColor: AppTheme.success)
                  else ...[
                    _row(
                      'Recipient receives',
                      _fetchingRate
                          ? 'Fetching rate...'
                          : _rateError != null ? _rateError! : _recipientAmountDisplay,
                      valueColor: _fetchingRate || _rateError != null
                          ? AppTheme.textSecondary : AppTheme.success,
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
                                  fontSize: 10, color: AppTheme.textSecondary)),
                          const SizedBox(width: 4),
                          Text('• exchangerate-api.com',
                              style: GoogleFonts.poppins(
                                  fontSize: 9, color: Colors.grey.shade400)),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Withdraw Button ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasAmount ? _onWithdrawTapped : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                hasAmount
                    ? 'Withdraw ${_country.currencySymbol} ${fmt.format(_amount)}'
                    : 'Enter Amount to Continue',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700),
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
        left: 24, right: 24, top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: AppTheme.info, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Security Verification',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'A 6-digit code was sent to\n${widget.registeredPhone}\n\nEnter it below to confirm the withdrawal.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 28, fontWeight: FontWeight.w800,
                letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 28, color: Colors.grey.shade300,
                  letterSpacing: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('Confirm Withdrawal',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _state = _ModalState.form),
            child: Text('← Go Back',
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── PROCESSING ─────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return Padding(
      key: const ValueKey('processing'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 32),
          const CenteredLoader(
            color: AppTheme.primary,
            message: 'Processing Withdrawal',
            subMessage: 'Please wait, do not close this screen.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── SUCCESS / ERROR ────────────────────────────────────────────────────────
  Widget _buildResult({required bool success}) {
    final color = success ? AppTheme.success : AppTheme.error;
    final icon  = success ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = success ? 'Withdrawal Successful!' : 'Withdrawal Failed';
    final msg   = success ? _successMsg : _errorMsg;

    return Padding(
      key: ValueKey(success ? 'success' : 'error'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 32),

          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 56),
          ),
          const SizedBox(height: 20),

          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(msg,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
              textAlign: TextAlign.center),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(success ? 'Done' : 'Close',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          if (!success) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _state = _ModalState.form;
                _errorMsg = '';
              }),
              child: Text('Try Again',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40, height: 4,
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
                fontSize: 13, color: AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary)),
      ],
    );
  }
}

// ─── States the modal can be in ──────────────────────────────────────────────
enum _ModalState { form, otp, processing, success, error }

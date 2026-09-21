import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/payment_countries.dart';
import '../../widgets/centered_loader.dart';
import '../../widgets/country_selector.dart';

enum _DepositState { form, processing, success, failed, timeout }

class ModernDepositModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const ModernDepositModal({super.key, required this.onSuccess});

  @override
  State<ModernDepositModal> createState() => _ModernDepositModalState();
}

class _ModernDepositModalState extends State<ModernDepositModal> {
  final fmt = NumberFormat('#,###', 'en_US');
  final _amountCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();

  // ── Country / currency state ──────────────────────────────────────────────
  PaymentCountry _country  = PaymentCountries.uganda; // Uganda default
  String _currency = 'UGX';

  String _network = 'MTN';
  Map<String, dynamic>? _verified;
  bool _verifying = false;

  _DepositState _state = _DepositState.form;
  double _pollProgress = 0.0;
  String _successMsg = '';
  String _failMsg    = '';

  // For re-check after timeout
  String? _pendingUuid;
  String? _pendingTxnId;
  int?    _pendingAmount;

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get _charge => (_amount * AppConstants.walletDepositChargePercent)
      .ceil()
      .clamp(AppConstants.walletMinCharge, 999999);
  int get _totalCollected => _amount + _charge;

  static const _networkColors = {
    'MTN':   Color(0xFFFFCC00),
    'Airtel': Color(0xFFE40000),
  };

  @override
  void initState() {
    super.initState();
    final profile = FirebaseService.sessionProfile;
    final regPhone = profile?['phone'] as String? ?? '';
    _phoneCtrl.text = FirebaseService.formatPhoneForMarzPay(regPhone);
    _amountCtrl.addListener(() => setState(() {}));
    _phoneCtrl.addListener(() {
      if (_verified != null) setState(() => _verified = null);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Called when user changes country ────────────────────────────────────────
  void _onCountryChanged(PaymentCountry country) {
    setState(() {
      _country  = country;
      _currency = country.currency;
      _verified = null;
      // Pre-fill phone with country dial code
      _phoneCtrl.text = country.dialCode + ' ';
      // Reset network to first available for the new country
      _network = country.networks.isNotEmpty ? country.networks.first : 'MTN';
    });
  }

  // ── Verify phone name ──────────────────────────────────────────────────────
  Future<void> _verifyPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (!PaymentCountries.isValidPhone(phone, _country)) {
      _snack('Enter a valid ${_country.dialCode} phone number', AppTheme.warning);
      return;
    }
    // Only Uganda supports phone verification via MarzPay currently
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

  // ── Validate & start deposit ───────────────────────────────────────────────
  void _onDepositTapped() {
    if (_amount < _country.minAmount) {
      _snack('Minimum deposit is ${_country.currencySymbol} ${fmt.format(_country.minAmount)}', AppTheme.warning);
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (!PaymentCountries.isValidPhone(phone, _country)) {
      _snack('Enter a valid ${_country.dialCode} phone number', AppTheme.warning);
      return;
    }
    _doDeposit(PaymentCountries.formatPhone(phone, _country));
  }

  // ── Execute deposit ────────────────────────────────────────────────────────
  Future<void> _doDeposit(String phone) async {
    setState(() => _state = _DepositState.processing);
    try {
      final uid    = FirebaseService.sessionUid;
      final result = await FirebaseService.walletDeposit(
        uid: uid,
        amount: _totalCollected,
        phoneNumber: phone,
        countryCode: _country.code,
        currencyCode: _currency,
      );

      final uuid  = result['uuid']  as String;
      final txnId = result['txnId'] as String;
      final depositedAmount = _amount;

      _pendingUuid   = uuid;
      _pendingTxnId  = txnId;
      _pendingAmount = depositedAmount;

      // Poll up to 3 minutes (36 × 5s) with automatic status checking
      String status = 'processing';
      for (int i = 0; i < 36; i++) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        if (mounted) setState(() => _pollProgress = (i + 1) / 36);
        try {
          status = await FirebaseService.marzPayCheckStatus(uuid);
        } catch (e) {
          // continue polling
        }
        if (status == 'completed' || status == 'failed' || status == 'cancelled') break;
      }

      if (!mounted) return;

      if (status == 'completed') {
        await FirebaseService.confirmWalletDeposit(
            uid: uid, txnId: txnId, amount: depositedAmount);
        setState(() {
          _state      = _DepositState.success;
          _successMsg = '${_country.currencySymbol} ${fmt.format(depositedAmount)} has been added to your wallet.\n\n'
              'Charge: ${_country.currencySymbol} ${fmt.format(_charge)}\n'
              'Total collected: ${_country.currencySymbol} ${fmt.format(_totalCollected)}';
        });
        widget.onSuccess();
      } else if (status == 'failed' || status == 'cancelled') {
        await FirebaseService.updateWalletTxnStatus(txnId, 'failed');
        setState(() {
          _state   = _DepositState.failed;
          _failMsg = 'The payment was declined or cancelled.\nPlease try again.';
        });
      } else {
        // No response in 3 minutes — continue checking in background
        print('DEBUG: Initial polling timeout, continuing background checks...');
        _continueBackgroundPolling(uuid, txnId, depositedAmount);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state   = _DepositState.failed;
        _failMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Re-check after timeout ─────────────────────────────────────────────────
  Future<void> _recheck() async {
    if (_pendingUuid == null || _pendingTxnId == null || _pendingAmount == null) return;
    setState(() => _state = _DepositState.processing);
    try {
      // First try MarzPay status API
      final status = await FirebaseService.marzPayCheckStatus(_pendingUuid!);
      if (!mounted) return;
      if (status == 'completed') {
        final uid = FirebaseService.sessionUid;
        await FirebaseService.confirmWalletDeposit(
            uid: uid, txnId: _pendingTxnId!, amount: _pendingAmount!);
        await FirebaseService.updateWalletTxnStatus(_pendingTxnId!, 'completed');
        setState(() {
          _state      = _DepositState.success;
          _successMsg = 'UGX ${fmt.format(_pendingAmount!)} has been added to your wallet.';
        });
        widget.onSuccess();
      } else {
        // Status still not confirmed — offer force-confirm
        setState(() => _state = _DepositState.timeout);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _DepositState.timeout);
    }
  }

  // ── Continue background polling after initial timeout ──────────────────────
  Future<void> _continueBackgroundPolling(String uuid, String txnId, int depositedAmount) async {
    // Keep showing processing state while continuing to poll
    setState(() => _state = _DepositState.processing);
    
    // Continue polling for up to 10 more minutes (120 × 5s)
    String status = 'processing';
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      
      try {
        status = await FirebaseService.marzPayCheckStatus(uuid);
        print('DEBUG: Background poll ${i + 1}/120, Status: $status');
        
        if (status == 'completed') {
          final uid = FirebaseService.sessionUid;
          await FirebaseService.confirmWalletDeposit(
              uid: uid, txnId: txnId, amount: depositedAmount);
          setState(() {
            _state = _DepositState.success;
            _successMsg = '${_country.currencySymbol} ${fmt.format(depositedAmount)} has been added to your wallet.\n\n'
                'Charge: ${_country.currencySymbol} ${fmt.format(_charge)}\n'
                'Total collected: ${_country.currencySymbol} ${fmt.format(_totalCollected)}';
          });
          widget.onSuccess();
          return;
        } else if (status == 'failed' || status == 'cancelled') {
          await FirebaseService.updateWalletTxnStatus(txnId, 'failed');
          setState(() {
            _state = _DepositState.failed;
            _failMsg = 'The payment was declined or cancelled.\nPlease try again.';
          });
          return;
        }
      } catch (e) {
        print('DEBUG: Background status check error: $e');
        // Continue polling even on errors
      }
    }
    
    // If still no response after 13+ minutes total, show timeout
    if (!mounted) return;
    setState(() => _state = _DepositState.timeout);
  }

  /// Force-confirm when user insists money was deducted
  Future<void> _forceConfirm() async {
    if (_pendingUuid == null) return;
    setState(() => _state = _DepositState.processing);
    try {
      final confirmed = await FirebaseService.forceConfirmPendingDeposit(_pendingUuid!);
      if (!mounted) return;
      if (confirmed) {
        setState(() {
          _state      = _DepositState.success;
          _successMsg = 'Your wallet has been credited.\n\nIf there is any discrepancy, please contact support.';
        });
        widget.onSuccess();
      } else {
        setState(() {
          _state   = _DepositState.failed;
          _failMsg = 'Could not find a pending transaction to confirm.\nPlease contact support with your transaction reference.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state   = _DepositState.failed;
        _failMsg = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
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
              _DepositState.form       => _buildForm(),
              _DepositState.processing => _buildProcessing(),
              _DepositState.success    => _buildResult(
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.success,
                  title: 'Deposit Successful!',
                  message: _successMsg,
                  primaryLabel: 'Done',
                  onPrimary: () => Navigator.pop(context),
                ),
              _DepositState.failed     => _buildResult(
                  icon: Icons.cancel_rounded,
                  color: AppTheme.error,
                  title: 'Deposit Failed',
                  message: _failMsg,
                  primaryLabel: 'Try Again',
                  onPrimary: () => setState(() {
                    _state = _DepositState.form;
                    _failMsg = '';
                  }),
                  secondaryLabel: 'Close',
                  onSecondary: () => Navigator.pop(context),
                ),
              _DepositState.timeout    => _buildResult(
                  icon: Icons.hourglass_empty_rounded,
                  color: AppTheme.warning,
                  title: 'No Response Yet',
                  message: 'No confirmation received.\n\nIf money was deducted from your phone, tap "Money Was Deducted" to credit your wallet.',
                  primaryLabel: 'Check Again',
                  onPrimary: _recheck,
                  secondaryLabel: 'Money Was Deducted',
                  onSecondary: _forceConfirm,
                  tertiaryLabel: 'Close',
                  onTertiary: () => Navigator.pop(context),
                ),
            },
          ),
        ),
      ),
    );
  }

  // ── FORM ───────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    final hasAmount = _amount >= _country.minAmount;
    final netColor  = _networkColors[_network] ?? const Color(0xFF1976D2);

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

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add_circle_rounded,
                      color: AppTheme.success, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deposit Money',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('Add money to your wallet via mobile money',
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

          // ── Country Selector ──────────────────────────────────────────────
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

          // ── Network Selector (dynamic per country) ────────────────────────
          Text('Select Network',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _country.networks.map((n) {
                final selected = _network == n;
                final color    = _networkColors[n] ?? const Color(0xFF1976D2);
                return GestureDetector(
                  onTap: () => setState(() => _network = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.12) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? color : Colors.grey.shade300,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.signal_cellular_alt_rounded,
                            color: selected ? color : Colors.grey.shade400,
                            size: 22),
                        const SizedBox(height: 4),
                        Text(n,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected ? color : Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

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
                    ? AppTheme.success.withOpacity(0.5)
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
            children: [5000, 10000, 20000, 50000].map((v) {
              final selected = _amount == v;
              return GestureDetector(
                onTap: () => setState(() => _amountCtrl.text = v.toString()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.success : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppTheme.success : Colors.grey.shade300,
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
                        color: AppTheme.success, size: 20),
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
                      borderSide: const BorderSide(
                          color: AppTheme.success, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Only show verify button for Uganda (MarzPay verification is UG-only)
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
                        Text('Account Verified',
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
                  _row('You send (from phone)', '${_country.currencySymbol} ${fmt.format(_totalCollected)}'),
                  const SizedBox(height: 8),
                  _row('Service Charge (3.2%)', '${_country.currencySymbol} ${fmt.format(_charge)}',
                      valueColor: AppTheme.warning),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  _row('Added to wallet', '${_country.currencySymbol} ${fmt.format(_amount)}',
                      bold: true, valueColor: AppTheme.success),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // USSD prompt notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You will receive a USSD prompt on your phone. Approve it to complete the deposit.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── Deposit Button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasAmount ? _onDepositTapped : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: netColor,
                foregroundColor: _network == 'MTN' ? Colors.black87 : Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                hasAmount
                    ? 'Deposit ${_country.currencySymbol} ${fmt.format(_amount)} via $_network'
                    : 'Enter Amount to Continue',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PROCESSING ─────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    return SizedBox(
      key: const ValueKey('processing'),
      height: 320,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _handle(),
          Expanded(
            child: CenteredLoader(
              progress: _pollProgress > 0 ? _pollProgress : null,
              color: AppTheme.success,
              message: 'Checking Payment Status',
              subMessage: 'Approve the USSD prompt on your phone.\nThis may take a few minutes...',
            ),
          ),
        ],
      ),
    );
  }

  // ── RESULT (success / failed / timeout) ────────────────────────────────────
  Widget _buildResult({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? tertiaryLabel,
    VoidCallback? onTertiary,
  }) {
    return Padding(
      key: ValueKey(title),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          const SizedBox(height: 32),
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
          Text(message,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(primaryLabel,
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(secondaryLabel,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          if (tertiaryLabel != null && onTertiary != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onTertiary,
              child: Text(tertiaryLabel,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
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

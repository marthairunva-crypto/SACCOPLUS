import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/migration_service.dart';
import '../../core/sacco_service.dart';
import '../../core/account_number_service.dart';
import '../../widgets/app_widgets.dart';
import '../farmer/farmer_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../admin/platform_admin_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            AppConstants.logoPath,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                              begin: const Offset(0.4, 0.4),
                              duration: 600.ms,
                              curve: Curves.elasticOut)
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: 14),
                      Text(AppConstants.appName,
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary))
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 400.ms)
                          .slideY(begin: 0.3, end: 0),
                      const SizedBox(height: 4),
                      Text(AppConstants.appSubtitle,
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center)
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 400.ms),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const _LoginForm(),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: 'New member? ',
                      style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Register here',
                          style: GoogleFonts.poppins(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _identifierCtrl = TextEditingController(); // phone OR account number
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _useAccountNumber = false; // toggle login method

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final identifier = _identifierCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (identifier.isEmpty || pin.length != 4) {
      _snack(
          _useAccountNumber
              ? 'Enter your account number and 4-digit PIN.'
              : 'Enter your phone number and 4-digit PIN.',
          AppTheme.error);
      return;
    }

    setState(() => _loading = true);
    try {
      Map<String, dynamic>? profile;
      String uid;

      if (_useAccountNumber) {
        // Login with account number
        profile = await AccountNumberService.getMemberByAccountNumber(identifier);
        if (profile == null) {
          _snack('Account number not found. Check your details.', AppTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? profile['phone'] as String? ?? '';
      } else {
        // Login with phone number (existing flow)
        final phone = FirebaseService.formatPhone(identifier);
        profile = await FirebaseService.getProfileByPhone(phone);
        if (profile == null) {
          _snack('No account found for this number. Please register.', AppTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? 'phone_$phone';
      }

      final pinOk = await FirebaseService.verifyPin(uid, pin);
      if (!pinOk) {
        _snack('Incorrect PIN. Try again.', AppTheme.error);
        return;
      }
      if (!mounted) return;

      // Patch uid back into profile in case it was missing
      final fullProfile = {...profile, 'uid': uid};
      FirebaseService.setSession(uid, fullProfile);

      // Load the SACCO branding/config for this user's tenant
      await SaccoService.loadForUser(fullProfile);

      // Run per-user migration in background — won't block navigation
      MigrationService.run(uid: uid, onStatus: (_) {});

      final role = fullProfile['role'] ?? AppConstants.roleMember;

      // Debug: print to see what role we got
      debugPrint('🔐 Login role: $role (expecting: ${AppConstants.roleSuperAdmin})');

      // Platform super-admin goes to SACCO management hub
      if (role == AppConstants.roleSuperAdmin || role == 'super_admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PlatformAdminScreen()),
          (r) => false,
        );
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => role == AppConstants.roleAdmin ||
                  role == AppConstants.roleManager ||
                  role == AppConstants.roleLoanOfficer ||
                  role == AppConstants.roleTeller
              ? const AdminDashboard()
              : const FarmerDashboard(),
        ),
        (r) => false,
      );
    } catch (e) {
      _snack(_friendly(e.toString()), AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _friendly(String e) {
    if (e.contains('network') || e.contains('unavailable')) {
      return 'Check your internet connection and try again.';
    }
    if (e.contains('permission-denied')) {
      return 'Access denied. Please contact support.';
    }
    if (e.contains('not-found')) {
      return 'No account found for this number. Please register.';
    }
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back',
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary))
            .animate()
            .fadeIn(delay: 350.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 4),
        Text(
            _useAccountNumber
                ? 'Sign in with your account number and PIN'
                : 'Sign in with your phone number and PIN',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppTheme.textSecondary))
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms),
        const SizedBox(height: 24),
        TextFormField(
          controller: _identifierCtrl,
          keyboardType: _useAccountNumber
              ? TextInputType.text
              : TextInputType.phone,
          inputFormatters: _useAccountNumber
              ? null
              : [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          decoration: InputDecoration(
            labelText: _useAccountNumber ? 'Account Number' : 'Phone Number',
            hintText: _useAccountNumber
                ? 'e.g. MUS-0001'
                : '07XX XXX XXX  or  256...',
            prefixIcon: Icon(_useAccountNumber
                ? Icons.badge_rounded
                : Icons.phone_rounded),
          ),
        )
            .animate()
            .fadeIn(delay: 440.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 14),
        _PinField(controller: _pinCtrl, label: 'Your 4-digit PIN')
            .animate()
            .fadeIn(delay: 490.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() => _useAccountNumber = !_useAccountNumber);
                _identifierCtrl.clear();
              },
              icon: Icon(
                  _useAccountNumber
                      ? Icons.phone_rounded
                      : Icons.badge_rounded,
                  size: 15),
              label: Text(
                  _useAccountNumber
                      ? 'Use Phone Number'
                      : 'Use Account Number',
                  style: GoogleFonts.poppins(
                      color: AppTheme.info, fontSize: 12)),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PinResetScreen())),
              icon: const Icon(Icons.lock_reset_rounded, size: 15),
              label: Text('Forgot PIN?',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: 'Sign In',
          loading: _loading,
          onPressed: _login,
          icon: Icons.login_rounded,
        )
            .animate()
            .fadeIn(delay: 540.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
      ],
    );
  }
}

class _PinField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _PinField({required this.controller, required this.label});
  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.poppins(
          fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        prefixIcon: const Icon(Icons.dialpad_rounded),
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class OtpVerifyScreen extends StatefulWidget {
  final String phone;
  final VoidCallback afterVerified;
  const OtpVerifyScreen(
      {super.key, required this.phone, required this.afterVerified});
  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _sending = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _nodes) f.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final sent = await FirebaseService.generateAndSendOtp(widget.phone);
    if (mounted) {
      setState(() {
        _sending = false;
        if (!sent) _error = 'Failed to send OTP. Check your connection.';
      });
    }
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 6) return;
    setState(() => _verifying = true);
    final ok = FirebaseService.verifyEgoOtp(widget.phone, _code);
    if (ok) {
      if (mounted) widget.afterVerified();
    } else {
      if (mounted) {
        setState(() {
          _error = 'Invalid or expired OTP. Please try again.';
          _verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Verify Phone'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sms_rounded,
                  color: AppTheme.primary, size: 36),
            )
                .animate()
                .scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 500.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('OTP Sent',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Enter the 6-digit code sent to\n${widget.phone}',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            if (_sending)
              const CircularProgressIndicator(color: AppTheme.primary)
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (i) => SizedBox(
                    width: 46,
                    height: 54,
                    child: TextField(
                      controller: _ctrls[i],
                      focusNode: _nodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5)
                          _nodes[i + 1].requestFocus();
                        if (v.isEmpty && i > 0)
                          _nodes[i - 1].requestFocus();
                        if (_code.length == 6) _verify();
                      },
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: GoogleFonts.poppins(
                        color: AppTheme.error, fontSize: 13)),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Verify',
                loading: _verifying,
                onPressed: _verify,
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _sending ? null : _sendOtp,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Resend OTP',
                    style: GoogleFonts.poppins(
                        color: AppTheme.primary, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PinResetScreen extends StatefulWidget {
  const PinResetScreen({super.key});
  @override
  State<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends State<PinResetScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    final rawPhone = _phoneCtrl.text.trim();
    if (rawPhone.isEmpty) return;
    final phone = FirebaseService.formatPhone(rawPhone);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          phone: phone,
          afterVerified: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
            builder: (_) => SetPinScreen(isReset: true, phone: phone)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Reset PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
                'Enter your registered phone number to reset your PIN.',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Send OTP',
              loading: _loading,
              onPressed: _proceed,
              icon: Icons.sms_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class SetPinScreen extends StatefulWidget {
  final bool isReset;
  final String phone;
  const SetPinScreen({super.key, this.isReset = false, required this.phone});
  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pinCtrl.text.length != 4) {
      _snack('PIN must be exactly 4 digits.', AppTheme.error);
      return;
    }
    if (_pinCtrl.text != _confirmCtrl.text) {
      _snack('PINs do not match.', AppTheme.error);
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseService.savePin(_pinCtrl.text, phone: widget.phone);
      if (!mounted) return;
      _snack(
          widget.isReset ? 'PIN reset successfully!' : 'PIN set!',
          AppTheme.success);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    } catch (e) {
      _snack('Error: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.isReset ? 'Reset PIN' : 'Set Your PIN'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dialpad_rounded,
                  color: AppTheme.primary, size: 36),
            )
                .animate()
                .scale(
                    begin: const Offset(0.5, 0.5),
                    duration: 500.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(
              widget.isReset
                  ? 'Create a new 4-digit PIN'
                  : 'Choose a 4-digit PIN to secure your account',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _PinField(controller: _pinCtrl, label: 'New PIN'),
            const SizedBox(height: 16),
            _PinField(controller: _confirmCtrl, label: 'Confirm PIN'),
            const SizedBox(height: 28),
            PrimaryButton(
              label:
                  widget.isReset ? 'Reset PIN' : 'Save PIN & Continue',
              loading: _loading,
              onPressed: _save,
              icon: Icons.lock_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

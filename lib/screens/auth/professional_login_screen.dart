import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../core/account_number_service.dart';
import '../../core/login_attempt_service.dart';
import '../farmer/farmer_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'register_screen.dart';
import 'first_login_setup_screen.dart';
import 'otp_verification_screen.dart';

/// Professional login screen.
///
/// Responsive layouts (measured with LayoutBuilder):
///  • >= 900px : split screen. Brand panel on the left, sign-in card on the
///               right. BOTH panels are centred horizontally and vertically.
///  • <  900px : full-bleed branded background with a centred brand header,
///               sign-in card and footer (card capped at 480px).
/// Also handles tiny phones (<360px), short / landscape screens, large system
/// font sizes and the on-screen keyboard (everything scrolls).
///
/// Sign-in is two steps: 1) phone or account number, 2) PIN.
class ProfessionalLoginScreen extends StatefulWidget {
  const ProfessionalLoginScreen({super.key});

  @override
  State<ProfessionalLoginScreen> createState() => _ProfessionalLoginScreenState();
}

class _ProfessionalLoginScreenState extends State<ProfessionalLoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _pinFocus = FocusNode();

  bool _loading = false;
  bool _useAccountNumber = false;
  bool _obscurePin = true;
  bool _pinStep = false; // false = step 1 (username), true = step 2 (PIN)

  static const double _desktopBreakpoint = 900;
  static const String _supportPhone = '+256 778474686';
  static const Color _brandDark = Color(0xFF0D2B6B);
  static const Color _brandMid = Color(0xFF1565C0);

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    _usernameFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  // ───────────────────────── Helpers ─────────────────────────

  TextStyle _t(
    double size, {
    FontWeight w = FontWeight.w400,
    Color? c,
    double? ls,
    double? h,
  }) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: w,
        color: c ?? ModernTheme.textPrimary,
        letterSpacing: ls,
        height: h,
      );

  // ───────────────────────── Logic ─────────────────────────

  void _onNext() {
    final value = _usernameCtrl.text.trim();
    if (value.isEmpty) {
      _showSnack(
        _useAccountNumber ? 'Please enter your account number' : 'Please enter your phone number',
        ModernTheme.error,
      );
      return;
    }
    if (!_useAccountNumber && value.replaceAll(RegExp(r'\D'), '').length < 9) {
      _showSnack('Please enter a valid phone number', ModernTheme.error);
      return;
    }
    setState(() => _pinStep = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  void _backToUsername() {
    setState(() {
      _pinStep = false;
      _pinCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _usernameFocus.requestFocus();
    });
  }

  void _setLoginMethod(bool useAccountNumber) {
    if (_useAccountNumber == useAccountNumber) return;
    setState(() {
      _useAccountNumber = useAccountNumber;
      _pinStep = false;
      _usernameCtrl.clear();
      _pinCtrl.clear();
    });
  }

  Future<void> _login() async {
    if (_loading) return;

    final username = _usernameCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (username.isEmpty || pin.length != 4) {
      _showSnack(
        _useAccountNumber
            ? 'Enter your account number and 4-digit PIN'
            : 'Enter your phone number and 4-digit PIN',
        ModernTheme.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      Map<String, dynamic>? profile;
      String uid;

      if (_useAccountNumber) {
        profile = await AccountNumberService.getMemberByAccountNumber(username);
        if (profile == null) {
          _showSnack('Account number not found. Please check and try again.', ModernTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? profile['phone'] as String? ?? '';
      } else {
        final phone = FirebaseService.formatPhone(username);
        profile = await FirebaseService.getProfileByPhone(phone);
        if (profile == null) {
          _showSnack('No account found for $phone. Contact $_supportPhone for help.', ModernTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? 'phone_$phone';
      }

      // ── Brute-force protection ──────────────────────────────
      // One counter per account (falls back to the typed account number)
      final lockKey = uid.isNotEmpty ? uid : 'acct_$username';

      final remainingLock = await LoginAttemptService.getRemainingLock(lockKey);
      if (remainingLock != null) {
        _pinCtrl.clear();
        _showSnack(
          'Too many failed attempts. Try again in ${LoginAttemptService.formatRemaining(remainingLock)}, '
          'or contact $_supportPhone.',
          ModernTheme.error,
        );
        return;
      }

      final pinOk = await FirebaseService.verifyPin(uid, pin);
      if (!pinOk) {
        final attemptsLeft = await LoginAttemptService.recordFailure(lockKey);
        _pinCtrl.clear();
        if (attemptsLeft == 0) {
          _showSnack(
            'Too many failed attempts. Account locked for '
            '${LoginAttemptService.lockDuration.inMinutes} minutes. Contact $_supportPhone for help.',
            ModernTheme.error,
          );
        } else if (attemptsLeft < LoginAttemptService.maxAttempts) {
          _showSnack(
            'Incorrect PIN. $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} left before your account is locked.',
            ModernTheme.error,
          );
        } else {
          _showSnack('Incorrect PIN. Please try again.', ModernTheme.error);
        }
        return;
      }

      // Correct PIN -> clear the failed-attempt counter
      await LoginAttemptService.reset(lockKey);

      // Store session
      FirebaseService.setSession(uid, profile);

      // Check if user needs first login setup
      final needsSetup = await FirebaseService.needsFirstLoginSetup(uid);

      if (!mounted) return;

      if (needsSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FirstLoginSetupScreen(
              uid: uid,
              profile: profile ?? {},
            ),
          ),
        );
        return;
      }

      final role = profile['role'] as String? ?? '';
      final name = profile['name'] as String? ?? 'User';
      final phone = profile['phone'] as String? ?? username;

      // ADMIN/TELLER: require OTP verification
      if (role == 'admin' || role == 'teller') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OTPVerificationScreen(
              uid: uid,
              profile: profile ?? {},
              phoneNumber: phone,
            ),
          ),
        );
        return;
      }

      // MEMBER: welcome dialog, then dashboard
      if (mounted) await _showWelcomeDialog(name);

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      if (role == 'admin' || role == 'super_admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FarmerDashboard()),
        );
      }
    } catch (e) {
      _showSnack('Login failed: ${e.toString()}', ModernTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    final h = MediaQuery.of(context).size.height;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg, style: _t(14, w: FontWeight.w500, c: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        // Shown near the top so the keyboard never hides it. Clamped so it
        // never goes negative on short screens (that would crash).
        margin: EdgeInsets.only(
          bottom: math.max(0.0, h - 150),
          left: 20,
          right: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Branded welcome dialog. Auto-continues after 3 seconds; the button
  /// continues immediately.
  Future<void> _showWelcomeDialog(String name) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _WelcomeDialog(name: name),
    );
  }

  void _showResetPINDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: ModernTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Reset PIN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(18, w: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To reset your PIN, please contact our support team.',
                  style: _t(14, c: ModernTheme.textPrimary, h: 1.5),
                ),
                const SizedBox(height: 16),
                _supportRow(),
                const SizedBox(height: 12),
                Text(
                  'Our team will verify your identity and help you reset your PIN securely.',
                  style: _t(12.5, c: ModernTheme.textHint, h: 1.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: _t(14, w: FontWeight.w600, c: ModernTheme.primaryBlue)),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Layout ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    // Cap the user's system font scaling so huge fonts can't break the layout
    final scaler = mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.2);

    return MediaQuery(
      data: mq.copyWith(textScaler: scaler),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _desktopBreakpoint) {
              return _buildDesktopLayout(constraints.maxWidth);
            }
            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // ── Desktop / large tablet landscape: split screen ──
  Widget _buildDesktopLayout(double totalWidth) {
    return Row(
      children: [
        Expanded(flex: 11, child: _buildBrandPanel()),
        Expanded(flex: 10, child: _buildFormPanel(totalWidth)),
      ],
    );
  }

  /// Brand panel: everything is centred as one block (logo lockup, headline,
  /// copy, feature list) with the copyright pinned to the bottom.
  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.JPG'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _brandDark.withOpacity(0.92),
              _brandMid.withOpacity(0.80),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final pad = (w * 0.08).clamp(32.0, 64.0);
            final headline = (w * 0.07).clamp(30.0, 48.0);

            return Column(
              children: [
                // Centred content block (scrolls on very short windows)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0.0, inner.maxHeight - 48),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _logo(96, radius: 24),
                                  const SizedBox(height: 18),
                                  Text(
                                    'MBADIFA SACCO',
                                    textAlign: TextAlign.center,
                                    style: _t(18, w: FontWeight.w700, c: Colors.white, ls: 2),
                                  ),
                                  const SizedBox(height: 28),
                                  Container(
                                    width: 48,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    'Poverty Must Go',
                                    textAlign: TextAlign.center,
                                    style: _t(headline, w: FontWeight.w700, c: Colors.white, h: 1.15),
                                  ),
                                  const SizedBox(height: 16),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 380),
                                    child: Text(
                                      'Sign in to manage your savings, shares and loans in one secure place.',
                                      textAlign: TextAlign.center,
                                      style: _t(15.5, c: Colors.white.withOpacity(0.85), h: 1.6),
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  // Feature list: the block hugs its widest row, so it
                                  // is truly centred under the copy; icons and text
                                  // line up with each other inside it
                                  IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _feature(Icons.savings_outlined, 'Savings and shares at a glance'),
                                        const SizedBox(height: 14),
                                        _feature(Icons.request_quote_outlined, 'Loan applications and repayments'),
                                        const SizedBox(height: 14),
                                        _feature(Icons.lock_outline_rounded, 'PIN-protected, secure access'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/logo2.png',
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SACCO PLUS',
                        textAlign: TextAlign.center,
                        style: _t(14, w: FontWeight.w600, c: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\u00A9 ${DateTime.now().year} MBADIFA SACCO. All rights reserved.',
                        textAlign: TextAlign.center,
                        style: _t(12, c: Colors.white.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(text, style: _t(14.5, c: Colors.white.withOpacity(0.92))),
        ),
      ],
    );
  }

  /// Form panel: the card is centred horizontally AND vertically. The
  /// ConstrainedBox(minHeight) is what makes vertical centring work inside a
  /// scroll view (a bare Center would pin the card to the top).
  Widget _buildFormPanel(double totalWidth) {
    final hPad = totalWidth < 1100 ? 24.0 : 40.0;

    return Container(
      color: ModernTheme.bgLight,
      child: LayoutBuilder(
        builder: (context, c) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: math.max(0.0, c.maxHeight - 64)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: EdgeInsets.all(totalWidth < 1100 ? 28 : 40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ModernTheme.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _buildFormFields(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Phones & portrait tablets: branded background + centred card ──
  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.JPG'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _brandDark.withOpacity(0.94),
              _brandDark.withOpacity(0.88),
              _brandMid.withOpacity(0.84),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;

              final small = w < 360; // tiny phones
              final tablet = w >= 600; // portrait tablets
              final shortScreen = h < 560; // landscape phones / split-screen
              final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
              final compact = shortScreen || keyboardOpen;

              final logoSize = compact ? 56.0 : (small ? 72.0 : (tablet ? 100.0 : 84.0));
              final titleSize = small ? 20.0 : (tablet ? 28.0 : 23.0);
              final hPad = small ? 14.0 : 20.0;
              final cardPad = small ? 20.0 : (tablet ? 32.0 : 24.0);

              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  // Fill the screen so content is centred on tall screens and
                  // scrolls on short ones
                  constraints: BoxConstraints(minHeight: h),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Brand header
                        Padding(
                          padding: EdgeInsets.fromLTRB(24, compact ? 12 : 20, 24, compact ? 12 : 22),
                          child: Column(
                            children: [
                              _logo(logoSize, radius: logoSize * 0.26),
                              SizedBox(height: compact ? 10 : 16),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'MBADIFA SACCO',
                                  textAlign: TextAlign.center,
                                  style: _t(titleSize, w: FontWeight.w700, c: Colors.white, ls: 2),
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                                  ),
                                  child: Text(
                                    'Poverty Must Go',
                                    textAlign: TextAlign.center,
                                    style: _t(small ? 12 : 13, w: FontWeight.w500, c: Colors.white.withOpacity(0.92), ls: 0.4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Sign-in card
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(cardPad),
                              child: _buildFormFields(compact: true),
                            ),
                          ),
                        ),

                        _mobileLinks(),

                        // Footer
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/logo2.png',
                                height: 32,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'SACCO PLUS',
                                textAlign: TextAlign.center,
                                style: _t(12, w: FontWeight.w600, c: Colors.white.withOpacity(0.9)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '\u00A9 ${DateTime.now().year} MBADIFA SACCO. All rights reserved.',
                                textAlign: TextAlign.center,
                                style: _t(11.5, c: Colors.white.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _logo(double size, {double radius = 16}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/mbadifa-logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.account_balance_rounded, color: ModernTheme.primaryBlue, size: size * 0.6),
      ),
    );
  }

  // ───────────────────────── Form ─────────────────────────

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    TextStyle? hintStyle,
    Widget? suffixIcon,
    bool small = false,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: _t(small ? 13 : 14, c: ModernTheme.textSecondary),
      floatingLabelStyle: _t(13, w: FontWeight.w500, c: ModernTheme.primaryBlue),
      hintText: hint,
      hintStyle: hintStyle ?? _t(small ? 13 : 14, c: ModernTheme.textHint),
      counterText: '',
      prefixIcon: Icon(icon, size: 20, color: ModernTheme.textSecondary),
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: 18),
      filled: true,
      fillColor: ModernTheme.bgLight,
      border: border(ModernTheme.borderLight, 1.2),
      enabledBorder: border(ModernTheme.borderLight, 1.2),
      focusedBorder: border(ModernTheme.primaryBlue, 2),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    Color? color,
    bool loading = false,
  }) {
    final bg = color ?? ModernTheme.primaryBlue;
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: bg.withOpacity(0.6),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label, style: _t(15.5, w: FontWeight.w600, c: Colors.white, ls: 0.3)),
      ),
    );
  }

  /// Small two-bar progress indicator for the two sign-in steps.
  Widget _stepIndicator() {
    Widget bar(bool active) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 4,
            decoration: BoxDecoration(
              color: active ? ModernTheme.primaryBlue : ModernTheme.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    return Row(
      children: [
        bar(true),
        const SizedBox(width: 6),
        bar(_pinStep),
      ],
    );
  }

  Widget _stepHeader(bool small) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _pinStep ? 'One more step' : 'Welcome back',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _t(small ? 22 : 26, w: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _pinStep
              ? 'Enter your 4-digit PIN to sign in.'
              : (_useAccountNumber
                  ? 'Sign in with your account number.'
                  : 'Sign in with your phone number.'),
          style: _t(small ? 13 : 14, c: ModernTheme.textSecondary, h: 1.5),
        ),
      ],
    );
  }

  /// [compact] = mobile: only the current step is shown in the card (register
  /// and support move below the card). Steps slide left/right and can be
  /// swiped: swipe left = next, swipe right = back.
  Widget _buildFormFields({bool compact = false}) {
    final small = MediaQuery.of(context).size.width < 360;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepIndicator(),
        SizedBox(height: small ? 18 : 22),

        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, if (current != null) current],
            ),
            transitionBuilder: (child, anim) {
              final incoming = child.key == ValueKey(_pinStep);
              final begin = incoming
                  ? Offset(_pinStep ? 0.3 : -0.3, 0)
                  : Offset(_pinStep ? -0.3 : 0.3, 0);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: begin, end: Offset.zero).animate(anim),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_pinStep),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stepHeader(small),
                  SizedBox(height: small ? 20 : 24),
                  if (!_pinStep) ...[
                    _methodSwitch(small),
                    const SizedBox(height: 20),
                  ],
                  _pinStep ? _buildPinStep(small) : _buildUsernameStep(small),
                ],
              ),
            ),
          ),
        ),

        if (!compact) ...[
          SizedBox(height: small ? 20 : 24),

          // Register
          Row(
            children: [
              const Expanded(child: Divider(color: ModernTheme.borderLight, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('New to MBADIFA SACCO?', style: _t(12, c: ModernTheme.textHint)),
              ),
              const Expanded(child: Divider(color: ModernTheme.borderLight, thickness: 1)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _loading ? null : _openRegister,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ModernTheme.primaryBlue, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Create new account',
                  maxLines: 1,
                  style: _t(14.5, w: FontWeight.w600, c: ModernTheme.primaryBlue),
                ),
              ),
            ),
          ),

          SizedBox(height: small ? 20 : 24),

          // Support
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3F2FD)),
            ),
            child: Column(
              children: [
                _supportRow(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: ModernTheme.textHint),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Never share your PIN or password with anyone.',
                        textAlign: TextAlign.center,
                        style: _t(11.5, c: ModernTheme.textHint, h: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (!compact) return body;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_loading) return;
        if (v < -300 && !_pinStep) {
          _onNext();
        } else if (v > 300 && _pinStep) {
          _backToUsername();
        }
      },
      child: body,
    );
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  /// Mobile only: register + help live below the card on the blue
  /// background, so the card itself stays clean and uncluttered.
  Widget _mobileLinks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        children: [
          if (!_pinStep)
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('New to MBADIFA SACCO?', style: _t(13, c: Colors.white.withOpacity(0.8))),
                TextButton(
                  onPressed: _loading ? null : _openRegister,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Create account', style: _t(13, w: FontWeight.w700, c: Colors.white)),
                ),
              ],
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.headset_mic_rounded, size: 15, color: Colors.white.withOpacity(0.75)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Need help? $_supportPhone',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12.5, c: Colors.white.withOpacity(0.8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _methodSwitch(bool small) {
    Widget item(String label, IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: _loading ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? ModernTheme.primaryBlue : ModernTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(
                      small ? 12 : 13,
                      w: selected ? FontWeight.w600 : FontWeight.w500,
                      c: selected ? ModernTheme.primaryBlue : ModernTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ModernTheme.bgLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ModernTheme.borderLight),
      ),
      child: Row(
        children: [
          item('Phone', Icons.phone_outlined, !_useAccountNumber, () => _setLoginMethod(false)),
          item('Account no.', Icons.badge_outlined, _useAccountNumber, () => _setLoginMethod(true)),
        ],
      ),
    );
  }

  Widget _buildUsernameStep(bool small) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _usernameCtrl,
          focusNode: _usernameFocus,
          style: _t(small ? 15 : 16, w: FontWeight.w500),
          decoration: _fieldDecoration(
            label: _useAccountNumber ? 'Account number' : 'Phone number',
            hint: _useAccountNumber ? '60000001' : '0700000000',
            icon: _useAccountNumber ? Icons.badge_outlined : Icons.phone_outlined,
            small: small,
          ),
          keyboardType: _useAccountNumber ? TextInputType.number : TextInputType.phone,
          inputFormatters: [
            _useAccountNumber
                ? FilteringTextInputFormatter.digitsOnly
                : FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          ],
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _onNext(),
        ),
        const SizedBox(height: 20),
        _primaryButton(label: 'Continue', onPressed: _loading ? null : _onNext),
      ],
    );
  }

  Widget _buildPinStep(bool small) {
    final username = _usernameCtrl.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Who is signing in, with a way to go back
        Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          decoration: BoxDecoration(
            color: ModernTheme.bgLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ModernTheme.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                _useAccountNumber ? Icons.badge_outlined : Icons.phone_outlined,
                size: 18,
                color: ModernTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(14, w: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _backToUsername,
                child: Text('Change', style: _t(13, w: FontWeight.w600, c: ModernTheme.primaryBlue)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pinCtrl,
          focusNode: _pinFocus,
          style: _t(small ? 17 : 18, w: FontWeight.w600, ls: 8),
          decoration: _fieldDecoration(
            label: 'PIN',
            hint: '\u2022\u2022\u2022\u2022',
            icon: Icons.lock_outline_rounded,
            hintStyle: _t(18, c: ModernTheme.textHint, ls: 8),
            small: small,
            suffixIcon: IconButton(
              tooltip: _obscurePin ? 'Show PIN' : 'Hide PIN',
              icon: Icon(
                _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: ModernTheme.textSecondary,
              ),
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
            ),
          ),
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _login(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showResetPINDialog,
            child: Text('Forgot PIN?', style: _t(13, w: FontWeight.w600, c: ModernTheme.primaryBlue)),
          ),
        ),
        const SizedBox(height: 4),
        _primaryButton(
          label: 'Sign in',
          color: ModernTheme.success,
          loading: _loading,
          onPressed: _loading ? null : _login,
        ),
      ],
    );
  }

  Widget _supportRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ModernTheme.primaryBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.headset_mic_rounded, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need help?', style: _t(12, c: ModernTheme.textSecondary)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _supportPhone,
                  style: _t(16, w: FontWeight.w700, c: ModernTheme.primaryBlue, ls: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  Welcome dialog (shown after a successful member login)
// ═════════════════════════════════════════════════════════════════════

/// Branded welcome dialog. Auto-closes after [_autoCloseSeconds]; the button
/// closes it immediately. Uses a Timer that is cancelled on dispose so it can
/// never pop twice or pop a screen that is no longer there.
class _WelcomeDialog extends StatefulWidget {
  final String name;
  const _WelcomeDialog({required this.name});

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  static const int _autoCloseSeconds = 3;
  static const Color _brandDark = Color(0xFF0D2B6B);
  static const Color _brandMid = Color(0xFF1565C0);

  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: _autoCloseSeconds), _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  TextStyle _t(
    double size, {
    FontWeight w = FontWeight.w400,
    Color? c,
    double? ls,
  }) =>
      GoogleFonts.poppins(
        fontSize: size,
        fontWeight: w,
        color: c ?? ModernTheme.textPrimary,
        letterSpacing: ls,
      );

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final fullName = widget.name.trim();
    final firstName = fullName.isEmpty ? 'Member' : fullName.split(RegExp(r'\s+')).first;
    final showFullName = fullName.isNotEmpty && fullName != firstName;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Branded header with animated check ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 44),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_brandDark, _brandMid],
                      ),
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) =>
                              Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(Icons.check_rounded, size: 52, color: ModernTheme.success),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'LOGIN SUCCESSFUL',
                          style: _t(12.5, w: FontWeight.w600, c: Colors.white.withOpacity(0.85), ls: 1.4),
                        ),
                      ],
                    ),
                  ),

                  // ── Greeting card (overlaps the header) ──
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(_greeting, style: _t(14, c: ModernTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: _t(28, w: FontWeight.w700, c: _brandDark),
                          ),
                          if (showFullName) ...[
                            const SizedBox(height: 2),
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: _t(13, c: ModernTheme.textSecondary),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _brandMid.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Poverty Must Go',
                              style: _t(12.5, w: FontWeight.w600, c: _brandMid, ls: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Button + auto-continue progress ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _close,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brandMid,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Go to dashboard',
                                    style: _t(15.5, w: FontWeight.w600, c: Colors.white)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(seconds: _autoCloseSeconds),
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 3,
                              backgroundColor: ModernTheme.borderLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(_brandMid),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
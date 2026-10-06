import 'dart:math' as math;
import 'package:flutter/material.dart';
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

/// Professional split-screen login (like dfcu QuickBanking)
///
/// Responsive layouts:
///  • >= 900px  : split screen (branding left, form right)
///  • < 900px   : full-bleed background with a centered form card
///                (card is capped at 480px so tablets don't look stretched)
/// Also handles: tiny phones (<360px), short/landscape screens, big system
/// font sizes, and the on-screen keyboard (everything scrolls).
class ProfessionalLoginScreen extends StatefulWidget {
  const ProfessionalLoginScreen({super.key});

  @override
  State<ProfessionalLoginScreen> createState() => _ProfessionalLoginScreenState();
}

class _ProfessionalLoginScreenState extends State<ProfessionalLoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _useAccountNumber = false;
  bool _obscurePin = true;

  static const double _desktopBreakpoint = 900;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── Logic ─────────────────────────

  void _onNext() {
    // First step: validate username, then show PIN field
    if (_usernameCtrl.text.trim().isEmpty) {
      _showSnack('Please enter your username', ModernTheme.error);
    } else {
      setState(() {}); // Trigger rebuild to show PIN field
    }
  }

  Future<void> _login() async {
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
          _showSnack('No account found for $phone. Contact +256 778474686 for help.', ModernTheme.error);
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
          'or contact +256 778474686.',
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
            '${LoginAttemptService.lockDuration.inMinutes} minutes. Contact +256 778474686 for help.',
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

      // 🔍 DEBUG: Log the profile data
      print('🔍 LOGIN DEBUG:');
      print('   UID: $uid');
      print('   Name: ${profile['name']}');
      print('   Phone: ${profile['phone']}');
      print('   Role: ${profile['role']}');
      print('   TenantID: ${profile['tenantId']}');
      print('   Full Profile: $profile');

      // Store session
      FirebaseService.setSession(uid, profile);

      // Check if user needs first login setup
      final needsSetup = await FirebaseService.needsFirstLoginSetup(uid);

      if (!mounted) return;

      if (needsSetup) {
        // Redirect to first login setup screen
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

      // ✅ ADMIN/TELLER: Require OTP verification
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

      // ✅ MEMBER: Show welcome dialog and navigate to dashboard
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            content: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ModernTheme.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 60,
                        color: ModernTheme.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Poverty Must Go',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Small delay before navigation
      await Future.delayed(const Duration(milliseconds: 300));

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        // Clamped so it never goes negative on short screens (would crash)
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

  void _showResetPINDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_reset, color: ModernTheme.primaryBlue),
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Reset PIN',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To reset your PIN, please contact our support team:',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3F2FD)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ModernTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.phone, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support Line',
                            style: TextStyle(
                              fontSize: 12,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+256 778474686',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ModernTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Our team will verify your identity and help you reset your PIN securely.',
                style: TextStyle(fontSize: 13, color: ModernTheme.textHint),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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

  // Desktop / large tablet landscape: split screen
  Widget _buildDesktopLayout(double totalWidth) {
    return Row(
      children: [
        Expanded(child: _buildImageSection()),
        Expanded(child: _buildFormSection(totalWidth)),
      ],
    );
  }

  // Phones & portrait tablets: background image + centered form card
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
              ModernTheme.primaryBlue.withOpacity(0.85),
              ModernTheme.primaryBlue.withOpacity(0.75),
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

              final logoSize = shortScreen ? 64.0 : (small ? 80.0 : (tablet ? 120.0 : 100.0));
              final titleSize = small ? 28.0 : (tablet ? 48.0 : 38.0);
              final hPad = small ? 12.0 : 20.0;
              final cardPad = small ? 16.0 : (tablet ? 32.0 : 24.0);

              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  // Fill the screen so content is vertically centred on tall
                  // screens, and scrolls on short ones
                  constraints: BoxConstraints(minHeight: h),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo and branding
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            shortScreen ? 12 : 28,
                            24,
                            shortScreen ? 8 : 16,
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.all(logoSize * 0.12),
                                child: Image.asset(
                                  'assets/images/mbadifa-logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              SizedBox(height: shortScreen ? 10 : 20),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'MBADIFA SACCO',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    shadows: const [
                                      Shadow(color: Colors.black38, blurRadius: 12),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: shortScreen ? 4 : 12),
                              Text(
                                'Poverty Must Go',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: small ? 15 : 17,
                                  fontWeight: FontWeight.w300,
                                  shadows: const [
                                    Shadow(color: Colors.black38, blurRadius: 12),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Login form in white card (max 480px wide)
                        Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.all(cardPad),
                                child: _buildFormFields(),
                              ),
                            ),
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

  Widget _buildImageSection() {
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
              const Color(0xFF0D2B6B).withOpacity(0.88),
              const Color(0xFF1565C0).withOpacity(0.75),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            // Everything scales with the panel size (no more fixed 64px title)
            final w = c.maxWidth;
            final h = c.maxHeight;
            final pad = (w * 0.08).clamp(24.0, 60.0);
            final logo = (w * 0.28).clamp(110.0, 160.0);
            final titleSize = (w * 0.1).clamp(32.0, 64.0);
            final taglineSize = (w * 0.05).clamp(20.0, 28.0);
            final tall = h > 650;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: h),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: logo,
                          height: logo,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.all(logo * 0.125),
                          child: Image.asset(
                            'assets/images/mbadifa-logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        SizedBox(height: tall ? 50 : 24),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'MBADIFA SACCO',
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleSize,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              shadows: const [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 20,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          width: 100,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Colors.white, Colors.transparent],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        SizedBox(height: tall ? 24 : 14),

                        Text(
                          'Poverty Must Go',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: taglineSize,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            height: 1.4,
                            shadows: const [
                              Shadow(color: Colors.black38, blurRadius: 15),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Empowering Communities • Building Futures',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 10),
                            ],
                          ),
                          textAlign: TextAlign.center,
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
    );
  }

  Widget _buildFormSection(double totalWidth) {
    final hPad = totalWidth < 1100 ? 28.0 : 48.0;

    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _buildFormFields(),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Form ─────────────────────────

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    TextStyle? hintStyle,
    Widget? suffixIcon,
    bool small = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: small ? 14 : 16),
      hintText: hint,
      hintStyle: hintStyle ?? TextStyle(fontSize: small ? 14 : 16),
      counterText: '',
      contentPadding: EdgeInsets.symmetric(horizontal: small ? 14 : 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ModernTheme.borderLight, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ModernTheme.borderLight, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ModernTheme.primaryBlue, width: 2.5),
      ),
      filled: true,
      fillColor: ModernTheme.bgLight,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildFormFields() {
    final small = MediaQuery.of(context).size.width < 360;
    final headingSize = small ? 24.0 : 28.0;
    final fieldFont = small ? 16.0 : 18.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Heading
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: ModernTheme.primaryBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _useAccountNumber ? 'Account Login' : 'Sign In',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: headingSize,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          _useAccountNumber
              ? 'Enter your account number to continue'
              : 'Enter your phone number to continue',
          style: TextStyle(
            fontSize: small ? 14 : 15,
            color: ModernTheme.textSecondary,
            height: 1.4,
          ),
        ),

        SizedBox(height: small ? 24 : 36),

        // Username / Account Number field
        TextFormField(
          controller: _usernameCtrl,
          style: TextStyle(fontSize: fieldFont, fontWeight: FontWeight.w500),
          decoration: _fieldDecoration(
            label: _useAccountNumber ? 'Account Number' : 'Phone Number',
            hint: _useAccountNumber ? '60000001' : '0700000000',
            small: small,
          ),
          keyboardType: _useAccountNumber ? TextInputType.number : TextInputType.phone,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _onNext(),
        ),

        const SizedBox(height: 24),

        // NEXT button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: ModernTheme.primaryBlue.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'NEXT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),

        // PIN field after username entered
        if (_usernameCtrl.text.trim().isNotEmpty) ...[
          const SizedBox(height: 24),

          TextFormField(
            controller: _pinCtrl,
            style: TextStyle(
              fontSize: fieldFont,
              fontWeight: FontWeight.w500,
              letterSpacing: 8,
            ),
            decoration: _fieldDecoration(
              label: 'Password/PIN',
              hint: '••••',
              hintStyle: const TextStyle(fontSize: 20, letterSpacing: 8),
              small: small,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin ? Icons.visibility_off : Icons.visibility,
                  color: ModernTheme.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            maxLength: 4,
            onFieldSubmitted: (_) => _login(),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.success,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: ModernTheme.success.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'LOG IN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Password reset link
        TextButton(
          onPressed: _showResetPINDialog,
          child: const Text(
            'Forgot PIN?',
            style: TextStyle(
              color: ModernTheme.primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Register section
        Container(
          padding: EdgeInsets.all(small ? 14 : 20),
          decoration: BoxDecoration(
            color: ModernTheme.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ModernTheme.borderLight, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                "Don't have an account?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ModernTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ModernTheme.primaryBlue, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Create New Account',
                      maxLines: 1,
                      style: TextStyle(
                        color: ModernTheme.primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: small ? 20 : 32),

        // Toggle login method (scales down instead of overflowing)
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _useAccountNumber = !_useAccountNumber;
                  _usernameCtrl.clear();
                  _pinCtrl.clear();
                });
              },
              icon: Icon(
                _useAccountNumber ? Icons.phone : Icons.badge,
                size: 18,
                color: ModernTheme.primaryBlue,
              ),
              label: Text(
                _useAccountNumber
                    ? 'Login with phone instead'
                    : 'Login with account number instead',
                maxLines: 1,
                style: const TextStyle(
                  color: ModernTheme.primaryBlue,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: small ? 20 : 40),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: ModernTheme.borderLight, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'SECURE & TRUSTED',
                style: TextStyle(
                  color: ModernTheme.textHint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(child: Divider(color: ModernTheme.borderLight, thickness: 1)),
          ],
        ),

        const SizedBox(height: 20),

        // Support card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3F2FD), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ModernTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.headset_mic,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+256 778474686',
                            style: TextStyle(
                              color: ModernTheme.primaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Never share your PIN or password with anyone.',
                style: TextStyle(
                  color: ModernTheme.textHint,
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Professional grid pattern painter
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../core/account_number_service.dart';
import '../farmer/farmer_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'register_screen.dart';

/// Professional split-screen login (like dfcu QuickBanking)
/// Responsive: Side-by-side on desktop/web, stacked on mobile
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
  bool _obscurePin = true; // Add this for eye button

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
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

      final pinOk = await FirebaseService.verifyPin(uid, pin);
      if (!pinOk) {
        _showSnack('Incorrect PIN. Please try again.', ModernTheme.error);
        return;
      }

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
      
      if (!mounted) return;
      
      final role = profile['role'] as String? ?? '';
      final name = profile['name'] as String? ?? 'User';
      
      // Show welcome dialog instead of snackbar
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Container(
              padding: const EdgeInsets.all(20),
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
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: ModernTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
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
            const Text('Reset PIN'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To reset your PIN, please contact our support team:',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support Line',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                      const Text(
                        '+256 778474686',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ModernTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Our team will verify your identity and help you reset your PIN securely.',
              style: TextStyle(fontSize: 13, color: ModernTheme.textHint),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // Desktop: Split screen (image left, form right)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left: Image with overlay
        Expanded(
          child: _buildImageSection(),
        ),
        
        // Right: Login form
        Expanded(
          child: _buildFormSection(),
        ),
      ],
    );
  }

  // Mobile: Stacked layout with image background
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Logo and branding at top
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/images/mbadifa-logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      const Text(
                        'MBADIFA SACCO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      const Text(
                        'Poverty Must Go',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Login form in white card
                Container(
                  margin: const EdgeInsets.all(20),
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
                  padding: const EdgeInsets.all(24),
                  child: _buildFormFields(),
                ),
              ],
            ),
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Elegant logo with glow effect
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/images/mbadifa-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Premium title
                const Text(
                  'MBADIFA SACCO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Decorative line
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
                
                const SizedBox(height: 24),
                
                const Text(
                  'Poverty Must Go',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    height: 1.4,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 15,
                      ),
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
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 10,
                      ),
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
  }

  Widget _buildFormSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _buildFormFields(),
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
              // Modern heading with icon
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
                      style: const TextStyle(
                        fontSize: 28,
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
                style: const TextStyle(
                  fontSize: 15,
                  color: ModernTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 36),
              
              // Username/Account Number field
              TextFormField(
                controller: _usernameCtrl,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: _useAccountNumber ? 'Account Number' : 'Phone Number',
                  labelStyle: const TextStyle(fontSize: 16),
                  hintText: _useAccountNumber ? '60000001' : '0700000000',
                  hintStyle: const TextStyle(fontSize: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                ),
                keyboardType: _useAccountNumber
                    ? TextInputType.number
                    : TextInputType.phone,
              ),
              
              const SizedBox(height: 24),
              
              // NEXT button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : () {
                    // First step: validate username, then show PIN field
                    if (_usernameCtrl.text.trim().isEmpty) {
                      _showSnack('Please enter your username', ModernTheme.error);
                    } else {
                      setState(() {}); // Trigger rebuild to show PIN field
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: ModernTheme.primaryBlue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              
              // Show PIN field after username entered
              if (_usernameCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _pinCtrl,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Password/PIN',
                    labelStyle: const TextStyle(fontSize: 16),
                    hintText: '••••',
                    hintStyle: const TextStyle(fontSize: 20, letterSpacing: 8),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_off : Icons.visibility,
                        color: ModernTheme.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePin = !_obscurePin;
                        });
                      },
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                onPressed: () {
                  _showResetPINDialog();
                },
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
              
              // Register section - Prominent
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ModernTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ModernTheme.borderLight, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Don't have an account?",
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Create New Account',
                          style: TextStyle(
                            color: ModernTheme.primaryBlue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Toggle login method
              Center(
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
                    style: const TextStyle(
                      color: ModernTheme.primaryBlue,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Clean divider
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Need Help?',
                              style: TextStyle(
                                color: ModernTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '+256 778474686',
                              style: TextStyle(
                                color: ModernTheme.primaryBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
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

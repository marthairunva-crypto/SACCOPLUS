import 'package:flutter/material.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../core/account_number_service.dart';
import '../farmer/farmer_dashboard.dart';
import '../admin/admin_dashboard.dart';

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
            : 'Enter your username and 4-digit PIN',
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
          _showSnack('Account number not found', ModernTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? profile['phone'] as String? ?? '';
      } else {
        final phone = FirebaseService.formatPhone(username);
        profile = await FirebaseService.getProfileByPhone(phone);
        if (profile == null) {
          _showSnack('No account found. Please register.', ModernTheme.error);
          return;
        }
        uid = profile['uid'] as String? ?? 'phone_$phone';
      }

      final pinOk = await FirebaseService.verifyPin(uid, pin);
      if (!pinOk) {
        _showSnack('Incorrect PIN', ModernTheme.error);
        return;
      }
      
      if (!mounted) return;
      
      final role = profile['role'] as String? ?? '';
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
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  // Mobile: Stacked layout
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 300,
            child: _buildImageSection(),
          ),
          _buildFormSection(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), // Very light overlay
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance,
                    size: 50,
                    color: ModernTheme.primaryBlue,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Welcome text
                const Text(
                  'Welcome to',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  'SACCOPLUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                const Text(
                  'Your trusted SACCO management system',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 2),
                        blurRadius: 8,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Heading
              Text(
                _useAccountNumber ? 'Enter your account number to log in' : 'Enter your phone number to log in',
                style: const TextStyle(
                  fontSize: 16,
                  color: ModernTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Username/Account Number field
              TextFormField(
                controller: _usernameCtrl,
                decoration: InputDecoration(
                  labelText: _useAccountNumber ? 'Account Number' : 'Phone Number',
                  hintText: _useAccountNumber ? '60000001' : '0700000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: ModernTheme.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: ModernTheme.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: ModernTheme.primaryBlue, width: 2),
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
                height: 50,
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'NEXT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              
              // Show PIN field after username entered
              if (_usernameCtrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _pinCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password/PIN',
                    hintText: '••••',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: ModernTheme.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: ModernTheme.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: ModernTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: ModernTheme.bgLight,
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  onFieldSubmitted: (_) => _login(),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'LOG IN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Password reset link
              TextButton(
                onPressed: () {
                  // TODO: Password reset
                },
                child: const Text(
                  'Password reset',
                  style: TextStyle(
                    color: ModernTheme.primaryBlue,
                    fontSize: 14,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have access? ",
                    style: TextStyle(
                      color: ModernTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Registration
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Click here to register',
                      style: TextStyle(
                        color: ModernTheme.primaryBlue,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
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
              
              const SizedBox(height: 48),
              
              // Footer
              const Text(
                'SECURITY ALERT\nSACCOPLUS does not send emails requesting for confidential information such as account codes, PINs, passwords, or PIN codes. Consider all email requests for such personal information to be suspicious and contact us immediately.',
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
      ),
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

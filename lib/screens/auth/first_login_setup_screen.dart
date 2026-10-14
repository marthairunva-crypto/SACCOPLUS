import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../farmer/farmer_dashboard.dart';
import '../admin/admin_dashboard.dart';

/// First login setup screen - forces users to change temp password and verify phone
class FirstLoginSetupScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> profile;

  const FirstLoginSetupScreen({
    super.key,
    required this.uid,
    required this.profile,
  });

  @override
  State<FirstLoginSetupScreen> createState() => _FirstLoginSetupScreenState();
}

class _FirstLoginSetupScreenState extends State<FirstLoginSetupScreen> {
  final _phoneCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  
  bool _loading = false;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill phone if available
    final existingPhone = widget.profile['phone'] as String?;
    if (existingPhone != null && existingPhone.isNotEmpty) {
      _phoneCtrl.text = existingPhone;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    // Validate inputs
    final phone = _phoneCtrl.text.trim();
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      _showSnack('Please enter a valid phone number', ModernTheme.error);
      return;
    }

    if (newPin.length != 4) {
      _showSnack('PIN must be exactly 4 digits', ModernTheme.error);
      return;
    }

    if (newPin != confirmPin) {
      _showSnack('PINs do not match', ModernTheme.error);
      return;
    }

    if (newPin == widget.profile['tempPassword']) {
      _showSnack('New PIN cannot be the same as temporary password', ModernTheme.error);
      return;
    }

    setState(() => _loading = true);

    try {
      // Format phone number
      final formattedPhone = FirebaseService.formatPhone(phone);

      // Save new PIN using the phone number
      await FirebaseService.savePin(newPin, phone: formattedPhone);

      // Update phone number and mark first login as complete
      await FirebaseService.completeFirstLogin(widget.uid);
      
      // Update phone if changed
      if (formattedPhone != widget.profile['phone']) {
        await FirebaseFirestore.instance
            .collection('saccoplus-members')
            .doc(widget.uid)
            .update({'phone': formattedPhone});
      }

      // Send SMS notification
      try {
        final name = widget.profile['name'] ?? 'Member';
        final accountNumber = widget.profile['accountNumber'] ?? 'N/A';
        await FirebaseService.sendSmsToPhone(
          formattedPhone,
          'MBADIFA SACCO\n'
          'Dear $name, your account has been activated successfully. '
          'Account: $accountNumber. You can now access all services. '
          'Keep your PIN secure. Thank you.',
        );
      } catch (e) {
        print('SMS sending failed: $e');
        // Continue even if SMS fails
      }

      if (!mounted) return;

      // Show success dialog
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
                  'Setup Complete!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ModernTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your account is now ready to use. Remember your new PIN for future logins.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ModernTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
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

      if (!mounted) return;

      // Navigate to appropriate dashboard
      final role = widget.profile['role'] as String? ?? '';
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
      if (mounted) {
        _showSnack('Setup failed: ${e.toString()}', ModernTheme.error);
      }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['name'] ?? 'Member';
    final accountNumber = widget.profile['accountNumber'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: ModernTheme.primaryBlue,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Account Setup',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ModernTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: ModernTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: ModernTheme.primaryBlue,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'First Time Login',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: ModernTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome, $name!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Account Number: $accountNumber',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'For security, please change your temporary password and verify your phone number.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ModernTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Phone Number Field
              Text(
                'Phone Number',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: '0700000000',
                  prefixIcon: Icon(Icons.phone, color: ModernTheme.primaryBlue),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.borderLight, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.borderLight, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.primaryBlue, width: 2.5),
                  ),
                  filled: true,
                  fillColor: ModernTheme.bgLight,
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // New PIN Field
              Text(
                'New 4-Digit PIN',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPinCtrl,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  prefixIcon: Icon(Icons.lock, color: ModernTheme.primaryBlue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPin ? Icons.visibility_off : Icons.visibility,
                      color: ModernTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _obscureNewPin = !_obscureNewPin);
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.borderLight, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.borderLight, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.primaryBlue, width: 2.5),
                  ),
                  filled: true,
                  fillColor: ModernTheme.bgLight,
                ),
                obscureText: _obscureNewPin,
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),

              const SizedBox(height: 16),

              // Confirm PIN Field
              Text(
                'Confirm New PIN',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPinCtrl,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  prefixIcon: Icon(Icons.lock_outline, color: ModernTheme.primaryBlue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                      color: ModernTheme.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirmPin = !_obscureConfirmPin);
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.borderLight, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.borderLight, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ModernTheme.primaryBlue, width: 2.5),
                  ),
                  filled: true,
                  fillColor: ModernTheme.bgLight,
                ),
                obscureText: _obscureConfirmPin,
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),

              const SizedBox(height: 32),

              // Complete Setup Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _completeSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.success,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: ModernTheme.success.withOpacity(0.4),
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
                      : Text(
                          'COMPLETE SETUP',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

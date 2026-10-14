import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../admin/admin_dashboard.dart';

/// OTP Verification Screen for Admin Login
/// Sends 6-digit OTP via SMS and verifies before allowing access
class OTPVerificationScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> profile;
  final String phoneNumber;

  const OTPVerificationScreen({
    Key? key,
    required this.uid,
    required this.profile,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  bool _loading = false;
  bool _resending = false;
  String? _generatedOTP;
  DateTime? _otpExpiry;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _sendOTP();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Generate and send OTP via SMS
  Future<void> _sendOTP() async {
    setState(() => _resending = true);

    try {
      // Generate 6-digit OTP
      final random = Random();
      _generatedOTP = (100000 + random.nextInt(900000)).toString();
      _otpExpiry = DateTime.now().add(const Duration(minutes: 5));

      // Store OTP in Firestore (for backup verification)
      await FirebaseFirestore.instance
          .collection('otp_verifications')
          .doc(widget.uid)
          .set({
        'otp': _generatedOTP,
        'phoneNumber': widget.phoneNumber,
        'expiresAt': Timestamp.fromDate(_otpExpiry!),
        'createdAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      // ✅ SEND ACTUAL SMS via EHGO
      final smsMessage = 'MBADIFA SACCO\nYour verification code is: $_generatedOTP\nValid for 5 minutes. Do not share this code.';
      await FirebaseService.sendSmsToPhone(widget.phoneNumber, smsMessage);

      // Debug console output
      debugPrint('');
      debugPrint('📱 ═══════════════════════════════════════════════');
      debugPrint('📱 SMS SENT TO: ${widget.phoneNumber}');
      debugPrint('📱 ═══════════════════════════════════════════════');
      debugPrint('');
      debugPrint('MBADIFA SACCO');
      debugPrint('Your verification code is: $_generatedOTP');
      debugPrint('Valid for 5 minutes. Do not share this code.');
      debugPrint('');
      debugPrint('📱 ═══════════════════════════════════════════════');
      debugPrint('');

      if (mounted) {
        _showSnack('OTP sent to ${_maskPhone(widget.phoneNumber)}', ModernTheme.success);
        _startResendCountdown();
      }
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      if (mounted) {
        _showSnack('Failed to send OTP. Please try again.', ModernTheme.error);
      }
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  /// Start countdown timer for resend button
  void _startResendCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  /// Mask phone number for privacy (show last 4 digits)
  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '****${phone.substring(phone.length - 4)}';
  }

  /// Verify entered OTP
  Future<void> _verifyOTP() async {
    final enteredOTP = _otpControllers.map((c) => c.text).join();

    if (enteredOTP.length != 6) {
      _showSnack('Please enter complete 6-digit OTP', ModernTheme.error);
      return;
    }

    // Check if OTP expired
    if (_otpExpiry != null && DateTime.now().isAfter(_otpExpiry!)) {
      _showSnack('OTP has expired. Please request a new one.', ModernTheme.error);
      return;
    }

    setState(() => _loading = true);

    try {
      // Verify OTP
      if (enteredOTP == _generatedOTP) {
        // Mark OTP as verified in Firestore
        await FirebaseFirestore.instance
            .collection('otp_verifications')
            .doc(widget.uid)
            .update({
          'verified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // Show success and navigate to dashboard
          await _showSuccessDialog();
        }
      } else {
        _showSnack('Invalid OTP. Please check and try again.', ModernTheme.error);
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      _showSnack('Verification failed. Please try again.', ModernTheme.error);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    showDialog(
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
                  Icons.verified_user,
                  size: 60,
                  color: ModernTheme.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification Successful!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ModernTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back, ${widget.profile['name'] ?? 'Admin'}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-close after 2 seconds and navigate
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context); // Close dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminDashboard(),
        ),
      );
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile['name'] ?? 'Admin';
    
    return WillPopScope(
      onWillPop: () async {
        // Allow back navigation
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: ModernTheme.textPrimary),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 20),
              
              // Security Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ModernTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: 64,
                  color: ModernTheme.primary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Verify Your Identity',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ModernTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'We\'ve sent a 6-digit OTP to\n${_maskPhone(widget.phoneNumber)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: ModernTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // OTP Input Fields
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive dimensions
                  final availableWidth = constraints.maxWidth;
                  final fieldMargin = 4.0;
                  final fieldCount = 6;
                  final totalMargin = fieldMargin * 2 * fieldCount;
                  final maxFieldWidth = (availableWidth - totalMargin) / fieldCount;
                  final fieldWidth = maxFieldWidth.clamp(40.0, 55.0);
                  final fieldHeight = fieldWidth * 1.18;
                  
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: fieldWidth,
                        height: fieldHeight,
                        margin: EdgeInsets.symmetric(horizontal: fieldMargin),
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: GoogleFonts.poppins(
                        fontSize: (fieldWidth * 0.43).clamp(18.0, 24.0),
                        fontWeight: FontWeight.w600,
                        color: ModernTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ModernTheme.primary, width: 2.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onChanged: (value) {
                        if (value.length == 1 && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        } else if (value.length == 1 && index == 5) {
                          // Auto-submit when last digit entered
                          _verifyOTP();
                        }
                      },
                    ),
                  );
                }),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Verify OTP',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Resend OTP
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    'Didn\'t receive OTP?',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: ModernTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _resending ? null : _sendOTP,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Resend OTP',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ModernTheme.primary,
                              ),
                            ),
                    ),
                ],
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

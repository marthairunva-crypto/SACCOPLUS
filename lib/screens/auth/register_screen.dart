import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/account_number_service.dart';
import '../../widgets/app_widgets.dart';
import 'professional_login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Step 0 = phone entry, 1 = OTP, 2 = set PIN, 3 = profile
  int _step = 0;

  final _phoneCtrl = TextEditingController();

  // Profile fields
  final _nameCtrl      = TextEditingController();
  final _villageCtrl   = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _nextOfKinCtrl = TextEditingController();
  String _memberType = 'Individual';
  final List<String> _memberTypes = ['Individual', 'Business', 'Group'];
  DateTime? _dateOfBirth;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _villageCtrl.dispose();
    _occupationCtrl.dispose();
    _nextOfKinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    return Scaffold(
      body: Container(
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
                const Color(0xFF0D2B6B).withOpacity(0.92),
                const Color(0xFF1565C0).withOpacity(0.88),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () {
                          if (_step == 0) {
                            Navigator.pop(context);
                          } else {
                            setState(() => _step--);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Step indicator
                _StepIndicator(current: _step),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
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
                        padding: const EdgeInsets.all(32),
                        child: AnimatedSwitcher(
                          duration: 350.ms,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(0.1, 0), end: Offset.zero)
                                  .animate(anim),
                              child: child,
                            ),
                          ),
                          child: _buildStep(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _PhoneStep(
          key: const ValueKey(0),
          phoneCtrl: _phoneCtrl,
          onNext: (phone) {
            setState(() => _step = 1);
          },
        );
      case 1:
        return _OtpStep(
          key: const ValueKey(1),
          phone: FirebaseService.formatPhone(_phoneCtrl.text.trim()),
          onVerified: () {
            setState(() => _step = 2);
          },
        );
      case 2:
        return _SetPinStep(
          key: const ValueKey(2),
          phone: FirebaseService.formatPhone(_phoneCtrl.text.trim()),
          onPinSet: () => setState(() => _step = 3),
        );
      case 3:
        return _ProfileStep(
          key: const ValueKey(3),
          nameCtrl: _nameCtrl,
          villageCtrl: _villageCtrl,
          occupationCtrl: _occupationCtrl,
          nextOfKinCtrl: _nextOfKinCtrl,
          memberType: _memberType,
          memberTypes: _memberTypes,
          onMemberTypeChanged: (v) => setState(() => _memberType = v),
          phone: FirebaseService.formatPhone(_phoneCtrl.text.trim()),
          dateOfBirth: _dateOfBirth,
          onDateOfBirthChanged: (d) => setState(() => _dateOfBirth = d),
          onDone: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ProfessionalLoginScreen()),
              (r) => false,
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    final labels = ['Phone', 'Verify OTP', 'Set PIN', 'Profile'];
    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: 300.ms,
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done || active ? Colors.white : Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: AppTheme.primary)
                            : Text('${i + 1}',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? AppTheme.primary
                                        : Colors.white54)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i],
                        style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: active || done
                                ? Colors.white
                                : Colors.white54)),
                  ],
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: done ? Colors.white : Colors.white24,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── Step 0: Phone ────────────────────────────────────────────────────────────
class _PhoneStep extends StatefulWidget {
  final TextEditingController phoneCtrl;
  final ValueChanged<String> onNext;

  const _PhoneStep({super.key, required this.phoneCtrl, required this.onNext});

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  bool _loading = false;

  Future<void> _proceed() async {
    final rawPhone = widget.phoneCtrl.text.trim();
    if (rawPhone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid phone number'),
          backgroundColor: AppTheme.error));
      return;
    }
    final phone = FirebaseService.formatPhone(rawPhone);
    // Check if already registered
    setState(() => _loading = true);
    try {
      final existing = await FirebaseService.getProfileByPhone(phone);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('This number is already registered. Please sign in.'),
              backgroundColor: AppTheme.warning));
        }
        return;
      }
      widget.onNext(phone);
    } catch (_) {
      widget.onNext(phone);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Enter your phone number',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary))
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 6),
        Text('We will send a one-time code to verify your number.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary))
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 28),
        TextField(
          controller: widget.phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))
          ],
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+256 7XX XXX XXX',
            prefixIcon: Icon(Icons.phone_rounded),
          ),
        )
            .animate()
            .fadeIn(delay: 150.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Send OTP',
          loading: _loading,
          onPressed: _proceed,
          icon: Icons.sms_rounded,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: RichText(
              text: TextSpan(
                text: 'Already have an account? ',
                style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary, fontSize: 13),
                children: [
                  TextSpan(
                    text: 'Sign In',
                    style: GoogleFonts.poppins(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 1: OTP ──────────────────────────────────────────────────────────────
class _OtpStep extends StatefulWidget {
  final String phone;
  final VoidCallback onVerified;

  const _OtpStep({super.key, required this.phone, required this.onVerified});

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
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
    setState(() { _sending = true; _error = null; });
    final sent = await FirebaseService.generateAndSendOtp(widget.phone);
    if (mounted) {
      setState(() {
        _sending = false;
        if (!sent) _error = 'Failed to send OTP. Check your connection.';
      });
    }
  }

  String get _code => _ctrls.map((c) => c.text).join();

  void _verify() {
    if (_code.length != 6) return;
    setState(() => _verifying = true);
    final ok = FirebaseService.verifyEgoOtp(widget.phone, _code);
    if (ok) {
      if (mounted) widget.onVerified();
    } else {
      if (mounted) {
        setState(() {
          _error = 'Invalid or expired code. Please try again.';
          _verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Text('Verify your number',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary))
            .animate()
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 6),
        Text('Code sent to ${widget.phone}',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary))
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 32),

        if (_sending)
          const CircularProgressIndicator(color: AppTheme.primary)
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => SizedBox(
              width: 46,
              height: 54,
              child: TextField(
                controller: _ctrls[i],
                focusNode: _nodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                  if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                  if (_code.length == 6) _verify();
                },
              ),
            )),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),

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
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _sending ? null : _sendOtp,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Resend OTP',
                style: GoogleFonts.poppins(
                    color: AppTheme.primary, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

// ─── Step 2: Set PIN ──────────────────────────────────────────────────────────
class _SetPinStep extends StatefulWidget {
  final String phone;
  final VoidCallback onPinSet;
  const _SetPinStep({super.key, required this.phone, required this.onPinSet});

  @override
  State<_SetPinStep> createState() => _SetPinStepState();
}

class _SetPinStepState extends State<_SetPinStep> {
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
      widget.onPinSet();
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.dialpad_rounded,
              color: AppTheme.primary, size: 28),
        )
            .animate()
            .scale(
                begin: const Offset(0.5, 0.5),
                duration: 500.ms,
                curve: Curves.elasticOut),
        const SizedBox(height: 12),
        Text('Set your PIN',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary))
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 6),
        Text('Choose a 4-digit PIN to secure your account.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center)
            .animate()
            .fadeIn(delay: 150.ms, duration: 400.ms),
        const SizedBox(height: 20),
        _PinInputRow(
          controller: _pinCtrl,
          label: 'New PIN',
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        _PinInputRow(
          controller: _confirmCtrl,
          label: 'Confirm PIN',
        )
            .animate()
            .fadeIn(delay: 250.ms, duration: 400.ms)
            .slideY(begin: 0.2, end: 0),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Save PIN & Continue',
          loading: _loading,
          onPressed: _save,
          icon: Icons.lock_rounded,
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }
}

// ─── Step 3: Profile ──────────────────────────────────────────────────────────
class _ProfileStep extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController villageCtrl;
  final TextEditingController occupationCtrl;
  final TextEditingController nextOfKinCtrl;
  final String memberType;
  final List<String> memberTypes;
  final ValueChanged<String> onMemberTypeChanged;
  final String phone;
  final DateTime? dateOfBirth;
  final ValueChanged<DateTime?> onDateOfBirthChanged;
  final VoidCallback onDone;

  const _ProfileStep({
    super.key,
    required this.nameCtrl,
    required this.villageCtrl,
    required this.occupationCtrl,
    required this.nextOfKinCtrl,
    required this.memberType,
    required this.memberTypes,
    required this.onMemberTypeChanged,
    required this.phone,
    required this.dateOfBirth,
    required this.onDateOfBirthChanged,
    required this.onDone,
  });

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  bool _loading = false;
  File? _profileImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  Future<void> _save() async {
    if (widget.nameCtrl.text.trim().isEmpty ||
        widget.villageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill in your name and location.'),
          backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _loading = true);
    try {
      String imageUrl = '';
      if (_profileImage != null) {
        imageUrl = await FirebaseService.uploadImageToImgbb(_profileImage!) ?? '';
      }

      // Auto-generate account number for this member
      final accountNumber = await AccountNumberService.generateNext();

      final uid = 'phone_${widget.phone}';
      await FirebaseService.createUserProfile({
        'uid': uid,
        'name': widget.nameCtrl.text.trim(),
        'phone': widget.phone,
        'accountNumber': accountNumber,
        'village': widget.villageCtrl.text.trim(),
        'occupation': widget.occupationCtrl.text.trim(),
        'nextOfKin': widget.nextOfKinCtrl.text.trim(),
        'memberType': widget.memberType,
        'role': AppConstants.roleMember,
        'profileImage': imageUrl,
        'memberStatus': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
        if (widget.dateOfBirth != null)
          'dateOfBirth': widget.dateOfBirth!.toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Account created! Your account number: $accountNumber'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 5)));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text, bool required = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Complete your profile',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary))
            .animate()
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 6),
        Text('This information helps us serve you better.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary))
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 20),

        // Profile picture picker
        Center(
          child: GestureDetector(
            onTap: _profileImage == null ? _pickImage : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person_rounded,
                          size: 48, color: AppTheme.primary)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
        const SizedBox(height: 6),
        Center(
          child: Text('Tap to add profile photo (optional)',
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ),

        const SizedBox(height: 16),
        _field(widget.nameCtrl, 'Full Name', Icons.person_outline_rounded, required: true),
        const SizedBox(height: 10),
        _field(widget.villageCtrl, 'Village / Town / Sub-county',
            Icons.location_on_outlined, required: true),
        const SizedBox(height: 10),
        _field(widget.occupationCtrl, 'Occupation / Business',
            Icons.work_outline_rounded),
        const SizedBox(height: 10),
        _field(widget.nextOfKinCtrl, 'Next of Kin (Name & Phone)',
            Icons.people_outline_rounded),
        const SizedBox(height: 10),
        // ─── Date of Birth picker ──────────────────────────────────────────
        _DateOfBirthPicker(
          value: widget.dateOfBirth,
          onChanged: widget.onDateOfBirthChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: widget.memberType,
          decoration: const InputDecoration(
            labelText: 'Member Type',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          items: widget.memberTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => widget.onMemberTypeChanged(v!),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Create Account',
          loading: _loading,
          onPressed: _save,
          icon: Icons.check_circle_rounded,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),
      ],
    );
  }
}

// ─── PIN input row (4 boxes) ──────────────────────────────────────────────────
class _PinInputRow extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const _PinInputRow({required this.controller, required this.label});

  @override
  State<_PinInputRow> createState() => _PinInputRowState();
}

class _PinInputRowState extends State<_PinInputRow> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 24,
              letterSpacing: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            hintText: '• • • •',
            hintStyle: GoogleFonts.poppins(
                fontSize: 24,
                letterSpacing: 16,
                color: Colors.grey.shade300),
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Date of Birth Picker ─────────────────────────────────────────────────────
class _DateOfBirthPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _DateOfBirthPicker({required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      helpText: 'Select Date of Birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = value != null
        ? '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/'
            '${value!.year}'
        : 'Date of Birth (optional)';
    return GestureDetector(
      onTap: () => _pick(context),
      child: AbsorbPointer(
        child: TextField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.cake_outlined),
            suffixIcon: value != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => onChanged(null),
                  )
                : const Icon(Icons.calendar_today_outlined, size: 18),
          ),
        ),
      ),
    );
  }
}

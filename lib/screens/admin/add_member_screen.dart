import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../services/account_number_service.dart';
import '../../services/audit_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _bg = Color(0xFFF5F7FA);
const _line = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _fieldFill = Color(0xFFF8FAFC);

TextStyle _t(double size, {FontWeight w = FontWeight.w400, Color c = _ink, double? h}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: h);

class _StepInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  const _StepInfo(this.title, this.subtitle, this.icon);
}

const _steps = <_StepInfo>[
  _StepInfo('Personal', 'Identity and contact', Icons.person_outline_rounded),
  _StepInfo('Location', 'Where the member lives', Icons.location_on_outlined),
  _StepInfo('Next of kin', 'Emergency contact', Icons.people_outline_rounded),
];

/// A grid cell: [full] cells span both columns on wide layouts.
class _F {
  final Widget child;
  final bool full;
  const _F(this.child, {this.full = false});
}

class AddMemberScreen extends StatefulWidget {
  /// When true the screen renders without its own Scaffold/AppBar, so it can live
  /// inside a Dialog. Use [AddMemberScreen.show] to pick the right presentation.
  final bool isDialog;

  const AddMemberScreen({super.key, this.isDialog = false});

  /// Opens the form as a dialog on large screens and as a full page on phones.
  static Future<void> show(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width < 700) {
      return Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddMemberScreen()),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: math.min(980, size.width - 48),
          height: math.min(780, size.height - 48),
          child: const AddMemberScreen(isDialog: true),
        ),
      ),
    );
  }

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Personal Information
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ninController = TextEditingController();
  String _gender = 'Male';
  DateTime? _dateOfBirth;

  // Step 2: Location Details
  final _villageController = TextEditingController();
  final _parishController = TextEditingController();
  final _subcountyController = TextEditingController();
  final _countyController = TextEditingController();
  final _districtController = TextEditingController();

  // Step 3: Next of Kin
  final _kinNameController = TextEditingController();
  final _kinPhoneController = TextEditingController();
  final _kinRelationshipController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ninController.dispose();
    _villageController.dispose();
    _parishController.dispose();
    _subcountyController.dispose();
    _countyController.dispose();
    _districtController.dispose();
    _kinNameController.dispose();
    _kinPhoneController.dispose();
    _kinRelationshipController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGIC (unchanged)
  // ═══════════════════════════════════════════════════════════════════════════
  String _formatPhoneNumber(String phone) {
    // Remove any spaces or special characters
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // If starts with 07, convert to 2567
    if (phone.startsWith('07') && phone.length == 10) {
      return '256${phone.substring(1)}';
    }

    // If starts with 7, add 256
    if (phone.startsWith('7') && phone.length == 9) {
      return '256$phone';
    }

    // If already starts with 256, return as is
    if (phone.startsWith('256')) {
      return phone;
    }

    return phone;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');

    if (!cleaned.startsWith('07') && !cleaned.startsWith('256')) {
      return 'Phone must start with 07';
    }

    if (cleaned.startsWith('07') && cleaned.length != 10) {
      return 'Phone must be 10 digits (07XXXXXXXX)';
    }

    if (cleaned.startsWith('256') && cleaned.length != 12) {
      return 'Phone must be 12 digits (256XXXXXXXXX)';
    }

    return null;
  }

  String? _required(String? v, String message) => (v ?? '').trim().isEmpty ? message : null;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Format phone numbers
      final phone = _formatPhoneNumber(_phoneController.text.trim());
      final kinPhone = _formatPhoneNumber(_kinPhoneController.text.trim());

      // Generate account number and member number
      final accountNumber = await AccountNumberService.generateNext();

      // Generate member number in same format as existing (10-digit: 922XXXXXXX)
      // Use a counter to get the next number
      final memberCounterRef = FirebaseFirestore.instance
          .collection('saccoplus-counters')
          .doc('member_numbers_${FirebaseService.sessionTenantId}');

      int memberNumberInt = 9220000000;
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(memberCounterRef);
        if (snap.exists) {
          memberNumberInt = (snap.data()!['lastNumber'] as int? ?? 9219999999) + 1;
        }
        txn.set(memberCounterRef, {'lastNumber': memberNumberInt}, SetOptions(merge: true));
      });

      final memberNumber = memberNumberInt.toString(); // e.g., "9220000361"

      // Generate default PIN (last 4 digits of phone)
      final defaultPin = phone.substring(phone.length - 4);

      // Create member data
      final memberData = {
        'name': _fullNameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'phone': phone,
        'email': _emailController.text.trim(),
        'nationalId': _ninController.text.trim(),
        'nin': _ninController.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'village': _villageController.text.trim(),
        'parish': _parishController.text.trim(),
        'subcounty': _subcountyController.text.trim(),
        'county': _countyController.text.trim(),
        'district': _districtController.text.trim(),
        'nextOfKin': _kinNameController.text.trim(),
        'nextOfKinPhone': kinPhone,
        'nextOfKinRelationship': _kinRelationshipController.text.trim(),
        'accountNumber': accountNumber,
        'memberNumber': memberNumber,
        'pin': defaultPin,
        'role': AppConstants.roleMember, // 'Member' with capital M - ensures they appear in loan creation
        'status': 'active',
        'idStatus': 'pending',
        'tenantId': FirebaseService.sessionTenantId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseService.sessionUid,
        'walletBalance': 0,
        'savingsBalance': 0,
        'sharesBalance': 0,
        'fixedDepositBalance': 0,
        'loanBalance': 0,
      };

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance.collection('users').add(memberData);

      // Audit log
      await AuditService.log(
        action: 'MEMBER_ADDED',
        details: 'Admin added new member: ${_fullNameController.text.trim()}',
        userId: FirebaseService.sessionUid,
        affectedUserId: docRef.id,
        metadata: {
          'memberNumber': memberNumber,
          'accountNumber': accountNumber,
        },
      );

      if (!mounted) return;

      // Send SMS with login credentials
      final memberName = _fullNameController.text.trim();
      final saccoName = 'MBADIFA SACCO';
      final smsMessage = '$saccoName: Dear $memberName, welcome! Your account has been created. '
          'Account: $accountNumber, Member No: $memberNumber, PIN: $defaultPin. '
          'Download our app or visit any branch to access your account. Thank you!';
      
      try {
        await FirebaseService.sendSmsToPhone(phone, smsMessage);
        print('✅ Welcome SMS sent to $phone');
      } catch (e) {
        print('⚠️ Failed to send welcome SMS: $e');
      }

      // Show success message with account details
      _showSuccessDialog(memberName, memberNumber, accountNumber, phone, defaultPin);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      if (_formKey.currentState!.validate()) {
        setState(() => _currentStep++);
      }
    } else {
      _submitForm();
    }
  }

  Future<void> _pickDob() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _dateOfBirth = date);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUCCESS DIALOG
  // ═══════════════════════════════════════════════════════════════════════════
  void _showSuccessDialog(String memberName, String memberNumber, String accountNumber, String phone, String pin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top colored section with icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.success,
                      AppTheme.success.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_add_rounded,
                        color: AppTheme.success,
                        size: 60,
                      ),
                    ),
                  ],
                ),
              ),

              // Content section
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Title
                    Text(
                      'Member Added Successfully! 🎉',
                      textAlign: TextAlign.center,
                      style: _t(24, w: FontWeight.w700, c: _ink),
                    ),

                    const SizedBox(height: 12),

                    // Member name
                    Text(
                      memberName,
                      textAlign: TextAlign.center,
                      style: _t(18, w: FontWeight.w600, c: AppTheme.primary),
                    ),

                    const SizedBox(height: 16),

                    // Message
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sms_outlined, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'SMS sent with login credentials to member\'s phone',
                              style: _t(12, c: Colors.green.shade900, h: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Account details card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.success.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          _successInfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Member Number',
                            value: memberNumber,
                            canCopy: true,
                          ),
                          const SizedBox(height: 16),
                          _successInfoRow(
                            icon: Icons.account_balance_outlined,
                            label: 'Account Number',
                            value: accountNumber,
                            canCopy: true,
                          ),
                          const SizedBox(height: 16),
                          _successInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            value: phone,
                          ),
                          const SizedBox(height: 16),
                          _successInfoRow(
                            icon: Icons.lock_outline,
                            label: 'Default PIN',
                            value: pin,
                            canCopy: true,
                            highlight: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Info text
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Member can now log in with their phone number and PIN. They should change their PIN on first login.',
                              style: _t(12, c: Colors.blue.shade900, h: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Done button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogCtx).pop(); // close success dialog
                          if (mounted) Navigator.of(context).pop(); // close add-member screen/dialog
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: _t(16, w: FontWeight.w600, c: Colors.white),
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
    );
  }

  Widget _successInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool canCopy = false,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.success, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: _t(12, c: _muted, w: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: _t(
                  highlight ? 16 : 15,
                  w: highlight ? FontWeight.w700 : FontWeight.w600,
                  c: highlight ? AppTheme.success : _ink,
                ),
              ),
            ],
          ),
        ),
        if (canCopy) ...[
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _muted.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.copy_rounded, size: 16, color: _muted),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final body = Form(
      key: _formKey,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 820 && c.maxHeight >= 600;

        if (widget.isDialog) {
          return wide ? _wideLayout() : _narrowLayout();
        }

        if (wide) {
          final w = math.min(c.maxWidth - 48, 1040.0);
          final h = math.min(c.maxHeight - 48, 760.0);
          return Center(
            child: Container(
              width: w,
              height: h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: _wideLayout(),
            ),
          );
        }
        return _narrowLayout();
      }),
    );

    if (widget.isDialog) {
      return Material(color: Colors.white, child: body);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Add new member', style: _t(17, w: FontWeight.w600, c: Colors.white)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: body,
    );
  }

  // ───────────────────────────── WIDE: side panel + form ───────────────────────
  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 290, child: _sidePanel()),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(36, 32, 36, 24),
                  child: _stepContent(showClose: widget.isDialog),
                ),
              ),
              _footer(compact: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidePanel() {
    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 18),
          Text('New member', style: _t(21, w: FontWeight.w700, c: Colors.white)),
          const SizedBox(height: 4),
          Text('Register a member in three short steps.',
              style: _t(12.5, c: Colors.white70, h: 1.4)),
          const SizedBox(height: 30),
          for (int i = 0; i < _steps.length; i++) ...[
            _sideStep(i),
            if (i < _steps.length - 1)
              Container(
                width: 2,
                height: 22,
                margin: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                color: Colors.white.withOpacity(_currentStep > i ? 0.7 : 0.2),
              ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white70),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Account number, member number and login PIN are generated automatically.',
                    style: _t(11.5, c: Colors.white70, h: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideStep(int i) {
    final s = _steps[i];
    final done = _currentStep > i;
    final active = _currentStep == i;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active || done ? Colors.white : Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            done ? Icons.check_rounded : s.icon,
            size: 18,
            color: active || done ? AppTheme.primary : Colors.white70,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.title,
                  style: _t(13.5,
                      w: active ? FontWeight.w600 : FontWeight.w500,
                      c: active || done ? Colors.white : Colors.white70)),
              Text(s.subtitle, style: _t(11.5, c: Colors.white54)),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────── NARROW: stacked ───────────────────────────────
  Widget _narrowLayout() {
    return Column(
      children: [
        if (widget.isDialog)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: Text('Add new member', style: _t(16, w: FontWeight.w600))),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        _compactProgress(),
        Expanded(
          child: Container(
            color: widget.isDialog ? Colors.white : _bg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _line),
                ),
                child: _stepContent(showClose: false),
              ),
            ),
          ),
        ),
        _footer(compact: true),
      ],
    );
  }

  Widget _compactProgress() {
    Widget dot(int i) {
      final done = _currentStep > i;
      final active = _currentStep == i;
      final on = done || active;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: on ? AppTheme.primary : const Color(0xFFEEF2F6),
              shape: BoxShape.circle,
            ),
            child: Icon(done ? Icons.check_rounded : _steps[i].icon,
                size: 18, color: on ? Colors.white : const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Text(_steps[i].title,
              style: _t(11,
                  w: active ? FontWeight.w600 : FontWeight.w400,
                  c: on ? AppTheme.primary : _muted)),
        ],
      );
    }

    Widget bar(int i) => Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
            color: _currentStep > i ? AppTheme.primary : _line,
          ),
        );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [dot(0), bar(0), dot(1), bar(1), dot(2)],
      ),
    );
  }

  // ───────────────────────────── FOOTER ────────────────────────────────────────
  Widget _footer({required bool compact}) {
    final last = _currentStep == _steps.length - 1;

    final nextBtn = ElevatedButton(
      onPressed: _isSubmitting ? null : _next,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: compact ? 16 : 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(last ? 'Add member' : 'Continue', style: _t(14.5, w: FontWeight.w600, c: Colors.white)),
                const SizedBox(width: 8),
                Icon(last ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
              ],
            ),
    );

    final backBtn = OutlinedButton(
      onPressed: _isSubmitting ? null : () => setState(() => _currentStep--),
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        side: const BorderSide(color: _line),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: compact ? 16 : 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text('Back', style: _t(14.5, w: FontWeight.w500)),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 36, 14, compact ? 16 : 36, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: SafeArea(
        top: false,
        child: compact
            ? Row(
                children: [
                  if (_currentStep > 0) ...[
                    Expanded(child: backBtn),
                    const SizedBox(width: 12),
                  ],
                  Expanded(flex: 2, child: nextBtn),
                ],
              )
            : Row(
                children: [
                  if (_currentStep > 0)
                    backBtn
                  else
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: _t(14, w: FontWeight.w500, c: _muted)),
                    ),
                  const Spacer(),
                  Text('Step ${_currentStep + 1} of ${_steps.length}', style: _t(12, c: _muted)),
                  const SizedBox(width: 20),
                  nextBtn,
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP CONTENT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _stepContent({required bool showClose}) {
    final s = _steps[_currentStep];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_stepTitle(), style: _t(21, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_stepSubtitle(), style: _t(13, c: _muted, h: 1.4)),
                ],
              ),
            ),
            if (showClose)
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, color: _muted),
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Fields marked * are required', style: _t(11.5, c: const Color(0xFF94A3B8))),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(s.title),
            child: _stepFields(),
          ),
        ),
      ],
    );
  }

  String _stepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Personal information';
      case 1:
        return 'Location details';
      default:
        return 'Next of kin';
    }
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Enter the member\'s basic details.';
      case 1:
        return 'Specify where the member is located.';
      default:
        return 'Who should we contact in an emergency?';
    }
  }

  Widget _stepFields() {
    switch (_currentStep) {
      case 0:
        return _personalFields();
      case 1:
        return _locationFields();
      default:
        return _kinFields();
    }
  }

  Widget _personalFields() {
    return _grid([
      _F(
        _textField(
          controller: _fullNameController,
          label: 'Full name *',
          icon: Icons.person_outline_rounded,
          capitalization: TextCapitalization.words,
          validator: (v) => _required(v, 'Name is required'),
        ),
        full: true,
      ),
      _F(_textField(
        controller: _phoneController,
        label: 'Phone number *',
        icon: Icons.phone_outlined,
        hint: '07XXXXXXXX',
        keyboardType: TextInputType.phone,
        formatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
          LengthLimitingTextInputFormatter(15),
        ],
        validator: _validatePhone,
      )),
      _F(_textField(
        controller: _emailController,
        label: 'Email (optional)',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      )),
      _F(_textField(
        controller: _ninController,
        label: 'National ID (NIN) *',
        icon: Icons.badge_outlined,
        hint: 'CM1234567890123',
        capitalization: TextCapitalization.characters,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'NIN is required';
          if (v.trim().length < 10) return 'Enter valid NIN';
          return null;
        },
      )),
      _F(_dropdown(
        value: _gender,
        label: 'Gender *',
        icon: Icons.wc_rounded,
        items: const ['Male', 'Female', 'Other'],
        onChanged: (v) => setState(() => _gender = v ?? _gender),
      )),
      _F(_dateField()),
    ]);
  }

  Widget _locationFields() {
    return _grid([
      _F(_textField(
        controller: _villageController,
        label: 'Village *',
        icon: Icons.home_outlined,
        capitalization: TextCapitalization.words,
        validator: (v) => _required(v, 'Village is required'),
      )),
      _F(_textField(
        controller: _parishController,
        label: 'Parish *',
        icon: Icons.location_city_outlined,
        capitalization: TextCapitalization.words,
        validator: (v) => _required(v, 'Parish is required'),
      )),
      _F(_textField(
        controller: _subcountyController,
        label: 'Sub-county *',
        icon: Icons.place_outlined,
        capitalization: TextCapitalization.words,
        validator: (v) => _required(v, 'Sub-county is required'),
      )),
      _F(_textField(
        controller: _countyController,
        label: 'County / Division',
        icon: Icons.map_outlined,
        capitalization: TextCapitalization.words,
      )),
      _F(_textField(
        controller: _districtController,
        label: 'District *',
        icon: Icons.location_on_outlined,
        capitalization: TextCapitalization.words,
        validator: (v) => _required(v, 'District is required'),
      )),
    ]);
  }

  Widget _kinFields() {
    const relations = ['Spouse', 'Parent', 'Sibling', 'Child', 'Other'];
    final current = _kinRelationshipController.text.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _grid([
          _F(_textField(
            controller: _kinNameController,
            label: 'Next of kin name *',
            icon: Icons.person_outline_rounded,
            capitalization: TextCapitalization.words,
            validator: (v) => _required(v, 'Next of kin name is required'),
          )),
          _F(_textField(
            controller: _kinPhoneController,
            label: 'Next of kin phone *',
            icon: Icons.phone_outlined,
            hint: '07XXXXXXXX',
            keyboardType: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              LengthLimitingTextInputFormatter(15),
            ],
            validator: _validatePhone,
          )),
          _F(
            _textField(
              controller: _kinRelationshipController,
              label: 'Relationship *',
              icon: Icons.family_restroom_rounded,
              hint: 'e.g. Spouse, Parent, Sibling',
              capitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) => _required(v, 'Relationship is required'),
            ),
            full: true,
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in relations)
              ChoiceChip(
                label: Text(r, style: _t(12.5, w: FontWeight.w500)),
                selected: current == r.toLowerCase(),
                selectedColor: AppTheme.primary.withOpacity(0.12),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: current == r.toLowerCase() ? AppTheme.primary : _line,
                ),
                showCheckmark: false,
                onSelected: (_) => setState(() => _kinRelationshipController.text = r),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _autoInfoCard(),
      ],
    );
  }

  Widget _autoInfoCard() {
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$label  ', style: _t(12.5, w: FontWeight.w600, c: Colors.green.shade900)),
                    TextSpan(text: value, style: _t(12.5, c: Colors.green.shade800)),
                  ]),
                ),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 8),
              Text('Generated automatically',
                  style: _t(13.5, w: FontWeight.w600, c: Colors.green.shade900)),
            ],
          ),
          const SizedBox(height: 8),
          row(Icons.account_balance_outlined, 'Account number', 'created when you save'),
          row(Icons.tag_rounded, 'Member number', 'assigned in sequence'),
          row(Icons.lock_outline_rounded, 'Login PIN', 'last 4 digits of the phone number'),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIELD HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  /// Two columns when there is room, one column otherwise.
  Widget _grid(List<_F> items) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 16.0;
      final two = c.maxWidth >= 520;
      final half = (c.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final f in items)
            SizedBox(width: (two && !f.full) ? half : c.maxWidth, child: f.child),
        ],
      );
    });
  }

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  InputDecoration _deco(String label, IconData icon, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: _t(13.5, c: _muted),
        hintStyle: _t(13.5, c: const Color(0xFF94A3B8)),
        errorStyle: _t(11.5, c: Colors.red.shade600),
        prefixIcon: Icon(icon, size: 20, color: _muted),
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(_line),
        enabledBorder: _border(_line),
        focusedBorder: _border(AppTheme.primary, 1.6),
        errorBorder: _border(Colors.red.shade300),
        focusedErrorBorder: _border(Colors.red.shade400, 1.6),
      );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      decoration: _deco(label, icon, hint: hint),
      style: _t(14),
      validator: validator,
    );
  }

  Widget _dropdown({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: _deco(label, icon),
      style: _t(14),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: _t(14)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _dateField() {
    String two(int n) => n.toString().padLeft(2, '0');
    final dob = _dateOfBirth;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDob,
      child: InputDecorator(
        decoration: _deco('Date of birth (optional)', Icons.cake_outlined).copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: _muted),
        ),
        child: Text(
          dob != null ? '${two(dob.day)}/${two(dob.month)}/${dob.year}' : 'Select date',
          style: _t(14, c: dob != null ? _ink : const Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
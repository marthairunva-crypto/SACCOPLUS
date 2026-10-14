import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';

class CreateFixedDepositScreen extends StatefulWidget {
  const CreateFixedDepositScreen({super.key});
  @override
  State<CreateFixedDepositScreen> createState() => _CreateFixedDepositScreenState();
}

class _CreateFixedDepositScreenState extends State<CreateFixedDepositScreen> {
  final _principalCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  
  int _termMonths = 12;
  double _interestRate = 5.0;
  bool _rollover = false;
  bool _loading = false;
  bool _otpSent = false;
  bool _showPinOtp = false;
  
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  void dispose() {
    _principalCtrl.dispose();
    _pinCtrl.dispose();
    _otpCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  int get _principal => int.tryParse(_principalCtrl.text.trim().replaceAll(',', '')) ?? 0;
  int get _interestAmount => (_principal * _interestRate * _termMonths / 12 / 100).round();
  int get _maturityAmount => _principal + _interestAmount;

  Future<void> _sendOTP() async {
    if (_principal < 50000) {
      _snack('Minimum fixed deposit amount is UGX 50,000', AppTheme.error);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      final profile = await FirebaseService.getUserProfile(uid);
      final phone = profile?['phone'] as String?;
      
      if (phone == null) {
        _snack('Phone number not found. Please update your profile.', AppTheme.error);
        return;
      }

      await FirebaseService.sendOtp(phone);
      setState(() {
        _otpSent = true;
        _showPinOtp = true;
      });
      _snack('OTP sent to your phone. Please enter PIN and OTP to continue.', AppTheme.success);
    } catch (e) {
      _snack('Error sending OTP: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (_principal < 50000) {
      _snack('Minimum fixed deposit amount is UGX 50,000', AppTheme.error);
      return;
    }

    if (pin.length != 4) {
      _snack('Enter your 4-digit PIN', AppTheme.error);
      return;
    }

    if (otp.length != 6) {
      _snack('Enter the 6-digit OTP sent to your phone', AppTheme.error);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      
      await FirebaseService.createFixedDeposit(
        uid: uid,
        principal: _principal,
        termMonths: _termMonths,
        interestRate: _interestRate,
        pin: pin,
        otpCode: otp,
        rollover: _rollover,
        description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      );
      
      _snack('Fixed deposit created successfully! Amount deducted from wallet. Pending admin approval.', AppTheme.success);
      Navigator.pop(context);
    } catch (e) {
      _snack('Error: ${e.toString()}', AppTheme.error);
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

  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'Create Fixed Deposit',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fixed Deposit Application',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Secure fixed deposit with PIN + OTP verification. Amount will be deducted from your wallet.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),

            const SizedBox(height: 20),

            TextField(
              controller: _principalCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Principal Amount (UGX)',
                prefixIcon: Icon(Icons.attach_money_rounded),
                hintText: 'Minimum 50,000',
              ),
            ),

            const SizedBox(height: 16),

            // Term selection
            Text('Term Period', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [6, 12, 18, 24, 36].map((months) => 
                ChoiceChip(
                  label: Text('$months months'),
                  selected: _termMonths == months,
                  onSelected: (selected) => setState(() => _termMonths = months),
                  selectedColor: AppTheme.primary.withOpacity(0.2),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _termMonths == months ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ).toList(),
            ),

            const SizedBox(height: 16),

            // Interest rate
            Text('Interest Rate', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [3.0, 4.0, 5.0, 6.0, 7.0].map((rate) => 
                ChoiceChip(
                  label: Text('${rate.toStringAsFixed(1)}% p.a.'),
                  selected: _interestRate == rate,
                  onSelected: (selected) => setState(() => _interestRate = rate),
                  selectedColor: AppTheme.accent.withOpacity(0.2),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _interestRate == rate ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                ),
              ).toList(),
            ),

            const SizedBox(height: 16),

            // Auto-rollover
            SwitchListTile(
              title: Text('Auto-Rollover', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Automatically renew at maturity', style: GoogleFonts.poppins(fontSize: 12)),
              value: _rollover,
              onChanged: (value) => setState(() => _rollover = value),
              activeColor: AppTheme.primary,
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.description_rounded),
                hintText: 'e.g. Emergency fund',
              ),
            ),

            // Calculation preview
            if (_principal >= 50000) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maturity Calculation', 
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.success)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Principal:', style: GoogleFonts.poppins(fontSize: 12)),
                      Text('UGX ${fmt.format(_principal)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Interest (${_interestRate.toStringAsFixed(1)}% × $_termMonths months):', style: GoogleFonts.poppins(fontSize: 12)),
                      Text('UGX ${fmt.format(_interestAmount)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const Divider(),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Maturity Amount:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('UGX ${fmt.format(_maturityAmount)}', 
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success)),
                    ]),
                  ],
                ),
              ),
            ],

            if (_showPinOtp) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 20),
                      const SizedBox(width: 8),
                      Text('Security Verification', 
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.success)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '4-Digit PIN',
                        prefixIcon: Icon(Icons.lock_rounded),
                        hintText: '••••',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      decoration: const InputDecoration(
                        labelText: '6-Digit OTP',
                        prefixIcon: Icon(Icons.sms_rounded),
                        hintText: '123456',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (!_showPinOtp)
              PrimaryButton(
                label: 'Send OTP & Continue',
                loading: _loading,
                onPressed: _sendOTP,
                icon: Icons.sms_rounded,
              )
            else
              PrimaryButton(
                label: 'Create Fixed Deposit',
                loading: _loading,
                onPressed: _submit,
                icon: Icons.account_balance_rounded,
              ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fixed deposits require admin approval. Your funds will be locked for the selected term period.',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.info),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

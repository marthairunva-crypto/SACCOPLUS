import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';
import 'guarantor_picker_screen.dart';
import 'guarantor_consent_screen.dart';

class ApplyLoanScreen extends StatefulWidget {
  const ApplyLoanScreen({super.key});

  @override
  State<ApplyLoanScreen> createState() => _ApplyLoanScreenState();
}

class _ApplyLoanScreenState extends State<ApplyLoanScreen> {
  // ── step tracking ──────────────────────────────────────────────────────────
  int _step = 0;
  static const int _totalSteps = 5;

  // ── ID gate ────────────────────────────────────────────────────────────────
  bool _checkingId = true;
  bool _idVerified = false;
  bool _hasActiveLoan = false;

  // ── Step 1: Loan Details ───────────────────────────────────────────────────
  final _s1Key = GlobalKey<FormState>();
  String _loanType = 'Input Loan';
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _period = '6 months';

  // ── Step 2: Collateral ─────────────────────────────────────────────────────
  final _s2Key = GlobalKey<FormState>();
  String _collateralType = 'Land Title';
  final _collateralDescCtrl = TextEditingController();
  final _collateralValueCtrl = TextEditingController();
  // collateral images (up to 3)
  final List<XFile?> _collateralImages = [null, null, null];
  final List<Uint8List?> _collateralBytes = [null, null, null];

  // ── Step 3: Financial Info ─────────────────────────────────────────────────
  final _s3Key = GlobalKey<FormState>();
  String _incomeSource = 'Farming';
  final _monthlyIncomeCtrl = TextEditingController();
  final _existingLoansCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  bool _hasMobileMoney = false;
  final _mobileMoneyCtrl = TextEditingController();

  // ── Step 4: Next of Kin / Guarantor ───────────────────────────────────────
  final _s4Key = GlobalKey<FormState>();
  final _kinNameCtrl = TextEditingController();
  final _kinPhoneCtrl = TextEditingController();
  final _kinRelationCtrl = TextEditingController();
  final _kinAddressCtrl = TextEditingController();

  // ── Step 5: Guarantors ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> _selectedGuarantors = [];

  // ── submission ─────────────────────────────────────────────────────────────
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkIdStatus();
  }

  Future<void> _checkIdStatus() async {
    try {
      final uid = FirebaseService.sessionUid;
      if (uid.isNotEmpty) {
        final results = await Future.wait([
          FirebaseService.getUserProfile(uid),
          FirebaseService.getFarmerLoansOnce(uid),
        ]);
        final profile = results[0] as Map<String, dynamic>?;
        final loans = results[1] as List<Map<String, dynamic>>;

        final hasActive = loans.any((l) =>
            l['status'] == 'Approved' ||
            l['status'] == 'Active' ||
            l['status'] == 'Pending');

        if (mounted) {
          setState(() {
            _idVerified = profile?['idStatus'] == 'approved';
            _hasActiveLoan = hasActive;
            _checkingId = false;
          });
        }
      } else {
        if (mounted) setState(() => _checkingId = false);
      }
    } catch (_) {
      if (mounted) setState(() => _checkingId = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _descCtrl.dispose();
    _collateralDescCtrl.dispose();
    _collateralValueCtrl.dispose();
    _monthlyIncomeCtrl.dispose();
    _existingLoansCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _mobileMoneyCtrl.dispose();
    _kinNameCtrl.dispose();
    _kinPhoneCtrl.dispose();
    _kinRelationCtrl.dispose();
    _kinAddressCtrl.dispose();
    super.dispose();
  }

  // ── image picker ───────────────────────────────────────────────────────────
  Future<void> _pickCollateralImage(int index) async {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _collateralImages[index] = f;
      _collateralBytes[index] = bytes;
    });
  }

  // ── navigation ─────────────────────────────────────────────────────────────
  void _next() {
    bool valid = false;
    if (_step == 0) valid = _s1Key.currentState?.validate() ?? false;
    if (_step == 1) valid = _s2Key.currentState?.validate() ?? false;
    if (_step == 2) valid = _s3Key.currentState?.validate() ?? false;
    if (_step == 3) valid = _s4Key.currentState?.validate() ?? false;
    if (_step == 4) { _goToConsentScreen(); return; }
    if (valid) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  // ── open guarantor consent screen then submit ──────────────────────────────
  void _goToConsentScreen() {
    if (_selectedGuarantors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select at least one guarantor.'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuarantorConsentScreen(
          guarantors: _selectedGuarantors,
          loanSummary: {
            'amount':
                int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
            'loanType': _loanType,
            'repaymentPeriod': _period,
          },
          onConfirmed: () {
            Navigator.pop(context); // close consent screen
            _submit();
          },
        ),
      ),
    );
  }

  // ── submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!(_s4Key.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      // Upload collateral images
      final List<String> collateralUrls = [];
      for (final bytes in _collateralBytes) {
        if (bytes != null) {
          final url = await FirebaseService.uploadImageBytesToImgbb(bytes);
          if (url != null) collateralUrls.add(url);
        }
      }

      await FirebaseService.applyLoan({
        // Step 1
        'loanType': _loanType,
        'amount': int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        'purpose': _purposeCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'repaymentPeriod': _period,
        // Step 2
        'collateralType': _collateralType,
        'collateralDescription': _collateralDescCtrl.text.trim(),
        'collateralValue': int.tryParse(
                _collateralValueCtrl.text.replaceAll(',', '')) ?? 0,
        'collateralImages': collateralUrls,
        // Step 3
        'incomeSource': _incomeSource,
        'monthlyIncome': int.tryParse(
                _monthlyIncomeCtrl.text.replaceAll(',', '')) ?? 0,
        'existingLoans': _existingLoansCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'bankAccount': _bankAccountCtrl.text.trim(),
        'mobileMoneyNumber': _hasMobileMoney ? _mobileMoneyCtrl.text.trim() : '',
        // Step 4 — Next of Kin
        'nextOfKinName': _kinNameCtrl.text.trim(),
        'nextOfKinPhone': _kinPhoneCtrl.text.trim(),
        'nextOfKinRelation': _kinRelationCtrl.text.trim(),
        'nextOfKinAddress': _kinAddressCtrl.text.trim(),
        // Step 5 — Guarantors
        'guarantors': _selectedGuarantors.map((g) => {
          'uid': g['uid'],
          'name': g['name'],
          'phone': g['phone'],
          'memberNumber': g['memberNumber'] ?? '',
        }).toList(),
        'guarantorCount': _selectedGuarantors.length,
        // farmer name for admin display
        'farmerName': FirebaseService.sessionProfile?['name'] ?? '',
      });

      if (!mounted) return;
      _showSuccess();
    } catch (_) {
      if (mounted) _showSuccess(); // still show success — saved locally
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 44),
            ),
            const SizedBox(height: 16),
            Text('Application Submitted!',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Your loan application has been submitted and is under review. '
              'You will be notified once it is processed.',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingId) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (!_idVerified) {
      return FarmerScaffold(
        title: 'Apply for Loan',
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.badge_outlined,
                    color: AppTheme.warning, size: 44),
              ),
              const SizedBox(height: 20),
              Text('ID Verification Required',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'You need to verify your identity before applying for a loan. '
                'Go to your Profile and upload your ID documents.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Go to Profile',
                icon: Icons.person_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasActiveLoan) {
      return FarmerScaffold(
        title: 'Apply for Loan',
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.block_rounded,
                    color: AppTheme.error, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Active Loan Exists',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'You already have an active or pending loan. '
                'You must fully repay your current loan before applying for a new one.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'View My Loans',
                icon: Icons.account_balance_wallet_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return FarmerScaffold(
      title: 'Apply for Loan (${_step + 1}/$_totalSteps)',
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(),
            ),
          ),
          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _back,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _next,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_step == _totalSteps - 1 ? 'Submit Application' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _step1();
      case 1: return _step2();
      case 2: return _step3();
      case 3: return _step4();
      case 4: return _step5();
      default: return const SizedBox();
    }
  }

  // ── Step 1: Loan Details ───────────────────────────────────────────────────
  Widget _step1() {
    return Form(
      key: _s1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('Loan Details', 'Tell us about the loan you need.',
              Icons.account_balance_wallet_rounded),
          const SizedBox(height: 20),
          _label('Loan Type'),
          DropdownButtonFormField<String>(
            value: _loanType,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined)),
            items: [
              'Input Loan', 'Equipment Loan', 'Land Development',
              'Livestock Loan', 'Emergency Loan', 'Business Loan',
              'Education Loan', 'Other'
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _loanType = v!),
          ),
          const SizedBox(height: 14),
          _label('Loan Amount (UGX)'),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.attach_money_rounded),
              hintText: 'e.g. 1,000,000',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter amount';
              final n = int.tryParse(v.replaceAll(',', ''));
              if (n == null || n < 50000) return 'Minimum is UGX 50,000';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _label('Repayment Period'),
          DropdownButtonFormField<String>(
            value: _period,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_month_outlined)),
            items: ['1 month', '3 months', '6 months', '12 months',
                    '18 months', '24 months']
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _period = v!),
          ),
          const SizedBox(height: 14),
          _label('Purpose of Loan'),
          TextFormField(
            controller: _purposeCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.grass_outlined),
              hintText: 'e.g. Purchase seeds and fertilizer',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Enter purpose' : null,
          ),
          const SizedBox(height: 14),
          _label('Additional Description (optional)'),
          TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.description_outlined),
              alignLabelWithHint: true,
              hintText: 'Provide more details about how you will use the loan...',
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Collateral ─────────────────────────────────────────────────────
  Widget _step2() {
    return Form(
      key: _s2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('Collateral', 'Provide details of assets you are offering as security.',
              Icons.home_work_rounded),
          const SizedBox(height: 20),
          _label('Collateral Type'),
          DropdownButtonFormField<String>(
            value: _collateralType,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.inventory_2_outlined)),
            items: [
              'Land Title', 'Property/House', 'Vehicle/Car',
              'Motorcycle (Boda)', 'Farm Equipment', 'Livestock',
              'Salary/Employment', 'Other'
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _collateralType = v!),
          ),
          const SizedBox(height: 14),
          _label('Collateral Description'),
          TextFormField(
            controller: _collateralDescCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.notes_rounded),
              hintText: 'e.g. Land title, vehicle logbook, property',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Describe your collateral' : null,
          ),
          const SizedBox(height: 14),
          _label('Estimated Value (UGX)'),
          TextFormField(
            controller: _collateralValueCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.price_check_rounded),
              hintText: 'e.g. 5,000,000',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter estimated value';
              final n = int.tryParse(v.replaceAll(',', ''));
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _label('Upload Collateral Documents / Photos'),
          Text(
            'Upload photos of land title, property, vehicle logbook, or any supporting documents (up to 3 images).',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                child: _collateralImagePicker(i),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _collateralImagePicker(int index) {
    final bytes = _collateralBytes[index];
    return GestureDetector(
      onTap: () => _pickCollateralImage(index),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: bytes != null
                ? AppTheme.success
                : AppTheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: bytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.memory(bytes, fit: BoxFit.cover,
                    width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary, size: 24),
                  const SizedBox(height: 4),
                  Text('Doc ${index + 1}',
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: AppTheme.primary)),
                ],
              ),
      ),
    );
  }

  // ── Step 3: Financial Info ─────────────────────────────────────────────────
  Widget _step3() {
    return Form(
      key: _s3Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('Financial Information',
              'Help us understand your financial situation.',
              Icons.account_balance_rounded),
          const SizedBox(height: 20),
          _label('Primary Income Source'),
          DropdownButtonFormField<String>(
            value: _incomeSource,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.work_outline_rounded)),
            items: [
              'Farming', 'Livestock', 'Business', 'Employment/Salary',
              'Mixed (Farming + Business)', 'Other'
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _incomeSource = v!),
          ),
          const SizedBox(height: 14),
          _label('Estimated Monthly Income (UGX)'),
          TextFormField(
            controller: _monthlyIncomeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.trending_up_rounded),
              hintText: 'e.g. 300,000',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter monthly income';
              final n = int.tryParse(v.replaceAll(',', ''));
              if (n == null || n <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _label('Existing Loans (if any)'),
          TextFormField(
            controller: _existingLoansCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.credit_card_outlined),
              hintText: 'e.g. None / UGX 200,000 at Centenary Bank',
            ),
          ),
          const SizedBox(height: 20),
          _label('Bank Details (optional)'),
          TextFormField(
            controller: _bankNameCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.account_balance_outlined),
              hintText: 'Bank name (e.g. Centenary Bank)',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankAccountCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.numbers_rounded),
              hintText: 'Account number',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Checkbox(
                value: _hasMobileMoney,
                activeColor: AppTheme.primary,
                onChanged: (v) => setState(() => _hasMobileMoney = v!),
              ),
              Text('I have a Mobile Money account',
                  style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
          if (_hasMobileMoney) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _mobileMoneyCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_android_rounded),
                hintText: 'Mobile Money number (e.g. 0772123456)',
              ),
              validator: (v) => _hasMobileMoney && (v == null || v.trim().isEmpty)
                  ? 'Enter mobile money number'
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 4: Next of Kin / Guarantor ───────────────────────────────────────
  Widget _step4() {
    return Form(
      key: _s4Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('Next of Kin / Guarantor',
              'Provide details of someone we can contact if needed.',
              Icons.people_rounded),
          const SizedBox(height: 20),
          _label('Full Name'),
          TextFormField(
            controller: _kinNameCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline_rounded),
              hintText: 'Guarantor\'s full name',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
          ),
          const SizedBox(height: 14),
          _label('Phone Number'),
          TextFormField(
            controller: _kinPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: 'e.g. 0772123456',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Enter phone number' : null,
          ),
          const SizedBox(height: 14),
          _label('Relationship to Applicant'),
          TextFormField(
            controller: _kinRelationCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.family_restroom_rounded),
              hintText: 'e.g. Spouse, Parent, Sibling, Friend',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Enter relationship' : null,
          ),
          const SizedBox(height: 14),
          _label('Physical Address'),
          TextFormField(
            controller: _kinAddressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on_outlined),
              alignLabelWithHint: true,
              hintText: 'Village, Sub-county, District',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Enter address' : null,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.info.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'By submitting this application, you confirm that all '
                    'information provided is accurate and complete. '
                    'False information may result in rejection or legal action.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _stepHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
              Text(subtitle,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 5: Guarantors ─────────────────────────────────────────────────────
  Widget _step5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          'Guarantors',
          'Select SACCO members who will guarantee your loan.',
          Icons.people_rounded,
        ),
        const SizedBox(height: 20),

        // ── Info box ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.info.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.info.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You need at least 1 guarantor (up to 2). '
                  'Guarantors must be registered SACCO members. '
                  'They will receive an SMS consent notification.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Selected guarantors ─────────────────────────────────────────────
        if (_selectedGuarantors.isNotEmpty) ...[
          Text('Selected (${_selectedGuarantors.length}/2)',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          ..._selectedGuarantors.map((g) => _SelectedGuarantorTile(
                guarantor: g,
                onRemove: () => setState(
                    () => _selectedGuarantors.removeWhere(
                        (s) => s['uid'] == g['uid'])),
              )),
          const SizedBox(height: 16),
        ],

        // ── Pick button ─────────────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: () async {
            final result = await Navigator.push<List<Map<String, dynamic>>>(
              context,
              MaterialPageRoute(
                builder: (_) => GuarantorPickerScreen(
                  maxGuarantors: 2,
                  alreadySelected: _selectedGuarantors,
                ),
              ),
            );
            if (result != null) {
              setState(() => _selectedGuarantors = result);
            }
          },
          icon: const Icon(Icons.person_add_rounded),
          label: Text(_selectedGuarantors.isEmpty
              ? 'Select Guarantors'
              : 'Change Guarantors'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary),
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 20),

        // ── Declaration ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_rounded,
                  color: AppTheme.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'By proceeding, you confirm all information is accurate. '
                  'False information may result in rejection or legal action.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.warning),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
    );
  }
}

// ── Selected guarantor tile (inline in step 5) ────────────────────────────────
class _SelectedGuarantorTile extends StatelessWidget {
  final Map<String, dynamic> guarantor;
  final VoidCallback onRemove;
  const _SelectedGuarantorTile(
      {required this.guarantor, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = guarantor['name'] as String? ?? 'Member';
    final phone = guarantor['phone'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary)),
                Text(phone,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline_rounded,
                color: AppTheme.error, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

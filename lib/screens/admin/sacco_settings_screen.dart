import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/audit_service.dart';
import '../../core/sacco_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class SaccoSettingsScreen extends StatefulWidget {
  const SaccoSettingsScreen({super.key});
  @override
  State<SaccoSettingsScreen> createState() => _SaccoSettingsScreenState();
}

class _SaccoSettingsScreenState extends State<SaccoSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  bool _saving  = false;

  // SACCO Info
  final _nameCtrl        = TextEditingController();
  final _taglineCtrl     = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _regNoCtrl       = TextEditingController();

  // Loan Settings
  final _minLoanCtrl     = TextEditingController();
  final _maxLoanCtrl     = TextEditingController();
  final _loanRateCtrl    = TextEditingController();
  final _penaltyRateCtrl = TextEditingController();

  // Savings Settings
  final _minSavingsCtrl  = TextEditingController();
  final _savingsRateCtrl = TextEditingController();

  // Share Settings
  final _shareValueCtrl  = TextEditingController();
  final _minSharesCtrl   = TextEditingController();

  // Bank Account Settings
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankBranchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _taglineCtrl, _emailCtrl, _phoneCtrl, _addressCtrl, _regNoCtrl,
      _minLoanCtrl, _maxLoanCtrl, _loanRateCtrl, _penaltyRateCtrl,
      _minSavingsCtrl, _savingsRateCtrl, _shareValueCtrl, _minSharesCtrl,
      _bankNameCtrl, _bankAccountNameCtrl, _bankAccountNumberCtrl, _bankBranchCtrl,
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Load from the current SACCO's tenantId doc (not the legacy 'config' doc)
    final docId = SaccoService.tenantId;
    try {
      final doc = await _db.collection(AppConstants.saccoCol).doc(docId).get();
      if (!mounted) return;
      // Fall back to legacy 'config' doc for existing single-SACCO setups
      final d = doc.exists
          ? doc.data()!
          : (await _db.collection(AppConstants.saccoCol).doc('config').get()).data() ?? {};
      if (!mounted) return;
      if (d.isNotEmpty) {
        _nameCtrl.text        = d['saccoName']   ?? d['name']        ?? AppConstants.appName;
        _taglineCtrl.text     = d['tagline']      ?? AppConstants.appTagline;
        _emailCtrl.text       = d['email']        ?? AppConstants.companyEmail;
        _phoneCtrl.text       = d['phone']        ?? AppConstants.companyContact;
        _addressCtrl.text     = d['address']      ?? AppConstants.companyCity;
        _regNoCtrl.text       = d['registrationNo'] ?? d['regNo'] ?? '';
        _minLoanCtrl.text     = '${d['minLoan']   ?? 50000}';
        _maxLoanCtrl.text     = '${d['maxLoan']   ?? 10000000}';
        _loanRateCtrl.text    = '${d['loanRate']  ?? 18}';
        _penaltyRateCtrl.text = '${d['penaltyRate'] ?? 5}';
        _minSavingsCtrl.text  = '${d['minSavings'] ?? 10000}';
        _savingsRateCtrl.text = '${d['savingsRate'] ?? 8}';
        _shareValueCtrl.text  = '${d['shareValue']  ?? 1000}';
        _minSharesCtrl.text   = '${d['minShares']   ?? 1}';
        _bankNameCtrl.text = d['bankName'] ?? '';
        _bankAccountNameCtrl.text = d['bankAccountName'] ?? '';
        _bankAccountNumberCtrl.text = d['bankAccountNumber'] ?? '';
        _bankBranchCtrl.text = d['bankBranch'] ?? '';
      } else {
        _setDefaults();
      }
    } catch (_) {
      if (!mounted) return;
      _setDefaults();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _setDefaults() {
    _nameCtrl.text        = AppConstants.appName;
    _taglineCtrl.text     = AppConstants.appTagline;
    _emailCtrl.text       = AppConstants.companyEmail;
    _phoneCtrl.text       = AppConstants.companyContact;
    _addressCtrl.text     = AppConstants.companyCity;
    _minLoanCtrl.text     = '50000';
    _maxLoanCtrl.text     = '10000000';
    _loanRateCtrl.text    = '18';
    _penaltyRateCtrl.text = '5';
    _minSavingsCtrl.text  = '10000';
    _savingsRateCtrl.text = '8';
    _shareValueCtrl.text  = '1000';
    _minSharesCtrl.text   = '1';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Write to the current SACCO's tenantId doc — not 'config'
    final docId = SaccoService.tenantId;
    try {
      await _db.collection(AppConstants.saccoCol).doc(docId).set({
        'tenantId':    docId,
        'saccoName':   _nameCtrl.text.trim(),
        'tagline':     _taglineCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'phone':       _phoneCtrl.text.trim(),
        'address':     _addressCtrl.text.trim(),
        'registrationNo': _regNoCtrl.text.trim(),
        'minLoan':     int.tryParse(_minLoanCtrl.text)     ?? 50000,
        'maxLoan':     int.tryParse(_maxLoanCtrl.text)     ?? 10000000,
        'loanRate':    double.tryParse(_loanRateCtrl.text) ?? 18.0,
        'penaltyRate': double.tryParse(_penaltyRateCtrl.text) ?? 5.0,
        'minSavings':  int.tryParse(_minSavingsCtrl.text)  ?? 10000,
        'savingsRate': double.tryParse(_savingsRateCtrl.text) ?? 8.0,
        'shareValue':  int.tryParse(_shareValueCtrl.text)  ?? 1000,
        'minShares':   int.tryParse(_minSharesCtrl.text)   ?? 1,
        'bankName': _bankNameCtrl.text.trim(),
        'bankAccountName': _bankAccountNameCtrl.text.trim(),
        'bankAccountNumber': _bankAccountNumberCtrl.text.trim(),
        'bankBranch': _bankBranchCtrl.text.trim(),
        'updatedAt':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // Reload SaccoService so branding updates live
      await SaccoService.loadById(docId);
      AuditService.log(
        action: 'SACCO_SETTINGS_UPDATED',
        description: 'SACCO configuration updated by admin',
      );
      _snack('Settings saved successfully.', AppTheme.success);
    } catch (e) {
      _snack('Error saving: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _saving = false);
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
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('SACCO Settings', style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        )),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
              label: Text('Save', style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [

                _section('SACCO Information'),
                _field(_nameCtrl,    'SACCO Name',           Icons.business_rounded),
                _field(_taglineCtrl, 'Tagline / Motto',      Icons.format_quote_rounded),
                _field(_emailCtrl,   'Email Address',        Icons.email_outlined, type: TextInputType.emailAddress),
                _field(_phoneCtrl,   'Phone Number',         Icons.phone_rounded,  type: TextInputType.phone),
                _field(_addressCtrl, 'Physical Address',     Icons.location_on_outlined),
                _field(_regNoCtrl,   'Registration Number',  Icons.badge_outlined),

                const SizedBox(height: 8),
                _section('Loan Settings'),
                _numField(_minLoanCtrl,     'Minimum Loan Amount (UGX)',  Icons.arrow_downward_rounded),
                _numField(_maxLoanCtrl,     'Maximum Loan Amount (UGX)',  Icons.arrow_upward_rounded),
                _numField(_loanRateCtrl,    'Annual Interest Rate (%)',   Icons.percent_rounded, isDouble: true),
                _numField(_penaltyRateCtrl, 'Late Payment Penalty (%)',   Icons.warning_rounded, isDouble: true),

                const SizedBox(height: 8),
                _section('Savings Settings'),
                _numField(_minSavingsCtrl,  'Minimum Savings Deposit (UGX)', Icons.savings_rounded),
                _numField(_savingsRateCtrl, 'Savings Interest Rate (% p.a.)', Icons.percent_rounded, isDouble: true),

                const SizedBox(height: 8),
                _section('Share Settings'),
                _numField(_shareValueCtrl, 'Share Value (UGX per share)', Icons.price_change_rounded),
                _numField(_minSharesCtrl,  'Minimum Shares per Member',   Icons.confirmation_number_rounded),

                const SizedBox(height: 8),
                _section('Bank Account Configuration'),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Configure SACCO bank account for receiving teller transfers',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                _field(_bankNameCtrl, 'Bank Name', Icons.account_balance),
                _field(_bankAccountNameCtrl, 'Account Name', Icons.person_outline),
                _field(_bankAccountNumberCtrl, 'Account Number', Icons.numbers),
                _field(_bankBranchCtrl, 'Branch (Optional)', Icons.location_on_outlined),

                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Save All Settings',
                  loading: _saving,
                  onPressed: _save,
                  icon: Icons.save_rounded,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 8),
    child: Text(title,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: AppTheme.primary, letterSpacing: 0.5)),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
        ),
      );

  Widget _numField(TextEditingController ctrl, String label, IconData icon,
      {bool isDouble = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: isDouble
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: isDouble
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
          ),
        ),
      );
}

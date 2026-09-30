import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/constants.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';

// Bank transfer functionality for Uganda - integrated with bank APIs.
// This screen operates on the user's wallet balance only.

// ── Module-level cache so banks only load once per app session ────────────────
List<Map<String, dynamic>>? _cachedBanks;
Map<String, dynamic>? _cachedSettings;

class BankTransferScreen extends StatefulWidget {
  const BankTransferScreen({super.key});

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  final fmt = NumberFormat('#,###', 'en_US');
  final _accountCtrl     = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _amountCtrl      = TextEditingController();
  final _descCtrl        = TextEditingController();

  bool _loading    = _cachedBanks == null; // skip loading if cached
  bool _validating = false;
  bool _processing = false;

  List<Map<String, dynamic>> _banks    = _cachedBanks ?? [];
  Map<String, dynamic>?      _settings = _cachedSettings;
  String?                    _selectedBank;
  Map<String, dynamic>?      _validated;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    if (_loading) _loadData();
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _accountNameCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Parallel fetch — much faster than sequential
      final results = await Future.wait([
        FirebaseService.getBankList(),
        FirebaseService.getBankTransferSettings(),
      ]);
      if (!mounted) return;
      _cachedBanks    = results[0] as List<Map<String, dynamic>>;
      _cachedSettings = results[1] as Map<String, dynamic>;
      setState(() {
        _banks    = _cachedBanks!;
        _settings = _cachedSettings;
        _loading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Could not load banks: $e', AppTheme.error);
    }
  }

  Future<void> _validateAccount() async {
    if (_selectedBank == null || _accountCtrl.text.trim().isEmpty) {
      _snack('Select a bank and enter account number first', AppTheme.warning);
      return;
    }
    setState(() => _validating = true);
    try {
      final r = await FirebaseService.validateBankAccount(
        bankName: _selectedBank!,
        accountNumber: _accountCtrl.text.trim(),
      );
      if (!mounted) return;
      if (r['valid'] == true && (r['account_name'] as String? ?? '').isNotEmpty) {
        setState(() {
          _validated = r;
          _accountNameCtrl.text = r['account_name'] as String;
        });
      } else {
        _snack('Could not verify account name — you can still proceed', AppTheme.warning);
      }
    } catch (_) {
      if (mounted) _snack('Verification unavailable — you can still proceed', AppTheme.warning);
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    final minAmount = _minAmount;

    if (_selectedBank == null) { _snack('Select a bank', AppTheme.warning); return; }
    if (_accountCtrl.text.trim().isEmpty) { _snack('Enter account number', AppTheme.warning); return; }
    if (amount == null || amount < minAmount) {
      _snack('Minimum transfer is UGX ${fmt.format(minAmount)}', AppTheme.warning);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) { _snack('Enter a description', AppTheme.warning); return; }

    if (_validated == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Account Not Verified',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Text('We couldn\'t verify the account name. Continue anyway?',
              style: GoogleFonts.poppins(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text('Continue', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _processing = true);
    try {
      final result = await FirebaseService.createBankTransfer(
        amount: amount,
        description: _descCtrl.text.trim(),
        bankName: _selectedBank!,
        bankAccountNumber: _accountCtrl.text.trim(),
        bankAccountName: _accountNameCtrl.text.trim().isNotEmpty
            ? _accountNameCtrl.text.trim()
            : null,
        walletSource: 'main',
      );
      if (!mounted) return;
      final status = result['status'] as String? ?? '';
      if (status == 'processing' || status == 'completed') {
        _showSuccess(result);
        _clearForm();
      } else {
        _showErrorSheet(_friendlyError('Transfer failed with status: $status'));
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceAll('Exception: ', '');
      _showErrorSheet(_friendlyError(raw));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Convert raw error messages into human-friendly text
  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient') || lower.contains('balance')) {
      // Extract amounts if present
      final availMatch = RegExp(r'available[:\s]+ugx\s*([\d,]+)', caseSensitive: false).firstMatch(raw);
      final reqMatch   = RegExp(r'required[:\s]+ugx\s*([\d,]+)', caseSensitive: false).firstMatch(raw);
      if (availMatch != null && reqMatch != null) {
        return 'You don\'t have enough balance for this transfer.\n\n'
            'Your balance: UGX ${availMatch.group(1)}\n'
            'Amount needed: UGX ${reqMatch.group(1)}\n\n'
            'Please deposit more funds and try again.';
      }
      return 'Insufficient balance.\n\nPlease top up your wallet and try again.';
    }
    if (lower.contains('invalid') && lower.contains('account')) {
      return 'The bank account number is invalid.\n\nPlease check the account number and try again.';
    }
    if (lower.contains('bank') && lower.contains('not found')) {
      return 'Bank not found. Please select a valid bank from the list.';
    }
    if (lower.contains('timeout') || lower.contains('network')) {
      return 'Network timeout. Please check your connection and try again.';
    }
    if (lower.contains('duplicate') || lower.contains('already')) {
      return 'This transfer was already processed. Check your transaction history.';
    }
    // Return cleaned-up version of the raw message
    return raw.isNotEmpty ? raw : 'Transfer could not be completed. Please try again.';
  }

  void _showErrorSheet(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red top banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 10),
                    Text('Transfer Failed',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              // Message body
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    Text(message,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            height: 1.6),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('OK, Got It',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w700)),
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

  void _clearForm() {
    _accountCtrl.clear();
    _accountNameCtrl.clear();
    _amountCtrl.clear();
    _descCtrl.clear();
    setState(() { _selectedBank = null; _validated = null; });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccess(Map<String, dynamic> result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Transfer Initiated!',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'UGX ${fmt.format(result['amount'])} → ${result['accountName'] ?? result['accountNumber']}',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _row('Bank', result['bankName'] ?? '—'),
                  const SizedBox(height: 6),
                  _row('Account', result['accountNumber'] ?? '—'),
                  const SizedBox(height: 6),
                  _row('Charge', 'UGX ${fmt.format(result['charge'] ?? 0)}'),
                  const SizedBox(height: 6),
                  _row('Total', 'UGX ${fmt.format(result['total'] ?? 0)}',
                      bold: true),
                  const SizedBox(height: 6),
                  _row('Reference',
                      (result['reference'] as String? ?? '—').length > 16
                          ? '${(result['reference'] as String).substring(0, 16)}…'
                          : result['reference'] ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Done',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _minAmount {
    final raw = _settings?['bank_transfer_settings']?['minimum_transfer_amount'];
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw.replaceAll('.00', '')) ?? AppConstants.bankTransferMinAmount;
    return AppConstants.bankTransferMinAmount;
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return FarmerScaffold(
        title: 'Bank Transfer',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('Loading banks...',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    final available = _settings?['bank_transfer_available'] == true;
    if (!available) {
      return FarmerScaffold(
        title: 'Bank Transfer',
        body: const Center(
          child: EmptyState(
            message: 'Bank transfer is not available at the moment.',
            icon: Icons.account_balance_outlined,
          ),
        ),
      );
    }

    final hasAmount = _amount >= _minAmount;

    return FarmerScaffold(
      title: 'Bank Transfer',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () {
            _cachedBanks = null;
            _cachedSettings = null;
            setState(() => _loading = true);
            _loadData();
          },
          tooltip: 'Refresh',
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header info strip ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_rounded,
                      color: AppTheme.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Send directly to any bank account in Uganda. Min: UGX ${fmt.format(_minAmount)}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Bank selector ──────────────────────────────────────────────
            _label('Bank'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedBank != null
                      ? AppTheme.primary.withOpacity(0.4)
                      : Colors.grey.shade300,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBank,
                  hint: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('Select bank',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey.shade400)),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  borderRadius: BorderRadius.circular(12),
                  items: _banks.map((b) {
                    final name = b['name'] as String;
                    return DropdownMenuItem(
                      value: name,
                      child: Text(name,
                          style: GoogleFonts.poppins(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedBank = v;
                    _validated = null;
                  }),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Account number + verify ────────────────────────────────────
            _label('Account Number'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _accountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Enter account number',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade400),
                      ),
                      onChanged: (_) => setState(() => _validated = null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _validating ? null : _validateAccount,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: _validated != null
                          ? AppTheme.success
                          : AppTheme.info,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _validating
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _validated != null ? '✓ Verified' : 'Verify',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),

            // Verified name card
            if (_validated != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Verified',
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600)),
                          Text(_validated!['account_name'] ?? '',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Amount ────────────────────────────────────────────────────
            _label('Amount (UGX)'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasAmount
                      ? AppTheme.primary.withOpacity(0.4)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: hasAmount
                          ? AppTheme.primary.withOpacity(0.06)
                          : Colors.grey.shade50,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(11)),
                      border: Border(
                          right: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Text('UGX',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: hasAmount
                                ? AppTheme.primary
                                : Colors.grey.shade500)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: fmt.format(_minAmount),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────────────
            _label('Description'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _descCtrl,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Purpose of transfer',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade400),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Submit ────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Send to Bank',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
      );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});
  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen>
    with SingleTickerProviderStateMixin {
  final fmt = NumberFormat('#,###', 'en_US');
  late TabController _tabs;

  Map<String, dynamic> _summary = {
    'voluntary': 0,
    'compulsory': 0,
    'fixedDeposit': 0,
    'totalInterest': 0,
  };
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseService.sessionUid;
    if (uid.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final savingsAccount = await FirebaseService.getSavingsAccount(uid);
      final transactions = await FirebaseService.getSavingsTransactions(uid);

      int voluntary = savingsAccount?['voluntaryBalance'] ?? 0;
      int compulsory = savingsAccount?['compulsoryBalance'] ?? 0;
      int fixedDeposit = 0;
      int interest = 0;

      for (final t in transactions) {
        final type = t['savingsType'] as String? ?? '';
        final amount = (t['amount'] as num?)?.toInt() ?? 0;
        if (type == 'Interest') interest += amount;
      }

      if (!mounted) return;
      setState(() {
        _summary = {
          'voluntary': voluntary,
          'compulsory': compulsory,
          'fixedDeposit': fixedDeposit,
          'totalInterest': interest,
        };
        _transactions = transactions.map((d) {
          final ts = d['timestamp'] ?? d['createdAt'];
          String dateStr = '—';
          if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
          return {...d, 'dateStr': dateStr};
        }).toList();
        _loading = false;
      });
    } catch (e) {
      print('ERROR loading savings: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalSavings =>
      (_summary['voluntary'] as int) +
      (_summary['compulsory'] as int) +
      (_summary['fixedDeposit'] as int);

  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'My Savings',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _load,
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: AppTheme.accent,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Transactions'),
          Tab(text: 'Deposit'),
          Tab(text: 'Withdraw'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(summary: _summary, total: _totalSavings, fmt: fmt),
                _TransactionsTab(transactions: _transactions, fmt: fmt),
                _DepositTab(onDeposited: _load),
                _WithdrawTab(summary: _summary, onWithdrawn: _load),
              ],
            ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> summary;
  final int total;
  final NumberFormat fmt;
  const _OverviewTab({required this.summary, required this.total, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total savings hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4620F), Color(0xFFF47920)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF47920).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Total Savings',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                Text('UGX ${fmt.format(total)}',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Interest Earned: UGX ${fmt.format(summary['totalInterest'] as int)}',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Savings Breakdown',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),

          _SavingsTypeCard(
            label: 'Voluntary Savings',
            amount: summary['voluntary'] as int,
            icon: Icons.volunteer_activism_rounded,
            color: AppTheme.accent,
            fmt: fmt,
            description: 'Deposits made at your own discretion',
          ),
          const SizedBox(height: 10),
          _SavingsTypeCard(
            label: 'Compulsory Savings',
            amount: summary['compulsory'] as int,
            icon: Icons.lock_clock_rounded,
            color: AppTheme.primary,
            fmt: fmt,
            description: 'Mandatory monthly contributions',
          ),
          const SizedBox(height: 10),
          _SavingsTypeCard(
            label: 'Fixed Deposits',
            amount: summary['fixedDeposit'] as int,
            icon: Icons.account_balance_rounded,
            color: AppTheme.primaryLight,
            fmt: fmt,
            description: 'Term deposits earning higher interest',
          ),

          const SizedBox(height: 20),
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
                  'Use the Deposit and Withdraw tabs to manage your savings.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.info),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SavingsTypeCard extends StatelessWidget {
  final String label, description;
  final int amount;
  final IconData icon;
  final Color color;
  final NumberFormat fmt;
  const _SavingsTypeCard({
    required this.label, required this.amount, required this.icon,
    required this.color, required this.fmt, required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
          Text(description, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('UGX', style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
          Text(fmt.format(amount),
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ]),
      ]),
    );
  }
}

// ─── Transactions Tab ─────────────────────────────────────────────────────────
class _TransactionsTab extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final NumberFormat fmt;
  const _TransactionsTab({required this.transactions, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const EmptyState(
        message: 'No savings transactions yet.\nMake your first deposit to get started.',
        icon: Icons.savings_outlined,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final t = transactions[i];
        final type = t['savingsType'] as String? ?? 'Savings';
        final amount = (t['amount'] as num?)?.toInt() ?? 0;
        final date = t['dateStr'] as String? ?? '—';
        final isCredit = (t['txnType'] as String? ?? 'credit') == 'credit';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (isCredit ? AppTheme.success : AppTheme.error).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isCredit ? AppTheme.success : AppTheme.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(date, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            ])),
            Text(
              '${isCredit ? '+' : '-'} UGX ${fmt.format(amount)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isCredit ? AppTheme.success : AppTheme.error,
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Deposit Tab ──────────────────────────────────────────────────────────────
class _DepositTab extends StatefulWidget {
  final VoidCallback onDeposited;
  const _DepositTab({required this.onDeposited});
  @override
  State<_DepositTab> createState() => _DepositTabState();
}

class _DepositTabState extends State<_DepositTab> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final fmt = NumberFormat('#,###', 'en_US');
  String _savingsType = AppConstants.savingsVoluntary;
  bool _loading = false;
  bool _otpSent = false;
  bool _showPinOtp = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _pinCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final amount = int.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount < 1000) {
      _snack('Enter a valid amount (min UGX 1,000)', AppTheme.error);
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
    final amount = int.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    final pin = _pinCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (amount == null || amount < 1000) {
      _snack('Enter a valid amount (min UGX 1,000)', AppTheme.error);
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
      
      // Use the new secure backend method
      await FirebaseService.depositToSavings(
        uid: uid,
        amount: amount,
        savingsType: _savingsType,
        pin: pin,
        otpCode: otp,
        description: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      
      // Refresh the savings data to get updated balance
      widget.onDeposited();
      
      _snack('UGX ${fmt.format(amount)} deposited successfully! Check your updated balance above.', AppTheme.success);
      _amountCtrl.clear();
      _noteCtrl.clear();
      _pinCtrl.clear();
      _otpCtrl.clear();
      setState(() {
        _showPinOtp = false;
        _otpSent = false;
      });
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Savings Deposit',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Secure deposit with PIN + OTP verification. Amount will be deducted from your wallet.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),

          const SizedBox(height: 20),

          // Savings type
          Text('Savings Type', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          ...[ AppConstants.savingsVoluntary, AppConstants.savingsCompulsory ]
              .map((type) => GestureDetector(
                    onTap: () => setState(() => _savingsType = type),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _savingsType == type ? AppTheme.primary.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _savingsType == type ? AppTheme.primary : Colors.grey.shade200,
                          width: _savingsType == type ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _savingsType == type ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: _savingsType == type ? AppTheme.primary : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(type, style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: _savingsType == type ? FontWeight.w600 : FontWeight.w400,
                          color: _savingsType == type ? AppTheme.primary : AppTheme.textPrimary,
                        )),
                      ]),
                    ),
                  )),

          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Amount (UGX)',
              prefixIcon: Icon(Icons.attach_money_rounded),
              hintText: 'e.g. 50000',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
              hintText: 'e.g. Monthly contribution',
            ),
          ),

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
              label: 'Complete Deposit',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.savings_rounded,
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Withdraw Tab ─────────────────────────────────────────────────────────────
class _WithdrawTab extends StatefulWidget {
  final Map<String, dynamic> summary;
  final VoidCallback onWithdrawn;
  const _WithdrawTab({required this.summary, required this.onWithdrawn});
  @override
  State<_WithdrawTab> createState() => _WithdrawTabState();
}

class _WithdrawTabState extends State<_WithdrawTab> {
  final _amountCtrl = TextEditingController();
  final _pinCtrl    = TextEditingController();
  final _otpCtrl    = TextEditingController();
  final fmt = NumberFormat('#,###', 'en_US');

  String _savingsType  = AppConstants.savingsVoluntary;
  String _destination  = 'wallet'; // 'wallet' | 'mobile_money'
  bool   _loading      = false;
  bool   _showPinOtp   = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _pinCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0;
  int get _charge => (_amount * AppConstants.walletWithdrawChargePercent)
      .ceil()
      .clamp(AppConstants.walletMinCharge, 999999);
  int get _netAmount => _amount > 0 ? _amount - _charge : 0;

  int get _availableBalance {
    if (_savingsType == AppConstants.savingsVoluntary) {
      return (widget.summary['voluntary'] as int? ?? 0);
    }
    return (widget.summary['compulsory'] as int? ?? 0);
  }

  Future<void> _sendOTP() async {
    if (_amount < 1000) {
      _snack('Minimum withdrawal is UGX 1,000', AppTheme.error);
      return;
    }
    if (_amount > _availableBalance) {
      _snack('Amount exceeds your $_savingsType balance of UGX ${fmt.format(_availableBalance)}', AppTheme.error);
      return;
    }
    setState(() => _loading = true);
    try {
      final uid     = FirebaseService.sessionUid;
      final profile = await FirebaseService.getUserProfile(uid);
      final phone   = profile?['phone'] as String?;
      if (phone == null) {
        _snack('Phone number not found', AppTheme.error);
        return;
      }
      await FirebaseService.sendOtp(phone);
      setState(() => _showPinOtp = true);
      _snack('OTP sent to your phone', AppTheme.success);
    } catch (e) {
      _snack('Error: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (_amount < 1000) { _snack('Minimum withdrawal is UGX 1,000', AppTheme.error); return; }
    if (pin.length != 4) { _snack('Enter your 4-digit PIN', AppTheme.error); return; }
    if (otp.length != 6) { _snack('Enter the 6-digit OTP', AppTheme.error); return; }

    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      final result = await FirebaseService.withdrawFromSavings(
        uid: uid,
        amount: _amount,
        savingsType: _savingsType,
        pin: pin,
        otpCode: otp,
        destination: _destination,
      );

      final net    = result['netAmount'] as int;
      final charge = result['charge']    as int;
      final dest   = _destination == 'wallet' ? 'your wallet' : 'mobile money';

      widget.onWithdrawn();
      _snack('UGX ${fmt.format(net)} sent to $dest (charge: UGX ${fmt.format(charge)})', AppTheme.success);
      _amountCtrl.clear();
      _pinCtrl.clear();
      _otpCtrl.clear();
      setState(() => _showPinOtp = false);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Withdraw Savings',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Withdraw to your wallet or mobile money. A 12% service charge applies.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),

          // ── Savings type ──────────────────────────────────────────────────
          Text('Withdraw From', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          ...[AppConstants.savingsVoluntary, AppConstants.savingsCompulsory].map((type) {
            final bal = type == AppConstants.savingsVoluntary
                ? (widget.summary['voluntary'] as int? ?? 0)
                : (widget.summary['compulsory'] as int? ?? 0);
            final selected = _savingsType == type;
            return GestureDetector(
              onTap: () => setState(() => _savingsType = type),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.error.withOpacity(0.06) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppTheme.error : Colors.grey.shade200,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? AppTheme.error : Colors.grey, size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(type, style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppTheme.error : AppTheme.textPrimary,
                  ))),
                  Text('UGX ${fmt.format(bal)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700,
                          color: selected ? AppTheme.error : AppTheme.textSecondary)),
                ]),
              ),
            );
          }),

          const SizedBox(height: 20),

          // ── Destination ───────────────────────────────────────────────────
          Text('Send To', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DestCard(
              label: 'My Wallet',
              icon: Icons.account_balance_wallet_rounded,
              color: AppTheme.primary,
              selected: _destination == 'wallet',
              onTap: () => setState(() => _destination = 'wallet'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _DestCard(
              label: 'Mobile Money',
              icon: Icons.phone_android_rounded,
              color: AppTheme.accent,
              selected: _destination == 'mobile_money',
              onTap: () => setState(() => _destination = 'mobile_money'),
            )),
          ]),

          const SizedBox(height: 20),

          // ── Amount ────────────────────────────────────────────────────────
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Amount (UGX)',
              prefixIcon: const Icon(Icons.attach_money_rounded),
              hintText: 'e.g. 50,000',
              helperText: 'Available: UGX ${fmt.format(_availableBalance)}',
            ),
          ),

          // ── Charge preview ────────────────────────────────────────────────
          if (_amount >= 1000) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
              ),
              child: Column(children: [
                _ChargeRow('Withdrawal amount', 'UGX ${fmt.format(_amount)}'),
                const SizedBox(height: 6),
                _ChargeRow('Service charge (12%)', '- UGX ${fmt.format(_charge)}',
                    valueColor: AppTheme.error),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                _ChargeRow('You receive', 'UGX ${fmt.format(_netAmount)}',
                    bold: true, valueColor: AppTheme.success),
              ]),
            ),
          ],

          // ── PIN + OTP ─────────────────────────────────────────────────────
          if (_showPinOtp) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              ]),
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
              label: 'Complete Withdrawal',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.arrow_upward_rounded,
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _DestCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _DestCard({required this.label, required this.icon, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : Colors.grey.shade400, size: 26),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? color : AppTheme.textSecondary,
          )),
        ]),
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold;
  const _ChargeRow(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
      Text(value, style: GoogleFonts.poppins(
        fontSize: bold ? 14 : 12,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
        color: valueColor ?? AppTheme.textPrimary,
      )),
    ]);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'transaction_history_screen.dart';
import 'modern_deposit_modal.dart';
import 'modern_send_money_modal.dart';
import 'modern_withdraw_modal.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final fmt = NumberFormat('#,###', 'en_US');
  Map<String, dynamic> _wallet = {'balance': 0, 'totalDeposited': 0, 'totalWithdrawn': 0};
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  bool _balanceHidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseService.sessionUid;
    if (uid.isEmpty) return;
    try {
      // SACCO WALLET = SAVINGS ACCOUNT
      // Wallet and Savings are the same in a SACCO - show savings data here
      final results = await Future.wait([
        FirebaseService.getSavingsAccount(uid),
        FirebaseService.getSavingsTransactions(uid),
      ]);
      if (!mounted) return;
      
      final savingsAccount = results[0] as Map<String, dynamic>?;
      final savingsTxns = results[1] as List<Map<String, dynamic>>;
      
      // Calculate total savings balance (voluntary + compulsory)
      final voluntary = (savingsAccount?['voluntaryBalance'] as num?)?.toInt() ?? 0;
      final compulsory = (savingsAccount?['compulsoryBalance'] as num?)?.toInt() ?? 0;
      final totalBalance = voluntary + compulsory;
      
      // Calculate total deposited and withdrawn from transactions
      int totalDeposited = 0;
      int totalWithdrawn = 0;
      for (final txn in savingsTxns) {
        final type = (txn['type'] as String?)?.toLowerCase() ?? '';
        final amount = (txn['amount'] as num?)?.toInt() ?? 0;
        if (type == 'deposit') {
          totalDeposited += amount;
        } else if (type == 'withdrawal' || type == 'withdraw') {
          totalWithdrawn += amount;
        }
      }
      
      setState(() {
        _wallet = {
          'balance': totalBalance,
          'totalDeposited': totalDeposited,
          'totalWithdrawn': totalWithdrawn,
        };
        _transactions = savingsTxns.map((d) {
          final ts = d['createdAt'] ?? d['timestamp'];
          String dateStr = '—';
          if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy HH:mm').format(ts.toDate());
          return {...d, 'dateStr': dateStr};
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _balance => (_wallet['balance'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Wallet',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF0D47A1).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Wallet Balance',
                                style: GoogleFonts.poppins(
                                    color: Colors.white60, fontSize: 13)),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: Colors.white70, size: 13),
                                        const SizedBox(width: 4),
                                        Text(_balanceHidden ? 'Show' : 'Hide',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _balanceHidden ? '••••••••' : 'UGX ${fmt.format(_balance)}',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                        const SizedBox(height: 14),
                        if (!_balanceHidden) ...[
                          Container(
                            height: 1,
                            color: Colors.white.withOpacity(0.1),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _miniStat(Icons.south_rounded, 'Deposited',
                                  (_wallet['totalDeposited'] as num?)?.toInt() ?? 0),
                              const SizedBox(width: 20),
                              _miniStat(Icons.north_rounded, 'Withdrawn',
                                  (_wallet['totalWithdrawn'] as num?)?.toInt() ?? 0),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Action buttons — modern pill cards ──────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.add_rounded,
                            label: 'Deposit',
                            iconBg: const Color(0xFF00897B),
                            onTap: () => _showDeposit(context),
                          ),
                        ),
                        _vertDivider(),
                        Expanded(
                          child: _actionButton(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Withdraw',
                            iconBg: const Color(0xFFE53935),
                            onTap: () => _showWithdraw(context),
                          ),
                        ),
                        _vertDivider(),
                        Expanded(
                          child: _actionButton(
                            icon: Icons.send_rounded,
                            label: 'Send',
                            iconBg: const Color(0xFF5E35B1),
                            onTap: () => _showSendMoney(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SectionHeader(title: 'Recent Transactions'),
                      if (_transactions.length > 3)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionHistoryScreen(),
                            ),
                          ),
                          child: Text('View All',
                              style: GoogleFonts.poppins(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_transactions.isEmpty)
                    const EmptyState(
                        message: 'No transactions yet.\nDeposit money to get started.',
                        icon: Icons.account_balance_wallet_outlined)
                  else
                    ..._transactions.take(3).map((t) => GestureDetector(
                        onTap: () => _showTransactionDetail(t),
                        child: _TransactionTile(txn: t, fmt: fmt),
                      )),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _miniStat(IconData icon, String label, int value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 5),
        Text('$label: ${fmt.format(value)}',
            style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.85), fontSize: 11)),
      ],
    );
  }

  Widget _vertDivider() => Container(
        height: 40,
        width: 1,
        color: Colors.grey.shade100,
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconBg, size: 22),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeposit(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ModernDepositModal(onSuccess: _load),
    );
  }

  void _showWithdraw(BuildContext context) async {
    final profile = FirebaseService.sessionProfile;
    final registeredPhone = profile?['phone'] as String? ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,   // prevent accidental swipe-away mid-flow
      enableDrag: false,
      builder: (_) => ModernWithdrawModal(
        balance: _balance,
        registeredPhone: registeredPhone,
        onSuccess: _load,
      ),
    );
  }

  void _showSendMoney(BuildContext context) async {
    final profile = FirebaseService.sessionProfile;
    final registeredPhone = profile?['phone'] as String? ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => ModernSendMoneyModal(
        balance: _balance,
        registeredPhone: registeredPhone,
        onSuccess: _load,
      ),
    );
  }

  Future<bool> _showOtpDialog(BuildContext context, String phone) async {
    final otpCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Icon(Icons.security_rounded, color: AppTheme.primary, size: 22),
          const SizedBox(width: 8),
          Text('Security Verification',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A 6-digit code has been sent to your registered number:\n$phone\n\nEnter it below to authorize this withdrawal.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins(color: AppTheme.error))),
          ElevatedButton(
            onPressed: () {
              final code = otpCtrl.text.trim();
              final ok = FirebaseService.verifyEgoOtp(phone, code);
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invalid or expired code. Try again.',
                        style: GoogleFonts.poppins()),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('Verify', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(message,
                style: GoogleFonts.poppins(fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(Map<String, dynamic> t) {
    final type = t['type'] as String?;
    final isDeposit = type == 'deposit';
    final amount = (t['amount'] as num?)?.toInt() ?? 0;
    final status = t['status'] as String? ?? 'pending';
    final provider = t['provider'] as String?;
    final providerLabel = provider == 'mtn'
        ? 'MTN Mobile Money'
        : provider == 'airtel'
            ? 'Airtel Money'
            : provider ?? '—';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: (isDeposit ? AppTheme.success : AppTheme.error)
                        .withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(
                  isDeposit
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: isDeposit ? AppTheme.success : AppTheme.error,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isDeposit ? 'Deposit' : 'Withdrawal',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                Text(t['dateStr'] ?? '—',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 16),
            Center(
              child: Text('UGX ${fmt.format(amount)}',
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDeposit ? AppTheme.success : AppTheme.error)),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _txnDetailRow('Type', isDeposit ? 'Deposit' : 'Withdrawal'),
            _txnDetailRow('Status', status.toUpperCase()),
            _txnDetailRow('Network', providerLabel),
            _txnDetailRow('Phone', t['phone'] ?? '—'),
            if ((t['marzUuid'] as String?)?.isNotEmpty == true)
              _txnDetailRow('Transaction ID', t['marzUuid'] as String),
            if ((t['marzReference'] as String?)?.isNotEmpty == true)
              _txnDetailRow('Reference', t['marzReference'] as String),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Show receipt
                  final profile = FirebaseService.sessionProfile;
                  final name = profile?['name'] as String? ?? 'Member';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _WalletReceiptScreen(
                        txn: t,
                        farmerName: name,
                        fmt: fmt,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text('View Receipt',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txnDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      duration: const Duration(seconds: 4),
    ));
  }

  void _showErrorDialog(String title, String message, {IconData icon = Icons.error_rounded, Color color = AppTheme.error}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('OK',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> txn;
  final NumberFormat fmt;
  const _TransactionTile({required this.txn, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final type = txn['type'] as String?;
    final isDeposit = type == 'deposit';
    final amount = (txn['amount'] as num?)?.toInt() ?? 0;
    final status = txn['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: (isDeposit ? AppTheme.success : AppTheme.error)
                .withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (isDeposit ? AppTheme.success : AppTheme.error)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDeposit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isDeposit ? AppTheme.success : AppTheme.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDeposit ? 'Deposit' : 'Withdrawal',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Text(txn['dateStr'] ?? '—',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.textSecondary)),
                if (txn['phone'] != null)
                  Text(txn['phone'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDeposit ? '+' : '-'} UGX ${fmt.format(amount)}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDeposit ? AppTheme.success : AppTheme.error),
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? AppTheme.success.withOpacity(0.1)
                      : status == 'failed'
                          ? AppTheme.error.withOpacity(0.1)
                          : AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: status == 'completed'
                          ? AppTheme.success
                          : status == 'failed'
                              ? AppTheme.error
                              : AppTheme.warning),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── All Transactions Screen ──────────────────────────────────────────────────

class _AllTransactionsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final NumberFormat fmt;
  final void Function(Map<String, dynamic>) onTap;

  const _AllTransactionsScreen({
    required this.transactions,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('All Transactions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            Navigator.pop(context);
            onTap(transactions[i]);
          },
          child: _TransactionTile(txn: transactions[i], fmt: fmt),
        ),
      ),
    );
  }
}

// ─── Wallet Receipt Screen ────────────────────────────────────────────────────

class _WalletReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> txn;
  final String farmerName;
  final NumberFormat fmt;

  const _WalletReceiptScreen({
    required this.txn,
    required this.farmerName,
    required this.fmt,
  });

  String get _type => txn['type'] as String? ?? 'transaction';
  bool get _isDeposit => _type == 'deposit';
  int get _amount => (txn['amount'] as num?)?.toInt() ?? 0;
  String get _phone => txn['phone'] as String? ?? '—';
  String get _date => txn['dateStr'] as String? ?? '—';
  String get _txnId => txn['marzUuid'] as String? ?? txn['id'] as String? ?? '—';
  String get _reference => txn['marzReference'] as String? ?? '—';
  String get _status => txn['status'] as String? ?? '—';
  String get _provider {
    final p = txn['provider'] as String?;
    if (p == 'mtn') return 'MTN Mobile Money';
    if (p == 'airtel') return 'Airtel Money';
    return p ?? 'Mobile Money';
  }

  String get _qrData =>
      'TXN:$_txnId|TYPE:${_type.toUpperCase()}|AMT:UGX $_amount|PHONE:$_phone|DATE:$_date';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('${_isDeposit ? 'Deposit' : 'Withdrawal'} Receipt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isDeposit
                        ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
                        : [const Color(0xFFC62828), const Color(0xFFEF5350)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: Icon(
                        _isDeposit
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: Colors.white, size: 30,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isDeposit ? 'Deposit Successful' : 'Withdrawal Successful',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('MBADIFA SACCO — Wallet',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),

              // Amount
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Text('Amount',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('UGX ${fmt.format(_amount)}',
                        style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _isDeposit
                                ? AppTheme.success
                                : AppTheme.error)),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _row('Member', farmerName),
                    _row('Type', _isDeposit ? 'Deposit' : 'Withdrawal'),
                    _row('Network', _provider),
                    _row('Phone', _phone),
                    _row('Date', _date),
                    _row('Status', _status.toUpperCase()),
                    _row('Transaction ID', _txnId, small: true),
                    _row('Reference', _reference, small: true),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),

              // QR
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Scan to Verify',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 150,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('MBADIFA SACCO • ${AppConstants.companyCity}',
                        style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.grey.shade400),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: small ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
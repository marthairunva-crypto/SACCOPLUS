import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../auth/login_screen.dart';
import '../common/about_screen.dart';
import '../common/settings_screen.dart';
import 'ai_chat_screen.dart';
import 'airtime_data_screen.dart';
import 'transaction_history_screen.dart';
import 'apply_loan_screen.dart';
import 'bank_transfer_screen.dart';
import 'bill_payment_screen.dart';
import 'fixed_deposit_screen.dart';
import 'loan_status_screen.dart';
import 'notifications_screen.dart';
import 'repayment_screen.dart';
import 'savings_screen.dart';
import 'shares_screen.dart';
import 'wallet_screen.dart';

class FarmerScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBack;

  const FarmerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottom,
    this.showBack = false,
  });

  @override
  State<FarmerScaffold> createState() => _FarmerScaffoldState();
}

class _FarmerScaffoldState extends State<FarmerScaffold> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = FirebaseService.sessionUid;
      if (uid.isNotEmpty) {
        final p = await FirebaseService.getUserProfile(uid);
        if (mounted) setState(() => _profile = p);
      }
    } catch (_) {}
  }

  String get _name  => _profile?['name']  as String? ?? FirebaseService.sessionProfile?['name']  as String? ?? 'Member';
  String get _phone => _profile?['phone'] as String? ?? FirebaseService.sessionProfile?['phone'] as String? ?? '';
  String get _image => _profile?['profileImage'] as String? ?? FirebaseService.sessionProfile?['profileImage'] as String? ?? '';

  void _go(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _confirmLogout() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Sign Out', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.title),
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        actions: widget.actions,
        bottom: widget.bottom,
      ),
      drawer: _FarmerDrawer(
        name: _name,
        phone: _phone,
        imageUrl: _image,
        onHome:         () { Navigator.pop(context); Navigator.of(context).popUntil((r) => r.isFirst); },
        onWallet:       () => _go(const WalletScreen()),
        onSavings:      () => _go(const SavingsScreen()),
        onShares:       () => _go(const SharesScreen()),
        onFixedDeposit: () => _go(const FixedDepositScreen()),
        onBankTransfer: () => _go(const BankTransferScreen()),
        onBillPayment:  () => _go(const BillPaymentScreen()),
        onAirtime:      () => _go(const AirtimeDataScreen()),
        onTxnHistory:   () => _go(const TransactionHistoryScreen()),
        onApply:        () => _go(const ApplyLoanScreen()),
        onLoans:        () => _go(const LoanStatusScreen()),
        onRepayments:   () => _go(const RepaymentScreen()),
        onNotif:        () => _go(const NotificationsScreen()),
        onSettings:     () => _go(const SettingsScreen()),
        onAbout:        () => _go(const AboutScreen()),
        onAiChat:       () => _go(const AiChatScreen()),
        onLogout:       _confirmLogout,
      ),
      body: widget.body,
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────────────────────
class _FarmerDrawer extends StatelessWidget {
  final String name;
  final String phone;
  final String imageUrl;
  final VoidCallback onHome;
  final VoidCallback onWallet;
  final VoidCallback onSavings;
  final VoidCallback onShares;
  final VoidCallback onFixedDeposit;
  final VoidCallback onBankTransfer;
  final VoidCallback onBillPayment;
  final VoidCallback onAirtime;
  final VoidCallback onTxnHistory;
  final VoidCallback onApply;
  final VoidCallback onLoans;
  final VoidCallback onRepayments;
  final VoidCallback onNotif;
  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback onAiChat;
  final VoidCallback onLogout;

  const _FarmerDrawer({
    required this.name,
    required this.phone,
    required this.imageUrl,
    required this.onHome,
    required this.onWallet,
    required this.onSavings,
    required this.onShares,
    required this.onFixedDeposit,
    required this.onBankTransfer,
    required this.onBillPayment,
    required this.onAirtime,
    required this.onTxnHistory,
    required this.onApply,
    required this.onLoans,
    required this.onRepayments,
    required this.onNotif,
    required this.onSettings,
    required this.onAbout,
    required this.onAiChat,
    required this.onLogout,
  });

  // Dark sidebar — SACCOPLUS Pro navy
  static const _bg     = Color(0xFF071A45); // darkest navy
  static const _bg2    = Color(0xFF0D2B6B); // primary navy
  static const _white  = Colors.white;
  static const _muted  = Color(0xFF8A9BB0);
  static const _active = Color(0xFFF47920); // orange accent highlight

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Drawer(
      backgroundColor: _bg,
      width: 280,
      child: SafeArea(
        top: false, // we handle top padding manually in the header
        bottom: false,
        child: Column(
          children: [
            // ── Profile header ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: _bg2,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                20,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _active.withOpacity(0.2),
                    backgroundImage:
                        imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    child: imageUrl.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'F',
                            style: GoogleFonts.poppins(
                                color: _active,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: GoogleFonts.poppins(
                                color: _white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          phone.isNotEmpty ? phone : 'SACCO Member',
                          style: GoogleFonts.poppins(
                              color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu (scrollable) ──────────────────────────────────────────
            Expanded(
              child: ListView(
                primary: false,
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _item(Icons.home_outlined, 'Home', onHome),
                  _divider(),

                  _section('MONEY'),
                  _item(Icons.account_balance_wallet_outlined, 'My Wallet', onWallet),
                  _item(Icons.savings_outlined, 'My Savings', onSavings),
                  _item(Icons.pie_chart_outline_rounded, 'My Shares', onShares),
                  _item(Icons.account_balance_rounded, 'Fixed Deposits', onFixedDeposit),
                  _item(Icons.account_balance_outlined, 'Bank Transfer', onBankTransfer),
                  _item(Icons.receipt_outlined, 'Pay Bills', onBillPayment),
                  _item(Icons.phone_android_rounded, 'Airtime & Data', onAirtime),
                  _item(Icons.receipt_long_rounded, 'Transactions', onTxnHistory),
                  _item(Icons.credit_score_outlined, 'Apply for Loan', onApply),
                  _divider(),

                  _section('LOANS'),
                  _item(Icons.receipt_long_outlined, 'My Loans', onLoans),
                  _item(Icons.payments_outlined, 'Repayments', onRepayments),
                  _divider(),

                  _section('ACCOUNT'),
                  _item(Icons.auto_awesome_rounded, 'AI Assistant', onAiChat, isNew: true),
                  _item(Icons.notifications_none_rounded, 'Notifications', onNotif),
                  _item(Icons.settings_outlined, 'Settings', onSettings),
                  _item(Icons.info_outline_rounded, 'About', onAbout),
                ],
              ),
            ),

            // ── Sign out — always visible at bottom ────────────────────────
            Container(
              color: _bg2,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onLogout,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded,
                            color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 14),
                        Text('Sign Out',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFFEF4444),
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      );

  Widget _divider() => Divider(
        color: Colors.white.withOpacity(0.06),
        height: 1,
        indent: 20,
        endIndent: 20,
      );

  Widget _item(IconData icon, String label, VoidCallback onTap, {bool isNew = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: _active.withOpacity(0.1),
        highlightColor: _active.withOpacity(0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: _muted, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(color: _white, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('NEW',
                      style: GoogleFonts.poppins(
                          fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

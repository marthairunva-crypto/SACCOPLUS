import 'dart:ui' show FontFeature;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/birthday_service.dart';
import '../../widgets/app_widgets.dart';
import '../auth/professional_login_screen.dart';
import '../common/about_screen.dart';
import '../common/settings_screen.dart';
import 'ai_chat_screen.dart';
import 'airtime_data_screen.dart';
import 'transaction_history_screen.dart';
import 'apply_loan_screen.dart';
import 'bill_payment_screen.dart';
import 'loan_status_screen.dart';
import 'repayment_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'wallet_screen.dart';
import 'bank_transfer_screen.dart';
import 'savings_screen.dart';
import 'shares_screen.dart';
import 'fixed_deposit_screen.dart';
import 'create_fixed_deposit_screen.dart';

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});
  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;

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
        if (mounted) setState(() { _profile = p; _profileLoading = false; });
        // Check and send birthday notification + SMS if today is their birthday
        if (p != null) {
          BirthdayService.checkAndWish(uid: uid, profile: p);
        }
      } else {
        if (mounted) setState(() => _profileLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  String get _farmerName => _profile?['name'] ?? 'Member';
  void _navigate(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    final pages = [
      _HomeTab(
        onApply: () => _navigate(const ApplyLoanScreen()),
        onStatus: () => _navigate(const LoanStatusScreen()),
        onRepay: () => _navigate(const RepaymentScreen()),
        onNotif: () => _navigate(const NotificationsScreen()),
      ),
      const LoanStatusScreen(embedded: true),
      const RepaymentScreen(embedded: true),
      const ProfileScreen(),
    ];
    
    // DESKTOP LAYOUT: Side nav + content
    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Row(
          children: [
            // Side Navigation (220px fixed width)
            _SharedDashboardDrawer(
              name: _farmerName,
              phone: _profile?['phone'] ?? '',
              imageUrl: _profile?['profileImage'] ?? '',
              onNavigate: (i) => setState(() => _selectedIndex = i),
              onNavigatePage: (page) => _navigate(page),
              onLogout: () => _confirmLogout(context),
            ),
            // Main Content
            Expanded(
              child: pages[_selectedIndex],
            ),
          ],
        ),
      );
    }
    
    // MOBILE LAYOUT: Drawer + Bottom nav (existing)
    return Scaffold(
      backgroundColor: AppTheme.surface,
      drawer: _SharedDashboardDrawer(
        name: _farmerName,
        phone: _profile?['phone'] ?? '',
        imageUrl: _profile?['profileImage'] ?? '',
        onNavigate: (i) { Navigator.pop(context); setState(() => _selectedIndex = i); },
        onNavigatePage: (page) { Navigator.pop(context); _navigate(page); },
        onLogout: () => _confirmLogout(context),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
      floatingActionButton: _AiChatFab(),
    );
  }

  void _confirmLogout(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const ProfessionalLoginScreen()), (r) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Drawer ────────────────────────────────────────────────────────────
class _SharedDashboardDrawer extends StatelessWidget {
  final String name, phone, imageUrl;
  final ValueChanged<int> onNavigate;
  final ValueChanged<Widget> onNavigatePage;
  final VoidCallback onLogout;
  const _SharedDashboardDrawer({required this.name, required this.phone, required this.imageUrl,
      required this.onNavigate, required this.onNavigatePage, required this.onLogout});

  static const _bg   = Color(0xFF1A2332); // Modern dark navy
  static const _bg2  = Color(0xFF242D3C); // Slightly lighter
  static const _white = Colors.white;
  static const _muted = Color(0xFF8B92A0);
  static const _blue  = Color(0xFF4A90E2); // Modern blue accent

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final content = Column(children: [
      Container(
        width: double.infinity, color: _bg2,
        padding: EdgeInsets.fromLTRB(20, isDesktop ? 32 : MediaQuery.of(context).padding.top + 20, 20, 20),
        child: Row(children: [
          CircleAvatar(
            radius: 26, backgroundColor: _blue.withOpacity(0.2),
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                style: GoogleFonts.poppins(color: _blue, fontSize: 20, fontWeight: FontWeight.w700)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.poppins(color: _white, fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(phone.isNotEmpty ? phone : 'SACCO Member',
                style: GoogleFonts.poppins(color: _muted, fontSize: 12)),
          ])),
        ]),
      ),
      Expanded(child: ListView(primary: false, padding: const EdgeInsets.symmetric(vertical: 12), children: [
        _item(Icons.home_outlined, 'Dashboard', () => onNavigate(0)),
        _divider(),
        _section('MONEY'),
        _item(Icons.account_balance_wallet_outlined, 'My Wallet', () => onNavigatePage(const WalletScreen())),
        _item(Icons.savings_outlined, 'My Savings', () => onNavigatePage(const SavingsScreen())),
        _item(Icons.pie_chart_outline_rounded, 'My Shares', () => onNavigatePage(const SharesScreen())),
        _item(Icons.account_balance_rounded, 'Fixed Deposits', () => onNavigatePage(const FixedDepositScreen())),
        _item(Icons.account_balance_outlined, 'Bank Transfer', () => onNavigatePage(const BankTransferScreen())),
        _item(Icons.receipt_outlined, 'Pay Bills', () => onNavigatePage(const BillPaymentScreen())),
        _item(Icons.phone_android_rounded, 'Airtime & Data', () => onNavigatePage(const AirtimeDataScreen())),
        _item(Icons.auto_awesome_rounded, 'AI Assistant', () => onNavigatePage(const AiChatScreen()), isNew: true),
        _item(Icons.receipt_long_rounded, 'Transactions', () => onNavigatePage(const TransactionHistoryScreen())),
        _item(Icons.credit_score_outlined, 'Apply for Loan', () => onNavigatePage(const ApplyLoanScreen())),
        _divider(),
        _section('LOANS'),
        _item(Icons.receipt_long_outlined, 'My Loans', () => onNavigate(1)),
        _item(Icons.payments_outlined, 'Repayments', () => onNavigate(2)),
        _divider(),
        _section('ACCOUNT'),
        _item(Icons.person_outlined, 'Profile', () => onNavigate(3)),
        _item(Icons.notifications_none_rounded, 'Notifications', () => onNavigatePage(const NotificationsScreen())),
        _item(Icons.settings_outlined, 'Settings', () => onNavigatePage(const SettingsScreen())),
        _item(Icons.info_outline_rounded, 'About', () => onNavigatePage(const AboutScreen())),
      ])),
      Container(
        color: _bg2,
        child: Material(color: Colors.transparent, child: InkWell(
          onTap: onLogout,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
            child: Row(children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 14),
              Text('Sign Out', style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.w600)),
            ])),
        )),
      ),
    ]);
    
    // Desktop: Container (no Drawer widget)
    if (isDesktop) {
      return Container(
        width: 220,
        color: _bg,
        child: SafeArea(
          top: false,
          bottom: false,
          child: content,
        ),
      );
    }
    
    // Mobile: Drawer widget
    return Drawer(
      backgroundColor: _bg, 
      width: 280,
      child: SafeArea(
        top: false,
        bottom: false,
        child: content,
      ),
    );
  }

  Widget _section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(label, style: GoogleFonts.poppins(color: _muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)));

  Widget _divider() => Divider(color: Colors.white.withOpacity(0.06), height: 1, indent: 20, endIndent: 20);

  Widget _item(IconData icon, String label, VoidCallback onTap, {bool isNew = false}) => Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, splashColor: _blue.withOpacity(0.1), highlightColor: _blue.withOpacity(0.06),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(children: [
            Icon(icon, color: _muted, size: 20), const SizedBox(width: 16),
            Expanded(child: Text(label, style: GoogleFonts.poppins(color: _white, fontSize: 14, fontWeight: FontWeight.w500))),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('NEW', style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
              ),
          ]))));
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final VoidCallback onApply, onStatus, onRepay, onNotif;
  const _HomeTab({required this.onApply, required this.onStatus, required this.onRepay, required this.onNotif});
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _profile;
  late final String _memberId;
  int _totalBorrowed = 0, _totalRepaid = 0, _outstanding = 0;
  int _active = 0, _pending = 0, _overdue = 0, _paid = 0, _walletBalance = 0;
  bool _walletBalanceHidden = false;
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _memberId = FirebaseService.sessionUid;
    _profile = FirebaseService.sessionProfile;
    _load();
  }

  Future<void> _load() async {
    if (_memberId.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    try {
      final results = await Future.wait([
        FirebaseService.getUserProfile(_memberId),
        FirebaseService.getFarmerLoansOnce(_memberId),
        FirebaseService.getFarmerRepaymentsOnce(_memberId),
        FirebaseService.getWallet(_memberId),
      ]);
      final profile    = results[0] as Map<String, dynamic>?;
      final loans      = results[1] as List<Map<String, dynamic>>;
      final repayments = results[2] as List<Map<String, dynamic>>;
      final wallet     = results[3] as Map<String, dynamic>;
      final fmtLocal   = NumberFormat('#,###', 'en_US');

      int active = 0, pending = 0, overdue = 0, paid = 0, totalBorrowed = 0;
      for (final d in loans) {
        final status = d['status'] as String? ?? '';
        final amount = (d['amount'] as num?)?.toInt() ?? 0;
        totalBorrowed += amount;
        if (status == AppConstants.statusApproved || status == AppConstants.statusActive) active++;
        else if (status == AppConstants.statusPending) pending++;
        else if (status == AppConstants.statusOverdue) overdue++;
        else if (status == AppConstants.statusPaid) paid++;
      }
      final totalRepaidAmount = repayments.fold<int>(0, (s, r) => s + ((r['amount'] as num?)?.toInt() ?? 0));
      final totalActive = loans.where((l) => l['status'] == AppConstants.statusApproved || l['status'] == AppConstants.statusActive)
          .fold<int>(0, (s, l) => s + ((l['amount'] as num?)?.toInt() ?? 0));
      final outstanding = (totalActive - totalRepaidAmount).clamp(0, totalActive);
      final recent = loans.take(3).map((d) {
        final ts = d['createdAt'];
        String dateStr = '—';
        if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
        return {'amount': 'UGX ${fmtLocal.format((d['amount'] as num?)?.toInt() ?? 0)}',
          'purpose': d['purpose'] ?? '—', 'date': dateStr, 'status': d['status'] ?? '—'};
      }).toList();

      if (!mounted) return;
      setState(() {
        _profile = profile ?? _profile;
        _totalBorrowed = totalBorrowed; _totalRepaid = totalRepaidAmount;
        _outstanding = outstanding; 
        _active = active; 
        _pending = pending;
        _overdue = overdue;
        _paid = paid;
        _walletBalance = (wallet['balance'] as num?)?.toInt() ?? 0;
        _recent = recent; _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
  String get _name => _profile?['name'] ?? 'Member';
  String get _phone => _profile?['phone'] ?? '';
  String _fmt(int n) => NumberFormat('#,###', 'en_US').format(n);
  String _shortNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final tot = _totalBorrowed + _walletBalance;
    final depPct = tot > 0 ? (_walletBalance / tot * 100).round() : 0;
    final loanPct = tot > 0 ? (_totalBorrowed / tot * 100).round() : 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700; // Lowered from 900
    
    print('🖥️ DASHBOARD: Screen width = $screenWidth, isDesktop = $isDesktop');

    // DESKTOP: Completely different layout
    if (isDesktop) {
      print('✅ Using DESKTOP layout');
      return _buildDesktopLayout();
    }
    
    print('📱 Using MOBILE layout');

    // MOBILE: Original layout
    final content = CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 160, pinned: true, backgroundColor: AppTheme.primary,
        leading: Builder(builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer())),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: widget.onNotif),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.primaryLight],
                begin: Alignment.topLeft, end: Alignment.bottomRight)),
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('$_greeting, $_name', style: GoogleFonts.poppins(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600)),
              Text(AppConstants.appSubtitle, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
            ]),
          ),
        ),
      ),
      SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Financial Overview ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(children: [
            Text('FINANCIAL OVERVIEW', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent, letterSpacing: 1.6)),
            const SizedBox(height: 4),
            Text(_loading ? '...' : 'UGX ${_fmt(tot)}',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w300, color: AppTheme.textPrimary)),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Deposits
              Expanded(child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('MY DEPOSITS', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: 0.8)),
                    const SizedBox(width: 4),
                    Text('$depPct%', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('UGX ', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary)),
                    Flexible(child: Text(_loading ? '...' : _fmt(_walletBalance),
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Container(height: 2, color: AppTheme.accent),  // orange = deposits
                ]),
              )),
              // Donut
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _DonutRing(
                  depositFraction: tot > 0 ? _walletBalance / tot : 0,
                  loanFraction: tot > 0 ? _totalBorrowed / tot : 0,
                  loading: _loading,
                )),
              // Loans
              Expanded(child: GestureDetector(
                onTap: widget.onStatus,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('MY LOANS', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: 0.8)),
                    const SizedBox(width: 4),
                    Text('$loanPct%', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text('UGX ', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary)),
                    Flexible(child: Text(_loading ? '...' : _fmt(_outstanding),
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Container(height: 2, color: AppTheme.primary),  // navy = loans
                ]),
              )),
            ]),
            const SizedBox(height: 10),
            Text('AT', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 1.2)),
            Text('100 %', style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textSecondary)),
          ]),
        ).animate().fadeIn(duration: 500.ms),

        const SizedBox(height: 8),

        // ── Wallet card ─────────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0D2B6B), Color(0xFF1A3F8F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF0D2B6B).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Wallet Balance', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                  Text(_walletBalanceHidden ? '••••••' : 'UGX ${_fmt(_walletBalance)}',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ])),
                GestureDetector(
                  onTap: () => setState(() => _walletBalanceHidden = !_walletBalanceHidden),
                  child: Icon(_walletBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70, size: 20),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
              ]),
            ),
          ),
        ).animate().fadeIn(delay: 80.ms, duration: 500.ms),

        const SizedBox(height: 20),

        // ── Services grid ───────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Services', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive column count
                final crossAxisCount = constraints.maxWidth > 900 ? 6 : 4;
                return GridView.count(
                  crossAxisCount: crossAxisCount, 
                  shrinkWrap: true, 
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10, 
                  mainAxisSpacing: 14, 
                  childAspectRatio: 0.82,
                  children: [
                    _ServiceTile(icon: Icons.add_card_rounded,          label: 'Apply\nLoan',      color: const Color(0xFF1565C0), onTap: widget.onApply),
                    _ServiceTile(icon: Icons.folder_copy_rounded,        label: 'My\nLoans',        color: const Color(0xFF6A1B9A), onTap: widget.onStatus),
                    _ServiceTile(icon: Icons.currency_exchange_rounded,  label: 'Repay\nLoan',      color: const Color(0xFF00796B), onTap: widget.onRepay),
                    _ServiceTile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet',        color: const Color(0xFF1565C0),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
                    _ServiceTile(icon: Icons.savings_rounded,            label: 'Savings',          color: const Color(0xFF2E7D32),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen()))),
                    _ServiceTile(icon: Icons.donut_large_rounded,        label: 'Shares',           color: const Color(0xFF6A1B9A),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SharesScreen()))),
                    _ServiceTile(icon: Icons.lock_clock_rounded,         label: 'Fixed\nDeposit',   color: const Color(0xFF0277BD),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedDepositScreen()))),
                    _ServiceTile(icon: Icons.receipt_rounded,            label: 'Pay\nBills',       color: const Color(0xFFF57C00),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillPaymentScreen()))),
                    _ServiceTile(icon: Icons.sim_card_rounded,           label: 'Airtime\n& Data',  color: const Color(0xFF00838F),
                        isNew: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AirtimeDataScreen()))),
                    _ServiceTile(icon: Icons.account_balance_rounded,    label: 'Bank\nTransfer',   color: const Color(0xFF37474F),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankTransferScreen()))),
                    _ServiceTile(icon: Icons.psychology_rounded,         label: 'AI\nAssistant',    color: const Color(0xFF6A1B9A),
                        isNew: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()))),
                  ],
                );
              },
            ),
          ]),
        ).animate().fadeIn(delay: 150.ms, duration: 500.ms),

        const SizedBox(height: 20),

        const SizedBox(height: 20),

        // ── Recent activity ─────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Recent Activity', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            GestureDetector(onTap: widget.onStatus,
                child: Text('See All', style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500))),
          ]),
        ),
        const SizedBox(height: 10),

        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primary)))
        else if (_recent.isEmpty)
          const EmptyState(message: 'No loan activity yet.\nTap Apply Loan to get started.', icon: Icons.account_balance_wallet_outlined)
        else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: _recent.asMap().entries.map((e) {
              final l = e.value;
              return LoanListTile(loanId: '', amount: l['amount']!, purpose: l['purpose']!, date: l['date']!, status: l['status']!)
                  .animate().fadeIn(delay: (300 + e.key * 80).ms, duration: 400.ms).slideX(begin: 0.1, end: 0);
            }).toList()),
          ),

        const SizedBox(height: 90),
      ])),
    ]);
    
    return content;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT - FinBank Premium Design
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    final tot = _totalBorrowed + _walletBalance;
    final depPct = tot > 0 ? (_walletBalance / tot * 100).round() : 0;
    final loanPct = tot > 0 ? (_totalBorrowed / tot * 100).round() : 0;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Content Area (70%)
            Expanded(
              flex: 7,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    Text(
                      'Welcome to ${AppConstants.appName}',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Hi, $_name. Welcome Back.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Account Balance Card (Like FinBank Debit Card)
                    _buildPremiumBalanceCard(),
                    const SizedBox(height: 32),

                    // Recent Transactions
                    _buildRecentTransactionsCard(),
                    const SizedBox(height: 32),

                    // Services Grid
                    _buildServicesCard(),
                  ],
                ),
              ),
            ),

            // Right Sidebar (30%)
            Container(
              width: 380,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Balance Card
                    _buildTotalBalanceCard(),
                    const SizedBox(height: 32),

                    // Expenses/Stats
                    _buildExpensesCard(depPct, loanPct),
                    const SizedBox(height: 32),

                    // Quick Actions
                    _buildQuickActionsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINBANK-STYLE PREMIUM WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPremiumBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Card Design
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savings Account',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Virtual Card
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 24,
                        left: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Member Account',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        left: 24,
                        child: Text(
                          _walletBalanceHidden ? '•••• •••• •••• ••••' : 'ACC ${_phone.replaceAll('+', '')}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 2,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        left: 24,
                        right: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Valid Thru: ${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().add(const Duration(days: 365)).year.toString().substring(2)}',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'VISA',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
          // Right: Add Card Button
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2, style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Icon(Icons.add_circle_outline, size: 40, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Add Debit Card',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    onPressed: () {},
                  ),
                  TextButton.icon(
                    onPressed: widget.onStatus,
                    icon: const Icon(Icons.filter_list, size: 16),
                    label: Text(
                      'Last 7 Days',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          else if (_recent.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No recent transactions',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recent.take(5).map((tx) {
              final isPositive = tx['status'] == 'approved';
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx['purpose'] ?? 'Transaction',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            tx['date'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : '-'}UGX ${_fmt(tx['amount'] ?? 0)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Total Balance',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: Icon(
                  _walletBalanceHidden ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _walletBalanceHidden = !_walletBalanceHidden),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _walletBalanceHidden ? '\$••••••' : '\$ ${(_walletBalance / 3700).toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _walletBalanceHidden ? '••••••' : 'UGX ${_fmt(_walletBalance)}',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _balanceAction(Icons.send, 'Send'),
              const SizedBox(width: 16),
              _balanceAction(Icons.account_balance_wallet, 'Receive'),
              const SizedBox(width: 16),
              _balanceAction(Icons.swap_horiz, 'Transfer'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceAction(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesCard(int depPct, int loanPct) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Split',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, size: 20),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 50,
                      sections: [
                        PieChartSectionData(
                          value: depPct.toDouble(),
                          color: const Color(0xFF10B981),
                          radius: 40,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: loanPct.toDouble(),
                          color: const Color(0xFF3B82F6),
                          radius: 40,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: Text(
                      '$depPct%',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Savings Level',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Exp:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'UGX ${_fmt(_totalBorrowed)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          _quickActionItem(Icons.add_card, 'Apply for Loan', widget.onApply),
          _quickActionItem(Icons.receipt, 'My Loans', widget.onStatus),
          _quickActionItem(Icons.payment, 'Repay Loan', widget.onRepay),
          _quickActionItem(Icons.savings, 'View Savings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen()))),
        ],
      ),
    );
  }

  Widget _quickActionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(int tot, int depPct, int loanPct) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINANCIAL OVERVIEW',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _loading ? '...' : 'UGX ${_fmt(tot)}',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              // Deposits
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MY DEPOSITS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$depPct%',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loading ? '...' : 'UGX ${_fmt(_walletBalance)}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2332),
                      ),
                    ),
                  ],
                ),
              ),
              // Donut Chart
              SizedBox(
                width: 120,
                height: 120,
                child: _DonutRing(
                  depositFraction: tot > 0 ? _walletBalance / tot : 0,
                  loanFraction: tot > 0 ? _totalBorrowed / tot : 0,
                  loading: _loading,
                ),
              ),
              // Loans
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MY LOANS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$loanPct%',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loading ? '...' : 'UGX ${_fmt(_outstanding)}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
            children: [
              _ServiceTile(icon: Icons.add_card_rounded, label: 'Apply\nLoan', color: const Color(0xFF1565C0), onTap: widget.onApply),
              _ServiceTile(icon: Icons.folder_copy_rounded, label: 'My\nLoans', color: const Color(0xFF6A1B9A), onTap: widget.onStatus),
              _ServiceTile(icon: Icons.currency_exchange_rounded, label: 'Repay\nLoan', color: const Color(0xFF00796B), onTap: widget.onRepay),
              _ServiceTile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', color: const Color(0xFF1565C0),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
              _ServiceTile(icon: Icons.savings_rounded, label: 'Savings', color: const Color(0xFF2E7D32),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsScreen()))),
              _ServiceTile(icon: Icons.donut_large_rounded, label: 'Shares', color: const Color(0xFF6A1B9A),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SharesScreen()))),
              _ServiceTile(icon: Icons.lock_clock_rounded, label: 'Fixed\nDeposit', color: const Color(0xFF0277BD),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedDepositScreen()))),
              _ServiceTile(icon: Icons.receipt_rounded, label: 'Pay\nBills', color: const Color(0xFFF57C00),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillPaymentScreen()))),
              _ServiceTile(icon: Icons.sim_card_rounded, label: 'Airtime', color: const Color(0xFF00838F), isNew: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AirtimeDataScreen()))),
              _ServiceTile(icon: Icons.account_balance_rounded, label: 'Transfer', color: const Color(0xFF37474F),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankTransferScreen()))),
              _ServiceTile(icon: Icons.psychology_rounded, label: 'AI Chat', color: const Color(0xFF6A1B9A), isNew: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()))),
              _ServiceTile(icon: Icons.receipt_long_rounded, label: 'History', color: const Color(0xFF455A64),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanStatsChart() {
    // Don't show chart if still loading or no data
    if (_loading || (_active == 0 && _pending == 0 && _overdue == 0 && _paid == 0)) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loan Statistics',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    if (_loading)
                      const CircularProgressIndicator()
                    else ...[
                      Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No loan data available',
                        style: GoogleFonts.poppins(color: const Color(0xFF9CA3AF)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Statistics',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: ((_active > 0 ? _active : 0) + (_pending > 0 ? _pending : 0) + (_overdue > 0 ? _overdue : 0) + (_paid > 0 ? _paid : 0)).toDouble() + 2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String status;
                      switch (group.x.toInt()) {
                        case 0:
                          status = 'Active';
                          break;
                        case 1:
                          status = 'Pending';
                          break;
                        case 2:
                          status = 'Overdue';
                          break;
                        case 3:
                          status = 'Paid';
                          break;
                        default:
                          status = '';
                      }
                      return BarTooltipItem(
                        '$status\n${rod.toY.toInt()} loans',
                        GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        String text;
                        switch (value.toInt()) {
                          case 0:
                            text = 'Active';
                            break;
                          case 1:
                            text = 'Pending';
                            break;
                          case 2:
                            text = 'Overdue';
                            break;
                          case 3:
                            text = 'Paid';
                            break;
                          default:
                            text = '';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            text,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFF3F4F6),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: (_active > 0 ? _active : 0).toDouble(),
                        color: const Color(0xFF10B981), // Green
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: (_pending > 0 ? _pending : 0).toDouble(),
                        color: const Color(0xFFF59E0B), // Orange
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: (_overdue > 0 ? _overdue : 0).toDouble(),
                        color: const Color(0xFFEF4444), // Red
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: (_paid > 0 ? _paid : 0).toDouble(),
                        color: const Color(0xFF6366F1), // Purple
                        width: 40,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _legendItem('Active', const Color(0xFF10B981), _active),
              _legendItem('Pending', const Color(0xFFF59E0B), _pending),
              _legendItem('Overdue', const Color(0xFFEF4444), _overdue),
              _legendItem('Paid', const Color(0xFF6366F1), _paid),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $count',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2332),
                ),
              ),
              TextButton(
                onPressed: widget.onStatus,
                child: Text(
                  'See All',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_recent.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No recent activities',
                      style: GoogleFonts.poppins(color: const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: _recent.map((l) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LoanListTile(
                    loanId: '',
                    amount: l['amount']!,
                    purpose: l['purpose']!,
                    date: l['date']!,
                    status: l['status']!,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D2B6B), Color(0xFF1A3F8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2B6B).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Wallet Balance',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _walletBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _walletBalanceHidden = !_walletBalanceHidden),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _walletBalanceHidden ? '••••••' : 'UGX ${_fmt(_walletBalance)}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  'View Details',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 28),
          _statRow('Active Loans', '$_active', Icons.receipt_long, const Color(0xFF6A1B9A)),
          const SizedBox(height: 20),
          _statRow('Pending', '$_pending', Icons.hourglass_empty, const Color(0xFFF59E0B)),
          const SizedBox(height: 16),
          _statRow('Total Repaid', 'UGX ${_shortNum(_totalRepaid)}', Icons.check_circle, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2332),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Donut Ring ───────────────────────────────────────────────────────────────
class _DonutRing extends StatelessWidget {
  final double depositFraction, loanFraction;
  final bool loading;
  const _DonutRing({required this.depositFraction, required this.loanFraction, required this.loading});
  @override
  Widget build(BuildContext context) => SizedBox(width: 100, height: 100,
      child: CustomPaint(painter: _DonutPainter(
          depositFraction: loading ? 0 : depositFraction,
          loanFraction: loading ? 0 : loanFraction)));
}

class _DonutPainter extends CustomPainter {
  final double depositFraction, loanFraction;
  _DonutPainter({required this.depositFraction, required this.loanFraction});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final outerR = size.width / 2; final strokeW = outerR * 0.38;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: outerR - strokeW / 2);
    canvas.drawCircle(Offset(cx, cy), outerR - strokeW / 2,
        Paint()..color = const Color(0xFFE5E7EB)..style = PaintingStyle.stroke..strokeWidth = strokeW);
    const start = -1.5707963; const full = 6.2831853;
    if (depositFraction > 0)
      canvas.drawArc(rect, start, full * depositFraction, false,
          Paint()..color = const Color(0xFFF47920)..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.butt);
    if (loanFraction > 0)
      canvas.drawArc(rect, start + full * depositFraction, full * loanFraction, false,
          Paint()..color = const Color(0xFF0D2B6B)..style = PaintingStyle.stroke..strokeWidth = strokeW..strokeCap = StrokeCap.butt);
    canvas.drawCircle(Offset(cx, cy), outerR - strokeW - 4,
        Paint()..color = const Color(0xFFE5E7EB)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.depositFraction != depositFraction || old.loanFraction != loanFraction;
}

// ─── Service Tile ─────────────────────────────────────────────────────────────
class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isNew;
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ),
            ),
            if (isNew)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFFF1744).withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text('NEW',
                      style: GoogleFonts.poppins(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A2E),
            height: 1.2,
          ),
        ),
      ],
    ),
  );
}

// ─── Summary Chip ─────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label, value; final Color color; final VoidCallback onTap;
  const _SummaryChip({required this.label, required this.value, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
        ]),
      )));
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex; final ValueChanged<int> onTap;
  const _BottomNav({required this.selectedIndex, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -2))]),
      child: BottomNavigationBar(
        currentIndex: selectedIndex, onTap: onTap,
        type: BottomNavigationBarType.fixed, backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent, unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11), elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Loans'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_rounded), label: 'Repayments'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ));
}

// ─── AI Chat Floating Button ──────────────────────────────────────────────────
class _AiChatFab extends StatefulWidget {
  @override
  State<_AiChatFab> createState() => _AiChatFabState();
}

class _AiChatFabState extends State<_AiChatFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + _pulse.value * 0.06,
        child: child,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiChatScreen()),
        ),
        backgroundColor: AppTheme.accent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.support_agent_rounded, color: Colors.white, size: 26),
            Positioned(
              top: -4, right: -4,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        label: Text(
          'AI Help',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }
}

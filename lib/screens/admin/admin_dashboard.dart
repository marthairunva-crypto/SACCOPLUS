import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/modern_theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/interest_service.dart';
import '../../widgets/app_widgets.dart';
import '../auth/professional_login_screen.dart';
import '../common/about_screen.dart';
import '../common/settings_screen.dart';
import 'loan_approval_screen.dart';
import 'farmer_management_screen.dart';
import 'migration_screen.dart';
import 'reports_screen.dart';
import 'admin_notification_screen.dart';
import 'fixed_deposits_admin_screen.dart';
import 'audit_log_screen.dart';
import 'savings_admin_screen.dart';
import 'shares_admin_screen.dart';
import 'sacco_settings_screen.dart';
import 'staff_management_screen.dart';
import 'dividend_distribution_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  void _navigate(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _AdminHomeTab(),
      const LoanApprovalScreen(embedded: true),
      const FarmerManagementScreen(embedded: true),
      const ReportsScreen(embedded: true),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light gray background for content area
      drawer: _AdminDrawer(
        onNavigate: (i) {
          Navigator.pop(context);
          setState(() => _selectedIndex = i);
        },
        onNavigateFixed: () {
          Navigator.pop(context);
          _navigate(const FixedDepositsAdminScreen());
        },
        onNavigateAudit: () {
          Navigator.pop(context);
          _navigate(const AuditLogScreen());
        },
        onNavigateSavings: () {
          Navigator.pop(context);
          _navigate(const SavingsAdminScreen());
        },
        onNavigateShares: () {
          Navigator.pop(context);
          _navigate(const SharesAdminScreen());
        },
        onNavigateStaff: () {
          Navigator.pop(context);
          _navigate(const StaffManagementScreen());
        },
        onNavigateSaccoSettings: () {
          Navigator.pop(context);
          _navigate(const SaccoSettingsScreen());
        },
        onNotif: () {
          Navigator.pop(context);
          _navigate(const AdminNotificationsScreen());
        },
        onSettings: () {
          Navigator.pop(context);
          _navigate(const SettingsScreen());
        },
        onAbout: () {
          Navigator.pop(context);
          _navigate(const AboutScreen());
        },
        onLogout: () => _confirmLogout(context),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: ModernTheme.primary,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle:
              GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.fact_check_rounded), label: 'Loans'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_rounded), label: 'Members'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfessionalLoginScreen()),
                  (r) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─── Admin Drawer ─────────────────────────────────────────────────────────────
class _AdminDrawer extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback onNavigateFixed;
  final VoidCallback onNavigateAudit;
  final VoidCallback onNavigateSavings;
  final VoidCallback onNavigateShares;
  final VoidCallback onNavigateStaff;
  final VoidCallback onNavigateSaccoSettings;
  final VoidCallback onNotif;
  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.onNavigate,
    required this.onNavigateFixed,
    required this.onNavigateAudit,
    required this.onNavigateSavings,
    required this.onNavigateShares,
    required this.onNavigateStaff,
    required this.onNavigateSaccoSettings,
    required this.onNotif,
    required this.onSettings,
    required this.onAbout,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A2332), // Dark blue background
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)], // Aurora Bank dark blue
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text('Administrator',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(AppConstants.appSubtitle,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Admin',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _drawerItem(Icons.dashboard_rounded, 'Dashboard',
                    () => onNavigate(0)),
                _drawerItem(Icons.fact_check_rounded, 'Loan Applications',
                    () => onNavigate(1)),
                _drawerItem(Icons.people_rounded, 'Manage Members',
                    () => onNavigate(2)),
                _drawerItem(Icons.account_balance_rounded, 'Fixed Deposits',
                    () => onNavigateFixed()),
                _drawerItem(Icons.bar_chart_rounded, 'Reports & Analytics',
                    () => onNavigate(3)),
                _drawerItem(Icons.history_rounded, 'Audit Trail',
                    () => onNavigateAudit()),
                Divider(color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16),
                _drawerItem(Icons.savings_rounded, 'Savings Management',
                    () => onNavigateSavings()),
                _drawerItem(Icons.pie_chart_rounded, 'Shares Management',
                    () => onNavigateShares()),
                _drawerItem(Icons.manage_accounts_rounded, 'Staff & Roles',
                    () => onNavigateStaff()),
                _drawerItem(Icons.settings_rounded, 'SACCO Settings',
                    () => onNavigateSaccoSettings()),
                Divider(color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16),
                _drawerItem(Icons.notifications_rounded, 'Send Notifications',
                    onNotif,
                    color: const Color(0xFF4A90E2)),
                Divider(color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16),
                _drawerItem(Icons.settings_outlined, 'Settings', onSettings),
                _drawerItem(Icons.info_outline_rounded, 'About App', onAbout),
                Divider(color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded,
                        color: Color(0xFFEF4444)),
                    label: Text('Sign Out',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white70, size: 22),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 14,
              color: color ?? Colors.white,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 8,
      dense: true,
      hoverColor: Colors.white.withOpacity(0.05),
    );
  }
}

// ─── Admin Home Tab ───────────────────────────────────────────────────────────
class _AdminHomeTab extends StatefulWidget {
  const _AdminHomeTab();

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab> {
  Map<String, int> _cachedStats = {
    'totalFarmers': 0, 'totalLoans': 0, 'pendingLoans': 0,
    'approvedLoans': 0, 'verifiedIds': 0, 'pendingIds': 0,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = _cachedStats['totalLoans'] == 0);
    try {
      final results = await Future.wait([
        FirebaseService.getAllLoansOnce(),
        FirebaseService.getAllFarmersOnce(),
      ]);
      final loans = results[0] as List<Map<String, dynamic>>;
      final farmers = results[1] as List<Map<String, dynamic>>;

      int pending = 0, approved = 0, verifiedIds = 0, pendingIds = 0;
      for (final d in loans) {
        final status = d['status'] as String? ?? '';
        if (status == AppConstants.statusPending) pending++;
        if (status == AppConstants.statusApproved) approved++;
      }
      for (final d in farmers) {
        final idStatus = d['idStatus'] as String? ?? '';
        if (idStatus == 'approved') verifiedIds++;
        if (idStatus == 'pending') pendingIds++;
      }
      if (!mounted) return;
      setState(() {
        _cachedStats = {
          'totalFarmers': farmers.length,
          'totalLoans': loans.length,
          'pendingLoans': pending,
          'approvedLoans': approved,
          'verifiedIds': verifiedIds,
          'pendingIds': pendingIds,
        };
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _calculateInterest(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Calculate Monthly Interest', 
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('This will calculate and apply monthly interest to all savings accounts. Continue?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.primary),
            child: const Text('Calculate'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Calculating interest...', style: GoogleFonts.poppins()),
          ],
        ),
      ),
    );

    try {
      await InterestService.calculateMonthlySavingsInterest();
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Monthly interest calculated and applied successfully!', 
            style: GoogleFonts.poppins()),
        backgroundColor: ModernTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error calculating interest: ${e.toString()}', 
            style: GoogleFonts.poppins()),
        backgroundColor: ModernTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody(context, _cachedStats);
  }

  Widget _buildBody(BuildContext context, Map<String, int> stats) {

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: const Color(0xFF1E3A5F), // Dark blue
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const AdminNotificationsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _load,
              tooltip: 'Refresh',
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)], // Aurora Bank colors
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Admin Dashboard',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  Text(AppConstants.appSubtitle,
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats grid
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: StatCard(
                          title: 'Total Members',
                          value: '${stats['totalFarmers'] ?? 0}',
                          icon: Icons.people_rounded,
                          color: ModernTheme.info,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: StatCard(
                          title: 'Verified IDs',
                          value: '${stats['verifiedIds'] ?? 0}',
                          icon: Icons.verified_rounded,
                          color: ModernTheme.success,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: StatCard(
                          title: 'Loan Applications',
                          value: '${stats['totalLoans'] ?? 0}',
                          icon: Icons.account_balance_rounded,
                          color: ModernTheme.primary,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: StatCard(
                          title: 'Pending Review',
                          value: '${stats['pendingLoans'] ?? 0}',
                          icon: Icons.pending_actions_rounded,
                          color: ModernTheme.warning,
                        )),
                      ],
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.15, end: 0),

                const SizedBox(height: 20),

                SectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 12),

                ...[
                  _ActionItem(
                    icon: Icons.fact_check_rounded,
                    title: 'Review Loan Applications',
                    subtitle: '${stats['pendingLoans'] ?? 0} pending',
                    color: ModernTheme.warning,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const LoanApprovalScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.people_rounded,
                    title: 'Manage Members',
                    subtitle: '${stats['pendingIds'] ?? 0} KYC(s) pending review',
                    color: ModernTheme.info,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const FarmerManagementScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.account_balance_rounded,
                    title: 'Fixed Deposits',
                    subtitle: 'Manage member fixed deposit accounts',
                    color: ModernTheme.primaryDark,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const FixedDepositsAdminScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'View Reports',
                    subtitle: 'Loans & repayments analytics',
                    color: ModernTheme.primary,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.history_rounded,
                    title: 'Audit Trail',
                    subtitle: 'Full log of all system actions',
                    color: ModernTheme.primaryDark,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AuditLogScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.savings_rounded,
                    title: 'Savings Management',
                    subtitle: 'Approve deposits, view all savings',
                    color: ModernTheme.accent,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SavingsAdminScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.pie_chart_rounded,
                    title: 'Shares Management',
                    subtitle: 'Approve purchases, process dividends',
                    color: ModernTheme.primaryLight,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SharesAdminScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.manage_accounts_rounded,
                    title: 'Staff & Roles',
                    subtitle: 'Manage staff permissions and roles',
                    color: ModernTheme.success,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const StaffManagementScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.settings_rounded,
                    title: 'SACCO Settings',
                    subtitle: 'Interest rates, fees, SACCO info',
                    color: ModernTheme.textSecondary,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SaccoSettingsScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.rocket_launch_rounded,
                    title: '🚀 Multi-Tenant Migration',
                    subtitle: 'ONE-TIME: Add tenantId to all records',
                    color: ModernTheme.warning,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MigrationScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.announcement_rounded,
                    title: 'Send Notification',
                    subtitle: 'Broadcast to all members',
                    color: ModernTheme.success,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AdminNotificationsScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.share_rounded,
                    title: 'Distribute Dividends',
                    subtitle: 'Pay dividends to all shareholders',
                    color: ModernTheme.accent,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const DividendDistributionScreen())),
                  ),
                  _ActionItem(
                    icon: Icons.calculate_rounded,
                    title: 'Calculate Interest',
                    subtitle: 'Apply monthly interest to savings',
                    color: ModernTheme.primaryLight,
                    onTap: () => _calculateInterest(context),
                  ),
                ]
                    .asMap()
                    .entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: e.value
                              .animate()
                              .fadeIn(
                                  delay: (100 + e.key * 80).ms,
                                  duration: 400.ms)
                              .slideX(begin: 0.1, end: 0),
                        ))
                    .toList(),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Action Item ──────────────────────────────────────────────────────────────
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: ModernTheme.textPrimary)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: ModernTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

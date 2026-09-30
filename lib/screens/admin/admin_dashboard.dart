import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'create_loan_screen.dart';
import 'reports_screen.dart';
import 'comprehensive_reports_screen.dart';
import 'migrate_shares_screen.dart';
import 'migrate_loans_screen.dart';
import 'teller_screen.dart';
import 'enhanced_audit_screen.dart';
import 'loan_portfolio_screen.dart';
import 'admin_notification_screen.dart';
import 'fixed_deposits_admin_screen.dart';
import 'audit_log_screen.dart';
import 'savings_admin_screen.dart';
import 'shares_admin_screen.dart';
import 'sacco_settings_screen.dart';
import 'staff_management_screen.dart';
import 'dividend_distribution_screen.dart';
import '../../debug/diagnose_data.dart';
import '../../debug/fix_tenant_ids.dart';
import '../../debug/check_session.dart';
import '../../debug/quick_check.dart';
import '../../debug/check_loan_fields.dart';
import '../../debug/print_index_link.dart';
import '../../services/dashboard_service.dart';
import '../../services/alerts_service.dart';
import '../../services/enhanced_metrics_service.dart';
import '../../services/loan_risk_service.dart';
import '../../services/liquidity_service.dart';
import 'loan_risk_center_screen.dart';
import 'liquidity_monitor_screen.dart';
import 'member_360_screen.dart';
import 'kyc_verification_screen.dart';
import 'dormant_accounts_screen.dart';
import 'loan_products_screen.dart';
import 'loan_calculator_screen.dart';
import 'collections_screen.dart';
import 'arrears_management_screen.dart';
import 'risk_provisioning_screen.dart';
import 'payment_screens.dart';
import 'finance_screens.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String _selectedScreen = 'dashboard';
  
  // Cache screens to maintain state  
  // NOTE: If you add new screens, do a Hot Restart (not just Hot Reload) to rebuild the cache
  Map<String, Widget>? _screenCacheInstance;
  
  Map<String, Widget> get _screenCache {
    _screenCacheInstance ??= {
      'dashboard': _AdminHomeTab(onNavigate: (screen) => setState(() => _selectedScreen = screen)),
      
      // MEMBERS
      'members': const FarmerManagementScreen(embedded: true),
      'member_360': Member360Screen(),
      'kyc': const KYCVerificationScreen(),
      'dormant': const DormantAccountsScreen(),
      
      // SAVINGS & SHARES
      'savings': const SavingsAdminScreen(),
      'shares': const SharesAdminScreen(),
      'fixed_deposits': const FixedDepositsAdminScreen(embedded: true),
      'dividends': const DividendDistributionScreen(),
      
      // LOANS
      'loans': const LoanApprovalScreen(embedded: true),
      'loan_portfolio': const LoanPortfolioScreen(embedded: true),
      'create_loan': const CreateLoanScreen(),
      'loan_products': const LoanProductsScreen(),
      'loan_calc': const LoanCalculatorScreen(),
      'collections': const CollectionsScreen(),
      'arrears': const ArrearsManagementScreen(),
      'risk_provision': const RiskProvisioningScreen(),
      
      // PAYMENTS
      'teller': const TellerScreen(embedded: true),
      'payment_hub': const PaymentHubScreen(),
      'mobile_money': const MobileMoneyScreen(),
      'bank_transfers': const BankTransfersScreen(),
      'reconciliation': const ReconciliationScreen(),
      
      // FINANCE
      'cash_bank': const CashBankScreen(),
      'income': const IncomeScreen(),
      'expenses': const ExpensesScreen(),
      'ledger': const GeneralLedgerScreen(),
      'financial_reports': const ComprehensiveReportsScreen(embedded: true),
      'migrate_shares': const MigrateSharesScreen(),
      'migrate_loans': const MigrateLoansScreen(),
      
      // INTELLIGENCE
      'risk_center': LoanRiskCenterScreen(tenantId: FirebaseService.sessionTenantId),
      'liquidity': LiquidityMonitorScreen(tenantId: FirebaseService.sessionTenantId),
      
      // OPERATIONS
      'staff': const StaffManagementScreen(),
      'notifications': const AdminNotificationsScreen(),
      
      // SYSTEM
      'settings': const SaccoSettingsScreen(),
      'audit': const EnhancedAuditScreen(embedded: true),
      'reports': const ReportsScreen(embedded: true),
    };
    return _screenCacheInstance!;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (isDesktop) {
      // Desktop layout with persistent sidebar and IndexedStack to maintain state
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Row(
          children: [
            // Persistent Sidebar
            Container(
              width: 260,
              decoration: const BoxDecoration(
                color: Color(0xFF1A2332),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(2, 0),
                  ),
                ],
              ),
              child: _buildSidebar(),
            ),
            // Main content area with IndexedStack to preserve state
            Expanded(
              child: IndexedStack(
                index: _getScreenIndex(_selectedScreen),
                children: _screenCache.values.toList(),
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile layout with drawer
      final pages = [
        _screenCache['dashboard']!,
        _screenCache['loans']!,
        _screenCache['members']!,
        _screenCache['reports']!,
      ];

      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        drawer: _AdminDrawer(
          onNavigate: (screen) {
            Navigator.pop(context);
            setState(() => _selectedScreen = screen);
          },
          onLogout: () => _confirmLogout(context),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
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
  }

  int _getScreenIndex(String screenKey) {
    final keys = _screenCache.keys.toList();
    final index = keys.indexOf(screenKey);
    if (kDebugMode) {
      print('🔍 _getScreenIndex: screenKey=$screenKey, index=$index, keys.length=${keys.length}');
      if (index == -1) {
        print('   ❌ Screen not found! Available keys: ${keys.take(20).join(", ")}...');
      }
    }
    return index == -1 ? 0 : index;
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // SACCO Plus Logo with elegant circular background
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  'assets/images/logo2.png',
                  fit: BoxFit.contain,
                ),
              ),
              
              const SizedBox(height: 14),
              
              // Administrator title
              Text(
                'Administrator',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              
              const SizedBox(height: 6),
              
              // Luganda slogan with better styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  AppConstants.appSubtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Admin badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Admin',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _drawerItem(Icons.dashboard_rounded, 'Dashboard', 'dashboard'),
              
              const SizedBox(height: 8),
              
              // MEMBERS SECTION - Collapsible
              _buildExpansionSection(
                'Members',
                Icons.people_rounded,
                [
                  {'icon': Icons.people_rounded, 'label': 'All Members', 'route': 'members'},
                  {'icon': Icons.person_search_rounded, 'label': 'Member 360', 'route': 'member_360'},
                  {'icon': Icons.verified_user_rounded, 'label': 'KYC & Verification', 'route': 'kyc'},
                  {'icon': Icons.account_box_rounded, 'label': 'Dormant Accounts', 'route': 'dormant'},
                ],
              ),
              
              // SAVINGS & SHARES SECTION - Collapsible
              _buildExpansionSection(
                'Savings & Shares',
                Icons.savings_rounded,
                [
                  {'icon': Icons.savings_rounded, 'label': 'Savings Management', 'route': 'savings'},
                  {'icon': Icons.pie_chart_rounded, 'label': 'Shares Management', 'route': 'shares'},
                  {'icon': Icons.account_balance_rounded, 'label': 'Fixed Deposits', 'route': 'fixed_deposits'},
                  {'icon': Icons.card_giftcard_rounded, 'label': 'Dividends', 'route': 'dividends'},
                ],
              ),
              
              // LOANS SECTION - Collapsible
              _buildExpansionSection(
                'Loans',
                Icons.account_tree_rounded,
                [
                  {'icon': Icons.add_card_rounded, 'label': 'Create & Disburse Loan', 'route': 'create_loan'},
                  {'icon': Icons.fact_check_rounded, 'label': 'Loan Applications', 'route': 'loans'},
                  {'icon': Icons.account_tree_rounded, 'label': 'Loan Portfolio', 'route': 'loan_portfolio'},
                  {'icon': Icons.inventory_2_rounded, 'label': 'Loan Products', 'route': 'loan_products'},
                  {'icon': Icons.calculate_rounded, 'label': 'Loan Calculator', 'route': 'loan_calc'},
                  {'icon': Icons.payment_rounded, 'label': 'Collections', 'route': 'collections'},
                  {'icon': Icons.warning_amber_rounded, 'label': 'Arrears Management', 'route': 'arrears'},
                  {'icon': Icons.gavel_rounded, 'label': 'Risk & Provisioning', 'route': 'risk_provision'},
                ],
              ),
              
              // PAYMENTS SECTION - Collapsible
              _buildExpansionSection(
                'Payments',
                Icons.point_of_sale_rounded,
                [
                  {'icon': Icons.point_of_sale_rounded, 'label': 'Teller Operations', 'route': 'teller'},
                  {'icon': Icons.hub_rounded, 'label': 'Payment Hub', 'route': 'payment_hub'},
                  {'icon': Icons.phone_android_rounded, 'label': 'Mobile Money', 'route': 'mobile_money'},
                  {'icon': Icons.transform_rounded, 'label': 'Bank Transfers', 'route': 'bank_transfers'},
                  {'icon': Icons.sync_rounded, 'label': 'Reconciliation', 'route': 'reconciliation'},
                ],
              ),
              
              // FINANCE SECTION - Collapsible
              _buildExpansionSection(
                'Finance',
                Icons.account_balance_wallet_rounded,
                [
                  {'icon': Icons.account_balance_wallet_rounded, 'label': 'Cash & Bank', 'route': 'cash_bank'},
                  {'icon': Icons.receipt_long_rounded, 'label': 'Income', 'route': 'income'},
                  {'icon': Icons.money_off_rounded, 'label': 'Expenses', 'route': 'expenses'},
                  {'icon': Icons.book_rounded, 'label': 'General Ledger', 'route': 'ledger'},
                  {'icon': Icons.assessment_rounded, 'label': 'Financial Reports', 'route': 'financial_reports'},
                  {'icon': Icons.upload_file_rounded, 'label': 'Migrate Shares', 'route': 'migrate_shares'},
                  {'icon': Icons.account_balance_rounded, 'label': 'Migrate Loans', 'route': 'migrate_loans'},
                ],
              ),
              
              // INTELLIGENCE SECTION - Collapsible
              _buildExpansionSection(
                'Intelligence',
                Icons.psychology_rounded,
                [
                  {'icon': Icons.shield_rounded, 'label': 'Risk Center', 'route': 'risk_center'},
                  {'icon': Icons.water_rounded, 'label': 'Liquidity Monitor', 'route': 'liquidity'},
                ],
              ),
              
              
              // OPERATIONS SECTION - Collapsible
              _buildExpansionSection(
                'Operations',
                Icons.settings_rounded,
                [
                  {'icon': Icons.badge_rounded, 'label': 'Staff Management', 'route': 'staff'},
                  {'icon': Icons.mail_rounded, 'label': 'Notifications', 'route': 'notifications'},
                ],
              ),
              
              // SYSTEM SECTION - Collapsible
              _buildExpansionSection(
                'System',
                Icons.settings_applications_rounded,
                [
                  {'icon': Icons.tune_rounded, 'label': 'Settings', 'route': 'settings'},
                  {'icon': Icons.history_rounded, 'label': 'Audit Trail', 'route': 'audit'},
                  {'icon': Icons.description_rounded, 'label': 'Reports', 'route': 'reports'},
                ],
              ),
              
              Divider(color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16, height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
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
    );
  }

  Widget _drawerItem(IconData icon, String label, String screenKey, {Color? color}) {
    final isSelected = _selectedScreen == screenKey;
    
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? ModernTheme.accent : (color ?? Colors.white70), size: 22),
        title: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 14,
                color: isSelected ? ModernTheme.accent : (color ?? Colors.white),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
        onTap: () => setState(() => _selectedScreen = screenKey),
        horizontalTitleGap: 8,
        dense: true,
        selected: isSelected,
        selectedTileColor: ModernTheme.accent.withOpacity(0.1),
        hoverColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Collapsible Expansion Section for Sidebar
  Widget _buildExpansionSection(String title, IconData icon, List<Map<String, dynamic>> items) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.white.withOpacity(0.05),
          highlightColor: Colors.white.withOpacity(0.05),
        ),
        child: ExpansionTile(
          leading: Icon(icon, color: Colors.white70, size: 22),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16),
          children: items.map((item) {
            final route = item['route'] as String;
            final isSelected = _selectedScreen == route;
            
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (kDebugMode) {
                    print('🎯 Sidebar item clicked: $route, current: $_selectedScreen');
                  }
                  setState(() {
                    _selectedScreen = route;
                    if (kDebugMode) {
                      print('✅ State updated: $_selectedScreen');
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFF4A90E2).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border(
                            left: BorderSide(
                              color: const Color(0xFF4A90E2),
                              width: 3,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 18,
                        color: isSelected 
                            ? const Color(0xFF4A90E2)
                            : Colors.white60,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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

// ─── Admin Drawer (Mobile) ────────────────────────────────────────────────────
class _AdminDrawer extends StatelessWidget {
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A2332),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // SACCO Plus Logo with elegant circular background
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/images/logo2.png',
                    fit: BoxFit.contain,
                  ),
                ),
                
                const SizedBox(height: 14),
                
                // Administrator title
                Text(
                  'Administrator',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Luganda slogan with better styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    AppConstants.appSubtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _drawerItem(Icons.dashboard_rounded, 'Dashboard', () => onNavigate('dashboard')),
                _drawerItem(Icons.point_of_sale_rounded, 'Teller', () => onNavigate('teller')),
                _drawerItem(Icons.fact_check_rounded, 'Loans', () => onNavigate('loans')),
                _drawerItem(Icons.account_tree_rounded, 'Portfolio', () => onNavigate('loan_portfolio')),
                _drawerItem(Icons.people_rounded, 'Members', () => onNavigate('members')),
                _drawerItem(Icons.assessment_rounded, 'Reports', () => onNavigate('financial_reports')),
                _drawerItem(Icons.history_rounded, 'Audit', () => onNavigate('audit')),
                Divider(color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
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

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
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
      ),
    );
  }
}

// ─── Admin Home Tab ───────────────────────────────────────────────────────────
class _AdminHomeTab extends StatefulWidget {
  final Function(String) onNavigate;
  
  const _AdminHomeTab({required this.onNavigate});

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab> {
  Map<String, int> _cachedStats = {
    'totalFarmers': 0, 'totalLoans': 0, 'pendingLoans': 0,
    'approvedLoans': 0, 'verifiedIds': 0, 'pendingIds': 0,
    'totalDisbursed': 0, 'totalRepaid': 0, 'outstanding': 0,
    'savingsTotal': 0, 'sharesTotal': 0, 'fixedDepositsTotal': 0,
  };
  bool _loading = true;
  List<Map<String, dynamic>> _recentLoans = [];
  List<Map<String, dynamic>> _monthlyData = [];
  Map<String, dynamic> _tellerData = {
    'totalDeposits': 0,
    'totalWithdrawals': 0,
    'depositCount': 0,
    'withdrawalCount': 0,
    'byTeller': {},
    'byAccountType': {},
    'recentTransactions': [],
  };
  Map<String, dynamic> _savingsData = {};
  List<Map<String, dynamic>> _depositTrends = [];
  Map<String, dynamic> _alerts = {};
  EnhancedMetrics? _enhancedMetrics;
  LoanRiskAnalysis? _riskAnalysis;
  LiquidityAnalysis? _liquidityAnalysis;
  
  // Chart time period selection
  String _selectedPeriod = 'Last 6 months';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = _cachedStats['totalLoans'] == 0);
    try {
      final tenantId = FirebaseService.sessionTenantId;
      final results = await Future.wait([
        FirebaseService.getAllLoansOnce(),
        FirebaseService.getAllFarmersOnce(),
        DashboardService.getSavingsSummary(),
        DashboardService.getTellerTransactionSummary(),
        DashboardService.getDepositWithdrawalTrends(days: 7),
        AlertsService.getAllAlerts(),
        EnhancedMetricsService().getEnhancedMetrics(tenantId),
        LoanRiskService().getLoanRiskAnalysis(tenantId),
        LiquidityService().getLiquidityAnalysis(tenantId),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⚠️  Dashboard: Load timeout after 30 seconds');
          // Return empty/default data on timeout
          return [
            <Map<String, dynamic>>[],
            <Map<String, dynamic>>[],
            <String, dynamic>{},
            <String, dynamic>{},
            <Map<String, dynamic>>[],
            <String, dynamic>{'total': 0, 'byType': {}},
            EnhancedMetrics(
              par30Rate: 0,
              par60Rate: 0,
              par90Rate: 0,
              par30Amount: 0,
              par60Amount: 0,
              par90Amount: 0,
              totalPortfolioValue: 0,
              totalLoans: 0,
              portfolioHealthScore: 0,
              healthStatus: 'Unknown',
              memberGrowthRate: 0,
              newMembers30Days: 0,
              totalMembers: 0,
              collectionEfficiency: 0,
              totalCollected30Days: 0,
              liquidityRatio: 0,
              totalCash: 0,
            ),
            LoanRiskAnalysis(
              totalLoans: 0,
              totalPortfolio: 0,
              performingCount: 0,
              watchCount: 0,
              substandardCount: 0,
              doubtfulCount: 0,
              lossCount: 0,
              performingAmount: 0,
              watchAmount: 0,
              substandardAmount: 0,
              doubtfulAmount: 0,
              lossAmount: 0,
              performingPercent: 0,
              watchPercent: 0,
              substandardPercent: 0,
              doubtfulPercent: 0,
              lossPercent: 0,
              currentCount: 0,
              aging1_30Count: 0,
              aging31_60Count: 0,
              aging61_90Count: 0,
              aging91_180Count: 0,
              aging180PlusCount: 0,
              currentAmount: 0,
              aging1_30Amount: 0,
              aging31_60Amount: 0,
              aging61_90Amount: 0,
              aging91_180Amount: 0,
              aging180PlusAmount: 0,
              riskScore: 0,
              highRiskLoans: [],
            ),
            LiquidityAnalysis(
              currentCashPosition: 0,
              totalDeposits: 0,
              totalWithdrawals: 0,
              activeLoanBalance: 0,
              totalLoansDisbursed: 0,
              last7DaysDeposits: 0,
              last7DaysWithdrawals: 0,
              last7DaysRepayments: 0,
              avgDailyInflow: 0,
              avgDailyOutflow: 0,
              netDailyFlow: 0,
              liquidityRatio: 0,
              cashCoverageDays: 0,
              liquidityStatus: 'Unknown',
              isHealthy: false,
              recommendation: 'Data unavailable',
              forecast: [],
              alerts: [],
            ),
          ];
        },
      );
      final loans = results[0] as List<Map<String, dynamic>>;
      final farmers = results[1] as List<Map<String, dynamic>>;
      final savingsData = results[2] as Map<String, dynamic>;
      final tellerData = results[3] as Map<String, dynamic>;
      final depositTrends = results[4] as List<Map<String, dynamic>>;
      final alerts = results[5] as Map<String, dynamic>;
      final enhancedMetrics = results[6] as EnhancedMetrics;
      final riskAnalysis = results[7] as LoanRiskAnalysis;
      final liquidityAnalysis = results[8] as LiquidityAnalysis;

      int pending = 0, approved = 0, verifiedIds = 0, pendingIds = 0;
      int totalDisbursed = 0, totalRepaid = 0, outstanding = 0, overdueAmount = 0;
      
      final now = DateTime.now();
      
      for (final d in loans) {
        final status = d['status'] as String? ?? '';
        final amount = (d['amount'] as num?)?.toInt() ?? 0;
        final repaid = (d['totalRepaid'] as num?)?.toInt() ?? 0;
        final dueDate = d['dueDate'];
        
        if (status == AppConstants.statusPending) pending++;
        if (status == AppConstants.statusApproved) {
          approved++;
          totalDisbursed += amount;
          totalRepaid += repaid;
          outstanding += (amount - repaid);
          
          // Check if overdue: due date passed and not fully repaid
          if (dueDate != null) {
            DateTime? due;
            if (dueDate is Timestamp) {
              due = dueDate.toDate();
            } else if (dueDate is DateTime) {
              due = dueDate;
            }
            
            if (due != null && due.isBefore(now) && repaid < amount) {
              overdueAmount += (amount - repaid);
            }
          }
        }
        if (status == AppConstants.statusPaid) {
          totalDisbursed += amount;
          totalRepaid += amount;
        }
      }
      
      for (final d in farmers) {
        final idStatus = d['idStatus'] as String? ?? '';
        if (idStatus == 'approved') verifiedIds++;
        if (idStatus == 'pending') pendingIds++;
      }

      // Get recent loans for activity
      _recentLoans = loans.take(5).toList();

      // Generate monthly data for charts (last 6 months)
      _monthlyData = _generateMonthlyData(loans);

      if (!mounted) return;
      setState(() {
        _cachedStats = {
          'totalFarmers': farmers.length,
          'totalLoans': loans.length,
          'pendingLoans': pending,
          'approvedLoans': approved,
          'verifiedIds': verifiedIds,
          'pendingIds': pendingIds,
          'totalDisbursed': totalDisbursed,
          'totalRepaid': totalRepaid,
          'outstanding': outstanding,
          'overdueAmount': overdueAmount,
          'savingsTotal': savingsData['totalSavings'] ?? 0,
          'sharesTotal': savingsData['totalShares'] ?? 0,
          'fixedDepositsTotal': 0,
        };
        _tellerData = tellerData;
        _savingsData = savingsData;
        _depositTrends = depositTrends;
        _alerts = alerts;
        _enhancedMetrics = enhancedMetrics;
        _riskAnalysis = riskAnalysis;
        _liquidityAnalysis = liquidityAnalysis;
        _loading = false;
      });
    } catch (e) {
      print('❌ Dashboard: Error loading data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildActionRequiredSection(bool isDesktop) {
    // Build alert items from real data only
    final actionItems = <Map<String, dynamic>>[];
    
    // Overdue loans
    final overdueCount = _alerts['overdueLoans']?['count'] ?? 0;
    if (overdueCount > 0) {
      actionItems.add({
        'severity': 'critical',
        'icon': Icons.error_outline,
        'title': 'loans are overdue',
        'count': overdueCount,
        'action': 'view_overdue_loans',
      });
    }
    
    // Pending loan approvals
    final pendingLoansCount = _alerts['pendingLoanApprovals']?['count'] ?? 0;
    if (pendingLoansCount > 0) {
      actionItems.add({
        'severity': 'warning',
        'icon': Icons.pending_actions,
        'title': 'loan applications awaiting approval',
        'count': pendingLoansCount,
        'action': 'view_pending_loans',
      });
    }
    
    // Pending KYC
    final pendingKYCCount = _alerts['pendingKYC']?['count'] ?? 0;
    if (pendingKYCCount > 0) {
      actionItems.add({
        'severity': 'warning',
        'icon': Icons.badge_outlined,
        'title': 'members have incomplete KYC',
        'count': pendingKYCCount,
        'action': 'view_kyc',
      });
    }
    
    // Liquidity warnings
    final liquidityStatus = _alerts['liquidityStatus']?['status'] ?? 'healthy';
    if (liquidityStatus == 'caution' || liquidityStatus == 'critical') {
      actionItems.add({
        'severity': liquidityStatus == 'critical' ? 'critical' : 'warning',
        'icon': Icons.water_drop_outlined,
        'title': _alerts['liquidityStatus']?['message'] ?? 'liquidity needs attention',
        'count': 1,
        'action': 'view_liquidity',
      });
    }
    
    // Failed transactions
    final failedTxnCount = _alerts['failedTransactions']?['count'] ?? 0;
    if (failedTxnCount > 0) {
      actionItems.add({
        'severity': 'critical',
        'icon': Icons.cancel_outlined,
        'title': 'failed payment transactions',
        'count': failedTxnCount,
        'action': 'view_failed_payments',
      });
    }

    // If no alerts, don't show the section
    if (actionItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Required',
                      style: GoogleFonts.poppins(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    Text(
                      '${actionItems.length} item${actionItems.length == 1 ? '' : 's'} need your attention',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View all',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...actionItems.map((item) => _buildEnhancedAlertItem(item, isDesktop)).toList(),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildEnhancedAlertItem(Map<String, dynamic> item, bool isDesktop) {
    final severity = item['severity'] as String;
    final icon = item['icon'] as IconData;
    final title = item['title'] as String;
    final count = item['count'] as int;
    final action = item['action'] as String;

    Color severityColor;
    Color bgColor;
    
    switch (severity) {
      case 'critical':
        severityColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEE2E2);
        break;
      case 'warning':
        severityColor = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFEF3C7);
        break;
      default:
        severityColor = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFDBEAFE);
    }

    return GestureDetector(
      onTap: () => _handleAlertAction(action),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 16 : 12,
          vertical: isDesktop ? 14 : 12,
        ),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: severityColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: severityColor, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: severityColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: severityColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert, bool isDesktop) {
    final severity = alert['severity'] as String? ?? 'low';
    final message = alert['message'] as String? ?? '';
    final action = alert['action'] as String?;

    Color severityColor;
    IconData severityIcon;
    
    switch (severity) {
      case 'critical':
        severityColor = const Color(0xFFDC2626);
        severityIcon = Icons.error;
        break;
      case 'high':
        severityColor = const Color(0xFFEF4444);
        severityIcon = Icons.warning;
        break;
      case 'medium':
        severityColor = const Color(0xFFF59E0B);
        severityIcon = Icons.info;
        break;
      default:
        severityColor = const Color(0xFF3B82F6);
        severityIcon = Icons.info_outline;
    }

    return GestureDetector(
      onTap: action != null ? () => _handleAlertAction(action) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isDesktop ? 14 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: severityColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(severityIcon, color: severityColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ),
            if (action != null)
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _handleAlertAction(String action) {
    // Navigate to relevant screen by changing _selectedScreen (stay inside dashboard)
    switch (action) {
      case 'view_pending_loans':
        widget.onNavigate('loans');
        break;
      case 'view_overdue_loans':
        widget.onNavigate('loan_portfolio');
        break;
      case 'view_pending_kyc':
        widget.onNavigate('kyc');
        break;
      case 'view_liquidity':
        widget.onNavigate('liquidity');
        break;
    }
  }

  List<Map<String, dynamic>> _generateMonthlyData(List<Map<String, dynamic>> loans) {
    final now = DateTime.now();
    final monthlyData = <Map<String, dynamic>>[];
    
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthLoans = loans.where((loan) {
        final createdAt = (loan['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            createdAt.year == month.year &&
            createdAt.month == month.month;
      }).length;
      
      monthlyData.add({
        'month': DateFormat('MMM').format(month),
        'loans': monthLoans,
      });
    }
    
    return monthlyData;
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody(context, _cachedStats);
  }

  Widget _buildBody(BuildContext context, Map<String, int> stats) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF5F7FA), // Light gray background like reference
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title
            Container(
              padding: EdgeInsets.all(isDesktop ? 20 : 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MBADIFA SACCO',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: isDesktop ? 24 : 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants.appSubtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: isDesktop ? 14 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: _load,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 24 : 16),

            // ACTION REQUIRED CENTER
            if (_alerts.isNotEmpty && _alerts['totalAlerts'] > 0)
              _buildActionRequiredSection(isDesktop),

            SizedBox(height: isDesktop ? 24 : 16),

            // Professional Metric Cards Grid (12 cards)
            _buildProfessionalMetricsGrid(stats, isDesktop),

            SizedBox(height: isDesktop ? 20 : 16),

            // PAR (Portfolio at Risk) Indicators
            _buildPARIndicators(_enhancedMetrics, isDesktop),

            SizedBox(height: isDesktop ? 24 : 16),

            // Three Charts Row
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monthly Disbursements Chart
                      Expanded(
                        flex: 2,
                        child: _buildMonthlyChart(),
                      ),
                      const SizedBox(width: 16),
                      // Loan Trends Line Chart
                      Expanded(
                        flex: 2,
                        child: _buildLoanTrendsChart(),
                      ),
                      const SizedBox(width: 16),
                      // Loan Status Pie Chart
                      Expanded(
                        child: _buildLoanStatusChart(stats),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildMonthlyChart(),
                      const SizedBox(height: 16),
                      _buildLoanTrendsChart(),
                      const SizedBox(height: 16),
                      _buildLoanStatusChart(stats),
                    ],
                  ),

            SizedBox(height: isDesktop ? 24 : 16),

            // Teller Operations Summary
            Text(
              'TELLER OPERATIONS',
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E3A5F),
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: isDesktop ? 16 : 12),

            // Recent Transactions by Teller (Simple version)
            _buildSimpleRecentTransactions(),

            SizedBox(height: isDesktop ? 24 : 16),

            // Bottom Section - Recent Activity and Quick Stats
            isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildRecentActivityCard(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildQuickStatsCard(stats),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildRecentActivityCard(),
                      const SizedBox(height: 16),
                      _buildQuickStatsCard(stats),
                    ],
                  ),

            SizedBox(height: isDesktop ? 24 : 16),

            // ========== NEW PHASE 1 COMMAND CENTER SECTIONS (TEMPORARILY DISABLED) ==========
            // TODO: Fix layout issues and re-enable
            /*
            // Enhanced Portfolio Health Metrics
            if (_enhancedMetrics != null) ...[
              Text(
                'PORTFOLIO HEALTH METRICS',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1E3A5F),
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: isDesktop ? 16 : 12),
              EnhancedMetricsCard(
                metrics: _enhancedMetrics!,
                onTap: () {},
              ),
              SizedBox(height: isDesktop ? 24 : 16),
            ],

            // Enhanced Metrics Compact Cards Grid
            if (_enhancedMetrics != null && _riskAnalysis != null && _liquidityAnalysis != null) ...[
              isDesktop
                  ? Row(
                      children: [
                        Expanded(
                          child: EnhancedMetricsCompactCard(
                            title: 'Portfolio Health',
                            value: '${_enhancedMetrics!.portfolioHealthScore.toStringAsFixed(0)}/100',
                            subtitle: _enhancedMetrics!.healthStatus,
                            icon: Icons.health_and_safety,
                            color: _getHealthColor(_enhancedMetrics!.portfolioHealthScore),
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EnhancedMetricsCompactCard(
                            title: 'Loan Risk Center',
                            value: '${_riskAnalysis!.riskScore.toStringAsFixed(0)}/100',
                            subtitle: _getRiskLabel(_riskAnalysis!.riskScore),
                            icon: Icons.shield,
                            color: _getRiskColor(_riskAnalysis!.riskScore),
                            onTap: () {
                              setState(() => _selectedScreen = 'risk_center');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EnhancedMetricsCompactCard(
                            title: 'Liquidity Monitor',
                            value: _liquidityAnalysis!.liquidityStatus,
                            subtitle: '${_liquidityAnalysis!.liquidityRatio.toStringAsFixed(1)}% ratio',
                            icon: Icons.water_drop,
                            color: _getLiquidityColor(_liquidityAnalysis!.liquidityStatus),
                            onTap: () {
                              setState(() => _selectedScreen = 'liquidity');
                            },
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        EnhancedMetricsCompactCard(
                          title: 'Portfolio Health',
                          value: '${_enhancedMetrics!.portfolioHealthScore.toStringAsFixed(0)}/100',
                          subtitle: _enhancedMetrics!.healthStatus,
                          icon: Icons.health_and_safety,
                          color: _getHealthColor(_enhancedMetrics!.portfolioHealthScore),
                          onTap: () {},
                        ),
                        const SizedBox(height: 12),
                        EnhancedMetricsCompactCard(
                          title: 'Loan Risk Center',
                          value: '${_riskAnalysis!.riskScore.toStringAsFixed(0)}/100',
                          subtitle: _getRiskLabel(_riskAnalysis!.riskScore),
                          icon: Icons.shield,
                          color: _getRiskColor(_riskAnalysis!.riskScore),
                          onTap: () {
                            widget.onNavigate('risk_center');
                          },
                        ),
                        const SizedBox(height: 12),
                        EnhancedMetricsCompactCard(
                          title: 'Liquidity Monitor',
                          value: _liquidityAnalysis!.liquidityStatus,
                          subtitle: '${_liquidityAnalysis!.liquidityRatio.toStringAsFixed(1)}% ratio',
                          icon: Icons.water_drop,
                          color: _getLiquidityColor(_liquidityAnalysis!.liquidityStatus),
                          onTap: () {
                            widget.onNavigate('liquidity');
                          },
                        ),
                      ],
                    ),
              SizedBox(height: isDesktop ? 24 : 16),
            ],
            */

            // Bottom Info Cards
            _buildBottomStatsRow(stats, isDesktop),
          ],
        ),
      ),
    );
  }

  // Professional Metrics Grid with 12 cards
  Widget _buildProfessionalMetricsGrid(Map<String, dynamic> stats, bool isDesktop) {
    final totalAssets = (stats['outstanding'] ?? 0) + (_savingsData['totalBalance'] ?? 0);
    final totalSavings = _savingsData['totalBalance'] ?? 0;
    
    // Get real shares from savings data
    final totalShares = (_savingsData['totalShares'] ?? 0).toDouble();
    
    final totalLoansOutstanding = stats['outstanding'] ?? 0;
    final activeLoans = stats['approvedLoans'] ?? 0;
    final totalDisbursed = stats['totalDisbursed'] ?? 0;
    final totalRepaid = stats['totalRepaid'] ?? 0;
    
    // Calculate balances from teller data and account types
    final byAccountType = _tellerData['byAccountType'] as Map<String, dynamic>? ?? {};
    final netFlow = _tellerData['netFlow'] ?? 0;
    
    // Estimate cash balance as net flow (could be refined with actual balance tracking)
    final cashBalance = (byAccountType['cash'] ?? netFlow * 0.4).toDouble();
    final bankBalance = (byAccountType['bank'] ?? netFlow * 0.5).toDouble();
    final mobileMoneyBalance = (byAccountType['mobile_money'] ?? netFlow * 0.1).toDouble();
    
    // Calculate available liquidity as sum of all liquid assets
    final availableLiquidity = cashBalance + bankBalance + mobileMoneyBalance;
    
    // Calculate overdue amount: loans where dueDate has passed and amount not fully repaid
    final overdueAmount = (stats['overdueAmount'] ?? 0).toDouble();

    final metrics = [
      {
        'label': 'Total Assets',
        'value': 'UGX ${NumberFormat('#,###').format(totalAssets)}',
        'icon': Icons.account_balance_wallet,
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'Total Savings',
        'value': 'UGX ${NumberFormat('#,###').format(totalSavings)}',
        'icon': Icons.savings,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Total Shares',
        'value': 'UGX ${NumberFormat('#,###').format(totalShares)}',
        'icon': Icons.pie_chart,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'Total Loans Outstanding',
        'value': 'UGX ${NumberFormat('#,###').format(totalLoansOutstanding)}',
        'icon': Icons.trending_up,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Active Loans',
        'value': '$activeLoans',
        'icon': Icons.list_alt,
        'color': const Color(0xFF06B6D4),
      },
      {
        'label': 'Total Disbursed',
        'value': 'UGX ${NumberFormat('#,###').format(totalDisbursed)}',
        'icon': Icons.payment,
        'color': const Color(0xFF14B8A6),
      },
      {
        'label': 'Total Repaid',
        'value': 'UGX ${NumberFormat('#,###').format(totalRepaid)}',
        'icon': Icons.check_circle,
        'color': const Color(0xFF22C55E),
      },
      {
        'label': 'Available Liquidity',
        'value': 'UGX ${NumberFormat('#,###').format(availableLiquidity)}',
        'icon': Icons.water_drop,
        'color': const Color(0xFF0EA5E9),
      },
      {
        'label': 'Cash Balance',
        'value': 'UGX ${NumberFormat('#,###').format(cashBalance)}',
        'icon': Icons.money,
        'color': const Color(0xFF84CC16),
      },
      {
        'label': 'Bank Balance',
        'value': 'UGX ${NumberFormat('#,###').format(bankBalance)}',
        'icon': Icons.account_balance,
        'color': const Color(0xFF6366F1),
      },
      {
        'label': 'Mobile Money Balance',
        'value': 'UGX ${NumberFormat('#,###').format(mobileMoneyBalance)}',
        'icon': Icons.phone_android,
        'color': const Color(0xFFA855F7),
      },
      {
        'label': 'Overdue Amount',
        'value': 'UGX ${NumberFormat('#,###').format(overdueAmount)}',
        'icon': Icons.warning,
        'color': const Color(0xFFEF4444),
      },
    ];

    if (isDesktop) {
      // Desktop: 4 columns grid
      return Column(
        children: [
          Row(
            children: metrics.sublist(0, 4).map((m) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildProfessionalMetricCard(m),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: metrics.sublist(4, 8).map((m) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildProfessionalMetricCard(m),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: metrics.sublist(8, 12).map((m) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildProfessionalMetricCard(m),
              ),
            )).toList(),
          ),
        ],
      );
    } else {
      // Mobile: 2 columns grid
      return Column(
        children: [
          for (int i = 0; i < metrics.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(child: _buildProfessionalMetricCard(metrics[i])),
                  const SizedBox(width: 12),
                  if (i + 1 < metrics.length)
                    Expanded(child: _buildProfessionalMetricCard(metrics[i + 1])),
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _buildProfessionalMetricCard(Map<String, dynamic> metric) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (metric['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  metric['icon'] as IconData,
                  color: metric['color'] as Color,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            metric['label'] as String,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric['value'] as String,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  // PAR (Portfolio at Risk) Indicators
  Widget _buildPARIndicators(EnhancedMetrics? metrics, bool isDesktop) {
    final par30 = metrics?.par30Rate ?? 2.4;
    final par60 = metrics?.par60Rate ?? 1.2;
    final par90 = metrics?.par90Rate ?? 0.6;

    final parData = [
      {'label': 'PAR 30', 'value': par30, 'target': 5.0},
      {'label': 'PAR 60', 'value': par60, 'target': 3.0},
      {'label': 'PAR 90', 'value': par90, 'target': 2.0},
    ];

    Color _getParColor(double value, double target) {
      if (value <= target * 0.5) return Colors.green;
      if (value <= target * 0.75) return Colors.lightGreen;
      if (value <= target) return Colors.orange;
      return Colors.red;
    }

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: parData.map((par) {
            final color = _getParColor(par['value'] as double, par['target'] as double);
            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        par['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(par['value'] as double).toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        'Target: ${(par['target'] as double).toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  if (parData.indexOf(par) < parData.length - 1) ...[
                    const Spacer(),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      );
    } else {
      // Mobile layout
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: parData.map((par) {
            final color = _getParColor(par['value'] as double, par['target'] as double);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    par['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(par['value'] as double).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }
  }

  // Top stat card matching reference design
  Widget _buildTopStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E3A5F),
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // Monthly bar chart with enhanced header
  Widget _buildMonthlyChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disbursements Over Time (Monthly)',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E3A5F),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total loan disbursements by month',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    isDense: true,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF1E3A5F),
                    ),
                    items: ['Last 6 months', 'Last 12 months', 'Year to date']
                        .map((period) => DropdownMenuItem(
                              value: period,
                              child: Text(period),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPeriod = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: _monthlyData.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _monthlyData.map((e) => (e['loans'] as int).toDouble()).reduce((a, b) => a > b ? a : b) + 5,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _monthlyData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _monthlyData[value.toInt()]['month'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
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
                                  fontSize: 10,
                                  color: Colors.grey[600],
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
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(
                        _monthlyData.length,
                        (index) => BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: (_monthlyData[index]['loans'] as int).toDouble(),
                              color: const Color(0xFF1E3A5F),
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Loan trends line chart
  Widget _buildLoanTrendsChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'LOAN APPLICATIONS OVER TIME (Monthly)',
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: _monthlyData.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 50,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _monthlyData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _monthlyData[value.toInt()]['month'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
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
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            _monthlyData.length,
                            (index) => FlSpot(
                              index.toDouble(),
                              (_monthlyData[index]['loans'] as int).toDouble(),
                            ),
                          ),
                          isCurved: true,
                          color: const Color(0xFF2C5282),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: const Color(0xFF2C5282),
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF2C5282).withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Pie chart for loan status
  Widget _buildLoanStatusChart(Map<String, int> stats) {
    final approved = stats['approvedLoans'] ?? 0;
    final pending = stats['pendingLoans'] ?? 0;
    final total = stats['totalLoans'] ?? 1;
    final others = total - approved - pending;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'LOANS BY STATUS',
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: approved.toDouble(),
                    title: '${(approved / total * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF1E3A5F),
                    radius: 60,
                    titleStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: pending.toDouble(),
                    title: '${(pending / total * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF5B8CC6),
                    radius: 60,
                    titleStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (others > 0)
                    PieChartSectionData(
                      value: others.toDouble(),
                      title: '${(others / total * 100).toStringAsFixed(1)}%',
                      color: const Color(0xFFB0C4DE),
                      radius: 60,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendItem('Approved', const Color(0xFF1E3A5F), approved),
          const SizedBox(height: 8),
          _buildLegendItem('Pending', const Color(0xFF5B8CC6), pending),
          if (others > 0) ...[
            const SizedBox(height: 8),
            _buildLegendItem('Others', const Color(0xFFB0C4DE), others),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
        const Spacer(),
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  // Recent activity card
  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'RECENT LOAN APPLICATIONS',
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_recentLoans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No recent loans',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
            )
          else
            ...List.generate(
              _recentLoans.length > 5 ? 5 : _recentLoans.length,
              (index) {
                final loan = _recentLoans[index];
                final amount = (loan['amount'] as num?)?.toInt() ?? 0;
                final status = loan['status'] as String? ?? 'pending';
                final farmerName = loan['farmerName'] as String? ?? 'Unknown';
                
                // ⏰ Calculate overdue days
                int? overdueDays;
                final dueDate = loan['dueDate'];
                final repaid = (loan['totalRepaid'] as num?)?.toInt() ?? 0;
                
                if (dueDate != null && repaid < amount) {
                  DateTime? due;
                  if (dueDate is Timestamp) {
                    due = dueDate.toDate();
                  } else if (dueDate is DateTime) {
                    due = dueDate;
                  }
                  
                  if (due != null && due.isBefore(DateTime.now())) {
                    overdueDays = DateTime.now().difference(due).inDays;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          overdueDays != null && overdueDays > 0
                              ? Icons.warning_amber_rounded
                              : Icons.receipt_long_rounded,
                          color: overdueDays != null && overdueDays > 0
                              ? Colors.red
                              : _getStatusColor(status),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farmerName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  'UGX ${NumberFormat('#,###').format(amount)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (overdueDays != null && overdueDays > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$overdueDays days overdue',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Quick stats card
  Widget _buildQuickStatsCard(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'LOAN PORTFOLIO BREAKDOWN',
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildPortfolioBar('Total Disbursed', stats['totalDisbursed'] ?? 0, const Color(0xFF1E3A5F)),
          const SizedBox(height: 12),
          _buildPortfolioBar('Total Repaid', stats['totalRepaid'] ?? 0, const Color(0xFF5B8CC6)),
          const SizedBox(height: 12),
          _buildPortfolioBar('Outstanding', stats['outstanding'] ?? 0, const Color(0xFF87CEEB)),
        ],
      ),
    );
  }

  Widget _buildPortfolioBar(String label, int value, Color color) {
    final maxValue = _cachedStats.values.reduce((a, b) => a > b ? a : b).toDouble();
    final percentage = maxValue > 0 ? (value / maxValue * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
            Text(
              'UGX ${NumberFormat('#,###').format(value)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Deposits & Withdrawals Trend Chart
  Widget _buildDepositWithdrawalChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            children: [
              Icon(Icons.trending_up_rounded, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'DEPOSITS & WITHDRAWALS (Last 7 Days)',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Total Deposits: UGX ${DashboardService.formatAmount((_tellerData['totalDeposits'] as int?) ?? 0)}',
                style: GoogleFonts.poppins(
                  color: Colors.green[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Total Withdrawals: UGX ${DashboardService.formatAmount((_tellerData['totalWithdrawals'] as int?) ?? 0)}',
                style: GoogleFonts.poppins(
                  color: Colors.red[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: _depositTrends.isEmpty
                ? Center(
                    child: Text(
                      'No transaction data available',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _depositTrends.isEmpty
                          ? 100
                          : () {
                              double maxVal = 0;
                              for (var trend in _depositTrends) {
                                final deposits = ((trend['deposits'] as num?) ?? 0).toDouble();
                                final withdrawals = ((trend['withdrawals'] as num?) ?? 0).toDouble();
                                if (deposits > maxVal) maxVal = deposits;
                                if (withdrawals > maxVal) maxVal = withdrawals;
                              }
                              return maxVal + 50000;
                            }(),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            if (group.x.toInt() >= _depositTrends.length) return null;
                            final trendData = _depositTrends[group.x.toInt()];
                            final date = trendData['date'] as DateTime?;
                            if (date == null) return null;
                            final amount = rod.toY.toInt();
                            final type = rodIndex == 0 ? 'Deposits' : 'Withdrawals';
                            return BarTooltipItem(
                              '${DateFormat('MMM d').format(date)}\n',
                              GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              children: [
                                TextSpan(
                                  text: '$type\nUGX ${DashboardService.formatAmount(amount)}',
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                                ),
                              ],
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
                              if (value.toInt() >= 0 && value.toInt() < _depositTrends.length) {
                                final date = _depositTrends[value.toInt()]['date'] as DateTime?;
                                if (date == null) return const Text('');
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MMM d').format(date),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 55,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                DashboardService.formatAmount(value.toInt()),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.grey[600],
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
                        horizontalInterval: 50000,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(
                        _depositTrends.length,
                        (index) {
                          final deposits = ((_depositTrends[index]['deposits'] as num?) ?? 0).toDouble();
                          final withdrawals = ((_depositTrends[index]['withdrawals'] as num?) ?? 0).toDouble();
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: deposits,
                                color: Colors.green[600]!,
                                width: 12,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                              BarChartRodData(
                                toY: withdrawals,
                                color: Colors.red[600]!,
                                width: 12,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          );
                        },
                      ),
                      groupsSpace: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Deposits', Colors.green[600]!, (_tellerData['depositCount'] as int?) ?? 0),
              const SizedBox(width: 24),
              _buildLegendItem('Withdrawals', Colors.red[600]!, (_tellerData['withdrawalCount'] as int?) ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  // Transactions by Account Type Pie Chart
  Widget _buildTransactionsByTypeChart() {
    final byAccountType = _tellerData['byAccountType'] as Map<String, int>? ?? {};
    final total = byAccountType.values.fold(0, (sum, val) => sum + val);

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              'BY ACCOUNT TYPE',
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 60),
            Center(
              child: Text(
                'No data available',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final wallet = byAccountType['wallet'] ?? 0;
    final savings = byAccountType['savings'] ?? 0;
    final shares = byAccountType['shares'] ?? 0;

    final colors = {
      'wallet': const Color(0xFF1E3A5F),
      'savings': const Color(0xFF5B8CC6),
      'shares': const Color(0xFF87CEEB),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'BY ACCOUNT TYPE',
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  if (wallet > 0)
                    PieChartSectionData(
                      value: wallet.toDouble(),
                      title: '${(wallet / total * 100).toStringAsFixed(1)}%',
                      color: colors['wallet'],
                      radius: 60,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (savings > 0)
                    PieChartSectionData(
                      value: savings.toDouble(),
                      title: '${(savings / total * 100).toStringAsFixed(1)}%',
                      color: colors['savings'],
                      radius: 60,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (shares > 0)
                    PieChartSectionData(
                      value: shares.toDouble(),
                      title: '${(shares / total * 100).toStringAsFixed(1)}%',
                      color: colors['shares'],
                      radius: 60,
                      titleStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (wallet > 0) _buildLegendItem('Wallet', colors['wallet']!, wallet),
          if (wallet > 0 && (savings > 0 || shares > 0)) const SizedBox(height: 8),
          if (savings > 0) _buildLegendItem('Savings', colors['savings']!, savings),
          if (savings > 0 && shares > 0) const SizedBox(height: 8),
          if (shares > 0) _buildLegendItem('Shares', colors['shares']!, shares),
        ],
      ),
    );
  }

  // Recent Transactions by Teller
  Widget _buildRecentTransactionsByTeller() {
    final recentTxns = _tellerData['recentTransactions'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            children: [
              Icon(Icons.receipt_long_rounded, color: const Color(0xFF1E3A5F), size: 20),
              const SizedBox(width: 8),
              Text(
                'RECENT TELLER TRANSACTIONS',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentTxns.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No recent transactions',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentTxns.length > 10 ? 10 : recentTxns.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final txn = recentTxns[index];
                final type = txn['type'] as String? ?? '';
                final amount = txn['amount'] as int? ?? 0;
                final memberName = txn['memberName'] as String? ?? 'Unknown';
                final tellerName = txn['tellerName'] as String? ?? 'Unknown';
                final accountType = txn['accountType'] as String? ?? 'wallet';
                final timestamp = txn['timestamp'] as DateTime?;
                final receiptNumber = txn['receiptNumber'] as String? ?? '';

                final isDeposit = type == 'deposit';
                final icon = isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
                final color = isDeposit ? Colors.green[600]! : Colors.red[600]!;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          memberName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E3A5F),
                          ),
                        ),
                      ),
                      Text(
                        '${isDeposit ? '+' : '-'}UGX ${DashboardService.formatAmount(amount)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${isDeposit ? 'Deposit' : 'Withdrawal'} • $accountType • By: $tellerName',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (timestamp != null)
                        Text(
                          '${DateFormat('MMM d, yyyy • h:mm a').format(timestamp)} • $receiptNumber',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Simple Recent Transactions List (no complex charts)
  Widget _buildSimpleRecentTransactions() {
    final recentTxns = (_tellerData['recentTransactions'] as List<dynamic>?) ?? [];

    if (recentTxns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No recent teller transactions',
                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            children: [
              Icon(Icons.receipt_long_rounded, color: const Color(0xFF1E3A5F), size: 20),
              const SizedBox(width: 8),
              Text(
                'RECENT TELLER TRANSACTIONS',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTxns.length > 5 ? 5 : recentTxns.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final txn = recentTxns[index] as Map<String, dynamic>;
              final type = txn['type'] as String? ?? '';
              final amount = txn['amount'] as int? ?? 0;
              final memberName = txn['memberName'] as String? ?? 'Unknown';
              final tellerName = txn['tellerName'] as String? ?? 'Unknown';
              final accountType = txn['accountType'] as String? ?? 'wallet';
              final timestamp = txn['timestamp'] as DateTime?;

              final isDeposit = type == 'deposit';
              final icon = isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
              final color = isDeposit ? Colors.green[600]! : Colors.red[600]!;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        memberName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E3A5F),
                        ),
                      ),
                    ),
                    Text(
                      '${isDeposit ? '+' : '-'}UGX ${DashboardService.formatAmount(amount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${isDeposit ? 'Deposit' : 'Withdrawal'} • $accountType • By: $tellerName',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (timestamp != null)
                      Text(
                        DateFormat('MMM d, yyyy • h:mm a').format(timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Bottom stats row - Enhanced professional version
  Widget _buildBottomStatsRow(Map<String, int> stats, bool isDesktop) {
    final totalDisbursed = stats['totalDisbursed'] ?? 1;
    final totalRepaid = stats['totalRepaid'] ?? 0;
    final repaymentRate = totalDisbursed > 0 ? (totalRepaid / totalDisbursed * 100) : 0.0;
    final now = DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);

    final items = [
      {
        'icon': Icons.groups_rounded,
        'label': 'Total Members',
        'value': '${stats['totalFarmers'] ?? 6}',
        'subtitle': 'Unique members',
        'color': const Color(0xFF3B82F6),
        'showIndicator': false,
      },
      {
        'icon': Icons.trending_up_rounded,
        'label': 'Repayment Rate',
        'value': '${repaymentRate.toStringAsFixed(1)}%',
        'subtitle': '${repaymentRate >= 80 ? '+0.0%' : '-2.1%'}',
        'color': const Color(0xFF10B981),
        'showIndicator': true,
        'indicatorValue': '+0.0%',
        'indicatorColor': Colors.green,
      },
      {
        'icon': Icons.badge_outlined,
        'label': 'Pending KYC',
        'value': '${stats['pendingIds'] ?? 0}',
        'subtitle': '0% verification',
        'color': const Color(0xFFF59E0B),
        'showIndicator': false,
      },
      {
        'icon': Icons.update_rounded,
        'label': 'Data Refresh',
        'value': formattedDate,
        'subtitle': formattedTime,
        'color': const Color(0xFF8B5CF6),
        'showIndicator': true,
        'indicatorText': 'Live',
        'indicatorColor': Colors.green,
      },
    ];

    return isDesktop
        ? Row(
            children: items
                .map((item) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: _buildProfessionalBottomCard(item),
                      ),
                    ))
                .toList(),
          )
        : Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildProfessionalBottomCard(item),
                    ))
                .toList(),
          );
  }

  Widget _buildProfessionalBottomCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: item['color'] as Color,
                  size: 24,
                ),
              ),
              const Spacer(),
              if (item['showIndicator'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (item['indicatorColor'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item['indicatorText'] != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: item['indicatorColor'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        item['indicatorText'] as String? ?? item['indicatorValue'] as String? ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item['indicatorColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item['label'] as String,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item['value'] as String,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item['subtitle'] as String,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatCard(IconData icon, String label, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for Phase 1 Command Center features
  Color _getHealthColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  // Command Center Card Builder
  Widget _buildCommandCenterCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Portfolio Health Dialog
  void _showPortfolioHealthDialog() {
    if (_enhancedMetrics == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Portfolio Health Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMetricRow('PAR 30', '${_enhancedMetrics!.par30Rate.toStringAsFixed(2)}%'),
              _buildMetricRow('PAR 60', '${_enhancedMetrics!.par60Rate.toStringAsFixed(2)}%'),
              _buildMetricRow('PAR 90', '${_enhancedMetrics!.par90Rate.toStringAsFixed(2)}%'),
              const Divider(height: 24),
              _buildMetricRow('Collection Rate', '${_enhancedMetrics!.collectionEfficiency.toStringAsFixed(1)}%'),
              _buildMetricRow('Total Loans', '${_enhancedMetrics!.totalLoans}'),
              const Divider(height: 24),
              _buildMetricRow('Health Score', '${_enhancedMetrics!.portfolioHealthScore.toStringAsFixed(0)}/100'),
              _buildMetricRow('Status', _enhancedMetrics!.healthStatus),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700])),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Helper functions for Command Center
  String _getRiskLabel(double riskScore) {
    if (riskScore >= 80) return 'Low Risk';
    if (riskScore >= 60) return 'Moderate Risk';
    if (riskScore >= 40) return 'Medium Risk';
    if (riskScore >= 20) return 'High Risk';
    return 'Critical Risk';
  }

  Color _getRiskColor(double riskScore) {
    if (riskScore >= 80) return Colors.green;
    if (riskScore >= 60) return Colors.lightGreen;
    if (riskScore >= 40) return Colors.orange;
    if (riskScore >= 20) return Colors.deepOrange;
    return Colors.red;
  }

  Color _getLiquidityColor(String status) {
    switch (status) {
      case 'Healthy':
        return Colors.green;
      case 'Adequate':
        return Colors.lightGreen;
      case 'Warning':
        return Colors.orange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}


// ─── Placeholder Screen ───────────────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  
  const _PlaceholderScreen({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: const Color(0xFF4A90E2),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E3A5F),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This feature is under development',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

            ],
          ),
        ),
      ),
    );
  }
}

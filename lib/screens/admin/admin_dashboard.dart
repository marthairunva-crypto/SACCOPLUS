import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
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
import 'members_detailed_screen.dart';
import 'create_loan_screen.dart';
import 'loan_data_correction_screen.dart';
import 'reports_screen.dart';
import 'comprehensive_reports_screen.dart';
import 'teller_screen.dart';
import 'teller_center_reorganized.dart';
import 'till_management_screen.dart';
import 'till_reports_screen.dart';
import 'member_activation_screen.dart';
import 'enhanced_audit_screen.dart';
import 'loan_portfolio_screen.dart';
import 'admin_notification_screen.dart';
import 'fixed_deposits_admin_screen.dart';
import 'audit_log_screen.dart';
import 'savings_admin_screen.dart';
import 'shares_admin_screen.dart';
import 'savings_summary_screen.dart';
import 'sacco_settings_screen.dart';

import 'staff_management_screen.dart';
import 'dividend_distribution_screen.dart';
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
import 'loan_details_screen.dart';
import 'arrears_management_screen.dart';
import 'risk_provisioning_screen.dart';
import 'payment_screens.dart';
import 'finance_screens.dart';
import '../../scripts/reconcile_savings.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';
import 'admin_statement_preview.dart';
import 'statement_date_selector.dart';
import '../../services/member_statement_service.dart';
import 'admin_nav_panel.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _selectedScreen = 'dashboard';
  String? _selectedLoanId;
  Map<String, dynamic>? _selectedLoanData;
  bool? _navCollapsed; // null = follow window width

  // Statement state
  StatementResult? _pendingStatement;
  String _statementMemberName = '';
  String _statementMemberId = '';
  Map<String, dynamic>? _statementMemberData;
  DateTime? _statementFrom;
  DateTime? _statementTo;

  void _showStatementSelector(String memberId, String memberName, Map<String, dynamic> memberData) {
    setState(() {
      _statementMemberId = memberId;
      _statementMemberName = memberName;
      _statementMemberData = memberData;
      _pendingStatement = null;
      _selectedScreen = 'statement_selector';
    });
  }

  void _showStatement(StatementResult result, String memberName,
      DateTime from, DateTime to) {
    setState(() {
      _pendingStatement = result;
      _statementMemberName = memberName;
      _statementFrom = from;
      _statementTo = to;
      _selectedScreen = 'statement_preview';
    });
  }

  void _openLoan(String loanId, Map<String, dynamic>? loanData) {
    setState(() {
      _selectedLoanId = loanId;
      _selectedLoanData = loanData;
      _selectedScreen = 'loan_details';
    });
  }

  /// Builds ONLY the requested screen.
  ///
  /// Previously every screen (~40) was constructed and mounted at once inside
  /// an IndexedStack on desktop. Every setState rebuilt all of them, which is
  /// what triggered "_dependents.isEmpty", "Duplicate GlobalKey" and
  /// "dirty widget in the wrong build scope" when navigating back.
  Widget _buildScreen(String key) {
    switch (key) {
      case 'dashboard':
        return _AdminHomeTab(
          onNavigate: (screen) => setState(() => _selectedScreen = screen),
        );

      // MEMBERS
      case 'members':
        return const MembersDetailedScreen();
      case 'member_activation':
        return const MemberActivationScreen();
      case 'member_360':
        return Member360Screen(
          onShowStatement: _showStatementSelector,
        );
      case 'statement_selector':
        if (_statementMemberId.isEmpty || _statementMemberData == null) {
          return Member360Screen(onShowStatement: _showStatementSelector);
        }
        return StatementDateSelector(
          memberId: _statementMemberId,
          memberName: _statementMemberName,
          memberData: _statementMemberData!,
          onStatementGenerated: _showStatement,
        );
      case 'statement_preview':
        if (_pendingStatement == null) {
          return Member360Screen(onShowStatement: _showStatementSelector);
        }
        return AdminStatementPreview(
          pdfBytes: _pendingStatement!.bytes,
          filename: _pendingStatement!.filename,
          memberName: _statementMemberName,
          from: _statementFrom!,
          to: _statementTo!,
          onBack: () => setState(() => _selectedScreen = 'statement_selector'),
        );
      case 'kyc':
        return const KYCVerificationScreen();
      case 'dormant':
        return const DormantAccountsScreen();

      // SAVINGS & SHARES
      case 'savings':
        return const SavingsAdminScreen(embedded: true);
      case 'savings_summary':
        return const SavingsSummaryScreen(embedded: true);
      case 'shares':
        return const SharesAdminScreen(embedded: true);
      case 'fixed_deposits':
        return const FixedDepositsAdminScreen(embedded: true);
      case 'dividends':
        return const DividendDistributionScreen();

      // LOANS
      case 'loans':
        return LoanApprovalScreen(embedded: true, onLoanTap: _openLoan);
      case 'loan_details':
        return _selectedLoanId != null
            ? LoanDetailsScreen(
                // Key by loan id so opening a different loan fully resets state.
                key: ValueKey('loan_details_$_selectedLoanId'),
                loanId: _selectedLoanId!,
                initialLoanData: _selectedLoanData,
              )
            : const Center(child: Text('No loan selected'));
      case 'loan_portfolio':
        return const LoanPortfolioScreen(embedded: true);
      case 'create_loan':
        return const CreateLoanScreen();
      case 'loan_correction':
        return const LoanDataCorrectionScreenEnhanced();
      case 'loan_products':
        return const LoanProductsScreen();
      case 'loan_calc':
        return const LoanCalculatorScreen();
      case 'arrears':
        return const ArrearsManagementScreen();
      case 'risk_provision':
        return const RiskProvisioningScreen();

      // TELLER CENTER
      case 'teller':
        return TellerCenterReorganized(
          onLoanTap: _openLoan,
          onNavigate: (screen) => setState(() => _selectedScreen = screen),
        );
      case 'till_management':
        return const TillManagementScreen(embedded: true);
      case 'till_reports':
        return const TillReportsScreen(embedded: true);
      case 'mobile_money':
        return const MobileMoneyScreen();
      case 'bank_transfers':
        return const BankTransfersScreen();
      case 'reconciliation':
        return const ReconciliationScreen();

      // FINANCE
      case 'cash_bank':
        return const CashBankScreen();
      case 'income':
        return const IncomeScreen();
      case 'expenses':
        return const ExpensesScreen();
      case 'ledger':
        return const GeneralLedgerScreen();
      case 'financial_reports':
        return const ComprehensiveReportsScreen(embedded: true);

      // INTELLIGENCE
      case 'risk_center':
        return LoanRiskCenterScreen(tenantId: FirebaseService.sessionTenantId);
      case 'liquidity':
        return LiquidityMonitorScreen(tenantId: FirebaseService.sessionTenantId);

      // OPERATIONS
      case 'staff':
        return const StaffManagementScreen();
      case 'notifications':
        return const AdminNotificationsScreen();

      // SYSTEM
      case 'settings':
        return const SaccoSettingsScreen();
      case 'audit':
        return const EnhancedAuditScreen(embedded: true);
      case 'reports':
        return const ReportsScreen(embedded: true);
      case 'data_reconciliation':
        return const DataReconciliationScreen();

      default:
        return _AdminHomeTab(
          onNavigate: (screen) => setState(() => _selectedScreen = screen),
        );
    }
  }

  /// One screen at a time, each with its own key so the previous screen is
  /// completely disposed before the next one mounts.
  Widget _currentScreen() {
    return KeyedSubtree(
      key: ValueKey(_selectedScreen),
      child: _buildScreen(_selectedScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    if (isDesktop) {
      final navCollapsed = _navCollapsed ?? screenWidth < 1100;
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Row(
          children: [
            // Persistent sidebar: full menu on wide windows, icon rail on
            // narrower ones. The toggle in the panel overrides the default.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: navCollapsed
                  ? 76.0
                  : (screenWidth * 0.16).clamp(232.0, 272.0).toDouble(),
              child: AdminNavPanel(
                currentScreen: _selectedScreen,
                onNavigate: (screen) => setState(() => _selectedScreen = screen),
                onLogout: () => _confirmLogout(context),
                onToggleCollapse: () =>
                    setState(() => _navCollapsed = !navCollapsed),
              ),
            ),
            // Main content: only the selected screen is mounted.
            Expanded(child: _currentScreen()),
          ],
        ),
      );
    } else {
      // Mobile layout with drawer - show current screen only
      final wrappedScreen = Container(
        color: const Color(0xFFF5F7FA),
        child: _currentScreen(),
      );

      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: ModernTheme.primaryBlue,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/mbadifa-logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'MBADIFA SACCO',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                // Force rebuild to reload data
                setState(() {});
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        drawer: _AdminDrawer(
          currentScreen: _selectedScreen,
          onNavigate: (screen) {
            Navigator.pop(context);
            setState(() {
              _selectedScreen = screen;
            });
          },
          onLogout: () {
            Navigator.pop(context); // close the drawer
            _confirmLogout(context);
          },
        ),
        body: wrappedScreen,
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
            currentIndex: _getBottomNavIndex(_selectedScreen),
            onTap: (i) {
              setState(() {
                if (i == 0) {
                  _selectedScreen = 'dashboard';
                } else if (i == 1) {
                  _selectedScreen = 'loans';
                } else if (i == 2) {
                  _selectedScreen = 'members';
                } else if (i == 3) {
                  _selectedScreen = 'financial_reports';
                }
              });
            },
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

  int _getBottomNavIndex(String screenKey) {
    // Map screen keys to bottom nav indices
    switch (screenKey) {
      case 'dashboard':
        return 0;
      case 'loans':
      case 'loan_details':
      case 'loan_portfolio':
      case 'create_loan':
      case 'loan_correction':
      case 'loan_products':
      case 'loan_calc':
      case 'arrears':
      case 'risk_provision':
        return 1;
      case 'members':
      case 'member_activation':
      case 'member_360':
      case 'kyc':
      case 'dormant':
        return 2;
      case 'financial_reports':
      case 'reports':
      case 'cash_bank':
      case 'income':
      case 'expenses':
      case 'ledger':
        return 3;
      default:
        return 0; // Default to Dashboard for other screens
    }
  }

  void _confirmLogout(BuildContext context) {
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
  final String currentScreen;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;

  const _AdminDrawer({
    required this.currentScreen,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Drawer(
      width: screenWidth * 0.86 > 304 ? 304 : screenWidth * 0.86,
      backgroundColor: AdminNavPanel.background,
      shape: const RoundedRectangleBorder(),
      child: AdminNavPanel(
        currentScreen: currentScreen,
        onNavigate: onNavigate,
        onLogout: onLogout,
      ),
    );
  }
}

// ─── Admin Home Tab ───────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF6F7F9);
  static const ink = Color(0xFF111827);
  static const sub = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFDCE0E6);
  static const accent = Color(0xFF1B365D);
  static const neg = Color(0xFFB42318);
  static const pos = Color(0xFF067647);
  static const warn = Color(0xFFB54708);
}

class _AdminHomeTab extends StatefulWidget {
  final Function(String) onNavigate;
  const _AdminHomeTab({required this.onNavigate});

  @override
  State<_AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<_AdminHomeTab> {
  bool _loading = false;
  String? _error;
  DateTime? _lastRefresh;

  List<Map<String, dynamic>> _loans = [];
  int _members = 0;

  double _savings = 0, _shares = 0, _outstanding = 0, _disbursed = 0;
  double _repaid = 0, _overdueAmount = 0;
  double _par30 = 0, _par60 = 0, _par90 = 0; // amounts
  int _activeLoans = 0, _overdueCount = 0, _pendingCount = 0;
  
  // Outstanding breakdown for teller clarity
  double _principalOut = 0, _interestOut = 0, _chargesOut = 0, _arrearsOut = 0;
  
  final Map<String, int> _statusCounts = {};
  final Map<String, double> _statusAmounts = {};

  int _periodMonths = 6;

  /// True when the CONTENT area (sidebar excluded) is wide enough for
  /// side-by-side panels with fixed heights. Set from build().
  bool _desktop = true;

  static final _num = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _checkForUpdates();
  }

  // ── Toast (same style as the loan details screen) ─────────────────────────
  void _snack(String msg,
      {bool ok = true, VoidCallback? onRetry, Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: _t(13.5, FontWeight.w400, Colors.white)),
          backgroundColor: ok ? _C.ink : _C.neg,
          behavior: SnackBarBehavior.floating,
          width: wide ? 440 : null,
          duration: duration,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: onRetry == null
              ? null
              : SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry),
        ),
      );
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  static double _n(dynamic v) => v is num ? v.toDouble() : 0.0;

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String _fmt(double v) => _num.format(v.round());

  /// Compact axis labels (K / M / B) for narrow charts.
  static String _fmtAxis(double v, bool compact) {
    if (!compact) return _num.format(v.round());
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(v % 1e9 == 0 ? 0 : 1)}B';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(v % 1e6 == 0 ? 0 : 1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  Future<void> _checkForUpdates() async {
    try {
      if (!kIsWeb && Platform.isWindows) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        final info = await UpdateService.checkForUpdates();
        if (info['hasUpdate'] == true && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => UpdateDialog(updateInfo: info),
          );
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() { _error = null; _loading = true; });
    try {
      final loans = await FirebaseService.getAllLoansOnce();
      final members = await FirebaseService.getAllFarmersOnce();

      double savings = 0, shares = 0, outstanding = 0, disbursed = 0;
      double repaid = 0, overdueAmt = 0, p30 = 0, p60 = 0, p90 = 0;
      double principalOut = 0, interestOut = 0, chargesOut = 0, arrearsOut = 0;
      int active = 0, overdueCnt = 0, pending = 0;
      final counts = <String, int>{};
      final amounts = <String, double>{};
      final now = DateTime.now();

      for (final m in members) {
        savings += _n(m['savingsBalance']);
        shares += _n(m['sharesBalance']);
      }

      for (final loan in loans) {
        final status = (loan['status'] ?? '').toString().toLowerCase();
        final amount = _n(loan['amount'] ?? loan['loanAmount']);
        
        // Use corrected totalOutstanding from Loan Data Correction (most accurate)
        // This is the ONLY source of truth - do not calculate from components
        double out = _n(loan['totalOutstanding']);
        if (out == 0) out = _n(loan['remainingBalance']);
        if (out == 0) out = _n(loan['principalOutstanding']);

        final isLive = status == 'active' || status == 'disbursed' || status == 'overdue';
        final isPaid = status == 'paid';
        if (isLive) { 
          active++; 
          outstanding += out;
          
          // Use CORRECTED values from Loan Data Correction screen only
          // These are the manually verified/corrected amounts
          principalOut += _n(loan['principalOutstanding']);
          interestOut += _n(loan['interestOutstanding']);
          // Arrears are separate - not part of outstanding
          arrearsOut += _n(loan['arrears']);
        }
        if (isLive || isPaid || status == 'approved') disbursed += amount;
        if (status == 'pending') pending++;

        // Repaid: use the recorded total if present, otherwise derive it from
        // what has been disbursed minus what is still outstanding.
        if (isLive || isPaid) {
          final recorded = _n(loan['totalRepaid']);
          final derived = isPaid ? amount : (amount - out);
          repaid += recorded > 0 ? recorded : (derived > 0 ? derived : 0);
        }

        final bucket = isLive ? 'Active' : isPaid ? 'Paid'
            : status == 'pending' ? 'Pending' : status == 'approved' ? 'Approved'
            : status == 'rejected' ? 'Rejected' : 'Other';
        counts[bucket] = (counts[bucket] ?? 0) + 1;
        amounts[bucket] = (amounts[bucket] ?? 0) + amount;

        final due = _date(loan['dueDate']);
        if (due != null && out > 0 && due.isBefore(now)) {
          final days = now.difference(due).inDays;
          overdueAmt += out; overdueCnt++;
          if (days > 30) p30 += out;
          if (days > 60) p60 += out;
          if (days > 90) p90 += out;
        }
      }

      if (!mounted) return;
      setState(() {
        _loans = List<Map<String, dynamic>>.from(loans);
        _members = members.length;
        _savings = savings; _shares = shares; _outstanding = outstanding;
        _disbursed = disbursed; _repaid = repaid; _overdueAmount = overdueAmt;
        _par30 = p30; _par60 = p60; _par90 = p90;
        _activeLoans = active; _overdueCount = overdueCnt; _pendingCount = pending;
        _principalOut = principalOut; _interestOut = interestOut;
        _chargesOut = chargesOut; _arrearsOut = arrearsOut;
        _statusCounts..clear()..addAll(counts);
        _statusAmounts..clear()..addAll(amounts);
        _lastRefresh = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
      _snack('Couldn\'t refresh the dashboard', ok: false, onRetry: _load);
    }
  }

  List<MapEntry<String, double>> get _monthly {
    final now = DateTime.now();
    final out = <MapEntry<String, double>>[];
    for (int i = _periodMonths - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      double total = 0;
      for (final l in _loans) {
        final s = (l['status'] ?? '').toString().toLowerCase();
        if (s == 'pending' || s == 'rejected') continue;
        final d = _date(l['createdAt']);
        if (d != null && d.year == month.year && d.month == month.month) {
          total += _n(l['amount'] ?? l['loanAmount']);
        }
      }
      out.add(MapEntry(DateFormat('MMM yy').format(month), total));
    }
    return out;
  }

  // ── Text helpers ──────────────────────────────────────────────────────────
  TextStyle _t(double size, FontWeight w, Color c, {bool tab = false, double? ls}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: ls,
        fontFeatures: tab ? const [FontFeature.tabularFigures()] : null,
      );

  Widget _label(String s) => Text(s.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _t(10.5, FontWeight.w600, _C.muted, ls: 0.6));

  // ── Layout shell ──────────────────────────────────────────────────────────
  Widget _panel({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    // true for panels whose content could be taller than the fixed row height
    bool scroll = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _C.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(14, FontWeight.w600, _C.ink)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w400, _C.muted)),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ]),
        ),
        const Divider(height: 1, color: _C.line),
        if (_desktop)
          Expanded(
            child: scroll
                ? LayoutBuilder(
                    builder: (_, c) => SingleChildScrollView(
                      padding: padding,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (c.maxHeight - padding.vertical)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Center(child: child),
                      ),
                    ),
                  )
                : Padding(padding: padding, child: child),
          )
        else
          Padding(padding: padding, child: child),
      ]),
    );
  }

  /// Lays panels out side by side at a fixed height on wide content areas (so
  /// every panel in the row is the same height), stacked on narrower ones.
  Widget _row(bool desktop, double height, List<(int, Widget)> items) {
    if (!desktop) {
      return Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          items[i].$2,
        ],
      ]);
    }
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(flex: items[i].$1, child: items[i].$2),
        ],
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _C.bg,
      child: LayoutBuilder(builder: (context, box) {
        // Real content width (sidebar already excluded).
        final w = box.maxWidth;
        final pad = w >= 900 ? 24.0 : w >= 600 ? 18.0 : 12.0;
        final desktop = w >= 1200;
        _desktop = desktop;

        return Column(children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(pad),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _header(w >= 700),
                if (_error != null) ...[const SizedBox(height: 12), _errorBanner()],
                const SizedBox(height: 16),
                _summaryGrid(),
                const SizedBox(height: 16),
                _row(desktop, 400, [
                  (5, _disbursementPanel()),
                  (3, _statusPanel()),
                ]),
                const SizedBox(height: 16),
                _row(desktop, 290, [
                  (1, _fundsPanel()),
                  (1, _loanBookPanel()),
                  (1, _riskMixPanel()),
                ]),
                const SizedBox(height: 16),
                _row(desktop, 260, [
                  (3, _parPanel()),
                  (2, _attentionPanel()),
                ]),
                const SizedBox(height: 16),
                _row(desktop, 440, [
                  (3, _recentLoansPanel()),
                  (2, _linksPanel()),
                ]),
              ]),
            ),
          ),
        ]);
      }),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(bool wide) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Financial Overview',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(wide ? 22 : 18, FontWeight.w700, _C.ink, ls: -0.3)),
          const SizedBox(height: 2),
          Text('MBADIFA SACCO  ·  ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(12, FontWeight.w400, _C.muted)),
        ]),
      ),
      if (wide && _lastRefresh != null)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text('Last updated ${DateFormat('h:mm a').format(_lastRefresh!)}',
              style: _t(12, FontWeight.w400, _C.muted)),
        ),
      TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh, size: 16),
        label: Text('Refresh', style: _t(13, FontWeight.w600, _C.accent)),
        style: TextButton.styleFrom(foregroundColor: _C.accent),
      ),
    ]);
  }

  Widget _errorBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDA29B)),
        ),
        child: Text('Some data could not be loaded. Tap Refresh to try again.',
            style: _t(12.5, FontWeight.w500, _C.neg)),
      );

  // ── Summary grid (single bordered block, hairline dividers) ───────────────
  Widget _summaryGrid() {
    final repaymentRate = _disbursed > 0 ? _repaid / _disbursed * 100 : 0.0;
    
    final cells = <(String, double, String, bool)>[
      ('Member Funds', _savings + _shares, '$_members members', false),
      ('Savings', _savings, 'Member deposits', false),
      ('Shares', _shares, 'Share capital', false),
      ('Loan Outstanding', _outstanding, '$_activeLoans active loans', false),
      ('Total Disbursed', _disbursed, 'All loans given out', false),
      ('Total Repaid', _repaid, '${repaymentRate.toStringAsFixed(1)}% recovered', false),
      ('Overdue Loans', _overdueAmount, '$_overdueCount loans past due', _overdueCount > 0),
      ('Arrears', _arrearsOut, 'Late payment penalties', _arrearsOut > 0),
      ('Net Liquidity', _savings - _outstanding, 'Available cash', _savings - _outstanding < 0),
    ];

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 900 ? 4 : (c.maxWidth >= 300 ? 2 : 1);
      final rows = (cells.length / cols).ceil();
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _C.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(children: [
          for (int r = 0; r < rows; r++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (int k = 0; k < cols; k++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: k < cols - 1 ? const BorderSide(color: _C.line) : BorderSide.none,
                          bottom: r < rows - 1 ? const BorderSide(color: _C.line) : BorderSide.none,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: r * cols + k < cells.length
                          ? _summaryCell(cells[r * cols + k])
                          : const SizedBox.shrink(),
                    ),
                  ),
              ]),
            ),
        ]),
      );
    });
  }

  Widget _summaryCell((String, double, String, bool) c) {
    final color = c.$4 ? _C.neg : _C.ink;
    final isBreakdown = c.$1.startsWith('  ');
    final labelText = isBreakdown ? c.$1.trim() : c.$1;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (isBreakdown) ...[
          const SizedBox(width: 12),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: _C.muted.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: _label(labelText)),
      ]),
      const SizedBox(height: 8),
      Padding(
        padding: EdgeInsets.only(left: isBreakdown ? 23 : 0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'UGX ', style: _t(12, FontWeight.w500, _C.muted)),
            TextSpan(text: _fmt(c.$2), style: _t(isBreakdown ? 18 : 21, FontWeight.w700, color, tab: true, ls: -0.3)),
          ])),
        ),
      ),
      const SizedBox(height: 4),
      Padding(
        padding: EdgeInsets.only(left: isBreakdown ? 23 : 0),
        child: Text(c.$3, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: _t(11.5, FontWeight.w400, _C.muted)),
      ),
    ]);
  }

  // ── Disbursement chart ────────────────────────────────────────────────────
  double _niceStep(double max) {
    final rough = max / 4;
    double mag = 1;
    while (mag * 10 <= rough) { mag *= 10; }
    while (mag > rough * 10) { mag /= 10; }
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * mag >= rough) return m * mag;
    }
    return 10 * mag;
  }

  Widget _disbursementPanel() {
    final data = _monthly;
    final maxVal = data.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final total = data.fold<double>(0, (s, e) => s + e.value);
    final step = maxVal > 0 ? _niceStep(maxVal) : 1.0;
    var maxY = maxVal > 0 ? step * (maxVal / step).ceil() : 4.0;
    if (maxY <= maxVal) maxY += step;

    return _panel(
      title: 'Loan disbursements',
      subtitle: 'Amount issued per month (UGX)',
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _periodMonths,
          isDense: true,
          style: _t(12, FontWeight.w600, _C.sub),
          items: const [
            DropdownMenuItem(value: 6, child: Text('Last 6 months')),
            DropdownMenuItem(value: 12, child: Text('Last 12 months')),
          ],
          onChanged: (v) => setState(() => _periodMonths = v ?? 6),
        ),
      ),
      child: _withStats(total, data, SizedBox(
        height: _desktop ? double.infinity : 260,
        child: maxVal <= 0
            ? Center(child: Text('No disbursements in this period',
                style: _t(13, FontWeight.w400, _C.muted)))
            : LayoutBuilder(builder: (context, c) {
                final narrow = c.maxWidth < 480;
                final axisW = narrow ? 44.0 : 88.0;
                final barW = ((c.maxWidth - axisW) / data.length * 0.55)
                    .clamp(6.0, 30.0)
                    .toDouble();
                final skipEvery = (narrow && data.length > 6) ? 2 : 1;
                return BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (total > 0)
                      HorizontalLine(
                        y: total / data.length,
                        color: _C.warn,
                        strokeWidth: 1,
                        dashArray: [5, 4],
                      ),
                  ]),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(bottom: BorderSide(color: _C.line)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFEDEFF3), strokeWidth: 1),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        '${data[group.x].key}\nUGX ${_fmt(rod.toY)}',
                        _t(11.5, FontWeight.w600, Colors.white, tab: true),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: axisW,
                        interval: step,
                        getTitlesWidget: (v, _) => Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(_fmtAxis(v, narrow),
                                style: _t(10.5, FontWeight.w400, _C.muted, tab: true)),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= data.length || i % skipEvery != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(data[i].key, style: _t(10.5, FontWeight.w400, _C.muted)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < data.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: data[i].value,
                          width: barW,
                          color: _C.accent,
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY,
                            color: const Color(0xFFF3F4F6),
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ]),
                  ],
                ));
              }),
      )),
    );
  }

  Widget _withStats(double total, List<MapEntry<String, double>> data, Widget chart) {
    final avg = data.isEmpty ? 0.0 : total / data.length;
    final peak = data.fold<MapEntry<String, double>?>(
        null, (m, e) => (m == null || e.value > m.value) ? e : m);
    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(label),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: _t(15, FontWeight.w700, _C.ink, tab: true)),
            ),
          ]),
        );
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stat('Total disbursed', 'UGX ${_fmt(total)}'),
        const SizedBox(width: 8),
        stat('Monthly average', 'UGX ${_fmt(avg)}'),
        const SizedBox(width: 8),
        stat('Peak month',
            peak != null && peak.value > 0 ? '${peak.key}  ·  UGX ${_fmt(peak.value)}' : '—'),
      ]),
      const SizedBox(height: 14),
      if (_desktop) Expanded(child: chart) else chart,
    ]);
  }

  // ── Donut helpers ─────────────────────────────────────────────────────────
  Widget _donut(
    List<(String, double, Color)> parts, {
    required String centerTop,
    required String centerBottom,
    double size = 150,
    double thickness = 12,
  }) {
    final live = parts.where((p) => p.$2 > 0).toList();
    final total = live.fold<double>(0, (s, p) => s + p.$2);
    final hole = size - thickness * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          startDegreeOffset: -90,
          sectionsSpace: live.length > 1 ? 1.5 : 0,
          centerSpaceRadius: hole / 2,
          sections: total <= 0
              ? [PieChartSectionData(
                  value: 1, color: const Color(0xFFE5E7EB), radius: thickness, showTitle: false)]
              : [for (final p in live)
                  PieChartSectionData(
                      value: p.$2, color: p.$3, radius: thickness, showTitle: false)],
        )),
        SizedBox(
          width: hole - 20,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(centerBottom.toUpperCase(),
                  style: _t(9.5, FontWeight.w600, _C.muted, ls: 0.6)),
              const SizedBox(height: 2),
              Text(centerTop, style: _t(17, FontWeight.w700, _C.ink, tab: true)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _legend(List<(String, double, Color)> parts, {bool money = true}) {
    final total = parts.fold<double>(0, (s, p) => s + p.$2);
    final rows = parts.where((p) => p.$2 > 0).toList();
    if (rows.isEmpty) {
      return Center(child: Text('No data', style: _t(12.5, FontWeight.w400, _C.muted)));
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < rows.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: _C.line),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(width: 8, height: 8, color: rows[i].$3),
            const SizedBox(width: 8),
            Expanded(
              child: Text(rows[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12.5, FontWeight.w500, _C.ink)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(money ? _fmt(rows[i].$2) : '${rows[i].$2.toInt()}',
                    style: _t(12.5, FontWeight.w500, _C.ink, tab: true)),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text('${(rows[i].$2 / total * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: _t(12, FontWeight.w400, _C.muted, tab: true)),
            ),
          ]),
        ),
      ],
    ]);
  }

  /// Donut + legend panel. Side by side when the panel is wide enough,
  /// stacked when it is narrow.
  Widget _mixPanel(String title, String subtitle, List<(String, double, Color)> parts,
      {int centerIndex = 0, bool money = true}) {
    final total = parts.fold<double>(0, (s, p) => s + p.$2);
    return _panel(
      title: title,
      subtitle: subtitle,
      scroll: true,
      child: LayoutBuilder(builder: (context, c) {
        final sideBySide = c.maxWidth >= 300;
        final size = sideBySide
            ? (c.maxWidth * 0.4).clamp(110.0, 150.0).toDouble()
            : 140.0;
        final donut = _donut(
          parts,
          centerTop: money ? _fmt(total) : '${total.toInt()}',
          centerBottom: 'Total',
          size: size,
          thickness: size >= 140 ? 12 : 10,
        );
        if (sideBySide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            donut,
            const SizedBox(width: 16),
            Expanded(child: _legend(parts, money: money)),
          ]);
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          donut,
          const SizedBox(height: 12),
          _legend(parts, money: money),
        ]);
      }),
    );
  }

  Widget _fundsPanel() => _mixPanel('Member funds', 'Savings vs shares', [
        ('Savings', _savings, _C.accent),
        ('Shares', _shares, const Color(0xFF5B7DB1)),
      ]);

  Widget _loanBookPanel() => _mixPanel('Loan book', 'Repaid vs outstanding', [
        ('Repaid', _repaid, const Color(0xFF3E8E7E)),
        ('Outstanding', _outstanding, _C.accent),
      ]);

  Widget _riskMixPanel() {
    final performing = (_outstanding - _overdueAmount).clamp(0.0, double.infinity);
    return _mixPanel('Portfolio quality', 'Outstanding by days overdue', [
      ('Performing', performing, const Color(0xFF3E8E7E)),
      ('1–30 days', (_overdueAmount - _par30).clamp(0.0, double.infinity), const Color(0xFFC98A1B)),
      ('31–60 days', (_par30 - _par60).clamp(0.0, double.infinity), const Color(0xFFD9622B)),
      ('61–90 days', (_par60 - _par90).clamp(0.0, double.infinity), const Color(0xFFB42318)),
      ('Over 90 days', _par90, const Color(0xFF7A1F16)),
    ]);
  }

  // ── Loans by status ───────────────────────────────────────────────────────
  static const _statusOrder = ['Active', 'Approved', 'Paid', 'Pending', 'Rejected', 'Other'];
  static const _statusColors = {
    'Active': Color(0xFF1B365D),
    'Approved': Color(0xFF5B7DB1),
    'Paid': Color(0xFF3E8E7E),
    'Pending': Color(0xFFC98A1B),
    'Rejected': Color(0xFFB42318),
    'Other': Color(0xFF9CA3AF),
  };

  Widget _statusPanel() {
    final total = _statusCounts.values.fold<int>(0, (a, b) => a + b);
    final keys = _statusOrder.where((k) => (_statusCounts[k] ?? 0) > 0).toList();
    final parts = [for (final k in keys) (k, _statusCounts[k]!.toDouble(), _statusColors[k]!)];

    Widget table() => Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(flex: 3, child: _label('Status')),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _label('Loans'))),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _label('Share'))),
            Expanded(flex: 4, child: Align(alignment: Alignment.centerRight, child: _label('Amount'))),
          ]),
          const SizedBox(height: 6),
          for (final k in keys) ...[
            const Divider(height: 1, color: _C.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Row(children: [
                    Container(width: 8, height: 8, color: _statusColors[k]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(k,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12.5, FontWeight.w500, _C.ink)),
                    ),
                  ]),
                ),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight,
                    child: Text('${_statusCounts[k]}',
                        style: _t(12.5, FontWeight.w500, _C.ink, tab: true)))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerRight,
                    child: Text('${(_statusCounts[k]! / total * 100).toStringAsFixed(0)}%',
                        style: _t(12.5, FontWeight.w400, _C.muted, tab: true)))),
                Expanded(flex: 4, child: Align(alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(_fmt(_statusAmounts[k] ?? 0),
                          style: _t(12.5, FontWeight.w500, _C.ink, tab: true)),
                    ))),
              ]),
            ),
          ],
        ]);

    return _panel(
      title: 'Loans by status',
      subtitle: '$total loans',
      scroll: true,
      child: total == 0
          ? Center(child: Text('No loans recorded', style: _t(13, FontWeight.w400, _C.muted)))
          : LayoutBuilder(builder: (context, c) {
              final sideBySide = c.maxWidth >= 460;
              final donut = _donut(parts,
                  centerTop: '$total',
                  centerBottom: 'Loans',
                  size: sideBySide ? 170 : 140,
                  thickness: 14);
              return sideBySide
                  ? Row(children: [
                      donut,
                      const SizedBox(width: 24),
                      Expanded(child: table()),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min,
                      children: [donut, const SizedBox(height: 14), table()]);
            }),
    );
  }

  // ── Portfolio at risk ─────────────────────────────────────────────────────
  Widget _parPanel() {
    final rows = [
      ('Over 30 days', _par30, 5.0),
      ('Over 60 days', _par60, 3.0),
      ('Over 90 days', _par90, 2.0),
    ];

    Widget cell(int flex, Widget w, {bool right = true}) => Expanded(
          flex: flex,
          child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: w),
        );

    return _panel(
      title: 'Portfolio at risk',
      subtitle: 'Overdue principal as a share of loans outstanding',
      scroll: true,
      child: LayoutBuilder(builder: (context, c) {
        final showTarget = c.maxWidth >= 520;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            cell(3, _label('Overdue by'), right: false),
            cell(3, _label('Amount')),
            cell(2, _label('% of book')),
            if (showTarget) cell(2, _label('Target')),
            cell(2, _label('Status')),
          ]),
          const SizedBox(height: 6),
          for (final r in rows) ...[
            const Divider(height: 1, color: _C.line),
            Builder(builder: (_) {
              final pct = _outstanding > 0 ? r.$2 / _outstanding * 100 : 0.0;
              final ok = pct <= r.$3 * 0.6;
              final watch = !ok && pct <= r.$3;
              final color = ok ? _C.pos : watch ? _C.warn : _C.neg;
              final label = ok ? 'Within target' : watch ? 'Watch' : 'Above target';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  cell(3, Text(r.$1, style: _t(12.5, FontWeight.w500, _C.ink)), right: false),
                  cell(3, FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(_fmt(r.$2), style: _t(12.5, FontWeight.w500, _C.ink, tab: true)),
                  )),
                  cell(2, Text('${pct.toStringAsFixed(1)}%',
                      style: _t(12.5, FontWeight.w600, color, tab: true))),
                  if (showTarget)
                    cell(2, Text('≤ ${r.$3.toStringAsFixed(0)}%',
                        style: _t(12.5, FontWeight.w400, _C.muted, tab: true))),
                  cell(2, Text(label, textAlign: TextAlign.right,
                      style: _t(11.5, FontWeight.w600, color))),
                ]),
              );
            }),
          ],
        ]);
      }),
    );
  }

  // ── Needs attention ───────────────────────────────────────────────────────
  Widget _attentionPanel() {
    final items = <(String, int, Color, String)>[
      if (_overdueCount > 0) ('Loans past due date', _overdueCount, _C.neg, 'loan_portfolio'),
      if (_pendingCount > 0) ('Applications awaiting approval', _pendingCount, _C.warn, 'loans'),
    ];

    return _panel(
      title: 'Needs attention',
      padding: EdgeInsets.zero,
      scroll: true,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle_outline, size: 30, color: _C.pos),
                  const SizedBox(height: 8),
                  Text('No items require attention.',
                      style: _t(12.5, FontWeight.w400, _C.muted)),
                ]),
              ),
            )
          : Column(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: _C.line),
                InkWell(
                  onTap: () => widget.onNavigate(items[i].$4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(children: [
                      Container(width: 3, height: 18, color: items[i].$3),
                      const SizedBox(width: 12),
                      Expanded(child: Text(items[i].$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(13, FontWeight.w500, _C.ink))),
                      const SizedBox(width: 8),
                      Text('${items[i].$2}',
                          style: _t(15, FontWeight.w700, items[i].$3, tab: true)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 18, color: _C.muted),
                    ]),
                  ),
                ),
              ],
            ]),
    );
  }

  // ── Recent loans table ────────────────────────────────────────────────────
  Widget _recentLoansPanel() {
    final sorted = [..._loans]..sort((a, b) {
        final da = _date(a['createdAt']) ?? DateTime(2000);
        final db = _date(b['createdAt']) ?? DateTime(2000);
        return db.compareTo(da);
      });

    return _panel(
      title: 'Recent loan applications',
      trailing: TextButton(
        onPressed: () => widget.onNavigate('loans'),
        style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 28)),
        child: Text('View all', style: _t(12.5, FontWeight.w600, _C.accent)),
      ),
      child: _loans.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No loan applications yet',
                  style: _t(13, FontWeight.w400, _C.muted))),
            )
          : LayoutBuilder(builder: (context, c) {
              final showDate = c.maxWidth >= 460;
              final n = _desktop ? ((c.maxHeight - 34) / 46).floor().clamp(3, 12) : 6;
              final recent = sorted.take(n).toList();
              return ClipRect(
                child: Column(children: [
                  Row(children: [
                    Expanded(flex: 4, child: _label('Member')),
                    if (showDate) Expanded(flex: 2, child: _label('Date')),
                    Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: _label('Amount'))),
                    Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _label('Status'))),
                  ]),
                  const SizedBox(height: 6),
                  for (final loan in recent) ...[
                    const Divider(height: 1, color: _C.line),
                    _loanRow(loan, showDate),
                  ],
                ]),
              );
            }),
    );
  }

  Widget _loanRow(Map<String, dynamic> loan, bool showDate) {
    final name = (loan['farmerName'] ?? loan['memberName'] ?? 'Unknown').toString();
    final amount = _n(loan['amount'] ?? loan['loanAmount']);
    final status = (loan['status'] ?? 'pending').toString();
    final created = _date(loan['createdAt']);
    final color = _statusTextColor(status);
    final statusText = status.isEmpty
        ? '—'
        : status[0].toUpperCase() + status.substring(1).toLowerCase();

    return InkWell(
      onTap: () => widget.onNavigate('loans'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _t(12.5, FontWeight.w500, _C.ink)),
          ),
          if (showDate)
            Expanded(
              flex: 2,
              child: Text(created != null ? DateFormat('dd MMM yyyy').format(created) : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, FontWeight.w400, _C.muted, tab: true)),
            ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(_fmt(amount), style: _t(12.5, FontWeight.w500, _C.ink, tab: true)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, FontWeight.w600, color)),
            ),
          ),
        ]),
      ),
    );
  }

  Color _statusTextColor(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return _C.pos;
      case 'pending':
        return _C.warn;
      case 'rejected':
      case 'overdue':
        return _C.neg;
      default:
        return _C.accent;
    }
  }

  // ── Shortcuts ─────────────────────────────────────────────────────────────
  Widget _linksPanel() {
    final links = <(String, String)>[
      ('Create loan', 'create_loan'),
      ('Loan approvals', 'loans'),
      ('Members', 'members'),
      ('Teller center', 'teller'),
      ('Financial reports', 'financial_reports'),
      ('Liquidity monitor', 'liquidity'),
    ];
    Widget row(int i) => InkWell(
          onTap: () => widget.onNavigate(links[i].$2),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Expanded(child: Text(links[i].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(13, FontWeight.w500, _C.ink))),
              const Icon(Icons.chevron_right, size: 18, color: _C.muted),
            ]),
          ),
        );
    return _panel(
      title: 'Shortcuts',
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (int i = 0; i < links.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: _C.line),
          if (_desktop) Expanded(child: row(i))
          else row(i),
        ],
      ]),
    );
  }
}
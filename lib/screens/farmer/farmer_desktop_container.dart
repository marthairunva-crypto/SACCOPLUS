import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../theme/modern_theme.dart';
import '../auth/professional_login_screen.dart';
import 'farmer_dashboard.dart';
import 'savings_screen.dart';
import 'shares_screen.dart';
import 'fixed_deposit_screen.dart';
import 'bank_transfer_screen.dart';
import 'bill_payment_screen.dart';
import 'airtime_data_screen.dart';
import 'transaction_history_screen.dart';
import 'account_statement_screen.dart';
import 'apply_loan_screen.dart';
import 'loan_status_screen.dart';
import 'repayment_screen.dart';
import 'notifications_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';

/// Desktop-style container with persistent sidebar
class FarmerDesktopContainer extends StatefulWidget {
  const FarmerDesktopContainer({super.key});

  @override
  State<FarmerDesktopContainer> createState() => _FarmerDesktopContainerState();
}

class _FarmerDesktopContainerState extends State<FarmerDesktopContainer> {
  String _currentPage = 'dashboard';

  String get _name => FirebaseService.sessionProfile?['name'] as String? ?? 'Member';

  Widget _getCurrentBody() {
    // Return body content wrapped to extract from scaffold
    switch (_currentPage) {
      case 'dashboard':
        return _BodyExtractor(child: FarmerDashboard());
      case 'savings':
        return _BodyExtractor(child: const SavingsScreen());
      case 'shares':
        return _BodyExtractor(child: const SharesScreen());
      case 'fixedDeposit':
        return _BodyExtractor(child: const FixedDepositScreen());
      case 'bankTransfer':
        return _BodyExtractor(child: const BankTransferScreen());
      case 'billPayment':
        return _BodyExtractor(child: const BillPaymentScreen());
      case 'airtime':
        return _BodyExtractor(child: const AirtimeDataScreen());
      case 'aiAssistant':
        return _BodyExtractor(child: const AiChatScreen());
      case 'transactions':
        return _BodyExtractor(child: const TransactionHistoryScreen());
      case 'statement':
        return _BodyExtractor(child: const AccountStatementScreen());
      case 'apply':
        return _BodyExtractor(child: const ApplyLoanScreen());
      case 'loans':
        return _BodyExtractor(child: const LoanStatusScreen());
      case 'repayments':
        return _BodyExtractor(child: const RepaymentScreen());
      case 'profile':
        return _BodyExtractor(child: const ProfileScreen());
      case 'notifications':
        return _BodyExtractor(child: const NotificationsScreen());
      default:
        return _BodyExtractor(child: FarmerDashboard());
    }
  }

  String _getTitle() {
    switch (_currentPage) {
      case 'dashboard':
        return 'Dashboard';
      case 'savings':
        return 'My Savings';
      case 'shares':
        return 'My Shares';
      case 'fixedDeposit':
        return 'Fixed Deposits';
      case 'bankTransfer':
        return 'Bank Transfer';
      case 'billPayment':
        return 'Pay Bills';
      case 'airtime':
        return 'Airtime & Data';
      case 'aiAssistant':
        return 'AI Assistant';
      case 'transactions':
        return 'Transactions';
      case 'statement':
        return 'Account Statement';
      case 'apply':
        return 'Apply for Loan';
      case 'loans':
        return 'My Loans';
      case 'repayments':
        return 'Repayments';
      case 'profile':
        return 'Profile';
      case 'notifications':
        return 'Notifications';
      default:
        return 'Dashboard';
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ModernTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.logout_rounded, color: ModernTheme.error, size: 28),
            ),
            const SizedBox(width: 16),
            Text('Sign Out',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to sign out?',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will need to log in again to access your account.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                )),
          ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Left Sidebar
          _buildSidebar(),
          // Right Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Text(
                        _getTitle(),
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, size: 24),
                        onPressed: () => setState(() => _currentPage = 'notifications'),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: ModernTheme.primary,
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content Area
                Expanded(
                  child: _getCurrentBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    const bgDark = Color(0xFF071A45);
    const bgLight = Color(0xFF0D2B6B);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgDark, bgLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Logo/Header
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  'MBADIFA SACCO',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Poverty Must Go',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E3A8A), height: 1),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _menuItem(Icons.dashboard_rounded, 'Dashboard', 'dashboard'),
                _menuItem(Icons.savings_rounded, 'My Savings', 'savings'),
                _menuItem(Icons.donut_large_rounded, 'My Shares', 'shares'),
                _menuItem(Icons.lock_clock_rounded, 'Fixed Deposits', 'fixedDeposit'),
                _menuItem(Icons.account_balance_rounded, 'Bank Transfer', 'bankTransfer'),
                _menuItem(Icons.receipt_rounded, 'Pay Bills', 'billPayment'),
                _menuItem(Icons.sim_card_rounded, 'Airtime & Data', 'airtime'),
                _menuItem(Icons.psychology_rounded, 'AI Assistant', 'aiAssistant', isNew: true),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: Color(0xFF1E3A8A), height: 1),
                ),
                const SizedBox(height: 16),
                _menuItem(Icons.add_card_rounded, 'Apply for Loan', 'apply'),
                _menuItem(Icons.assignment_rounded, 'My Loans', 'loans'),
                _menuItem(Icons.payment_rounded, 'Repayments', 'repayments'),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: Color(0xFF1E3A8A), height: 1),
                ),
                const SizedBox(height: 16),
                _menuItem(Icons.history_rounded, 'Transactions', 'transactions'),
                _menuItem(Icons.description_rounded, 'Statement', 'statement'),
                _menuItem(Icons.person_rounded, 'Profile', 'profile'),
              ],
            ),
          ),
          // Sign Out
          Container(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, String pageKey, {bool isNew = false}) {
    final isActive = _currentPage == pageKey;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E3A8A) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 22),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NEW',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => setState(() => _currentPage = pageKey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
      ),
    );
  }
}

/// Widget to extract body from FarmerScaffold screens
class _BodyExtractor extends StatelessWidget {
  final Widget child;
  const _BodyExtractor({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: child,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';

/// Modern Responsive Dashboard matching the design image
/// - Desktop: Side nav + 3-column grid layout
/// - Mobile: Bottom nav + stacked cards
class ModernDashboard extends StatefulWidget {
  const ModernDashboard({super.key});

  @override
  State<ModernDashboard> createState() => _ModernDashboardState();
}

class _ModernDashboardState extends State<ModernDashboard> {
  Map<String, dynamic>? _profile;
  int _walletBalance = 0;
  int _totalLoans = 0;
  int _totalRepaid = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  Map<String, int> _expenses = {};
  List<FlSpot> _chartData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final uid = FirebaseService.sessionUid;
      if (uid.isEmpty) return;

      final results = await Future.wait([
        FirebaseService.getUserProfile(uid),
        FirebaseService.getWallet(uid),
        FirebaseService.getFarmerLoansOnce(uid),
        FirebaseService.getFarmerRepaymentsOnce(uid),
        _loadWalletTransactions(uid),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final wallet = results[1] as Map<String, dynamic>;
      final loans = results[2] as List<Map<String, dynamic>>;
      final repayments = results[3] as List<Map<String, dynamic>>;
      final transactions = results[4] as List<Map<String, dynamic>>;

      final totalLoans = loans.fold<int>(0, (sum, l) => sum + ((l['amount'] as num?)?.toInt() ?? 0));
      final totalRepaid = repayments.fold<int>(0, (sum, r) => sum + ((r['amount'] as num?)?.toInt() ?? 0));

      // Recent activities from transactions
      final recent = transactions.take(5).map((t) {
        return {
          'icon': _getIconForType(t['type'] as String? ?? ''),
          'title': t['description'] as String? ?? 'Transaction',
          'time': _formatTime(t['createdAt']),
          'amount': (t['amount'] as num?)?.toInt() ?? 0,
        };
      }).toList();

      // Expenses breakdown (mock data - replace with real)
      final expenses = {
        'Online Shopping': 326860,
        'Car services': 213564,
        'Entertainments': 127478,
        'Households': 35872,
      };

      // Chart data (last 6 months spending)
      final chartData = [
        FlSpot(0, 4000),
        FlSpot(1, 5000),
        FlSpot(2, 4500),
        FlSpot(3, 7000),
        FlSpot(4, 8000),
        FlSpot(5, 6500),
        FlSpot(6, 7500),
      ];

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _walletBalance = (wallet['balance'] as num?)?.toInt() ?? 0;
        _totalLoans = totalLoans;
        _totalRepaid = totalRepaid;
        _recentActivities = recent;
        _expenses = expenses;
        _chartData = chartData;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadWalletTransactions(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.walletTxnCol)
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  IconData _getIconForType(String type) {
    if (type.contains('airtime')) return Icons.phone_android;
    if (type.contains('bill')) return Icons.receipt;
    if (type.contains('transfer')) return Icons.send;
    return Icons.shopping_bag;
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hour ago';
      return '${diff.inDays} day ago';
    }
    return 'Recent';
  }

  String get _userName => _profile?['name']?.split(' ').first ?? 'Member';
  String _fmt(int n) => NumberFormat('#,###', 'en_US').format(n);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT (Side Nav + 3-Column Grid)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Side Navigation
          Container(
            width: 220,
            color: const Color(0xFF1A2332),
            child: _buildSideNav(),
          ),
          
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 32),
                  
                  // 3-Column Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column (Expenses + Chart)
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildExpensesCard(),
                            const SizedBox(height: 24),
                            _buildStatisticsChart(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      
                      // Right Column (Cards + Activities + Cashback)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildCreditCards(),
                            const SizedBox(height: 24),
                            _buildRecentActivities(),
                            const SizedBox(height: 24),
                            _buildCashbackCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT (Stacked Cards)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Welcome, $_userName!',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A2332),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1A2332)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCardMobile(),
            const SizedBox(height: 20),
            _buildExpensesCard(),
            const SizedBox(height: 20),
            _buildStatisticsChart(),
            const SizedBox(height: 20),
            _buildRecentActivities(),
            const SizedBox(height: 20),
            _buildCashbackCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSideNav() {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Logo
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.dashboard, color: Colors.white),
        ),
        const SizedBox(height: 48),
        
        // Nav Items
        _navItem(Icons.home, 'Dashboard', true),
        _navItem(Icons.credit_card, 'Premium', false),
        _navItem(Icons.person_outline, 'Profile', false),
        _navItem(Icons.receipt_long, 'Transactions', false),
        _navItem(Icons.support_agent, 'Support', false),
        _navItem(Icons.settings, 'Settings', false),
        
        const Spacer(),
        
        // Premium Card
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Get a premium\ncard',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2332),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Get now',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2A3544) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: active ? const Color(0xFF4A90E2) : const Color(0xFF8B92A0),
          size: 20,
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            color: active ? Colors.white : const Color(0xFF8B92A0),
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $_userName!',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2332),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Balance: UGX ${_fmt(_walletBalance)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF4A90E2),
              child: Text(
                _userName[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCardMobile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'UGX ${_fmt(_walletBalance)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildExpensesCard() {
    final total = _expenses.values.fold<int>(0, (sum, val) => sum + val);
    
    return Container(
      padding: const EdgeInsets.all(24),
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
                'Expenses instead',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2332),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'April',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Donut Chart + Legend
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut Chart
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 45,
                        sections: [
                          PieChartSectionData(
                            value: _expenses['Online Shopping']?.toDouble() ?? 0,
                            color: const Color(0xFF4A90E2),
                            radius: 20,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: _expenses['Car services']?.toDouble() ?? 0,
                            color: const Color(0xFF93C5FD),
                            radius: 20,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: _expenses['Entertainments']?.toDouble() ?? 0,
                            color: const Color(0xFF60A5FA),
                            radius: 20,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: _expenses['Households']?.toDouble() ?? 0,
                            color: const Color(0xFFDEEBFF),
                            radius: 20,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          Text(
                            '\$${(total / 1000).toStringAsFixed(0)} 093',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A2332),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _expenses.entries.map((e) {
                    final color = _getExpenseColor(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          Text(
                            '\$${(e.value / 1000).toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2332),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 600.ms);
  }

  Color _getExpenseColor(String category) {
    switch (category) {
      case 'Online Shopping': return const Color(0xFF4A90E2);
      case 'Car services': return const Color(0xFF93C5FD);
      case 'Entertainments': return const Color(0xFF60A5FA);
      case 'Households': return const Color(0xFFDEEBFF);
      default: return const Color(0xFF4A90E2);
    }
  }

  Widget _buildStatisticsChart() {
    return Container(
      padding: const EdgeInsets.all(24),
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
                'Statistic',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2332),
                ),
              ),
              Row(
                children: [
                  _chipButton('Spending', true),
                  const SizedBox(width: 8),
                  _chipButton('Arrival', false),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Line Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFF3F4F6),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 1000).toInt()}k',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartData,
                    isCurved: true,
                    color: const Color(0xFF1A2332),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == 3) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: const Color(0xFF1A2332),
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          );
                        }
                        return FlDotCirclePainter(
                          radius: 0,
                          color: Colors.transparent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          '+ \$${(spot.y * 1000).toInt().toString()}',
                          GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _chipButton(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF1A2332) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: active ? Colors.white : const Color(0xFF6B7280),
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildCreditCards() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                'Credit Cards',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2332),
                ),
              ),
              const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Card Stack
          Stack(
            children: [
              // Card 2 (behind)
              Transform.translate(
                offset: const Offset(10, 10),
                child: _creditCard(
                  '4865 **** **** ****',
                  'Amazon',
                  const Color(0xFF2D4A7C),
                ),
              ),
              // Card 1 (front)
              _creditCard(
                '5276 5786 6758 9095',
                'Universal Card',
                const Color(0xFF4A6FA5),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 600.ms);
  }

  Widget _creditCard(String number, String name, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const Icon(Icons.contactless, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            number,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nickole Robson',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              Text(
                '15/23',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                'Recent Activities',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2332),
                ),
              ),
              Text(
                'See all',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF4A90E2),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Today',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          
          if (_recentActivities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No recent activities',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )
          else
            ..._recentActivities.map((activity) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activity['icon'] as IconData,
                        size: 20,
                        color: const Color(0xFF1A2332),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['title'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2332),
                            ),
                          ),
                          Text(
                            activity['time'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-UGX ${_fmt(activity['amount'] as int)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2332),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
  }

  Widget _buildCashbackCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDEEBFF), Color(0xFFB6D9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your cashback',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ UGX ${_fmt((_walletBalance * 0.1).toInt())}',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2332),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 600.ms);
  }
}

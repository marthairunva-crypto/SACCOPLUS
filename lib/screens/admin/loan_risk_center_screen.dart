import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/loan_risk_service.dart';
import 'loan_360_screen.dart';

/// Loan Risk Center - Full risk analysis dashboard
/// Portfolio classification charts, aging analysis, top defaulters
class LoanRiskCenterScreen extends StatefulWidget {
  final String tenantId;

  const LoanRiskCenterScreen({Key? key, required this.tenantId}) : super(key: key);

  @override
  State<LoanRiskCenterScreen> createState() => _LoanRiskCenterScreenState();
}

class _LoanRiskCenterScreenState extends State<LoanRiskCenterScreen> {
  final LoanRiskService _riskService = LoanRiskService();
  LoanRiskAnalysis? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRiskAnalysis();
  }

  Future<void> _loadRiskAnalysis() async {
    setState(() => _isLoading = true);
    final analysis = await _riskService.getLoanRiskAnalysis(widget.tenantId);
    setState(() {
      _analysis = analysis;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Risk Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRiskAnalysis,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analysis == null
              ? const Center(child: Text('No data available'))
              : RefreshIndicator(
                  onRefresh: _loadRiskAnalysis,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRiskScoreCard(),
                        const SizedBox(height: 20),
                        _buildPortfolioSummary(),
                        const SizedBox(height: 20),
                        _buildClassificationChart(),
                        const SizedBox(height: 20),
                        _buildAgingAnalysisChart(),
                        const SizedBox(height: 20),
                        _buildHighRiskLoansList(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildRiskScoreCard() {
    final score = _analysis!.riskScore;
    Color scoreColor;
    String scoreLabel;

    if (score >= 85) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (score >= 70) {
      scoreColor = Colors.lightGreen;
      scoreLabel = 'Good';
    } else if (score >= 50) {
      scoreColor = Colors.orange;
      scoreLabel = 'Fair';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Poor';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scoreColor.withOpacity(0.8), scoreColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Overall Portfolio Risk Score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${score.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              scoreLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreMetric('Total Loans', '${_analysis!.totalLoans}'),
                _buildScoreMetric(
                  'Portfolio',
                  'UGX ${_formatAmount(_analysis!.totalPortfolio)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portfolio Classification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildClassificationRow(
              'Performing',
              _analysis!.performingCount,
              _analysis!.performingAmount,
              _analysis!.performingPercent,
              Colors.green,
            ),
            const Divider(height: 20),
            _buildClassificationRow(
              'Watch',
              _analysis!.watchCount,
              _analysis!.watchAmount,
              _analysis!.watchPercent,
              Colors.blue,
            ),
            const Divider(height: 20),
            _buildClassificationRow(
              'Substandard',
              _analysis!.substandardCount,
              _analysis!.substandardAmount,
              _analysis!.substandardPercent,
              Colors.orange,
            ),
            const Divider(height: 20),
            _buildClassificationRow(
              'Doubtful',
              _analysis!.doubtfulCount,
              _analysis!.doubtfulAmount,
              _analysis!.doubtfulPercent,
              Colors.deepOrange,
            ),
            const Divider(height: 20),
            _buildClassificationRow(
              'Loss',
              _analysis!.lossCount,
              _analysis!.lossAmount,
              _analysis!.lossPercent,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassificationRow(
    String category,
    int count,
    double amount,
    double percent,
    Color color,
  ) {
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            category,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'UGX ${_formatAmount(amount)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '$count loans • ${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClassificationChart() {
    final total = _analysis!.totalPortfolio;
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No portfolio data')),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portfolio Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    if (_analysis!.performingAmount > 0)
                      PieChartSectionData(
                        value: _analysis!.performingAmount,
                        title: '${_analysis!.performingPercent.toStringAsFixed(0)}%',
                        color: Colors.green,
                        radius: 80,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if (_analysis!.watchAmount > 0)
                      PieChartSectionData(
                        value: _analysis!.watchAmount,
                        title: '${_analysis!.watchPercent.toStringAsFixed(0)}%',
                        color: Colors.blue,
                        radius: 80,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if (_analysis!.substandardAmount > 0)
                      PieChartSectionData(
                        value: _analysis!.substandardAmount,
                        title: '${_analysis!.substandardPercent.toStringAsFixed(0)}%',
                        color: Colors.orange,
                        radius: 80,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if (_analysis!.doubtfulAmount > 0)
                      PieChartSectionData(
                        value: _analysis!.doubtfulAmount,
                        title: '${_analysis!.doubtfulPercent.toStringAsFixed(0)}%',
                        color: Colors.deepOrange,
                        radius: 80,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    if (_analysis!.lossAmount > 0)
                      PieChartSectionData(
                        value: _analysis!.lossAmount,
                        title: '${_analysis!.lossPercent.toStringAsFixed(0)}%',
                        color: Colors.red,
                        radius: 80,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingAnalysisChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aging Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _getMaxAgingAmount() * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const titles = ['Current', '1-30', '31-60', '61-90', '91-180', '180+'];
                          if (value.toInt() >= 0 && value.toInt() < titles.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                titles[value.toInt()],
                                style: const TextStyle(fontSize: 10),
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
                            _formatAmount(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildBarGroup(0, _analysis!.currentAmount, Colors.green),
                    _buildBarGroup(1, _analysis!.aging1_30Amount, Colors.blue),
                    _buildBarGroup(2, _analysis!.aging31_60Amount, Colors.orange),
                    _buildBarGroup(3, _analysis!.aging61_90Amount, Colors.deepOrange),
                    _buildBarGroup(4, _analysis!.aging91_180Amount, Colors.red[700]!),
                    _buildBarGroup(5, _analysis!.aging180PlusAmount, Colors.red[900]!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 24,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  double _getMaxAgingAmount() {
    return [
      _analysis!.currentAmount,
      _analysis!.aging1_30Amount,
      _analysis!.aging31_60Amount,
      _analysis!.aging61_90Amount,
      _analysis!.aging91_180Amount,
      _analysis!.aging180PlusAmount,
    ].reduce((a, b) => a > b ? a : b);
  }

  Widget _buildHighRiskLoansList() {
    if (_analysis!.highRiskLoans.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No high-risk loans'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'High Risk Loans (Top 20)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _analysis!.highRiskLoans.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final loan = _analysis!.highRiskLoans[index];
                return _buildHighRiskLoanItem(loan);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighRiskLoanItem(LoanRiskDetail loan) {
    Color categoryColor;
    switch (loan.riskCategory) {
      case 'Substandard':
        categoryColor = Colors.orange;
        break;
      case 'Doubtful':
        categoryColor = Colors.deepOrange;
        break;
      case 'Loss':
        categoryColor = Colors.red;
        break;
      default:
        categoryColor = Colors.grey;
    }

    return InkWell(
      onTap: () async {
        // Fetch loan data from Firestore
        try {
          final doc = await FirebaseFirestore.instance
              .collection('saccoplus-loans')
              .doc(loan.loanId)
              .get();
          
          if (doc.exists && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Loan360Screen(
                  loanId: loan.loanId,
                  loanData: doc.data()!,
                ),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading loan: $e')),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning, color: categoryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.borrowerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UGX ${_formatAmount(loan.remainingBalance)} outstanding',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: categoryColor),
                  ),
                  child: Text(
                    loan.riskCategory,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${loan.daysOverdue} days overdue',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}

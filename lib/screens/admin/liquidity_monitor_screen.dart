import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/liquidity_service.dart';

/// Liquidity Monitor - Cash flow dashboard with forecasting
/// Current position, 7-day forecast chart, threshold alerts
class LiquidityMonitorScreen extends StatefulWidget {
  final String tenantId;

  const LiquidityMonitorScreen({Key? key, required this.tenantId}) : super(key: key);

  @override
  State<LiquidityMonitorScreen> createState() => _LiquidityMonitorScreenState();
}

class _LiquidityMonitorScreenState extends State<LiquidityMonitorScreen> {
  final LiquidityService _liquidityService = LiquidityService();
  LiquidityAnalysis? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLiquidityAnalysis();
  }

  Future<void> _loadLiquidityAnalysis() async {
    setState(() => _isLoading = true);
    final analysis = await _liquidityService.getLiquidityAnalysis(widget.tenantId);
    setState(() {
      _analysis = analysis;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquidity Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLiquidityAnalysis,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analysis == null
              ? const Center(child: Text('No data available'))
              : RefreshIndicator(
                  onRefresh: _loadLiquidityAnalysis,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLiquidityStatusCard(),
                        const SizedBox(height: 20),
                        if (_analysis!.alerts.isNotEmpty) ...[
                          _buildAlertsSection(),
                          const SizedBox(height: 20),
                        ],
                        _buildCurrentPositionCard(),
                        const SizedBox(height: 20),
                        _buildCashFlowMetrics(),
                        const SizedBox(height: 20),
                        _buildForecastChart(),
                        const SizedBox(height: 20),
                        _buildRecommendationCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildLiquidityStatusCard() {
    Color statusColor;
    IconData statusIcon;

    switch (_analysis!.liquidityStatus) {
      case 'Excellent':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Good':
        statusColor = Colors.lightGreen;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Fair':
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber;
        break;
      case 'Low':
        statusColor = Colors.deepOrange;
        statusIcon = Icons.error_outline;
        break;
      case 'Critical':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.8), statusColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(statusIcon, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              _analysis!.liquidityStatus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Liquidity Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusMetric(
                  'Liquidity Ratio',
                  '${_analysis!.liquidityRatio.toStringAsFixed(1)}%',
                ),
                _buildStatusMetric(
                  'Cash Coverage',
                  '${_analysis!.cashCoverageDays.toStringAsFixed(0)} days',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMetric(String label, String value) {
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

  Widget _buildAlertsSection() {
    return Card(
      elevation: 2,
      color: Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Active Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _analysis!.alerts.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final alert = _analysis!.alerts[index];
                return _buildAlertItem(alert);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(LiquidityAlert alert) {
    Color alertColor;
    IconData alertIcon;

    switch (alert.severity) {
      case 'critical':
        alertColor = Colors.red;
        alertIcon = Icons.error;
        break;
      case 'warning':
        alertColor = Colors.orange;
        alertIcon = Icons.warning;
        break;
      default:
        alertColor = Colors.blue;
        alertIcon = Icons.info;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(alertIcon, color: alertColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.metric,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: alertColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                alert.message,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPositionCard() {
    final isPositive = _analysis!.currentCashPosition >= 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Cash Position',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPositive ? Icons.account_balance_wallet : Icons.warning,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'UGX ${_formatAmount(_analysis!.currentCashPosition)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPositionMetric(
                  'Total Deposits',
                  _analysis!.totalDeposits,
                  Colors.green,
                  Icons.arrow_downward,
                ),
                _buildPositionMetric(
                  'Total Withdrawals',
                  _analysis!.totalWithdrawals,
                  Colors.red,
                  Icons.arrow_upward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionMetric(String label, double amount, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'UGX ${_formatAmount(amount)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCashFlowMetrics() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cash Flow Analysis (Last 7 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildFlowMetricRow(
              'Deposits',
              _analysis!.last7DaysDeposits,
              Colors.green,
              Icons.add_circle,
            ),
            const Divider(height: 24),
            _buildFlowMetricRow(
              'Withdrawals',
              _analysis!.last7DaysWithdrawals,
              Colors.red,
              Icons.remove_circle,
            ),
            const Divider(height: 24),
            _buildFlowMetricRow(
              'Loan Repayments',
              _analysis!.last7DaysRepayments,
              Colors.blue,
              Icons.payments,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _analysis!.netDailyFlow >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: _analysis!.netDailyFlow >= 0 ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Avg Daily Net Flow',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'UGX ${_formatAmount(_analysis!.netDailyFlow)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _analysis!.netDailyFlow >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowMetricRow(String label, double amount, Color color, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          'UGX ${_formatAmount(amount)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildForecastChart() {
    if (_analysis!.forecast.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No forecast data')),
        ),
      );
    }

    final maxY = _analysis!.forecast
        .map((f) => f.projectedCash)
        .reduce((a, b) => a > b ? a : b);
    final minY = _analysis!.forecast
        .map((f) => f.projectedCash)
        .reduce((a, b) => a < b ? a : b);
    
    final yRange = maxY - minY;
    final chartMaxY = (maxY + (yRange * 0.2)).toDouble();
    final chartMinY = (minY < 0 ? minY - (yRange.abs() * 0.2) : 0.0).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7-Day Cash Flow Forecast',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: chartMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _analysis!.forecast.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.projectedCash);
                      }).toList(),
                      isCurved: true,
                      color: _analysis!.forecast.any((f) => f.projectedCash < 0)
                          ? Colors.red
                          : Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: spot.y < 0 ? Colors.red : Colors.green,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: (_analysis!.forecast.any((f) => f.projectedCash < 0)
                                ? Colors.red
                                : Colors.green)
                            .withOpacity(0.1),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _analysis!.forecast.length) {
                            final date = _analysis!.forecast[value.toInt()].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM\ndd').format(date),
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
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
                        reservedSize: 50,
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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (chartMaxY - chartMinY) / 5,
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = _analysis!.forecast[spot.spotIndex].date;
                          return LineTooltipItem(
                            '${DateFormat('MMM dd').format(date)}\nUGX ${_formatAmount(spot.y)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Card(
      elevation: 2,
      color: _analysis!.isHealthy ? Colors.blue[50] : Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _analysis!.isHealthy ? Icons.lightbulb : Icons.priority_high,
                  color: _analysis!.isHealthy ? Colors.blue[700] : Colors.orange[700],
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recommendation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _analysis!.recommendation,
              style: const TextStyle(fontSize: 15),
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

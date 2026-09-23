import 'package:flutter/material.dart';
import '../services/enhanced_metrics_service.dart';

/// Enhanced metrics display card with PAR rates and health indicators
/// Color-coded health scores with trend indicators
class EnhancedMetricsCard extends StatelessWidget {
  final EnhancedMetrics metrics;
  final VoidCallback? onTap;

  const EnhancedMetricsCard({
    Key? key,
    required this.metrics,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Portfolio Health',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildHealthBadge(),
                ],
              ),
              const SizedBox(height: 16),
              _buildHealthScoreIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Portfolio at Risk (PAR)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildPARMetrics(),
              const SizedBox(height: 20),
              const Text(
                'Key Indicators',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              _buildKeyIndicators(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthBadge() {
    Color badgeColor;
    IconData icon;

    switch (metrics.healthStatus) {
      case 'Excellent':
        badgeColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'Good':
        badgeColor = Colors.lightGreen;
        icon = Icons.check_circle_outline;
        break;
      case 'Fair':
        badgeColor = Colors.orange;
        icon = Icons.warning_amber;
        break;
      case 'Poor':
        badgeColor = Colors.red;
        icon = Icons.error;
        break;
      default:
        badgeColor = Colors.grey;
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 16),
          const SizedBox(width: 6),
          Text(
            metrics.healthStatus,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreIndicator() {
    final score = metrics.portfolioHealthScore;
    Color scoreColor;

    if (score >= 85) {
      scoreColor = Colors.green;
    } else if (score >= 70) {
      scoreColor = Colors.lightGreen;
    } else if (score >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${score.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            const Text(
              '/100',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPARMetrics() {
    return Column(
      children: [
        _buildPARRow('PAR 30', metrics.par30Rate, metrics.par30Amount),
        const SizedBox(height: 8),
        _buildPARRow('PAR 60', metrics.par60Rate, metrics.par60Amount),
        const SizedBox(height: 8),
        _buildPARRow('PAR 90', metrics.par90Rate, metrics.par90Amount),
      ],
    );
  }

  Widget _buildPARRow(String label, double rate, double amount) {
    Color rateColor;
    if (rate < 2) {
      rateColor = Colors.green;
    } else if (rate < 5) {
      rateColor = Colors.orange;
    } else {
      rateColor = Colors.red;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rateColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: rateColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₦${_formatAmount(amount)}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyIndicators(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildIndicatorChip(
          'Member Growth',
          '${metrics.memberGrowthRate.toStringAsFixed(1)}%',
          Icons.trending_up,
          metrics.memberGrowthRate > 0 ? Colors.green : Colors.grey,
        ),
        _buildIndicatorChip(
          'Collection Eff.',
          '${metrics.collectionEfficiency.toStringAsFixed(1)}%',
          Icons.payment,
          metrics.collectionEfficiency >= 80 ? Colors.green : Colors.orange,
        ),
        _buildIndicatorChip(
          'Liquidity',
          '${metrics.liquidityRatio.toStringAsFixed(1)}%',
          Icons.water_drop,
          metrics.liquidityRatio >= 15 ? Colors.green : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildIndicatorChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
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

/// Compact version for dashboard grid
class EnhancedMetricsCompactCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const EnhancedMetricsCompactCard({
    Key? key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: color, size: 32),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_forward, color: color, size: 16),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Liquidity monitoring and cash flow forecasting service
/// Tracks cash position, projects inflows/outflows, monitors thresholds
class LiquidityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive liquidity analysis with 7-day forecast
  Future<LiquidityAnalysis> getLiquidityAnalysis(String tenantId) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final sevenDaysAhead = now.add(const Duration(days: 7));

      // Calculate current cash position from teller transactions
      final depositsSnapshot = await _firestore
          .collection('saccoplus-teller-transactions')
          .where('tenantId', isEqualTo: tenantId)
          .where('type', isEqualTo: 'deposit')
          .get();

      final withdrawalsSnapshot = await _firestore
          .collection('saccoplus-teller-transactions')
          .where('tenantId', isEqualTo: tenantId)
          .where('type', isEqualTo: 'withdrawal')
          .get();

      double totalDeposits = 0;
      double totalWithdrawals = 0;

      for (var doc in depositsSnapshot.docs) {
        totalDeposits += (doc.data()['amount'] ?? 0).toDouble();
      }

      for (var doc in withdrawalsSnapshot.docs) {
        totalWithdrawals += (doc.data()['amount'] ?? 0).toDouble();
      }

      final double currentCashPosition = totalDeposits - totalWithdrawals;

      // Get loan disbursements (outflows)
      final loansSnapshot = await _firestore
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      double totalLoansDisbursed = 0;
      double activeLoanBalance = 0;

      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        totalLoansDisbursed += (data['loanAmount'] ?? 0).toDouble();
        if (data['status'] == 'active') {
          activeLoanBalance += (data['remainingBalance'] ?? 0).toDouble();
        }
      }

      // Get loan repayments (inflows) - last 7 days
      final recentRepaymentsSnapshot = await _firestore
          .collection('loan_repayments')
          .where('tenantId', isEqualTo: tenantId)
          .where('paymentDate', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      double last7DaysRepayments = 0;
      for (var doc in recentRepaymentsSnapshot.docs) {
        last7DaysRepayments += (doc.data()['amount'] ?? 0).toDouble();
      }

      // Get recent deposits (last 7 days)
      final recentDepositsSnapshot = await _firestore
          .collection('saccoplus-teller-transactions')
          .where('tenantId', isEqualTo: tenantId)
          .where('type', isEqualTo: 'deposit')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      double last7DaysDeposits = 0;
      for (var doc in recentDepositsSnapshot.docs) {
        last7DaysDeposits += (doc.data()['amount'] ?? 0).toDouble();
      }

      // Get recent withdrawals (last 7 days)
      final recentWithdrawalsSnapshot = await _firestore
          .collection('saccoplus-teller-transactions')
          .where('tenantId', isEqualTo: tenantId)
          .where('type', isEqualTo: 'withdrawal')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      double last7DaysWithdrawals = 0;
      for (var doc in recentWithdrawalsSnapshot.docs) {
        last7DaysWithdrawals += (doc.data()['amount'] ?? 0).toDouble();
      }

      // Calculate average daily flows
      final double avgDailyInflow = (last7DaysDeposits + last7DaysRepayments) / 7;
      final double avgDailyOutflow = last7DaysWithdrawals / 7;
      final double netDailyFlow = avgDailyInflow - avgDailyOutflow;

      // Generate 7-day forecast
      List<DailyForecast> forecast = [];
      double projectedCash = currentCashPosition;

      for (int i = 1; i <= 7; i++) {
        final forecastDate = now.add(Duration(days: i));
        projectedCash += netDailyFlow;

        forecast.add(DailyForecast(
          date: forecastDate,
          projectedCash: projectedCash,
          projectedInflow: avgDailyInflow,
          projectedOutflow: avgDailyOutflow,
        ));
      }

      // Calculate liquidity ratio (Cash / Active Loans)
      final double liquidityRatio = activeLoanBalance > 0
          ? (currentCashPosition / activeLoanBalance) * 100
          : 0;

      // Calculate cash coverage days (how many days current cash can cover avg outflows)
      final double cashCoverageDays = avgDailyOutflow > 0
          ? currentCashPosition / avgDailyOutflow
          : 999; // Effectively infinite if no outflows

      // Determine liquidity status
      String liquidityStatus;
      bool isHealthy;
      String recommendation;

      if (liquidityRatio >= 20 && cashCoverageDays >= 30) {
        liquidityStatus = 'Excellent';
        isHealthy = true;
        recommendation = 'Liquidity position is strong. Consider expanding loan portfolio.';
      } else if (liquidityRatio >= 15 && cashCoverageDays >= 20) {
        liquidityStatus = 'Good';
        isHealthy = true;
        recommendation = 'Liquidity is healthy. Monitor daily flows regularly.';
      } else if (liquidityRatio >= 10 && cashCoverageDays >= 15) {
        liquidityStatus = 'Fair';
        isHealthy = true;
        recommendation = 'Liquidity is adequate but watch closely. Focus on collections.';
      } else if (liquidityRatio >= 5 && cashCoverageDays >= 7) {
        liquidityStatus = 'Low';
        isHealthy = false;
        recommendation = 'WARNING: Low liquidity. Accelerate collections and reduce disbursements.';
      } else {
        liquidityStatus = 'Critical';
        isHealthy = false;
        recommendation = 'URGENT: Critical liquidity shortage. Immediate action required!';
      }

      // Check for threshold breaches
      List<LiquidityAlert> alerts = [];

      // Alert: Low liquidity ratio
      if (liquidityRatio < 10) {
        alerts.add(LiquidityAlert(
          severity: liquidityRatio < 5 ? 'critical' : 'warning',
          message: 'Liquidity ratio is ${liquidityRatio.toStringAsFixed(1)}% (minimum recommended: 10%)',
          metric: 'Liquidity Ratio',
          value: liquidityRatio,
          threshold: 10,
        ));
      }

      // Alert: Low cash coverage
      if (cashCoverageDays < 15) {
        alerts.add(LiquidityAlert(
          severity: cashCoverageDays < 7 ? 'critical' : 'warning',
          message: 'Cash covers only ${cashCoverageDays.toStringAsFixed(1)} days of outflows (recommended: 15+ days)',
          metric: 'Cash Coverage',
          value: cashCoverageDays,
          threshold: 15,
        ));
      }

      // Alert: Negative projected cash in next 7 days
      final negativeForecast = forecast.where((f) => f.projectedCash < 0).toList();
      if (negativeForecast.isNotEmpty) {
        final daysUntilNegative = forecast.indexOf(negativeForecast.first) + 1;
        alerts.add(LiquidityAlert(
          severity: 'critical',
          message: 'Projected negative cash position in $daysUntilNegative days',
          metric: 'Cash Forecast',
          value: negativeForecast.first.projectedCash,
          threshold: 0,
        ));
      }

      // Alert: Declining trend
      if (netDailyFlow < 0) {
        alerts.add(LiquidityAlert(
          severity: 'warning',
          message: 'Negative net daily cash flow: ${netDailyFlow.toStringAsFixed(0)} per day',
          metric: 'Net Daily Flow',
          value: netDailyFlow,
          threshold: 0,
        ));
      }

      return LiquidityAnalysis(
        currentCashPosition: currentCashPosition,
        totalDeposits: totalDeposits,
        totalWithdrawals: totalWithdrawals,
        activeLoanBalance: activeLoanBalance,
        totalLoansDisbursed: totalLoansDisbursed,
        last7DaysDeposits: last7DaysDeposits,
        last7DaysWithdrawals: last7DaysWithdrawals,
        last7DaysRepayments: last7DaysRepayments,
        avgDailyInflow: avgDailyInflow,
        avgDailyOutflow: avgDailyOutflow,
        netDailyFlow: netDailyFlow,
        liquidityRatio: liquidityRatio,
        cashCoverageDays: cashCoverageDays,
        liquidityStatus: liquidityStatus,
        isHealthy: isHealthy,
        recommendation: recommendation,
        forecast: forecast,
        alerts: alerts,
      );
    } catch (e) {
      print('Error calculating liquidity analysis: $e');
      return LiquidityAnalysis.empty();
    }
  }
}

/// Liquidity analysis data model
class LiquidityAnalysis {
  final double currentCashPosition;
  final double totalDeposits;
  final double totalWithdrawals;
  final double activeLoanBalance;
  final double totalLoansDisbursed;
  final double last7DaysDeposits;
  final double last7DaysWithdrawals;
  final double last7DaysRepayments;
  final double avgDailyInflow;
  final double avgDailyOutflow;
  final double netDailyFlow;
  final double liquidityRatio;
  final double cashCoverageDays;
  final String liquidityStatus;
  final bool isHealthy;
  final String recommendation;
  final List<DailyForecast> forecast;
  final List<LiquidityAlert> alerts;

  LiquidityAnalysis({
    required this.currentCashPosition,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.activeLoanBalance,
    required this.totalLoansDisbursed,
    required this.last7DaysDeposits,
    required this.last7DaysWithdrawals,
    required this.last7DaysRepayments,
    required this.avgDailyInflow,
    required this.avgDailyOutflow,
    required this.netDailyFlow,
    required this.liquidityRatio,
    required this.cashCoverageDays,
    required this.liquidityStatus,
    required this.isHealthy,
    required this.recommendation,
    required this.forecast,
    required this.alerts,
  });

  factory LiquidityAnalysis.empty() {
    return LiquidityAnalysis(
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
      liquidityStatus: 'N/A',
      isHealthy: true,
      recommendation: 'Insufficient data',
      forecast: [],
      alerts: [],
    );
  }
}

/// Daily forecast model
class DailyForecast {
  final DateTime date;
  final double projectedCash;
  final double projectedInflow;
  final double projectedOutflow;

  DailyForecast({
    required this.date,
    required this.projectedCash,
    required this.projectedInflow,
    required this.projectedOutflow,
  });
}

/// Liquidity alert model
class LiquidityAlert {
  final String severity; // 'critical', 'warning', 'info'
  final String message;
  final String metric;
  final double value;
  final double threshold;

  LiquidityAlert({
    required this.severity,
    required this.message,
    required this.metric,
    required this.value,
    required this.threshold,
  });
}

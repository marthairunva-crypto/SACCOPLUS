import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced metrics calculation service for admin dashboard
/// Calculates PAR rates, portfolio health, collection efficiency
class EnhancedMetricsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive enhanced metrics
  Future<EnhancedMetrics> getEnhancedMetrics(String tenantId) async {
    try {
      // Get all active loans
      final loansSnapshot = await _firestore
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: tenantId)
          .where('status', isEqualTo: 'active')
          .get();

      final now = DateTime.now();
      double totalPortfolioValue = 0;
      double par30Amount = 0;
      double par60Amount = 0;
      double par90Amount = 0;
      int totalLoans = loansSnapshot.docs.length;

      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        final double remainingBalance = (data['remainingBalance'] ?? 0).toDouble();
        totalPortfolioValue += remainingBalance;

        // Check if loan has overdue payments
        final DateTime? lastPaymentDate = data['lastPaymentDate'] != null
            ? (data['lastPaymentDate'] as Timestamp).toDate()
            : null;
        final DateTime? nextPaymentDate = data['nextPaymentDate'] != null
            ? (data['nextPaymentDate'] as Timestamp).toDate()
            : null;

        if (nextPaymentDate != null && nextPaymentDate.isBefore(now)) {
          final int daysOverdue = now.difference(nextPaymentDate).inDays;

          if (daysOverdue >= 30) {
            par30Amount += remainingBalance;
          }
          if (daysOverdue >= 60) {
            par60Amount += remainingBalance;
          }
          if (daysOverdue >= 90) {
            par90Amount += remainingBalance;
          }
        }
      }

      // Calculate PAR rates
      final double par30Rate = totalPortfolioValue > 0 ? (par30Amount / totalPortfolioValue) * 100 : 0;
      final double par60Rate = totalPortfolioValue > 0 ? (par60Amount / totalPortfolioValue) * 100 : 0;
      final double par90Rate = totalPortfolioValue > 0 ? (par90Amount / totalPortfolioValue) * 100 : 0;

      // Get member growth (last 30 days)
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final newMembersSnapshot = await _firestore
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .where('registrationDate', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final int newMembers30Days = newMembersSnapshot.docs.length;

      // Get total members for growth rate
      final totalMembersSnapshot = await _firestore
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      final int totalMembers = totalMembersSnapshot.docs.length;
      final double memberGrowthRate = totalMembers > 0 
          ? (newMembers30Days / totalMembers) * 100 
          : 0;

      // Calculate collection efficiency (last 30 days)
      final repaymentsSnapshot = await _firestore
          .collection('loan_repayments')
          .where('tenantId', isEqualTo: tenantId)
          .where('paymentDate', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      double totalCollected = 0;
      for (var doc in repaymentsSnapshot.docs) {
        totalCollected += (doc.data()['amount'] ?? 0).toDouble();
      }

      // Expected collections (simplified: total portfolio / 12 months)
      final double expectedMonthlyCollection = totalPortfolioValue / 12;
      final double collectionEfficiency = expectedMonthlyCollection > 0
          ? (totalCollected / expectedMonthlyCollection) * 100
          : 0;

      // Portfolio health score (0-100)
      // Formula: 100 - (PAR30*0.5 + PAR90*1.5) capped at 0
      final double healthScore = (100 - (par30Rate * 0.5 + par90Rate * 1.5)).clamp(0, 100);

      // Determine health status
      String healthStatus;
      if (healthScore >= 85) {
        healthStatus = 'Excellent';
      } else if (healthScore >= 70) {
        healthStatus = 'Good';
      } else if (healthScore >= 50) {
        healthStatus = 'Fair';
      } else {
        healthStatus = 'Poor';
      }

      // Get liquidity ratio (simplified)
      final cashSnapshot = await _firestore
          .collection('saccoplus-teller-transactions')
          .where('tenantId', isEqualTo: tenantId)
          .where('type', isEqualTo: 'deposit')
          .get();

      double totalCash = 0;
      for (var doc in cashSnapshot.docs) {
        totalCash += (doc.data()['amount'] ?? 0).toDouble();
      }

      final double liquidityRatio = totalPortfolioValue > 0
          ? (totalCash / totalPortfolioValue) * 100
          : 0;

      return EnhancedMetrics(
        par30Rate: par30Rate,
        par60Rate: par60Rate,
        par90Rate: par90Rate,
        par30Amount: par30Amount,
        par60Amount: par60Amount,
        par90Amount: par90Amount,
        totalPortfolioValue: totalPortfolioValue,
        totalLoans: totalLoans,
        portfolioHealthScore: healthScore,
        healthStatus: healthStatus,
        memberGrowthRate: memberGrowthRate,
        newMembers30Days: newMembers30Days,
        totalMembers: totalMembers,
        collectionEfficiency: collectionEfficiency,
        totalCollected30Days: totalCollected,
        liquidityRatio: liquidityRatio,
        totalCash: totalCash,
      );
    } catch (e) {
      print('Error calculating enhanced metrics: $e');
      return EnhancedMetrics.empty();
    }
  }
}

/// Enhanced metrics data model
class EnhancedMetrics {
  final double par30Rate;
  final double par60Rate;
  final double par90Rate;
  final double par30Amount;
  final double par60Amount;
  final double par90Amount;
  final double totalPortfolioValue;
  final int totalLoans;
  final double portfolioHealthScore;
  final String healthStatus;
  final double memberGrowthRate;
  final int newMembers30Days;
  final int totalMembers;
  final double collectionEfficiency;
  final double totalCollected30Days;
  final double liquidityRatio;
  final double totalCash;

  EnhancedMetrics({
    required this.par30Rate,
    required this.par60Rate,
    required this.par90Rate,
    required this.par30Amount,
    required this.par60Amount,
    required this.par90Amount,
    required this.totalPortfolioValue,
    required this.totalLoans,
    required this.portfolioHealthScore,
    required this.healthStatus,
    required this.memberGrowthRate,
    required this.newMembers30Days,
    required this.totalMembers,
    required this.collectionEfficiency,
    required this.totalCollected30Days,
    required this.liquidityRatio,
    required this.totalCash,
  });

  factory EnhancedMetrics.empty() {
    return EnhancedMetrics(
      par30Rate: 0,
      par60Rate: 0,
      par90Rate: 0,
      par30Amount: 0,
      par60Amount: 0,
      par90Amount: 0,
      totalPortfolioValue: 0,
      totalLoans: 0,
      portfolioHealthScore: 100,
      healthStatus: 'N/A',
      memberGrowthRate: 0,
      newMembers30Days: 0,
      totalMembers: 0,
      collectionEfficiency: 0,
      totalCollected30Days: 0,
      liquidityRatio: 0,
      totalCash: 0,
    );
  }
}

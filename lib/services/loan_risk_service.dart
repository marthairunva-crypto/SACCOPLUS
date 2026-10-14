import 'package:cloud_firestore/cloud_firestore.dart';

/// Loan risk analysis service for portfolio classification
/// Implements 5-tier risk classification system (Performing, Watch, Substandard, Doubtful, Loss)
class LoanRiskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get comprehensive loan risk analysis
  Future<LoanRiskAnalysis> getLoanRiskAnalysis(String tenantId) async {
    try {
      // Get all active loans
      final loansSnapshot = await _firestore
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: tenantId)
          .where('status', isEqualTo: 'active')
          .get();

      final now = DateTime.now();
      
      // Initialize classification counters
      int performingCount = 0;
      int watchCount = 0;
      int substandardCount = 0;
      int doubtfulCount = 0;
      int lossCount = 0;

      double performingAmount = 0;
      double watchAmount = 0;
      double substandardAmount = 0;
      double doubtfulAmount = 0;
      double lossAmount = 0;

      // Aging buckets
      int current = 0; // 0 days
      int aging1_30 = 0;
      int aging31_60 = 0;
      int aging61_90 = 0;
      int aging91_180 = 0;
      int aging180Plus = 0;

      double currentAmount = 0;
      double aging1_30Amount = 0;
      double aging31_60Amount = 0;
      double aging61_90Amount = 0;
      double aging91_180Amount = 0;
      double aging180PlusAmount = 0;

      List<LoanRiskDetail> highRiskLoans = [];

      for (var doc in loansSnapshot.docs) {
        final data = doc.data();
        final String loanId = doc.id;
        final String borrowerName = data['borrowerName'] ?? 'Unknown';
        final double remainingBalance = (data['remainingBalance'] ?? 0).toDouble();
        final double loanAmount = (data['loanAmount'] ?? 0).toDouble();

        // Check overdue status
        final DateTime? nextPaymentDate = data['nextPaymentDate'] != null
            ? (data['nextPaymentDate'] as Timestamp).toDate()
            : null;

        int daysOverdue = 0;
        if (nextPaymentDate != null && nextPaymentDate.isBefore(now)) {
          daysOverdue = now.difference(nextPaymentDate).inDays;
        }

        // Classify loan based on days overdue
        // Standard risk classification:
        // Performing: 0 days overdue
        // Watch: 1-30 days overdue
        // Substandard: 31-90 days overdue
        // Doubtful: 91-180 days overdue
        // Loss: 180+ days overdue

        String riskCategory;
        if (daysOverdue == 0) {
          performingCount++;
          performingAmount += remainingBalance;
          riskCategory = 'Performing';
          current++;
          currentAmount += remainingBalance;
        } else if (daysOverdue <= 30) {
          watchCount++;
          watchAmount += remainingBalance;
          riskCategory = 'Watch';
          aging1_30++;
          aging1_30Amount += remainingBalance;
        } else if (daysOverdue <= 90) {
          substandardCount++;
          substandardAmount += remainingBalance;
          riskCategory = 'Substandard';
          if (daysOverdue <= 60) {
            aging31_60++;
            aging31_60Amount += remainingBalance;
          } else {
            aging61_90++;
            aging61_90Amount += remainingBalance;
          }
        } else if (daysOverdue <= 180) {
          doubtfulCount++;
          doubtfulAmount += remainingBalance;
          riskCategory = 'Doubtful';
          aging91_180++;
          aging91_180Amount += remainingBalance;
        } else {
          lossCount++;
          lossAmount += remainingBalance;
          riskCategory = 'Loss';
          aging180Plus++;
          aging180PlusAmount += remainingBalance;
        }

        // Add to high risk list if Substandard or worse
        if (daysOverdue > 30) {
          highRiskLoans.add(LoanRiskDetail(
            loanId: loanId,
            borrowerName: borrowerName,
            loanAmount: loanAmount,
            remainingBalance: remainingBalance,
            daysOverdue: daysOverdue,
            riskCategory: riskCategory,
            nextPaymentDate: nextPaymentDate,
          ));
        }
      }

      // Sort high risk loans by days overdue (descending)
      highRiskLoans.sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));

      // Calculate total portfolio
      final double totalPortfolio = performingAmount + watchAmount + 
          substandardAmount + doubtfulAmount + lossAmount;

      // Calculate percentages
      final double performingPercent = totalPortfolio > 0 
          ? (performingAmount / totalPortfolio) * 100 : 0;
      final double watchPercent = totalPortfolio > 0 
          ? (watchAmount / totalPortfolio) * 100 : 0;
      final double substandardPercent = totalPortfolio > 0 
          ? (substandardAmount / totalPortfolio) * 100 : 0;
      final double doubtfulPercent = totalPortfolio > 0 
          ? (doubtfulAmount / totalPortfolio) * 100 : 0;
      final double lossPercent = totalPortfolio > 0 
          ? (lossAmount / totalPortfolio) * 100 : 0;

      // Calculate overall risk score (0-100, higher is better)
      // Formula: Performing * 1.0 - Watch * 0.1 - Substandard * 0.3 - Doubtful * 0.6 - Loss * 1.0
      final double riskScore = (performingPercent * 1.0 - 
          watchPercent * 0.1 - 
          substandardPercent * 0.3 - 
          doubtfulPercent * 0.6 - 
          lossPercent * 1.0).clamp(0, 100);

      return LoanRiskAnalysis(
        totalLoans: loansSnapshot.docs.length,
        totalPortfolio: totalPortfolio,
        performingCount: performingCount,
        watchCount: watchCount,
        substandardCount: substandardCount,
        doubtfulCount: doubtfulCount,
        lossCount: lossCount,
        performingAmount: performingAmount,
        watchAmount: watchAmount,
        substandardAmount: substandardAmount,
        doubtfulAmount: doubtfulAmount,
        lossAmount: lossAmount,
        performingPercent: performingPercent,
        watchPercent: watchPercent,
        substandardPercent: substandardPercent,
        doubtfulPercent: doubtfulPercent,
        lossPercent: lossPercent,
        currentCount: current,
        aging1_30Count: aging1_30,
        aging31_60Count: aging31_60,
        aging61_90Count: aging61_90,
        aging91_180Count: aging91_180,
        aging180PlusCount: aging180Plus,
        currentAmount: currentAmount,
        aging1_30Amount: aging1_30Amount,
        aging31_60Amount: aging31_60Amount,
        aging61_90Amount: aging61_90Amount,
        aging91_180Amount: aging91_180Amount,
        aging180PlusAmount: aging180PlusAmount,
        riskScore: riskScore,
        highRiskLoans: highRiskLoans.take(20).toList(), // Top 20 high risk loans
      );
    } catch (e) {
      print('Error calculating loan risk analysis: $e');
      return LoanRiskAnalysis.empty();
    }
  }

  /// Get detailed information about a specific loan's risk
  Future<LoanRiskDetail?> getLoanRiskDetail(String tenantId, String loanId) async {
    try {
      final doc = await _firestore
          .collection('saccoplus-loans')
          .doc(loanId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['tenantId'] != tenantId) return null;

      final now = DateTime.now();
      final DateTime? nextPaymentDate = data['nextPaymentDate'] != null
          ? (data['nextPaymentDate'] as Timestamp).toDate()
          : null;

      int daysOverdue = 0;
      if (nextPaymentDate != null && nextPaymentDate.isBefore(now)) {
        daysOverdue = now.difference(nextPaymentDate).inDays;
      }

      String riskCategory;
      if (daysOverdue == 0) {
        riskCategory = 'Performing';
      } else if (daysOverdue <= 30) {
        riskCategory = 'Watch';
      } else if (daysOverdue <= 90) {
        riskCategory = 'Substandard';
      } else if (daysOverdue <= 180) {
        riskCategory = 'Doubtful';
      } else {
        riskCategory = 'Loss';
      }

      return LoanRiskDetail(
        loanId: loanId,
        borrowerName: data['borrowerName'] ?? 'Unknown',
        loanAmount: (data['loanAmount'] ?? 0).toDouble(),
        remainingBalance: (data['remainingBalance'] ?? 0).toDouble(),
        daysOverdue: daysOverdue,
        riskCategory: riskCategory,
        nextPaymentDate: nextPaymentDate,
      );
    } catch (e) {
      print('Error getting loan risk detail: $e');
      return null;
    }
  }
}

/// Loan risk analysis data model
class LoanRiskAnalysis {
  final int totalLoans;
  final double totalPortfolio;
  
  // Classification counts
  final int performingCount;
  final int watchCount;
  final int substandardCount;
  final int doubtfulCount;
  final int lossCount;
  
  // Classification amounts
  final double performingAmount;
  final double watchAmount;
  final double substandardAmount;
  final double doubtfulAmount;
  final double lossAmount;
  
  // Classification percentages
  final double performingPercent;
  final double watchPercent;
  final double substandardPercent;
  final double doubtfulPercent;
  final double lossPercent;
  
  // Aging buckets counts
  final int currentCount;
  final int aging1_30Count;
  final int aging31_60Count;
  final int aging61_90Count;
  final int aging91_180Count;
  final int aging180PlusCount;
  
  // Aging buckets amounts
  final double currentAmount;
  final double aging1_30Amount;
  final double aging31_60Amount;
  final double aging61_90Amount;
  final double aging91_180Amount;
  final double aging180PlusAmount;
  
  final double riskScore;
  final List<LoanRiskDetail> highRiskLoans;

  LoanRiskAnalysis({
    required this.totalLoans,
    required this.totalPortfolio,
    required this.performingCount,
    required this.watchCount,
    required this.substandardCount,
    required this.doubtfulCount,
    required this.lossCount,
    required this.performingAmount,
    required this.watchAmount,
    required this.substandardAmount,
    required this.doubtfulAmount,
    required this.lossAmount,
    required this.performingPercent,
    required this.watchPercent,
    required this.substandardPercent,
    required this.doubtfulPercent,
    required this.lossPercent,
    required this.currentCount,
    required this.aging1_30Count,
    required this.aging31_60Count,
    required this.aging61_90Count,
    required this.aging91_180Count,
    required this.aging180PlusCount,
    required this.currentAmount,
    required this.aging1_30Amount,
    required this.aging31_60Amount,
    required this.aging61_90Amount,
    required this.aging91_180Amount,
    required this.aging180PlusAmount,
    required this.riskScore,
    required this.highRiskLoans,
  });

  factory LoanRiskAnalysis.empty() {
    return LoanRiskAnalysis(
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
      riskScore: 100,
      highRiskLoans: [],
    );
  }
}

/// Individual loan risk detail
class LoanRiskDetail {
  final String loanId;
  final String borrowerName;
  final double loanAmount;
  final double remainingBalance;
  final int daysOverdue;
  final String riskCategory;
  final DateTime? nextPaymentDate;

  LoanRiskDetail({
    required this.loanId,
    required this.borrowerName,
    required this.loanAmount,
    required this.remainingBalance,
    required this.daysOverdue,
    required this.riskCategory,
    this.nextPaymentDate,
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/constants.dart';

/// Service for calculating action-required alerts for administrators
class AlertsService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;

  /// Get all alerts requiring admin attention
  static Future<Map<String, dynamic>> getAllAlerts() async {
    try {
      final results = await Future.wait([
        getPendingLoanApprovals(),
        getOverdueLoans(),
        getPendingKYC(),
        checkLiquidity(),
        getFailedTransactions(),
      ]);

      return {
        'pendingLoanApprovals': results[0],
        'overdueLoans': results[1],
        'pendingKYC': results[2],
        'liquidityStatus': results[3],
        'failedTransactions': results[4],
        'totalAlerts': _countCriticalAlerts(results),
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('❌ Error getting alerts: $e');
      return {
        'pendingLoanApprovals': {'count': 0, 'severity': 'none'},
        'overdueLoans': {'count': 0, 'severity': 'none'},
        'pendingKYC': {'count': 0, 'severity': 'none'},
        'liquidityStatus': {'status': 'unknown', 'severity': 'none'},
        'failedTransactions': {'count': 0, 'severity': 'none'},
        'totalAlerts': 0,
        'lastUpdated': DateTime.now(),
      };
    }
  }

  /// Count pending loan applications awaiting approval
  static Future<Map<String, dynamic>> getPendingLoanApprovals() async {
    try {
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('status', isEqualTo: AppConstants.statusPending)
          .get();

      final count = snapshot.docs.length;
      
      return {
        'count': count,
        'severity': count > 10 ? 'critical' : count > 5 ? 'high' : count > 0 ? 'medium' : 'none',
        'message': count > 0 
            ? '$count loan${count == 1 ? '' : 's'} awaiting approval'
            : 'No pending loan approvals',
        'action': 'view_pending_loans',
      };
    } catch (e) {
      print('❌ Error getting pending loans: $e');
      return {'count': 0, 'severity': 'none', 'message': 'Unable to check', 'action': null};
    }
  }

  /// Count overdue loans
  static Future<Map<String, dynamic>> getOverdueLoans() async {
    try {
      final now = DateTime.now();
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();

      int overdueCount = 0;
      int criticalOverdueCount = 0; // 90+ days
      int totalOverdueAmount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
        
        if (dueDate != null && dueDate.isBefore(now)) {
          overdueCount++;
          final amount = (data['amount'] as num?)?.toInt() ?? 0;
          final repaid = (data['totalRepaid'] as num?)?.toInt() ?? 0;
          totalOverdueAmount += (amount - repaid);
          
          final daysOverdue = now.difference(dueDate).inDays;
          if (daysOverdue > 90) criticalOverdueCount++;
        }
      }

      return {
        'count': overdueCount,
        'criticalCount': criticalOverdueCount,
        'totalAmount': totalOverdueAmount,
        'severity': criticalOverdueCount > 0 ? 'critical' 
            : overdueCount > 20 ? 'high' 
            : overdueCount > 10 ? 'medium' 
            : overdueCount > 0 ? 'low' : 'none',
        'message': overdueCount > 0
            ? '$overdueCount loan${overdueCount == 1 ? '' : 's'} overdue'
            : 'No overdue loans',
        'action': 'view_overdue_loans',
      };
    } catch (e) {
      print('❌ Error getting overdue loans: $e');
      return {'count': 0, 'severity': 'none', 'message': 'Unable to check', 'action': null};
    }
  }

  /// Count members with pending KYC verification
  static Future<Map<String, dynamic>> getPendingKYC() async {
    try {
      final snapshot = await _db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: _tenantId)
          .where('idStatus', isEqualTo: 'pending')
          .get();

      final count = snapshot.docs.length;

      return {
        'count': count,
        'severity': count > 20 ? 'high' : count > 10 ? 'medium' : count > 0 ? 'low' : 'none',
        'message': count > 0
            ? '$count member${count == 1 ? '' : 's'} pending KYC verification'
            : 'All KYC verifications up to date',
        'action': 'view_pending_kyc',
      };
    } catch (e) {
      print('❌ Error getting pending KYC: $e');
      return {'count': 0, 'severity': 'none', 'message': 'Unable to check', 'action': null};
    }
  }

  /// Check liquidity status
  static Future<Map<String, dynamic>> checkLiquidity() async {
    try {
      // Get cash balance from wallet transactions
      final walletSnapshot = await _db
          .collection('wallet_transactions')
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      int cashBalance = 0;
      for (var doc in walletSnapshot.docs) {
        final type = doc['type'] as String? ?? '';
        final amount = (doc['amount'] as num?)?.toInt() ?? 0;
        
        if (type == 'deposit' || type == 'loan_repayment') {
          cashBalance += amount;
        } else if (type == 'withdrawal' || type == 'loan_disbursement') {
          cashBalance -= amount;
        }
      }

      // Get total member savings (liabilities)
      final membersSnapshot = await _db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      int totalSavings = 0;
      for (var doc in membersSnapshot.docs) {
        final data = doc.data();
        totalSavings += (data['savingsBalance'] as num?)?.toInt() ?? 0;
        totalSavings += (data['sharesValue'] as num?)?.toInt() ?? 0;
      }

      // Calculate liquidity ratio
      final liquidityRatio = totalSavings > 0 ? (cashBalance / totalSavings * 100) : 100.0;

      String status;
      String severity;
      String message;

      if (liquidityRatio >= 20) {
        status = 'healthy';
        severity = 'none';
        message = 'Liquidity is healthy (${liquidityRatio.toStringAsFixed(1)}%)';
      } else if (liquidityRatio >= 10) {
        status = 'caution';
        severity = 'medium';
        message = 'Liquidity needs attention (${liquidityRatio.toStringAsFixed(1)}%)';
      } else {
        status = 'critical';
        severity = 'critical';
        message = 'CRITICAL: Low liquidity (${liquidityRatio.toStringAsFixed(1)}%)';
      }

      return {
        'status': status,
        'ratio': liquidityRatio,
        'cashBalance': cashBalance,
        'totalLiabilities': totalSavings,
        'severity': severity,
        'message': message,
        'action': 'view_liquidity',
      };
    } catch (e) {
      print('❌ Error checking liquidity: $e');
      return {
        'status': 'unknown',
        'severity': 'none',
        'message': 'Unable to check liquidity',
        'action': null
      };
    }
  }

  /// Count failed transactions (placeholder - implement based on your payment tracking)
  static Future<Map<String, dynamic>> getFailedTransactions() async {
    try {
      // Check for failed teller transactions in the last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('status', isEqualTo: 'failed')
          .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
          .get();

      final count = snapshot.docs.length;

      return {
        'count': count,
        'severity': count > 10 ? 'high' : count > 5 ? 'medium' : count > 0 ? 'low' : 'none',
        'message': count > 0
            ? '$count failed transaction${count == 1 ? '' : 's'} (last 7 days)'
            : 'No recent failed transactions',
        'action': 'view_failed_transactions',
      };
    } catch (e) {
      print('❌ Error getting failed transactions: $e');
      return {'count': 0, 'severity': 'none', 'message': 'Unable to check', 'action': null};
    }
  }

  /// Count total critical alerts
  static int _countCriticalAlerts(List<dynamic> results) {
    int count = 0;
    
    for (var result in results) {
      if (result is Map<String, dynamic>) {
        final severity = result['severity'] as String? ?? 'none';
        if (severity == 'critical' || severity == 'high') {
          count++;
        }
      }
    }
    
    return count;
  }
}

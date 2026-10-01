import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/constants.dart';

/// Dashboard service for aggregating SACCO data
class DashboardService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;

  // ─── Get Teller Transaction Summary ───────────────────────────────────────
  static Future<Map<String, dynamic>> getTellerTransactionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      print('🔍 DashboardService.getTellerTransactionSummary:');
      print('   - tenantId: $_tenantId');
      print('   - startDate: $start');
      print('   - endDate: $end');

      Query query = _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end);

      final snapshot = await query.get();

      print('   - Found ${snapshot.docs.length} transactions');
      
      if (snapshot.docs.isEmpty) {
        print('');
        print('❌ ═══════════════════════════════════════════════════════════════════');
        print('❌ NO TRANSACTIONS FOUND - FIRESTORE INDEX REQUIRED!');
        print('❌ ═══════════════════════════════════════════════════════════════════');
        print('❌');
        print('❌ Copy this link and paste in your browser:');
        print('❌');
        print('https://console.firebase.google.com/project/mwiza-projects/firestore/indexes');
        print('');
        print('❌ Then create this index:');
        print('❌   Collection: saccoplus-teller-transactions');
        print('❌   Field 1: tenantId (Ascending)');
        print('❌   Field 2: timestamp (Ascending)');
        print('❌');
        print('❌ ═══════════════════════════════════════════════════════════════════');
        print('');
      }

      int totalDeposits = 0;
      int totalWithdrawals = 0;
      int depositCount = 0;
      int withdrawalCount = 0;
      Map<String, int> byTeller = {};
      Map<String, int> byAccountType = {};
      List<Map<String, dynamic>> recentTransactions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final type = data['type'] as String? ?? '';
        final tellerName = data['tellerName'] as String? ?? 'Unknown';
        final accountType = data['accountType'] as String? ?? 'wallet';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        if (type == 'deposit') {
          totalDeposits += amount;
          depositCount++;
        } else if (type == 'withdrawal') {
          totalWithdrawals += amount;
          withdrawalCount++;
        }

        // Group by teller
        byTeller[tellerName] = (byTeller[tellerName] ?? 0) + amount;

        // Group by account type
        byAccountType[accountType] = (byAccountType[accountType] ?? 0) + amount;

        // Store for recent transactions
        recentTransactions.add({
          'id': doc.id,
          'type': type,
          'amount': amount,
          'memberName': data['memberName'] ?? 'Unknown',
          'tellerName': tellerName,
          'accountType': accountType,
          'timestamp': timestamp,
          'receiptNumber': data['receiptNumber'] ?? '',
        });
      }

      // Sort recent transactions by timestamp (newest first)
      recentTransactions.sort((a, b) {
        final aTime = a['timestamp'] as DateTime?;
        final bTime = b['timestamp'] as DateTime?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return {
        'totalDeposits': totalDeposits,
        'totalWithdrawals': totalWithdrawals,
        'depositCount': depositCount,
        'withdrawalCount': withdrawalCount,
        'netFlow': totalDeposits - totalWithdrawals,
        'totalTransactions': snapshot.docs.length,
        'byTeller': byTeller,
        'byAccountType': byAccountType,
        'recentTransactions': recentTransactions.take(10).toList(),
      };
    } catch (e) {
      return {
        'totalDeposits': 0,
        'totalWithdrawals': 0,
        'depositCount': 0,
        'withdrawalCount': 0,
        'netFlow': 0,
        'totalTransactions': 0,
        'byTeller': {},
        'byAccountType': {},
        'recentTransactions': [],
      };
    }
  }

  // ─── Get Savings Summary ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSavingsSummary() async {
    try {
      print('📊 DashboardService.getSavingsSummary:');
      
      // Query actual savings transactions
      final savingsSnapshot = await _db
          .collection('saccoplus-savings')
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      // Query actual shares transactions
      final sharesSnapshot = await _db
          .collection('saccoplus-shares')
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      // Query members for count
      final membersSnapshot = await _db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      print('   - Found ${savingsSnapshot.docs.length} savings records');
      print('   - Found ${sharesSnapshot.docs.length} shares records');
      print('   - Found ${membersSnapshot.docs.length} members');

      // Calculate total savings
      double totalSavingsDouble = 0;
      Set<String> membersWithSavings = {};
      for (var doc in savingsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? data['availableBalance'] ?? 0).toDouble();
        totalSavingsDouble += amount;
        
        final memberId = data['memberId'] ?? data['farmerId'] ?? '';
        if (memberId.isNotEmpty) {
          membersWithSavings.add(memberId);
        }
      }
      int totalSavings = totalSavingsDouble.toInt();

      // Calculate total shares
      double totalSharesDouble = 0;
      Set<String> membersWithSharesSet = {};
      for (var doc in sharesSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0).toDouble();
        totalSharesDouble += amount;
        
        final memberId = data['memberId'] ?? data['farmerId'] ?? '';
        if (memberId.isNotEmpty) {
          membersWithSharesSet.add(memberId);
        }
      }
      int totalShares = totalSharesDouble.toInt();

      // Calculate loans from member balances
      int totalLoans = 0;
      for (var doc in membersSnapshot.docs) {
        final data = doc.data();
        final loans = (data['loanBalance'] as num?)?.toInt() ?? 0;
        totalLoans += loans;
      }

      print('   - Total Savings: UGX $totalSavings');
      print('   - Total Shares: UGX $totalShares');
      print('   - Total Loans: UGX $totalLoans');
      print('   - Members with savings: ${membersWithSavings.length}');
      print('   - Members with shares: ${membersWithSharesSet.length}');

      return {
        'totalSavings': totalSavings,
        'totalShares': totalShares,
        'totalWallet': 0,
        'totalLoans': totalLoans,
        'totalBalance': totalSavings, // For dashboard display
        'totalAssets': totalSavings + totalShares,
        'membersWithSavings': membersWithSavings.length,
        'membersWithShares': membersWithSharesSet.length,
        'totalMembers': membersSnapshot.docs.length,
      };
    } catch (e) {
      print('❌ Error in getSavingsSummary: $e');
      return {
        'totalSavings': 0,
        'totalShares': 0,
        'totalWallet': 0,
        'totalLoans': 0,
        'totalBalance': 0,
        'totalAssets': 0,
        'membersWithSavings': 0,
        'membersWithShares': 0,
        'totalMembers': 0,
      };
    }
  }

  // ─── Get Daily Deposit/Withdrawal Trends ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> getDepositWithdrawalTrends({
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));

      final snapshot = await _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .get();

      // Group by day
      Map<String, Map<String, int>> dailyData = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp == null) continue;

        final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        
        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {'deposits': 0, 'withdrawals': 0};
        }

        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        final type = data['type'] as String? ?? '';

        if (type == 'deposit') {
          dailyData[dateKey]!['deposits'] = (dailyData[dateKey]!['deposits'] ?? 0) + amount;
        } else if (type == 'withdrawal') {
          dailyData[dateKey]!['withdrawals'] = (dailyData[dateKey]!['withdrawals'] ?? 0) + amount;
        }
      }

      // Create list for all days (including days with no data)
      List<Map<String, dynamic>> trends = [];
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        
        trends.add({
          'date': date,
          'dateKey': dateKey,
          'deposits': dailyData[dateKey]?['deposits'] ?? 0,
          'withdrawals': dailyData[dateKey]?['withdrawals'] ?? 0,
        });
      }

      return trends;
    } catch (e) {
      return [];
    }
  }

  // ─── Format Amount with Commas ────────────────────────────────────────────
  static String formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';
import '../core/constants.dart';
import 'audit_service.dart';

/// Teller service for handling deposits and withdrawals
class TellerService {
  static final _db = FirebaseFirestore.instance;
  
  // Use FirebaseService.sessionTenantId instead of SaccoService to ensure consistency
  static String get _tenantId => FirebaseService.sessionTenantId;

  // ─── Process Deposit ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> processDeposit({
    required String memberId,
    required String memberName,
    required String memberPhone,
    required int amount,
    required String accountType, // 'wallet', 'savings', 'shares'
    required String tellerName,
    required String tellerId,
    String? notes,
  }) async {
    try {
      final transactionRef = _db.collection(AppConstants.tellerTxnCol).doc();
      final transactionId = transactionRef.id;
      final timestamp = DateTime.now();

      // Create transaction record
      final transaction = {
        'id': transactionId,
        'tenantId': _tenantId,
        'type': 'deposit',
        'memberId': memberId,
        'memberName': memberName,
        'memberPhone': memberPhone,
        'amount': amount,
        'accountType': accountType,
        'tellerName': tellerName,
        'tellerId': tellerId,
        'notes': notes ?? '',
        'status': 'completed',
        'timestamp': timestamp,
        'receiptNumber': _generateReceiptNumber(timestamp),
      };

      // Update member balance based on account type
      final memberRef = _db.collection('saccoplus-members').doc(memberId);
      final memberDoc = await memberRef.get();
      
      print('💰 DEPOSIT: Updating member $memberId ($memberName)');
      print('💰   - Account type: $accountType');
      print('💰   - Deposit amount: $amount');
      
      if (!memberDoc.exists) {
        throw Exception('Member not found');
      }

      final memberData = memberDoc.data()!;
      Map<String, dynamic> updateData = {};

      switch (accountType) {
        case 'wallet':
          final currentBalance = (memberData['walletBalance'] as num?)?.toInt() ?? 0;
          final newBalance = currentBalance + amount;
          updateData['walletBalance'] = newBalance;
          
          print('💰   - Current wallet balance: $currentBalance');
          print('💰   - New wallet balance: $newBalance');
          
          // Also create wallet transaction
          await _db.collection(AppConstants.walletTxnCol).add({
            'tenantId': _tenantId,
            'farmerId': memberId,
            'type': 'deposit',
            'amount': amount,
            'timestamp': timestamp,
            'description': 'Teller deposit by $tellerName',
            'tellerProcessed': true,
            'tellerId': tellerId,
            'tellerName': tellerName,
          });
          break;

        case 'savings':
          final currentBalance = (memberData['savingsBalance'] as num?)?.toInt() ?? 0;
          updateData['savingsBalance'] = currentBalance + amount;
          
          // Create savings transaction
          await _db.collection(AppConstants.savingsCol).add({
            'tenantId': _tenantId,
            'farmerId': memberId,
            'farmerName': memberName,
            'type': 'deposit',
            'amount': amount,
            'status': 'approved',
            'timestamp': timestamp,
            'approvedBy': tellerName,
            'tellerProcessed': true,
            'tellerId': tellerId,
          });
          break;

        case 'shares':
          final currentValue = (memberData['sharesValue'] as num?)?.toInt() ?? 0;
          final sharePrice = SaccoService.current.shareValue;
          final sharesPurchased = (amount / sharePrice).floor();
          final actualAmount = sharesPurchased * sharePrice;
          
          updateData['sharesValue'] = currentValue + actualAmount;
          updateData['sharesCount'] = (memberData['sharesCount'] as num?)?.toInt() ?? 0 + sharesPurchased;
          
          // Create shares transaction
          await _db.collection(AppConstants.sharesCol).add({
            'tenantId': _tenantId,
            'farmerId': memberId,
            'farmerName': memberName,
            'type': 'purchase',
            'amount': actualAmount,
            'shareCount': sharesPurchased,
            'sharePrice': sharePrice,
            'status': 'approved',
            'timestamp': timestamp,
            'approvedBy': tellerName,
            'tellerProcessed': true,
            'tellerId': tellerId,
          });
          
          transaction['sharesCount'] = sharesPurchased;
          transaction['sharePrice'] = sharePrice;
          break;
      }

      // Update member record
      await memberRef.update(updateData);
      
      print('💰 DEPOSIT: Member balance updated in Firebase!');
      print('💰   - Updated fields: ${updateData.keys.join(", ")}');
      print('💰   - New values: $updateData');

      // Save transaction
      await transactionRef.set(transaction);

      // Send in-app notification to member
      await FirebaseService.sendNotification(
        memberId,
        '💰 Deposit Successful',
        'Your $accountType account has been credited with UGX ${_formatAmount(amount)}. '
        'New balance: UGX ${_formatAmount(updateData.values.first as int)}. '
        'Receipt: ${transaction['receiptNumber']}',
        type: 'deposit',
      );

      // Send SMS notification
      final smsMessage = 
          'Dear $memberName, your $accountType account has been credited with '
          'UGX ${_formatAmount(amount)}. '
          'New balance: UGX ${_formatAmount(updateData.values.first as int)}. '
          'Receipt: ${transaction['receiptNumber']}. '
          'Thank you.';
      
      await FirebaseService.sendSmsToPhone(memberPhone, smsMessage);

      // Audit trail
      await AuditService.log(
        action: 'TELLER_DEPOSIT',
        details: 'Teller $tellerName processed deposit of UGX $amount to $memberName ($accountType)',
        userId: tellerId,
        affectedUserId: memberId,
        metadata: {
          'amount': amount,
          'accountType': accountType,
          'transactionId': transactionId,
        },
      );

      return {
        'success': true,
        'transaction': transaction,
        'message': 'Deposit processed successfully. SMS sent to member.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to process deposit: ${e.toString()}',
      };
    }
  }

  // ─── Process Withdrawal ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> processWithdrawal({
    required String memberId,
    required String memberName,
    required String memberPhone,
    required int amount,
    required String accountType, // 'wallet', 'savings'
    required String tellerName,
    required String tellerId,
    String? notes,
  }) async {
    try {
      final transactionRef = _db.collection(AppConstants.tellerTxnCol).doc();
      final transactionId = transactionRef.id;
      final timestamp = DateTime.now();

      // Check member balance
      final memberRef = _db.collection('saccoplus-members').doc(memberId);
      final memberDoc = await memberRef.get();
      
      if (!memberDoc.exists) {
        throw Exception('Member not found');
      }

      final memberData = memberDoc.data()!;
      Map<String, dynamic> updateData = {};
      int currentBalance = 0;

      switch (accountType) {
        case 'wallet':
          currentBalance = (memberData['walletBalance'] as num?)?.toInt() ?? 0;
          if (currentBalance < amount) {
            throw Exception('Insufficient wallet balance');
          }
          updateData['walletBalance'] = currentBalance - amount;
          
          // Create wallet transaction
          await _db.collection(AppConstants.walletTxnCol).add({
            'tenantId': _tenantId,
            'farmerId': memberId,
            'type': 'withdrawal',
            'amount': amount,
            'timestamp': timestamp,
            'description': 'Teller withdrawal by $tellerName',
            'tellerProcessed': true,
            'tellerId': tellerId,
            'tellerName': tellerName,
          });
          break;

        case 'savings':
          currentBalance = (memberData['savingsBalance'] as num?)?.toInt() ?? 0;
          if (currentBalance < amount) {
            throw Exception('Insufficient savings balance');
          }
          updateData['savingsBalance'] = currentBalance - amount;
          
          // Create savings transaction
          await _db.collection(AppConstants.savingsCol).add({
            'tenantId': _tenantId,
            'farmerId': memberId,
            'farmerName': memberName,
            'type': 'withdrawal',
            'amount': amount,
            'status': 'approved',
            'timestamp': timestamp,
            'approvedBy': tellerName,
            'tellerProcessed': true,
            'tellerId': tellerId,
          });
          break;

        default:
          throw Exception('Invalid account type for withdrawal');
      }

      // Create transaction record
      final transaction = {
        'id': transactionId,
        'tenantId': _tenantId,
        'type': 'withdrawal',
        'memberId': memberId,
        'memberName': memberName,
        'memberPhone': memberPhone,
        'amount': amount,
        'accountType': accountType,
        'tellerName': tellerName,
        'tellerId': tellerId,
        'notes': notes ?? '',
        'status': 'completed',
        'timestamp': timestamp,
        'receiptNumber': _generateReceiptNumber(timestamp),
        'balanceBefore': currentBalance,
        'balanceAfter': currentBalance - amount,
      };

      // Update member record
      await memberRef.update(updateData);

      // Save transaction
      await transactionRef.set(transaction);

      // Send in-app notification to member
      final newBalance = currentBalance - amount;
      await FirebaseService.sendNotification(
        memberId,
        '💸 Withdrawal Successful',
        'UGX ${_formatAmount(amount)} has been withdrawn from your $accountType account. '
        'New balance: UGX ${_formatAmount(newBalance)}. '
        'Receipt: ${transaction['receiptNumber']}',
        type: 'withdrawal',
      );

      // Send SMS notification
      final smsMessage = 
          'Dear $memberName, UGX ${_formatAmount(amount)} has been withdrawn from '
          'your $accountType account. '
          'New balance: UGX ${_formatAmount(newBalance)}. '
          'Receipt: ${transaction['receiptNumber']}. '
          'Thank you.';
      
      await FirebaseService.sendSmsToPhone(memberPhone, smsMessage);

      // Audit trail
      await AuditService.log(
        action: 'TELLER_WITHDRAWAL',
        details: 'Teller $tellerName processed withdrawal of UGX $amount from $memberName ($accountType)',
        userId: tellerId,
        affectedUserId: memberId,
        metadata: {
          'amount': amount,
          'accountType': accountType,
          'transactionId': transactionId,
        },
      );

      return {
        'success': true,
        'transaction': transaction,
        'message': 'Withdrawal processed successfully. SMS sent to member.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to process withdrawal: ${e.toString()}',
      };
    }
  }

  // ─── Get Member Details ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getMemberDetails(String memberId) async {
    try {
      final doc = await _db.collection('saccoplus-members').doc(memberId).get();
      
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'phone': data['phone'] ?? '',
        'email': data['email'] ?? '',
        'walletBalance': (data['walletBalance'] as num?)?.toInt() ?? 0,
        'savingsBalance': (data['savingsBalance'] as num?)?.toInt() ?? 0,
        'sharesValue': (data['sharesValue'] as num?)?.toInt() ?? 0,
        'sharesCount': (data['sharesCount'] as num?)?.toInt() ?? 0,
        'idStatus': data['idStatus'] ?? 'pending',
      };
    } catch (e) {
      return null;
    }
  }

  // ─── Search Members ───────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchMembers(String query) async {
    if (query.isEmpty) return [];

    try {
      final queryLower = query.toLowerCase();
      
      // Get all members for this tenant (no role filter - search all users)
      final allMembers = await _db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      final members = <Map<String, dynamic>>[];

      for (var doc in allMembers.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final phone = (data['phone'] ?? '').toString();
        
        // Filter in-memory by name or phone
        if (name.contains(queryLower) || phone.contains(query)) {
          members.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? '',
            'memberNumber': data['memberNumber'] ?? '',
            'walletBalance': (data['walletBalance'] as num?)?.toInt() ?? 0,
            'savingsBalance': (data['savingsBalance'] as num?)?.toInt() ?? 0,
            'sharesValue': (data['sharesValue'] as num?)?.toInt() ?? 0,
            'idStatus': data['idStatus'] ?? 'pending',
          });
        }
      }

      return members;
    } catch (e) {
      return [];
    }
  }

  // ─── Get Transaction History ──────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTransactionHistory({
    String? memberId,
    String? tellerId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      print('🔍 TellerService.getTransactionHistory: Querying ${AppConstants.tellerTxnCol}');
      print('🔍   - tenantId: $_tenantId');
      print('🔍   - memberId: $memberId');
      print('🔍   - tellerId: $tellerId');
      
      Query query = _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId);
          // Removed orderBy to avoid composite index requirement
          // .orderBy('timestamp', descending: true);

      if (memberId != null) {
        query = query.where('memberId', isEqualTo: memberId);
      }

      if (tellerId != null) {
        query = query.where('tellerId', isEqualTo: tellerId);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.limit(limit).get();
      
      print('🔍 TellerService.getTransactionHistory: Found ${snapshot.docs.length} documents');
      if (snapshot.docs.isNotEmpty) {
        print('🔍   First transaction: ${snapshot.docs.first.data()}');
      }

      final results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();
      
      // Sort in memory since we removed orderBy
      results.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
      
      return results;
    } catch (e) {
      print('🔍 TellerService.getTransactionHistory ERROR: $e');
      return [];
    }
  }

  // ─── Get Daily Summary ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDailySummary({
    String? tellerId, // Made optional
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

    try {
      Query query = _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay);
      
      // Only filter by teller if provided
      if (tellerId != null) {
        query = query.where('tellerId', isEqualTo: tellerId);
      }

      final snapshot = await query.get();

      print('🔍 TellerService.getDailySummary: Found ${snapshot.docs.length} transactions for date $targetDate');
      print('🔍   - startOfDay: $startOfDay');
      print('🔍   - endOfDay: $endOfDay');
      
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
      
      if (snapshot.docs.isNotEmpty) {
        final firstDoc = snapshot.docs.first.data() as Map<String, dynamic>;
        final txnTimestamp = (firstDoc['timestamp'] as Timestamp).toDate();
        print('🔍   - First transaction timestamp: $txnTimestamp');
      }

      int totalDeposits = 0;
      int totalWithdrawals = 0;
      int depositCount = 0;
      int withdrawalCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] as num?)?.toInt() ?? 0;
        
        if (data['type'] == 'deposit') {
          totalDeposits += amount;
          depositCount++;
        } else if (data['type'] == 'withdrawal') {
          totalWithdrawals += amount;
          withdrawalCount++;
        }
      }

      return {
        'date': targetDate,
        'totalTransactions': snapshot.docs.length,
        'deposits': {
          'count': depositCount,
          'amount': totalDeposits,
        },
        'withdrawals': {
          'count': withdrawalCount,
          'amount': totalWithdrawals,
        },
        'netCashFlow': totalDeposits - totalWithdrawals,
      };
    } catch (e) {
      print('');
      print('🔥🔥🔥 FIRESTORE INDEX ERROR 🔥🔥🔥');
      print('');
      print(e.toString());
      print('');
      print('👆 COPY THE URL ABOVE AND PASTE IN YOUR BROWSER 👆');
      print('👆 IT WILL AUTO-CREATE THE INDEX FOR YOU! 👆');
      print('');
      
      return {
        'date': targetDate,
        'totalTransactions': 0,
        'deposits': {'count': 0, 'amount': 0},
        'withdrawals': {'count': 0, 'amount': 0},
        'netCashFlow': 0,
      };
    }
  }

  // ─── Generate Receipt Number ──────────────────────────────────────────────
  static String _generateReceiptNumber(DateTime timestamp) {
    final dateStr = timestamp.toString().substring(0, 10).replaceAll('-', '');
    final timeStr = timestamp.millisecondsSinceEpoch.toString().substring(8);
    return 'RCT$dateStr$timeStr';
  }

  // ─── Format Amount with Commas ────────────────────────────────────────────
  static String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

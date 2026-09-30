import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
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
          final currentBalance = (memberData['sharesBalance'] as num?)?.toDouble() ?? 0.0;
          final sharePrice = SaccoService.current.shareValue;
          final sharesPurchased = (amount / sharePrice).floor();
          final actualAmount = sharesPurchased * sharePrice;
          
          updateData['sharesBalance'] = currentBalance + actualAmount;
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

        case 'fixed_deposit':
          final currentBalance = (memberData['fixedDepositBalance'] as num?)?.toInt() ?? 0;
          updateData['fixedDepositBalance'] = currentBalance + amount;
          
          // Create fixed deposit transaction
          await _db.collection('saccoplus-fixed-deposits').add({
            'tenantId': _tenantId,
            'memberId': memberId,
            'memberName': memberName,
            'amount': amount,
            'status': 'active',
            'depositDate': timestamp,
            'maturityDate': timestamp.add(const Duration(days: 365)), // 1 year term
            'interestRate': 10.0, // 10% annual interest
            'tellerProcessed': true,
            'tellerId': tellerId,
            'tellerName': tellerName,
          });
          break;

        case 'loan_payment':
          // Find active loan for this member
          final loansQuery = await _db.collection('saccoplus-loans')
              .where('farmerId', isEqualTo: memberId)
              .where('tenantId', isEqualTo: _tenantId)
              .where('status', whereIn: ['active', 'overdue', 'approved'])
              .get();
          
          if (loansQuery.docs.isEmpty) {
            throw Exception('No active loan found for this member');
          }
          
          // Use the first active loan (or most recent)
          final loanDoc = loansQuery.docs.first;
          final loanData = loanDoc.data();
          final loanId = loanDoc.id;
          
          final principalOutstanding = (loanData['principalOutstanding'] as num?)?.toDouble() ?? 0.0;
          final interestOutstanding = (loanData['interestOriginalBalance'] as num?)?.toDouble() ?? 0.0;
          
          // Apply payment: first to interest, then to principal
          double remainingPayment = amount.toDouble();
          double interestPayment = 0;
          double principalPayment = 0;
          
          if (interestOutstanding > 0) {
            interestPayment = remainingPayment > interestOutstanding ? interestOutstanding : remainingPayment;
            remainingPayment -= interestPayment;
          }
          
          if (remainingPayment > 0 && principalOutstanding > 0) {
            principalPayment = remainingPayment > principalOutstanding ? principalOutstanding : remainingPayment;
          }
          
          final newPrincipalOutstanding = principalOutstanding - principalPayment;
          final newInterestOutstanding = interestOutstanding - interestPayment;
          final newTotalOutstanding = newPrincipalOutstanding + newInterestOutstanding;
          
          // Update loan
          await _db.collection('saccoplus-loans').doc(loanId).update({
            'principalOutstanding': newPrincipalOutstanding,
            'interestOriginalBalance': newInterestOutstanding,
            'totalOutstanding': newTotalOutstanding,
            'status': newTotalOutstanding <= 0 ? 'paid' : loanData['status'],
            'lastPaymentDate': timestamp,
            'lastPaymentAmount': amount,
          });
          
          // Create loan repayment record
          await _db.collection('saccoplus-loan-repayments').add({
            'tenantId': _tenantId,
            'loanId': loanId,
            'memberId': memberId,
            'memberName': memberName,
            'amount': amount,
            'principalPayment': principalPayment,
            'interestPayment': interestPayment,
            'timestamp': timestamp,
            'tellerProcessed': true,
            'tellerId': tellerId,
            'tellerName': tellerName,
            'loanReference': loanData['referenceNumber'] ?? '',
          });
          
          transaction['loanId'] = loanId;
          transaction['loanReference'] = loanData['referenceNumber'] ?? '';
          transaction['principalPayment'] = principalPayment;
          transaction['interestPayment'] = interestPayment;
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
        userId: FirebaseService.currentUser!.uid,
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
        userId: FirebaseService.currentUser!.uid,
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
    String? tellerId,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

    try {
      // Simplified query - just get all transactions for the day for this tenant
      // Filter the rest in memory to avoid complex index requirements
      final snapshot = await _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId)
          .get();

      print('🔍 TellerService.getDailySummary: Found ${snapshot.docs.length} total transactions');
      
      // Filter by date and teller in memory
      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        if (timestamp == null) return false;
        
        // Check if transaction is within the target day
        final isInDateRange = timestamp.isAfter(startOfDay) && timestamp.isBefore(endOfDay);
        if (!isInDateRange) return false;
        
        // If tellerId is provided, filter by it
        if (tellerId != null && data['tellerId'] != tellerId) return false;
        
        return true;
      }).toList();

      print('🔍   - Filtered to ${filteredDocs.length} transactions for date $targetDate');

      int totalDeposits = 0;
      int totalWithdrawals = 0;
      int depositCount = 0;
      int withdrawalCount = 0;

      for (var doc in filteredDocs) {
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
        'totalTransactions': filteredDocs.length,
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
      print('❌ TELLER SUMMARY ERROR: $e');
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

  // ─── Bank Transfer Methods ────────────────────────────────────────────────
  
  /// Get list of available banks from MarzPay
  static Future<Map<String, dynamic>> getBankList() async {
    try {
      final url = '${AppConstants.renderProxyUrl}/bank-transfer/banks';
      print('🏦 GET $url');
      
      // Retry up to 3 times (Render free tier may be sleeping)
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'X-Proxy-Key': AppConstants.marzPayProxyKey,
            },
          ).timeout(const Duration(seconds: 30));
          
          print('🏦 Response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print('🏦 Success! Banks loaded');
            return data;
          } else {
            print('🏦 HTTP ${response.statusCode}: ${response.body}');
            if (attempt < 3) {
              print('🏦 Retrying... (attempt $attempt/3)');
              await Future.delayed(Duration(seconds: attempt * 2));
              continue;
            }
            return {
              'status': 'error',
              'message': 'HTTP ${response.statusCode}: ${response.body}',
            };
          }
        } on TimeoutException {
          print('🏦 Timeout on attempt $attempt/3');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          return {
            'status': 'error',
            'message': 'Connection timeout. Proxy server may be starting up. Please try again in 30 seconds.',
          };
        }
      }
      
      return {'status': 'error', 'message': 'Failed after 3 attempts'};
    } catch (e) {
      print('❌ Error getting bank list: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Verify bank account using MarzPay
  static Future<Map<String, dynamic>> verifyBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final url = '${AppConstants.renderProxyUrl}/bank-transfer/validate';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Key': AppConstants.marzPayProxyKey,
        },
        body: jsonEncode({
          'bank_code': bankCode,
          'account_number': accountNumber,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error verifying bank account: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Process bank transfer from SACCOPLUS to member's bank account
  static Future<Map<String, dynamic>> processBankTransfer({
    required int amount,
    required String bankCode,
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String narration,
  }) async {
    try {
      final reference = 'BT-${DateTime.now().millisecondsSinceEpoch}';
      final timestamp = DateTime.now();
      final tellerId = FirebaseService.sessionUid;
      final tellerName = 'Teller';

      // Call MarzPay to process the transfer
      final url = '${AppConstants.renderProxyUrl}/bank-transfer';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Key': AppConstants.marzPayProxyKey,
        },
        body: jsonEncode({
          'amount': amount,
          'bank_code': bankCode,
          'account_number': accountNumber,
          'reference': reference,
          'description': narration,
        }),
      );
      
      final responseData = jsonDecode(response.body);

      // Log the transaction in Firestore regardless of MarzPay status
      final transactionRef = _db.collection(AppConstants.tellerTxnCol).doc();
      final transactionId = transactionRef.id;

      final transaction = {
        'id': transactionId,
        'tenantId': _tenantId,
        'type': 'bank_transfer',
        'amount': amount,
        'bankCode': bankCode,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'reference': reference,
        'narration': narration,
        'tellerName': tellerName,
        'tellerId': tellerId,
        'status': responseData['status'] == 'success' ? 'completed' : 'failed',
        'marzpayResponse': responseData,
        'timestamp': timestamp,
        'receiptNumber': _generateReceiptNumber(timestamp),
      };

      await transactionRef.set(transaction);

      // Audit log
      await AuditService.log(
        action: 'BANK_TRANSFER',
        details: 'Bank transfer of $amount to $accountName ($accountNumber) at $bankName',
        userId: tellerId,
        metadata: {
          'amount': amount,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'reference': reference,
          'status': transaction['status'],
        },
      );

      if (responseData['status'] == 'success') {
        return {
          'success': true,
          'reference': reference,
          'transactionId': transactionId,
          'message': 'Transfer successful',
        };
      } else {
        throw Exception(responseData['message'] ?? 'Transfer failed');
      }
    } catch (e) {
      print('❌ Error processing bank transfer: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get bank transfer history
  static Future<List<Map<String, dynamic>>> getBankTransferHistory({
    int limit = 50,
  }) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('type', isEqualTo: 'bank_transfer')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error getting bank transfer history: $e');
      return [];
    }
  }

  /// Check bank transfer status from MarzPay
  static Future<Map<String, dynamic>> checkBankTransferStatus(String reference) async {
    try {
      final url = '${AppConstants.renderProxyUrl}/bank-transfer/$reference';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Proxy-Key': AppConstants.marzPayProxyKey,
        },
      );
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error checking bank transfer status: $e');
      return {'status': 'error', 'message': e.toString()};
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

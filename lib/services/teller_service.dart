import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/firebase_service.dart';
import '../core/sacco_service.dart';
import '../core/constants.dart';
import '../models/till_session.dart';
import '../models/till_entry.dart';
import 'audit_service.dart';
import 'arrears_service.dart';
import 'till_service.dart';

/// Teller service for handling deposits and withdrawals
class TellerService {
  static final _db = FirebaseFirestore.instance;

  // Use FirebaseService.sessionTenantId instead of SaccoService to ensure consistency
  static String get _tenantId => FirebaseService.sessionTenantId;

  // ─── Safe runner for non-critical steps ───────────────────────────────────
  /// Runs a non-critical step (notification, SMS, audit, arrears refresh)
  /// without letting a failure there turn an already-recorded transaction
  /// into a "failed" one.
  static Future<void> _safe(Future<dynamic> Function() job, String label) async {
    try {
      await job();
    } catch (e, st) {
      print('⚠️ Non-critical step failed ($label): $e');
      print(st);
    }
  }

  // ─── Process Deposit ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> processDeposit({
    required String memberId,
    required String memberName,
    required String memberPhone,
    required int amount,
    required String accountType, // 'wallet', 'savings', 'shares'
    required String tellerName,
    required String tellerId,
    TillSession? tillSession, // Optional for now (will be required in Phase 3)
    String? notes,
    String? paymentMethod,
    String? telecomProvider,
    String? phoneNumber,
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
        'source': 'teller', // Mark as teller transaction
        'paymentMethod': paymentMethod ?? 'Cash',
        if (telecomProvider != null) 'telecomProvider': telecomProvider,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
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

      // New balance shown to the member in the notification / SMS.
      // Stays null for loan payments (they send their own messages).
      int? newBalanceForMessage;

      switch (accountType) {
        case 'savings':
          final currentBalance = (memberData['savingsBalance'] as num?)?.toInt() ?? 0;
          final newBalance = currentBalance + amount;
          updateData['savingsBalance'] = newBalance;
          newBalanceForMessage = newBalance;

          print('💰   - Current savings balance: $currentBalance');
          print('💰   - New savings balance: $newBalance');

          // Create savings transaction (use savingsTxnCol and memberId for consistency)
          await _db.collection(AppConstants.savingsTxnCol).add({
            'tenantId': _tenantId,
            'memberId': memberId,
            'memberName': memberName,
            'type': 'deposit',
            'amount': amount,
            'status': 'Approved',
            'createdAt': timestamp,
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
          // FIX: parentheses added so the purchased shares are really added
          // to the existing count (before, `?? 0 + n` ignored n).
          updateData['sharesCount'] =
              ((memberData['sharesCount'] as num?)?.toInt() ?? 0) + sharesPurchased;
          newBalanceForMessage = (currentBalance + actualAmount).toInt();

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
          newBalanceForMessage = currentBalance + amount;

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
          // Find loan for this member (any status with outstanding balance)
          final loansQuery = await _db
              .collection('saccoplus-loans')
              .where('farmerId', isEqualTo: memberId)
              .where('tenantId', isEqualTo: _tenantId)
              .get();

          if (loansQuery.docs.isEmpty) {
            throw Exception('No loan found for this member');
          }

          // Filter to loans with outstanding balance
          final activeLoans = loansQuery.docs.where((doc) {
            final principalOut = (doc.data()['principalOutstanding'] as num?)?.toDouble() ?? 0.0;
            return principalOut > 0;
          }).toList();

          if (activeLoans.isEmpty) {
            throw Exception('No loans with outstanding balance found for this member');
          }

          // Use the first loan with outstanding balance
          final loanDoc = activeLoans.first;
          final loanData = loanDoc.data();
          final loanId = loanDoc.id;

          final principalOutstanding =
              (loanData['principalOutstanding'] as num?)?.toDouble() ?? 0.0;
          final interestOutstanding =
              (loanData['interestOriginalBalance'] as num?)?.toDouble() ?? 0.0;

          // Apply payment: first to interest, then to principal
          double remainingPayment = amount.toDouble();
          double interestPayment = 0;
          double principalPayment = 0;

          if (interestOutstanding > 0) {
            interestPayment = remainingPayment > interestOutstanding
                ? interestOutstanding
                : remainingPayment;
            remainingPayment -= interestPayment;
          }

          if (remainingPayment > 0 && principalOutstanding > 0) {
            principalPayment = remainingPayment > principalOutstanding
                ? principalOutstanding
                : remainingPayment;
          }

          final newPrincipalOutstanding = principalOutstanding - principalPayment;
          final newInterestOutstanding = interestOutstanding - interestPayment;
          final newTotalOutstanding = newPrincipalOutstanding + newInterestOutstanding;

          // Update loan
          await _db.collection('saccoplus-loans').doc(loanId).update({
            'principalOutstanding': newPrincipalOutstanding,
            'interestOriginalBalance': newInterestOutstanding,
            'totalOutstanding': newTotalOutstanding,
            'outstanding': newTotalOutstanding, // Also update 'outstanding' field for compatibility
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

          // Post till entry for loan repayment (if till session provided and payment is cash)
          if (tillSession != null && (paymentMethod ?? 'Cash') == 'Cash') {
            try {
              final tillEntryInput = TillEntryInput(
                entryType: 'loan_repayment',
                amount: amount,
                affectsCash: true,
                paymentMethod: paymentMethod ?? 'Cash',
                memberId: memberId,
                memberName: memberName,
                businessRecordId: transactionId,
                businessRecordType: 'loan_repayment',
                notes: 'Loan repayment - Loan: ${loanData['referenceNumber'] ?? loanId} '
                    'Principal: ${_formatAmount(principalPayment.toInt())}, '
                    'Interest: ${_formatAmount(interestPayment.toInt())} - '
                    'Receipt: ${transaction['receiptNumber']}',
              );

              await TillService.postEntry(
                tillSessionId: tillSession.id,
                tellerId: tellerId,
                tellerName: tellerName,
                input: tillEntryInput,
              );

              print('✅ Till entry posted for loan repayment $transactionId');
            } catch (tillError) {
              // Till entry failure is non-critical - transaction already recorded
              print('⚠️ Failed to post till entry for loan repayment: $tillError');
            }
          }

          // Send in-app notification for loan repayment (non-critical)
          await _safe(
            () => FirebaseService.sendNotification(
              memberId,
              'Loan Payment Received',
              'Payment of UGX ${_formatAmount(amount)} received. '
              'Principal: UGX ${_formatAmount(principalPayment.toInt())}, '
              'Interest: UGX ${_formatAmount(interestPayment.toInt())}. '
              'Outstanding: UGX ${_formatAmount(newTotalOutstanding.toInt())}. '
              'Receipt: ${transaction['receiptNumber']}',
              type: 'loan_payment',
            ),
            'loan notification',
          );

          // Send SMS notification for loan repayment (non-critical)
          final loanSmsMessage =
              'MBADIFA SACCO\n'
              'Dear $memberName, your loan payment of UGX ${_formatAmount(amount)} has been received. '
              'Principal: UGX ${_formatAmount(principalPayment.toInt())}, '
              'Interest: UGX ${_formatAmount(interestPayment.toInt())}. '
              'Outstanding balance: UGX ${_formatAmount(newTotalOutstanding.toInt())}. '
              'Receipt: ${transaction['receiptNumber']}. '
              'Thank you.';

          await _safe(
            () => FirebaseService.sendSmsToPhone(memberPhone, loanSmsMessage),
            'loan sms',
          );

          // Update arrears and penalties after payment (non-critical)
          await _safe(() => ArrearsService.updateLoanArrears(loanId), 'arrears update');

          transaction['loanId'] = loanId;
          transaction['loanReference'] = loanData['referenceNumber'] ?? '';
          transaction['principalPayment'] = principalPayment;
          transaction['interestPayment'] = interestPayment;
          break;
      }

      // Update member record (only if there is something to update;
      // loan payments don't touch the member document)
      if (updateData.isNotEmpty) {
        await memberRef.update(updateData);
      }

      print('💰 DEPOSIT: Member balance updated in Firebase!');
      print('💰   - Updated fields: ${updateData.keys.join(", ")}');
      print('💰   - New values: $updateData');

      // Save transaction
      await transactionRef.set(transaction);

      // Post till entry if till session provided and payment is cash
      if (tillSession != null && (paymentMethod ?? 'Cash') == 'Cash') {
        try {
          final tillEntryInput = TillEntryInput.deposit(
            amount: amount,
            memberId: memberId,
            memberName: memberName,
            businessRecordId: transactionId,
            paymentMethod: paymentMethod ?? 'Cash',
            notes: 'Deposit to $accountType account - Receipt: ${transaction['receiptNumber']}',
          );

          await TillService.postEntry(
            tillSessionId: tillSession.id,
            tellerId: tellerId,
            tellerName: tellerName,
            input: tillEntryInput,
          );

          print('✅ Till entry posted for deposit $transactionId');
        } catch (tillError) {
          // Till entry failure is non-critical - transaction already recorded
          print('⚠️ Failed to post till entry for deposit: $tillError');
        }
      }

      // ── Everything below is NON-CRITICAL ─────────────────────────────────
      // The money has already been recorded, so a failure here must never
      // report the deposit as failed.
      if (newBalanceForMessage != null) {
        final balanceText = _formatAmount(newBalanceForMessage);

        // In-app notification
        await _safe(
          () => FirebaseService.sendNotification(
            memberId,
            'Deposit Successful',
            'Your $accountType account has been credited with UGX ${_formatAmount(amount)}. '
            'New balance: UGX $balanceText. '
            'Receipt: ${transaction['receiptNumber']}',
            type: 'deposit',
          ),
          'deposit notification',
        );

        // SMS notification
        final smsMessage =
            'MBADIFA SACCO\n'
            'Dear $memberName, your $accountType account has been credited with '
            'UGX ${_formatAmount(amount)}. '
            'New balance: UGX $balanceText. '
            'Receipt: ${transaction['receiptNumber']}. '
            'Thank you.';

        await _safe(
          () => FirebaseService.sendSmsToPhone(memberPhone, smsMessage),
          'deposit sms',
        );
      }

      // Audit trail
      // FIX: use sessionUid instead of FirebaseService.currentUser!.uid
      // (currentUser is null with the custom session login → "Unexpected null value")
      await _safe(
        () => AuditService.log(
          action: 'TELLER_DEPOSIT',
          details:
              'Teller $tellerName processed deposit of UGX $amount to $memberName ($accountType)',
          userId: FirebaseService.sessionUid,
          affectedUserId: memberId,
          metadata: {
            'amount': amount,
            'accountType': accountType,
            'transactionId': transactionId,
          },
        ),
        'deposit audit',
      );

      return {
        'success': true,
        'transaction': transaction,
        'message': 'Deposit processed successfully. SMS sent to member.',
      };
    } catch (e, st) {
      print('❌ processDeposit error: $e');
      print(st);
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
    TillSession? tillSession, // Optional for now (will be required in Phase 3)
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
        case 'savings':
          currentBalance = (memberData['savingsBalance'] as num?)?.toInt() ?? 0;
          if (currentBalance < amount) {
            throw Exception('Insufficient savings balance');
          }
          updateData['savingsBalance'] = currentBalance - amount;

          // Create savings transaction (use savingsTxnCol and memberId for consistency)
          await _db.collection(AppConstants.savingsTxnCol).add({
            'tenantId': _tenantId,
            'memberId': memberId,
            'memberName': memberName,
            'type': 'withdrawal',
            'amount': amount,
            'status': 'Approved',
            'createdAt': timestamp,
            'approvedBy': tellerName,
            'tellerProcessed': true,
            'tellerId': tellerId,
          });
          break;

        case 'shares':
          currentBalance = (memberData['sharesBalance'] as num?)?.toInt() ?? 0;
          if (currentBalance < amount) {
            throw Exception(
                'Insufficient shares balance. Available: UGX ${_formatAmount(currentBalance)}');
          }
          updateData['sharesBalance'] = currentBalance - amount;

          // Create shares transaction
          await _db.collection(AppConstants.sharesCol).add({
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
        'source': 'teller', // Mark as teller transaction
        'paymentMethod': 'Cash',
        'balanceBefore': currentBalance,
        'balanceAfter': currentBalance - amount,
      };

      // Update member record
      await memberRef.update(updateData);

      // Save transaction
      await transactionRef.set(transaction);

      // Post till entry if till session provided (cash withdrawal)
      if (tillSession != null) {
        try {
          final tillEntryInput = TillEntryInput.withdrawal(
            amount: amount,
            memberId: memberId,
            memberName: memberName,
            businessRecordId: transactionId,
            paymentMethod: 'Cash',
            notes: 'Withdrawal from $accountType account - Receipt: ${transaction['receiptNumber']}',
          );

          await TillService.postEntry(
            tillSessionId: tillSession.id,
            tellerId: tellerId,
            tellerName: tellerName,
            input: tillEntryInput,
          );

          print('✅ Till entry posted for withdrawal $transactionId');
        } catch (tillError) {
          // Till entry failure is non-critical - transaction already recorded
          print('⚠️ Failed to post till entry for withdrawal: $tillError');
        }
      }

      // ── Everything below is NON-CRITICAL ─────────────────────────────────
      final newBalance = currentBalance - amount;

      await _safe(
        () => FirebaseService.sendNotification(
          memberId,
          '💸 Withdrawal Successful',
          'UGX ${_formatAmount(amount)} has been withdrawn from your $accountType account. '
          'New balance: UGX ${_formatAmount(newBalance)}. '
          'Receipt: ${transaction['receiptNumber']}',
          type: 'withdrawal',
        ),
        'withdrawal notification',
      );

      final smsMessage =
          'MBADIFA SACCO\n'
          'Dear $memberName, UGX ${_formatAmount(amount)} has been withdrawn from '
          'your $accountType account. '
          'New balance: UGX ${_formatAmount(newBalance)}. '
          'Receipt: ${transaction['receiptNumber']}. '
          'Thank you.';

      await _safe(
        () => FirebaseService.sendSmsToPhone(memberPhone, smsMessage),
        'withdrawal sms',
      );

      // Audit trail (FIX: sessionUid instead of currentUser!.uid)
      await _safe(
        () => AuditService.log(
          action: 'TELLER_WITHDRAWAL',
          details:
              'Teller $tellerName processed withdrawal of UGX $amount from $memberName ($accountType)',
          userId: FirebaseService.sessionUid,
          affectedUserId: memberId,
          metadata: {
            'amount': amount,
            'accountType': accountType,
            'transactionId': transactionId,
          },
        ),
        'withdrawal audit',
      );

      return {
        'success': true,
        'transaction': transaction,
        'message': 'Withdrawal processed successfully. SMS sent to member.',
      };
    } catch (e, st) {
      print('❌ processWithdrawal error: $e');
      print(st);
      return {
        'success': false,
        'message': 'Failed to process withdrawal: ${e.toString()}',
      };
    }
  }

  // ─── Create Fixed Deposit ─────────────────────────────────────────────────────
  /// Create a new fixed deposit for a member
  static Future<Map<String, dynamic>> createFixedDeposit({
    required String memberId,
    required String memberName,
    required double amount,
    required int months,
  }) async {
    try {
      final timestamp = DateTime.now();
      final maturityDate = timestamp.add(Duration(days: months * 30));
      final receiptNumber = _generateReceiptNumber(timestamp);

      // Create fixed deposit record
      final docRef = await _db.collection(AppConstants.fixedDepositCol).add({
        'tenantId': _tenantId,
        'memberId': memberId,
        'memberName': memberName,
        'amount': amount,
        'interestRate': 10.0, // 10% per annum
        'months': months,
        'depositDate': Timestamp.fromDate(timestamp),
        'maturityDate': Timestamp.fromDate(maturityDate),
        'status': 'active',
        'receiptNumber': receiptNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _tenantId, // Use tenant ID as creator
      });

      // Deduct from member's savings
      final memberRef = _db.collection('saccoplus-members').doc(memberId);
      final memberSnap = await memberRef.get();
      
      if (memberSnap.exists) {
        final currentSavings = (memberSnap.data()?['savingsBalance'] ?? 0).toDouble();
        await memberRef.update({
          'savingsBalance': currentSavings - amount,
        });
      }

      // Record transaction
      await _db.collection('saccoplus-savings-transactions').add({
        'tenantId': _tenantId,
        'memberId': memberId,
        'memberName': memberName,
        'type': 'Withdrawal',
        'amount': amount,
        'method': 'Fixed Deposit',
        'description': 'Fixed deposit for $months months',
        'status': 'Approved',
        'receiptNumber': receiptNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Fixed deposit created successfully',
        'depositId': docRef.id,
        'receiptNumber': receiptNumber,
      };
    } catch (e) {
      print('❌ Error creating fixed deposit: $e');
      return {
        'success': false,
        'message': 'Failed to create fixed deposit: $e',
      };
    }
  }

  // ─── Mature Fixed Deposit ─────────────────────────────────────────────────
  /// Mature a fixed deposit and transfer principal + interest to savings
  static Future<Map<String, dynamic>> matureFixedDeposit({
    required String fixedDepositId,
    required String tellerId,
    required String tellerName,
  }) async {
    try {
      final timestamp = DateTime.now();

      // Get fixed deposit details
      final fdDoc =
          await _db.collection(AppConstants.fixedDepositCol).doc(fixedDepositId).get();

      if (!fdDoc.exists) {
        throw Exception('Fixed deposit not found');
      }

      final fdData = fdDoc.data()!;
      final memberId = fdData['memberId'] as String;
      final memberName = fdData['memberName'] as String? ?? 'Unknown';
      final principal = (fdData['amount'] as num?)?.toInt() ?? 0;
      final interestRate = (fdData['interestRate'] as num?)?.toDouble() ?? 10.0;
      final status = fdData['status'] as String? ?? 'active';

      if (status == 'Matured' || status == 'matured') {
        throw Exception('This fixed deposit has already been matured');
      }

      // Calculate interest earned
      final depositDate = (fdData['depositDate'] as Timestamp?)?.toDate() ?? timestamp;
      final daysElapsed = timestamp.difference(depositDate).inDays;
      final yearsElapsed = daysElapsed / 365.0;
      final interestEarned = (principal * (interestRate / 100) * yearsElapsed).round();
      final totalPayout = principal + interestEarned;

      print('💰 Maturing Fixed Deposit:');
      print('   - Principal: UGX ${_formatAmount(principal)}');
      print('   - Interest Rate: $interestRate%');
      print('   - Days Elapsed: $daysElapsed');
      print('   - Interest Earned: UGX ${_formatAmount(interestEarned)}');
      print('   - Total Payout: UGX ${_formatAmount(totalPayout)}');

      // Get member details
      final memberDoc = await _db.collection('saccoplus-members').doc(memberId).get();
      if (!memberDoc.exists) {
        throw Exception('Member not found');
      }

      final memberData = memberDoc.data()!;
      final memberPhone = memberData['phone'] as String? ?? '';
      final currentSavings = (memberData['savingsBalance'] as num?)?.toInt() ?? 0;
      final newSavings = currentSavings + totalPayout;

      // Update fixed deposit status to matured
      await _db.collection(AppConstants.fixedDepositCol).doc(fixedDepositId).update({
        'status': 'Matured',
        'maturedDate': timestamp,
        'maturedBy': tellerName,
        'interestEarned': interestEarned,
        'totalPayout': totalPayout,
        'maturedByTellerId': tellerId,
      });

      // Transfer to savings account
      await _db.collection('saccoplus-members').doc(memberId).update({
        'savingsBalance': newSavings,
      });

      // Create savings transaction for the payout
      await _db.collection(AppConstants.savingsTxnCol).add({
        'tenantId': _tenantId,
        'memberId': memberId,
        'memberName': memberName,
        'type': 'fixed_deposit_maturity',
        'amount': totalPayout,
        'principal': principal,
        'interestEarned': interestEarned,
        'status': 'Approved',
        'createdAt': timestamp,
        'approvedBy': tellerName,
        'tellerProcessed': true,
        'tellerId': tellerId,
        'fixedDepositId': fixedDepositId,
      });

      // Create teller transaction record
      final receiptNumber = _generateReceiptNumber(timestamp);

      await _db.collection(AppConstants.tellerTxnCol).add({
        'tenantId': _tenantId,
        'receiptNumber': receiptNumber,
        'type': 'fixed_deposit_maturity',
        'memberId': memberId,
        'memberName': memberName,
        'memberPhone': memberPhone,
        'accountType': 'fixed_deposit',
        'amount': totalPayout,
        'principal': principal,
        'interestEarned': interestEarned,
        'timestamp': timestamp,
        'tellerId': tellerId,
        'tellerName': tellerName,
        'fixedDepositId': fixedDepositId,
        'status': 'completed',
        'source': 'teller',
      });

      // ── Everything below is NON-CRITICAL ───────────────────────────────────
      await _safe(
        () => FirebaseService.sendNotification(
          memberId,
          '🎉 Fixed Deposit Matured',
          'Your fixed deposit of UGX ${_formatAmount(principal)} has matured! '
          'You earned UGX ${_formatAmount(interestEarned)} interest. '
          'Total UGX ${_formatAmount(totalPayout)} has been transferred to your savings account. '
          'New savings balance: UGX ${_formatAmount(newSavings)}.',
          type: 'fixed_deposit_maturity',
        ),
        'maturity notification',
      );

      final smsMessage =
          'MBADIFA SACCO\n'
          'Congratulations! Your fixed deposit of UGX ${_formatAmount(principal)} has matured. '
          'Interest earned: UGX ${_formatAmount(interestEarned)}. '
          'Total UGX ${_formatAmount(totalPayout)} transferred to savings. '
          'New balance: UGX ${_formatAmount(newSavings)}. '
          'Thank you!';

      await _safe(
        () => FirebaseService.sendSmsToPhone(memberPhone, smsMessage),
        'maturity sms',
      );

      // Audit trail (FIX: sessionUid instead of currentUser!.uid)
      await _safe(
        () => AuditService.log(
          action: 'FIXED_DEPOSIT_MATURED',
          details: 'Teller $tellerName matured fixed deposit for $memberName. '
              'Principal: UGX $principal, Interest: UGX $interestEarned, Total: UGX $totalPayout',
          userId: FirebaseService.sessionUid,
          affectedUserId: memberId,
          metadata: {
            'fixedDepositId': fixedDepositId,
            'principal': principal,
            'interestEarned': interestEarned,
            'totalPayout': totalPayout,
            'receiptNumber': receiptNumber,
          },
        ),
        'maturity audit',
      );

      return {
        'success': true,
        'principal': principal,
        'interestEarned': interestEarned,
        'totalPayout': totalPayout,
        'receiptNumber': receiptNumber,
        'message':
            'Fixed deposit matured successfully. Total UGX ${_formatAmount(totalPayout)} transferred to savings.',
      };
    } catch (e, st) {
      print('❌ matureFixedDeposit error: $e');
      print(st);
      return {
        'success': false,
        'message': 'Failed to mature fixed deposit: ${e.toString()}',
      };
    }
  }

  // ─── Get Member Fixed Deposits ────────────────────────────────────────────
  /// Get all fixed deposits for a member
  static Future<List<Map<String, dynamic>>> getMemberFixedDeposits(String memberId) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.fixedDepositCol)
          .where('memberId', isEqualTo: memberId)
          .where('tenantId', isEqualTo: _tenantId)
          .orderBy('depositDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting member fixed deposits: $e');
      return [];
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
    bool includeAllSources = true, // Include both teller and mobile app transactions
  }) async {
    try {
      print('🔍 TellerService.getTransactionHistory: Querying ${AppConstants.tellerTxnCol} AND ${AppConstants.tillEntriesCol}');
      print('🔍   - tenantId: $_tenantId');
      print('🔍   - memberId: $memberId');
      print('🔍   - tellerId: $tellerId');
      print('🔍   - includeAllSources: $includeAllSources');

      // Query 1: Get teller transactions (deposits, withdrawals, etc.)
      Query query1 = _db
          .collection(AppConstants.tellerTxnCol)
          .where('tenantId', isEqualTo: _tenantId);

      if (memberId != null) {
        query1 = query1.where('memberId', isEqualTo: memberId);
      }

      if (tellerId != null) {
        query1 = query1.where('tellerId', isEqualTo: tellerId);
      }

      if (!includeAllSources) {
        query1 = query1.where('source', isEqualTo: 'teller');
      }

      if (startDate != null) {
        query1 = query1.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query1 = query1.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      // Query 2: Get till entries (loan repayments, disbursements, etc.)
      Query query2 = _db
          .collection(AppConstants.tillEntriesCol)
          .where('tenantId', isEqualTo: _tenantId);

      if (memberId != null) {
        query2 = query2.where('memberId', isEqualTo: memberId);
      }

      if (tellerId != null) {
        query2 = query2.where('tellerId', isEqualTo: tellerId);
      }

      if (startDate != null) {
        query2 = query2.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query2 = query2.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      // Execute both queries
      final snapshot1 = await query1.limit(limit).get();
      final snapshot2 = await query2.limit(limit).get();

      print('🔍 TellerService.getTransactionHistory: Found ${snapshot1.docs.length} teller transactions + ${snapshot2.docs.length} till entries');

      final results = <Map<String, dynamic>>[];

      // Add teller transactions
      for (final doc in snapshot1.docs) {
        final data = doc.data() as Map<String, dynamic>;
        results.add({
          'id': doc.id,
          ...data,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0),
          'source': data['source'] ?? 'teller',
          'paymentMethod': data['paymentMethod'] ?? 'Cash',
        });
      }

      // Add till entries (convert to transaction format)
      for (final doc in snapshot2.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final entryType = data['entryType'] ?? '';
        
        // Map till entry types to transaction types
        String transactionType = entryType;
        if (entryType == 'loan_repayment') {
          transactionType = 'loan_payment';
        } else if (entryType == 'loan_disbursement') {
          transactionType = 'loan_disbursement';
        }

        results.add({
          'id': doc.id,
          ...data,
          'type': transactionType,
          'timestamp': (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0),
          'source': 'teller',
          'paymentMethod': data['affectsCash'] == true ? 'Cash' : 'Bank Transfer',
          'receiptNumber': data['notes'] ?? '', // Till entries don't have receipt numbers yet
        });
      }

      // Sort combined results by timestamp
      results.sort((a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

      // Apply limit to combined results
      return results.take(limit).toList();
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
    final endOfDay =
        DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

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
        final isInDateRange =
            timestamp.isAfter(startOfDay) && timestamp.isBefore(endOfDay);
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
            'message':
                'Connection timeout. Proxy server may be starting up. Please try again in 30 seconds.',
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

      // Audit log (non-critical)
      await _safe(
        () => AuditService.log(
          action: 'BANK_TRANSFER',
          details:
              'Bank transfer of $amount to $accountName ($accountNumber) at $bankName',
          userId: tellerId,
          metadata: {
            'amount': amount,
            'bankName': bankName,
            'accountNumber': accountNumber,
            'accountName': accountName,
            'reference': reference,
            'status': transaction['status'],
          },
        ),
        'bank transfer audit',
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

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
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

  // ─── Verify Mobile Money Account ──────────────────────────────────────────
  /// Verifies a mobile money account and returns the account holder's name
  static Future<Map<String, dynamic>> verifyMobileMoneyAccount({
    required String phoneNumber,
    required String provider,
  }) async {
    try {
      print('🔍 Verifying mobile money account: $phoneNumber ($provider)');

      // Use FirebaseService's verifyPhoneNumber which properly handles the proxy
      final result =
          await FirebaseService.verifyPhoneNumber(phoneNumber, countryCode: 'UG');

      print('📥 Verification result: ${result['verified']}');

      if (result['verified'] == true) {
        return {
          'success': true,
          'accountName':
              result['full_name'] ?? result['first_name'] ?? 'Account Verified',
          'full_name': result['full_name'] ??
              '${result['first_name']} ${result['last_name']}'.trim(),
          'phoneNumber': phoneNumber,
          'provider': provider,
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Account verification failed',
          'canSkip': true,
        };
      }
    } catch (e) {
      print('❌ Error verifying mobile money account: $e');
      return {
        'success': false,
        'message': 'Verification unavailable — you can still proceed',
        'canSkip': true,
      };
    }
  }

  // ─── Request Mobile Money Payment ─────────────────────────────────────────
  /// Sends a payment request to the customer's mobile money account
  /// Customer will receive a prompt to enter their PIN to approve the payment
  static Future<Map<String, dynamic>> requestMobileMoneyPayment({
    required String phoneNumber,
    required double amount,
    required String provider,
    required String narration,
  }) async {
    try {
      print('💳 Requesting mobile money payment:');
      print('   - Phone: $phoneNumber');
      print('   - Amount: UGX ${amount.round()}');
      print('   - Provider: $provider');
      print('   - Narration: $narration');

      // Use FirebaseService's wallet deposit which properly handles mobile money collections
      final result = await FirebaseService.walletDeposit(
        uid: FirebaseService.sessionUid,
        amount: amount.round(),
        phoneNumber: phoneNumber,
        countryCode: 'UG',
        currencyCode: 'UGX',
      );

      print('Payment response: ${result['success']}');

      if (result['success'] == true || result['uuid'] != null) {
        return {
          'success': true,
          'message': 'Payment request sent successfully',
          'transaction_id': result['txnId'] ?? result['uuid'],
          'transactionId': result['txnId'] ?? result['uuid'],
          'reference': result['uuid'],
          'status': 'pending',
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Payment request failed',
        };
      }
    } catch (e) {
      print('Error requesting mobile money payment: $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAL LEDGER ENTRIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Record a journal entry (no till impact, accounting only)
  static Future<void> recordJournalEntry({
    required String description,
    required int amount,
    String? notes,
    required String tellerName,
    required String tellerId,
  }) async {
    try {
      final transactionRef = _db.collection(AppConstants.tellerTxnCol).doc();
      final transactionId = transactionRef.id;
      final timestamp = DateTime.now();

      final transaction = {
        'id': transactionId,
        'tenantId': _tenantId,
        'type': 'journal_entry',
        'description': description,
        'amount': amount,
        'notes': notes ?? '',
        'tellerName': tellerName,
        'tellerId': tellerId,
        'status': 'completed',
        'timestamp': timestamp,
        'receiptNumber': _generateReceiptNumber(timestamp),
        'source': 'teller',
      };

      await transactionRef.set(transaction);

      // Audit log
      await _safe(
        () => AuditService.log(
          action: 'JOURNAL_ENTRY',
          details: 'Journal entry: $description - ${_formatAmount(amount)}',
          userId: tellerId,
          metadata: {
            'description': description,
            'amount': amount,
            'notes': notes ?? '',
          },
        ),
        'journal entry audit',
      );

      print('Journal entry recorded: $description - ${_formatAmount(amount)}');
    } catch (e, st) {
      print('Error recording journal entry: $e');
      print(st);
      rethrow;
    }
  }

  /// Record an expense payment (reduces till cash)
  static Future<void> recordExpensePayment({
    required String description,
    String? category,
    required int amount,
    String? notes,
    required String tellerName,
    required String tellerId,
    required TillSession tillSession,
  }) async {
    try {
      final transactionRef = _db.collection(AppConstants.tellerTxnCol).doc();
      final transactionId = transactionRef.id;
      final timestamp = DateTime.now();

      final transaction = {
        'id': transactionId,
        'tenantId': _tenantId,
        'type': 'expense',
        'description': description,
        'category': category ?? 'General',
        'amount': amount,
        'notes': notes ?? '',
        'tellerName': tellerName,
        'tellerId': tellerId,
        'status': 'completed',
        'timestamp': timestamp,
        'receiptNumber': _generateReceiptNumber(timestamp),
        'source': 'teller',
      };

      await transactionRef.set(transaction);

      // Post to till (cash out)
      await TillService.postEntry(
        tillSessionId: tillSession.id,
        tellerId: tellerId,
        tellerName: tellerName,
        input: TillEntryInput(
          entryType: 'expense',
          amount: -amount, // Negative = cash out
          affectsCash: true,
          paymentMethod: 'Cash',
          notes: 'Expense: $description${category != null ? ' ($category)' : ''}',
        ),
      );

      // Audit log
      await _safe(
        () => AuditService.log(
          action: 'EXPENSE_PAYMENT',
          details: 'Expense payment: $description - ${_formatAmount(amount)}',
          userId: tellerId,
          metadata: {
            'description': description,
            'category': category ?? 'General',
            'amount': amount,
            'notes': notes ?? '',
          },
        ),
        'expense payment audit',
      );

      print('Expense payment recorded: $description - ${_formatAmount(amount)}');
    } catch (e, st) {
      print('Error recording expense payment: $e');
      print(st);
      rethrow;
    }
  }

  /// Record a revenue entry (increases till cash)
  static Future<void> recordRevenueEntry({
    required String description,
    String? source,
    required int amount,
    String? notes,
    required String tellerName,
    required String tellerId,
    required TillSession tillSession,
  }) async {
    try {
      final transactionRef = _db.collection(AppConstants.tellerTxnCol).doc();
      final transactionId = transactionRef.id;
      final timestamp = DateTime.now();

      final transaction = {
        'id': transactionId,
        'tenantId': _tenantId,
        'type': 'revenue',
        'description': description,
        'source': source ?? 'Other Income',
        'amount': amount,
        'notes': notes ?? '',
        'tellerName': tellerName,
        'tellerId': tellerId,
        'status': 'completed',
        'timestamp': timestamp,
        'receiptNumber': _generateReceiptNumber(timestamp),
      };

      await transactionRef.set(transaction);

      // Post to till (cash in)
      await TillService.postEntry(
        tillSessionId: tillSession.id,
        tellerId: tellerId,
        tellerName: tellerName,
        input: TillEntryInput(
          entryType: 'revenue',
          amount: amount, // Positive = cash in
          affectsCash: true,
          paymentMethod: 'Cash',
          notes: 'Revenue: $description${source != null ? ' ($source)' : ''}',
        ),
      );

      // Audit log
      await _safe(
        () => AuditService.log(
          action: 'REVENUE_ENTRY',
          details: 'Revenue entry: $description - ${_formatAmount(amount)}',
          userId: tellerId,
          metadata: {
            'description': description,
            'source': source ?? 'Other Income',
            'amount': amount,
            'notes': notes ?? '',
          },
        ),
        'revenue entry audit',
      );

      print('Revenue entry recorded: $description - ${_formatAmount(amount)}');
    } catch (e, st) {
      print('Error recording revenue entry: $e');
      print(st);
      rethrow;
    }
  }
}

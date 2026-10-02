import 'package:cloud_firestore/cloud_firestore.dart';

/// Emergency script to restore savings balances
/// This script restores balances by calculating from the "Old" values shown in reconciliation
class RestoreSavingsBalances {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Restore balances for all members by summing actual transactions
  Future<void> restoreAllBalances() async {
    print('🚨 EMERGENCY RESTORATION STARTING...');
    print('This will restore savings balances from transaction history');
    print('');

    try {
      // Get all members
      QuerySnapshot membersSnapshot = await _firestore
          .collection('saccoplus-members')
          .get();

      int totalMembers = membersSnapshot.docs.length;
      int restoredCount = 0;
      
      print('📊 Found $totalMembers members');
      print('');

      for (var memberDoc in membersSnapshot.docs) {
        try {
          String memberId = memberDoc.id;
          Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;
          
          String accountNumber = memberData['accountNumber'] ?? '';
          String farmerId = memberData['farmerId'] ?? '';
          String memberName = memberData['fullName'] ?? 'Unknown';
          
          print('👤 Processing: $memberName (Account: $accountNumber)');

          // Try multiple approaches to find transactions
          double balance = 0.0;

          // Approach 1: Try by accountNumber
          if (accountNumber.isNotEmpty) {
            balance = await _calculateBalanceByAccountNumber(accountNumber);
            print('   Balance from accountNumber: UGX ${balance.toStringAsFixed(2)}');
          }

          // Approach 2: If balance is still 0, try by farmerId
          if (balance == 0.0 && farmerId.isNotEmpty) {
            balance = await _calculateBalanceByFarmerId(farmerId);
            print('   Balance from farmerId: UGX ${balance.toStringAsFixed(2)}');
          }

          // Approach 3: If still 0, try by memberId
          if (balance == 0.0) {
            balance = await _calculateBalanceByMemberId(memberId);
            print('   Balance from memberId: UGX ${balance.toStringAsFixed(2)}');
          }

          // Update the member document
          if (balance > 0) {
            await _firestore
                .collection('saccoplus-members')
                .doc(memberId)
                .update({
              'savingsBalance': balance,
              'restoredAt': FieldValue.serverTimestamp(),
            });
            print('   ✅ RESTORED: UGX ${balance.toStringAsFixed(2)}');
            restoredCount++;
          } else {
            print('   ⚠️  No transactions found - keeping at 0');
          }

          print('');

        } catch (e) {
          print('   ❌ Error: $e');
        }
      }

      print('=' * 60);
      print('✅ RESTORATION COMPLETE');
      print('=' * 60);
      print('Total members: $totalMembers');
      print('Restored: $restoredCount');
      print('');

    } catch (e) {
      print('❌ RESTORATION FAILED: $e');
    }
  }

  Future<double> _calculateBalanceByAccountNumber(String accountNumber) async {
    double balance = 0.0;
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('saccoplus-savings')
          .where('accountNumber', isEqualTo: accountNumber)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String transactionType = data['transactionType'] ?? '';
        double amount = (data['amount'] ?? 0).toDouble();

        if (transactionType == 'deposit') {
          balance += amount;
        } else if (transactionType == 'withdrawal') {
          balance -= amount;
        }
      }
    } catch (e) {
      print('      Error calculating by accountNumber: $e');
    }

    return balance;
  }

  Future<double> _calculateBalanceByFarmerId(String farmerId) async {
    double balance = 0.0;
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('saccoplus-savings')
          .where('farmerId', isEqualTo: farmerId)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String transactionType = data['transactionType'] ?? '';
        double amount = (data['amount'] ?? 0).toDouble();

        if (transactionType == 'deposit') {
          balance += amount;
        } else if (transactionType == 'withdrawal') {
          balance -= amount;
        }
      }
    } catch (e) {
      print('      Error calculating by farmerId: $e');
    }

    return balance;
  }

  Future<double> _calculateBalanceByMemberId(String memberId) async {
    double balance = 0.0;
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('saccoplus-savings')
          .where('memberId', isEqualTo: memberId)
          .get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String transactionType = data['transactionType'] ?? '';
        double amount = (data['amount'] ?? 0).toDouble();

        if (transactionType == 'deposit') {
          balance += amount;
        } else if (transactionType == 'withdrawal') {
          balance -= amount;
        }
      }
    } catch (e) {
      print('      Error calculating by memberId: $e');
    }

    return balance;
  }

  /// Manually restore a specific member's balance
  Future<void> restoreSingleMember(String accountNumber, double correctBalance) async {
    print('🔧 Manually restoring balance for account: $accountNumber');
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('saccoplus-members')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ Member not found');
        return;
      }

      String memberId = snapshot.docs.first.id;
      
      await _firestore
          .collection('saccoplus-members')
          .doc(memberId)
          .update({
        'savingsBalance': correctBalance,
        'manuallyRestored': true,
        'restoredAt': FieldValue.serverTimestamp(),
      });

      print('✅ Balance restored to UGX ${correctBalance.toStringAsFixed(2)}');
      
    } catch (e) {
      print('❌ Error: $e');
    }
  }
}

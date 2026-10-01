import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Reconciliation script to fix inflated savings balances in member documents
/// This script calculates the correct savings balance from transaction history
/// and updates the member document's savingsBalance field
class SavingsReconciliationScript {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Run the reconciliation for all members
  Future<Map<String, dynamic>> reconcileAllMembers() async {
    print('🔄 Starting savings reconciliation...');
    
    int totalMembers = 0;
    int updatedMembers = 0;
    int errorMembers = 0;
    List<Map<String, dynamic>> discrepancies = [];

    try {
      // Get all members
      QuerySnapshot membersSnapshot = await _firestore
          .collection('saccoplus-members')
          .get();

      totalMembers = membersSnapshot.docs.length;
      print('📊 Found $totalMembers members to reconcile');

      for (var memberDoc in membersSnapshot.docs) {
        try {
          String memberId = memberDoc.id;
          Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;
          
          String accountNumber = memberData['accountNumber'] ?? '';
          String memberName = memberData['fullName'] ?? 'Unknown';
          double currentBalance = (memberData['savingsBalance'] ?? 0).toDouble();

          print('\n👤 Processing: $memberName (Account: $accountNumber)');
          print('   Current balance in document: UGX ${currentBalance.toStringAsFixed(2)}');

          // Calculate actual balance from transactions
          double actualBalance = await _calculateActualSavingsBalance(accountNumber);
          print('   Actual balance from transactions: UGX ${actualBalance.toStringAsFixed(2)}');

          // Check for discrepancy
          double difference = (currentBalance - actualBalance).abs();
          if (difference > 1.0) { // Allow 1 UGX tolerance for rounding
            print('   ⚠️  DISCREPANCY FOUND: ${currentBalance - actualBalance}');
            
            discrepancies.add({
              'memberId': memberId,
              'accountNumber': accountNumber,
              'memberName': memberName,
              'oldBalance': currentBalance,
              'newBalance': actualBalance,
              'difference': currentBalance - actualBalance,
            });

            // Update the member document
            await _firestore
                .collection('saccoplus-members')
                .doc(memberId)
                .update({
              'savingsBalance': actualBalance,
              'lastReconciled': FieldValue.serverTimestamp(),
            });

            print('   ✅ Updated to correct balance: UGX ${actualBalance.toStringAsFixed(2)}');
            updatedMembers++;
          } else {
            print('   ✓ Balance is correct');
          }

        } catch (e) {
          print('   ❌ Error processing member: $e');
          errorMembers++;
        }
      }

      print('\n' + '=' * 60);
      print('📋 RECONCILIATION COMPLETE');
      print('=' * 60);
      print('Total members processed: $totalMembers');
      print('Members updated: $updatedMembers');
      print('Errors: $errorMembers');
      print('');

      if (discrepancies.isNotEmpty) {
        print('📊 DISCREPANCIES FOUND ($updatedMembers):');
        print('-' * 60);
        for (var disc in discrepancies) {
          print('${disc['memberName']} (${disc['accountNumber']})');
          print('  Old: UGX ${disc['oldBalance'].toStringAsFixed(2)}');
          print('  New: UGX ${disc['newBalance'].toStringAsFixed(2)}');
          print('  Diff: UGX ${disc['difference'].toStringAsFixed(2)}');
          print('');
        }
      }

      return {
        'success': true,
        'totalMembers': totalMembers,
        'updatedMembers': updatedMembers,
        'errorMembers': errorMembers,
        'discrepancies': discrepancies,
      };

    } catch (e) {
      print('❌ RECONCILIATION FAILED: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Calculate actual savings balance from transaction history
  Future<double> _calculateActualSavingsBalance(String accountNumber) async {
    if (accountNumber.isEmpty) return 0.0;

    double balance = 0.0;

    try {
      // Get all savings transactions for this account
      QuerySnapshot transactionsSnapshot = await _firestore
          .collection('saccoplus-savings')
          .where('accountNumber', isEqualTo: accountNumber)
          .orderBy('timestamp', descending: false)
          .get();

      for (var doc in transactionsSnapshot.docs) {
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
      print('   ⚠️  Error calculating balance: $e');
    }

    return balance;
  }

  /// Reconcile a single member by account number
  Future<Map<String, dynamic>> reconcileSingleMember(String accountNumber) async {
    print('🔄 Reconciling member: $accountNumber');

    try {
      // Find the member
      QuerySnapshot memberSnapshot = await _firestore
          .collection('saccoplus-members')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isEmpty) {
        return {
          'success': false,
          'error': 'Member not found',
        };
      }

      var memberDoc = memberSnapshot.docs.first;
      String memberId = memberDoc.id;
      Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;
      
      String memberName = memberData['fullName'] ?? 'Unknown';
      double currentBalance = (memberData['savingsBalance'] ?? 0).toDouble();

      print('👤 Member: $memberName');
      print('   Current balance: UGX ${currentBalance.toStringAsFixed(2)}');

      // Calculate actual balance
      double actualBalance = await _calculateActualSavingsBalance(accountNumber);
      print('   Actual balance: UGX ${actualBalance.toStringAsFixed(2)}');

      double difference = currentBalance - actualBalance;

      // Update if different
      if (difference.abs() > 1.0) {
        await _firestore
            .collection('saccoplus-members')
            .doc(memberId)
            .update({
          'savingsBalance': actualBalance,
          'lastReconciled': FieldValue.serverTimestamp(),
        });

        print('   ✅ Updated successfully');

        return {
          'success': true,
          'memberName': memberName,
          'oldBalance': currentBalance,
          'newBalance': actualBalance,
          'difference': difference,
        };
      } else {
        print('   ✓ Balance already correct');
        return {
          'success': true,
          'noChangeNeeded': true,
        };
      }

    } catch (e) {
      print('❌ Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

/// Widget to run reconciliation from admin panel
class DataReconciliationScreen extends StatefulWidget {
  const DataReconciliationScreen({Key? key}) : super(key: key);

  @override
  State<DataReconciliationScreen> createState() => _DataReconciliationScreenState();
}

class _DataReconciliationScreenState extends State<DataReconciliationScreen> {
  final SavingsReconciliationScript _script = SavingsReconciliationScript();
  bool _isRunning = false;
  Map<String, dynamic>? _results;

  Future<void> _runReconciliation() async {
    setState(() {
      _isRunning = true;
      _results = null;
    });

    try {
      Map<String, dynamic> results = await _script.reconcileAllMembers();
      setState(() {
        _results = results;
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Reconciliation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Savings Balance Reconciliation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This tool will:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Calculate actual savings from transaction history'),
                    const Text('• Compare with stored balance in member documents'),
                    const Text('• Fix any discrepancies found'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isRunning ? null : _runReconciliation,
                      icon: _isRunning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_isRunning ? 'Running...' : 'Run Reconciliation'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_results != null) ...[
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Results',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          if (_results!['success'] == true) ...[
                            _buildResultRow(
                              'Total Members',
                              '${_results!['totalMembers']}',
                            ),
                            _buildResultRow(
                              'Updated Members',
                              '${_results!['updatedMembers']}',
                              Colors.orange,
                            ),
                            _buildResultRow(
                              'Errors',
                              '${_results!['errorMembers']}',
                              _results!['errorMembers'] > 0
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(height: 16),
                            if (_results!['discrepancies'] != null &&
                                (_results!['discrepancies'] as List).isNotEmpty) ...[
                              const Text(
                                'Discrepancies Fixed:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...((_results!['discrepancies'] as List)
                                  .map((disc) => Card(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                disc['memberName'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Account: ${disc['accountNumber']}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Old: UGX ${(disc['oldBalance'] as double).toStringAsFixed(2)}',
                                              ),
                                              Text(
                                                'New: UGX ${(disc['newBalance'] as double).toStringAsFixed(2)}',
                                              ),
                                              Text(
                                                'Difference: UGX ${(disc['difference'] as double).toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList()),
                            ],
                          ] else ...[
                            Text(
                              'Error: ${_results!['error']}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

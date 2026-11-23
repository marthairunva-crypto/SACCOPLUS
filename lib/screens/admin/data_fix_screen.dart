import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';

/// Admin screen to find and fix data issues
/// Currently handles: fixing revenue transactions that should be internal_transfer
class DataFixScreen extends StatefulWidget {
  const DataFixScreen({super.key});

  @override
  State<DataFixScreen> createState() => _DataFixScreenState();
}

class _DataFixScreenState extends State<DataFixScreen> {
  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _foundTransactions = [];

  final _receiptController = TextEditingController();

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  Future<void> _searchByReceipt() async {
    final receipt = _receiptController.text.trim();
    if (receipt.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a receipt number';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
      _foundTransactions = [];
    });

    try {
      // Try lowercase first
      var snapshot = await FirebaseFirestore.instance
          .collection('saccoplus-teller-transactions')
          .where('receiptNumber', isEqualTo: receipt)
          .limit(5)
          .get();

      // If not found, try uppercase
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('saccoplus-teller-transactions')
            .where('receiptNumber', isEqualTo: receipt.toUpperCase())
            .limit(5)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No transaction found with receipt: $receipt (tried both cases)';
          _loading = false;
        });
        return;
      }

      setState(() {
        _foundTransactions = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'data': doc.data(),
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching: $e';
        _loading = false;
      });
    }
  }

  Future<void> _searchRevenueTransactions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
      _foundTransactions = [];
    });

    try {
      // Search in BOTH collections: teller transactions AND till sessions
      print('🔍 Searching saccoplus-teller-transactions...');
      final tellerSnap = await FirebaseFirestore.instance
          .collection('saccoplus-teller-transactions')
          .limit(200)
          .get();
      
      print('📦 Found ${tellerSnap.docs.length} in teller-transactions');

      print('🔍 Searching till-sessions...');
      final tillSnap = await FirebaseFirestore.instance
          .collection('till-sessions')
          .limit(100)
          .get();
      
      print('📦 Found ${tillSnap.docs.length} till sessions');

      // Check till session entries
      final List<Map<String, dynamic>> tillEntries = [];
      for (final sessionDoc in tillSnap.docs) {
        final sessionData = sessionDoc.data();
        final entries = sessionData['entries'] as List<dynamic>?;
        if (entries != null) {
          for (final entry in entries) {
            if (entry is Map<String, dynamic>) {
              final receiptNum = entry['receiptNumber'] as String?;
              if (receiptNum != null && receiptNum.contains('2826111797336')) {
                print('  ✅ FOUND IN TILL SESSION: ${sessionDoc.id}');
                print('     Receipt: $receiptNum, Type: ${entry['type']}, Amount: ${entry['amount']}');
                tillEntries.add({
                  'id': '${sessionDoc.id}__${receiptNum}',
                  'data': {
                    ...entry,
                    '_sessionId': sessionDoc.id,
                    '_source': 'till-session',
                  },
                });
              }
            }
          }
        }
      }

      if (tillEntries.isNotEmpty) {
        setState(() {
          _foundTransactions = tillEntries;
          _successMessage = 'Found ${tillEntries.length} matching entry in till-sessions (not in teller-transactions!)';
          _loading = false;
        });
        return;
      }

      // Show all teller transactions
      final all = tellerSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'data': data,
        };
      }).toList();

      // Sort by timestamp
      all.sort((a, b) {
        final aData = a['data'] as Map<String, dynamic>;
        final bData = b['data'] as Map<String, dynamic>;
        final aTime = aData['timestamp'] as Timestamp?;
        final bTime = bData['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _foundTransactions = all.take(50).toList();
        _errorMessage = 'Transaction rct2826111797336 NOT found in either collection. It may have been deleted or never existed.';
        _loading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _errorMessage = 'Error searching: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fixTransaction(String docId, Map<String, dynamic> data) async {
    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fix Transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt: ${data['receiptNumber']}'),
            Text('Amount: UGX ${_formatMoney(data['amount'])}'),
            Text('Date: ${_formatTimestamp(data['timestamp'])}'),
            const SizedBox(height: 16),
            const Text('This will:'),
            const Text('• Change type: revenue → internal_transfer'),
            const Text('• Add direction: in'),
            const Text('• Fix till session entry'),
            const Text('• Remove from Income Reports'),
            const Text('• Keep in Till Sessions'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fix It'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final receiptNumber = data['receiptNumber'] as String?;
      
      // 1. Fix the transaction document
      await FirebaseFirestore.instance
          .collection('saccoplus-teller-transactions')
          .doc(docId)
          .update({
        'type': 'internal_transfer',
        'direction': 'in',
        'fixedAt': FieldValue.serverTimestamp(),
        'fixNote': 'Changed from revenue to internal_transfer - bank→cash is not income',
      });

      // 2. Fix the till entry (in separate collection saccoplus-till-entries)
      if (receiptNumber != null) {
        print('🔍 Searching for till entry with receipt: $receiptNumber');
        
        final entriesSnapshot = await FirebaseFirestore.instance
            .collection('saccoplus-till-entries')
            .where('receiptNumber', isEqualTo: receiptNumber)
            .limit(5)
            .get();

        print('📦 Found ${entriesSnapshot.docs.length} matching till entries');

        for (final entryDoc in entriesSnapshot.docs) {
          final entryData = entryDoc.data();
          final currentType = entryData['entryType'];
          
          print('  ✅ FOUND entry ${entryDoc.id}');
          print('     Current entryType: $currentType');
          
          if (currentType == 'revenue') {
            await entryDoc.reference.update({
              'entryType': 'internal_transfer_in',
            });
            print('  ✅ Updated entryType to internal_transfer_in');
          } else {
            print('  ℹ️ Already fixed (type is $currentType)');
          }
        }
      }

      setState(() {
        _successMessage = 'Fixed! Transaction ${data['receiptNumber']} is now internal_transfer.\nBoth transaction and till session updated.';
        _loading = false;
        // Remove from list
        _foundTransactions.removeWhere((t) => t['id'] == docId);
      });

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Fixed ${data['receiptNumber']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fixing transaction: $e';
        _loading = false;
      });
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return '0';
    final numValue = amount is num ? amount : (int.tryParse(amount.toString()) ?? 0);
    return NumberFormat('#,###').format(numValue);
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Unknown';
    try {
      final DateTime dt = (ts as Timestamp).toDate();
      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
    } catch (e) {
      return ts.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final TC = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Transaction Data'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text('Data Fix Tools', style: TC.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Fix transactions that were incorrectly categorized',
                    style: TC.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Search by receipt
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Search by Receipt Number',
                              style: TC.titleMedium),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _receiptController,
                                  decoration: const InputDecoration(
                                    labelText: 'Receipt Number',
                                    hintText: 'e.g. rct2026111797336',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _searchByReceipt(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _searchByReceipt,
                                icon: const Icon(Icons.search),
                                label: const Text('Search'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search all revenue
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Find All Revenue Transactions',
                              style: TC.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Lists recent transactions marked as "revenue" (some may be internal transfers)',
                            style: TC.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _searchRevenueTransactions,
                            icon: const Icon(Icons.list),
                            label: const Text('Show Revenue Transactions'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),

                  // Success message
                  if (_successMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_successMessage!,
                                style: const TextStyle(color: Colors.green)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Results
                  if (_foundTransactions.isNotEmpty) ...[
                    Text(
                      '${_foundTransactions.length} transaction(s) found',
                      style: TC.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ..._foundTransactions.map((item) {
                      final data = item['data'] as Map<String, dynamic>;
                      final alreadyFixed = data['type'] == 'internal_transfer';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Receipt: ${data['receiptNumber']}',
                                          style: TC.titleSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Amount: UGX ${_formatMoney(data['amount'])}',
                                          style: TC.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: ${_formatTimestamp(data['timestamp'])}',
                                          style: TC.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Type: ${data['type']}',
                                          style: TC.bodySmall?.copyWith(
                                            color: alreadyFixed
                                                ? Colors.green
                                                : Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (data['description'] != null)
                                          Text(
                                            'Note: ${data['description']}',
                                            style: TC.bodySmall
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!alreadyFixed)
                                    ElevatedButton.icon(
                                      onPressed: () => _fixTransaction(
                                          item['id'], data),
                                      icon: const Icon(Icons.build),
                                      label: const Text('Fix'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    )
                                  else
                                    ElevatedButton.icon(
                                      onPressed: () => _fixTransaction(
                                          item['id'], data),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Fix Till Session'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/professional_data_table.dart';

// Payment Hub Screen
class PaymentHubScreen extends StatelessWidget {
  const PaymentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Payment Hub', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payments')
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('');
            print('🔥🔥🔥 FIRESTORE INDEX ERROR - PAYMENTS 🔥🔥🔥');
            print('');
            print(snapshot.error.toString());
            print('');
            print('👆 COPY THE URL ABOVE AND PASTE IN YOUR BROWSER 👆');
            print('');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Index Required', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Check console for index creation URL'),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = snapshot.data!.docs;

          return Column(
            children: [
              _buildPaymentStats(payments),
              Expanded(
                child: payments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index].data() as Map<String, dynamic>;
                          return _buildPaymentCard(payment);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentStats(List<QueryDocumentSnapshot> payments) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    double total = 0;
    int pending = 0;
    int completed = 0;

    for (var doc in payments) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] ?? 0).toDouble();
      if (data['status'] == 'pending') pending++;
      if (data['status'] == 'completed') completed++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('Total', currencyFormat.format(total), Icons.payments, Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Pending', pending.toString(), Icons.hourglass_empty, Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Completed', completed.toString(), Icons.check_circle, Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final status = payment['status'] ?? 'pending';
    final statusColor = status == 'completed' ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.payment, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['type'] ?? 'Payment',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format((payment['createdAt'] as Timestamp).toDate()),
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(payment['amount']),
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No payments yet', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}

// Mobile Money Screen
class MobileMoneyScreen extends StatelessWidget {
  const MobileMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Mobile Money', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProviderCards(context),
            const SizedBox(height: 24),
            Text('Recent Transactions', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildTransactionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCards(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildProviderCard('MTN Mobile Money', Colors.yellow.shade700, Icons.phone_android)),
        const SizedBox(width: 12),
        Expanded(child: _buildProviderCard('Airtel Money', Colors.red, Icons.phone_iphone)),
      ],
    );
  }

  Widget _buildProviderCard(String provider, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            provider,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mobileMoneyTransactions')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('');
          print('🔥🔥🔥 FIRESTORE INDEX ERROR - MOBILE MONEY 🔥🔥🔥');
          print('');
          print(snapshot.error.toString());
          print('');
          print('👆 COPY THE URL ABOVE AND PASTE IN YOUR BROWSER 👆');
          print('');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Index Required', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Check console for index creation URL'),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!.docs;

        if (transactions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.phone_android_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No mobile money transactions', style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: ModernTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(txn['provider'] ?? 'Mobile Money', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
                        Text(
                          DateFormat('MMM dd, yyyy').format((txn['createdAt'] as Timestamp).toDate()),
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(txn['amount']),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// Bank Transfers Screen with Till Management
class BankTransfersScreen extends StatefulWidget {
  const BankTransfersScreen({super.key});

  @override
  State<BankTransfersScreen> createState() => _BankTransfersScreenState();
}

class _BankTransfersScreenState extends State<BankTransfersScreen> {
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Bank Transfers & Till', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Till Summary Card
          _buildTillSummary(),
          
          // Transfers Table
          Expanded(child: _buildTransfersTable()),
        ],
      ),
    );
  }

  Widget _buildTillSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('saccoplus-wallet-transactions')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('paymentMethod', isEqualTo: 'bank_transfer')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final pendingTransfers = snapshot.data!.docs;
        final totalTill = pendingTransfers.fold<int>(
          0,
          (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0) as int,
        );

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Till Balance (Pending)',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UGX ${fmt.format(totalTill)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pendingTransfers.length} pending transfer${pendingTransfers.length == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              if (totalTill > 0) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showSettleAllDialog(pendingTransfers),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Settle All Transfers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransfersTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('saccoplus-wallet-transactions')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('paymentMethod', isEqualTo: 'bank_transfer')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading transfers', style: GoogleFonts.poppins(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var transfers = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'memberName': data['memberName'] ?? data['farmerId'] ?? 'Member',
            'memberPhone': data['memberPhone'] ?? 'N/A',
            'amount': data['amount'] ?? 0,
            'reference': data['reference'] ?? doc.id,
            'timestamp': data['timestamp'],
            'status': data['status'] ?? 'pending',
          };
        }).toList();

        // Sort in memory by timestamp (descending)
        transfers.sort((a, b) {
          final aTime = a['timestamp'];
          final bTime = b['timestamp'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        // Limit to 100 most recent
        if (transfers.length > 100) {
          transfers = transfers.sublist(0, 100);
        }

        if (transfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.transform_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No bank transfers', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ProfessionalDataTable(
            columns: [
              const DataTableColumn(
                key: 'memberName',
                label: 'Member',
                width: 180,
              ),
              const DataTableColumn(
                key: 'memberPhone',
                label: 'Phone',
                width: 130,
              ),
              DataTableColumn(
                key: 'amount',
                label: 'Amount',
                width: 140,
                builder: (row) => Text(
                  'UGX ${fmt.format(row['amount'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              DataTableColumn(
                key: 'reference',
                label: 'Reference',
                width: 150,
                builder: (row) {
                  final ref = row['reference'] as String;
                  return Text(
                    ref.length > 20 ? '${ref.substring(0, 20)}...' : ref,
                    style: const TextStyle(fontSize: 13),
                  );
                },
              ),
              DataTableColumn(
                key: 'timestamp',
                label: 'Date',
                width: 140,
                builder: (row) {
                  final timestamp = row['timestamp'];
                  if (timestamp is Timestamp) {
                    return Text(
                      DateFormat('MMM dd, yyyy').format(timestamp.toDate()),
                      style: const TextStyle(fontSize: 13),
                    );
                  }
                  return const Text('-', style: TextStyle(fontSize: 13));
                },
              ),
              DataTableColumn(
                key: 'status',
                label: 'Status',
                width: 110,
                builder: (row) {
                  final status = row['status'] ?? 'pending';
                  final statusColor = status == 'settled'
                      ? AppTheme.success
                      : status == 'failed'
                          ? AppTheme.error
                          : AppTheme.warning;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
              DataTableColumn(
                key: 'actions',
                label: 'Actions',
                width: 140,
                builder: (row) {
                  final status = row['status'] ?? 'pending';
                  if (status == 'pending') {
                    return ElevatedButton.icon(
                      onPressed: () => _markAsSettled(row['id'], row),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Settle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                    );
                  }
                  return Text('-', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey));
                },
              ),
            ],
            data: transfers,
            filters: const [
              TableFilter(
                key: 'status',
                label: 'Status',
                options: [
                  FilterOption(value: 'pending', label: 'Pending'),
                  FilterOption(value: 'settled', label: 'Settled'),
                  FilterOption(value: 'failed', label: 'Failed'),
                ],
              ),
            ],
            searchPlaceholder: 'Search by member name, phone, reference...',
          ),
        );
      },
    );
  }

  Future<void> _markAsSettled(String docId, Map<String, dynamic> transfer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Settlement', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Confirm that UGX ${fmt.format(transfer['amount'])} has been received in your bank account?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('saccoplus-wallet-transactions')
            .doc(docId)
            .update({
          'status': 'settled',
          'settledAt': FieldValue.serverTimestamp(),
          'settledBy': FirebaseService.sessionUid,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transfer marked as settled'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSettleAllDialog(List<QueryDocumentSnapshot> transfers) async {
    final total = transfers.fold<int>(
      0,
      (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0) as int,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Settle All Transfers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm that the following amount has been received in your bank account:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    'UGX ${fmt.format(total)}',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.success,
                    ),
                  ),
                  Text(
                    '${transfers.length} transfers',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Confirm All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in transfers) {
          batch.update(doc.reference, {
            'status': 'settled',
            'settledAt': FieldValue.serverTimestamp(),
            'settledBy': FirebaseService.sessionUid,
          });
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${transfers.length} transfers marked as settled'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
}

// Reconciliation Screen
class ReconciliationScreen extends StatelessWidget {
  const ReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Reconciliation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReconciliationSummary(),
            const SizedBox(height: 24),
            Text('Pending Items', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPendingItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.sync, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            'Account Reconciliation',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep your accounts balanced and accurate',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingItems() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text(
              'All accounts reconciled',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

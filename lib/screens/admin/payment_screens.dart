import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class MobileMoneyScreen extends StatefulWidget {
  const MobileMoneyScreen({super.key});

  @override
  State<MobileMoneyScreen> createState() => _MobileMoneyScreenState();
}

class _MobileMoneyScreenState extends State<MobileMoneyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Mobile Money Transactions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.check_circle), text: 'Completed'),
            Tab(icon: Icon(Icons.history), text: 'All'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsList('pending'),
                _buildTransactionsList('completed'),
                _buildTransactionsList('all'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('mobileMoneyTransactions')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snapshot) {
        double pending = 0;
        double completed = 0;
        int pendingCount = 0;
        int completedCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0).toDouble();
            final status = data['status'] as String?;

            if (status == 'pending') {
              pending += amount;
              pendingCount++;
            } else if (status == 'completed' || status == 'approved') {
              completed += amount;
              completedCount++;
            }
          }
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade700, Colors.purple.shade900],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Pending',
                  'UGX ${_currencyFormat.format(pending)}',
                  '$pendingCount transactions',
                  Icons.access_time,
                  Colors.orange.shade400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Completed',
                  'UGX ${_currencyFormat.format(completed)}',
                  '$completedCount transactions',
                  Icons.check_circle,
                  Colors.green.shade400,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, String amount, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(String filter) {
    Query query = FirebaseFirestore.instance
        .collection('mobileMoneyTransactions')
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .orderBy('createdAt', descending: true);

    if (filter == 'pending') {
      query = query.where('status', isEqualTo: 'pending');
    } else if (filter == 'completed') {
      query = query.where('status', whereIn: ['completed', 'approved']);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Extract the Firestore index URL from the error message
          final errorMsg = snapshot.error.toString();
          String? indexUrl;
          
          // Try to extract URL from the error message
          final urlMatch = RegExp(r'https://[^\s]+').firstMatch(errorMsg);
          if (urlMatch != null) {
            indexUrl = urlMatch.group(0);
          }
          
          // Print to console
          debugPrint('');
          debugPrint('🔥🔥🔥 FIRESTORE INDEX ERROR - MOBILE MONEY 🔥🔥🔥');
          debugPrint('');
          debugPrint(errorMsg);
          debugPrint('');
          if (indexUrl != null) {
            debugPrint('👆 INDEX URL: $indexUrl 👆');
            debugPrint('');
          }
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Firestore Index Required',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This query requires a composite index.',
                    style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  if (indexUrl != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        indexUrl,
                        style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (indexUrl != null) {
                          Clipboard.setData(ClipboardData(text: indexUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Index URL copied to clipboard!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy URL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Click the URL above, sign in to Firebase Console, and click "Create Index".',
                    style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!.docs;

        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_android_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    filter == 'pending'
                        ? 'No pending transactions'
                        : filter == 'completed'
                            ? 'No completed transactions'
                            : 'No transactions yet',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Client mobile money deposits will appear here',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final doc = transactions[index];
            final txn = doc.data() as Map<String, dynamic>;
            final status = txn['status'] as String? ?? 'pending';
            final isPending = status == 'pending';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPending ? Colors.orange.shade200 : Colors.green.shade200,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isPending
                                      ? [Colors.orange.shade400, Colors.orange.shade600]
                                      : [Colors.green.shade400, Colors.green.shade600],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isPending ? Icons.pending_actions : Icons.check_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    txn['memberName'] ?? txn['clientName'] ?? 'Unknown Member',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    txn['provider'] ?? 'Mobile Money',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isPending ? Colors.orange.shade200 : Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                isPending ? 'PENDING' : 'COMPLETED',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow('Amount', 'UGX ${_currencyFormat.format(txn['amount'])}'),
                              const Divider(height: 16),
                              _buildDetailRow('Phone', txn['phoneNumber'] ?? 'N/A'),
                              const Divider(height: 16),
                              _buildDetailRow(
                                'Date',
                                txn['createdAt'] != null
                                    ? DateFormat('MMM dd, yyyy hh:mm a').format(
                                        (txn['createdAt'] as Timestamp).toDate(),
                                      )
                                    : 'N/A',
                              ),
                              if (txn['reference'] != null) ...[
                                const Divider(height: 16),
                                _buildDetailRow('Reference', txn['reference']),
                              ],
                              if (txn['description'] != null) ...[
                                const Divider(height: 16),
                                _buildDetailRow('Description', txn['description']),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPending)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveTransaction(doc.id, txn),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectTransaction(doc.id),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                side: BorderSide(color: Colors.red.shade600, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _approveTransaction(String docId, Map<String, dynamic> txn) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      // Update member's savings balance
      final memberId = txn['memberId'] as String?;
      if (memberId != null && memberId.isNotEmpty) {
        final memberRef = FirebaseFirestore.instance.collection('saccoplus-members').doc(memberId);
        final memberSnap = await memberRef.get();
        
        if (memberSnap.exists) {
          final currentSavings = (memberSnap.data()?['savingsBalance'] ?? 0).toDouble();
          final amount = (txn['amount'] ?? 0).toDouble();
          
          await memberRef.update({
            'savingsBalance': currentSavings + amount,
          });

          // Record in savings transactions
          await FirebaseFirestore.instance.collection('saccoplus-savings-transactions').add({
            'tenantId': FirebaseService.sessionTenantId,
            'memberId': memberId,
            'memberName': txn['memberName'] ?? 'Unknown',
            'type': 'Deposit',
            'amount': amount,
            'balanceAfter': currentSavings + amount,
            'method': 'Mobile Money',
            'provider': txn['provider'],
            'phoneNumber': txn['phoneNumber'],
            'reference': txn['reference'],
            'description': txn['description'] ?? 'Mobile money deposit',
            'status': 'Approved',
            'approvedBy': FirebaseService.sessionProfile?['name'] as String? ?? 
                         FirebaseService.sessionProfile?['fullName'] as String? ?? 'Admin',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update transaction status
      await FirebaseFirestore.instance
          .collection('mobileMoneyTransactions')
          .doc(docId)
          .update({
        'status': 'completed',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseService.sessionProfile?['name'] as String? ?? 
                     FirebaseService.sessionProfile?['fullName'] as String? ?? 'Admin',
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction approved successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _rejectTransaction(String docId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            const Text('Reject Transaction?'),
          ],
        ),
        content: const Text('Are you sure you want to reject this transaction? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('mobileMoneyTransactions')
          .doc(docId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseService.sessionProfile?['name'] as String? ?? 
                     FirebaseService.sessionProfile?['fullName'] as String? ?? 'Admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaction rejected'),
            backgroundColor: Colors.orange.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
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
            tableKey: 'payment_history',
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

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
        title: Text('Collections', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ModernTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              indicatorColor: ModernTheme.primary,
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'This Week'),
                Tab(text: 'This Month'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCollectionsList('today'),
                _buildCollectionsList('week'),
                _buildCollectionsList('month'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordPaymentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
        backgroundColor: ModernTheme.primary,
        heroTag: 'collections_fab',
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loanRepayments')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        final payments = snapshot.data!.docs;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = today.subtract(Duration(days: now.weekday - 1));

        double todayTotal = 0;
        double weekTotal = 0;
        double monthTotal = 0;

        for (var doc in payments) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = (data['createdAt'] as Timestamp).toDate();
          final amount = (data['amount'] ?? 0).toDouble();

          if (timestamp.isAfter(today)) todayTotal += amount;
          if (timestamp.isAfter(weekStart)) weekTotal += amount;
          monthTotal += amount;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: _buildSummaryCard('Today', todayTotal, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('This Week', weekTotal, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('This Month', monthTotal, Colors.purple)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsList(String period) {
    DateTime startDate;
    final now = DateTime.now();

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loanRepayments')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data!.docs;

        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No collections in this period', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index].data() as Map<String, dynamic>;
            return _buildPaymentCard(payment);
          },
        );
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('farmers').doc(payment['farmerId']).get(),
                  builder: (context, snapshot) {
                    final memberName = snapshot.hasData 
                        ? ((snapshot.data!.data() as Map?)?['name'] ?? 'Unknown')
                        : 'Loading...';
                    return Text(
                      memberName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                    );
                  },
                ),
              ),
              Text(
                _currencyFormat.format(payment['amount'] ?? 0),
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                DateFormat('MMM dd, yyyy hh:mm a').format(
                  (payment['createdAt'] as Timestamp).toDate(),
                ),
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (payment['receiptNumber'] != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.receipt, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Receipt: ${payment['receiptNumber']}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
          if (payment['notes'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                payment['notes'],
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRecordPaymentDialog() {
    final amountController = TextEditingController();
    final receiptController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedMemberId;
    String? selectedLoanId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Record Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('farmers')
                      .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    
                    return DropdownButtonFormField<String>(
                      value: selectedMemberId,
                      decoration: const InputDecoration(labelText: 'Select Member'),
                      items: snapshot.data!.docs.map((doc) {
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text((doc.data() as Map)['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMemberId = value;
                          selectedLoanId = null;
                        });
                      },
                    );
                  },
                ),
                if (selectedMemberId != null) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('loans')
                        .where('farmerId', isEqualTo: selectedMemberId)
                        .where('status', whereIn: ['approved', 'disbursed'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      
                      if (snapshot.data!.docs.isEmpty) {
                        return const Text('No active loans for this member');
                      }
                      
                      return DropdownButtonFormField<String>(
                        value: selectedLoanId,
                        decoration: const InputDecoration(labelText: 'Select Loan'),
                        items: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('Loan - ${NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0).format(data['amount'])}'),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedLoanId = value),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Payment Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: receiptController,
                  decoration: const InputDecoration(labelText: 'Receipt Number (Optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMemberId == null || selectedLoanId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select member and loan')),
                  );
                  return;
                }

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid amount')),
                  );
                  return;
                }

                await FirebaseFirestore.instance.collection('loanRepayments').add({
                  'tenantId': FirebaseService.sessionTenantId,
                  'farmerId': selectedMemberId,
                  'loanId': selectedLoanId,
                  'amount': amount,
                  'receiptNumber': receiptController.text.isEmpty ? null : receiptController.text,
                  'notes': notesController.text.isEmpty ? null : notesController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseService.sessionUid,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment recorded'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}

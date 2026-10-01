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
          .collection('saccoplus-repayments')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('paidAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30))))
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
          final timestamp = data['paidAt'] != null 
              ? (data['paidAt'] as Timestamp).toDate() 
              : (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
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
          .collection('saccoplus-repayments')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('paidAt', isGreaterThan: Timestamp.fromDate(startDate))
          .orderBy('paidAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading data: ${snapshot.error}'),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final payments = snapshot.data!.docs;

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
                  future: FirebaseFirestore.instance
                      .collection('saccoplus-members')
                      .doc(payment['memberId'] ?? payment['farmerId'])
                      .get(),
                  builder: (context, snapshot) {
                    final data = snapshot.hasData ? (snapshot.data!.data() as Map?) : null;
                    final memberName = data?['name'] ?? data?['fullName'] ?? 'Unknown Member';
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
    final phoneController = TextEditingController();
    String? selectedMemberId;
    String? selectedLoanId;
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Record Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Member Dropdown
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('saccoplus-members')
                      .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    return DropdownButtonFormField<String>(
                      value: selectedMemberId,
                      decoration: const InputDecoration(labelText: 'Select Member'),
                      items: snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data['name'] ?? data['fullName'] ?? 'Unknown'),
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
                
                // Loan Dropdown (shows when member selected)
                if (selectedMemberId != null) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('saccoplus-loans')
                        .where('memberId', isEqualTo: selectedMemberId)
                        .where('status', whereIn: ['active', 'disbursed', 'overdue', 'approved'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      
                      if (snapshot.data!.docs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('No active loans for this member'),
                        );
                      }
                      
                      return DropdownButtonFormField<String>(
                        value: selectedLoanId,
                        decoration: const InputDecoration(labelText: 'Select Loan'),
                        items: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final amount = data['amount'] ?? data['loanAmount'] ?? 0;
                          final outstanding = data['principalOutstanding'] ?? 0;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('Loan UGX ${NumberFormat('#,##0').format(amount)} (Outstanding: ${NumberFormat('#,##0').format(outstanding)})'),
                          );
                        }).toList(),
                        onChanged: (value) => setDialogState(() => selectedLoanId = value),
                      );
                    },
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Payment Method
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('💵 Cash')),
                    DropdownMenuItem(value: 'MTN Money', child: Text('📱 MTN Money')),
                    DropdownMenuItem(value: 'Airtel Money', child: Text('📱 Airtel Money')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('🏦 Bank Transfer')),
                  ],
                  onChanged: (value) => setDialogState(() => paymentMethod = value!),
                ),
                
                // Phone number for mobile money
                if (paymentMethod == 'MTN Money' || paymentMethod == 'Airtel Money') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '256XXXXXXXXX',
                      helperText: 'Format: 256XXXXXXXXX (12 digits)',
                      helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
                
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: 'UGX ',
                  ),
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
                
                // Validate phone for mobile money
                if ((paymentMethod == 'MTN Money' || paymentMethod == 'Airtel Money') && phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter phone number for mobile money')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('saccoplus-repayments').add({
                    'tenantId': FirebaseService.sessionTenantId,
                    'memberId': selectedMemberId,
                    'loanId': selectedLoanId,
                    'amount': amount,
                    'paymentMethod': paymentMethod,
                    'phoneNumber': phoneController.text.isEmpty ? null : phoneController.text,
                    'transactionRef': receiptController.text.isEmpty ? null : receiptController.text,
                    'notes': notesController.text.isEmpty ? null : notesController.text,
                    'paidAt': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'recordedBy': FirebaseService.sessionUid,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment recorded successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}

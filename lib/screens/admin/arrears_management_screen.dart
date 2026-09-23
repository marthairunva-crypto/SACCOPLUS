import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';

class ArrearsManagementScreen extends StatefulWidget {
  const ArrearsManagementScreen({super.key});

  @override
  State<ArrearsManagementScreen> createState() => _ArrearsManagementScreenState();
}

class _ArrearsManagementScreenState extends State<ArrearsManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: Text('Arrears Management', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSummarySection(),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ModernTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
              indicatorColor: ModernTheme.primary,
              isScrollable: true,
              tabs: const [
                Tab(text: '1-30 Days'),
                Tab(text: '31-60 Days'),
                Tab(text: '61-90 Days'),
                Tab(text: '90+ Days'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildArrearsList(1, 30),
                _buildArrearsList(31, 60),
                _buildArrearsList(61, 90),
                _buildArrearsList(91, 999),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loans')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('status', whereIn: ['approved', 'disbursed'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        }

        final loans = snapshot.data!.docs;
        int count1_30 = 0;
        int count31_60 = 0;
        int count61_90 = 0;
        int count90Plus = 0;
        double totalArrears = 0;

        for (var doc in loans) {
          final data = doc.data() as Map<String, dynamic>;
          final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
          
          if (dueDate != null && dueDate.isBefore(DateTime.now())) {
            final daysOverdue = DateTime.now().difference(dueDate).inDays;
            
            if (daysOverdue <= 30) count1_30++;
            else if (daysOverdue <= 60) count31_60++;
            else if (daysOverdue <= 90) count61_90++;
            else count90Plus++;
            
            final amountPaid = (data['amountPaid'] ?? 0).toDouble();
            final totalDue = (data['amount'] ?? 0).toDouble();
            totalArrears += (totalDue - amountPaid);
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Arrears',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          _currencyFormat.format(totalArrears),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildStatCard('1-30 Days', count1_30, Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('31-60 Days', count31_60, Colors.deepOrange)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('61-90 Days', count61_90, Colors.red)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatCard('90+ Days', count90Plus, Colors.red.shade900)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildArrearsList(int minDays, int maxDays) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loans')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('status', whereIn: ['approved', 'disbursed'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final loans = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
          
          if (dueDate == null || dueDate.isAfter(DateTime.now())) return false;
          
          final daysOverdue = DateTime.now().difference(dueDate).inDays;
          return daysOverdue >= minDays && daysOverdue <= maxDays;
        }).toList();

        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                const SizedBox(height: 16),
                Text(
                  'No arrears in this range',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index].data() as Map<String, dynamic>;
            final loanId = loans[index].id;
            return _buildArrearCard(loanId, loan);
          },
        );
      },
    );
  }

  Widget _buildArrearCard(String loanId, Map<String, dynamic> loan) {
    final dueDate = (loan['dueDate'] as Timestamp?)?.toDate();
    final daysOverdue = dueDate != null ? DateTime.now().difference(dueDate).inDays : 0;
    final amountPaid = (loan['amountPaid'] ?? 0).toDouble();
    final totalDue = (loan['amount'] ?? 0).toDouble();
    final arrearAmount = totalDue - amountPaid;

    Color severityColor;
    if (daysOverdue <= 30) severityColor = Colors.orange;
    else if (daysOverdue <= 60) severityColor = Colors.deepOrange;
    else if (daysOverdue <= 90) severityColor = Colors.red;
    else severityColor = Colors.red.shade900;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.warning_amber_rounded, color: severityColor),
        ),
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('farmers').doc(loan['farmerId']).get(),
          builder: (context, snapshot) {
            final memberName = snapshot.hasData 
                ? ((snapshot.data!.data() as Map?)?['name'] ?? 'Unknown')
                : 'Loading...';
            return Text(
              memberName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$daysOverdue days overdue',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: severityColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Arrears: ${_currencyFormat.format(arrearAmount)}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Loan Amount', _currencyFormat.format(totalDue)),
                _buildDetailRow('Amount Paid', _currencyFormat.format(amountPaid)),
                _buildDetailRow('Outstanding', _currencyFormat.format(arrearAmount)),
                _buildDetailRow('Due Date', dueDate != null ? DateFormat('MMM dd, yyyy').format(dueDate) : 'N/A'),
                _buildDetailRow('Days Overdue', '$daysOverdue days'),
                _buildDetailRow('Interest Rate', '${loan['interestRate'] ?? 0}%'),
                
                const Divider(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showContactDialog(loan['farmerId']),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Contact'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ModernTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showFollowUpDialog(loanId),
                        icon: const Icon(Icons.note_add, size: 18),
                        label: const Text('Add Note'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: severityColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(String farmerId) async {
    final doc = await FirebaseFirestore.instance.collection('farmers').doc(farmerId).get();
    final memberData = doc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Member', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(memberData['name'], style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 12),
            Text('Phone:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(memberData['phone'] ?? 'N/A', style: GoogleFonts.poppins(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFollowUpDialog(String loanId) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Follow-up Note', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter follow-up notes...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('loanFollowUps').add({
                'tenantId': FirebaseService.sessionTenantId,
                'loanId': loanId,
                'note': noteController.text,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': FirebaseService.sessionUid,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Follow-up note added'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

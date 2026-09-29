import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';

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

// Bank Transfers Screen
class BankTransfersScreen extends StatelessWidget {
  const BankTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Bank Transfers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bankTransfers')
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('');
            print('🔥🔥🔥 FIRESTORE INDEX ERROR - BANK TRANSFERS 🔥🔥🔥');
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

          final transfers = snapshot.data!.docs;

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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transfers.length,
            itemBuilder: (context, index) {
              final transfer = transfers[index].data() as Map<String, dynamic>;
              return _buildTransferCard(transfer);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('New Transfer'),
        backgroundColor: ModernTheme.primary,
        heroTag: 'bank_transfers_fab',
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);
    final status = transfer['status'] ?? 'pending';
    final statusColor = status == 'completed' ? Colors.green : status == 'failed' ? Colors.red : Colors.orange;

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
              Text(
                transfer['bankName'] ?? 'Bank Transfer',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Account: ${transfer['accountNumber'] ?? 'N/A'}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(transfer['amount']),
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: ModernTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('MMM dd, yyyy hh:mm a').format((transfer['createdAt'] as Timestamp).toDate()),
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';

class RiskProvisioningScreen extends StatefulWidget {
  const RiskProvisioningScreen({super.key});

  @override
  State<RiskProvisioningScreen> createState() => _RiskProvisioningScreenState();
}

class _RiskProvisioningScreenState extends State<RiskProvisioningScreen> {
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Risk & Provisioning', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('loans')
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final loans = snapshot.data!.docs;
          final riskAnalysis = _analyzeRisk(loans);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(riskAnalysis),
                const SizedBox(height: 24),
                _buildRiskDistributionChart(riskAnalysis),
                const SizedBox(height: 24),
                _buildProvisionRequirements(riskAnalysis),
                const SizedBox(height: 24),
                _buildHighRiskLoans(loans),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _analyzeRisk(List<QueryDocumentSnapshot> loans) {
    double totalExposure = 0;
    double provisionRequired = 0;
    int performingLoans = 0;
    int watchLoans = 0;
    int substandard = 0;
    int doubtful = 0;
    int loss = 0;

    for (var doc in loans) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      final amountPaid = (data['amountPaid'] ?? 0).toDouble();
      final outstanding = amount - amountPaid;
      
      totalExposure += outstanding;

      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
      if (dueDate != null && dueDate.isBefore(DateTime.now())) {
        final daysOverdue = DateTime.now().difference(dueDate).inDays;
        
        if (daysOverdue == 0) {
          performingLoans++;
          provisionRequired += outstanding * 0.01; // 1% provision
        } else if (daysOverdue <= 30) {
          watchLoans++;
          provisionRequired += outstanding * 0.05; // 5% provision
        } else if (daysOverdue <= 60) {
          substandard++;
          provisionRequired += outstanding * 0.20; // 20% provision
        } else if (daysOverdue <= 90) {
          doubtful++;
          provisionRequired += outstanding * 0.50; // 50% provision
        } else {
          loss++;
          provisionRequired += outstanding * 1.00; // 100% provision
        }
      } else {
        performingLoans++;
        provisionRequired += outstanding * 0.01;
      }
    }

    return {
      'totalExposure': totalExposure,
      'provisionRequired': provisionRequired,
      'performing': performingLoans,
      'watch': watchLoans,
      'substandard': substandard,
      'doubtful': doubtful,
      'loss': loss,
    };
  }

  Widget _buildSummaryCards(Map<String, dynamic> analysis) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Exposure',
                _currencyFormat.format(analysis['totalExposure']),
                Icons.account_balance,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Provision Required',
                _currencyFormat.format(analysis['provisionRequired']),
                Icons.shield,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Coverage Ratio',
                '${((analysis['provisionRequired'] / analysis['totalExposure']) * 100).toStringAsFixed(1)}%',
                Icons.pie_chart,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'NPL Ratio',
                '${(((analysis['substandard'] + analysis['doubtful'] + analysis['loss']) / (analysis['performing'] + analysis['watch'] + analysis['substandard'] + analysis['doubtful'] + analysis['loss'])) * 100).toStringAsFixed(1)}%',
                Icons.trending_down,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
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
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskDistributionChart(Map<String, dynamic> analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Risk Distribution',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildRiskCategoryBar('Performing', analysis['performing'], Colors.green),
              const SizedBox(width: 8),
              _buildRiskCategoryBar('Watch', analysis['watch'], Colors.yellow.shade700),
              const SizedBox(width: 8),
              _buildRiskCategoryBar('Substandard', analysis['substandard'], Colors.orange),
              const SizedBox(width: 8),
              _buildRiskCategoryBar('Doubtful', analysis['doubtful'], Colors.deepOrange),
              const SizedBox(width: 8),
              _buildRiskCategoryBar('Loss', analysis['loss'], Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCategoryBar(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionRequirements(Map<String, dynamic> analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Provision Requirements',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildProvisionRow('Performing (1%)', Colors.green),
          _buildProvisionRow('Watch (5%)', Colors.yellow.shade700),
          _buildProvisionRow('Substandard (20%)', Colors.orange),
          _buildProvisionRow('Doubtful (50%)', Colors.deepOrange),
          _buildProvisionRow('Loss (100%)', Colors.red),
        ],
      ),
    );
  }

  Widget _buildProvisionRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.poppins(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildHighRiskLoans(List<QueryDocumentSnapshot> loans) {
    final highRiskLoans = loans.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
      if (dueDate == null) return false;
      final daysOverdue = DateTime.now().difference(dueDate).inDays;
      return daysOverdue > 60; // Substandard, Doubtful, or Loss
    }).toList();

    if (highRiskLoans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
              const SizedBox(height: 8),
              Text('No high-risk loans', style: GoogleFonts.poppins(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'High Risk Loans (60+ days overdue)',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...highRiskLoans.take(5).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _buildHighRiskLoanTile(data);
          }),
        ],
      ),
    );
  }

  Widget _buildHighRiskLoanTile(Map<String, dynamic> loan) {
    final dueDate = (loan['dueDate'] as Timestamp?)?.toDate();
    final daysOverdue = dueDate != null ? DateTime.now().difference(dueDate).inDays : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('farmers').doc(loan['farmerId']).get(),
                  builder: (context, snapshot) {
                    final name = snapshot.hasData 
                        ? ((snapshot.data!.data() as Map?)?['name'] ?? 'Unknown') 
                        : 'Loading...';
                    return Text(
                      name,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                    );
                  },
                ),
                Text(
                  '$daysOverdue days overdue',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.red),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(loan['amount']),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

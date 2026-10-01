import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/professional_data_table.dart';

class SavingsSummaryScreen extends StatefulWidget {
  const SavingsSummaryScreen({super.key});

  @override
  State<SavingsSummaryScreen> createState() => _SavingsSummaryScreenState();
}

class _SavingsSummaryScreenState extends State<SavingsSummaryScreen> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Savings Summary', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('saccoplus-savings')
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final savings = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'memberId': data['memberId'] ?? '',
              'referenceId': data['referenceId'] ?? '',
              'accountNumber': data['accountNumber'] ?? '',
              'memberName': data['memberName'] ?? '',
              'branch': data['branch'] ?? '',
              'productName': data['productName'] ?? '',
              'memberType': data['memberType'] ?? 'Regular',
              'openingBalance': (data['openingBalance'] ?? 0).toDouble(),
              'availableBalance': (data['availableBalance'] ?? 0).toDouble(),
              'reservedBalance': (data['reservedBalance'] ?? 0).toDouble(),
              'amount': (data['amount'] ?? 0).toDouble(), // Total balance
              'productType': data['productType'] ?? '',
              'group': data['group'] ?? '',
            };
          }).toList();

          if (savings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No savings records found',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ProfessionalDataTable(
              columns: [
                const DataTableColumn(key: 'accountNumber', label: 'Account No.', width: 120),
                const DataTableColumn(key: 'memberName', label: 'Client Name', width: 170),
                const DataTableColumn(key: 'branch', label: 'Branch', width: 105),
                const DataTableColumn(key: 'productName', label: 'Product Name', width: 125),
                const DataTableColumn(key: 'memberType', label: 'Member Type', width: 105),
                DataTableColumn(
                  key: 'openingBalance',
                  label: 'Opening Balance',
                  width: 125,
                  builder: (row) => Text(
                    'UGX ${_currencyFormat.format(row['openingBalance'])}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                DataTableColumn(
                  key: 'availableBalance',
                  label: 'Available Balance',
                  width: 130,
                  builder: (row) => Text(
                    'UGX ${_currencyFormat.format(row['availableBalance'])}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
                DataTableColumn(
                  key: 'reservedBalance',
                  label: 'Reserved Balance',
                  width: 130,
                  builder: (row) => Text(
                    'UGX ${_currencyFormat.format(row['reservedBalance'])}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.orange.shade700),
                  ),
                ),
                DataTableColumn(
                  key: 'amount',
                  label: 'Total Balance',
                  width: 115,
                  builder: (row) => Text(
                    'UGX ${_currencyFormat.format(row['amount'])}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.green.shade800, fontWeight: FontWeight.w700),
                  ),
                ),
                const DataTableColumn(key: 'productType', label: 'Product Type', width: 110),
              ],
              data: savings,
              searchPlaceholder: 'Search by member name, ID, or account number...',
            ),
          );
        },
      ),
    );
  }
}

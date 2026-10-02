import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/audit_service.dart';
import '../../widgets/professional_data_table.dart';
import '../../widgets/sweet_alert.dart';
import '../../widgets/firebase_index_error.dart';
import '../../utils/csv_export.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to CSV',
            onPressed: () => _exportSavings(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Savings Record',
            onPressed: () => _showAddEditDialog(null),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('saccoplus-members')
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return FirebaseIndexError(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
              'memberName': data['name'] ?? data['fullName'] ?? 'Unknown',
              'savingsBalance': (data['savingsBalance'] ?? 0).toDouble(),
            };
          }).toList();

          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No members found',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Calculate statistics
          final totalSavings = members.fold<double>(0, (sum, m) => sum + (m['savingsBalance'] as double));
          final activeAccounts = members.where((m) => (m['savingsBalance'] as double) > 0).length;
          final zeroBalance = members.where((m) => (m['savingsBalance'] as double) == 0).length;
          final highValue = members.where((m) => (m['savingsBalance'] as double) >= 1000000).length;

          return Column(
            children: [
              // Summary Cards
              Container(
                margin: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Savings', 'UGX ${_currencyFormat.format(totalSavings.round())}', Icons.account_balance_wallet, const Color(0xFF00BFA6))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Active Accounts', '$activeAccounts', Icons.people, const Color(0xFF1976D2))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Zero Balance', '$zeroBalance', Icons.money_off, const Color(0xFFFF9800))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('High Value (≥1M)', '$highValue', Icons.trending_up, const Color(0xFF2E7D32))),
                      ],
                    );
                  },
                ),
              ),
              
              // Chart Section
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildSavingsChart(members),
              ),

              // Table
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProfessionalDataTable(
              columns: [
                const DataTableColumn(key: 'accountNumber', label: 'Account No.', width: 110),
                const DataTableColumn(key: 'memberName', label: 'Member Name', width: 180),
                DataTableColumn(
                  key: 'savingsBalance',
                  label: 'Savings Balance',
                  width: 150,
                  builder: (row) => Text(
                    'UGX ${_currencyFormat.format(row['savingsBalance'])}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
                DataTableColumn(
                  key: 'actions',
                  label: 'Actions',
                  width: 120,
                  builder: (row) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _showAddEditDialog(row),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1565C0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _showDeleteDialog(row),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFD32F2F)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              data: members,
              searchPlaceholder: 'Search by member name or account number...',
              filters: [
                TableFilter(
                  key: 'savingsBalance',
                  label: 'Balance Range',
                  options: const [
                    FilterOption(value: 'zero', label: 'Zero Balance'),
                    FilterOption(value: 'below_100k', label: 'Below 100K'),
                    FilterOption(value: '100k_500k', label: '100K - 500K'),
                    FilterOption(value: '500k_1m', label: '500K - 1M'),
                    FilterOption(value: 'above_1m', label: 'Above 1M'),
                  ],
                ),
              ],
            ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportSavings(BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .get();

      final savings = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
          'memberName': data['name'] ?? data['fullName'] ?? 'Unknown',
          'savingsBalance': (data['savingsBalance'] ?? 0).toDouble(),
          'lastUpdated': data['lastUpdated'],
        };
      }).toList();

      CsvExport.exportSavings(savings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Savings exported successfully! Check your Downloads folder.'),
            backgroundColor: Color(0xFF388E3C),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }


  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsChart(List<Map<String, dynamic>> members) {
    final zero = members.where((m) => (m['savingsBalance'] as double) == 0).length;
    final low = members.where((m) {
      final bal = m['savingsBalance'] as double;
      return bal > 0 && bal < 100000;
    }).length;
    final medium = members.where((m) {
      final bal = m['savingsBalance'] as double;
      return bal >= 100000 && bal < 500000;
    }).length;
    final high = members.where((m) => (m['savingsBalance'] as double) >= 500000).length;

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                PieChartSectionData(
                  color: Colors.grey.shade400,
                  value: zero.toDouble(),
                  title: '$zero',
                  radius: 32,
                  titleStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                PieChartSectionData(
                  color: const Color(0xFFFF9800),
                  value: low.toDouble(),
                  title: '$low',
                  radius: 32,
                  titleStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                PieChartSectionData(
                  color: const Color(0xFF1976D2),
                  value: medium.toDouble(),
                  title: '$medium',
                  radius: 32,
                  titleStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                PieChartSectionData(
                  color: const Color(0xFF2E7D32),
                  value: high.toDouble(),
                  title: '$high',
                  radius: 32,
                  titleStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Savings Distribution', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 12),
              _buildLegendItem('Zero Balance', zero, Colors.grey.shade400),
              const SizedBox(height: 8),
              _buildLegendItem('Low (<100K)', low, const Color(0xFFFF9800)),
              const SizedBox(height: 8),
              _buildLegendItem('Medium (100K-500K)', medium, const Color(0xFF1976D2)),
              const SizedBox(height: 8),
              _buildLegendItem('High (≥500K)', high, const Color(0xFF2E7D32)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
        const Spacer(),
        Text('$count', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  void _showAddEditDialog(Map<String, dynamic>? member) {
    final isEdit = member != null;
    final amountCtrl = TextEditingController(
      text: isEdit ? member['savingsBalance'].toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(isEdit ? Icons.edit : Icons.add, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isEdit ? 'Edit Savings Balance' : 'Add Savings',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['memberName'],
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Account: ${member['accountNumber']}',
                            style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Savings Balance (UGX) *',
                hintText: 'e.g., 50000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text.trim());
              if (amount == null || amount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                );
                return;
              }

              Navigator.pop(ctx);
              await _saveSavings(member!['id'], member['memberName'], amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEdit ? 'Update' : 'Add', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSavings(String memberId, String memberName, int amount) async {
    try {
      await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(memberId)
          .update({
        'savingsBalance': amount.toDouble(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await AuditService.log(
        action: 'SAVINGS_UPDATED',
        description: 'Updated savings balance to UGX ${_currencyFormat.format(amount)} for $memberName',
        targetId: memberId,
        targetName: memberName,
        meta: {'amount': amount},
      );

      if (mounted) {
        await SweetAlert.show(
          context: context,
          type: SweetAlertType.success,
          title: 'Success',
          message: 'Savings balance updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        await SweetAlert.show(
          context: context,
          type: SweetAlertType.error,
          title: 'Error',
          message: 'Failed to update savings: $e',
        );
      }
    }
  }

  void _showDeleteDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text('Reset Savings?'),
          ],
        ),
        content: Text(
          'Reset ${member['memberName']}\'s savings balance to zero (UGX 0)?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveSavings(member['id'], member['memberName'], 0);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Reset', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

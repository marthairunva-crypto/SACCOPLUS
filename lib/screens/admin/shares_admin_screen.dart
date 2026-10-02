import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/audit_service.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/professional_data_table.dart';
import '../../utils/csv_export.dart';

class SharesAdminScreen extends StatefulWidget {
  final bool embedded;
  const SharesAdminScreen({super.key, this.embedded = false});
  @override
  State<SharesAdminScreen> createState() => _SharesAdminScreenState();
}

class _SharesAdminScreenState extends State<SharesAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Shares Management'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export to CSV',
            onPressed: () => _exportShares(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Share Settings',
            onPressed: () => _showShareSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.monetization_on_rounded, color: Colors.white),
            tooltip: 'Process Dividends',
            onPressed: () => _showDividendDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Pending Purchases'), Tab(text: 'All Members')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SharePurchaseList(fmt: fmt, onAction: _handlePurchaseAction),
          _MemberSharesList(fmt: fmt),
        ],
      ),
    );
  }

  Future<void> _exportShares(BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .get();

      final shares = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
          'memberName': data['name'] ?? data['fullName'] ?? 'Unknown',
          'shareValue': (data['sharesBalance'] ?? 0).toDouble(),
          'lastUpdated': data['lastUpdated'],
        };
      }).toList();

      CsvExport.exportShares(shares);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shares exported successfully! Check your Downloads folder.'),
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

  void _handlePurchaseAction(String memberId, String txnId, String action, Map<String, dynamic> data) async {
    final db = FirebaseFirestore.instance;
    final shares = (data['shares'] as num?)?.toInt() ?? 0;
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final memberName = data['memberName'] as String? ?? '';

    if (action == 'approve') {
      // Update transaction
      await db.collection(AppConstants.sharesCol).doc(memberId)
          .collection('transactions').doc(txnId).update({
        'status': 'Approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      // Update member shares total
      await db.collection(AppConstants.sharesCol).doc(memberId).set({
        'memberId': memberId,
        'totalShares': FieldValue.increment(shares),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AuditService.log(
        action: AuditService.kSharePurchase,
        description: 'Share purchase approved: $shares shares (UGX ${fmt.format(amount)})',
        targetId: memberId, targetName: memberName,
        meta: {'shares': shares, 'amount': amount},
      );
      _snack('Share purchase approved. $shares shares credited.', AppTheme.success);
    } else {
      await db.collection(AppConstants.sharesCol).doc(memberId)
          .collection('transactions').doc(txnId).update({
        'status': 'Rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      _snack('Share purchase rejected.', AppTheme.error);
    }
  }

  void _showShareSettingsDialog(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    final settingsDoc = await db.collection('saccoplus-settings')
        .doc('${FirebaseService.sessionTenantId}_shares')
        .get();
    
    final currentPrice = (settingsDoc.data()?['sharePrice'] ?? 10000).toInt();
    final priceCtrl = TextEditingController(text: currentPrice.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Share Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set the price per share. This will be used when adding or purchasing shares.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Price per Share (UGX)',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                hintText: 'e.g., 10000',
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
              final price = int.tryParse(priceCtrl.text.trim());
              if (price == null || price < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price (minimum 100)'), backgroundColor: Colors.red),
                );
                return;
              }

              await db.collection('saccoplus-settings')
                  .doc('${FirebaseService.sessionTenantId}_shares')
                  .set({
                'sharePrice': price,
                'updatedAt': FieldValue.serverTimestamp(),
                'tenantId': FirebaseService.sessionTenantId,
              }, SetOptions(merge: true));

              Navigator.pop(ctx);
              _snack('Share price updated to UGX ${fmt.format(price)}', AppTheme.success);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showDividendDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final yearCtrl   = TextEditingController(text: DateTime.now().year.toString());
    bool processing  = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Process Dividends',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the total dividend pool. It will be distributed proportionally '
                'to all members based on their share count.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Financial Year',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Total Dividend Pool (UGX)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: processing
                  ? null
                  : () async {
                      final pool = int.tryParse(amountCtrl.text.trim());
                      final year = yearCtrl.text.trim();
                      if (pool == null || pool < 1000) return;
                      setS(() => processing = true);
                      await _processDividends(pool, year);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _snack('Dividends processed and distributed.', AppTheme.success);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: processing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Process', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processDividends(int totalPool, String year) async {
    final db = FirebaseFirestore.instance;
    // Get all member shares
    final snap = await db.collection(AppConstants.sharesCol).get();
    if (snap.docs.isEmpty) return;

    final totalShares = snap.docs.fold<int>(
        0, (s, d) => s + ((d['totalShares'] as num?)?.toInt() ?? 0));
    if (totalShares == 0) return;

    final batch = db.batch();
    for (final doc in snap.docs) {
      final memberShares = (doc['totalShares'] as num?)?.toInt() ?? 0;
      if (memberShares == 0) continue;
      final dividend = ((memberShares / totalShares) * totalPool).round();
      final divId = '${doc.id}_$year';
      batch.set(db.collection(AppConstants.dividendsCol).doc(divId), {
        'id': divId,
        'memberId': doc.id,
        'year': year,
        'shares': memberShares,
        'amount': dividend,
        'totalPool': totalPool,
        'processedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    AuditService.log(
      action: 'DIVIDEND_PROCESSED',
      description: 'Dividends processed: UGX ${fmt.format(totalPool)} for $year',
      meta: {'pool': totalPool, 'year': year, 'totalShares': totalShares},
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─── Pending Share Purchases ──────────────────────────────────────────────────
class _SharePurchaseList extends StatelessWidget {
  final NumberFormat fmt;
  final void Function(String memberId, String txnId, String action, Map<String, dynamic> data) onAction;
  const _SharePurchaseList({required this.fmt, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.sharesCol)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final memberDocs = snap.data?.docs ?? [];
        if (memberDocs.isEmpty) {
          return const EmptyState(message: 'No share purchase requests.', icon: Icons.pie_chart_outline_rounded);
        }

        // Collect all pending transactions across all members
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchPendingTxns(memberDocs),
          builder: (context, txnSnap) {
            if (!txnSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
            }
            final pending = txnSnap.data!;
            if (pending.isEmpty) {
              return const EmptyState(message: 'No pending share purchases.', icon: Icons.pie_chart_outline_rounded);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              itemBuilder: (_, i) {
                final item = pending[i];
                final memberId = item['_memberId'] as String;
                final txnId    = item['id'] as String? ?? '';
                final shares   = (item['shares'] as num?)?.toInt() ?? 0;
                final amount   = (item['amount'] as num?)?.toInt() ?? 0;
                final ts       = item['createdAt'];
                String dateStr = '—';
                if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.pie_chart_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$shares shares', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        ]),
                      ]),
                      Text('UGX ${fmt.format(amount)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onAction(memberId, txnId, 'reject', item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text('Reject', style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => onAction(memberId, txnId, 'approve', item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text('Approve', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ]),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPendingTxns(List<QueryDocumentSnapshot> memberDocs) async {
    final result = <Map<String, dynamic>>[];
    for (final doc in memberDocs) {
      final txns = await FirebaseFirestore.instance
          .collection(AppConstants.sharesCol)
          .doc(doc.id)
          .collection('transactions')
          .where('status', isEqualTo: 'Pending')
          .get();
      for (final t in txns.docs) {
        result.add({...t.data(), '_memberId': doc.id});
      }
    }
    return result;
  }
}

// ─── All Members Shares ───────────────────────────────────────────────────────
class _MemberSharesList extends StatefulWidget {
  final NumberFormat fmt;
  const _MemberSharesList({required this.fmt});

  @override
  State<_MemberSharesList> createState() => _MemberSharesListState();
}

class _MemberSharesListState extends State<_MemberSharesList> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        
        final docs = snap.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No members found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text(
                  'Add members first to manage their shares',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Build member shares list from members collection
        final membersList = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shares = (data['sharesBalance'] ?? 0).toDouble();
          
          return {
            'id': doc.id,
            'memberId': data['memberId'] ?? data['accountNumber'] ?? doc.id,
            'memberName': data['name'] ?? data['fullName'] ?? 'Unknown',
            'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
            'totalShares': shares.toInt(),
            'shareValue': shares, // Already in currency value
            'lastUpdated': data['lastUpdated'] ?? data['updatedAt'],
          };
        }).toList()
          ..sort((a, b) => (b['shareValue'] as double).compareTo(a['shareValue'] as double));

        final totalShares = membersList.fold<double>(0, (sum, m) => sum + (m['shareValue'] as double));
        final totalMembers = membersList.where((m) => (m['totalShares'] as int) > 0).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Shares Portfolio', 
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                            Text(
                              'UGX ${widget.fmt.format(totalShares)}',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalMembers members with shares',
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showAddSharesDialog(null),
                        icon: const Icon(Icons.add_circle, color: Colors.white, size: 32),
                        tooltip: 'Add Member Shares',
                      ),
                    ],
                  ),
                ),

                // Data Table
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth - 32;
                      
                      return Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        constraints: BoxConstraints(maxWidth: availableWidth),
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
                        clipBehavior: Clip.hardEdge,
                        child: _buildSharesTable(membersList, totalShares),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSharesTable(List<Map<String, dynamic>> membersList, double totalShares) {
    return ProfessionalDataTable(
      tableKey: 'shares_admin',
      columns: [
        const DataTableColumn(key: 'accountNumber', label: 'Account No.', flex: 2),
        const DataTableColumn(key: 'memberName', label: 'Member Name', flex: 3),
        DataTableColumn(
          key: 'shareValue',
          label: 'Share Value (UGX)',
          flex: 2,
          builder: (row) => Text(
            'UGX ${widget.fmt.format(row['shareValue'])}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
        DataTableColumn(
          key: 'actions',
          label: 'Actions',
          flex: 2,
          builder: (row) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _showAddSharesDialog(row),
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
                  onTap: () => _showTransactionHistory(row),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.history, size: 14, color: Color(0xFFE65100)),
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
      data: membersList,
      searchPlaceholder: 'Search by member name or account number...',
      filters: [
        TableFilter(
          key: 'shareValue',
          label: 'Share Range',
          options: const [
            FilterOption(value: 'zero', label: 'Zero Shares (0)'),
            FilterOption(value: 'below_150k', label: 'Below 150K'),
            FilterOption(value: '150k_500k', label: '150K - 500K'),
            FilterOption(value: '500k_1m', label: '500K - 1M'),
            FilterOption(value: '1m_2m', label: '1M - 2M'),
            FilterOption(value: 'above_2m', label: 'Above 2M'),
          ],
        ),
      ],
    );
  }

  void _showAddSharesDialog(Map<String, dynamic>? existingMember) async {
    final isEdit = existingMember != null;
    
    // Fetch current share price
    final db = FirebaseFirestore.instance;
    final settingsDoc = await db.collection('saccoplus-settings')
        .doc('${FirebaseService.sessionTenantId}_shares')
        .get();
    final sharePrice = (settingsDoc.data()?['sharePrice'] ?? 10000).toInt();

    // Fetch all members for dropdown
    final membersSnapshot = await db.collection('saccoplus-members')
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .get();
    
    final allMembers = membersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'memberId': data['memberId'] ?? data['accountNumber'] ?? doc.id,
        'memberName': data['name'] ?? data['fullName'] ?? 'Unknown',
        'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
      };
    }).toList();

    String? selectedMemberId = existingMember?['id'];
    String selectedMemberName = existingMember?['memberName'] ?? '';
    String selectedAccountNumber = existingMember?['accountNumber'] ?? '';
    
    final sharesCtrl = TextEditingController(
        text: existingMember != null ? existingMember['totalShares'].toString() : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
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
                isEdit ? 'Edit Member Shares' : 'Add Member Shares',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Member Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: isEdit ? Colors.grey.shade100 : Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('Select Member *', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                    value: selectedMemberId,
                    icon: Icon(Icons.arrow_drop_down, color: isEdit ? Colors.grey : AppTheme.primary),
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                    items: allMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'] as String,
                        child: Text(
                          '${member['memberName']} (${member['accountNumber']})',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: isEdit ? null : (String? newValue) {
                      if (newValue != null) {
                        final selectedMember = allMembers.firstWhere((m) => m['id'] == newValue);
                        setState(() {
                          selectedMemberId = newValue;
                          selectedMemberName = selectedMember['memberName'] as String;
                          selectedAccountNumber = selectedMember['accountNumber'] as String;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Display selected member details
              if (selectedMemberId != null) ...[
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
                              selectedMemberName,
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Account: $selectedAccountNumber',
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
                controller: sharesCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Share Amount (UGX) *',
                  hintText: 'e.g., 10000, 15000, 35000',
                  helperText: 'Standard: ${widget.fmt.format(sharePrice)} per share, but any amount is accepted',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickAmountChip(amount: sharePrice, fmt: widget.fmt, onTap: (amt) => setState(() => sharesCtrl.text = amt.toString())),
                  _QuickAmountChip(amount: sharePrice * 2, fmt: widget.fmt, onTap: (amt) => setState(() => sharesCtrl.text = amt.toString())),
                  _QuickAmountChip(amount: sharePrice * 3, fmt: widget.fmt, onTap: (amt) => setState(() => sharesCtrl.text = amt.toString())),
                  _QuickAmountChip(amount: sharePrice * 5, fmt: widget.fmt, onTap: (amt) => setState(() => sharesCtrl.text = amt.toString())),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Entered Value: UGX ${widget.fmt.format(int.tryParse(sharesCtrl.text) ?? 0)}',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700),
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
                if (selectedMemberId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a member'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                final shareAmount = int.tryParse(sharesCtrl.text) ?? 0;
                if (shareAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid share amount'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(ctx);
                await _saveShares(selectedMemberId!, selectedMemberName, shareAmount, isEdit);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEdit ? 'Update' : 'Add', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveShares(String memberId, String memberName, int shareAmount, bool isEdit) async {
    try {
      // Update shares in members collection
      await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(memberId)
          .update({
        'sharesBalance': shareAmount.toDouble(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Log the action
      await AuditService.log(
        action: isEdit ? 'SHARES_UPDATED' : 'SHARES_ADDED',
        description: '${isEdit ? 'Updated' : 'Added'} shares worth UGX ${widget.fmt.format(shareAmount)} for $memberName',
        targetId: memberId,
        targetName: memberName,
        meta: {'shareAmount': shareAmount},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Shares updated successfully' : 'Shares added successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showDeleteDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 12),
            Text('Delete Shares?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${member['memberName']}\'s share record (${member['totalShares']} shares)?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteShares(member['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShares(String docId) async {
    try {
      // Set shares to 0 in members collection instead of deleting
      await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(docId)
          .update({
        'sharesBalance': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shares cleared successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showTransactionHistory(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Share History - ${member['memberName']}', 
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Transaction history coming soon...', 
                  style: GoogleFonts.poppins(fontSize: 13)),
            ],
          ),
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
}

// Quick amount selection chip widget
class _QuickAmountChip extends StatelessWidget {
  final int amount;
  final NumberFormat fmt;
  final Function(int) onTap;

  const _QuickAmountChip({
    required this.amount,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(amount),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Text(
          fmt.format(amount),
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

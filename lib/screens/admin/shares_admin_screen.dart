import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/audit_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

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
class _MemberSharesList extends StatelessWidget {
  final NumberFormat fmt;
  const _MemberSharesList({required this.fmt});

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
        
        final docs = snap.data?.docs ?? [];
        
        print('📊 Shares query returned ${docs.length} documents');
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No share records yet', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text(
                  'Share transactions will appear here once imported or created',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Aggregate shares by member from transaction documents
        final Map<String, Map<String, dynamic>> memberShares = {};
        double totalSharesValue = 0;
        
        for (final doc in docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            
            // Handle both data structures:
            // 1. Transaction format: {farmerId, amount, memberName, ...}
            // 2. Summary format: {memberId, totalShares, ...}
            
            String? memberId;
            double shareValue = 0;
            String memberName = '';
            
            if (data.containsKey('farmerId')) {
              // Transaction document
              memberId = data['farmerId'] as String?;
              shareValue = ((data['amount'] ?? 0) as num).toDouble();
              memberName = data['memberName'] as String? ?? memberId ?? '';
            } else if (data.containsKey('memberId')) {
              // Summary document
              memberId = data['memberId'] as String?;
              shareValue = ((data['totalShares'] ?? 0) as num).toDouble() * 1000; // Assuming 1000 per share
              memberName = memberId ?? '';
            } else {
              // Use doc ID as memberId
              memberId = doc.id;
              shareValue = ((data['totalShares'] ?? data['amount'] ?? 0) as num).toDouble();
              memberName = memberId;
            }
            
            if (memberId == null || memberId.isEmpty) continue;
            
            if (!memberShares.containsKey(memberId)) {
              memberShares[memberId] = {
                'memberId': memberId,
                'memberName': memberName,
                'totalValue': 0.0,
                'count': 0,
              };
            }
            
            memberShares[memberId]!['totalValue'] = 
                (memberShares[memberId]!['totalValue'] as double) + shareValue;
            memberShares[memberId]!['count'] = 
                (memberShares[memberId]!['count'] as int) + 1;
            totalSharesValue += shareValue;
            
          } catch (e) {
            print('Error processing share document ${doc.id}: $e');
          }
        }
        
        print('📊 Aggregated ${memberShares.length} unique members');
        print('📊 Total shares value: UGX ${fmt.format(totalSharesValue)}');
        
        if (memberShares.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No valid share records found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text(
                  '${docs.length} documents found but could not be processed',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }
        
        final membersList = memberShares.values.toList()
          ..sort((a, b) => (b['totalValue'] as double).compareTo(a['totalValue'] as double));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: membersList.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Shares Value', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                    Text(
                      'UGX ${fmt.format(totalSharesValue)}',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${membersList.length} members  •  ${docs.length} transactions',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                    ),
                  ]),
                ]),
              );
            }
            
            final member = membersList[i - 1];
            final shareValue = member['totalValue'] as double;
            final count = member['count'] as int;
            final memberId = member['memberId'] as String;
            final memberName = member['memberName'] as String;
            final pct = totalSharesValue > 0 ? (shareValue / totalSharesValue * 100) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                      style: GoogleFonts.poppins(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$memberId  •  $count transaction${count > 1 ? 's' : ''}  •  ${pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'UGX ${fmt.format(shareValue)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

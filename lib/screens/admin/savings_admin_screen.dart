import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/audit_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class SavingsAdminScreen extends StatefulWidget {
  const SavingsAdminScreen({super.key});
  @override
  State<SavingsAdminScreen> createState() => _SavingsAdminScreenState();
}

class _SavingsAdminScreenState extends State<SavingsAdminScreen>
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
        title: const Text('Savings Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Pending Deposits'), Tab(text: 'All Transactions')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SavingsList(statusFilter: 'Pending', fmt: fmt, onAction: _handleAction),
          _SavingsList(statusFilter: null, fmt: fmt, onAction: _handleAction),
        ],
      ),
    );
  }

  void _handleAction(String docId, String action, Map<String, dynamic> data) async {
    final db = FirebaseFirestore.instance;
    final memberId   = data['memberId'] as String? ?? '';
    final memberName = data['memberName'] as String? ?? '';
    final amount     = (data['amount'] as num?)?.toInt() ?? 0;
    final type       = data['savingsType'] as String? ?? '';

    if (action == 'approve') {
      // 1. Mark transaction as Approved
      await db.collection(AppConstants.savingsTxnCol).doc(docId).update({
        'status': 'Approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
      // 2. Update member savings summary
      final field = type == AppConstants.savingsVoluntary
          ? 'voluntary'
          : type == AppConstants.savingsCompulsory
              ? 'compulsory'
              : 'fixedDeposit';
      await db.collection(AppConstants.savingsCol).doc(memberId).set({
        field: FieldValue.increment(amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AuditService.log(
        action: AuditService.kSavingsDeposit,
        description: 'Savings deposit approved: UGX ${fmt.format(amount)} ($type)',
        targetId: memberId, targetName: memberName,
        meta: {'amount': amount, 'type': type},
      );
      _snack('Deposit approved and credited.', AppTheme.success);
    } else {
      await db.collection(AppConstants.savingsTxnCol).doc(docId).update({
        'status': 'Rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      _snack('Deposit rejected.', AppTheme.error);
    }
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

class _SavingsList extends StatelessWidget {
  final String? statusFilter;
  final NumberFormat fmt;
  final void Function(String docId, String action, Map<String, dynamic> data) onAction;

  const _SavingsList({this.statusFilter, required this.fmt, required this.onAction});

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection(AppConstants.savingsTxnCol)
        .orderBy('createdAt', descending: true);
    
    // For "Pending Deposits" tab, show only manually pending transactions
    // (Auto-approved transactions won't appear here)
    if (statusFilter == 'Pending') {
      q = q.where('status', isEqualTo: 'Pending');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return EmptyState(
            message: statusFilter == 'Pending'
                ? 'No pending deposits. All savings are auto-approved!'
                : 'No savings transactions yet.',
            icon: Icons.savings_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            final status = data['status'] as String? ?? 'Pending';
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final type   = data['savingsType'] as String? ?? '—';
            final memberName = data['memberName'] as String? ?? 
                              data['name'] as String? ?? 
                              data['fullName'] as String? ?? 
                              () {
                                final uid = data['uid'] as String? ?? '';
                                if (uid.length >= 8) {
                                  return 'Member ${uid.substring(0, 8)}';
                                } else if (uid.isNotEmpty) {
                                  return 'Member $uid';
                                } else {
                                  return 'Unknown Member';
                                }
                              }();
            final memberPhone = data['memberPhone'] as String? ?? data['phone'] as String? ?? '';
            final memberNumber = data['memberNumber'] as String? ?? data['memberNo'] as String? ?? '';
            final autoApproved = data['autoApproved'] as bool? ?? false;
            final ts = data['timestamp'] ?? data['createdAt'];
            String dateStr = '—';
            if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy • HH:mm').format(ts.toDate());

            Color statusColor;
            String statusText = status;
            switch (status) {
              case 'Approved': 
                statusColor = AppTheme.success; 
                statusText = autoApproved ? 'Auto-Approved' : 'Approved';
                break;
              case 'Rejected': statusColor = AppTheme.error; break;
              default: statusColor = AppTheme.warning;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withOpacity(0.25)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.savings_rounded, color: AppTheme.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(memberName, 
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                          if (memberNumber.isNotEmpty)
                            Text('Member #$memberNumber', 
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                          if (memberPhone.isNotEmpty)
                            Text(memberPhone, 
                                style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('UGX ${fmt.format(amount)}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(statusText,
                              style: GoogleFonts.poppins(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Type: $type',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                      Text(dateStr,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  if (status == 'Pending') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onAction(docId, 'reject', data),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Reject', style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => onAction(docId, 'approve', data),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text('Approve & Credit', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FIXED DEPOSITS — Admin Management Screen
// ═══════════════════════════════════════════════════════════════════════════

class FixedDepositsAdminScreen extends StatefulWidget {
  final bool embedded;
  const FixedDepositsAdminScreen({super.key, this.embedded = false});
  @override
  State<FixedDepositsAdminScreen> createState() => _FixedDepositsAdminScreenState();
}

class _FixedDepositsAdminScreenState extends State<FixedDepositsAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
        title: const Text('Fixed Deposits'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
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
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Matured'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.fixedDepositCol)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data?.docs ?? [];
          final pending = all.where((d) => (d['status'] as String?) == 'Pending').toList();
          final active  = all.where((d) => (d['status'] as String?) == 'Active').toList();
          final matured = all.where((d) => (d['status'] as String?) == 'Matured').toList();

          return TabBarView(
            controller: _tabs,
            children: [
              _DepositList(docs: pending, fmt: fmt, emptyMsg: 'No pending applications.',
                  onAction: _handleAction),
              _DepositList(docs: active, fmt: fmt, emptyMsg: 'No active fixed deposits.',
                  onAction: _handleAction),
              _DepositList(docs: matured, fmt: fmt, emptyMsg: 'No matured deposits.',
                  onAction: _handleAction),
            ],
          );
        },
      ),
    );
  }

  void _handleAction(String docId, String action) async {
    try {
      final adminUid = FirebaseService.sessionUid;
      
      switch (action) {
        case 'approve':
          await FirebaseService.approveFD(
            fdId: docId,
            adminUid: adminUid,
            notes: 'Approved via admin panel',
          );
          _snack('Fixed deposit approved and activated.', AppTheme.success);
          break;
        case 'reject':
          // Show dialog to get rejection reason
          final reason = await _showRejectDialog();
          if (reason != null && reason.isNotEmpty) {
            await FirebaseService.rejectFD(
              fdId: docId,
              adminUid: adminUid,
              reason: reason,
            );
            _snack('Fixed deposit rejected.', AppTheme.error);
          }
          break;
        case 'mature':
          // Mark as matured manually
          await FirebaseFirestore.instance
              .collection(AppConstants.fixedDepositCol)
              .doc(docId)
              .update({
            'status': 'Matured',
            'maturedAt': FieldValue.serverTimestamp(),
          });
          _snack('Deposit marked as matured.', AppTheme.accent);
          break;
        case 'close':
          await FirebaseFirestore.instance
              .collection(AppConstants.fixedDepositCol)
              .doc(docId)
              .update({
            'status': 'Closed',
            'closedAt': FieldValue.serverTimestamp(),
          });
          _snack('Deposit closed.', AppTheme.textSecondary);
          break;
      }
    } catch (e) {
      _snack('Error: ${e.toString()}', AppTheme.error);
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Fixed Deposit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for rejection:', style: GoogleFonts.poppins()),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. Insufficient documentation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
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

// ─── Deposit List ─────────────────────────────────────────────────────────────
class _DepositList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final NumberFormat fmt;
  final String emptyMsg;
  final void Function(String docId, String action) onAction;

  const _DepositList({
    required this.docs, required this.fmt,
    required this.emptyMsg, required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return EmptyState(message: emptyMsg, icon: Icons.account_balance_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        return _AdminDepositCard(
          docId: docs[i].id,
          data: data,
          fmt: fmt,
          onAction: onAction,
        );
      },
    );
  }
}

// ─── Admin Deposit Card ───────────────────────────────────────────────────────
class _AdminDepositCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final NumberFormat fmt;
  final void Function(String docId, String action) onAction;

  const _AdminDepositCard({
    required this.docId, required this.data,
    required this.fmt, required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final memberName   = data['memberName'] as String? ?? 'Member';
    final principal    = (data['principal'] as num?)?.toInt() ?? 0;
    final rate         = (data['interestRate'] as num?)?.toDouble() ?? 0.0;
    final termMonths   = (data['termMonths'] as num?)?.toInt() ?? 0;
    final status       = data['status'] as String? ?? 'Pending';
    final netInterest  = (data['interestEarned'] as num?)?.toInt() ?? 0;
    final maturityVal  = (data['maturityValue'] as num?)?.toInt() ?? 0;
    final rollover     = data['rollover'] as bool? ?? false;
    final maturityDate = data['maturityDate'] as String? ?? '—';
    final createdAt    = data['createdAt'];

    String dateStr = '—';
    if (createdAt is Timestamp) {
      dateStr = DateFormat('MMM d, yyyy').format(createdAt.toDate());
    }

    String maturityStr = maturityDate;
    try {
      if (maturityDate != '—') {
        maturityStr = DateFormat('MMM d, yyyy').format(DateTime.parse(maturityDate));
      }
    } catch (_) {}

    Color statusColor;
    switch (status) {
      case 'Active':   statusColor = AppTheme.success; break;
      case 'Matured':  statusColor = AppTheme.accent;  break;
      case 'Rejected': statusColor = AppTheme.error;   break;
      case 'Closed':   statusColor = AppTheme.textSecondary; break;
      default:         statusColor = AppTheme.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(memberName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('Applied $dateStr',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(status,
                      style: GoogleFonts.poppins(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Details ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(child: _detail('Principal', 'UGX ${fmt.format(principal)}')),
                Expanded(child: _detail('Term', '$termMonths months')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _detail('Rate', '${rate.toStringAsFixed(1)}% p.a.')),
                Expanded(child: _detail('Net Interest', 'UGX ${fmt.format(netInterest)}')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _detail('Maturity Value', 'UGX ${fmt.format(maturityVal)}')),
                Expanded(child: _detail('Maturity Date', maturityStr)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _detail('Auto-Rollover', rollover ? 'Yes' : 'No')),
              ]),
            ]),
          ),

          // ── Action buttons ────────────────────────────────────────────
          if (status == 'Pending') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(docId, 'reject'),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => onAction(docId, 'approve'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve & Activate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ]),
            ),
          ] else if (status == 'Active') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(docId, 'close'),
                    icon: const Icon(Icons.lock_rounded, size: 16),
                    label: const Text('Close Early'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onAction(docId, 'mature'),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Mark Matured'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
      Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
    ],
  );
}

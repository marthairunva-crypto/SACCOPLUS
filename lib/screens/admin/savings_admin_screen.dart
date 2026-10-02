import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/audit_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class SavingsAdminScreen extends StatefulWidget {
  final bool embedded;
  const SavingsAdminScreen({super.key, this.embedded = false});
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
    } else if (action == 'reject') {
      await db.collection(AppConstants.savingsTxnCol).doc(docId).update({
        'status': 'Rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      _snack('Deposit rejected.', AppTheme.error);
    } else if (action == 'edit') {
      _showEditDialog(docId, data);
    } else if (action == 'delete') {
      _showDeleteDialog(docId, data);
    }
  }

  void _showEditDialog(String docId, Map<String, dynamic> data) {
    final amountCtrl = TextEditingController(text: data['amount'].toString());
    String selectedType = data['savingsType'] as String? ?? AppConstants.savingsVoluntary;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Edit Savings', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['memberName'] ?? 'Unknown',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: 'UGX ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Savings Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: [
                  DropdownMenuItem(value: AppConstants.savingsVoluntary, child: Text('Voluntary', style: GoogleFonts.poppins())),
                  DropdownMenuItem(value: AppConstants.savingsCompulsory, child: Text('Compulsory', style: GoogleFonts.poppins())),
                  DropdownMenuItem(value: 'Fixed Deposit', child: Text('Fixed Deposit', style: GoogleFonts.poppins())),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newAmount = int.tryParse(amountCtrl.text) ?? 0;
                if (newAmount <= 0) {
                  _snack('Please enter a valid amount', AppTheme.error);
                  return;
                }
                
                Navigator.pop(context);
                await _updateSavings(docId, data, newAmount, selectedType);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Save Changes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSavings(String docId, Map<String, dynamic> oldData, int newAmount, String newType) async {
    try {
      final db = FirebaseFirestore.instance;
      final memberId = oldData['memberId'] as String? ?? '';
      final memberName = oldData['memberName'] as String? ?? '';
      final oldAmount = (oldData['amount'] as num?)?.toInt() ?? 0;
      final oldType = oldData['savingsType'] as String? ?? '';
      
      // Calculate the difference
      final amountDiff = newAmount - oldAmount;
      
      // Update the transaction
      await db.collection(AppConstants.savingsTxnCol).doc(docId).update({
        'amount': newAmount,
        'savingsType': newType,
        'editedAt': FieldValue.serverTimestamp(),
      });
      
      // Update member savings summary
      // If type changed, we need to adjust both old and new type balances
      if (oldType != newType) {
        // Remove from old type
        final oldField = oldType == AppConstants.savingsVoluntary
            ? 'voluntary'
            : oldType == AppConstants.savingsCompulsory
                ? 'compulsory'
                : 'fixedDeposit';
        await db.collection(AppConstants.savingsCol).doc(memberId).update({
          oldField: FieldValue.increment(-oldAmount),
        });
        
        // Add to new type
        final newField = newType == AppConstants.savingsVoluntary
            ? 'voluntary'
            : newType == AppConstants.savingsCompulsory
                ? 'compulsory'
                : 'fixedDeposit';
        await db.collection(AppConstants.savingsCol).doc(memberId).update({
          newField: FieldValue.increment(newAmount),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else if (amountDiff != 0) {
        // Same type, just adjust the amount
        final field = newType == AppConstants.savingsVoluntary
            ? 'voluntary'
            : newType == AppConstants.savingsCompulsory
                ? 'compulsory'
                : 'fixedDeposit';
        await db.collection(AppConstants.savingsCol).doc(memberId).update({
          field: FieldValue.increment(amountDiff),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      AuditService.log(
        action: AuditService.kSavingsEdit,
        description: 'Savings edited: UGX ${fmt.format(oldAmount)} → ${fmt.format(newAmount)} ($oldType → $newType)',
        targetId: memberId,
        targetName: memberName,
        meta: {'oldAmount': oldAmount, 'newAmount': newAmount, 'oldType': oldType, 'newType': newType},
      );
      
      _snack('Savings updated successfully', AppTheme.success);
    } catch (e) {
      _snack('Error updating savings: $e', AppTheme.error);
    }
  }

  void _showDeleteDialog(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Delete Savings?', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this savings transaction?',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['memberName'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Amount: UGX ${fmt.format(data['amount'] ?? 0)}', style: GoogleFonts.poppins(fontSize: 12)),
                  Text('Type: ${data['savingsType'] ?? '—'}', style: GoogleFonts.poppins(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ This will deduct the amount from the member\'s balance.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSavings(docId, data);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSavings(String docId, Map<String, dynamic> data) async {
    try {
      final db = FirebaseFirestore.instance;
      final memberId = data['memberId'] as String? ?? '';
      final memberName = data['memberName'] as String? ?? '';
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final type = data['savingsType'] as String? ?? '';
      
      // Delete the transaction
      await db.collection(AppConstants.savingsTxnCol).doc(docId).delete();
      
      // Update member savings summary (deduct the amount)
      final field = type == AppConstants.savingsVoluntary
          ? 'voluntary'
          : type == AppConstants.savingsCompulsory
              ? 'compulsory'
              : 'fixedDeposit';
      await db.collection(AppConstants.savingsCol).doc(memberId).update({
        field: FieldValue.increment(-amount),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      AuditService.log(
        action: AuditService.kSavingsDelete,
        description: 'Savings deleted: UGX ${fmt.format(amount)} ($type)',
        targetId: memberId,
        targetName: memberName,
        meta: {'amount': amount, 'type': type},
      );
      
      _snack('Savings deleted successfully', AppTheme.success);
    } catch (e) {
      _snack('Error deleting savings: $e', AppTheme.error);
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
                  ] else ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onAction(docId, 'edit', data),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onAction(docId, 'delete', data),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text('Delete', style: GoogleFonts.poppins(fontSize: 13)),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/audit_service.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/professional_data_table.dart';
import '../../utils/csv_export.dart';

class LoanApprovalScreen extends StatefulWidget {
  final bool embedded;
  const LoanApprovalScreen({super.key, this.embedded = false});

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> {
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Loan Applications'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Loans',
            onPressed: _exportLoans,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getAllLoans(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const EmptyState(
              message: 'No loan applications here.',
              icon: Icons.inbox_rounded,
            );
          }

          final loans = snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              ...data,
            };
          }).toList();

          return Container(
            margin: const EdgeInsets.all(16),
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
            child: ProfessionalDataTable(
              columns: [
                DataTableColumn(
                  key: 'memberName',
                  label: 'Member',
                  width: 180,
                  builder: (row) => Text(
                    row['memberName'] ?? '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataTableColumn(
                  key: 'referenceNumber',
                  label: 'Loan Ref',
                  width: 120,
                  builder: (row) => Text(
                    row['referenceNumber'] ?? '-',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                DataTableColumn(
                  key: 'amount',
                  label: 'Amount',
                  width: 140,
                  builder: (row) => Text(
                    'UGX ${fmt.format(row['amount'] ?? 0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                DataTableColumn(
                  key: 'loanProduct',
                  label: 'Product',
                  width: 140,
                  builder: (row) => Text(
                    row['loanProduct'] ?? '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                DataTableColumn(
                  key: 'principalOutstanding',
                  label: 'Outstanding',
                  width: 120,
                  builder: (row) => Text(
                    'UGX ${fmt.format(row['principalOutstanding'] ?? 0)}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.red.shade700),
                  ),
                ),
                DataTableColumn(
                  key: 'createdAt',
                  label: 'Applied',
                  width: 110,
                  builder: (row) {
                    final createdAt = row['createdAt'];
                    if (createdAt is Timestamp) {
                      return Text(
                        DateFormat('MMM d, yyyy').format(createdAt.toDate()),
                        style: const TextStyle(fontSize: 13),
                      );
                    }
                    return const Text('-', style: TextStyle(fontSize: 13));
                  },
                ),
                DataTableColumn(
                  key: 'outstandingDays',
                  label: 'Days Overdue',
                  width: 120,
                  builder: (row) {
                    final outstandingDays = row['outstandingDays'] ?? 0;
                    if (outstandingDays > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$outstandingDays days',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    return Text(
                      '-',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    );
                  },
                ),
                DataTableColumn(
                  key: 'status',
                  label: 'Status',
                  width: 110,
                  builder: (row) {
                    final status = row['status'] ?? '';
                    Color bgColor;
                    Color textColor;
                    
                    if (status == 'paid' || status == 'cleared') {
                      bgColor = Colors.green.shade50;
                      textColor = Colors.green.shade700;
                    } else if (status == AppConstants.statusPending) {
                      bgColor = AppTheme.warning.withOpacity(0.1);
                      textColor = AppTheme.warning;
                    } else if (status == AppConstants.statusApproved || status == 'active') {
                      bgColor = AppTheme.success.withOpacity(0.1);
                      textColor = AppTheme.success;
                    } else if (status == 'overdue') {
                      bgColor = AppTheme.error.withOpacity(0.1);
                      textColor = AppTheme.error;
                    } else {
                      bgColor = Colors.grey.shade100;
                      textColor = Colors.grey.shade700;
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                DataTableColumn(
                  key: 'actions',
                  label: 'Actions',
                  width: 160,
                  builder: (row) {
                    final loanId = row['id'];
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 20),
                          color: Colors.blue,
                          onPressed: () => _showLoanDetails(context, loanId, row),
                          tooltip: 'View',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: Colors.orange,
                          onPressed: () => _editLoan(loanId, row),
                          tooltip: 'Edit',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          onPressed: () => _deleteLoan(loanId, row),
                          tooltip: 'Delete',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    );
                  },
                ),
              ],
              data: loans,
              onRowTap: (row) => _showLoanDetails(context, row['id'], row),
              filters: [
                TableFilter(
                  key: 'status',
                  label: 'Status',
                  options: const [
                    FilterOption(value: 'pending', label: 'Pending'),
                    FilterOption(value: 'approved', label: 'Approved'),
                    FilterOption(value: 'rejected', label: 'Rejected'),
                    FilterOption(value: 'cleared', label: 'Cleared/Paid'),
                  ],
                ),
                TableFilter(
                  key: 'loanType',
                  label: 'Type',
                  options: const [
                    FilterOption(value: 'business', label: 'Business'),
                    FilterOption(value: 'agriculture', label: 'Agriculture'),
                    FilterOption(value: 'emergency', label: 'Emergency'),
                    FilterOption(value: 'education', label: 'Education'),
                    FilterOption(value: 'development', label: 'Development'),
                  ],
                ),
              ],
              searchPlaceholder: 'Search by member name, purpose...',
            ),
          );
        },
      ),
    );
  }

  int _calculateDaysOverdue(Map<String, dynamic> loan) {
    final dueDate = loan['dueDate'];
    if (dueDate == null) return 0;

    DateTime? due;
    if (dueDate is Timestamp) {
      due = dueDate.toDate();
    } else if (dueDate is DateTime) {
      due = dueDate;
    }

    if (due == null) return 0;

    final now = DateTime.now();
    if (now.isAfter(due)) {
      return now.difference(due).inDays;
    }
    return 0;
  }

  void _handleAction(String loanId, String action, String farmerName) {
    if (action == AppConstants.statusApproved) {
      _doUpdate(loanId, AppConstants.statusApproved);
    } else {
      _showRejectDialog(loanId);
    }
  }

  Future<void> _markLoanAsPaid(String loanId, String farmerName, Map<String, dynamic> loanData) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark Loan as Paid', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to mark this loan as fully paid?', 
                style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 16),
            Text('Member: $farmerName', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('Amount: UGX ${NumberFormat('#,###').format(loanData['amount'] ?? 0)}', 
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will set the remaining balance to 0 and mark the loan as cleared.',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Update loan in Firestore
      await FirebaseFirestore.instance
          .collection('loans')
          .doc(loanId)
          .update({
        'balance': 0,
        'status': 'cleared',
        'clearedAt': FieldValue.serverTimestamp(),
        'clearedBy': FirebaseService.sessionUid,
        'manuallyCleared': true,
        'clearNote': 'Manually marked as paid by admin',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan marked as fully paid for $farmerName'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _exportLoans() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exporting loans...'),
          duration: Duration(seconds: 2),
        ),
      );

      final loans = await FirebaseService.getAllLoansOnce();

      if (loans.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No loans to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      CsvExport.exportLoans(loans);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${loans.length} loans successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _doUpdate(String loanId, String status, {String? note}) async {
    await FirebaseService.updateLoanStatus(loanId, status, note: note);
    AuditService.log(
      action: status == AppConstants.statusApproved
          ? AuditService.kLoanApproved
          : AuditService.kLoanRejected,
      description: 'Loan ${status.toLowerCase()} by admin',
      targetId: loanId,
      meta: note != null ? {'note': note} : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Loan ${status.toLowerCase()} successfully.'),
      backgroundColor:
          status == AppConstants.statusApproved ? AppTheme.success : AppTheme.error,
    ));
  }

  void _showRejectDialog(String loanId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Loan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doUpdate(loanId, AppConstants.statusRejected,
                  note: ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _editLoan(String loanId, Map<String, dynamic> loanData) {
    // Show edit dialog with loan fields
    showDialog(
      context: context,
      builder: (context) => _EditLoanDialog(loanId: loanId, loanData: loanData),
    ).then((updated) {
      if (updated == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Loan updated successfully')),
        );
      }
    });
  }

  Future<void> _deleteLoan(String loanId, Map<String, dynamic> loanData) async {
    final memberName = loanData['memberName'] ?? 'this member';
    final amount = loanData['amount'] ?? 0;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Loan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this loan?', 
                style: GoogleFonts.poppins(fontSize: 14)),
            const SizedBox(height: 16),
            Text('Member: $memberName', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('Amount: UGX ${NumberFormat('#,###').format(amount)}', 
                style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete the loan from Firestore
      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(loanId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Loan deleted for $memberName'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Log audit trail
      await AuditService.log(
        action: 'delete_loan',
        details: 'Deleted loan for $memberName (UGX ${NumberFormat('#,###').format(amount)})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting loan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLoanDetails(BuildContext context, String loanId, Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Loan Details', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Member Name', loan['memberName'] ?? loan['farmerName'] ?? 'N/A'),
                      _buildDetailRow('Amount', 'UGX ${fmt.format(loan['amount'] ?? 0)}'),
                      _buildDetailRow('Loan Type', loan['loanType'] ?? 'N/A'),
                      _buildDetailRow('Purpose', loan['purpose'] ?? 'N/A'),
                      _buildDetailRow('Period', loan['repaymentPeriod'] ?? loan['period'] ?? 'N/A'),
                      _buildDetailRow('Status', loan['status'] ?? 'N/A'),
                      _buildDetailRow('Applied On', loan['createdAt'] is Timestamp
                          ? DateFormat('MMM d, yyyy').format((loan['createdAt'] as Timestamp).toDate())
                          : 'N/A'),
                      if (loan['dueDate'] != null)
                        _buildDetailRow('Due Date', loan['dueDate'] is Timestamp
                            ? DateFormat('MMM d, yyyy').format((loan['dueDate'] as Timestamp).toDate())
                            : 'N/A'),
                      if (_calculateDaysOverdue(loan) > 0)
                        _buildDetailRow('Days Overdue', '${_calculateDaysOverdue(loan)} days',
                            color: AppTheme.error),
                    ],
                  ),
                ),
              ),
              if (loan['status'] == AppConstants.statusPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleAction(loanId, AppConstants.statusRejected,
                              loan['memberName'] ?? 'Member');
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleAction(loanId, AppConstants.statusApproved,
                              loan['memberName'] ?? 'Member');
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Edit Loan Dialog ─────────────────────────────────────────────────────────
class _EditLoanDialog extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic> loanData;

  const _EditLoanDialog({required this.loanId, required this.loanData});

  @override
  State<_EditLoanDialog> createState() => _EditLoanDialogState();
}

class _EditLoanDialogState extends State<_EditLoanDialog> {
  late TextEditingController _memberNameCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _principalOutstandingCtrl;
  late TextEditingController _interestAmountCtrl;
  late TextEditingController _loanProductCtrl;
  late TextEditingController _referenceNumberCtrl;
  String _selectedStatus = 'approved';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _memberNameCtrl = TextEditingController(text: widget.loanData['memberName'] ?? '');
    _amountCtrl = TextEditingController(text: (widget.loanData['amount'] ?? 0).toString());
    _principalOutstandingCtrl = TextEditingController(text: (widget.loanData['principalOutstanding'] ?? 0).toString());
    _interestAmountCtrl = TextEditingController(text: (widget.loanData['interestAmount'] ?? 0).toString());
    _loanProductCtrl = TextEditingController(text: widget.loanData['loanProduct'] ?? '');
    _referenceNumberCtrl = TextEditingController(text: widget.loanData['referenceNumber'] ?? '');
    _selectedStatus = widget.loanData['status'] ?? 'approved';
  }

  @override
  void dispose() {
    _memberNameCtrl.dispose();
    _amountCtrl.dispose();
    _principalOutstandingCtrl.dispose();
    _interestAmountCtrl.dispose();
    _loanProductCtrl.dispose();
    _referenceNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveLoan() async {
    setState(() => _saving = true);

    try {
      final updatedData = {
        'memberName': _memberNameCtrl.text.trim(),
        'amount': int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        'principalOutstanding': int.tryParse(_principalOutstandingCtrl.text.replaceAll(',', '')) ?? 0,
        'interestAmount': int.tryParse(_interestAmountCtrl.text.replaceAll(',', '')) ?? 0,
        'loanProduct': _loanProductCtrl.text.trim(),
        'referenceNumber': _referenceNumberCtrl.text.trim(),
        'status': _selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .doc(widget.loanId)
          .update(updatedData);

      // Log audit trail
      await AuditService.log(
        action: 'update_loan',
        details: 'Updated loan ${_referenceNumberCtrl.text} for ${_memberNameCtrl.text}',
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating loan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Loan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _memberNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Member Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _loanProductCtrl,
                decoration: const InputDecoration(
                  labelText: 'Loan Product',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Loan Amount (UGX)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _principalOutstandingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Principal Outstanding (UGX)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _interestAmountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Interest Amount (UGX)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _saveLoan,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

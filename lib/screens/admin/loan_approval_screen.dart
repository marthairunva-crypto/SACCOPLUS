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
import 'loan_card_dialog.dart';

class LoanApprovalScreen extends StatefulWidget {
  final bool embedded;
  const LoanApprovalScreen({super.key, this.embedded = false});

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> {
  final fmt = NumberFormat('#,##0', 'en_US');

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
            margin: const EdgeInsets.all(12),
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
                const DataTableColumn(
                  key: 'memberName',
                  label: 'Member Name',
                  width: 200,
                ),
                const DataTableColumn(
                  key: 'referenceNumber',
                  label: 'Reference',
                  width: 130,
                ),
                DataTableColumn(
                  key: 'amount',
                  label: 'Amount',
                  width: 120,
                  builder: (row) => Text(
                    fmt.format(row['amount'] ?? 0),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataTableColumn(
                  key: 'principalOutstanding',
                  label: 'Outstanding',
                  width: 120,
                  builder: (row) => Text(
                    fmt.format(row['principalOutstanding'] ?? 0),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                ),
                DataTableColumn(
                  key: 'createdAt',
                  label: 'Created',
                  width: 105,
                  builder: (row) {
                    final createdAt = row['createdAt'];
                    if (createdAt is Timestamp) {
                      return Text(
                        DateFormat('dd MMM yy').format(createdAt.toDate()),
                        style: const TextStyle(fontSize: 13),
                      );
                    }
                    return const Text('-', style: TextStyle(fontSize: 13));
                  },
                ),
                DataTableColumn(
                  key: 'disbursementDate',
                  label: 'Disbursed',
                  width: 105,
                  builder: (row) {
                    // Try multiple possible field names
                    final disbursementDate = row['disbursementDate'] ?? row['disbursedAt'] ?? row['Disbursement Date'];
                    
                    if (disbursementDate is Timestamp) {
                      return Text(
                        DateFormat('dd MMM yy').format(disbursementDate.toDate()),
                        style: const TextStyle(fontSize: 13),
                      );
                    } else if (disbursementDate is String && disbursementDate.isNotEmpty) {
                      try {
                        final date = DateFormat('MMMM d, yyyy').parse(disbursementDate);
                        return Text(
                          DateFormat('dd MMM yy').format(date),
                          style: const TextStyle(fontSize: 13),
                        );
                      } catch (e) {
                        return Text(disbursementDate, style: const TextStyle(fontSize: 11));
                      }
                    }
                    return const Text('-', style: TextStyle(fontSize: 13, color: Colors.grey));
                  },
                ),
                DataTableColumn(
                  key: 'dueDate',
                  label: 'Due Date',
                  width: 115,
                  builder: (row) {
                    // Try multiple possible field names
                    final dueDate = row['dueDate'] ?? row['Due Date'];
                    final outstandingDays = row['outstandingDays'] ?? row['overdueDays'] ?? row['Overdue Days'] ?? 0;
                    
                    DateTime? parsedDate;
                    
                    if (dueDate is Timestamp) {
                      parsedDate = dueDate.toDate();
                    } else if (dueDate is String && dueDate.isNotEmpty) {
                      try {
                        parsedDate = DateFormat('MMMM d, yyyy').parse(dueDate);
                      } catch (e) {
                        // Try other formats
                        try {
                          parsedDate = DateTime.parse(dueDate);
                        } catch (e2) {
                          return Text(dueDate, style: const TextStyle(fontSize: 11));
                        }
                      }
                    }
                    
                    if (parsedDate != null) {
                      final isOverdue = (outstandingDays is int && outstandingDays > 0) || 
                                       (outstandingDays is String && int.tryParse(outstandingDays) != null && int.parse(outstandingDays) > 0);
                      final days = outstandingDays is int ? outstandingDays : (int.tryParse(outstandingDays.toString()) ?? 0);
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('dd MMM yy').format(parsedDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: isOverdue ? const Color(0xFFD32F2F) : Colors.black87,
                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (isOverdue && days > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+$days days',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      );
                    }
                    return const Text('-', style: TextStyle(fontSize: 13));
                  },
                ),
                DataTableColumn(
                  key: 'status',
                  label: 'Status',
                  width: 95,
                  builder: (row) {
                    final status = row['status'] ?? '';
                    Color bgColor;
                    Color textColor;
                    String label;
                    
                    if (status == 'paid' || status == 'cleared') {
                      bgColor = const Color(0xFFE8F5E9);
                      textColor = const Color(0xFF2E7D32);
                      label = 'Paid';
                    } else if (status == AppConstants.statusPending) {
                      bgColor = const Color(0xFFFFF3E0);
                      textColor = const Color(0xFFE65100);
                      label = 'Pending';
                    } else if (status == AppConstants.statusApproved || status == 'active') {
                      bgColor = const Color(0xFFE3F2FD);
                      textColor = const Color(0xFF1565C0);
                      label = status == 'active' ? 'Active' : 'Approved';
                    } else if (status == 'overdue') {
                      bgColor = const Color(0xFFFFEBEE);
                      textColor = const Color(0xFFD32F2F);
                      label = 'Overdue';
                    } else {
                      bgColor = const Color(0xFFEEEEEE);
                      textColor = const Color(0xFF757575);
                      label = status;
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
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
                  width: 140,
                  builder: (row) {
                    final loanId = row['id'];
                    
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _showLoanDetails(context, loanId, row),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1565C0)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _editLoan(loanId, row),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFE65100)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _deleteLoan(loanId, row),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD32F2F)),
                            ),
                          ),
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
    // Show loan card dialog for editing
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: LoanCardDialog(loanId: loanId, loanData: loanData),
      ),
    );
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
        description: 'Deleted loan for $memberName (UGX ${NumberFormat('#,###').format(amount)})',
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
  void _showLoanDetails(BuildContext context, String loanId, Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: LoanCardDialog(loanId: loanId, loanData: loan),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    
    try {
      if (date is Timestamp) {
        return DateFormat('MMM d, yyyy').format(date.toDate());
      } else if (date is String) {
        // Try parsing string date
        final parsedDate = DateTime.tryParse(date);
        if (parsedDate != null) {
          return DateFormat('MMM d, yyyy').format(parsedDate);
        }
        // Return as-is if can't parse
        return date;
      } else if (date is DateTime) {
        return DateFormat('MMM d, yyyy').format(date);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    
    return 'N/A';
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

}

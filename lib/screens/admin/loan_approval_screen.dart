import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/audit_service.dart';
import '../../widgets/app_widgets.dart';

class LoanApprovalScreen extends StatefulWidget {
  final bool embedded;
  const LoanApprovalScreen({super.key, this.embedded = false});

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen>
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
        title: const Text('Loan Applications'),
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
          labelStyle:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Reviewed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LoanList(filter: 'All', fmt: fmt, onAction: _handleAction),
          _LoanList(
              filter: AppConstants.statusPending,
              fmt: fmt,
              onAction: _handleAction),
          _LoanList(filter: 'Reviewed', fmt: fmt, onAction: _handleAction),
        ],
      ),
    );
  }

  void _handleAction(String loanId, String action, String farmerName) {
    if (action == AppConstants.statusApproved) {
      _doUpdate(loanId, AppConstants.statusApproved);
    } else {
      _showRejectDialog(loanId);
    }
  }

  void _doUpdate(String loanId, String status, {String? note}) async {
    await FirebaseService.updateLoanStatus(loanId, status, note: note);
    // Audit log
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
}

// ─── Loan List (StreamBuilder) ────────────────────────────────────────────────
class _LoanList extends StatelessWidget {
  final String filter;
  final NumberFormat fmt;
  final void Function(String loanId, String action, String farmerName) onAction;

  const _LoanList(
      {required this.filter, required this.fmt, required this.onAction});

  bool _include(String status) {
    if (filter == 'All') return true;
    if (filter == AppConstants.statusPending) {
      return status == AppConstants.statusPending;
    }
    return status != AppConstants.statusPending;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.getAllLoans(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data?.docs ?? [])
            .where((d) => _include((d['status'] as String? ?? '')))
            .toList();
        if (docs.isEmpty) {
          return const EmptyState(
              message: 'No loan applications here.',
              icon: Icons.inbox_rounded);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final loanId = docs[i].id;
            final status = data['status'] as String? ?? '';
            final isPending = status == AppConstants.statusPending;
            final farmerName = data['memberName'] as String? ??
                data['farmerName'] as String? ??
                data['memberId'] as String? ??
                data['farmerId'] as String? ??
                'Member';
            return _LoanApprovalCard(
              loan: data,
              loanId: loanId,
              fmt: fmt,
              onApprove: isPending
                  ? () => onAction(
                      loanId, AppConstants.statusApproved, farmerName)
                  : null,
              onReject: isPending
                  ? () => onAction(
                      loanId, AppConstants.statusRejected, farmerName)
                  : null,
            );
          },
        );
      },
    );
  }
}

// ─── Loan Card ────────────────────────────────────────────────────────────────
class _LoanApprovalCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final String loanId;
  final NumberFormat fmt;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _LoanApprovalCard({
    required this.loan,
    required this.loanId,
    required this.fmt,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final farmerName = loan['memberName'] as String? ??
        loan['farmerName'] as String? ??
        loan['memberId'] as String? ??
        loan['farmerId'] as String? ??
        'Member';
    final amount = (loan['amount'] as num?)?.toInt() ?? 0;
    final loanType = loan['loanType'] as String? ?? '-';
    final purpose = loan['purpose'] as String? ?? '-';
    final period = loan['repaymentPeriod'] as String? ??
        loan['period'] as String? ??
        '-';
    final status = loan['status'] as String? ?? '-';
    final createdAt = loan['createdAt'];
    String dateStr = '-';
    if (createdAt is Timestamp) {
      dateStr = DateFormat('yyyy-MM-dd').format(createdAt.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farmerName,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(loanId.length >= 8
                          ? loanId.substring(0, 8).toUpperCase()
                          : loanId.toUpperCase(),
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _detail('Amount', 'UGX ${fmt.format(amount)}')),
              Expanded(child: _detail('Type', loanType)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _detail('Purpose', purpose)),
              Expanded(child: _detail('Period', period)),
            ],
          ),
          const SizedBox(height: 8),
          _detail('Applied On', dateStr),
          // ── View full details (incl. guarantors) ──────────────────────────
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showFullDetails(context),
            child: Row(
              children: [
                Text('View Full Details',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: AppTheme.primary),
              ],
            ),
          ),
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (onApprove != null && onReject != null)
                  const SizedBox(width: 10),
                if (onApprove != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppTheme.textSecondary)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  void _showFullDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LoanDetailSheet(loan: loan, loanId: loanId, fmt: fmt),
    );
  }
}

// ─── Full Loan Detail Sheet (with Guarantors) ─────────────────────────────────
class _LoanDetailSheet extends StatefulWidget {
  final Map<String, dynamic> loan;
  final String loanId;
  final NumberFormat fmt;

  const _LoanDetailSheet({
    required this.loan,
    required this.loanId,
    required this.fmt,
  });

  @override
  State<_LoanDetailSheet> createState() => _LoanDetailSheetState();
}

class _LoanDetailSheetState extends State<_LoanDetailSheet> {
  List<Map<String, dynamic>> _guarantors = [];
  bool _loadingGuarantors = true;

  @override
  void initState() {
    super.initState();
    _loadGuarantors();
  }

  Future<void> _loadGuarantors() async {
    final list = await FirebaseService.getLoanGuarantors(widget.loanId);
    if (mounted) {
      setState(() {
        _guarantors = list;
        _loadingGuarantors = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final fmt = widget.fmt;
    final amount = (loan['amount'] as num?)?.toInt() ?? 0;
    final farmerName = loan['memberName'] as String? ??
        loan['farmerName'] as String? ??
        'Member';
    final createdAt = loan['createdAt'];
    String dateStr = '—';
    if (createdAt is Timestamp) {
      dateStr = DateFormat('MMM d, yyyy – HH:mm').format(createdAt.toDate());
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Loan Details',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  StatusBadge(status: loan['status'] ?? '—'),
                ],
              ),
            ),
            const Divider(height: 20),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── Applicant ──────────────────────────────────────────
                  _section('Applicant'),
                  InfoRow(
                      icon: Icons.person_rounded,
                      label: 'Name',
                      value: farmerName),
                  InfoRow(
                      icon: Icons.tag_rounded,
                      label: 'Loan ID',
                      value: widget.loanId.toUpperCase()),
                  InfoRow(
                      icon: Icons.event_rounded,
                      label: 'Applied On',
                      value: dateStr),

                  // ── Loan Info ──────────────────────────────────────────
                  _section('Loan Information'),
                  InfoRow(
                      icon: Icons.attach_money_rounded,
                      label: 'Amount',
                      value: 'UGX ${fmt.format(amount)}'),
                  InfoRow(
                      icon: Icons.category_outlined,
                      label: 'Type',
                      value: loan['loanType'] ?? '—'),
                  InfoRow(
                      icon: Icons.grass_outlined,
                      label: 'Purpose',
                      value: loan['purpose'] ?? '—'),
                  InfoRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'Repayment Period',
                      value: loan['repaymentPeriod'] ?? '—'),
                  if ((loan['description'] as String?)?.isNotEmpty == true)
                    InfoRow(
                        icon: Icons.notes_rounded,
                        label: 'Description',
                        value: loan['description']),

                  // ── Collateral ─────────────────────────────────────────
                  _section('Collateral'),
                  InfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Type',
                      value: loan['collateralType'] ?? '—'),
                  InfoRow(
                      icon: Icons.notes_rounded,
                      label: 'Description',
                      value: loan['collateralDescription'] ?? '—'),
                  InfoRow(
                      icon: Icons.price_check_rounded,
                      label: 'Estimated Value',
                      value:
                          'UGX ${fmt.format((loan['collateralValue'] as num?)?.toInt() ?? 0)}'),

                  // ── Financial Info ─────────────────────────────────────
                  _section('Financial Information'),
                  InfoRow(
                      icon: Icons.work_outline_rounded,
                      label: 'Income Source',
                      value: loan['incomeSource'] ?? '—'),
                  InfoRow(
                      icon: Icons.trending_up_rounded,
                      label: 'Monthly Income',
                      value:
                          'UGX ${fmt.format((loan['monthlyIncome'] as num?)?.toInt() ?? 0)}'),
                  if ((loan['existingLoans'] as String?)?.isNotEmpty == true)
                    InfoRow(
                        icon: Icons.credit_card_outlined,
                        label: 'Existing Loans',
                        value: loan['existingLoans']),

                  // ── Next of Kin ────────────────────────────────────────
                  _section('Next of Kin'),
                  InfoRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Name',
                      value: loan['nextOfKinName'] ?? '—'),
                  InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: loan['nextOfKinPhone'] ?? '—'),
                  InfoRow(
                      icon: Icons.family_restroom_rounded,
                      label: 'Relationship',
                      value: loan['nextOfKinRelation'] ?? '—'),
                  InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: loan['nextOfKinAddress'] ?? '—'),

                  // ── Guarantors ─────────────────────────────────────────
                  _section('Guarantors'),
                  if (_loadingGuarantors)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2)),
                    )
                  else if (_guarantors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No guarantors recorded for this loan.',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ..._guarantors.map((g) => _GuarantorRow(g)),

                  // ── Admin Note ─────────────────────────────────────────
                  if ((loan['adminNote'] as String?)?.isNotEmpty == true) ...[
                    _section('Admin Note'),
                    InfoRow(
                        icon: Icons.comment_outlined,
                        label: 'Note',
                        value: loan['adminNote']),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppTheme.primary),
      ),
    );
  }
}

class _GuarantorRow extends StatelessWidget {
  final Map<String, dynamic> g;
  const _GuarantorRow(this.g);

  @override
  Widget build(BuildContext context) {
    final name = g['guarantorName'] as String? ?? '—';
    final phone = g['guarantorPhone'] as String? ?? '—';
    final memberNo = g['guarantorMemberNo'] as String? ?? '';
    final consent = g['consentStatus'] as String? ?? 'pending';

    Color consentColor;
    IconData consentIcon;
    switch (consent) {
      case 'accepted':
        consentColor = AppTheme.success;
        consentIcon = Icons.check_circle_rounded;
        break;
      case 'declined':
        consentColor = AppTheme.error;
        consentIcon = Icons.cancel_rounded;
        break;
      default:
        consentColor = AppTheme.warning;
        consentIcon = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary)),
                Text(phone,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary)),
                if (memberNo.isNotEmpty)
                  Text('Member #$memberNo',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          // Consent badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: consentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: consentColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(consentIcon, size: 12, color: consentColor),
                const SizedBox(width: 4),
                Text(
                  consent[0].toUpperCase() + consent.substring(1),
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: consentColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

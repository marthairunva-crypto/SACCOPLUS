import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/constants.dart';

/// 360° Loan View - Complete loan details with all activities
class Loan360Screen extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic> loanData;

  const Loan360Screen({
    super.key,
    required this.loanId,
    required this.loanData,
  });

  @override
  State<Loan360Screen> createState() => _Loan360ScreenState();
}

class _Loan360ScreenState extends State<Loan360Screen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = (widget.loanData['amount'] as num?)?.toInt() ?? 0;
    final status = widget.loanData['status'] as String? ?? '';
    final memberName = widget.loanData['farmerName'] as String? ?? 'Unknown';
    final purpose = widget.loanData['purpose'] as String? ?? '';

    // Status color
    Color statusColor = AppTheme.textSecondary;
    if (status == AppConstants.statusApproved) statusColor = AppTheme.success;
    if (status == AppConstants.statusPending) statusColor = AppTheme.warning;
    if (status == AppConstants.statusRejected) statusColor = AppTheme.error;
    if (status == AppConstants.statusPaid) statusColor = AppTheme.info;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Header
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppTheme.primary,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryDark, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(Icons.credit_card, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'UGX ${fmt.format(amount)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          memberName,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Repayments'),
                    Tab(text: 'Guarantors'),
                    Tab(text: 'Documents'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(loanId: widget.loanId, loanData: widget.loanData, fmt: fmt),
            _RepaymentsTab(loanId: widget.loanId, fmt: fmt),
            _GuarantorsTab(loanData: widget.loanData, fmt: fmt),
            _DocumentsTab(loanData: widget.loanData),
          ],
        ),
      ),
    );
  }
}

// ─── Sticky Tab Bar Delegate ──────────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1: OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final String loanId;
  final Map<String, dynamic> loanData;
  final NumberFormat fmt;

  const _OverviewTab({required this.loanId, required this.loanData, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final amount = (loanData['amount'] as num?)?.toInt() ?? 0;
    final totalRepaid = (loanData['totalRepaid'] as num?)?.toInt() ?? 0;
    final outstanding = amount - totalRepaid;
    final interestRate = (loanData['interestRate'] as num?)?.toDouble() ?? 0.0;
    final duration = (loanData['duration'] as num?)?.toInt() ?? 0;
    final purpose = loanData['purpose'] as String? ?? 'Not specified';
    final status = loanData['status'] as String? ?? '';
    final createdAt = (loanData['createdAt'] as Timestamp?)?.toDate();
    final approvedAt = (loanData['approvedAt'] as Timestamp?)?.toDate();
    final dueDate = (loanData['dueDate'] as Timestamp?)?.toDate();

    // Calculate progress
    final repaymentProgress = amount > 0 ? (totalRepaid / amount * 100).toInt() : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Financial Summary
        Text(
          'FINANCIAL SUMMARY',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Loan Amount',
                'UGX ${fmt.format(amount)}',
                Icons.credit_card,
                AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'Repaid',
                'UGX ${fmt.format(totalRepaid)}',
                Icons.check_circle,
                AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Outstanding',
                'UGX ${fmt.format(outstanding)}',
                Icons.pending,
                AppTheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'Interest Rate',
                '$interestRate%',
                Icons.percent,
                AppTheme.info,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Repayment Progress
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Repayment Progress',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: repaymentProgress / 100,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    repaymentProgress >= 100 ? AppTheme.success : AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$repaymentProgress% Complete',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Loan Details
        Text(
          'LOAN DETAILS',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        _infoCard([
          _infoRow('Purpose', purpose),
          _infoRow('Duration', '$duration months'),
          _infoRow('Status', status.toUpperCase()),
          if (createdAt != null)
            _infoRow('Applied', DateFormat('MMM d, yyyy').format(createdAt)),
          if (approvedAt != null)
            _infoRow('Approved', DateFormat('MMM d, yyyy').format(approvedAt)),
          if (dueDate != null)
            _infoRow('Due Date', DateFormat('MMM d, yyyy').format(dueDate)),
        ]),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2: REPAYMENTS
// ═══════════════════════════════════════════════════════════════════════════════
class _RepaymentsTab extends StatelessWidget {
  final String loanId;
  final NumberFormat fmt;

  const _RepaymentsTab({required this.loanId, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loan_repayments')
          .where('loanId', isEqualTo: loanId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final repayments = snapshot.data?.docs ?? [];

        if (repayments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No repayments yet',
                  style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: repayments.length,
          itemBuilder: (context, index) {
            final doc = repayments[index];
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] as num?)?.toInt() ?? 0;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final method = data['method'] as String? ?? 'Cash';
            final receiptNumber = data['receiptNumber'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check_circle, color: AppTheme.success, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UGX ${fmt.format(amount)}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payment via $method',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (receiptNumber.isNotEmpty)
                          Text(
                            'Receipt: $receiptNumber',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (timestamp != null)
                          Text(
                            DateFormat('MMM d, yyyy • HH:mm').format(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3: GUARANTORS
// ═══════════════════════════════════════════════════════════════════════════════
class _GuarantorsTab extends StatelessWidget {
  final Map<String, dynamic> loanData;
  final NumberFormat fmt;

  const _GuarantorsTab({required this.loanData, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final guarantors = (loanData['guarantors'] as List<dynamic>?) ?? [];

    if (guarantors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No guarantors',
              style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guarantors.length,
      itemBuilder: (context, index) {
        final guarantor = guarantors[index] as Map<String, dynamic>;
        final name = guarantor['name'] as String? ?? 'Unknown';
        final phone = guarantor['phone'] as String? ?? '';
        final relationship = guarantor['relationship'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'G',
                  style: GoogleFonts.poppins(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    if (relationship.isNotEmpty)
                      Text(
                        relationship,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4: DOCUMENTS
// ═══════════════════════════════════════════════════════════════════════════════
class _DocumentsTab extends StatelessWidget {
  final Map<String, dynamic> loanData;

  const _DocumentsTab({required this.loanData});

  @override
  Widget build(BuildContext context) {
    final documents = <Map<String, String>>[];

    // Check for various document fields
    if (loanData['businessPlanUrl'] != null && loanData['businessPlanUrl'].toString().isNotEmpty) {
      documents.add({'name': 'Business Plan', 'url': loanData['businessPlanUrl'].toString()});
    }
    if (loanData['collateralPhotoUrl'] != null && loanData['collateralPhotoUrl'].toString().isNotEmpty) {
      documents.add({'name': 'Collateral Photo', 'url': loanData['collateralPhotoUrl'].toString()});
    }

    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No documents attached',
              style: GoogleFonts.poppins(fontSize: 16, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['name']!,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Image.network(
                  doc['url']!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

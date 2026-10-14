import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';

class LoanStatusScreen extends StatefulWidget {
  final bool embedded;
  const LoanStatusScreen({super.key, this.embedded = false});

  @override
  State<LoanStatusScreen> createState() => _LoanStatusScreenState();
}

class _LoanStatusScreenState extends State<LoanStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final fmt = NumberFormat('#,###', 'en_US');

  List<Map<String, dynamic>> _loans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = _loans.isEmpty);
    final memberId = FirebaseService.sessionUid;
    final loans = await FirebaseService.getFarmerLoansOnce(memberId);
    if (!mounted) return;
    setState(() {
      _loans = loans.map((d) {
        final ts = d['createdAt'];
        String dateStr = '—';
        if (ts is Timestamp) {
          dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
        }
        return {...d, 'dateStr': dateStr};
      }).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      controller: _tabs,
      isScrollable: true,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      indicatorColor: AppTheme.accent,
      indicatorWeight: 3,
      labelStyle:
          GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
      tabs: const [
        Tab(text: 'All'),
        Tab(text: 'Pending'),
        Tab(text: 'Approved'),
        Tab(text: 'Paid'),
        Tab(text: 'Rejected'),
      ],
    );

    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : Builder(builder: (context) {
            List<Map<String, dynamic>> filter(String status) => status == 'All'
                ? _loans
                : _loans.where((l) => l['status'] == status).toList();

            return TabBarView(
              controller: _tabs,
              children: [
                _LoanList(loans: filter('All'), fmt: fmt),
                _LoanList(loans: filter(AppConstants.statusPending), fmt: fmt),
                  _LoanList(loans: filter(AppConstants.statusApproved), fmt: fmt),
                  _LoanList(loans: filter(AppConstants.statusPaid), fmt: fmt),
                  _LoanList(loans: filter(AppConstants.statusRejected), fmt: fmt),
                ],
              );
            });

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: AppTheme.primary,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'My Loans',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => setState(() => _load()),
            ),
          ],
          bottom: tabBar,
        ),
        body: body,
      );
    }

    return FarmerScaffold(
      title: 'My Loans',
      bottom: tabBar,
      body: body,
    );
  }
}

class _LoanList extends StatelessWidget {
  final List<Map<String, dynamic>> loans;
  final NumberFormat fmt;

  const _LoanList({required this.loans, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return const EmptyState(
          message: 'No loans found in this category.',
          icon: Icons.account_balance_wallet_outlined);
    }
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (_, i) {
        final l = loans[i];
        return GestureDetector(
          onTap: () => _showDetail(context, l),
          child: LoanListTile(
            loanId: l['id'] ?? '',
            amount: 'UGX ${fmt.format((l['amount'] as num?)?.toInt() ?? 0)}',
            purpose: l['purpose'] ?? '—',
            date: l['dateStr'] ?? '—',
            status: l['status'] ?? '—',
          ),
        );
      },
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> loan) {
    final fmt = NumberFormat('#,###', 'en_US');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Loan Details',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 17)),
                StatusBadge(status: loan['status'] ?? '—'),
              ],
            ),
            const SizedBox(height: 16),
            InfoRow(
                icon: Icons.attach_money_rounded,
                label: 'Amount',
                value:
                    'UGX ${fmt.format((loan['amount'] as num?)?.toInt() ?? 0)}'),
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
            InfoRow(
                icon: Icons.event_rounded,
                label: 'Applied On',
                value: loan['dateStr'] ?? '—'),
            if ((loan['adminNote'] as String?)?.isNotEmpty == true)
              InfoRow(
                  icon: Icons.comment_outlined,
                  label: 'Admin Note',
                  value: loan['adminNote']),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

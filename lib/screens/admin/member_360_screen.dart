import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../services/member_statement_service.dart';
import 'admin_statement_preview.dart';
import 'statement_date_selector.dart';

class Member360Screen extends StatefulWidget {
  final String? memberId;
  /// Called when the statement button is clicked — receives member info
  /// so the dashboard can display the date selector in its content panel.
  /// If null, falls back to pushing a new route (standalone use).
  final void Function(String memberId, String memberName, Map<String, dynamic> memberData)? onShowStatement;

  const Member360Screen({
    super.key,
    this.memberId,
    this.onShowStatement,
  });

  @override
  State<Member360Screen> createState() => _Member360ScreenState();
}

class _Member360ScreenState extends State<Member360Screen>
    with SingleTickerProviderStateMixin {
  // ── Responsive breakpoints ────────────────────────────────────────────────
  static const double _maxContentWidth = 1400;
  static const double _phoneBreakpoint = 600;
  static const double _wideBreakpoint  = 900;
  static const double _shortHeight     = 500;

  late final TabController _tabController;
  String? _selectedMemberId;
  Map<String, dynamic>? _memberData;
  bool _isLoading = false;
  List<Map<String, dynamic>> _members = [];

  // Queries are created ONCE per member load (not on every rebuild)
  Future<List<Map<String, dynamic>>>? _loansFuture;

  /// Savings + wallet are ONE account in a SACCO. Both come from the same
  /// ledger the statement PDF uses, so the screen and the PDF always agree.
  Future<List<Map<String, dynamic>>>? _savingsRowsFuture;
  Future<List<Map<String, dynamic>>>? _sharesRowsFuture;
  Future<List<Map<String, dynamic>>>? _transactionsFuture;
  Stream<QuerySnapshot>? _savingsActivityStream;
  Stream<QuerySnapshot>? _repaymentsStream;

  final _currencyFormat =
      NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  Size get _screen => MediaQuery.sizeOf(context);
  bool get _isNarrow => _screen.width < _phoneBreakpoint;
  bool get _isWide => _screen.width >= _wideBreakpoint;
  bool get _isShort => _screen.height < _shortHeight;
  double get _pad => _isNarrow ? 12 : 16;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _selectedMemberId = widget.memberId;
    _loadMembers();
    if (_selectedMemberId != null) {
      _loadMemberData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  /// Centers content and caps its width on large screens.
  /// On large screens, constrain content width so it doesn't stretch too wide.
  Widget _constrain(Widget child) => child;

  double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

  DateTime _dateOf(dynamic v) =>
      v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

  String _nameOf(Map<String, dynamic> m) =>
      (m['name'] ?? m['fullName'] ?? '').toString().trim();

  String _val(String key, [String fallback = 'N/A']) {
    final v = _memberData?[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  /// Savings and wallet are the same money in a SACCO → one combined figure.
  double get _combinedSavings =>
      _num(_memberData?['savingsBalance']) + _num(_memberData?['walletBalance']);

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ));
  }

  BoxDecoration _cardDecoration({double blur = 10}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: blur,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadMembers() async {
    try {
      final members = await FirebaseService.getAllFarmersOnce();
      if (!mounted) return;
      setState(() {
        _members = members;
        _members.sort((a, b) => _nameOf(a).compareTo(_nameOf(b)));
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
  }

  Future<void> _loadMemberData() async {
    final id = _selectedMemberId;
    if (id == null) return;

    setState(() => _isLoading = true);

    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(id)
          .get();

      // Ignore stale responses if the admin picked another member meanwhile
      if (!mounted || id != _selectedMemberId) return;

      if (!memberDoc.exists) {
        setState(() => _isLoading = false);
        _snack('Member not found', color: AppTheme.error);
        return;
      }

      final data = <String, dynamic>{'id': memberDoc.id, ...memberDoc.data()!};
      setState(() {
        _memberData = data;
        _prepareMemberQueries(id, _nameOf(data));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('Error loading member: $e', color: AppTheme.error);
    }
  }

  void _prepareMemberQueries(String id, String name) {
    final db = FirebaseFirestore.instance;
    final tenant = FirebaseService.sessionTenantId;

    // Savings + wallet: one merged ledger (same loader as the PDF statement)
    _savingsRowsFuture =
        MemberStatementService.loadLedger(id).then((ledger) => ledger
            .map((e) => <String, dynamic>{
                  'createdAt': Timestamp.fromDate(e.date),
                  'amount': e.amount,
                  'description': e.description,
                  'debit': e.isDebit,
                })
            .toList());

    _sharesRowsFuture = db
        .collection('saccoplus-shares')
        .where('farmerId', isEqualTo: id)
        .where('tenantId', isEqualTo: tenant)
        .get()
        .then((snap) => snap.docs
            .map((d) => Map<String, dynamic>.from(d.data()))
            .toList());

    _transactionsFuture =
        _combineTransactions(_savingsRowsFuture!, _sharesRowsFuture!);
    _loansFuture = _getMemberLoans(id, name);

    _savingsActivityStream = db
        .collection('saccoplus-savings-transactions')
        .where('memberId', isEqualTo: id)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();

    _repaymentsStream = db
        .collection('saccoplus-repayments')
        .where('memberId', isEqualTo: id)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> _getMemberLoans(
      String memberId, String memberName) async {
    try {
      final allLoans = await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .get();

      final memberNameLower = memberName.toLowerCase();
      final memberLoans = <Map<String, dynamic>>[];

      for (final doc in allLoans.docs) {
        final data = doc.data();
        final loanMemberName =
            (data['memberName'] ?? '').toString().toLowerCase();

        final belongsToMember = data['memberId'] == memberId ||
            data['farmerId'] == memberId ||
            (memberNameLower.isNotEmpty && loanMemberName == memberNameLower);

        if (belongsToMember) {
          memberLoans.add({'id': doc.id, ...data});
        }
      }

      memberLoans.sort(
          (a, b) => _dateOf(b['createdAt']).compareTo(_dateOf(a['createdAt'])));
      return memberLoans;
    } catch (e) {
      debugPrint('Error getting member loans: $e');
      return [];
    }
  }

  /// Merges savings (incl. wallet) + shares into one list, re-using the same
  /// futures as the Savings and Shares tabs so all three always agree.
  Future<List<Map<String, dynamic>>> _combineTransactions(
      Future<List<Map<String, dynamic>>> savings,
      Future<List<Map<String, dynamic>>> shares) async {
    final results = await Future.wait([savings, shares]);
    final all = <Map<String, dynamic>>[];

    for (final row in results[0]) {
      final debit = row['debit'] == true;
      all.add({
        'createdAt': row['createdAt'],
        'amount': row['amount'],
        'description': '💰 ${row['description'] ?? 'Savings Deposit'}',
        'icon': Icons.savings,
        'color': debit ? Colors.red : Colors.green,
        'debit': debit,
      });
    }

    for (final row in results[1]) {
      all.add({
        'createdAt': row['createdAt'],
        'amount': row['amount'],
        'description': '📊 ${row['description'] ?? 'Shares Purchase'}',
        'icon': Icons.pie_chart,
        'color': Colors.blue,
        'debit': false,
      });
    }

    all.sort(
        (a, b) => _dateOf(b['createdAt']).compareTo(_dateOf(a['createdAt'])));
    return all;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _printMemberStatement() {
    if (_memberData == null || _selectedMemberId == null) return;

    final memberName = _nameOf(_memberData!).isEmpty ? 'Member' : _nameOf(_memberData!);

    // If embedded in dashboard, show date selector. Otherwise navigate.
    if (widget.onShowStatement != null) {
      widget.onShowStatement!(_selectedMemberId!, memberName, _memberData!);
    } else {
      // Standalone: navigate to date selector screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text('Generate Statement',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
            ),
            body: StatementDateSelector(
              memberId: _selectedMemberId!,
              memberName: memberName,
              memberData: _memberData!,
              onStatementGenerated: (result, name, from, to) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminStatementPreview(
                      pdfBytes: result.bytes,
                      filename: result.filename,
                      memberName: name,
                      from: from,
                      to: to,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showEditMemberDialog() async {
    if (_memberData == null || _selectedMemberId == null) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditMemberDialog(
        memberId: _selectedMemberId!,
        data: _memberData!,
      ),
    );

    if (saved == true) {
      _snack('Member information updated successfully!',
          color: AppTheme.success);
      _loadMemberData();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final narrow = _isNarrow;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Member 360° View',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: narrow ? 16 : 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          if (_memberData != null) ...[
            if (_isWide)
              TextButton.icon(
                onPressed: _printMemberStatement,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text('Statement',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                style:
                    TextButton.styleFrom(foregroundColor: AppTheme.primary),
              )
            else
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Download Account Statement',
                onPressed: _printMemberStatement,
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _loadMemberData,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Member selector
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(
                horizontal: _pad, vertical: _isShort || narrow ? 8 : 14),
            child: _constrain(_buildMemberSelector()),
          ),

          if (_memberData != null) ...[
            _buildMemberHeader(),

            // Tabs
            Container(
              color: Colors.white,
              child: _constrain(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                  indicatorColor: AppTheme.primary,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Savings'),
                    Tab(text: 'Shares'),
                    Tab(text: 'Loans'),
                    Tab(text: 'Transactions'),
                    Tab(text: 'Documents'),
                  ],
                ),
              ),
            ),

            // Tab content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _constrain(
                      TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildSavingsTab(),
                          _buildSharesTab(),
                          _buildLoansTab(),
                          _buildTransactionsTab(),
                          _buildDocumentsTab(),
                        ],
                      ),
                    ),
            ),
          ] else
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessageState(
                      icon: Icons.person_search_rounded,
                      title: 'Select a member to view details',
                      iconSize: 80,
                    ),
            ),
        ],
      ),
    );
  }

  // ── Reusable states ───────────────────────────────────────────────────────

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    double iconSize = 64,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor ?? Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 15, color: titleColor ?? Colors.grey),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, Object error) {
    return _buildMessageState(
      icon: Icons.error_outline,
      iconColor: Colors.red.shade300,
      title: title,
      titleColor: Colors.red,
      subtitle: '$error',
    );
  }

  // ── Member selector ───────────────────────────────────────────────────────

  Widget _buildMemberSelector() {
    final compact = _isNarrow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact && !_isShort) ...[
          Text(
            'Search Member',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(builder: (context, constraints) {
          final fieldWidth = constraints.maxWidth;
          final maxListHeight =
              (_screen.height * 0.4).clamp(160.0, 300.0).toDouble();

          return Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (m) {
              final n = _nameOf(m);
              return n.isEmpty ? 'Unknown' : n;
            },
            optionsBuilder: (TextEditingValue value) {
              if (value.text.isEmpty) {
                return const Iterable<Map<String, dynamic>>.empty();
              }
              final query = value.text.toLowerCase();
              return _members.where((member) {
                if (member['id'] == null) return false;
                final name = _nameOf(member).toLowerCase();
                final phone = (member['phone'] ?? '').toString();
                final accountNumber = (member['accountNumber'] ?? '').toString();
                final memberNumber = (member['memberNumber'] ?? '').toString();
                return name.contains(query) ||
                    phone.contains(query) ||
                    accountNumber.contains(query) ||
                    memberNumber.contains(query);
              }).take(20);
            },
            onSelected: (Map<String, dynamic> member) {
              FocusScope.of(context).unfocus();
              setState(() {
                _selectedMemberId = member['id'];
                _memberData = null;
              });
              _loadMemberData();
            },
            fieldViewBuilder:
                (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: compact
                      ? 'Search name, phone, account...'
                      : 'Search name, phone, account or member no...',
                  hintMaxLines: 1,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  isDense: compact,
                ),
                onEditingComplete: onEditingComplete,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: maxListHeight, maxWidth: fieldWidth),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final member = options.elementAt(index);
                        final name = _nameOf(member);
                        final accountNum =
                            (member['accountNumber'] ?? '').toString();
                        final phone =
                            (member['phone'] ?? '').toString().isEmpty
                                ? 'No phone'
                                : member['phone'].toString();
                        final subtitle = accountNum.isNotEmpty
                            ? '$phone  •  Acc: $accountNum'
                            : phone;

                        return ListTile(
                          dense: compact,
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primary.withOpacity(0.1),
                            child: Text(
                              name.isEmpty ? '?' : name[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary),
                            ),
                          ),
                          title: Text(
                            name.isEmpty ? 'Unknown' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          onTap: () => onSelected(member),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  // ── Member header ─────────────────────────────────────────────────────────

  Widget _buildMemberHeader() {
    final data         = _memberData!;
    final memberName   = _nameOf(data).isEmpty ? 'Unknown' : _nameOf(data);
    final initial      = memberName[0].toUpperCase();
    final accountNumber= _val('accountNumber');
    final memberNumber = _val('memberNumber');
    final phone        = _val('phone', 'No phone');
    final status       = _val('status', 'active');
    final isActive     = status.toLowerCase() == 'active';
    final photoUrl     = (data['profileImage'] ?? data['photoUrl'] ?? '') as String;

    // ── Avatar widget (photo → asset fallback → initial) ─────────────────
    Widget avatar(double radius) {
      if (photoUrl.isNotEmpty) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(photoUrl),
          onBackgroundImageError: (_, __) {},
        );
      }
      // Use the asset avatar when no photo
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        child: ClipOval(
          child: Image.asset(
            'assets/images/avatar.png',
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(
              initial,
              style: GoogleFonts.poppins(
                  fontSize: radius * 0.75,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
      );
    }

    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.shade400
            : Colors.orange.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildHeaderChip(Icons.phone, phone),
        _buildHeaderChip(Icons.calendar_today,
            'Joined ${_formatDate(data['createdAt'])}'),
      ],
    );

    final decoration = BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D2B6B), Color(0xFF1A3F8F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0D2B6B).withValues(alpha: 0.3),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );

    // ── Slim landscape header ─────────────────────────────────────────────
    if (_isShort) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: decoration,
        child: Row(children: [
          avatar(20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(memberName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('Acc: $accountNumber  •  Member: $memberNumber',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70)),
            ],
          )),
          const SizedBox(width: 8),
          statusBadge,
        ]),
      );
    }

    // ── Mobile portrait header ────────────────────────────────────────────
    if (_isNarrow) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            avatar(28),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(memberName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('Acc: $accountNumber', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.white70)),
                Text('Member: $memberNumber', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.white70)),
              ],
            )),
            statusBadge,
          ]),
          const SizedBox(height: 10),
          chips,
        ]),
      );
    }

    // ── Desktop / tablet wide header — fills full width ──────────────────
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: decoration,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Avatar
        avatar(44),
        const SizedBox(width: 20),

        // Name + meta
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(memberName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              'Account: $accountNumber   •   Member: $memberNumber',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.white60,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            chips,
          ],
        )),

        const SizedBox(width: 16),
        statusBadge,
      ]),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Gradient banner at the top of Savings / Shares / Loans tabs.
  Widget _buildBalanceBanner({
    required String title,
    required String amount,
    required IconData icon,
    required List<Color> colors,
    String? footnote,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(_pad, 16, _pad, 12),
      padding: EdgeInsets.all(_isNarrow ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: _isNarrow ? 24 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (footnote != null)
                  Text(
                    footnote,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: _isNarrow ? 40 : 48, color: Colors.white24),
        ],
      ),
    );
  }

  // ── Overview tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final sharesBalance = _num(_memberData!['sharesBalance']);

    final cards = <Widget>[
      _buildSummaryCard('Total Savings', _currencyFormat.format(_combinedSavings),
          Icons.savings, Colors.blue),
      _buildSummaryCard('Total Shares', _currencyFormat.format(sharesBalance),
          Icons.pie_chart, Colors.green),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _loansFuture,
        builder: (context, snapshot) {
          final loans = snapshot.data ?? [];
          // Use same priority as statement: totalOutstanding > remainingBalance > principalOutstanding
          final total = loans.fold<double>(0, (sum, loan) {
            double outstanding = _num(loan['totalOutstanding']);
            if (outstanding == 0) outstanding = _num(loan['remainingBalance']);
            if (outstanding == 0) outstanding = _num(loan['principalOutstanding']);
            return sum + outstanding;
          });
          return _buildSummaryCard('Active Loans', _currencyFormat.format(total),
              Icons.account_balance, Colors.orange);
        },
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(_pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Financial Summary'),

          // 3 across on wide, 2 on tablets, 1 on small phones
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 700 ? 3 : (c.maxWidth >= 420 ? 2 : 1);
            final w = (c.maxWidth - 12 * (cols - 1)) / cols;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final card in cards) SizedBox(width: w, child: card),
              ],
            );
          }),

          const SizedBox(height: 24),

          // Wide: details + activity side by side. Otherwise stacked.
          if (_isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Personal Information'),
                      _buildInfoCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Recent Activity'),
                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildSectionTitle('Personal Information'),
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('Recent Activity'),
            _buildRecentActivity(),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Savings / Shares tabs (shared builder) ────────────────────────────────

  Widget _buildSavingsTab() => _buildLedgerTab(
        future: _savingsRowsFuture,
        memberBalance: _combinedSavings,
        bannerTitle: 'Total Savings',
        icon: Icons.savings,
        emptyIcon: Icons.savings_outlined,
        colors: const [Color(0xFF4A90E2), Color(0xFF357ABD)],
        entityLabel: 'savings',
        defaultDescription: 'Savings Deposit',
        tileColor: Colors.green,
      );

  Widget _buildSharesTab() => _buildLedgerTab(
        future: _sharesRowsFuture,
        memberBalance: _num(_memberData!['sharesBalance']),
        bannerTitle: 'Total Shares Value',
        icon: Icons.pie_chart,
        emptyIcon: Icons.pie_chart_outline,
        colors: const [Color(0xFF10B981), Color(0xFF059669)],
        entityLabel: 'shares',
        defaultDescription: 'Share Purchase',
        tileColor: Colors.blue,
      );

  Widget _buildLedgerTab({
    required Future<List<Map<String, dynamic>>>? future,
    required double memberBalance,
    required String bannerTitle,
    required IconData icon,
    required IconData emptyIcon,
    required List<Color> colors,
    required String entityLabel,
    required String defaultDescription,
    required Color tileColor,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error loading $entityLabel', snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = List<Map<String, dynamic>>.from(snapshot.data!)
          ..sort((a, b) =>
              _dateOf(b['createdAt']).compareTo(_dateOf(a['createdAt'])));

        // Credits add, debits (withdrawals) subtract
        final transactionsTotal = rows.fold<double>(
            0,
            (sum, r) =>
                sum + (r['debit'] == true ? -1 : 1) * _num(r['amount']));

        // Prefer the balance stored on the member; fall back to the ledger sum
        final displayBalance =
            memberBalance > 0 ? memberBalance : transactionsTotal;

        return Column(
          children: [
            _buildBalanceBanner(
              title: bannerTitle,
              amount: _currencyFormat.format(displayBalance),
              icon: icon,
              colors: colors,
              footnote: rows.isNotEmpty ? '${rows.length} transactions' : null,
            ),
            if (rows.isEmpty)
              Expanded(
                child: _buildMessageState(
                  icon: emptyIcon,
                  title: 'No $entityLabel transactions found',
                  subtitle:
                      'Balance from member: ${_currencyFormat.format(displayBalance)}',
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(_pad, 4, _pad, 16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final debit = row['debit'] == true;
                    return _buildTransactionTile(
                      row['createdAt'],
                      row['amount'],
                      (row['description'] ?? defaultDescription).toString(),
                      icon,
                      debit ? Colors.red : tileColor,
                      debit: debit,
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Loans tab ─────────────────────────────────────────────────────────────

  Widget _buildLoansTab() {
    final loanBalance = _num(_memberData!['loanBalance']);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loansFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final loans = snapshot.data!;
        // Use same priority as statement: totalOutstanding > remainingBalance > principalOutstanding
        final actualOutstanding = loans.fold<double>(0, (sum, loan) {
          double outstanding = _num(loan['totalOutstanding']);
          if (outstanding == 0) outstanding = _num(loan['remainingBalance']);
          if (outstanding == 0) outstanding = _num(loan['principalOutstanding']);
          return sum + outstanding;
        });
        final displayBalance =
            actualOutstanding > 0 ? actualOutstanding : loanBalance;

        return Column(
          children: [
            _buildBalanceBanner(
              title: 'Outstanding Loan Balance',
              amount: _currencyFormat.format(displayBalance),
              icon: Icons.account_balance,
              colors: const [Color(0xFFEF4444), Color(0xFFDC2626)],
              footnote: loans.isNotEmpty ? '${loans.length} loan(s)' : null,
            ),
            if (loans.isEmpty)
              Expanded(
                child: _buildMessageState(
                  icon: Icons.account_balance_outlined,
                  title: 'No loan records',
                  subtitle: loanBalance > 0
                      ? 'Outstanding: ${_currencyFormat.format(loanBalance)}'
                      : null,
                ),
              )
            else
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final twoCols = c.maxWidth >= 800;
                  final inner = c.maxWidth - _pad * 2;
                  final cardWidth = twoCols ? (inner - 12) / 2 : inner;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(_pad, 4, _pad, 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final loan in loans)
                          SizedBox(width: cardWidth, child: _buildLoanCard(loan)),
                      ],
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  // ── Transactions tab ──────────────────────────────────────────────────────

  Widget _buildTransactionsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _transactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState('Error loading transactions', snapshot.error!);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data!;

        if (transactions.isEmpty) {
          return _buildMessageState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(_pad),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];
            return _buildTransactionTile(
              txn['createdAt'],
              txn['amount'],
              txn['description'],
              txn['icon'],
              txn['color'],
              debit: txn['debit'] == true,
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    return _buildMessageState(
      icon: Icons.folder_outlined,
      title: 'KYC documents, contracts, and attachments',
    );
  }

  // ── Cards & rows ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(_isNarrow ? 14 : 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: _isNarrow ? 16 : 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final status = _val('status', 'active');
    final kyc = _val('kycStatus', 'pending');
    final name = _nameOf(_memberData!);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_isNarrow ? 16 : 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Member Details',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _showEditMemberDialog,
                tooltip: 'Edit Member',
                color: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),

          _buildDetailRow('Member ID', _val('memberId')),
          _buildDetailRow('Account Number', _val('accountNumber')),
          _buildDetailRow('Member Number', _val('memberNumber')),
          const Divider(height: 24),

          _buildDetailRow('Full Name', name.isEmpty ? 'N/A' : name, bold: true),
          _buildDetailRow('Gender', _val('gender')),
          _buildDetailRow('Phone', _val('phone')),
          _buildDetailRow('National ID', _val('nationalId')),
          _buildDetailRow('Village', _val('village')),
          _buildDetailRow('District', _val('district')),
          const Divider(height: 24),

          _buildDetailRow('Member Type', _val('memberType', 'Individual')),
          _buildDetailRow('Branch', _val('branch', 'Main Branch')),
          _buildDetailRow('Manager', _val('manager')),
          _buildDetailRow('Group', _val('group')),
          const Divider(height: 24),

          _buildDetailRow('Next of Kin', _val('nextOfKin')),
          _buildDetailRow('Next of Kin Phone', _val('nextOfKinPhone')),
          const Divider(height: 24),

          _buildDetailRow('Status', status,
              valueWidget: _buildStatusBadge(status)),
          _buildDetailRow('KYC Status', kyc, valueWidget: _buildKycBadge(kyc)),
          _buildDetailRow('Joined Date', _formatDate(_memberData!['createdAt'])),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool bold = false, Widget? valueWidget}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: valueWidget != null
                ? Align(alignment: Alignment.centerLeft, child: valueWidget)
                : Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildKycBadge(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: isError ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent activity ───────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: _savingsActivityStream,
      builder: (context, savingsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _repaymentsStream,
          builder: (context, repaymentsSnapshot) {
            var activities = <Map<String, dynamic>>[];

            if (savingsSnapshot.hasData) {
              for (final doc in savingsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                activities.add({
                  'title': 'Savings Deposit',
                  'amount': _num(data['amount']),
                  'date': data['createdAt'],
                  'icon': Icons.savings,
                  'color': Colors.green,
                });
              }
            }

            if (repaymentsSnapshot.hasData) {
              for (final doc in repaymentsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                activities.add({
                  'title': 'Loan Repayment',
                  'amount': _num(data['amount']),
                  'date': data['createdAt'],
                  'icon': Icons.payment,
                  'color': Colors.orange,
                });
              }
            }

            activities.sort(
                (a, b) => _dateOf(b['date']).compareTo(_dateOf(a['date'])));
            activities = activities.take(5).toList();

            if (activities.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: GoogleFonts.poppins(
                          color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  for (int i = 0; i < activities.length; i++) ...[
                    if (i > 0) const Divider(),
                    _buildActivityItem(
                      activities[i]['title'],
                      _currencyFormat.format(activities[i]['amount']),
                      activities[i]['date'] is Timestamp
                          ? _getTimeAgo(
                              (activities[i]['date'] as Timestamp).toDate())
                          : 'Unknown',
                      activities[i]['icon'],
                      activities[i]['color'],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getTimeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildActivityItem(
      String title, String amount, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
                Text(time,
                    style:
                        GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(dynamic timestamp, dynamic amount,
      String description, IconData icon, Color color,
      {bool debit = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(_isNarrow ? 12 : 16),
      decoration: _cardDecoration(blur: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  _formatDate(timestamp),
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${debit ? '-' : ''}${_currencyFormat.format(_num(amount))}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final status = (loan['status'] ?? 'pending').toString();
    final statusColor = status == 'paid' || status == 'cleared'
        ? Colors.green
        : status == 'active' || status == 'approved'
            ? Colors.blue
            : status == 'overdue'
                ? Colors.red
                : Colors.orange;

    final amount = _num(loan['amount']);
    // Use same priority as statement: totalOutstanding > remainingBalance > principalOutstanding
    double principalOutstanding = _num(loan['totalOutstanding']);
    if (principalOutstanding == 0) principalOutstanding = _num(loan['remainingBalance']);
    if (principalOutstanding == 0) principalOutstanding = _num(loan['principalOutstanding']);
    
    final outstandingDays = _num(loan['outstandingDays']).toInt();
    final referenceNumber = (loan['referenceNumber'] ?? 'N/A').toString();
    final loanProduct = (loan['loanProduct'] ?? 'General Loan').toString();
    final interestRate = _num(loan['interestRate']);
    final durationMonths = _num(loan['durationMonths']).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(blur: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loanProduct,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: $referenceNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Loan Amount', _currencyFormat.format(amount)),
          _buildInfoRow('Principal Outstanding',
              _currencyFormat.format(principalOutstanding)),
          if (outstandingDays > 0)
            _buildInfoRow('Days Overdue', '$outstandingDays days',
                isError: true),
          if (interestRate > 0) _buildInfoRow('Interest Rate', '$interestRate%'),
          if (durationMonths > 0)
            _buildInfoRow('Duration', '$durationMonths months'),
          _buildInfoRow('Applied', _formatDate(loan['createdAt'])),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    return 'N/A';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit dialog — its own widget so controllers are disposed properly and the
// Save button can show a saving state.
// ─────────────────────────────────────────────────────────────────────────────

class _EditMemberDialog extends StatefulWidget {
  final String memberId;
  final Map<String, dynamic> data;

  const _EditMemberDialog({required this.memberId, required this.data});

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _nin;
  late final TextEditingController _village;
  late final TextEditingController _district;
  late final TextEditingController _kin;
  late final TextEditingController _kinPhone;
  bool _saving = false;

  String _initial(String key, [String? fallbackKey]) =>
      (widget.data[key] ?? (fallbackKey != null ? widget.data[fallbackKey] : null) ?? '')
          .toString();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _initial('name', 'fullName'));
    _phone = TextEditingController(text: _initial('phone'));
    _nin = TextEditingController(text: _initial('nationalId'));
    _village = TextEditingController(text: _initial('village'));
    _district = TextEditingController(text: _initial('district'));
    _kin = TextEditingController(text: _initial('nextOfKin'));
    _kinPhone = TextEditingController(text: _initial('nextOfKinPhone'));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nin.dispose();
    _village.dispose();
    _district.dispose();
    _kin.dispose();
    _kinPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(widget.memberId)
          .update({
        'name': _name.text.trim(),
        'fullName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'nationalId': _nin.text.trim(),
        'village': _village.text.trim(),
        'district': _district.text.trim(),
        'nextOfKin': _kin.text.trim(),
        'nextOfKinPhone': _kinPhone.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating member: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  InputDecoration _decoration(String label, IconData icon,
      {String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // 16px dialog inset + 24px content padding on each side
    final contentWidth = math.min(500.0, screenWidth - 80);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          const Icon(Icons.edit, color: AppTheme.primary),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Edit Member Information',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Full Name', Icons.person),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Phone Number', Icons.phone),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nin,
                  maxLength: 14,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('National ID (NIN)', Icons.badge,
                      helper: 'Must be exactly 14 characters'),
                  validator: (v) {
                    if (v != null &&
                        v.trim().isNotEmpty &&
                        v.trim().length != 14) {
                      return 'NIN must be exactly 14 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _village,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Village', Icons.location_on),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _district,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('District', Icons.map),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kin,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Next of Kin', Icons.people),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _kinPhone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration:
                      _decoration('Next of Kin Phone', Icons.phone_android),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Save Changes',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
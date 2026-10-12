import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../services/till_service.dart';
import '../../services/loan_disbursement_service.dart';
import '../../models/till_entry.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/success_dialog.dart';

/// Admin screen to create and disburse loans to members
class CreateLoanScreen extends StatefulWidget {
  const CreateLoanScreen({super.key});

  @override
  State<CreateLoanScreen> createState() => _CreateLoanScreenState();
}

class _CreateLoanScreenState extends State<CreateLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _interestRateController = TextEditingController(text: '15');
  final _durationController = TextEditingController(text: '12');
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedMemberId;
  String? _selectedMemberName;
  String? _selectedMemberPhone;
  String? _selectedMemberAccount;
  String _loanType = 'personal';
  String _paymentFrequency = 'monthly';
  String _interestMethod = 'flat';
  bool _isLoading = false;
  bool _autoApprove = true;

  // Existing-loan guard: a member with an open loan cannot get a new one.
  Map<String, dynamic>? _existingLoan;
  bool _checkingLoan = false;

  /// Loans with these statuses are finished and do NOT block a new loan.
  /// Add/remove values here to match the statuses your app really uses.
  static const _closedLoanStatuses = {
    'rejected',
    'declined',
    'cancelled',
    'canceled',
    'paid',
    'fully_paid',
    'completed',
    'closed',
    'cleared',
    'settled',
  };

  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  // ── Responsive breakpoints (measured on the space the page actually gets,
  //    i.e. AFTER the sidebar, because we use LayoutBuilder) ──
  static const double _compactBreakpoint = 600; // < this  -> phone
  static const double _wideBreakpoint = 900; // >= this -> two columns
  static const double _tripleBreakpoint = 1280; // >= this -> three columns
  static const double _maxWidthWide = 2000; // only caps ultra-wide monitors
  static const double _maxWidthNarrow = 720; // content cap for single column
  static const double _columnGap = 20;

  static const _radius = 14.0;

  @override
  void dispose() {
    _amountController.dispose();
    _interestRateController.dispose();
    _durationController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: canPop
          ? AppBar(
              title: Text(
                'Create & Disburse Loan',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final wide = w >= _wideBreakpoint;
              final hPad = w < 360 ? 12.0 : (w < _compactBreakpoint ? 16.0 : (wide ? 28.0 : 24.0));
              final vPad = wide ? 28.0 : 16.0;
              final maxW = wide ? _maxWidthWide : _maxWidthNarrow;

              // Scroll view spans the full width so the scrollbar sits at the
              // window edge; content is centred and capped inside it.
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad + 8),
                      child: Form(
                        key: _formKey,
                        child: wide
                            ? _buildWideBody(triple: w >= _tripleBreakpoint)
                            : _buildNarrowBody(compact: w < _compactBreakpoint),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Layouts ─────────────────────────

  /// Phones / small windows / portrait tablets: one column.
  Widget _buildNarrowBody({required bool compact}) {
    final gap = compact ? 14.0 : 18.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(compact: compact),
        SizedBox(height: gap),
        _buildMemberSelector(),
        SizedBox(height: gap),
        _buildLoanDetails(),
        SizedBox(height: gap),
        _buildLoanTypeSection(),
        SizedBox(height: gap),
        _buildCalculatedDetails(),
        SizedBox(height: gap + 6),
        _buildSubmitButton(),
      ],
    );
  }

  /// Desktop / web / tablets landscape: two balanced columns.
  ///   Left : member + loan details
  ///   Right: configuration + live summary + submit
  Widget _buildWideBody({required bool triple}) {
    if (triple) return _buildTripleBody();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(compact: false),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMemberSelector(),
                  const SizedBox(height: 20),
                  _buildLoanDetails(),
                ],
              ),
            ),
            const SizedBox(width: _columnGap),
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLoanTypeSection(),
                  const SizedBox(height: 20),
                  _buildCalculatedDetails(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Large desktop monitors: three columns so no space is wasted.
  ///   Col 1: member + loan details
  ///   Col 2: configuration
  ///   Col 3: repayment summary + submit
  Widget _buildTripleBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(compact: false),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMemberSelector(),
                  const SizedBox(height: 20),
                  _buildLoanDetails(),
                ],
              ),
            ),
            const SizedBox(width: _columnGap),
            Expanded(
              flex: 3,
              child: _buildLoanTypeSection(),
            ),
            const SizedBox(width: _columnGap),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCalculatedDetails(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────── Shared helpers ─────────────────────────

  /// Consistent section card with an icon badge, title and optional subtitle.
  Widget _card({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppTheme.primary),
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
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  /// One input style for every field so the form feels uniform.
  InputDecoration _dec({
    String? label,
    String? hint,
    IconData? icon,
    String? prefixText,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      prefixText: prefixText,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      labelStyle: GoogleFonts.poppins(fontSize: 13),
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
      border: border(Colors.grey.shade300),
      enabledBorder: border(Colors.grey.shade300),
      focusedBorder: border(AppTheme.primary, 1.6),
      errorBorder: border(AppTheme.error),
      focusedErrorBorder: border(AppTheme.error, 1.6),
    );
  }

  /// Two fields side by side, stacked only when the CARD itself is very narrow
  /// (so it also behaves correctly inside a two-column desktop layout).
  Widget _responsiveRow(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: 16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  DropdownMenuItem<String> _item(String value, String label) {
    return DropdownMenuItem(
      value: value,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(fontSize: 14),
      ),
    );
  }

  // ───────────────────────── Sections ─────────────────────────

  Widget _buildHeader({required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22, vertical: compact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.78)],
        ),
        borderRadius: BorderRadius.circular(_radius + 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New loan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pick a member, set the terms and disburse instantly with a custom interest rate.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 12 : 13,
                    height: 1.4,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Member selector (searchable) ──

  Widget _buildMemberSelector() {
    return _card(
      title: 'Select member',
      subtitle: 'Search by name, phone or account number',
      icon: Icons.person_search_rounded,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.usersCol)
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .where('role', isEqualTo: AppConstants.roleMember)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Could not load members. Check your connection and try again.',
              style: GoogleFonts.poppins(color: AppTheme.error, fontSize: 13),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final members = snapshot.data!.docs;

          return FormField<String>(
            key: ValueKey('member-field-$_selectedMemberId'),
            initialValue: _selectedMemberId,
            validator: (_) => _selectedMemberId == null ? 'Please select a member' : null,
            builder: (state) {
              final hasMember = _selectedMemberId != null;
              final name = _selectedMemberName ?? '';
              final sub = [
                if ((_selectedMemberPhone ?? '').isNotEmpty) _selectedMemberPhone!,
                if ((_selectedMemberAccount ?? '').isNotEmpty && _selectedMemberAccount != 'N/A')
                  'Acc: $_selectedMemberAccount',
              ].join('   |   ');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _pickMember(members),
                    child: InputDecorator(
                      decoration: _dec(
                        icon: hasMember ? null : Icons.search_rounded,
                        hint: 'Tap to search members',
                        suffix: Icon(
                          hasMember ? Icons.swap_horiz_rounded : Icons.keyboard_arrow_down_rounded,
                        ),
                      ).copyWith(
                        errorText: state.errorText,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: hasMember ? 10 : 15,
                        ),
                      ),
                      isEmpty: !hasMember,
                      child: hasMember
                          ? Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                                  child: Text(
                                    name.isEmpty ? '?' : name[0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (sub.isNotEmpty)
                                        Text(
                                          sub,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  _buildLoanBlockBanner(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Bottom sheet on phones, centred dialog on larger screens.
  Future<void> _pickMember(List<QueryDocumentSnapshot> members) async {
    FocusScope.of(context).unfocus();
    final compact = MediaQuery.of(context).size.width < _compactBreakpoint;

    final QueryDocumentSnapshot? picked;
    if (compact) {
      picked = await showModalBottomSheet<QueryDocumentSnapshot>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: FractionallySizedBox(
            heightFactor: 0.88,
            child: _MemberPicker(members: members, asSheet: true),
          ),
        ),
      );
    } else {
      picked = await showDialog<QueryDocumentSnapshot>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: _MemberPicker(members: members, asSheet: false),
          ),
        ),
      );
    }

    if (picked == null || !mounted) return;
    final data = picked.data() as Map<String, dynamic>;
    setState(() {
      _selectedMemberId = picked!.id;
      _selectedMemberName = (data['name'] ?? data['fullName'] ?? 'Unknown').toString();
      _selectedMemberPhone = (data['phone'] ?? data['phoneNumber'] ?? '').toString();
      _selectedMemberAccount = (data['accountNumber'] ?? 'N/A').toString();
      _existingLoan = null;
    });
    _checkExistingLoan(picked.id);
  }

  // ── Existing loan guard ──

  /// Returns the member's open loan (with its doc id) or null if they have none.
  /// Checks both `memberId` and `farmerId` so older records are caught too.
  Future<Map<String, dynamic>?> _findOpenLoan(String memberId) async {
    final col = FirebaseFirestore.instance.collection(AppConstants.loansCol);
    final tenant = FirebaseService.sessionTenantId;

    final results = await Future.wait([
      col.where('tenantId', isEqualTo: tenant).where('memberId', isEqualTo: memberId).get(),
      col.where('tenantId', isEqualTo: tenant).where('farmerId', isEqualTo: memberId).get(),
    ]);

    final seen = <String>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (!seen.add(doc.id)) continue;
        final d = doc.data();
        final status = (d['status'] ?? '').toString().toLowerCase();
        if (_closedLoanStatuses.contains(status)) continue;

        final rawBalance = d['balance'] ?? d['totalAmount'];
        final balance = rawBalance == null ? 1 : (num.tryParse('$rawBalance') ?? 1);
        if (balance <= 0) continue; // fully repaid

        return {...d, 'id': doc.id};
      }
    }
    return null;
  }

  Future<void> _checkExistingLoan(String memberId) async {
    setState(() {
      _checkingLoan = true;
      _existingLoan = null;
    });
    try {
      final loan = await _findOpenLoan(memberId);
      // Ignore the answer if the admin already picked someone else.
      if (!mounted || _selectedMemberId != memberId) return;
      setState(() {
        _existingLoan = loan;
        _checkingLoan = false;
      });
    } catch (e) {
      debugPrint('Existing loan check failed: $e');
      if (!mounted || _selectedMemberId != memberId) return;
      setState(() => _checkingLoan = false);
      // Not fatal here: _createLoan re-checks and refuses if it cannot verify.
    }
  }

  Widget _buildLoanBlockBanner() {
    if (_checkingLoan) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Checking for existing loans...',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final loan = _existingLoan;
    if (loan == null) return const SizedBox.shrink();

    final status = (loan['status'] ?? '').toString();
    final balanceRaw = loan['balance'] ?? loan['totalAmount'] ?? 0;
    final balance = num.tryParse('$balanceRaw') ?? 0;
    final amountRaw = loan['amount'] ?? loan['loanAmount'] ?? 0;
    final amount = num.tryParse('$amountRaw') ?? 0;

    String? dateText;
    final created = loan['createdAt'];
    if (created is Timestamp) {
      dateText = DateFormat('dd MMM yyyy').format(created.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_rounded, color: AppTheme.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member already has a loan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedMemberName ?? 'This member'} must clear the current loan '
                  'before a new one can be issued.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _loanFact('Amount', _currencyFormat.format(amount)),
                    _loanFact('Balance', _currencyFormat.format(balance)),
                    if (status.isNotEmpty) _loanFact('Status', status),
                    if (dateText != null) _loanFact('Issued', dateText),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loanFact(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loan details ──

  Widget _buildLoanDetails() {
    return _card(
      title: 'Loan details',
      subtitle: 'Amount, rate, duration and purpose',
      icon: Icons.payments_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: _dec(
              label: 'Loan amount',
              icon: Icons.payments_outlined,
              prefixText: 'UGX  ',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter loan amount';
              final v = int.tryParse(value);
              if (v == null) return 'Enter a valid amount';
              if (v < 10000) return 'Minimum loan is UGX 10,000';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _responsiveRow(
            TextFormField(
              controller: _interestRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: _dec(label: 'Interest (% per month)', icon: Icons.percent_rounded),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter rate';
                final rate = double.tryParse(value);
                if (rate == null || rate < 0 || rate > 100) return 'Invalid rate';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec(label: 'Duration (months)', icon: Icons.calendar_month_rounded),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter duration';
                final months = int.tryParse(value);
                if (months == null || months < 1 || months > 60) return '1 to 60 months';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [3, 6, 12, 18, 24].map((m) {
              final selected = _durationController.text == '$m';
              return ChoiceChip(
                label: Text('$m mo', style: GoogleFonts.poppins(fontSize: 12)),
                selected: selected,
                selectedColor: AppTheme.primary.withOpacity(0.15),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _durationController.text = '$m'),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _purposeController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec(
              label: 'Loan purpose',
              hint: 'e.g. Business expansion, school fees',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter loan purpose';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec(
              label: 'Admin notes (optional)',
              hint: 'Internal notes about this loan',
            ),
          ),
        ],
      ),
    );
  }

  // ── Configuration ──

  Widget _buildLoanTypeSection() {
    return _card(
      title: 'Loan configuration',
      subtitle: 'Type, repayment schedule and approval',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _loanType,
            isExpanded: true,
            decoration: _dec(label: 'Loan type', icon: Icons.category_outlined),
            items: [
              _item('personal', 'Personal Loan'),
              _item('business', 'Business Loan'),
              _item('emergency', 'Emergency Loan'),
              _item('education', 'Education Loan'),
              _item('agriculture', 'Agriculture Loan'),
            ],
            onChanged: (value) => setState(() => _loanType = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentFrequency,
            isExpanded: true,
            decoration: _dec(label: 'Payment frequency', icon: Icons.schedule_rounded),
            items: [
              _item('daily', 'Daily (Emergency)'),
              _item('weekly', 'Weekly'),
              _item('biweekly', 'Bi-Weekly'),
              _item('monthly', 'Monthly'),
            ],
            onChanged: (value) => setState(() => _paymentFrequency = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _interestMethod,
            isExpanded: true,
            decoration: _dec(label: 'Interest method', icon: Icons.calculate_outlined),
            items: [
              _item('flat', 'Flat Rate (Simple Interest)'),
              _item('reducing', 'Reducing Balance (Amortized)'),
            ],
            onChanged: (value) => setState(() => _interestMethod = value!),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: _autoApprove
                  ? AppTheme.success.withOpacity(0.07)
                  : const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _autoApprove ? AppTheme.success.withOpacity(0.35) : Colors.grey.shade300,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Approve & disburse now',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _autoApprove
                    ? 'Posts to the till and notifies the member by SMS'
                    : 'Saved as pending until someone approves it',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
              value: _autoApprove,
              onChanged: (value) => setState(() => _autoApprove = value),
              activeColor: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }

  // ── Live summary ──

  /// True when the live summary has enough valid input to be shown.
  bool get _hasSummary {
    if (_amountController.text.isEmpty ||
        _interestRateController.text.isEmpty ||
        _durationController.text.isEmpty) {
      return false;
    }
    final principal = int.tryParse(_amountController.text) ?? 0;
    final months = int.tryParse(_durationController.text) ?? 0;
    return principal != 0 && months != 0;
  }

  String get _paymentLabel {
    switch (_paymentFrequency) {
      case 'daily':
        return 'Daily payment';
      case 'weekly':
        return 'Weekly payment';
      case 'biweekly':
        return 'Bi-weekly payment';
      case 'monthly':
      default:
        return 'Monthly payment';
    }
  }

  Widget _buildCalculatedDetails() {
    if (!_hasSummary) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calculate_outlined, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enter an amount and duration to see the repayment summary.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final principal = int.tryParse(_amountController.text) ?? 0;
    final rate = double.tryParse(_interestRateController.text) ?? 0;
    final months = int.tryParse(_durationController.text) ?? 0;
    final calc = _calculate(principal, rate, months);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: AppTheme.success.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppTheme.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Repayment summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Headline figure
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paymentLabel,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currencyFormat.format(calc.periodic),
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ),
                Text(
                  '${calc.installments} installment${calc.installments == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildSummaryRow('Principal', _currencyFormat.format(principal)),
          _buildSummaryRow(
            'Interest (${_interestMethod == 'reducing' ? 'reducing' : 'flat'}, '
            '${_trimRate(rate)}% x $months mo)',
            _currencyFormat.format(calc.interest),
          ),
          const Divider(height: 18),
          _buildSummaryRow('Total repayment', _currencyFormat.format(calc.total), isTotal: true),
        ],
      ),
    );
  }

  String _trimRate(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();

  /// Number of installments for the chosen frequency.
  int _installmentCount(int months) {
    final n = switch (_paymentFrequency) {
      'daily' => months * 30,
      'weekly' => (months * 52 / 12).round(),
      'biweekly' => (months * 26 / 12).round(),
      _ => months,
    };
    return n < 1 ? 1 : n;
  }

  /// Single place for loan maths (used by the summary AND by _createLoan)
  ({double interest, double total, double periodic, int installments}) _calculate(
      int principal, double rate, int months) {
    double interest;
    double total;

    if (_interestMethod == 'reducing') {
      final monthlyRate = rate / (100 * 12);
      if (monthlyRate > 0) {
        double powN = 1;
        for (int i = 0; i < months; i++) {
          powN *= (1 + monthlyRate);
        }
        final monthlyPayment = (principal * monthlyRate * powN) / (powN - 1);
        total = monthlyPayment * months;
        interest = total - principal;
      } else {
        interest = 0;
        total = principal.toDouble();
      }
    } else {
      // Flat: rate is per month
      interest = (principal * rate / 100) * months;
      total = principal + interest;
    }

    final installments = _installmentCount(months);
    final periodic = total / installments;
    return (interest: interest, total: total, periodic: periodic, installments: installments);
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
                color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: GoogleFonts.poppins(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: (_isLoading || _checkingLoan || _existingLoan != null) ? null : _createLoan,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_autoApprove ? Icons.send_rounded : Icons.hourglass_top_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _autoApprove ? 'Create & disburse loan' : 'Create loan (pending approval)',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ───────────────────────── Actions ─────────────────────────

  void _resetForm() {
    _formKey.currentState?.reset();
    _amountController.clear();
    _purposeController.clear();
    _notesController.clear();
    _interestRateController.text = '15';
    _durationController.text = '12';
    setState(() {
      _selectedMemberId = null;
      _selectedMemberName = null;
      _selectedMemberPhone = null;
      _selectedMemberAccount = null;
      _existingLoan = null;
      _checkingLoan = false;
      _loanType = 'personal';
      _paymentFrequency = 'monthly';
      _interestMethod = 'flat';
      _autoApprove = true;
    });
  }

  /// Last check before money moves.
  Future<bool> _confirmCreate({
    required int principal,
    required double total,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _autoApprove ? 'Disburse this loan?' : 'Create this loan?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow('Member', _selectedMemberName ?? ''),
              _confirmRow('Amount', _currencyFormat.format(principal)),
              _confirmRow('Total repayment', _currencyFormat.format(total)),
              const SizedBox(height: 10),
              Text(
                _autoApprove
                    ? 'The loan will be approved now, cash will be deducted from the till and the member will be notified.'
                    : 'The loan will be saved as pending approval.',
                style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _autoApprove ? 'Disburse' : 'Create',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createLoan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberId == null) {
      _showError('Please select a member');
      return;
    }

    // Authoritative re-check right before saving, in case a loan was created
    // after the member was picked (e.g. by another admin). If we cannot verify,
    // we refuse rather than risk a duplicate loan.
    setState(() => _isLoading = true);
    try {
      final open = await _findOpenLoan(_selectedMemberId!);
      if (!mounted) return;
      if (open != null) {
        setState(() {
          _existingLoan = open;
          _isLoading = false;
        });
        _showError(
          '${_selectedMemberName ?? 'This member'} already has an open loan. '
          'It must be cleared before a new one can be issued.',
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Could not verify existing loans. Check your connection and try again.');
      return;
    }
    if (mounted) setState(() => _isLoading = false);

    final principalPreview = int.parse(_amountController.text);
    final previewCalc = _calculate(
      principalPreview,
      double.parse(_interestRateController.text),
      int.parse(_durationController.text),
    );
    final confirmed = await _confirmCreate(
      principal: principalPreview,
      total: previewCalc.total,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final principal = int.parse(_amountController.text);
      final rate = double.parse(_interestRateController.text);
      final months = int.parse(_durationController.text);

      final calc = _calculate(principal, rate, months);
      final interest = calc.interest;
      final totalAmount = calc.total;

      final loanData = <String, dynamic>{
        'tenantId': FirebaseService.sessionTenantId,
        'farmerId': _selectedMemberId,
        'memberId': _selectedMemberId, // Also save as memberId for consistency
        'farmerName': _selectedMemberName,
        'memberName': _selectedMemberName, // Also save as memberName
        'farmerPhone': _selectedMemberPhone,
        'accountNumber': _selectedMemberAccount ?? 'N/A', // Save account number
        'amount': principal,
        'loanAmount': principal,
        'interestRate': rate,
        'interestMethod': _interestMethod,
        'duration': months,
        'purpose': _purposeController.text.trim(),
        'loanType': _loanType,
        'paymentFrequency': _paymentFrequency,
        'installments': calc.installments,
        'installmentAmount': calc.periodic.round(),
        'interestAmount': interest.round(),
        'interest': interest.round(),
        'totalAmount': totalAmount.round(),
        'status': _autoApprove ? AppConstants.statusApproved : AppConstants.statusPending,
        'balance': totalAmount.round(),
        // Outstanding fields - ensure all are set consistently
        'principalOutstanding': principal.toDouble(),
        'interestOutstanding': interest,
        'chargesOutstanding': 0.0,
        'interestOriginalBalance': interest,
        'remainingBalance': totalAmount,
        'totalOutstanding': totalAmount,
        'outstanding': totalAmount,
        // Paid fields
        'principalPaid': 0.0,
        'interestPaid': 0.0,
        'chargesPaid': 0.0,
        'amountPaid': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseService.sessionUid,
        'createdByAdmin': true,
        'adminNotes': _notesController.text.trim(),
      };

      if (_autoApprove) {
        loanData['approvedAt'] = FieldValue.serverTimestamp();
        loanData['approvedBy'] = FirebaseService.sessionUid;
        loanData['disbursedAt'] = FieldValue.serverTimestamp();
        loanData['disbursedBy'] = FirebaseService.sessionUid;
      }

      // Create the loan document and get its ID
      final loanDocRef = await FirebaseFirestore.instance.collection(AppConstants.loansCol).add(loanData);
      final loanId = loanDocRef.id;
      
      // Update the loan with its actual ID
      await loanDocRef.update({'id': loanId});

      // If auto-approved and disbursed, credit to savings and send SMS
      if (_autoApprove) {
        try {
          // Use LoanDisbursementService to credit savings account
          final disbursementResult = await LoanDisbursementService.disburseLoan(
            loanId: loanId, // Use the real Firestore-generated ID
            disbursedBy: FirebaseService.sessionUid,
            amount: principal.toDouble(),
            narration: 'Loan auto-disbursed on creation',
          );

          if (disbursementResult['success'] == true) {
            debugPrint('✅ Loan $loanId disbursed and credited to member savings');
            debugPrint('✅ SMS notification sent to member');
          } else {
            debugPrint('⚠️ Loan disbursement failed: ${disbursementResult['message']}');
          }

          // Send in-app notification
          await FirebaseService.sendNotification(
            _selectedMemberId!,
            'Loan Approved & Disbursed',
            'Your loan of UGX ${_formatAmount(principal)} has been approved and credited to your savings account. '
            'Total payable: UGX ${_formatAmount(totalAmount.round())} over $months months. '
            'Visit any branch to withdraw.',
            type: 'loan_approved',
          );
        } catch (e) {
          debugPrint('❌ Failed to disburse loan or send notifications: $e');
          // Non-critical - loan is already created
        }
      }

      if (!mounted) return;

      // Show beautiful dialog for auto-disbursed loans
      if (_autoApprove) {
        // When opened as a tab (no back stack) don't pop the root route
        final shouldPop = Navigator.of(context).canPop();
        
        await SuccessDialog.showLoanDisbursement(
          context: context,
          memberName: _selectedMemberName ?? 'Member',
          amount: principal.toDouble(),
          loanReference: loanId,
        );
        
        if (shouldPop) {
          Navigator.pop(context);
        } else {
          _resetForm();
        }
      } else {
        // For pending loans, just show snackbar
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          _resetForm();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Loan created, pending approval', style: GoogleFonts.poppins()),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to create loan: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  String _formatAmount(int amount) {
    return NumberFormat('#,###', 'en_US').format(amount);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Searchable member picker (used as a bottom sheet on phones, dialog on
// tablets / desktop / web)
// ═════════════════════════════════════════════════════════════════════════

class _MemberPicker extends StatefulWidget {
  final List<QueryDocumentSnapshot> members;
  final bool asSheet;

  const _MemberPicker({required this.members, required this.asSheet});

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _data(QueryDocumentSnapshot d) => d.data() as Map<String, dynamic>;

  String _name(QueryDocumentSnapshot d) =>
      (_data(d)['name'] ?? _data(d)['fullName'] ?? 'Unknown').toString();

  String _phone(QueryDocumentSnapshot d) =>
      (_data(d)['phone'] ?? _data(d)['phoneNumber'] ?? '').toString();

  String _account(QueryDocumentSnapshot d) => (_data(d)['accountNumber'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();

    final filtered = widget.members.where((d) {
      if (q.isEmpty) return true;
      return _name(d).toLowerCase().contains(q) ||
          _phone(d).toLowerCase().contains(q) ||
          _account(d).toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: widget.asSheet ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.asSheet)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select member',
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search name, phone or account no.',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: const Color(0xFFF3F4F7),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 1.6),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          Text(
            '${filtered.length} member${filtered.length == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Flexible(
            fit: widget.asSheet ? FlexFit.tight : FlexFit.loose,
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'No members match your search',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: !widget.asSheet,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      final name = _name(d);
                      final phone = _phone(d);
                      final acct = _account(d);
                      final sub = [
                        if (phone.isNotEmpty) phone,
                        if (acct.isNotEmpty) 'Acc: $acct',
                      ].join('   |   ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: sub.isEmpty
                            ? null
                            : Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
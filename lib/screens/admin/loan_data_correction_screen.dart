import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../services/audit_service.dart';
import '../../services/till_service.dart';
import '../../services/loan_math.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _primary = Color(0xFF1E3A8A);
const _bg = Color(0xFFF1F5F9);
const _border = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _selectedTint = Color(0xFFEFF6FF);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);
const _blue = Color(0xFF2563EB);

final _numFmt = NumberFormat('#,###', 'en_US');
String _money(num v) => 'UGX ${_numFmt.format(v.round())}';

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'disbursed':
      return _green;
    case 'overdue':
      return _red;
    case 'paid':
      return const Color(0xFF0D9488);
    case 'approved':
      return _blue;
    default:
      return const Color(0xFFEA580C);
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts[1][0]).toUpperCase();
}

/// Lays children out in equal-width columns that adapt to the available width.
Widget _grid(
  List<Widget> children, {
  double minItemWidth = 260,
  int maxCols = 2,
  double gap = 16,
}) {
  return LayoutBuilder(builder: (context, cons) {
    final cols = math
        .max(1, ((cons.maxWidth + gap) / (minItemWidth + gap)).floor())
        .clamp(1, maxCols);
    final w = (cons.maxWidth - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final c in children) SizedBox(width: w, child: c)],
    );
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

/// Loan Data Correction screen: master-detail on wide screens,
/// list → detail navigation on narrow screens.
class LoanDataCorrectionScreenEnhanced extends StatefulWidget {
  const LoanDataCorrectionScreenEnhanced({super.key});

  @override
  State<LoanDataCorrectionScreenEnhanced> createState() =>
      _LoanDataCorrectionScreenEnhancedState();
}

class _LoanDataCorrectionScreenEnhancedState
    extends State<LoanDataCorrectionScreenEnhanced> {
  static const _statusFilters = [
    'All',
    'Overdue',
    'Disbursed',
    'Approved',
    'Paid',
    'Pending',
  ];

  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _filteredLoans = [];
  bool _isLoading = true;
  String? _selectedLoanId;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .orderBy('createdAt', descending: true)
          .get();

      final newLoans = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          // Raw data first, normalised values after so defaults always win.
          ...data,
          'id': doc.id,
          'memberName': (data['memberName'] ?? 'N/A').toString(),
          'accountNumber': (data['accountNumber'] ?? 'N/A').toString(),
          'status': (data['status'] ?? 'N/A').toString(),
          'loanAmount': LoanMath.d(data['loanAmount'] ?? data['amount']),
          'interestRate': LoanMath.d(data['interestRate']),
          'principalOutstanding': LoanMath.d(data['principalOutstanding']),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _loans = newLoans;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('❌ Error loading loans: $e');
      if (!mounted) return;
      setState(() {
        _loans = [];
        _filteredLoans = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredLoans = _loans.where((loan) {
        final matchesStatus = _statusFilter == 'All' ||
            loan['status'].toString().toLowerCase() ==
                _statusFilter.toLowerCase();
        final matchesQuery = q.isEmpty ||
            loan['memberName'].toString().toLowerCase().contains(q) ||
            loan['accountNumber'].toString().toLowerCase().contains(q);
        return matchesStatus && matchesQuery;
      }).toList();
    });
  }

  Future<void> _openReconcile() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ReconcileDialog(),
    );
    if (changed == true) _loadLoans(silent: true);
  }

  ThemeData _theme(BuildContext context) {
    final base = Theme.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );
    return base.copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: base.colorScheme.copyWith(primary: _primary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(_border),
        enabledBorder: border(_border),
        disabledBorder: border(_border),
        focusedBorder: border(_primary, 1.6),
        errorBorder: border(_red),
        focusedErrorBorder: border(_red, 1.6),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: _muted),
        floatingLabelStyle: GoogleFonts.inter(
            fontSize: 14, color: _primary, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: _muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme(context),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Loan Data Correction',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: LayoutBuilder(builder: (context, cons) {
          final wide = cons.maxWidth >= 900;
          if (wide) {
            final listWidth = cons.maxWidth >= 1300 ? 400.0 : 340.0;
            return Row(
              children: [
                SizedBox(width: listWidth, child: _buildListPane()),
                const VerticalDivider(width: 1, color: _border),
                Expanded(
                  child: _selectedLoanId == null
                      ? _buildEmptyState()
                      : _buildEditForm(showBack: false),
                ),
              ],
            );
          }

          // Narrow: show either the list or the form.
          return PopScope(
            canPop: _selectedLoanId == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) setState(() => _selectedLoanId = null);
            },
            child: _selectedLoanId == null
                ? _buildListPane()
                : _buildEditForm(showBack: true),
          );
        }),
      ),
    );
  }

  // ── List pane ──────────────────────────────────────────────────────────────

  Widget _buildListPane() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search by name or account',
                prefixIcon: const Icon(Icons.search, color: _muted),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openReconcile,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Reconcile all loans'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _statusFilters[i];
                final selected = f == _statusFilter;
                return Center(
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _muted,
                    ),
                    selectedColor: _primary,
                    backgroundColor: _bg,
                    side: BorderSide.none,
                    onSelected: (_) {
                      _statusFilter = f;
                      _applyFilters();
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_filteredLoans.length} ${_filteredLoans.length == 1 ? 'loan' : 'loans'}',
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(child: _buildLoanList()),
        ],
      ),
    );
  }

  Widget _buildLoanList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredLoans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text('No loans match your search',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: _muted)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredLoans.length,
      itemBuilder: (context, index) {
        final loan = _filteredLoans[index];
        final isSelected = loan['id'] == _selectedLoanId;
        final name = loan['memberName'].toString();
        final status = loan['status'].toString();

        return Material(
          color: isSelected ? _selectedTint : Colors.white,
          child: InkWell(
            onTap: () => setState(() => _selectedLoanId = loan['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: isSelected ? _primary : Colors.transparent,
                      width: 3),
                  bottom: const BorderSide(color: _border),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _primary.withOpacity(0.1),
                    child: Text(
                      _initials(name),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _primary,
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
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _money(loan['loanAmount'] as num),
                          style:
                              GoogleFonts.inter(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: status, compact: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Detail pane ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.edit_note_rounded,
                  size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text('Select a loan to correct',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _ink)),
            const SizedBox(height: 4),
            Text(
                'Pick a loan from the list, or use "Reconcile all loans" to fix migrated loans in one go.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm({required bool showBack}) {
    final index = _loans.indexWhere((l) => l['id'] == _selectedLoanId);
    if (index == -1) return _buildEmptyState();

    return _LoanEditForm(
      key: ValueKey(_selectedLoanId), // Rebuild when the loan changes
      loan: _loans[index],
      onBack: showBack ? () => setState(() => _selectedLoanId = null) : null,
      onSave: () => _loadLoans(silent: true),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit form
// ─────────────────────────────────────────────────────────────────────────────

class _Preview {
  final LoanSnapshot snap;
  final double legacyP, legacyI, ledgerP, ledgerI;
  final int payments;
  final String? error;
  final Map<String, dynamic> calc;

  const _Preview({
    required this.snap,
    required this.legacyP,
    required this.legacyI,
    required this.ledgerP,
    required this.ledgerI,
    required this.payments,
    required this.calc,
    this.error,
  });
}

class _LoanEditForm extends StatefulWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onSave;
  final VoidCallback? onBack;

  const _LoanEditForm({
    super.key,
    required this.loan,
    required this.onSave,
    this.onBack,
  });

  @override
  State<_LoanEditForm> createState() => _LoanEditFormState();
}

class _LoanEditFormState extends State<_LoanEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  final _loanAmountCtrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _installmentCtrl = TextEditingController();
  final _principalOutCtrl = TextEditingController();
  final _interestOutCtrl = TextEditingController();
  final _loanTypeCtrl = TextEditingController();
  final _arrearsCtrl = TextEditingController();

  DateTime? _disbursementDate;
  String _interestMethod = 'flat'; // flat, declining, simple
  bool _isSaving = false;
  bool _suppressListeners = false;

  // Payment history recorded in this system (drives the live reconciliation).
  List<Map<String, dynamic>> _reps = [];
  bool _repsLoading = true;
  String? _repsError;

  List<TextEditingController> get _all => [
        _loanAmountCtrl,
        _interestRateCtrl,
        _tenureCtrl,
        _installmentCtrl,
        _principalOutCtrl,
        _interestOutCtrl,
        _loanTypeCtrl,
        _arrearsCtrl,
      ];

  String get _frequency =>
      (widget.loan['paymentFrequency'] ?? 'monthly').toString();

  String get _tenureLabel {
    switch (_frequency.toLowerCase()) {
      case 'daily':
        return 'days';
      case 'weekly':
        return 'weeks';
      default:
        return 'months';
    }
  }

  String _signature(Map<String, dynamic> l) =>
      '${l['loanAmount']}|${l['principalOutstanding']}|${l['interestOutstanding']}|'
      '${l['arrears']}|${l['legacyAdjusted']}|${l['duration']}|${l['status']}';

  @override
  void initState() {
    super.initState();
    _populate();
    _loadReps();
    for (final c in _all) {
      c.addListener(_onAnyChanged);
    }
    // Auto-calculate installment when amount, rate, or tenure changes.
    _loanAmountCtrl.addListener(_calculateInstallment);
    _interestRateCtrl.addListener(_calculateInstallment);
    _tenureCtrl.addListener(_calculateInstallment);
  }

  @override
  void didUpdateWidget(_LoanEditForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loan['id'] != widget.loan['id'] ||
        _signature(oldWidget.loan) != _signature(widget.loan)) {
      _populate();
      _loadReps();
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAnyChanged() {
    if (_suppressListeners || !mounted) return;
    setState(() {});
  }

  Future<void> _loadReps() async {
    try {
      final snap = await _db
          .collection(AppConstants.repaymentsCol)
          .where('loanId', isEqualTo: widget.loan['id'])
          .get();
      if (!mounted) return;
      setState(() {
        _reps = snap.docs.map((d) => d.data()).toList();
        _repsLoading = false;
        _repsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _repsLoading = false;
        _repsError = e.toString();
      });
    }
  }

  /// Fills the controllers from the loan. Also used by Reset.
  void _populate() {
    _suppressListeners = true;
    final loan = widget.loan;

    String num0(dynamic v) {
      if (v == null) return '0';
      if (v is num && v == v.roundToDouble()) return v.toInt().toString();
      return v.toString();
    }

    _loanAmountCtrl.text = num0(loan['loanAmount'] ?? loan['amount']);
    _interestRateCtrl.text = num0(loan['interestRate']);
    _tenureCtrl.text =
        num0(loan['duration'] ?? loan['tenure'] ?? loan['loanTenure']);
    _installmentCtrl.text =
        num0(loan['installment'] ?? loan['monthlyInstallment']);
    _principalOutCtrl.text = num0(loan['principalOutstanding']);
    _interestOutCtrl.text = num0(loan['interestOutstanding']);
    _arrearsCtrl.text = num0(loan['arrears']);
    _loanTypeCtrl.text =
        (loan['loanType'] ?? loan['loanProduct'] ?? '').toString();

    _interestMethod = (loan['interestMethod'] ?? 'flat').toString();
    if (!['flat', 'declining', 'simple'].contains(_interestMethod)) {
      _interestMethod = 'flat';
    }

    final disbDate = loan['disbursementDate'] ?? loan['disbursedAt'];
    _disbursementDate = disbDate is Timestamp ? disbDate.toDate() : null;
    _suppressListeners = false;
  }

  void _reset() {
    setState(() {
      _populate();
      _formKey.currentState?.reset();
    });
  }

  // ── Calculations ───────────────────────────────────────────────────────────

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  /// Same formula as Loan Details and Reconcile: lives in LoanMath.
  double _computeTotalInterest() => LoanMath.totalInterest(
        principal: _num(_loanAmountCtrl),
        ratePct: _num(_interestRateCtrl),
        months: int.tryParse(_tenureCtrl.text.trim()) ?? 0,
        method: _interestMethod,
      );

  void _calculateInstallment() {
    if (_suppressListeners) return;
    final principal = _num(_loanAmountCtrl);
    final months = int.tryParse(_tenureCtrl.text.trim()) ?? 0;
    if (principal <= 0 || months <= 0) return;

    final installment = (principal + _computeTotalInterest()) / months;
    if (installment.isFinite && installment > 0) {
      _installmentCtrl.text = installment.toStringAsFixed(0);
    }
  }

  DateTime? get _dueDate {
    final months = int.tryParse(_tenureCtrl.text.trim());
    final d = _disbursementDate;
    if (d == null || months == null || months <= 0) return null;
    return LoanMath.dueDate(d, months, _frequency);
  }

  /// Live reconciliation: what the entered terms + TRUE balances imply.
  _Preview _preview() {
    final principal = _num(_loanAmountCtrl);
    final interest = _computeTotalInterest();
    final tenure = int.tryParse(_tenureCtrl.text.trim()) ?? 0;
    final pOut = _num(_principalOutCtrl);
    final iOut = _num(_interestOutCtrl);

    double lp = 0, li = 0;
    for (final r in _reps) {
      lp += LoanMath.d(r['principalAmount']);
      li += LoanMath.d(r['interestAmount']);
    }
    
    // For manually corrected loans, we accept any outstanding balance
    // because the admin has verified these are the true balances from the old system
    final isAlreadyCorrected = widget.loan['legacyAdjusted'] == true;
    
    final gapP = principal - pOut - lp;
    final gapI = interest - iOut - li;
    
    // Don't validate corrected loans - admin knows the true balances
    String? error;
    if (!isAlreadyCorrected && (gapP < -0.5 || gapI < -0.5)) {
      error = 'Outstanding balances seem too high. Recorded payments '
          '(principal ${_money(lp)}, interest ${_money(li)}) suggest lower balances. '
          'If you\'re sure these are correct, click "Override & Save".';
    }
    final legacyP = gapP > 0 ? gapP : 0.0;
    final legacyI = gapI > 0 ? gapI : 0.0;

    final calc = <String, dynamic>{
      ...widget.loan,
      'loanAmount': principal,
      'amount': principal,
      'interestRate': _num(_interestRateCtrl),
      'interestMethod': _interestMethod,
      'interestAmount': interest,
      'duration': tenure,
      'installment': _num(_installmentCtrl),
      'legacyPrincipalPaid': legacyP,
      'legacyInterestPaid': legacyI,
    };
    if (_disbursementDate != null) {
      calc['disbursementDate'] = Timestamp.fromDate(_disbursementDate!);
      calc['disbursedAt'] = Timestamp.fromDate(_disbursementDate!);
    }

    return _Preview(
      snap: LoanMath.compute(calc, _reps),
      legacyP: legacyP,
      legacyI: legacyI,
      ledgerP: lp,
      ledgerI: li,
      payments: _reps.length,
      calc: calc,
      error: error,
    );
  }

  /// Sets the balance fields to what the recorded payments imply (no legacy).
  void _useLedgerBalances() {
    final principal = _num(_loanAmountCtrl);
    final interest = _computeTotalInterest();
    double lp = 0, li = 0;
    for (final r in _reps) {
      lp += LoanMath.d(r['principalAmount']);
      li += LoanMath.d(r['interestAmount']);
    }
    setState(() {
      _principalOutCtrl.text =
          math.max(0, principal - lp).round().toString();
      _interestOutCtrl.text = math.max(0, interest - li).round().toString();
    });
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Widget _confirmRow(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(label,
                  style: GoogleFonts.inter(fontSize: 13, color: _muted)),
            ),
            Expanded(
              flex: 3,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color ?? _ink)),
            ),
          ],
        ),
      );

  Future<bool> _confirmSave(_Preview pv) async {
    final oldOut = LoanMath.d(widget.loan['principalOutstanding']) +
        LoanMath.d(widget.loan['interestOutstanding']);
    final oldArrears = LoanMath.d(widget.loan['arrears']);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Save changes?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Updating the loan for ${widget.loan['memberName']}. '
                'This changes financial reports and is recorded in the audit trail.',
                style: GoogleFonts.inter(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 12),
              _confirmRow('Outstanding',
                  '${_money(oldOut)}  →  ${_money(pv.snap.totalOut)}'),
              _confirmRow('Arrears',
                  '${_money(oldArrears)}  →  ${_money(pv.snap.arrears)}',
                  color: pv.snap.arrears > 0.5 ? _red : _green),
              _confirmRow('Paid before this system',
                  _money(pv.legacyP + pv.legacyI)),
              _confirmRow('Paid in this system',
                  _money(pv.ledgerP + pv.ledgerI)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save changes')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_repsLoading) {
      _showSnack('Still loading payment history. Try again in a second.', _amber);
      return;
    }
    final pv = _preview();
    if (pv.error != null) {
      final override = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text('Validation Warning', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pv.error!),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If the ledger data is incorrect, you can override and save anyway.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.amber[900]),
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
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context, false);
                _useLedgerBalances();
              },
              child: const Text('Use ledger'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _amber,
                minimumSize: const Size(140, 40),
              ),
              child: const Text('Override & Save'),
            ),
          ],
        ),
      );
      
      if (override != true) return;
    }
    if (!await _confirmSave(pv)) return;

    setState(() => _isSaving = true);

    try {
      final loanAmount = double.parse(_loanAmountCtrl.text.trim());
      final interestRate = double.parse(_interestRateCtrl.text.trim());
      final tenure = int.parse(_tenureCtrl.text.trim());
      final installment = double.parse(_installmentCtrl.text.trim());
      final totalInterest = _computeTotalInterest();

      final before = <String, dynamic>{
        'principalOutstanding': widget.loan['principalOutstanding'],
        'interestOutstanding': widget.loan['interestOutstanding'],
        'arrears': widget.loan['arrears'],
        'status': widget.loan['status'],
      };

      final updateData = <String, dynamic>{
        // Terms (what the admin edits)
        'loanAmount': loanAmount,
        'amount': loanAmount,
        'interestRate': interestRate,
        'tenure': tenure,
        'loanTenure': tenure,
        'duration': tenure, // loan details & schedule read this one
        'installment': installment,
        'monthlyInstallment': installment,
        'loanType': _loanTypeCtrl.text.trim(),
        'loanProduct': _loanTypeCtrl.text.trim(),
        'interestMethod': _interestMethod,
        'interest': totalInterest,
        'interestAmount': totalInterest, // loan details reads this one
        'interestOriginalBalance': totalInterest,
        // What was paid before the new system, worked out from the true balances
        'legacyPrincipalPaid': pv.legacyP,
        'legacyInterestPaid': pv.legacyI,
        'legacyAdjusted': true,
        'correctionDate': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_disbursementDate != null) {
        updateData['disbursementDate'] = Timestamp.fromDate(_disbursementDate!);
        updateData['disbursedAt'] = Timestamp.fromDate(_disbursementDate!);
        if (_dueDate != null) {
          updateData['dueDate'] = Timestamp.fromDate(_dueDate!);
        }
      }

      // Save the manually corrected outstanding balances (these are the TRUE balances)
      updateData['principalOutstanding'] = _num(_principalOutCtrl);
      updateData['interestOutstanding'] = _num(_interestOutCtrl);
      // Charges outstanding comes from the current loan document (not manually edited)
      updateData['chargesOutstanding'] = LoanMath.d(widget.loan['chargesOutstanding']);
      updateData['totalOutstanding'] = _num(_principalOutCtrl) + _num(_interestOutCtrl) + LoanMath.d(widget.loan['chargesOutstanding']);
      updateData['remainingBalance'] = updateData['totalOutstanding'];
      
      // Save manually corrected arrears
      final manualArrears = double.tryParse(_arrearsCtrl.text.trim());
      if (manualArrears != null) {
        updateData['arrears'] = manualArrears;
      } else {
        updateData['arrears'] = pv.snap.arrears;
      }
      
      // Save derived paid totals and status (but NOT the outstanding balances)
      updateData['principalPaid'] = pv.snap.pPaid;
      updateData['interestPaid'] = pv.snap.iPaid;
      updateData['chargesPaid'] = pv.snap.cPaid;
      updateData['totalRepaid'] = pv.snap.totalPaid;
      updateData['daysInArrears'] = pv.snap.dpd;
      updateData['arrearsUpdatedAt'] = FieldValue.serverTimestamp();
      
      // Update status based on arrears
      if (LoanMath.isActive(widget.loan)) {
        final arrearsValue = manualArrears ?? pv.snap.arrears;
        if (arrearsValue > 0.5) {
          updateData['status'] = 'overdue';
        } else {
          final currentStatus = (widget.loan['status'] ?? '').toString().toLowerCase();
          if (currentStatus == 'overdue') {
            updateData['status'] = 'disbursed';
          }
        }
      }

      await _db
          .collection(AppConstants.loansCol)
          .doc(widget.loan['id'])
          .update(updateData);

      await AuditService.log(
        action: 'loan_data_correction',
        details:
            'Corrected loan for ${widget.loan['memberName']}: outstanding '
            '${_money(LoanMath.d(before['principalOutstanding']) + LoanMath.d(before['interestOutstanding']))}'
            ' → ${_money(pv.snap.totalOut)}, arrears ${_money(LoanMath.d(before['arrears']))}'
            ' → ${_money(pv.snap.arrears)}, paid before this system '
            '${_money(pv.legacyP + pv.legacyI)}',
        userId: FirebaseService.sessionUid,
        affectedUserId: widget.loan['farmerId'] ?? widget.loan['memberId'],
        metadata: {
          'loanId': widget.loan['id'],
          'memberName': widget.loan['memberName'],
          'loanAmount': loanAmount,
          'interestRate': interestRate,
          'before': before.map((k, v) => MapEntry(k, v?.toString())),
          'after': {
            'principalOutstanding': pv.snap.pOut,
            'interestOutstanding': pv.snap.iOut,
            'arrears': pv.snap.arrears,
            'legacyPrincipalPaid': pv.legacyP,
            'legacyInterestPaid': pv.legacyI,
          },
        },
      );

      if (!mounted) return;
      _showSnack('Loan updated successfully', _green);
      widget.onSave();
    } catch (e) {
      debugPrint('❌ Error saving loan: $e');
      if (!mounted) return;
      _showSnack('Could not save the loan: $e', _red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Text(message),
      ));
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Text('Delete Loan?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to permanently delete this loan:',
              style: GoogleFonts.inter(fontSize: 14, color: _muted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.loan['memberName'].toString(),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Account: ${widget.loan['accountNumber']}',
                    style: GoogleFonts.inter(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Amount: ${_money(widget.loan['loanAmount'] ?? 0)}',
                    style: GoogleFonts.inter(fontSize: 13, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone. The deletion will be recorded in the audit trail.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Loan'),
            style: FilledButton.styleFrom(backgroundColor: _red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteLoan();
    }
  }

  Future<void> _deleteLoan() async {
    setState(() => _isSaving = true);

    try {
      final loanId = widget.loan['id'];
      final memberName = widget.loan['memberName'].toString();
      final accountNumber = widget.loan['accountNumber'].toString();
      final loanAmount = widget.loan['loanAmount'] ?? 0;
      final memberId = widget.loan['memberId'] ?? widget.loan['farmerId'];
      final principalOut = widget.loan['principalOutstanding'] ?? 0;
      final interestOut = widget.loan['interestOutstanding'] ?? 0;
      final totalOut = principalOut + interestOut;

      // 1. Update member's loan balance (reduce outstanding)
      if (memberId != null && totalOut > 0) {
        final memberRef = _db.collection(AppConstants.usersCol).doc(memberId);
        await memberRef.update({
          'loanBalance': FieldValue.increment(-totalOut),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
            '✅ Updated member loan balance: reduced by ${_money(totalOut)}');
      }

      // 2. If loan was disbursed and till session exists, reverse the disbursement entry
      final disbursementDate = widget.loan['disbursementDate'];
      if (disbursementDate != null && loanAmount > 0) {
        final tillEntries = await _db
            .collection(AppConstants.tillEntriesCol)
            .where('businessRecordId', isEqualTo: loanId)
            .where('entryType', isEqualTo: 'loan_disbursement')
            .get();

        for (final doc in tillEntries.docs) {
          try {
            final entry = doc.data();
            final tillSessionId = entry['tillSessionId'];
            if (tillSessionId != null) {
              await TillService.deleteTransaction(
                tillSessionId: tillSessionId,
                entryId: doc.id,
                deletedBy: FirebaseService.sessionUid,
                reason: 'Loan deleted by admin',
              );
              debugPrint(
                  '✅ Reversed till disbursement entry using TillService');
            }
          } catch (e) {
            debugPrint('⚠️ Could not delete till disbursement entry: $e');
          }
        }

        final repaymentEntries = await _db
            .collection(AppConstants.tillEntriesCol)
            .where('businessRecordId', isEqualTo: loanId)
            .where('entryType', isEqualTo: 'loan_repayment')
            .get();

        for (final doc in repaymentEntries.docs) {
          try {
            final entry = doc.data();
            final tillSessionId = entry['tillSessionId'];
            if (tillSessionId != null) {
              await TillService.deleteTransaction(
                tillSessionId: tillSessionId,
                entryId: doc.id,
                deletedBy: FirebaseService.sessionUid,
                reason: 'Loan deleted by admin',
              );
              debugPrint('✅ Reversed till repayment entry using TillService');
            }
          } catch (e) {
            debugPrint('⚠️ Could not delete till repayment entry: $e');
          }
        }
      }

      // 3. Delete all loan repayment records
      final repayments = await _db
          .collection(AppConstants.repaymentsCol)
          .where('loanId', isEqualTo: loanId)
          .get();

      for (final doc in repayments.docs) {
        await doc.reference.delete();
      }
      debugPrint('✅ Deleted ${repayments.docs.length} loan repayment records');

      // 4. Delete the loan document
      await _db.collection(AppConstants.loansCol).doc(loanId).delete();

      // 5. Log the deletion in audit trail
      await AuditService.log(
        action: 'loan_deleted',
        details:
            'Deleted loan for $memberName (Account: $accountNumber) - Loan Amount: ${_money(loanAmount)}, Outstanding: ${_money(totalOut)}. Reversed till entries and updated member balance.',
        userId: FirebaseService.sessionUid,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'memberName': memberName,
          'accountNumber': accountNumber,
          'loanAmount': loanAmount,
          'principalOutstanding': principalOut,
          'interestOutstanding': interestOut,
          'totalOutstanding': totalOut,
          'deletedAt': DateTime.now().toIso8601String(),
        },
      );

      if (!mounted) return;
      _showSnack('Loan deleted and balances updated successfully', _green);

      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        widget.onSave(); // Refresh the list
      }
    } catch (e) {
      debugPrint('❌ Error deleting loan: $e');
      if (!mounted) return;
      _showSnack('Could not delete the loan: $e', _red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final pad = width < 600 ? 16.0 : 24.0;
    final pv = _preview();

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildInfoBanner(),
                      const SizedBox(height: 16),
                      _buildSummary(pv),
                      const SizedBox(height: 16),
                      _buildReconCard(pv),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Loan information',
                        icon: Icons.description_outlined,
                        child: _grid([
                          _numField('Loan amount (UGX)', _loanAmountCtrl,
                              min: 1),
                          _numField('Interest rate (% per month)',
                              _interestRateCtrl,
                              min: 0, max: 100),
                          _numField('Tenure ($_tenureLabel)', _tenureCtrl,
                              integer: true, min: 1),
                          _buildInterestMethodDropdown(),
                          _numField('Installment (UGX)', _installmentCtrl,
                              min: 0),
                          _textField('Loan type / product', _loanTypeCtrl),
                          _buildDatePicker(),
                          _buildReadOnlyField(
                            'Due date',
                            _dueDate == null
                                ? '—'
                                : DateFormat('yyyy-MM-dd').format(_dueDate!),
                            Icons.event_available_outlined,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'True balances',
                        icon: Icons.account_balance_wallet_outlined,
                        trailing: TextButton.icon(
                          onPressed: _repsLoading ? null : _useLedgerBalances,
                          icon: const Icon(Icons.sync_alt, size: 16),
                          label: const Text('Use ledger balances'),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter what the member really owes today (from the old system or receipts). '
                              'Arrears is calculated for you.',
                              style: GoogleFonts.inter(
                                  fontSize: 12.5, color: _muted),
                            ),
                            const SizedBox(height: 14),
                            _grid([
                              _numField('Principal outstanding (UGX)',
                                  _principalOutCtrl,
                                  min: 0),
                              _numField('Interest outstanding (UGX)',
                                  _interestOutCtrl,
                                  min: 0),
                              _buildArrearsTile(pv),
                              _buildTotalOutstanding(),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildActionBar(pad),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = widget.loan['memberName'].toString();
    final status = widget.loan['status'].toString();

    return _Card(
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              tooltip: 'Back to loans',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
          ],
          CircleAvatar(
            radius: 24,
            backgroundColor: _primary.withOpacity(0.1),
            child: Text(_initials(name),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: _primary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Account ${widget.loan['accountNumber']}',
                  style: GoogleFonts.inter(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: status),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Editing loan data affects financial reports. Every change is recorded in the audit trail. '
              'Balances you enter are treated as the true position; the system works out what was paid '
              'before it and recalculates arrears automatically.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF9A3412), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(_Preview pv) {
    final principal = _num(_loanAmountCtrl);
    final interest = _computeTotalInterest();
    final outstanding = _num(_principalOutCtrl) + _num(_interestOutCtrl);

    return _grid(
      [
        _StatTile(label: 'Loan amount', value: _money(principal)),
        _StatTile(label: 'Total interest', value: _money(interest)),
        _StatTile(label: 'Total payable', value: _money(principal + interest)),
        _StatTile(
            label: 'Outstanding', value: _money(outstanding), highlight: true),
      ],
      minItemWidth: 190,
      maxCols: 4,
      gap: 12,
    );
  }

  Widget _buildReconCard(_Preview pv) {
    final s = pv.snap;
    final inArrears = s.arrears > 0.5;
    final Color tone = pv.error != null || inArrears ? _red : _green;
    final String label = _repsLoading
        ? 'Loading…'
        : pv.error != null
            ? 'Needs review'
            : inArrears
                ? 'In arrears'
                : 'Up to date';
    final n = int.tryParse(_tenureCtrl.text.trim()) ?? 0;

    return _SectionCard(
      title: 'Reconciliation (live)',
      icon: Icons.fact_check_outlined,
      trailing: _Pill(label: label, color: _repsLoading ? _muted : tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _grid(
            [
              _StatTile(
                label: 'Paid in this system',
                value: _money(pv.ledgerP + pv.ledgerI),
                sub:
                    '${pv.payments} payment${pv.payments == 1 ? '' : 's'} recorded',
              ),
              _StatTile(
                label: 'Paid before this system',
                value: _money(pv.legacyP + pv.legacyI),
                sub: 'Worked out from the balances',
              ),
              _StatTile(
                label: 'Due by today',
                value: _money(s.expectedToDate),
                sub: '${s.installmentsDue} of $n installments',
              ),
              _StatTile(
                label: 'Arrears',
                value: _money(s.arrears),
                valueColor: inArrears ? _red : _green,
                sub: inArrears ? '${s.dpd} days past due' : 'Not in arrears',
              ),
            ],
            minItemWidth: 190,
            maxCols: 4,
            gap: 12,
          ),
          if (pv.error != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: _red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(pv.error!,
                        style: GoogleFonts.inter(
                            fontSize: 12.5, color: const Color(0xFF7F1D1D))),
                  ),
                ],
              ),
            ),
          ],
          if (_repsError != null) ...[
            const SizedBox(height: 12),
            Text('Could not load payment history: $_repsError',
                style: GoogleFonts.inter(fontSize: 12.5, color: _red)),
          ],
        ],
      ),
    );
  }

  Widget _buildArrearsTile(_Preview pv) {
    return _numField('Arrears (UGX)', _arrearsCtrl, min: 0);
  }

  Widget _buildTotalOutstanding() {
    final total = _num(_principalOutCtrl) + _num(_interestOutCtrl);
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _selectedTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Total outstanding',
              style: GoogleFonts.inter(fontSize: 12, color: _muted)),
          const SizedBox(height: 2),
          Text(
            _money(total),
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(double pad) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Loan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: _red),
              ),
            ),
            const Spacer(),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _reset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: (_isSaving || _repsLoading) ? null : _saveLoan,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving…' : 'Save changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fields ─────────────────────────────────────────────────────────────────

  Widget _buildInterestMethodDropdown() {
    return DropdownButtonFormField<String>(
      value: _interestMethod,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Interest method'),
      items: const [
        DropdownMenuItem(
          value: 'flat',
          child: Text('Flat rate (principal × rate × tenure)',
              overflow: TextOverflow.ellipsis),
        ),
        DropdownMenuItem(
            value: 'declining',
            child: Text('Declining balance', overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(
            value: 'simple',
            child: Text('Simple interest', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _interestMethod = value);
        _calculateInstallment();
      },
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _numField(
    String label,
    TextEditingController controller, {
    bool integer = false,
    double? min,
    double? max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        integer
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Required';
        final n = double.tryParse(v);
        if (n == null) return 'Enter a valid number';
        if (min != null && n < min) {
          return min == 0
              ? 'Cannot be negative'
              : 'Must be at least ${_numFmt.format(min)}';
        }
        if (max != null && n > max) {
          return 'Must be at most ${_numFmt.format(max)}';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final now = DateTime.now();
        final latest = now.add(const Duration(days: 365));
        final initial = _disbursementDate ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial.isAfter(latest) ? latest : initial,
          firstDate: DateTime(2015),
          lastDate: latest,
        );
        if (picked != null) setState(() => _disbursementDate = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Disbursement date'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _disbursementDate != null
                    ? DateFormat('yyyy-MM-dd').format(_disbursementDate!)
                    : 'Select date',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _disbursementDate != null ? _ink : _muted,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, fillColor: _bg),
      child: Row(
        children: [
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(fontSize: 15, color: _ink)),
          ),
          Icon(icon, size: 18, color: _muted),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reconcile-all dialog (fixes migrated loans in bulk)
// ─────────────────────────────────────────────────────────────────────────────

class _RecRow {
  final String id;
  final Map<String, dynamic> loan;
  final LoanPlan plan;
  _RecRow(this.id, this.loan, this.plan);

  String get name => (loan['memberName'] ?? 'N/A').toString();
  String get account => (loan['accountNumber'] ?? 'N/A').toString();
  String get status => (loan['status'] ?? '').toString();
  double get oldArrears => LoanMath.d(loan['arrears']);
  double get oldOutstanding =>
      LoanMath.d(loan['principalOutstanding']) +
      LoanMath.d(loan['interestOutstanding']);
  bool get fixable =>
      plan.kind == PlanKind.migrate || plan.kind == PlanKind.refresh;
}

class _ReconcileDialog extends StatefulWidget {
  const _ReconcileDialog();

  @override
  State<_ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends State<_ReconcileDialog> {
  bool _loading = true;
  bool _applying = false;
  String? _error;
  String _filter = 'Needs action';
  List<_RecRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    try {
      final db = FirebaseFirestore.instance;
      final loansSnap = await db.collection(AppConstants.loansCol).get();
      final repSnap = await db.collection(AppConstants.repaymentsCol).get();

      final byLoan = <String, List<Map<String, dynamic>>>{};
      for (final d in repSnap.docs) {
        final m = d.data();
        (byLoan[(m['loanId'] ?? '').toString()] ??= []).add(m);
      }

      final rows = <_RecRow>[];
      for (final d in loansSnap.docs) {
        final loan = <String, dynamic>{'id': d.id, ...d.data()};
        if (!LoanMath.isActive(loan)) continue;
        rows.add(_RecRow(d.id, loan, LoanMath.plan(loan, byLoan[d.id] ?? [])));
      }
      rows.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _count(bool Function(_RecRow) test) => _rows.where(test).length;

  List<_RecRow> get _visible {
    switch (_filter) {
      case 'Review':
        return _rows.where((r) => r.plan.kind == PlanKind.review).toList();
      case 'All':
        return _rows;
      default:
        return _rows.where((r) => r.plan.kind != PlanKind.ok).toList();
    }
  }

  Future<void> _apply() async {
    final fix = _rows.where((r) => r.fixable).toList();
    if (fix.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apply to ${fix.length} loans?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This records what each member paid before the new system and recalculates '
          'balances and arrears. Loans marked Review are skipped. This is recorded in the audit trail.',
          style: GoogleFonts.inter(fontSize: 14, color: _muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _applying = true);
    try {
      final db = FirebaseFirestore.instance;
      var batch = db.batch();
      var n = 0;
      for (final r in fix) {
        final data = <String, dynamic>{};
        if (r.plan.kind == PlanKind.migrate) {
          data['legacyPrincipalPaid'] = r.plan.legacyP;
          data['legacyInterestPaid'] = r.plan.legacyI;
          data['legacyAdjusted'] = true;
          // For migration, we want to use the calculated balances, not preserve old ones
          // So we pass the loan WITHOUT legacyAdjusted flag for the derived() call
        }
        // During migration, use calculated balances (legacyAdjusted not yet on loan doc)
        // After migration, loan will have legacyAdjusted=true and balances will be preserved
        data.addAll(LoanMath.derived(r.loan, r.plan.after));
        batch.update(db.collection(AppConstants.loansCol).doc(r.id), data);
        n++;
        if (n % 400 == 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
      if (n % 400 != 0) await batch.commit();

      try {
        await AuditService.log(
          action: 'loan_bulk_reconcile',
          details:
              'Reconciled ${fix.length} loans after data migration (legacy paid amounts recorded, balances and arrears recalculated).',
          userId: FirebaseService.sessionUid,
          affectedUserId: '',
          metadata: {
            'loanIds': fix.map((r) => r.id).toList(),
            'migrated':
                fix.where((r) => r.plan.kind == PlanKind.migrate).length,
            'refreshed':
                fix.where((r) => r.plan.kind == PlanKind.refresh).length,
          },
        );
      } catch (e) {
        debugPrint('⚠️ Audit log failed: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
        content: Text('Reconciled ${fix.length} loans'),
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = 'Could not apply: $e';
      });
    }
  }

  Widget _chip(String label, int count) {
    final selected = _filter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      showCheckmark: false,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : _muted,
      ),
      selectedColor: _primary,
      backgroundColor: _bg,
      side: BorderSide.none,
      onSelected: (_) => setState(() => _filter = label),
    );
  }

  Widget _rowTile(_RecRow r) {
    final p = r.plan;
    String label;
    Color color;
    switch (p.kind) {
      case PlanKind.ok:
        label = 'OK';
        color = _green;
        break;
      case PlanKind.refresh:
        label = 'Refresh';
        color = _blue;
        break;
      case PlanKind.migrate:
        label = 'Migrate';
        color = _amber;
        break;
      case PlanKind.review:
        label = 'Review';
        color = _red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
              ),
              _Pill(label: label, color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text('A/C ${r.account}  •  ${r.status}',
              style: GoogleFonts.inter(fontSize: 12, color: _muted)),
          const SizedBox(height: 6),
          if (p.kind == PlanKind.review)
            Text(p.note,
                style:
                    GoogleFonts.inter(fontSize: 12, color: _red, height: 1.4))
          else ...[
            Text(
              'Arrears  ${_money(r.oldArrears)}  →  ${_money(p.after.arrears)}'
              '     Outstanding  ${_money(r.oldOutstanding)}  →  ${_money(p.after.totalOut)}',
              style: GoogleFonts.inter(fontSize: 12.5, color: _ink),
            ),
            if (p.kind == PlanKind.migrate)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Paid before this system: ${_money(p.legacyP + p.legacyI)}',
                  style: GoogleFonts.inter(fontSize: 12, color: _muted),
                ),
              ),
            if (p.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(p.note,
                    style: GoogleFonts.inter(fontSize: 12, color: _muted)),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fixCount = _count((r) => r.fixable);
    final reviewCount = _count((r) => r.plan.kind == PlanKind.review);
    final needsCount = _count((r) => r.plan.kind != PlanKind.ok);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
              color: _primary,
              child: Row(
                children: [
                  const Icon(Icons.fact_check_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reconcile all loans',
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text(
                            'Fix migrated loans: balances, paid-before-system and arrears',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed:
                        _applying ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Needs action', needsCount),
                    _chip('Review', reviewCount),
                    _chip('All', _rows.length),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(_error!,
                      style: GoogleFonts.inter(fontSize: 12.5, color: _red)),
                ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: _visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('Nothing here. All loans are consistent.',
                            style: GoogleFonts.inter(color: _muted)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _visible.length,
                        itemBuilder: (_, i) => _rowTile(_visible[i]),
                      ),
              ),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: const BoxDecoration(
                color: _bg,
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _applying ? null : () => Navigator.pop(context, false),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (_loading || _applying || fixCount == 0)
                        ? null
                        : _apply,
                    icon: _applying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.done_all, size: 18),
                    label: Text(_applying
                        ? 'Applying…'
                        : 'Apply to $fixCount loan${fixCount == 1 ? '' : 's'}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  final bool highlight;
  const _StatTile({
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? _primary : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: highlight ? Colors.white70 : _muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: highlight ? Colors.white : (valueColor ?? _ink),
              ),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: highlight ? Colors.white70 : _muted)),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool compact;
  const _StatusChip({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12, vertical: compact ? 3 : 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
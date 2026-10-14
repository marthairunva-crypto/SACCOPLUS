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

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _primary = Color(0xFF1E3A8A);
const _bg = Color(0xFFF1F5F9);
const _border = Color(0xFFE2E8F0);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _selectedTint = Color(0xFFEFF6FF);

final _numFmt = NumberFormat('#,###', 'en_US');
String _money(num v) => 'UGX ${_numFmt.format(v.round())}';

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'disbursed':
      return const Color(0xFF16A34A);
    case 'overdue':
      return const Color(0xFFDC2626);
    case 'paid':
      return const Color(0xFF0D9488);
    case 'approved':
      return const Color(0xFF2563EB);
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
          'loanAmount': ((data['loanAmount'] ?? data['amount'] ?? 0) as num)
              .toDouble(),
          'interestRate': ((data['interestRate'] ?? 0) as num).toDouble(),
          'principalOutstanding':
              ((data['principalOutstanding'] ?? 0) as num).toDouble(),
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
        errorBorder: border(const Color(0xFFDC2626)),
        focusedErrorBorder: border(const Color(0xFFDC2626), 1.6),
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
            Text('Pick a loan from the list to review and edit its details.',
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
  final _arrearsCtrl = TextEditingController();
  final _loanTypeCtrl = TextEditingController();

  DateTime? _disbursementDate;
  String _interestMethod = 'flat'; // flat, declining, simple
  bool _isSaving = false;
  bool _suppressListeners = false;

  List<TextEditingController> get _all => [
        _loanAmountCtrl,
        _interestRateCtrl,
        _tenureCtrl,
        _installmentCtrl,
        _principalOutCtrl,
        _interestOutCtrl,
        _arrearsCtrl,
        _loanTypeCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _populate();
    // Rebuild live summaries on any change.
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
    // If the loan ID changed or the loan data was updated, repopulate the form
    if (oldWidget.loan['id'] != widget.loan['id'] ||
        oldWidget.loan['loanAmount'] != widget.loan['loanAmount'] ||
        oldWidget.loan['principalOutstanding'] !=
            widget.loan['principalOutstanding']) {
      _populate();
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
    _tenureCtrl.text = num0(loan['tenure'] ?? loan['loanTenure']);
    _installmentCtrl.text =
        num0(loan['installment'] ?? loan['monthlyInstallment']);
    _principalOutCtrl.text = num0(loan['principalOutstanding']);
    _interestOutCtrl.text = num0(loan['interestOutstanding']);
    _arrearsCtrl.text = num0(loan['arrears']);
    _loanTypeCtrl.text = (loan['loanType'] ?? loan['loanProduct'] ?? '').toString();

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

  double _computeTotalInterest() {
    final principal = _num(_loanAmountCtrl);
    final rate = _num(_interestRateCtrl) / 100; // rate is per month
    final months = int.tryParse(_tenureCtrl.text.trim()) ?? 0;
    if (principal <= 0 || months <= 0 || rate <= 0) return 0;

    if (_interestMethod == 'declining') {
      // Reducing-balance EMI: total interest = EMI × n − principal
      final f = math.pow(1 + rate, months).toDouble();
      final emi = principal * rate * f / (f - 1);
      return emi * months - principal;
    }
    // Flat / simple: interest on the full principal for the whole tenure
    return principal * rate * months;
  }

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
    if (d == null || months == null) return null;
    return DateTime(d.year, d.month + months, d.day);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<bool> _confirmSave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Save changes?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'You are about to update the loan for ${widget.loan['memberName']}. '
          'This changes financial reports and is recorded in the audit trail.',
          style: GoogleFonts.inter(fontSize: 14, color: _muted),
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
    if (!await _confirmSave()) return;

    setState(() => _isSaving = true);

    try {
      final loanAmount = double.parse(_loanAmountCtrl.text.trim());
      final interestRate = double.parse(_interestRateCtrl.text.trim());
      final tenure = int.parse(_tenureCtrl.text.trim());
      final installment = double.parse(_installmentCtrl.text.trim());
      final principalOut = double.parse(_principalOutCtrl.text.trim());
      final interestOut = double.parse(_interestOutCtrl.text.trim());
      final arrears = double.parse(_arrearsCtrl.text.trim());

      final totalInterest = _computeTotalInterest();
      final principalPaid = loanAmount - principalOut;
      final interestPaid = totalInterest - interestOut;
      final totalOut = principalOut + interestOut;

      final updateData = <String, dynamic>{
        'loanAmount': loanAmount,
        'amount': loanAmount,
        'interestRate': interestRate,
        'tenure': tenure,
        'loanTenure': tenure,
        'installment': installment,
        'monthlyInstallment': installment,
        'principalOutstanding': principalOut,
        'interestOutstanding': interestOut,
        'totalOutstanding': totalOut,
        'remainingBalance': totalOut, // Keep in sync with totalOutstanding
        'arrears': arrears,
        'loanType': _loanTypeCtrl.text.trim(),
        'loanProduct': _loanTypeCtrl.text.trim(),
        'interestMethod': _interestMethod,
        'interest': totalInterest,
        'interestOriginalBalance': totalInterest,
        'principalPaid': principalPaid > 0 ? principalPaid : 0,
        'interestPaid': interestPaid > 0 ? interestPaid : 0,
        'totalRepaid': (principalPaid > 0 ? principalPaid : 0) +
            (interestPaid > 0 ? interestPaid : 0),
        'correctionDate': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_disbursementDate != null) {
        updateData['disbursementDate'] = Timestamp.fromDate(_disbursementDate!);
        updateData['disbursedAt'] = Timestamp.fromDate(_disbursementDate!);
        updateData['dueDate'] = Timestamp.fromDate(_dueDate!);
      }

      await _db
          .collection(AppConstants.loansCol)
          .doc(widget.loan['id'])
          .update(updateData);

      await AuditService.log(
        action: 'loan_data_correction',
        details:
            'Updated loan data for ${widget.loan['memberName']} - Loan Amount: UGX $loanAmount, Interest Rate: $interestRate%, Corrected fields: ${updateData.keys.join(', ')}',
        userId: FirebaseService.sessionUid,
        affectedUserId: widget.loan['farmerId'] ?? widget.loan['memberId'],
        metadata: {
          'loanId': widget.loan['id'],
          'memberName': widget.loan['memberName'],
          'loanAmount': loanAmount,
          'interestRate': interestRate,
          'correctedFields': updateData.keys.toList(),
        },
      );

      if (!mounted) return;
      _showSnack('Loan updated successfully', const Color(0xFF16A34A));
      widget.onSave();
    } catch (e) {
      debugPrint('❌ Error saving loan: $e');
      if (!mounted) return;
      _showSnack('Could not save the loan: $e', const Color(0xFFDC2626));
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
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
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
        debugPrint('✅ Updated member loan balance: reduced by ${_money(totalOut)}');
      }

      // 2. If loan was disbursed and till session exists, reverse the disbursement entry
      final disbursementDate = widget.loan['disbursementDate'];
      if (disbursementDate != null && loanAmount > 0) {
        // Find till entries for this loan disbursement
        final tillEntries = await _db
            .collection(AppConstants.tillEntriesCol)
            .where('businessRecordId', isEqualTo: loanId)
            .where('entryType', isEqualTo: 'loan_disbursement')
            .get();

        if (tillEntries.docs.isNotEmpty) {
          // Delete the disbursement entries using TillService (this will automatically rollback the balance)
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
                debugPrint('✅ Reversed till disbursement entry using TillService');
              }
            } catch (e) {
              debugPrint('⚠️ Could not delete till disbursement entry: $e');
            }
          }
        }

        // Also reverse any loan repayment entries in the till
        final repaymentEntries = await _db
            .collection(AppConstants.tillEntriesCol)
            .where('businessRecordId', isEqualTo: loanId)
            .where('entryType', isEqualTo: 'loan_repayment')
            .get();

        if (repaymentEntries.docs.isNotEmpty) {
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
      }

      // 3. Delete all loan repayment records
      final repayments = await _db
          .collection(AppConstants.repaymentsCol)
          .where('loanId', isEqualTo: loanId)
          .get();

      if (repayments.docs.isNotEmpty) {
        for (final doc in repayments.docs) {
          await doc.reference.delete();
        }
        debugPrint('✅ Deleted ${repayments.docs.length} loan repayment records');
      }

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
      _showSnack('Loan deleted and balances updated successfully', const Color(0xFF16A34A));
      
      // Navigate back to loan list
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        widget.onSave(); // Refresh the list
      }
    } catch (e) {
      debugPrint('❌ Error deleting loan: $e');
      if (!mounted) return;
      _showSnack('Could not delete the loan: $e', const Color(0xFFDC2626));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final pad = width < 600 ? 16.0 : 24.0;

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
                      _buildWarning(),
                      const SizedBox(height: 16),
                      _buildSummary(),
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
                          _numField('Tenure (months)', _tenureCtrl,
                              integer: true, min: 1),
                          _buildInterestMethodDropdown(),
                          _numField('Monthly installment (UGX)',
                              _installmentCtrl,
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
                        title: 'Outstanding balances',
                        icon: Icons.account_balance_wallet_outlined,
                        child: _grid([
                          _numField('Principal outstanding (UGX)',
                              _principalOutCtrl,
                              min: 0),
                          _numField('Interest outstanding (UGX)',
                              _interestOutCtrl,
                              min: 0),
                          _numField('Arrears (UGX)', _arrearsCtrl, min: 0),
                          _buildTotalOutstanding(),
                        ]),
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

  Widget _buildWarning() {
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
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEA580C), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Editing loan data affects financial reports. Every change is recorded in the audit trail.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF9A3412), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
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
            // Delete button on the left
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Loan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: const BorderSide(color: Color(0xFFDC2626)),
              ),
            ),
            const Spacer(),
            // Reset and Save buttons on the right
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
                  onPressed: _isSaving ? null : _saveLoan,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          return min == 0 ? 'Cannot be negative' : 'Must be at least ${_numFmt.format(min)}';
        }
        if (max != null && n > max) return 'Must be at most ${_numFmt.format(max)}';
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
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

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
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
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
  final bool highlight;
  const _StatTile(
      {required this.label, required this.value, this.highlight = false});

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
                color: highlight ? Colors.white : _ink,
              ),
            ),
          ),
        ],
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
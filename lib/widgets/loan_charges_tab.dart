import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/loan_charge.dart';
import '../services/charge_service.dart';
import 'add_loan_charge_dialog.dart';
import 'waive_charge_dialog.dart';

class LoanChargesTab extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic> loanData;
  final VoidCallback onChargeChanged;

  const LoanChargesTab({
    Key? key,
    required this.loanId,
    required this.loanData,
    required this.onChargeChanged,
  }) : super(key: key);

  @override
  State<LoanChargesTab> createState() => _LoanChargesTabState();
}

class _LoanChargesTabState extends State<LoanChargesTab> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  List<LoanCharge> _charges = [];
  bool _loading = true;

  // Design tokens
  static const _navy = Color(0xFF0B1F4B);
  static const _brand = Color(0xFF1E3A8A);
  static const _blue = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE5E9F0);
  static const _hair = Color(0xFFF1F4F9);
  static const _green = Color(0xFF047857);
  static const _red = Color(0xFFB91C1C);
  static const _amber = Color(0xFFB45309);
  static const _gold = Color(0xFFC9A24B);

  @override
  void initState() {
    super.initState();
    _loadCharges();
  }

  Future<void> _loadCharges() async {
    setState(() => _loading = true);
    print('🔍 Loading charges for loan: ${widget.loanId}');
    final charges = await ChargeService.getChargesForLoan(widget.loanId);
    print('📊 Loaded ${charges.length} charges');
    if (charges.isNotEmpty) {
      for (var charge in charges) {
        print('  - ${charge.chargeTypeName}: UGX ${charge.amount}');
      }
    }
    if (mounted) {
      setState(() {
        _charges = charges;
        _loading = false;
      });
    }
  }

  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _text}) {
    return GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);
  }

  String _money(int amount) => _currencyFormat.format(amount);

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return _green;
      case 'waived':
        return _blue;
      case 'reversed':
        return _muted;
      case 'partial':
        return _amber;
      default:
        return _red;
    }
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: _t(11, w: FontWeight.w600, c: color),
      ),
    );
  }

  void _showAddChargeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddLoanChargeDialog(
        loanId: widget.loanId,
        loanData: widget.loanData,
        onSuccess: () {
          _loadCharges();
          widget.onChargeChanged();
        },
      ),
    );
  }

  void _showWaiveDialog(LoanCharge charge) {
    showDialog(
      context: context,
      builder: (ctx) => WaiveChargeDialog(
        charge: charge,
        loanId: widget.loanId,
        onSuccess: () {
          _loadCharges();
          widget.onChargeChanged();
        },
      ),
    );
  }

  Future<void> _reverseCharge(LoanCharge charge) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ReverseChargeDialog(charge: charge),
    );

    if (confirmed == true) {
      _loadCharges();
      widget.onChargeChanged();
    }
  }

  Future<void> _deleteCharge(LoanCharge charge) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteChargeDialog(charge: charge),
    );

    if (confirmed == true) {
      _loadCharges();
      widget.onChargeChanged();
    }
  }

  Future<void> _showDeleteAllChargesDialog() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteAllChargesDialog(loanId: widget.loanId),
    );

    if (confirmed == true) {
      _loadCharges();
      widget.onChargeChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_charges.isEmpty) {
      return _buildEmptyState();
    }

    // Calculate totals
    int totalAmount = 0;
    int totalPaid = 0;
    int totalWaived = 0;
    int totalOutstanding = 0;

    for (final charge in _charges) {
      if (charge.status != 'reversed') {
        totalAmount += charge.amount;
        totalPaid += charge.amountPaid;
        totalWaived += charge.amountWaived;
        totalOutstanding += charge.amountOutstanding;
      }
    }

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Add button
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Loan charges', style: _t(16, w: FontWeight.w600, c: _ink)),
                    const SizedBox(height: 4),
                    Text(
                      '${_charges.length} charge${_charges.length == 1 ? '' : 's'}',
                      style: _t(13, c: _muted),
                    ),
                  ],
                ),
              ),
              if (_charges.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: _showDeleteAllChargesDialog,
                  icon: const Icon(Icons.delete_sweep, size: 18, color: _red),
                  label: Text(isCompact ? 'Clear' : 'Clear all charges'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: BorderSide(color: _red.withOpacity(0.3)),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: _showAddChargeDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text(isCompact ? 'Add' : 'Add charge'),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: _line),

        // Charges table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (isCompact) ..._buildCompactChargesList()
                else _buildChargesTable(),
                
                const SizedBox(height: 24),
                
                // Totals row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hair,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('TOTALS',
                            style: _t(13, w: FontWeight.w700, c: _ink)),
                      ),
                      if (!isCompact) ...[
                        SizedBox(
                          width: 120,
                          child: Text('UGX ${_money(totalAmount)}',
                              textAlign: TextAlign.right,
                              style: _t(14, w: FontWeight.w700, c: _ink)),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          child: Text('UGX ${_money(totalPaid)}',
                              textAlign: TextAlign.right,
                              style: _t(14, w: FontWeight.w700, c: _green)),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          child: Text('UGX ${_money(totalWaived)}',
                              textAlign: TextAlign.right,
                              style: _t(14, w: FontWeight.w700, c: _blue)),
                        ),
                        const SizedBox(width: 16),
                      ],
                      SizedBox(
                        width: 120,
                        child: Text('UGX ${_money(totalOutstanding)}',
                            textAlign: TextAlign.right,
                            style: _t(14, w: FontWeight.w700, c: _red)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    // Check if loan has charge totals but no detailed charges
    final loanCharges = widget.loanData['charges'] ?? 0;
    final hasLegacyCharges = loanCharges > 0 && _charges.isEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasLegacyCharges ? Icons.info_outline : Icons.receipt_long_outlined,
                size: 28,
                color: _brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasLegacyCharges ? 'Legacy charges detected' : 'No charges on this loan',
              style: _t(15, w: FontWeight.w600, c: _ink),
            ),
            const SizedBox(height: 6),
            Text(
              hasLegacyCharges
                  ? 'This loan has UGX ${_money(loanCharges)} in charges from the old system.\nAdd new charges using the button below to see detailed breakdown.'
                  : 'Charges must be added manually by staff.\nThey are never applied automatically.',
              textAlign: TextAlign.center,
              style: _t(13, c: _muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showAddChargeDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add charge'),
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                minimumSize: const Size(140, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargesTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _hair,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Date', style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Charge type', style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Instalment', style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                SizedBox(
                  width: 120,
                  child: Text('Amount',
                      textAlign: TextAlign.right,
                      style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Text('Paid',
                      textAlign: TextAlign.right,
                      style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Text('Waived',
                      textAlign: TextAlign.right,
                      style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: Text('Outstanding',
                      textAlign: TextAlign.right,
                      style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: Text('Status',
                      textAlign: TextAlign.center,
                      style: _t(12, w: FontWeight.w600, c: _muted)),
                ),
                const SizedBox(width: 48), // Actions
              ],
            ),
          ),

          // Rows
          for (int i = 0; i < _charges.length; i++)
            _buildChargeRow(_charges[i], i == _charges.length - 1),
        ],
      ),
    );
  }

  Widget _buildChargeRow(LoanCharge charge, bool isLast) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: _hair)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('d MMM yyyy').format(charge.chargeDate),
              style: _t(13, c: _text),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(charge.chargeTypeName,
                    style: _t(13, w: FontWeight.w500, c: _ink)),
                if (charge.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(charge.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(12, c: _muted)),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              charge.instalmentNumber != null
                  ? '#${charge.instalmentNumber}'
                  : '—',
              style: _t(13, c: _text),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text('UGX ${_money(charge.amount)}',
                textAlign: TextAlign.right, style: _t(13, c: _ink)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text('UGX ${_money(charge.amountPaid)}',
                textAlign: TextAlign.right,
                style: _t(13, c: charge.amountPaid > 0 ? _green : _muted)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text('UGX ${_money(charge.amountWaived)}',
                textAlign: TextAlign.right,
                style: _t(13, c: charge.amountWaived > 0 ? _blue : _muted)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text('UGX ${_money(charge.amountOutstanding)}',
                textAlign: TextAlign.right,
                style: _t(13,
                    w: FontWeight.w600,
                    c: charge.amountOutstanding > 0 ? _red : _muted)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Center(child: _statusChip(charge.status)),
          ),
          SizedBox(
            width: 48,
            child: _buildActionsMenu(charge),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCompactChargesList() {
    return _charges.map((charge) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(charge.chargeTypeName,
                      style: _t(14, w: FontWeight.w600, c: _ink)),
                ),
                _statusChip(charge.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(DateFormat('d MMM yyyy').format(charge.chargeDate),
                style: _t(12, c: _muted)),
            if (charge.instalmentNumber != null) ...[
              const SizedBox(height: 4),
              Text('Instalment #${charge.instalmentNumber}',
                  style: _t(12, c: _muted)),
            ],
            const SizedBox(height: 12),
            _buildCompactAmountRow('Amount', charge.amount, _ink),
            _buildCompactAmountRow('Paid', charge.amountPaid, _green),
            _buildCompactAmountRow('Waived', charge.amountWaived, _blue),
            _buildCompactAmountRow(
                'Outstanding', charge.amountOutstanding, _red,
                bold: true),
            if (charge.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(charge.notes, style: _t(12, c: _muted)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (charge.status != 'reversed' &&
                    charge.amountOutstanding > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showWaiveDialog(charge),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(color: _line),
                      ),
                      child: const Text('Waive'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (charge.status != 'reversed')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => charge.amountPaid > 0
                          ? _reverseCharge(charge)
                          : _deleteCharge(charge),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: BorderSide(color: _red.withOpacity(0.3)),
                        foregroundColor: _red,
                      ),
                      child: Text(charge.amountPaid > 0 ? 'Reverse' : 'Delete'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildCompactAmountRow(String label, int amount, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: _t(13, c: _muted)),
          ),
          Text('UGX ${_money(amount)}',
              style: _t(13, w: bold ? FontWeight.w600 : FontWeight.w500, c: color)),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(LoanCharge charge) {
    if (charge.status == 'reversed') {
      return const SizedBox();
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: _muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) {
        if (value == 'waive') {
          _showWaiveDialog(charge);
        } else if (value == 'reverse') {
          _reverseCharge(charge);
        } else if (value == 'delete') {
          _deleteCharge(charge);
        }
      },
      itemBuilder: (context) => [
        if (charge.amountOutstanding > 0)
          const PopupMenuItem(
            value: 'waive',
            child: Row(
              children: [
                Icon(Icons.money_off, size: 18, color: _muted),
                SizedBox(width: 12),
                Text('Waive charge'),
              ],
            ),
          ),
        if (charge.amountPaid > 0)
          const PopupMenuItem(
            value: 'reverse',
            child: Row(
              children: [
                Icon(Icons.undo, size: 18, color: _red),
                SizedBox(width: 12),
                Text('Reverse', style: TextStyle(color: _red)),
              ],
            ),
          ),
        if (charge.amountPaid == 0)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: _red),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: _red)),
              ],
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REVERSE CHARGE DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _ReverseChargeDialog extends StatefulWidget {
  final LoanCharge charge;

  const _ReverseChargeDialog({required this.charge});

  @override
  State<_ReverseChargeDialog> createState() => _ReverseChargeDialogState();
}

class _ReverseChargeDialogState extends State<_ReverseChargeDialog> {
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE5E9F0);
  static const _red = Color(0xFFB91C1C);

  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _text}) {
    return GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for reversal')),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await ChargeService.reverseCharge(
      chargeId: widget.charge.id,
      loanId: widget.charge.loanId,
      reason: _reasonCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Charge reversed successfully')),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Error reversing charge')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.undo, size: 20, color: _red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Reverse charge', style: _t(16, w: FontWeight.w600, c: _ink)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reversing ${widget.charge.chargeTypeName} (UGX ${NumberFormat('#,###').format(widget.charge.amount)})',
            style: _t(13, c: _muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason for reversal *',
              hintText: 'Explain why this charge is being reversed',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _red),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reverse'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELETE CHARGE DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _DeleteChargeDialog extends StatefulWidget {
  final LoanCharge charge;

  const _DeleteChargeDialog({required this.charge});

  @override
  State<_DeleteChargeDialog> createState() => _DeleteChargeDialogState();
}

class _DeleteChargeDialogState extends State<_DeleteChargeDialog> {
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE5E9F0);
  static const _red = Color(0xFFB91C1C);

  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _text}) {
    return GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 12),
              Text('Missing Information', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text('Please provide a reason for deleting this charge.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await ChargeService.deleteCharge(
      chargeId: widget.charge.id,
      loanId: widget.charge.loanId,
      reason: _reasonCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle, size: 24, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              const Text('Success', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'Charge deleted successfully.\n\n${widget.charge.chargeTypeName} (UGX ${NumberFormat('#,###').format(widget.charge.amount)}) has been removed from this loan.',
            style: _t(14),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                minimumSize: const Size(100, 40),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      setState(() => _loading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 12),
              Text('Error', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(result['message'] ?? 'Failed to delete charge. Please try again.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                minimumSize: const Size(100, 40),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline, size: 20, color: _red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Delete charge', style: _t(16, w: FontWeight.w600, c: _ink)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deleting ${widget.charge.chargeTypeName} (UGX ${NumberFormat('#,###').format(widget.charge.amount)})',
            style: _t(13, c: _muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will completely remove the charge. Use "Reverse" if the charge has payments.',
                    style: _t(11, c: Colors.amber[900]!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason for deletion *',
              hintText: 'Explain why this charge is being deleted',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _red),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// DELETE ALL CHARGES DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _DeleteAllChargesDialog extends StatefulWidget {
  final String loanId;

  const _DeleteAllChargesDialog({required this.loanId});

  @override
  State<_DeleteAllChargesDialog> createState() => _DeleteAllChargesDialogState();
}

class _DeleteAllChargesDialogState extends State<_DeleteAllChargesDialog> {
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE5E9F0);
  static const _red = Color(0xFFDC2626);

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 12),
              Text('Missing Information', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text('Please provide a reason for bulk deletion.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final result = await ChargeService.deleteAllChargesFromLoan(
      loanId: widget.loanId,
      reason: _reasonCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true);
      final chargesDeleted = result['chargesDeleted'] ?? 0;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle, size: 24, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              const Text('Success', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            chargesDeleted > 0
                ? 'Successfully deleted $chargesDeleted charge${chargesDeleted == 1 ? '' : 's'}.\n\nThe loan has been reset to normal state.'
                : 'All charges have been cleared from this loan.',
            style: _t(14),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                minimumSize: const Size(100, 40),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      setState(() => _loading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 12),
              Text('Error', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(result['message'] ?? 'Failed to delete charges. Please try again.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                minimumSize: const Size(100, 40),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  TextStyle _t(double size, {FontWeight? w, Color? c}) {
    return TextStyle(fontSize: size, fontWeight: w, color: c ?? _text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_sweep, color: _red, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Delete all charges', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will delete ALL unpaid charges from this loan and reset the loan to normal state.',
            style: _t(13, c: _muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: _red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Paid charges cannot be deleted and will be skipped.',
                    style: _t(12, c: _red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason for bulk deletion *',
              hintText: 'Explain why all charges are being removed',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _line),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _red),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete all charges'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }
}

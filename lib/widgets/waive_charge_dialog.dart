import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/loan_charge.dart';
import '../services/charge_service.dart';

class WaiveChargeDialog extends StatefulWidget {
  final LoanCharge charge;
  final String loanId;
  final VoidCallback onSuccess;

  const WaiveChargeDialog({
    Key? key,
    required this.charge,
    required this.loanId,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<WaiveChargeDialog> createState() => _WaiveChargeDialogState();
}

class _WaiveChargeDialogState extends State<WaiveChargeDialog> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  bool _submitting = false;

  static const _brand = Color(0xFF1E3A8A);
  static const _blue = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE5E9F0);
  static const _hair = Color(0xFFF1F4F9);

  @override
  void initState() {
    super.initState();
    // Default to full outstanding amount
    _amountCtrl.text = widget.charge.amountOutstanding.toString();
  }

  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _text}) {
    return GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);
  }

  int _parseAmount() {
    final text = _amountCtrl.text.trim().replaceAll(',', '');
    return int.tryParse(text) ?? 0;
  }

  String _money(int amount) => _currencyFormat.format(amount);

  Future<void> _submit() async {
    final amount = _parseAmount();
    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }

    if (amount > widget.charge.amountOutstanding) {
      _showSnackBar('Waiver amount exceeds outstanding charge amount');
      return;
    }

    if (_reasonCtrl.text.trim().isEmpty) {
      _showSnackBar('Please provide a reason for the waiver');
      return;
    }

    setState(() => _submitting = true);

    final result = await ChargeService.requestWaiver(
      chargeId: widget.charge.id,
      loanId: widget.loanId,
      amount: amount,
      reason: _reasonCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      widget.onSuccess();
      Navigator.pop(context);
      _showSnackBar(
        'Waiver request submitted for approval',
        isSuccess: true,
      );
    } else {
      setState(() => _submitting = false);
      _showSnackBar(result['message'] ?? 'Error submitting waiver request');
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width > 500 ? 450.0 : width - 48;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.money_off, size: 20, color: _blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Waive charge',
                            style: _t(16, w: FontWeight.w600, c: _ink)),
                        const SizedBox(height: 2),
                        Text('Request approval to waive this charge',
                            style: _t(12, c: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Charge info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _hair,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Charge details',
                              style: _t(12, w: FontWeight.w600, c: _muted)),
                          const SizedBox(height: 10),
                          _infoRow('Type', widget.charge.chargeTypeName),
                          const SizedBox(height: 6),
                          _infoRow('Total amount',
                              'UGX ${_money(widget.charge.amount)}'),
                          const SizedBox(height: 6),
                          _infoRow('Paid',
                              'UGX ${_money(widget.charge.amountPaid)}'),
                          const SizedBox(height: 6),
                          _infoRow('Already waived',
                              'UGX ${_money(widget.charge.amountWaived)}'),
                          const SizedBox(height: 6),
                          _infoRow(
                            'Outstanding',
                            'UGX ${_money(widget.charge.amountOutstanding)}',
                            bold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Amount to waive
                    Text('Amount to waive (UGX) *',
                        style: _t(13, w: FontWeight.w500, c: _ink)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixText: 'UGX ',
                        helperText:
                            'Maximum: UGX ${_money(widget.charge.amountOutstanding)}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _line),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Reason
                    Text('Reason for waiver *',
                        style: _t(13, w: FontWeight.w500, c: _ink)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Explain why this charge should be waived',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _line),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: _blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This waiver requires approval from a supervisor or manager.',
                              style: _t(12, c: _blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      minimumSize: const Size(140, 44),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Request waiver'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _t(12, c: _muted)),
        Text(
          value,
          style: _t(12,
              w: bold ? FontWeight.w600 : FontWeight.w500,
              c: bold ? _ink : _text),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }
}

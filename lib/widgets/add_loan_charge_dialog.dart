import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/charge_type.dart';
import '../services/charge_service.dart';
import '../services/loan_math.dart';
import '../core/firebase_service.dart';

/// Formats digits live as 1,234,567
class _ThousandsFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,###', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final formatted = _fmt.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AddLoanChargeDialog extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic> loanData;
  final VoidCallback onSuccess;

  const AddLoanChargeDialog({
    Key? key,
    required this.loanId,
    required this.loanData,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<AddLoanChargeDialog> createState() => _AddLoanChargeDialogState();
}

class _AddLoanChargeDialogState extends State<AddLoanChargeDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _customChargeNameCtrl = TextEditingController();
  final _currencyFormat = NumberFormat('#,###', 'en_US');

  List<ChargeType> _chargeTypes = [];
  ChargeType? _selectedType;
  bool _isCustomCharge = false;
  int? _selectedInstalment;
  DateTime _chargeDate = DateTime.now();
  int _suggestedAmount = 0;

  bool _loading = true;
  bool _submitting = false;
  bool _showConfirmation = false;

  // Inline validation (snackbars would hide behind the dialog barrier)
  String? _typeError;
  String? _nameError;
  String? _amountError;
  String? _notesError;
  String? _formError;

  static const _brand = Color(0xFF1E3A8A);
  static const _ink = Color(0xFF0F172A);
  static const _text = Color(0xFF334155);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE2E8F0);
  static const _hair = Color(0xFFF8FAFC);
  static const _amber = Color(0xFFB45309);
  static const _danger = Color(0xFFDC2626);

  static const _noteTemplates = [
    'Late payment penalty',
    'Administrative fee',
    'Recovery / legal cost',
    'Correction of earlier entry',
  ];

  @override
  void initState() {
    super.initState();
    _loadChargeTypes();
  }

  // ───────────────────────── data ─────────────────────────

  Future<void> _loadChargeTypes() async {
    var types = await ChargeService.getChargeTypes(activeOnly: true);

    if (types.isEmpty) {
      final tenantId = FirebaseService.sessionTenantId;
      await ChargeService.seedDefaultChargeTypes(tenantId);
      types = await ChargeService.getChargeTypes(activeOnly: true);
    }

    if (mounted) {
      setState(() {
        _chargeTypes = types;
        _loading = false;
      });
    }
  }

  // ───────────────────────── helpers ─────────────────────────

  TextStyle _t(double size,
      {FontWeight w = FontWeight.w400, Color c = _text, double? h}) {
    return GoogleFonts.inter(
        fontSize: size, fontWeight: w, color: c, height: h);
  }

  int _parseAmount() {
    final text = _amountCtrl.text.trim().replaceAll(',', '');
    return int.tryParse(text) ?? 0;
  }

  String _money(int amount) => _currencyFormat.format(amount);

  String get _chargeName => _isCustomCharge
      ? _customChargeNameCtrl.text.trim()
      : (_selectedType?.name ?? '');

  bool get _isToday {
    final n = DateTime.now();
    return _chargeDate.year == n.year &&
        _chargeDate.month == n.month &&
        _chargeDate.day == n.day;
  }

  String? _ctx(List<String> keys) {
    for (final k in keys) {
      final v = widget.loanData[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  InputDecoration _dec({
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? error,
  }) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: _t(13.5, c: const Color(0xFF94A3B8)),
      errorText: error,
      errorStyle: _t(11.5, c: _danger),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      prefixIcon: prefixIcon,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: b(_line),
      focusedBorder: b(_brand, 1.6),
      errorBorder: b(_danger),
      focusedErrorBorder: b(_danger, 1.6),
      border: b(_line),
    );
  }

  Widget _label(String text, {bool required = false, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(text, style: _t(12.5, w: FontWeight.w600, c: _ink)),
          if (required)
            Text(' *', style: _t(12.5, w: FontWeight.w600, c: _danger)),
          if (trailing != null) ...[
            const Spacer(),
            Text(trailing, style: _t(11.5, c: _muted)),
          ],
        ],
      ),
    );
  }

  // ───────────────────────── actions ─────────────────────────

  void _onChargeTypeChanged(ChargeType type) {
    setState(() {
      _selectedType = type;
      _isCustomCharge = false;
      _typeError = null;
      _formError = null;

      final suggested = ChargeService.suggestAmount(
        loan: widget.loanData,
        chargeType: type,
      );
      _suggestedAmount = suggested > 0 ? suggested.round() : 0;
      if (_suggestedAmount > 0) {
        _amountCtrl.text = _money(_suggestedAmount);
        _amountError = null;
      } else {
        _amountCtrl.clear();
      }
    });
  }

  void _onCustomChargeSelected() {
    setState(() {
      _selectedType = null;
      _isCustomCharge = true;
      _suggestedAmount = 0;
      _typeError = null;
      _formError = null;
      _amountCtrl.clear();
      _customChargeNameCtrl.clear();
    });
  }

  void _applyNoteTemplate(String text) {
    setState(() {
      _notesCtrl.text = text;
      _notesCtrl.selection =
          TextSelection.collapsed(offset: _notesCtrl.text.length);
      _notesError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chargeDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _chargeDate = picked);
  }

  bool _validate() {
    String? typeErr, nameErr, amountErr, notesErr;

    if (_selectedType == null && !_isCustomCharge) {
      typeErr = 'Select a charge type';
    }
    if (_isCustomCharge && _customChargeNameCtrl.text.trim().isEmpty) {
      nameErr = 'Enter a name for this charge';
    }
    if (_parseAmount() <= 0) {
      amountErr = 'Enter an amount greater than zero';
    }
    if (_notesCtrl.text.trim().isEmpty) {
      notesErr = 'A reason is required for the audit trail';
    }

    setState(() {
      _typeError = typeErr;
      _nameError = nameErr;
      _amountError = amountErr;
      _notesError = notesErr;
      _formError = null;
    });

    return typeErr == null &&
        nameErr == null &&
        amountErr == null &&
        notesErr == null;
  }

  Future<void> _submit({bool forceConfirm = false}) async {
    if (!_validate()) return;

    setState(() => _submitting = true);

    final chargeTypeId = _isCustomCharge ? 'custom_other' : _selectedType!.id;
    final chargeTypeName = _chargeName;

    final result = await ChargeService.addCharge(
      loanId: widget.loanId,
      chargeTypeId: chargeTypeId,
      chargeTypeName: chargeTypeName,
      scheduleItemId: null,
      instalmentNumber: _selectedInstalment,
      amount: _parseAmount(),
      chargeDate: _chargeDate,
      notes: _notesCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final messenger = ScaffoldMessenger.of(context);
      widget.onSuccess();
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Charge added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result['warning'] == true && !forceConfirm) {
      setState(() {
        _submitting = false;
        _showConfirmation = true;
      });
    } else {
      setState(() {
        _submitting = false;
        _formError = (result['message'] ?? 'Could not add charge').toString();
      });
    }
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width > 600 ? 520.0 : width - 32;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: 720),
        child: SizedBox(
          width: dialogWidth,
          child: _loading || _chargeTypes.isEmpty
              ? _buildLoading()
              : _showConfirmation
                  ? _buildConfirmation()
                  : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand),
          ),
          const SizedBox(height: 18),
          Text('Preparing charge types',
              style: _t(15, w: FontWeight.w600, c: _ink)),
          const SizedBox(height: 4),
          Text('This will only take a moment.', style: _t(12.5, c: _muted)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2F4FB0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.add_card_outlined,
                size: 21, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add loan charge',
                    style: _t(16.5, w: FontWeight.w700, c: _ink)),
                const SizedBox(height: 2),
                Text('Manually apply a charge to this loan',
                    style: _t(12, c: _muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, size: 20, color: _muted),
            onPressed: _submitting ? null : () => Navigator.pop(context),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildLoanContext() {
    final member = _ctx(['memberName', 'member_name', 'borrowerName']);
    final account =
        _ctx(['accountNumber', 'loanNumber', 'loanAccountNumber', 'loanNo']);
    if (member == null && account == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _hair,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, size: 18, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(member ?? '',
                overflow: TextOverflow.ellipsis,
                style: _t(13, w: FontWeight.w600, c: _ink)),
          ),
          if (account != null)
            Text(account, style: _t(12, c: _muted)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final duration = LoanMath.d(widget.loanData['duration']).toInt();
    final amount = _parseAmount();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLoanContext(),

                // ── Charge type ──
                _label('Charge type', required: true),
                DropdownButtonFormField<String>(
                  value: _isCustomCharge
                      ? 'custom'
                      : (_selectedType != null ? _selectedType!.id : null),
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _muted),
                  style: _t(13.5, w: FontWeight.w500, c: _ink),
                  decoration:
                      _dec(hint: 'Select charge type', error: _typeError),
                  items: [
                    ..._chargeTypes.map((type) => DropdownMenuItem<String>(
                          value: type.id,
                          child: Text(type.name,
                              overflow: TextOverflow.ellipsis,
                              style: _t(13.5, w: FontWeight.w500, c: _ink)),
                        )),
                    DropdownMenuItem<String>(
                      value: 'custom',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined,
                              size: 16, color: _brand),
                          const SizedBox(width: 8),
                          Text('Other (specify)',
                              style: _t(13.5, w: FontWeight.w600, c: _brand)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    if (value == 'custom') {
                      _onCustomChargeSelected();
                    } else {
                      _onChargeTypeChanged(
                          _chargeTypes.firstWhere((t) => t.id == value));
                    }
                  },
                ),

                // ── Custom name ──
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _isCustomCharge
                      ? Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Charge name', required: true),
                              TextField(
                                controller: _customChargeNameCtrl,
                                textCapitalization: TextCapitalization.words,
                                style: _t(13.5, c: _ink),
                                onChanged: (_) {
                                  if (_nameError != null) {
                                    setState(() => _nameError = null);
                                  }
                                },
                                decoration: _dec(
                                  hint: 'e.g. Court filing fee',
                                  error: _nameError,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),

                const SizedBox(height: 18),

                // ── Instalment ──
                _label('Related instalment', trailing: 'Optional'),
                DropdownButtonFormField<int>(
                  value: _selectedInstalment,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  menuMaxHeight: 320,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: _muted),
                  style: _t(13.5, w: FontWeight.w500, c: _ink),
                  decoration: _dec(hint: 'Not linked to a specific instalment'),
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text('Not linked to a specific instalment',
                          style: _t(13.5, c: _muted)),
                    ),
                    ...List.generate(duration, (i) {
                      final n = i + 1;
                      return DropdownMenuItem<int>(
                        value: n,
                        child: Text('Instalment #$n',
                            style: _t(13.5, w: FontWeight.w500, c: _ink)),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedInstalment = v),
                ),

                const SizedBox(height: 18),

                // ── Amount + Date side by side on wide, stacked on narrow ──
                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 420;
                  final amountField = _buildAmountField();
                  final dateField = _buildDateField();
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 11, child: amountField),
                        const SizedBox(width: 14),
                        Expanded(flex: 9, child: dateField),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      amountField,
                      const SizedBox(height: 18),
                      dateField,
                    ],
                  );
                }),

                // ── Suggested amount hint ──
                if (_selectedType != null &&
                    _selectedType!.calcBasis != 'manual_amount' &&
                    _suggestedAmount > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_outlined,
                            size: 15, color: _brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Suggested UGX ${_money(_suggestedAmount)} based on the loan terms',
                            style: _t(12, c: _brand, w: FontWeight.w500),
                          ),
                        ),
                        if (amount != _suggestedAmount)
                          InkWell(
                            onTap: () => setState(() {
                              _amountCtrl.text = _money(_suggestedAmount);
                              _amountError = null;
                            }),
                            child: Text('Reset',
                                style: _t(12, w: FontWeight.w700, c: _brand)),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── Notes ──
                _label('Reason / notes', required: true),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  minLines: 3,
                  maxLength: 250,
                  style: _t(13.5, c: _ink),
                  onChanged: (_) => setState(() => _notesError = null),
                  decoration: _dec(
                    hint: 'Explain why this charge is being applied',
                    error: _notesError,
                  ).copyWith(
                    counterStyle: _t(11, c: _muted),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _noteTemplates
                      .map((t) => ActionChip(
                            label: Text(t, style: _t(11.5, c: _text)),
                            onPressed: () => _applyNoteTemplate(t),
                            backgroundColor: _hair,
                            side: const BorderSide(color: _line),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 16),

                // ── Policy notice ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 16, color: _amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Charges are never applied automatically. This charge is only recorded because you are adding it manually.',
                          style: _t(11.5, c: _amber, h: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _danger.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: _danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_formError!,
                              style: _t(12, c: _danger, w: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        _buildFooter(amount),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Amount', required: true),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          style: _t(14, w: FontWeight.w600, c: _ink),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
            _ThousandsFormatter(),
          ],
          onChanged: (_) => setState(() => _amountError = null),
          decoration: _dec(
            hint: '0',
            error: _amountError,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Text('UGX', style: _t(12.5, w: FontWeight.w600, c: _muted)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Charge date', required: true),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: _muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('d MMM yyyy').format(_chargeDate),
                    style: _t(13.5, w: FontWeight.w500, c: _ink),
                  ),
                ),
                if (_isToday)
                  Text('Today', style: _t(11, w: FontWeight.w600, c: _brand)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(int amount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
      decoration: const BoxDecoration(
        color: _hair,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total to apply', style: _t(11, c: _muted)),
                const SizedBox(height: 2),
                Text(
                  amount > 0 ? 'UGX ${_money(amount)}' : 'UGX 0',
                  style: _t(15, w: FontWeight.w700, c: _ink),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _text,
              minimumSize: const Size(80, 44),
            ),
            child: Text('Cancel', style: _t(13.5, w: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _submitting ? null : () => _submit(),
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size(130, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text('Add charge', style: _t(13.5, w: FontWeight.w600, c: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    final amount = _parseAmount();
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _amber.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                size: 29, color: _amber),
          ),
          const SizedBox(height: 16),
          Text('Possible duplicate charge',
              style: _t(16.5, w: FontWeight.w700, c: _ink)),
          const SizedBox(height: 8),
          Text(
            'A "$_chargeName" charge was already added to this instalment today. Do you still want to add another?',
            textAlign: TextAlign.center,
            style: _t(13, c: _text, h: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hair,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: [
                _summaryRow('Charge type', _chargeName),
                const SizedBox(height: 10),
                _summaryRow('Amount', 'UGX ${_money(amount)}'),
                const SizedBox(height: 10),
                _summaryRow(
                    'Date', DateFormat('d MMM yyyy').format(_chargeDate)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _showConfirmation = false;
                    _submitting = false;
                  }),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    foregroundColor: _text,
                    side: const BorderSide(color: _line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Go back', style: _t(13.5, w: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() => _showConfirmation = false);
                          _submit(forceConfirm: true);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: _amber,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Add anyway',
                      style: _t(13.5, w: FontWeight.w600, c: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _t(12.5, c: _muted)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: _t(13, w: FontWeight.w600, c: _ink)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _customChargeNameCtrl.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../services/member_statement_service.dart';

/// Statement period selector - two-column layout on wide screens,
/// stacked on narrow screens.
class StatementDateSelector extends StatefulWidget {
  final String memberId;
  final String memberName;
  final Map<String, dynamic> memberData;
  final void Function(StatementResult result, String memberName,
      DateTime from, DateTime to) onStatementGenerated;

  const StatementDateSelector({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.memberData,
    required this.onStatementGenerated,
  });

  @override
  State<StatementDateSelector> createState() => _StatementDateSelectorState();
}

class _StatementDateSelectorState extends State<StatementDateSelector> {
  late DateTime _startDate;
  late DateTime _endDate;
  late DateTime _joinDate;
  bool _isGenerating = false;
  String? _errorMessage;
  String? _activePreset;

  final _dateFormat = DateFormat('dd MMM yyyy');
  final _money = NumberFormat('#,##0');

  static final DateTime _minDate = DateTime(2020);

  @override
  void initState() {
    super.initState();
    _joinDate = _getJoinDate();
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    _startDate = _joinDate.isAfter(oneYearAgo) ? _joinDate : oneYearAgo;
    _endDate = DateTime.now();
  }

  DateTime _getJoinDate() {
    try {
      final createdAt = widget.memberData['createdAt'];
      if (createdAt is Timestamp) return createdAt.toDate();
    } catch (_) {}
    return DateTime.now().subtract(const Duration(days: 365));
  }

  double _num(String key) =>
      (widget.memberData[key] as num?)?.toDouble() ?? 0;

  // ---------- presets ----------
  List<_Preset> get _presets {
    final now = DateTime.now();
    return [
      _Preset('30 days', now.subtract(const Duration(days: 30))),
      _Preset('3 months', DateTime(now.year, now.month - 3, now.day)),
      _Preset('6 months', DateTime(now.year, now.month - 6, now.day)),
      _Preset('12 months', DateTime(now.year - 1, now.month, now.day)),
      _Preset('This year', DateTime(now.year, 1, 1)),
      _Preset('Since joining', _joinDate),
    ];
  }

  void _applyPreset(_Preset p) {
    if (_isGenerating) return;
    setState(() {
      _startDate = p.start.isBefore(_minDate) ? _minDate : p.start;
      _endDate = DateTime.now();
      _activePreset = p.label;
    });
  }

  // ---------- pickers ----------
  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      );

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: _minDate,
      lastDate: _endDate,
      helpText: 'Select start date',
      builder: _pickerTheme,
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        _activePreset = null;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      helpText: 'Select end date',
      builder: _pickerTheme,
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
        _activePreset = null;
      });
    }
  }

  // ---------- generate ----------
  Future<void> _generateStatement() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final result = await MemberStatementService.generateForAdmin(
        memberId: widget.memberId,
        from: _startDate,
        to: _endDate,
      );
      if (!mounted) return;
      widget.onStatementGenerated(
          result, widget.memberName, _startDate, _endDate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _errorMessage = e.toString();
      });
    }
  }

  int get _days => _endDate.difference(_startDate).inDays + 1;

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF5F7FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final pad = constraints.maxWidth < 600 ? 16.0 : 24.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - pad * 2,
                  maxWidth: constraints.maxWidth - pad * 2,
                ),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 380, child: _buildMemberPanel()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildPeriodPanel()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMemberPanel(),
                          const SizedBox(height: 20),
                          _buildPeriodPanel(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= LEFT: MEMBER =================
  Widget _buildMemberPanel() {
    final savings = _num('savingsBalance');
    final wallet = _num('walletBalance');
    final total = savings + wallet;
    final initials = widget.memberName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile + balance card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.memberName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Acc: ${widget.memberData['accountNumber'] ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Total Balance',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'UGX ${_money.format(total)}',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _miniBalance('Savings', savings)),
                  const SizedBox(width: 12),
                  Expanded(child: _miniBalance('Wallet', wallet)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Member details
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(Icons.person_outline, 'Member Details'),
              const SizedBox(height: 16),
              _detailRow('Joined', _dateFormat.format(_joinDate)),
              if (widget.memberData['phone'] != null)
                _detailRow('Phone', '${widget.memberData['phone']}'),
              if (widget.memberData['status'] != null)
                _detailRow('Status', '${widget.memberData['status']}'),
              _detailRow('Member ID', widget.memberId, last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniBalance(String label, double value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 2),
          Text(
            _money.format(value),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= RIGHT: PERIOD =================
  Widget _buildPeriodPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Page heading
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.description_rounded,
                  color: AppTheme.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate Statement',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Choose a period and produce a PDF statement',
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
        const SizedBox(height: 20),

        // Quick select
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(Icons.bolt_rounded, 'Quick Select'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presets.map((p) {
                  final selected = _activePreset == p.label;
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: selected,
                    onSelected: _isGenerating ? null : (_) => _applyPreset(p),
                    showCheckmark: false,
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.primary.withOpacity(0.25),
                    ),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : AppTheme.textPrimary,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Custom range
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(Icons.calendar_month, 'Custom Period'),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Start Date',
                      date: _startDate,
                      dateFormat: _dateFormat,
                      onTap: _isGenerating ? null : _selectStartDate,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child:
                        Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                  ),
                  Expanded(
                    child: _DatePickerField(
                      label: 'End Date',
                      date: _endDate,
                      dateFormat: _dateFormat,
                      onTap: _isGenerating ? null : _selectEndDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                        Icons.timelapse, 'Coverage', '$_days days'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statTile(Icons.flag_outlined, 'Closing Balance',
                        'UGX ${_money.format(_num('savingsBalance') + _num('walletBalance'))}'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The closing balance on the statement will match the member\'s current balance.',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline,
                    color: Colors.red.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Generate button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isGenerating ? null : _generateStatement,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isGenerating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                else
                  const Icon(Icons.picture_as_pdf, size: 22),
                const SizedBox(width: 12),
                Text(
                  _isGenerating
                      ? 'Generating Statement...'
                      : 'Generate Statement',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= helpers =================
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Preset {
  final String label;
  final DateTime start;
  const _Preset(this.label, this.start);
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateFormat dateFormat;
  final VoidCallback? onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: disabled
                    ? Colors.grey.shade200
                    : AppTheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: disabled ? Colors.grey.shade50 : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: disabled ? Colors.grey.shade400 : AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dateFormat.format(date),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: disabled
                          ? Colors.grey.shade500
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
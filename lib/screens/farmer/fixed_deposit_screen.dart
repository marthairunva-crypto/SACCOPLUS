import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FIXED DEPOSITS — Member Screen
// ═══════════════════════════════════════════════════════════════════════════

class FixedDepositScreen extends StatefulWidget {
  const FixedDepositScreen({super.key});
  @override
  State<FixedDepositScreen> createState() => _FixedDepositScreenState();
}

class _FixedDepositScreenState extends State<FixedDepositScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final fmt = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _deposits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseService.sessionUid;
    if (uid.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    setState(() => _loading = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection(AppConstants.fixedDepositCol)
          .where('memberId', isEqualTo: uid)
          .get(const GetOptions(source: Source.server));
      final docs = q.docs.map((d) => d.data()).toList();
      docs.sort((a, b) {
        final ta = a['createdAt']; final tb = b['createdAt'];
        if (ta == null || tb == null) return 0;
        return (tb as Timestamp).compareTo(ta as Timestamp);
      });
      if (!mounted) return;
      setState(() { _deposits = docs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Summary stats ──────────────────────────────────────────────────────
  int get _totalPrincipal => _deposits.fold(0, (s, d) => s + ((d['principal'] as num?)?.toInt() ?? 0));
  int get _totalInterest  => _deposits.fold(0, (s, d) => s + ((d['interestEarned'] as num?)?.toInt() ?? 0));
  int get _activeCount    => _deposits.where((d) => (d['status'] as String?) == 'Active').length;
  int get _maturedCount   => _deposits.where((d) => (d['status'] as String?) == 'Matured').length;

  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'Fixed Deposits',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _load,
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: AppTheme.accent,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'My Deposits'), Tab(text: 'New Deposit')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _DepositsTab(deposits: _deposits, fmt: fmt,
                    totalPrincipal: _totalPrincipal, totalInterest: _totalInterest,
                    activeCount: _activeCount, maturedCount: _maturedCount),
                _NewDepositTab(onSubmitted: () { _load(); _tabs.animateTo(0); }),
              ],
            ),
    );
  }
}

// ─── Deposits Tab ─────────────────────────────────────────────────────────────
class _DepositsTab extends StatelessWidget {
  final List<Map<String, dynamic>> deposits;
  final NumberFormat fmt;
  final int totalPrincipal, totalInterest, activeCount, maturedCount;

  const _DepositsTab({
    required this.deposits, required this.fmt,
    required this.totalPrincipal, required this.totalInterest,
    required this.activeCount, required this.maturedCount,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF071A45), Color(0xFF1A3F8F)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Fixed Deposit Portfolio', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              Text('UGX ${fmt.format(totalPrincipal + totalInterest)}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Principal: UGX ${fmt.format(totalPrincipal)}  •  Interest: UGX ${fmt.format(totalInterest)}',
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
              const SizedBox(height: 14),
              Row(children: [
                _pill('$activeCount Active', AppTheme.success),
                const SizedBox(width: 8),
                _pill('$maturedCount Matured', AppTheme.accent),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          if (deposits.isEmpty)
            const EmptyState(
              message: 'No fixed deposits yet.\nTap "New Deposit" to open your first fixed deposit account.',
              icon: Icons.account_balance_outlined,
            )
          else ...[
            Text('Your Deposits',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            ...deposits.map((d) => _DepositCard(deposit: d, fmt: fmt)),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ─── Deposit Card ─────────────────────────────────────────────────────────────
class _DepositCard extends StatelessWidget {
  final Map<String, dynamic> deposit;
  final NumberFormat fmt;
  const _DepositCard({required this.deposit, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final principal    = (deposit['principal'] as num?)?.toInt() ?? 0;
    final interestRate = (deposit['interestRate'] as num?)?.toDouble() ?? 0.0;
    final termMonths   = (deposit['termMonths'] as num?)?.toInt() ?? 0;
    final status       = deposit['status'] as String? ?? 'Pending';
    final interestEarned = (deposit['interestEarned'] as num?)?.toInt() ?? 0;
    final withholding  = (deposit['withholdingTax'] as num?)?.toInt() ?? 0;
    final maturityDate = deposit['maturityDate'] as String? ?? '—';
    final rollover     = deposit['rollover'] as bool? ?? false;

    // Parse maturity date
    String maturityStr = maturityDate;
    try {
      if (maturityDate != '—') {
        maturityStr = DateFormat('MMM d, yyyy').format(DateTime.parse(maturityDate));
      }
    } catch (_) {}

    Color statusColor;
    switch (status) {
      case 'Active':   statusColor = AppTheme.success; break;
      case 'Matured':  statusColor = AppTheme.accent;  break;
      case 'Closed':   statusColor = AppTheme.textSecondary; break;
      default:         statusColor = AppTheme.warning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.account_balance_rounded, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('UGX ${fmt.format(principal)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
                    Text('$termMonths months  •  ${interestRate.toStringAsFixed(1)}% p.a.',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(status,
                      style: GoogleFonts.poppins(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Interest Earned', 'UGX ${fmt.format(interestEarned)}', AppTheme.success),
              _row('Withholding Tax (15%)', 'UGX ${fmt.format(withholding)}', AppTheme.error),
              _row('Net Interest', 'UGX ${fmt.format(interestEarned - withholding)}', AppTheme.primary),
              _row('Maturity Date', maturityStr, AppTheme.textPrimary),
              _row('Auto-Rollover', rollover ? 'Yes' : 'No', rollover ? AppTheme.success : AppTheme.textSecondary),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    ),
  );
}

// ─── New Deposit Tab ──────────────────────────────────────────────────────────
class _NewDepositTab extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _NewDepositTab({required this.onSubmitted});
  @override
  State<_NewDepositTab> createState() => _NewDepositTabState();
}

class _NewDepositTabState extends State<_NewDepositTab> {
  final _amountCtrl = TextEditingController();
  int _termMonths = 3;
  bool _rollover = false;
  bool _loading = false;
  final fmt = NumberFormat('#,###', 'en_US');

  // SACCO fixed deposit rates (configurable)
  static const Map<int, double> _rates = {
    3:  8.0,
    6:  10.0,
    12: 13.0,
    24: 15.0,
  };

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _rate => _rates[_termMonths] ?? 8.0;

  int get _principal => int.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;

  double get _grossInterest => _principal * (_rate / 100) * (_termMonths / 12);
  double get _withholdingTax => _grossInterest * 0.15;
  double get _netInterest => _grossInterest - _withholdingTax;
  int get _maturityValue => _principal + _netInterest.round();

  DateTime get _maturityDate => DateTime.now().add(Duration(days: _termMonths * 30));

  Future<void> _submit() async {
    if (_principal < 100000) {
      _snack('Minimum fixed deposit is UGX 100,000', AppTheme.error);
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      final id = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection(AppConstants.fixedDepositCol)
          .doc(id)
          .set({
        'id': id,
        'memberId': uid,
        'memberName': FirebaseService.sessionProfile?['name'] ?? '',
        'principal': _principal,
        'interestRate': _rate,
        'termMonths': _termMonths,
        'grossInterest': _grossInterest.round(),
        'withholdingTax': _withholdingTax.round(),
        'interestEarned': _netInterest.round(),
        'maturityValue': _maturityValue,
        'maturityDate': _maturityDate.toIso8601String(),
        'rollover': _rollover,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _snack('Fixed deposit application submitted! Admin will process it.', AppTheme.success);
      _amountCtrl.clear();
      setState(() {});
      widget.onSubmitted();
    } catch (e) {
      _snack('Error: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open Fixed Deposit',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Earn higher interest by locking your savings for a fixed term.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),

          // ── Amount ────────────────────────────────────────────────────
          Text('Principal Amount (UGX)',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.attach_money_rounded),
              hintText: 'Min UGX 100,000',
            ),
          ),

          const SizedBox(height: 20),

          // ── Term selection ────────────────────────────────────────────
          Text('Select Term',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Row(children: _rates.entries.map((e) {
            final selected = _termMonths == e.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _termMonths = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Text('${e.key}mo',
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppTheme.textPrimary)),
                    Text('${e.value}%',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: selected ? Colors.white70 : AppTheme.textSecondary)),
                  ]),
                ),
              ),
            );
          }).toList()),

          const SizedBox(height: 20),

          // ── Interest preview ──────────────────────────────────────────
          if (_principal >= 100000) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.success.withOpacity(0.2)),
              ),
              child: Column(children: [
                _previewRow('Principal', 'UGX ${fmt.format(_principal)}', AppTheme.textPrimary),
                _previewRow('Interest Rate', '${_rate.toStringAsFixed(1)}% p.a.', AppTheme.primary),
                _previewRow('Gross Interest', 'UGX ${fmt.format(_grossInterest.round())}', AppTheme.success),
                _previewRow('Withholding Tax (15%)', '- UGX ${fmt.format(_withholdingTax.round())}', AppTheme.error),
                const Divider(height: 16),
                _previewRow('Net Interest', 'UGX ${fmt.format(_netInterest.round())}', AppTheme.success),
                _previewRow('Maturity Value', 'UGX ${fmt.format(_maturityValue)}', AppTheme.primary),
                _previewRow('Maturity Date', DateFormat('MMM d, yyyy').format(_maturityDate), AppTheme.textPrimary),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // ── Auto-rollover ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Auto-Rollover',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text('Automatically renew at maturity for the same term',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
              ])),
              Switch(
                value: _rollover,
                onChanged: (v) => setState(() => _rollover = v),
                activeColor: AppTheme.primary,
              ),
            ]),
          ),

          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Submit Fixed Deposit Application',
            loading: _loading,
            onPressed: _submit,
            icon: Icons.account_balance_rounded,
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Fixed deposits are processed by the SACCO admin. '
                  'Early withdrawal may attract a penalty of 2% of principal.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.warning),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, Color valueColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
      Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor)),
    ]),
  );
}

// ── UUID helper (avoid importing uuid package directly) ───────────────────────
class Uuid {
  const Uuid();
  String v4() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${now.toRadixString(16)}-fd-${(now * 1000).toRadixString(16)}';
  }
}

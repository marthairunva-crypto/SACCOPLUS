import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';
import 'farmer_scaffold.dart';
import 'receipt_screen.dart';

class RepaymentScreen extends StatefulWidget {
  final bool embedded;
  const RepaymentScreen({super.key, this.embedded = false});

  @override
  State<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends State<RepaymentScreen> {
  final fmt = NumberFormat('#,###', 'en_US');
  bool _paying = false;
  bool _loading = true;

  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _repayments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = _loans.isEmpty);
    final memberId = FirebaseService.sessionUid;
    final loans = await FirebaseService.getFarmerLoansOnce(memberId);
    final reps = await FirebaseService.getFarmerRepaymentsOnce(memberId);
    if (!mounted) return;
    setState(() {
      _loans = loans;
      _repayments = reps.map((d) {
        final ts = d['paidAt'];
        String dateStr = '—';
        if (ts is Timestamp) {
          dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
        }
        return {...d, 'dateStr': dateStr};
      }).toList();
      _loading = false;
    });
  }

  Future<void> _makePayment(BuildContext context, Map<String, dynamic> loan) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentSheet(loan: loan, fmt: fmt),
    );

    if (result == null || !mounted) return;

    final amount = result['amount'] as int;
    final phone = result['phone'] as String;

    setState(() => _paying = true);

    // Use a completer to close the pending dialog safely
    BuildContext? dialogCtx;

    try {
      final marzResult = await FirebaseService.marzPayCollect(
        phoneNumber: phone,
        amount: amount,
        description: 'Loan repayment – ${loan['purpose'] ?? ''}',
      );

      if (!mounted) return;

      // Show pending dialog and capture its context
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogCtx = ctx;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(height: 16),
                Text('Waiting for payment...',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                Text('Please approve the prompt on your phone.',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        },
      );

      final uuid = marzResult['uuid'] as String;
      String status = 'processing';
      for (int i = 0; i < 18; i++) {
        await Future.delayed(const Duration(seconds: 5));
        try {
          status = await FirebaseService.marzPayCheckStatus(uuid);
        } catch (_) {}
        if (status == 'completed' || status == 'failed' || status == 'cancelled') break;
      }

      if (!mounted) return;
      // Close only the dialog using its own context
      if (dialogCtx != null && Navigator.of(dialogCtx!).canPop()) {
        Navigator.of(dialogCtx!).pop();
      }

      if (status == 'completed') {
        await FirebaseService.makeRepayment({
          'loanId': loan['id'] ?? '',
          'amount': amount,
          'purpose': loan['purpose'] ?? '',
          'phone': phone,
          'provider': marzResult['provider'],
          'marzReference': marzResult['reference'],
          'marzUuid': uuid,
          'paymentMethod': 'mobile_money',
        });
        if (!mounted) return;
        _showResultDialog(context, success: true, amount: amount);
        _load();
        // Auto-show receipt
        final profile = FirebaseService.sessionProfile;
        final farmerName = profile?['name'] as String? ?? 'Member';
        final repaymentData = {
          'amount': amount,
          'phone': phone,
          'purpose': loan['purpose'] ?? '',
          'provider': marzResult['provider'],
          'marzUuid': marzResult['uuid'],
          'marzReference': marzResult['reference'],
          'dateStr': DateFormat('MMM d, yyyy').format(DateTime.now()),
        };
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ReceiptScreen(
                repayment: repaymentData,
                farmerName: farmerName,
              ),
            ));
          }
        });
      } else {
        _showResultDialog(context, success: false, amount: amount);
      }
    } catch (e) {
      if (!mounted) return;
      if (dialogCtx != null && Navigator.of(dialogCtx!).canPop()) {
        Navigator.of(dialogCtx!).pop();
      }
      final msg = e.toString().contains('Failed to fetch')
          ? 'Payment blocked by browser (CORS). Please use the Android app to make payments.'
          : 'Payment failed: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 6),
      ));
    }
    if (mounted) setState(() => _paying = false);
  }

  void _showResultDialog(BuildContext context, {required bool success, required int amount}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: (success ? AppTheme.success : AppTheme.error).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: success ? AppTheme.success : AppTheme.error,
                size: 44,
              ),
            ),
            const SizedBox(height: 12),
            Text(success ? 'Payment Successful!' : 'Payment Failed',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              success
                  ? 'UGX ${fmt.format(amount)} received successfully.'
                  : 'The payment was not completed.\nPlease try again.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'OK', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, Map<String, dynamic> r) {
    final provider = r['provider'] as String?;
    final providerLabel = provider == 'mtn' ? 'MTN Mobile Money'
        : provider == 'airtel' ? 'Airtel Money' : 'Mobile Money';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.success, size: 26),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Payment Successful',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                Text(r['dateStr'] ?? '—',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _detailRow('Amount', 'UGX ${fmt.format((r['amount'] as num?)?.toInt() ?? 0)}'),
            _detailRow('Network', providerLabel),
            _detailRow('Phone', r['phone'] ?? '—'),
            _detailRow('Purpose', r['purpose'] ?? '—'),
            if ((r['marzUuid'] as String?)?.isNotEmpty == true)
              _detailRow('Transaction ID', r['marzUuid'] as String),
            if ((r['marzReference'] as String?)?.isNotEmpty == true)
              _detailRow('Reference', r['marzReference'] as String),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final profile = FirebaseService.sessionProfile;
                  final farmerName = profile?['name'] as String? ?? 'Member';
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReceiptScreen(
                      repayment: r,
                      farmerName: farmerName,
                    ),
                  ));
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text('View Receipt',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget _appBar({required Widget body}) => widget.embedded
        ? Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Repayments',
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
            ),
            body: body,
          )
        : FarmerScaffold(title: 'Repayments', body: body);

    if (_loading) {
      return _appBar(
        body: const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final activeLoans = _loans
        .where((l) => l['status'] == 'Approved' || l['status'] == 'Active')
        .toList();

    final totalDue = activeLoans.fold<int>(0, (s, l) => s + ((l['amount'] as num?)?.toInt() ?? 0));
    final totalRepaid = _repayments.fold<int>(0, (s, r) => s + ((r['amount'] as num?)?.toInt() ?? 0));
    final outstanding = (totalDue - totalRepaid).clamp(0, totalDue);

    return _appBar(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Outstanding Balance',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('UGX ${fmt.format(outstanding)}',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    '${activeLoans.length} active loan${activeLoans.length == 1 ? '' : 's'}  •  Total repaid: UGX ${fmt.format(totalRepaid)}',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (activeLoans.isNotEmpty) ...[
              SectionHeader(title: 'Active Loans'),
              const SizedBox(height: 10),
              ...activeLoans.map((loan) => _ActiveLoanTile(
                    loan: loan, fmt: fmt, paying: _paying,
                    onPay: () => _makePayment(context, loan),
                  )),
            ],

            if (activeLoans.isEmpty && _repayments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: EmptyState(
                  message: 'No repayments yet.\nRepayments will appear here once you have an active loan.',
                  icon: Icons.payments_outlined,
                ),
              ),

            if (_repayments.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionHeader(title: 'Payment History'),
              const SizedBox(height: 10),
              ..._repayments.map((r) => GestureDetector(
                  onTap: () => _showTransactionDetail(context, r),
                  child: _RepaymentHistoryTile(item: r, fmt: fmt),
                )),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── Payment Bottom Sheet ─────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final Map<String, dynamic> loan;
  final NumberFormat fmt;
  const _PaymentSheet({required this.loan, required this.fmt});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _network = 'MTN';

  static const _networks = ['MTN', 'Airtel'];
  static const _networkIcons = {
    'MTN': Icons.signal_cellular_alt_rounded,
    'Airtel': Icons.signal_cellular_alt_2_bar_rounded,
  };
  static const _networkColors = {
    'MTN': Color(0xFFFFCC00),
    'Airtel': Color(0xFFE40000),
  };

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final amount = int.tryParse(_amountCtrl.text.trim());
    final rawPhone = _phoneCtrl.text.trim();
    if (amount == null || amount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount (min UGX 500)')));
      return;
    }
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your mobile money number')));
      return;
    }
    final phone = FirebaseService.formatPhoneForMarzPay(rawPhone);
    Navigator.pop(context, {'amount': amount, 'phone': phone});
  }

  @override
  Widget build(BuildContext context) {
    final loanAmount = (widget.loan['amount'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Make Repayment',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              '${widget.loan['purpose'] ?? '—'}  •  UGX ${widget.fmt.format(loanAmount)}',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            Text('Select Network',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: _networks.map((n) {
                final selected = _network == n;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _network = n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: n == 'MTN' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: selected ? _networkColors[n]!.withOpacity(0.12) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _networkColors[n]! : Colors.grey.shade200,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_networkIcons[n],
                              color: selected ? _networkColors[n] : Colors.grey, size: 20),
                          const SizedBox(width: 6),
                          Text(n,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: selected ? _networkColors[n] : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Text('Mobile Money Number',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: _network == 'MTN'
                    ? '+256771234567'
                    : '+256701234567',
                prefixIcon: const Icon(Icons.phone_android_rounded),
                helperText: 'Include country code e.g. +256...',
              ),
            ),

            const SizedBox(height: 14),
            Text('Payment Amount (UGX)',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 50000',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text('Pay via $_network Mobile Money',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _networkColors[_network],
                  foregroundColor: _network == 'MTN' ? Colors.black87 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tiles ────────────────────────────────────────────────────────────────────

class _ActiveLoanTile extends StatelessWidget {
  final Map<String, dynamic> loan;
  final NumberFormat fmt;
  final bool paying;
  final VoidCallback onPay;

  const _ActiveLoanTile({
    required this.loan, required this.fmt,
    required this.paying, required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UGX ${fmt.format((loan['amount'] as num?)?.toInt() ?? 0)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(loan['purpose'] ?? '—',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
                Text(loan['repaymentPeriod'] ?? '—',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: paying ? null : onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }
}

class _RepaymentHistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat fmt;

  const _RepaymentHistoryTile({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final provider = item['provider'] as String?;
    final providerLabel = provider == 'mtn'
        ? 'MTN MoMo'
        : provider == 'airtel'
            ? 'Airtel Money'
            : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UGX ${fmt.format((item['amount'] as num?)?.toInt() ?? 0)}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                Text('Paid on ${item['dateStr'] ?? '—'}',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                if (providerLabel != null)
                  Text(providerLabel,
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text('PAID',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
          ),
        ],
      ),
    );
  }
}

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

class SharesScreen extends StatefulWidget {
  const SharesScreen({super.key});
  @override
  State<SharesScreen> createState() => _SharesScreenState();
}

class _SharesScreenState extends State<SharesScreen>
    with SingleTickerProviderStateMixin {
  final fmt = NumberFormat('#,###', 'en_US');
  late TabController _tabs;

  Map<String, dynamic> _sharesData = {
    'totalShares': 0,
    'shareValue': 1000,   // UGX per share
    'totalValue': 0,
    'dividendsEarned': 0,
    'ownershipPercent': 0.0,
  };
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
      // Use new backend method to get share holdings
      final shareHoldings = await FirebaseService.getShareHoldings(uid);
      
      final totalShares = shareHoldings['totalShares'] as int? ?? 0;
      final shareValue = shareHoldings['shareValue'] as int? ?? 0;
      final transactions = shareHoldings['transactions'] as List<Map<String, dynamic>>? ?? [];

      // Load dividends
      final divQ = await FirebaseFirestore.instance
          .collection(AppConstants.dividendsCol)
          .where('uid', isEqualTo: uid)
          .get();
      final totalDividends = divQ.docs.fold<int>(
          0, (s, d) => s + ((d['dividendAmount'] as num?)?.toInt() ?? 0));

      final pricePerShare = 1000; // Default share price
      final totalValue = totalShares * pricePerShare;
      final ownershipPercent = 0.0; // Calculate based on total SACCO shares

      if (!mounted) return;
      setState(() {
        _sharesData = {
          'totalShares': totalShares,
          'shareValue': pricePerShare,
          'totalValue': totalValue,
          'dividendsEarned': totalDividends,
          'ownershipPercent': ownershipPercent,
        };
        _transactions = transactions.map((d) {
          final ts = d['timestamp'];
          String dateStr = '—';
          if (ts is Timestamp) dateStr = DateFormat('MMM d, yyyy').format(ts.toDate());
          return {...d, 'dateStr': dateStr};
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'My Shares',
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
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'History'),
          Tab(text: 'Buy Shares'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(data: _sharesData, fmt: fmt),
                _HistoryTab(transactions: _transactions, fmt: fmt),
                _BuySharesTab(
                  shareValue: (_sharesData['shareValue'] as int?) ?? 1000,
                  onPurchased: _load,
                ),
              ],
            ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat fmt;
  const _OverviewTab({required this.data, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final totalShares = data['totalShares'] as int;
    final shareValue = data['shareValue'] as int;
    final totalValue = data['totalValue'] as int;
    final dividends = data['dividendsEarned'] as int;
    final ownership = (data['ownershipPercent'] as double?) ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF071A45), Color(0xFF0D2B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D2B6B).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Share Portfolio',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                Text('UGX ${fmt.format(totalValue)}',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$totalShares shares  •  UGX ${fmt.format(shareValue)} per share',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            Expanded(child: _StatBox(
              label: 'Total Shares',
              value: '$totalShares',
              icon: Icons.confirmation_number_rounded,
              color: AppTheme.primary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(
              label: 'Dividends Earned',
              value: 'UGX ${fmt.format(dividends)}',
              icon: Icons.monetization_on_rounded,
              color: AppTheme.accent,
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatBox(
              label: 'Share Value',
              value: 'UGX ${fmt.format(shareValue)}',
              icon: Icons.price_change_rounded,
              color: AppTheme.primaryLight,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatBox(
              label: 'Ownership',
              value: '${ownership.toStringAsFixed(2)}%',
              icon: Icons.donut_large_rounded,
              color: AppTheme.accentDark,
            )),
          ]),

          const SizedBox(height: 20),

          // Ownership bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SACCO Ownership',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (ownership / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Text('You own ${ownership.toStringAsFixed(2)}% of the SACCO',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.info.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dividends are declared annually by the SACCO board based on profits.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.info),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final NumberFormat fmt;
  const _HistoryTab({required this.transactions, required this.fmt});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const EmptyState(
        message: 'No share transactions yet.\nPurchase shares to get started.',
        icon: Icons.pie_chart_outline_rounded,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (_, i) {
        final t = transactions[i];
        final type = t['type'] as String? ?? 'Purchase';
        final shares = (t['shares'] as num?)?.toInt() ?? 0;
        final amount = (t['amount'] as num?)?.toInt() ?? 0;
        final date = t['dateStr'] as String? ?? '—';
        final isBuy = type == 'Purchase';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (isBuy ? AppTheme.primary : AppTheme.accent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isBuy ? Icons.add_chart_rounded : Icons.monetization_on_rounded,
                color: isBuy ? AppTheme.primary : AppTheme.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$shares shares  •  $date',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            ])),
            Text(
              'UGX ${fmt.format(amount)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 13,
                color: isBuy ? AppTheme.primary : AppTheme.accent,
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Buy Shares Tab ───────────────────────────────────────────────────────────
class _BuySharesTab extends StatefulWidget {
  final int shareValue;
  final VoidCallback onPurchased;
  const _BuySharesTab({required this.shareValue, required this.onPurchased});
  @override
  State<_BuySharesTab> createState() => _BuySharesTabState();
}

class _BuySharesTabState extends State<_BuySharesTab> {
  final _sharesCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  bool _showPinOtp = false;
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  void dispose() {
    _sharesCtrl.dispose();
    _pinCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  int get _totalCost {
    final n = int.tryParse(_sharesCtrl.text.trim()) ?? 0;
    return n * widget.shareValue;
  }

  Future<void> _sendOTP() async {
    final shares = int.tryParse(_sharesCtrl.text.trim());
    if (shares == null || shares < 1) {
      _snack('Enter a valid number of shares (min 1)', AppTheme.error);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      final profile = await FirebaseService.getUserProfile(uid);
      final phone = profile?['phone'] as String?;
      
      if (phone == null) {
        _snack('Phone number not found. Please update your profile.', AppTheme.error);
        return;
      }

      await FirebaseService.sendOtp(phone);
      setState(() {
        _otpSent = true;
        _showPinOtp = true;
      });
      _snack('OTP sent to your phone. Please enter PIN and OTP to continue.', AppTheme.success);
    } catch (e) {
      _snack('Error sending OTP: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final shares = int.tryParse(_sharesCtrl.text.trim());
    final pin = _pinCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (shares == null || shares < 1) {
      _snack('Enter a valid number of shares (min 1)', AppTheme.error);
      return;
    }

    if (pin.length != 4) {
      _snack('Enter your 4-digit PIN', AppTheme.error);
      return;
    }

    if (otp.length != 6) {
      _snack('Enter the 6-digit OTP sent to your phone', AppTheme.error);
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseService.sessionUid;
      
      // Use new secure backend method
      await FirebaseService.purchaseShares(
        uid: uid,
        numberOfShares: shares,
        pricePerShare: widget.shareValue,
        pin: pin,
        otpCode: otp,
        description: 'Share purchase via mobile app',
      );
      
      _snack('Shares purchased successfully! Amount deducted from wallet.', AppTheme.success);
      _sharesCtrl.clear();
      _pinCtrl.clear();
      _otpCtrl.clear();
      setState(() {
        _showPinOtp = false;
        _otpSent = false;
      });
      widget.onPurchased();
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
          Text('Purchase Shares',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Secure purchase with PIN + OTP verification. Amount will be deducted from your wallet.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),

          const SizedBox(height: 20),

          // Share price info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.price_change_rounded, color: AppTheme.primary, size: 22),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Current Share Price',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                Text('UGX ${fmt.format(widget.shareValue)}',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primary)),
              ]),
            ]),
          ),

          const SizedBox(height: 20),
          TextField(
            controller: _sharesCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Number of Shares',
              prefixIcon: Icon(Icons.confirmation_number_rounded),
              hintText: 'e.g. 10',
            ),
          ),

          // Live cost preview
          if (_sharesCtrl.text.isNotEmpty && _totalCost > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Cost',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
                  Text('UGX ${fmt.format(_totalCost)}',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.success)),
                ],
              ),
            ),
          ],

          if (_showPinOtp) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 20),
                    const SizedBox(width: 8),
                    Text('Security Verification', 
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.success)),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '4-Digit PIN',
                      prefixIcon: Icon(Icons.lock_rounded),
                      hintText: '••••',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    decoration: const InputDecoration(
                      labelText: '6-Digit OTP',
                      prefixIcon: Icon(Icons.sms_rounded),
                      hintText: '123456',
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          if (!_showPinOtp)
            PrimaryButton(
              label: 'Send OTP & Continue',
              loading: _loading,
              onPressed: _sendOTP,
              icon: Icons.sms_rounded,
            )
          else
            PrimaryButton(
              label: 'Complete Purchase',
              loading: _loading,
              onPressed: _submit,
              icon: Icons.add_chart_rounded,
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

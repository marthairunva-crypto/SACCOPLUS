import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import 'farmer_scaffold.dart';

// ── Utility definitions ───────────────────────────────────────────────────────
class _Utility {
  final String code;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Utility(this.code, this.name, this.subtitle, this.icon, this.color);
}

const _utilities = [
  _Utility('LIGHT', 'Electricity', 'UEDCL prepaid meter', Icons.bolt_rounded, Color(0xFFF59E0B)),
  _Utility('NWSC',  'Water',       'NWSC water bill',     Icons.water_drop_rounded, Color(0xFF3B82F6)),
  _Utility('DSTV',  'DSTV',        'TV subscription',     Icons.tv_rounded, Color(0xFF8B5CF6)),
  _Utility('GOTV',  'GOTV',        'TV subscription',     Icons.live_tv_rounded, Color(0xFF10B981)),
];

// ── Screen ────────────────────────────────────────────────────────────────────
class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({super.key});
  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  _Utility? _selected;

  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'Pay Bills',
      body: _selected == null ? _buildPicker() : _buildForm(_selected!),
    );
  }

  Widget _buildPicker() {
    final fmt = NumberFormat('#,###');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pay electricity, water, and TV bills directly from your wallet. Fixed charge: UGX ${fmt.format(1500)} per transaction.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          Text('Select Service',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Utility grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: _utilities.map((u) => _utilityCard(u)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _utilityCard(_Utility u) {
    return GestureDetector(
      onTap: () => setState(() => _selected = u),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: u.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(u.icon, color: u.color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(u.name,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(u.subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(_Utility utility) {
    return _BillForm(
      utility: utility,
      onBack: () => setState(() => _selected = null),
    );
  }
}

// ── Bill Form ─────────────────────────────────────────────────────────────────
enum _FormState { idle, verifying, verified, paying, success, error }

class _BillForm extends StatefulWidget {
  final _Utility utility;
  final VoidCallback onBack;
  const _BillForm({required this.utility, required this.onBack, super.key});

  @override
  State<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<_BillForm> {
  final fmt = NumberFormat('#,###');
  final _meterCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _tokenPhoneCtrl = TextEditingController(); // alternate phone for electricity token

  _FormState _state = _FormState.idle;
  String _errorMsg = '';
  String _successMsg = '';

  // NWSC
  List<String> _nwscAreas = [];
  String? _selectedArea;

  // DSTV/GOTV
  List<Map<String, dynamic>> _bouquets = [];
  Map<String, dynamic>? _selectedBouquet;

  // Verified customer
  Map<String, dynamic>? _customer;

  @override
  void initState() {
    super.initState();
    if (widget.utility.code == 'NWSC') _loadNwscAreas();
    if (widget.utility.code == 'DSTV') _loadBouquets('dstv');
    if (widget.utility.code == 'GOTV') _loadBouquets('gotv');
  }

  @override
  void dispose() {
    _meterCtrl.dispose();
    _amountCtrl.dispose();
    _tokenPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNwscAreas() async {
    final areas = await FirebaseService.getNwscAreas();
    if (mounted) setState(() => _nwscAreas = areas);
  }

  Future<void> _loadBouquets(String type) async {
    final list = type == 'dstv'
        ? await FirebaseService.getDstvBouquets()
        : await FirebaseService.getGotvBouquets();
    if (mounted) setState(() => _bouquets = list);
  }

  Future<void> _verify() async {
    final meter = _meterCtrl.text.trim();
    if (meter.isEmpty) { _snack('Enter meter/account number', AppTheme.warning); return; }
    if (widget.utility.code == 'NWSC' && _selectedArea == null) {
      _snack('Select an area', AppTheme.warning); return;
    }

    setState(() { _state = _FormState.verifying; _customer = null; });
    try {
      final result = await FirebaseService.verifyBillMeter(
        utilityCode: widget.utility.code,
        meterNumber: meter,
        area: _selectedArea,
      );
      if (!mounted) return;
      setState(() {
        _state = _FormState.verified;
        _customer = result;
        // For DSTV/GOTV, pre-select current bouquet
        if ((widget.utility.code == 'DSTV' || widget.utility.code == 'GOTV') &&
            result['bouquet_code'] != null) {
          _selectedBouquet = _bouquets.firstWhere(
            (b) => b['code'] == result['bouquet_code'],
            orElse: () => <String, dynamic>{},
          );
          if (_selectedBouquet!.isNotEmpty) {
            _amountCtrl.text = _selectedBouquet!['price'].toString();
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _state = _FormState.idle; });
      _snack(e.toString().replaceAll('Exception: ', ''), AppTheme.error);
    }
  }

  Future<void> _pay() async {
    final meter = _meterCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.trim());
    final profile = FirebaseService.sessionProfile;
    final phone = FirebaseService.formatPhoneForMarzPay(
        profile?['phone'] as String? ?? '');

    if (amount == null || amount < 1000) {
      _snack('Minimum payment is UGX 1,000', AppTheme.warning); return;
    }
    if ((widget.utility.code == 'DSTV' || widget.utility.code == 'GOTV') &&
        _selectedBouquet == null) {
      _snack('Select a bouquet', AppTheme.warning); return;
    }

    setState(() => _state = _FormState.paying);
    try {
      final tokenPhone = _tokenPhoneCtrl.text.trim();
      final result = await FirebaseService.payBill(
        utilityCode: widget.utility.code,
        meterNumber: meter,
        phoneNumber: phone,
        amount: amount,
        area: _selectedArea,
        bouquetCode: _selectedBouquet?['code'] as String?,
        customerName: _customer?['customer_name'] as String?,
        tokenPhone: tokenPhone.isNotEmpty ? tokenPhone : null,
      );
      if (!mounted) return;

      // Build success message — electricity gets a special token-delivery notice
      String msg;
      if (widget.utility.code == 'LIGHT') {
        final deliveryPhone = result['tokenPhone'] as String? ??
            (profile?['phone'] as String? ?? '');
        final displayPhone = deliveryPhone.isNotEmpty ? deliveryPhone : 'your registered number';
        msg = 'UGX ${fmt.format(result['amount'])} loaded for meter $meter.\n\n'
            'Charge: UGX ${fmt.format(result['charge'])}\n'
            'Total deducted: UGX ${fmt.format(result['total'])}\n'
            'Reference: ${result['reference']}\n\n'
            '📱 Your electricity token will be sent via SMS to $displayPhone by UEDCL. '
            'If you don\'t receive it within 10 minutes, contact UEDCL with your reference number.';
      } else {
        msg = 'UGX ${fmt.format(result['amount'])} paid for '
            '${(result['customerName'] as String).isNotEmpty ? result['customerName'] : meter}.\n\n'
            'Charge: UGX ${fmt.format(result['charge'])}\n'
            'Total deducted: UGX ${fmt.format(result['total'])}\n'
            'Reference: ${result['reference']}';
      }

      setState(() {
        _state = _FormState.success;
        _successMsg = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _FormState.error;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Full-screen states
    if (_state == _FormState.paying) return _buildProcessing();
    if (_state == _FormState.success) return _buildResult(success: true);
    if (_state == _FormState.error)   return _buildResult(success: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.utility.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.utility.icon,
                    color: widget.utility.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.utility.name,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(widget.utility.subtitle,
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // NWSC area selector
          if (widget.utility.code == 'NWSC') ...[
            _label('Area'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedArea,
                  hint: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('Select area',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey.shade400)),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  borderRadius: BorderRadius.circular(12),
                  items: _nwscAreas.map((a) => DropdownMenuItem(
                    value: a,
                    child: Text(a, style: GoogleFonts.poppins(fontSize: 14)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedArea = v),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Meter / account number
          _label(widget.utility.code == 'DSTV' || widget.utility.code == 'GOTV'
              ? 'Smart Card Number'
              : 'Meter Number'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _meterCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Enter number',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      hintStyle: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade400),
                    ),
                    onChanged: (_) => setState(() {
                      _customer = null;
                      _state = _FormState.idle;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _state == _FormState.verifying ? null : _verify,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: _customer != null
                        ? AppTheme.success
                        : widget.utility.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _state == _FormState.verifying
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _customer != null ? '✓ Verified' : 'Verify',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                ),
              ),
            ],
          ),

          // Customer details card
          if (_customer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 16),
                      const SizedBox(width: 6),
                      Text('Account Verified',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if ((_customer!['customer_name'] as String? ?? '').isNotEmpty)
                    _detailRow('Name', _customer!['customer_name'] as String),
                  if (_customer!['outstanding_balance'] != null) ...[
                    _detailRow('Outstanding Balance',
                        'UGX ${fmt.format((double.tryParse(_customer!['outstanding_balance'].toString()) ?? 0).toInt())}',
                        highlight: true),
                  ],
                  if ((_customer!['bouquet_name'] as String? ?? '').isNotEmpty)
                    _detailRow('Current Package', _customer!['bouquet_name'] as String),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // DSTV/GOTV bouquet selector
          if ((widget.utility.code == 'DSTV' || widget.utility.code == 'GOTV') &&
              _bouquets.isNotEmpty) ...[
            _label('Select Package'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: _selectedBouquet?.isNotEmpty == true
                      ? _selectedBouquet
                      : null,
                  hint: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('Select package',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey.shade400)),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  borderRadius: BorderRadius.circular(12),
                  items: _bouquets.map((b) {
                    final price = int.tryParse(b['price'].toString()) ?? 0;
                    return DropdownMenuItem(
                      value: b,
                      child: Text(
                        '${b['name']} — UGX ${fmt.format(price)} (${b['period_label']})',
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _selectedBouquet = v;
                    if (v != null) {
                      _amountCtrl.text = v['price'].toString();
                    }
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Amount (editable for LIGHT/NWSC, auto-filled for DSTV/GOTV)
          if (widget.utility.code == 'LIGHT' || widget.utility.code == 'NWSC') ...[
            _label('Amount (UGX)'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(11)),
                      border: Border(
                          right: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Text('UGX',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '10,000',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Quick amounts for electricity/water
            Row(
              children: [5000, 10000, 20000, 50000].map((v) {
                final sel = int.tryParse(_amountCtrl.text) == v;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _amountCtrl.text = v.toString()),
                    child: Container(
                      margin: EdgeInsets.only(right: v != 50000 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? widget.utility.color
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? widget.utility.color
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        '${v ~/ 1000}K',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppTheme.textSecondary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Charge notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fixed service charge: UGX 1,500 per transaction',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),

          // Electricity: alternate phone for token delivery
          if (widget.utility.code == 'LIGHT') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sms_rounded,
                          color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Token delivery via SMS',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your electricity token will be sent via SMS by UEDCL. '
                    'Leave blank to use your registered number, or enter an alternate number below.',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFF92400E), height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                    ),
                    child: TextField(
                      controller: _tokenPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Alternate phone (optional)',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.phone_rounded,
                            size: 18, color: Color(0xFFF59E0B)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Pay button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _state == _FormState.verified ||
                      (widget.utility.code != 'DSTV' &&
                          widget.utility.code != 'GOTV' &&
                          _amountCtrl.text.isNotEmpty)
                  ? _pay
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.utility.color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Pay ${widget.utility.name} Bill',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: widget.utility.color, strokeWidth: 3),
          const SizedBox(height: 20),
          Text('Processing Payment...',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Please wait',
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildResult({required bool success}) {
    final color = success ? AppTheme.success : AppTheme.error;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(success ? 'Payment Successful!' : 'Payment Failed',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(success ? _successMsg : _errorMsg,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() {
                _state = _FormState.idle;
                if (!success) {
                  _errorMsg = '';
                } else {
                  // Reset form for new payment
                  _meterCtrl.clear();
                  _amountCtrl.clear();
                  _tokenPhoneCtrl.clear();
                  _customer = null;
                  _selectedBouquet = null;
                  _successMsg = '';
                }
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(success ? 'Pay Another Bill' : 'Try Again',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          if (success) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: widget.onBack,
              child: Text('Back to Services',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary),
      );

  Widget _detailRow(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                      color: highlight ? AppTheme.warning : AppTheme.textPrimary)),
            ),
          ],
        ),
      );
}

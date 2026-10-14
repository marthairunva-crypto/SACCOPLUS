import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/centered_loader.dart';
import 'farmer_scaffold.dart';

class _Network {
  final String name;
  final String airtimeCode;
  final String? internetCode;
  final bool isNew;
  final Color color;
  final IconData icon;
  const _Network({required this.name, required this.airtimeCode, this.internetCode, this.isNew = false, required this.color, required this.icon});
}

const _networks = [
  _Network(name: 'MTN Uganda',   airtimeCode: 'MTN_UG_AIRTIME',   internetCode: 'MTN_UG_INTERNET',   color: Color(0xFFFFCC00), icon: Icons.signal_cellular_alt_rounded),
  _Network(name: 'Airtel Uganda', airtimeCode: 'AIRTEL_UG_AIRTIME', internetCode: 'AIRTEL_UG_INTERNET', color: Color(0xFFE53935), icon: Icons.signal_cellular_alt_rounded),
  _Network(name: 'Lyca Mobile',  airtimeCode: 'LYCA_UG_AIRTIME',  internetCode: null, isNew: true, color: Color(0xFF7B1FA2), icon: Icons.signal_cellular_alt_rounded),
];

class AirtimeDataScreen extends StatefulWidget {
  const AirtimeDataScreen({super.key});
  @override
  State<AirtimeDataScreen> createState() => _AirtimeDataScreenState();
}

class _AirtimeDataScreenState extends State<AirtimeDataScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FarmerScaffold(
      title: 'Airtime & Data',
      bottom: TabBar(
        controller: _tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: AppTheme.accent,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [Tab(text: 'Buy Airtime'), Tab(text: 'Data Bundles')],
      ),
      body: TabBarView(controller: _tab, children: const [_AirtimeTab(), _DataTab()]),
    );
  }
}

// ─── Airtime Tab ──────────────────────────────────────────────────────────────
class _AirtimeTab extends StatefulWidget {
  const _AirtimeTab();
  @override
  State<_AirtimeTab> createState() => _AirtimeTabState();
}

class _AirtimeTabState extends State<_AirtimeTab> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###', 'en_US');
  _Network? _selected = _networks[0]; // MTN pre-selected
  bool _loading = false;
  String _error = '';

  static const _presets = [500, 1000, 2000, 5000, 10000, 20000];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    final phone = _phoneCtrl.text.trim();
    final amount = int.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (_selected == null) { setState(() => _error = 'Please select a network'); return; }
    if (phone.isEmpty) { setState(() => _error = 'Please enter a phone number'); return; }
    if (amount < 500) { setState(() => _error = 'Minimum airtime is UGX 500'); return; }

    // Confirm dialog — no phone verification needed; MarzPay detects network from MSISDN
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: $phone',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('Airtime: UGX ${_fmt.format(amount)}',
                style: const TextStyle(fontSize: 13)),
            Text('Network: ${_selected!.name}',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _loading = true; _error = ''; });
    try {
      final result = await FirebaseService.purchaseAirtimeOrBundle(
        productCode: _selected!.airtimeCode,
        phoneNumber: phone,
        amount: amount,
      );
      if (!mounted) return;
      _showSuccess(
        title: 'Airtime Sent!',
        subtitle: 'UGX ${_fmt.format(amount)} airtime sent to $phone',
        reference: result['reference'] as String? ?? '',
      );
      _amountCtrl.clear();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess({required String title, required String subtitle, required String reference}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(title: title, subtitle: subtitle, reference: reference),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AirtimeTabWrapper(
      loading: _loading,
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _InfoBanner(icon: Icons.phone_android_rounded,
            text: 'Buy airtime for any Uganda network. Amount is deducted from your wallet instantly.'),
        const SizedBox(height: 24),

        Text('Select Network',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.8,
          children: _networks.map((n) => _NetworkTile(
            network: n, selected: _selected == n,
            onTap: () => setState(() { _selected = n; _error = ''; }),
          )).toList(),
        ),

        const SizedBox(height: 24),
        Text('Recipient Phone Number',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '07XX XXX XXX',
            prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.accent, size: 20),
            suffixIcon: IconButton(
              icon: const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 20),
              tooltip: 'Use my number',
              onPressed: () {
                final p = FirebaseService.sessionProfile?['phone'] as String? ?? '';
                if (p.isNotEmpty) _phoneCtrl.text = p;
              },
            ),
          ),
        ),

        const SizedBox(height: 20),
        Text('Amount (UGX)',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Enter amount',
            prefixIcon: Icon(Icons.attach_money_rounded, color: AppTheme.accent, size: 20),
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8, runSpacing: 8,
          children: _presets.map((p) => GestureDetector(
            onTap: () => setState(() => _amountCtrl.text = p.toString()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Text(_fmt.format(p),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent)),
            ),
          )).toList(),
        ),

        if (_error.isNotEmpty) ...[const SizedBox(height: 16), _ErrorBanner(message: _error)],
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _buy,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Buy Airtime'),
          ),
        ),
      ]),
      ),  // end SingleChildScrollView
    );    // end _AirtimeTabWrapper
  }
}

// ─── Airtime loading overlay ──────────────────────────────────────────────────
class _AirtimeTabWrapper extends StatelessWidget {
  final bool loading;
  final Widget child;
  const _AirtimeTabWrapper({required this.loading, required this.child});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      if (loading)
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.85),
            child: const CenteredLoader(
              color: AppTheme.accent,
              message: 'Sending Airtime',
              subMessage: 'Deducting from wallet...',
            ),
          ),
        ),
    ],
  );
}
class _DataTab extends StatefulWidget {
  const _DataTab();
  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  final _phoneCtrl = TextEditingController();
  final _fmt = NumberFormat('#,###', 'en_US');
  _Network? _selected = _networks[0]; // MTN pre-selected
  List<Map<String, dynamic>> _bundles = [];
  Map<String, dynamic>? _selectedBundle;
  bool _loadingBundles = false;
  bool _buying = false;
  String _error = '';

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  @override
  void initState() {
    super.initState();
    // Auto-load MTN bundles on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBundles(_networks[0]));
  }

  Future<void> _loadBundles(_Network network) async {
    if (network.internetCode == null) return;
    setState(() { _loadingBundles = true; _bundles = []; _selectedBundle = null; _error = ''; });
    try {
      final list = await FirebaseService.getRelworxPriceList(network.internetCode!);
      if (mounted) setState(() { _bundles = list; _loadingBundles = false; });
    } catch (e) {
      if (mounted) setState(() { 
        _error = e.toString().replaceFirst('Exception: ', ''); 
        _loadingBundles = false; 
      });
    }
  }

  Future<void> _verifyAndBuy() async {
    final phone = _phoneCtrl.text.trim();
    if (_selected == null) { setState(() => _error = 'Please select a network'); return; }
    if (phone.isEmpty) { setState(() => _error = 'Please enter a phone number'); return; }
    if (_selectedBundle == null) { setState(() => _error = 'Please select a bundle'); return; }

    final bundleName = _selectedBundle!['name'] as String? ?? 'Data Bundle';
    final bundlePrice = (_selectedBundle!['amount'] as num?)?.toInt() ?? 0;

    // Confirm dialog — no phone verification; MarzPay detects network from MSISDN
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: $phone',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('Bundle: $bundleName',
                style: const TextStyle(fontSize: 13)),
            Text('Price: UGX ${_fmt.format(bundlePrice)}',
                style: const TextStyle(fontSize: 13)),
            Text('Network: ${_selected!.name}',
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _buying = true; _error = ''; });
    try {
      await _buy();
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _buying = false;
      });
    }
  }

  Future<void> _buy() async {
    final phone = _phoneCtrl.text.trim();
    if (_selected == null) { setState(() => _error = 'Please select a network'); return; }
    if (phone.isEmpty) { setState(() => _error = 'Please enter a phone number'); return; }
    if (_selectedBundle == null) { setState(() => _error = 'Please select a bundle'); return; }

    final priceCode = _selectedBundle!['code'] as String? ?? '';
    final amount = (_selectedBundle!['amount'] as num?)?.toInt() ??
        (_selectedBundle!['price'] as num?)?.toInt() ?? 0;

    setState(() { _buying = true; _error = ''; });
    try {
      final result = await FirebaseService.purchaseAirtimeOrBundle(
        productCode: _selected!.internetCode!,
        phoneNumber: phone,
        amount: amount,           // bundle price — required for wallet deduction
        priceCode: priceCode.isNotEmpty ? priceCode : null,
      );
      if (!mounted) return;
      final bundleName = _selectedBundle!['name'] as String? ?? 'Data Bundle';
      _showSuccess(
        title: 'Bundle Activated!',
        subtitle: '$bundleName sent to $phone',
        reference: result['reference'] as String? ?? '',
      );
      setState(() => _selectedBundle = null);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _showSuccess({required String title, required String subtitle, required String reference}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(title: title, subtitle: subtitle, reference: reference),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedBundle != null;
    final bundlePrice = hasSelection
        ? ((_selectedBundle!['amount'] as num?)?.toInt() ?? 0)
        : 0;
    final bundleName = hasSelection
        ? (_selectedBundle!['name'] as String? ?? 'Bundle')
        : '';

    return Stack(
      children: [
        // ── Scrollable content ──────────────────────────────────────────
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, hasSelection ? 96 : 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _InfoBanner(icon: Icons.wifi_rounded,
                text: 'Buy internet data bundles for any Uganda network. Deducted from your wallet.'),
            const SizedBox(height: 24),

            Text('Select Network',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.8,
              children: _networks
                  .map((n) => _NetworkTile(
                        network: n, selected: _selected == n,
                        onTap: () {
                          setState(() { _selected = n; _error = ''; });
                          if (n.internetCode != null) {
                            _loadBundles(n);
                          } else {
                            setState(() { _bundles = []; _selectedBundle = null; });
                          }
                        },
                      ))
                  .toList(),
            ),

            const SizedBox(height: 24),
            Text('Recipient Phone Number',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '07XX XXX XXX',
                prefixIcon: const Icon(Icons.phone_rounded, color: AppTheme.accent, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.person_rounded, color: AppTheme.textSecondary, size: 20),
                  tooltip: 'Use my number',
                  onPressed: () {
                    final p = FirebaseService.sessionProfile?['phone'] as String? ?? '';
                    if (p.isNotEmpty) _phoneCtrl.text = p;
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text('Select Bundle',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            if (_selected == null)
              _EmptyHint(message: 'Select a network above to see available bundles')
            else if (_selected!.internetCode == null)
              _EmptyHint(message: '${_selected!.name} supports airtime top-up only. Use the Buy Airtime tab.')
            else if (_loadingBundles)
              const Center(child: Padding(padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppTheme.primary)))
            else if (_bundles.isEmpty)
              _EmptyHint(message: 'No bundles available for this network')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bundles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final b = _bundles[i];
                  final isSelected = _selectedBundle == b;
                  final price = (b['amount'] as num?)?.toInt() ?? (b['price'] as num?)?.toInt() ?? 0;
                  final name = b['name'] as String? ?? b['description'] as String? ?? 'Bundle';
                  final validity = b['validity'] as String? ?? b['duration'] as String? ?? '';
                  return GestureDetector(
                    onTap: () => setState(() { _selectedBundle = b; _error = ''; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accent.withOpacity(0.08) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.accent : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: (_selected?.color ?? AppTheme.accent).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.wifi_rounded, color: _selected?.color ?? AppTheme.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name,
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (validity.isNotEmpty)
                            Text(validity, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('UGX ${_fmt.format(price)}',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 18),
                        ]),
                      ]),
                    ),
                  );
                },
              ),

            if (_error.isNotEmpty) ...[const SizedBox(height: 16), _ErrorBanner(message: _error)],
          ]),
        ),

        // ── Sticky bottom buy bar (appears once a bundle is selected) ───
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          bottom: hasSelection ? 0 : -100,
          left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, -4))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                // Selected bundle summary
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(bundleName,
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('UGX ${_fmt.format(bundlePrice)}',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  ]),
                ),
                const SizedBox(width: 12),
                // Buy button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _buying ? null : _verifyAndBuy,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.wifi_rounded, size: 18),
                    label: Text('Buy Bundle',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Full-screen loader overlay while processing ───────────────
        if (_buying)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.85),
              child: const CenteredLoader(
                color: AppTheme.accent,
                message: 'Processing Purchase',
                subMessage: 'Deducting from wallet and sending bundle...',
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _NetworkTile extends StatelessWidget {
  final _Network network;
  final bool selected;
  final VoidCallback onTap;
  const _NetworkTile({required this.network, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? network.color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? network.color : Colors.grey.shade200, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: network.color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(network.icon, color: network.color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(network.name,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (selected) Icon(Icons.check_circle_rounded, color: network.color, size: 16),
          if (network.isNew && !selected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('NEW',
                  style: GoogleFonts.poppins(
                      fontSize: 7, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
            ),
        ]),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary))),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.error))),
      ]),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 36),
        const SizedBox(height: 8),
        Text(message,
            style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String reference;
  const _SuccessDialog({required this.title, required this.subtitle, required this.reference});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
              style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.receipt_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(child: Text('Ref: $reference',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ]),
      ),
    );
  }
}

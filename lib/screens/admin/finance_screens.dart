// lib/screens/admin/finance_screens.dart
//
// Finance hub: Cash & Bank, Income, Expenses.
//  - Everything is in UGX.
//  - All figures are live (Firestore streams), nothing is hard-coded.
//  - Income automatically includes loan interest and charges taken from the
//    loan repayments ledger, plus any manual income you record.
//  - Every money movement is written in ONE Firestore transaction
//    (record + account balance + account movement), so they never drift apart.
//  - Every change is written to the audit trail.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../services/audit_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (same palette as the dashboard)
// ─────────────────────────────────────────────────────────────────────────────
class _K {
  static const bg = Color(0xFFF6F7F9);
  static const ink = Color(0xFF111827);
  static const sub = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFDCE0E6);
  static const accent = Color(0xFF1B365D);
  static const neg = Color(0xFFB42318);
  static const pos = Color(0xFF067647);
  static const warn = Color(0xFFB54708);
}

final _numFmt = NumberFormat('#,##0');

/// UGX has no decimals in everyday use.
String _ugx(num v) {
  final r = v.round();
  return r < 0 ? '-UGX ${_numFmt.format(-r)}' : 'UGX ${_numFmt.format(r)}';
}

TextStyle _t(double size, FontWeight w, Color c, {bool tab = false, double? ls}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: ls,
      fontFeatures: tab ? const [FontFeature.tabularFigures()] : null,
    );

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
}

DateTime? _dt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class _Fail implements Exception {
  final String message;
  const _Fail(this.message);
  @override
  String toString() => message;
}

String _errText(Object e) => e is _Fail ? e.message : 'Something went wrong. $e';

void _toast(BuildContext context, String msg, {bool ok = true}) {
  if (!context.mounted) return;
  final wide = MediaQuery.sizeOf(context).width >= 900;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: _t(13.5, FontWeight.w400, Colors.white)),
      backgroundColor: ok ? _K.ink : _K.neg,
      behavior: SnackBarBehavior.floating,
      width: wide ? 440 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
}

Future<void> _audit(String action, String details, {Map<String, dynamic>? meta}) async {
  try {
    await AuditService.log(
      action: action,
      details: details,
      userId: FirebaseService.sessionUid,
      affectedUserId: '',
      metadata: meta ?? <String, dynamic>{},
    );
  } catch (e) {
    debugPrint('Audit log failed: $e');
  }
}

/// Writes an account movement inside a transaction. [current] must already have
/// been read in the same transaction. Returns the new balance.
double _post(
  Transaction tx,
  DocumentReference<Map<String, dynamic>> ref,
  double current, {
  required bool inflow,
  required double amount,
  required String description,
  required String type,
}) {
  final after = inflow ? current + amount : current - amount;
  tx.update(ref, {
    'balance': after,
    'lastMovementAt': FieldValue.serverTimestamp(),
  });
  tx.set(ref.collection('movements').doc(), {
    'type': type,
    'amount': amount,
    'description': description,
    'date': FieldValue.serverTimestamp(),
    'balanceAfter': after,
    'createdBy': FirebaseService.sessionUid,
  });
  return after;
}

// ─────────────────────────────────────────────────────────────────────────────
// Account types
// ─────────────────────────────────────────────────────────────────────────────
String _typeLabel(String t) => switch (t) {
      'bank' => 'Bank',
      'till' => 'Till / Mobile money',
      _ => 'Cash',
    };

IconData _typeIcon(String t) => switch (t) {
      'bank' => Icons.account_balance_outlined,
      'till' => Icons.phone_android_outlined,
      _ => Icons.payments_outlined,
    };

Color _typeColor(String t) => switch (t) {
      'bank' => const Color(0xFF1B365D),
      'till' => const Color(0xFF3E8E7E),
      _ => const Color(0xFFB54708),
    };

class _Account {
  final String id, name, type, currency;
  final String? number;
  final double balance;
  final bool active;
  final DateTime? lastMovement;

  const _Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.number,
    required this.balance,
    required this.active,
    required this.lastMovement,
  });

  factory _Account.from(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    final t = (m['type'] ?? 'cash').toString().toLowerCase();
    final num = (m['accountNumber'] ?? '').toString().trim();
    return _Account(
      id: d.id,
      name: (m['name'] ?? 'Unnamed account').toString(),
      type: const ['cash', 'bank', 'till'].contains(t) ? t : 'cash',
      currency: (m['currency'] ?? 'UGX').toString(),
      number: num.isEmpty ? null : num,
      balance: _d(m['balance']),
      active: m['isActive'] != false,
      lastMovement: _dt(m['lastMovementAt']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI pieces
// ─────────────────────────────────────────────────────────────────────────────
OutlineInputBorder _ob(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c, width: w),
    );

InputDecoration _dec(String label, {String? prefix, String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: _t(13.5, FontWeight.w400, _K.muted),
      floatingLabelStyle: _t(13.5, FontWeight.w500, _K.accent),
      hintStyle: _t(13.5, FontWeight.w400, _K.muted),
      border: _ob(_K.line),
      enabledBorder: _ob(_K.line),
      focusedBorder: _ob(_K.accent, 1.6),
    );

Widget _primaryBtn(String label, IconData icon, VoidCallback? onTap) => FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: _K.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _t(13.5, FontWeight.w600, Colors.white),
      ),
    );

Widget _ghostBtn(String label, IconData icon, VoidCallback? onTap, {Color? color}) =>
    OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? _K.accent,
        side: const BorderSide(color: _K.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _t(13.5, FontWeight.w600, _K.accent),
      ),
    );

class _PageHeader extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  const _PageHeader({required this.title, required this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: _t(22, FontWeight.w700, _K.ink, ls: -0.3)),
      const SizedBox(height: 2),
      Text(subtitle, style: _t(12.5, FontWeight.w400, _K.muted)),
    ]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 680 && actions.isNotEmpty) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          text,
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: text),
        if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
      ]);
    });
  }
}

class _Stat {
  final String label, value;
  final String? sub;
  final Color? color;
  const _Stat(this.label, this.value, {this.sub, this.color});
}

class _StatGrid extends StatelessWidget {
  final List<_Stat> stats;
  const _StatGrid(this.stats);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final cols = c.maxWidth >= 900
          ? (stats.length < 4 ? stats.length : 4)
          : (c.maxWidth >= 520 ? 2 : 1);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final s in stats)
          SizedBox(
            width: w,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _K.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(10.5, FontWeight.w600, _K.muted, ls: 0.6)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(s.value,
                      style: _t(21, FontWeight.w700, s.color ?? _K.ink, tab: true, ls: -0.3)),
                ),
                if (s.sub != null) ...[
                  const SizedBox(height: 4),
                  Text(s.sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(11.5, FontWeight.w400, _K.muted)),
                ],
              ]),
            ),
          ),
      ]);
    });
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _K.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(14, FontWeight.w600, _K.ink)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w400, _K.muted)),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ]),
        ),
        const Divider(height: 1, color: _K.line),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: _t(11, FontWeight.w600, color)),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const _Empty({required this.icon, required this.title, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: _t(14.5, FontWeight.w600, _K.ink)),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center, style: _t(12.5, FontWeight.w400, _K.muted)),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ]),
        ),
      );
}

Widget _errorLine(String? e) => e == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3F2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDA29B)),
          ),
          child: Text(e, style: _t(12.5, FontWeight.w500, _K.neg)),
        ),
      );

EdgeInsets _pagePad(double w) =>
    EdgeInsets.all(w >= 900 ? 24.0 : (w >= 600 ? 18.0 : 12.0));

// ── Date range filter ────────────────────────────────────────────────────────
enum _Range { thisMonth, lastMonth, thisYear, allTime, custom }

({DateTime start, DateTime end})? _resolve(_Range r, DateTimeRange? custom) {
  final now = DateTime.now();
  return switch (r) {
    _Range.thisMonth => (
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 1)
      ),
    _Range.lastMonth => (
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 1)
      ),
    _Range.thisYear => (start: DateTime(now.year, 1, 1), end: DateTime(now.year + 1, 1, 1)),
    _Range.allTime => null,
    _Range.custom => custom == null
        ? null
        : (
            start: DateTime(custom.start.year, custom.start.month, custom.start.day),
            end: DateTime(custom.end.year, custom.end.month, custom.end.day + 1)
          ),
  };
}

Future<DateTimeRange?> _pickRange(BuildContext context, DateTimeRange? current) =>
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: current,
    );

class _RangeChips extends StatelessWidget {
  final _Range value;
  final DateTimeRange? custom;
  final ValueChanged<_Range> onChanged;
  final VoidCallback onCustom;
  const _RangeChips({
    required this.value,
    required this.custom,
    required this.onChanged,
    required this.onCustom,
  });

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: _t(12, FontWeight.w600, selected ? Colors.white : _K.sub),
        selectedColor: _K.accent,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _K.accent : _K.line),
        onSelected: (_) => onTap(),
      );

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Range.thisMonth: 'This month',
      _Range.lastMonth: 'Last month',
      _Range.thisYear: 'This year',
      _Range.allTime: 'All time',
    };
    final customLabel = custom == null
        ? 'Custom range'
        : '${DateFormat('d MMM').format(custom!.start)} – ${DateFormat('d MMM yyyy').format(custom!.end)}';
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in labels.entries) _chip(e.value, value == e.key, () => onChanged(e.key)),
      _chip(customLabel, value == _Range.custom, onCustom),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hub
// ─────────────────────────────────────────────────────────────────────────────
/// Finance Screens Hub - Cash & Bank, Income, Expenses
class FinanceScreensHub extends StatefulWidget {
  const FinanceScreensHub({super.key});

  @override
  State<FinanceScreensHub> createState() => _FinanceScreensHubState();
}

class _FinanceScreensHubState extends State<FinanceScreensHub> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    CashAndBankScreen(),
    IncomeScreen(),
    ExpensesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_balance), label: 'Cash & Bank'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Income'),
          NavigationDestination(icon: Icon(Icons.trending_down), label: 'Expenses'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CASH & BANK
// ─────────────────────────────────────────────────────────────────────────────
class CashAndBankScreen extends StatefulWidget {
  const CashAndBankScreen({super.key});

  @override
  State<CashAndBankScreen> createState() => _CashAndBankScreenState();
}

class _CashAndBankScreenState extends State<CashAndBankScreen> {
  final _search = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _tillStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tillSub;
  String _filter = 'all';
  bool _showInactive = false;
  String? _selectedAccountId; // Track which account is open

  @override
  void initState() {
    super.initState();
    // Watch accounts collection
    _stream = FirebaseFirestore.instance
        .collection('accounts')
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .snapshots();

    // Watch till sessions for real-time updates (ALL sessions, not just open)
    _tillStream = FirebaseFirestore.instance
        .collection('saccoplus-till-sessions')
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .snapshots();

    // Listen to till changes and sync automatically
    _tillSub = _tillStream.listen(_syncTillBalancesFromSnapshot);
  }

  /// Syncs till balances in real-time whenever till data changes
  /// Groups all sessions by teller and sums their COUNTED balances (actual physical cash)
  void _syncTillBalancesFromSnapshot(QuerySnapshot<Map<String, dynamic>> tillSnapshot) async {
    try {
      print('📊 Syncing ${tillSnapshot.docs.length} till sessions (all statuses)...');

      // Group sessions by teller and calculate totals
      final Map<String, Map<String, dynamic>> tellerTotals = {};

      for (final tillDoc in tillSnapshot.docs) {
        final data = tillDoc.data();
        final tellerId = data['tellerId'] as String?;
        final tellerName = data['tellerName'] as String?;
        final status = data['status'] as String? ?? 'unknown';
        final openingFloat = (data['openingFloat'] ?? 0) as int;
        final totalIn = (data['totalIn'] ?? 0) as int;
        final totalOut = (data['totalOut'] ?? 0) as int;
        final expectedCash = openingFloat + totalIn - totalOut;

        // Use actualCash if available (actual physical count), otherwise use expected
        final countedCash = (data['actualCash'] ?? expectedCash) as int;

        print('  💰 $tellerName ($status): Expected=$expectedCash | Counted=$countedCash');

        if (tellerId != null && tellerName != null) {
          // Accumulate totals per teller
          if (!tellerTotals.containsKey(tellerId)) {
            tellerTotals[tellerId] = {
              'name': tellerName,
              'balance': 0,
              'sessionCount': 0,
              'hasOpen': false,
            };
          }

          tellerTotals[tellerId]!['balance'] =
              (tellerTotals[tellerId]!['balance'] as int) + countedCash;
          tellerTotals[tellerId]!['sessionCount'] =
              (tellerTotals[tellerId]!['sessionCount'] as int) + 1;
          if (status == 'open') {
            tellerTotals[tellerId]!['hasOpen'] = true;
          }
        }
      }

      // Now create/update one account per teller with their total
      for (final entry in tellerTotals.entries) {
        final tellerId = entry.key;
        final data = entry.value;
        final tellerName = data['name'] as String;
        final totalBalance = data['balance'] as int;
        final sessionCount = data['sessionCount'] as int;
        final hasOpen = data['hasOpen'] as bool;

        final accountId = 'till_$tellerId';
        final statusLabel = hasOpen ? 'Open' : 'Closed';

        await FirebaseFirestore.instance
            .collection('accounts')
            .doc(accountId)
            .set({
          'id': accountId,
          'tenantId': FirebaseService.sessionTenantId,
          'name': '$tellerName\'s Till ($statusLabel)',
          'type': 'till',
          'balance': totalBalance.toDouble(),
          'currency': 'UGX',
          'isActive': true,
          'active': true,
          'sessionCount': sessionCount,
          'hasOpenSession': hasOpen,
          'lastSynced': FieldValue.serverTimestamp(),
          'lastMovementAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('  ✅ Updated $accountId: $sessionCount sessions, total COUNTED balance: $totalBalance');
      }

      print('✅ Till sync complete - ${tellerTotals.length} teller account(s) updated');
    } catch (e) {
      print('⚠️ Could not sync till balances: $e');
    }
  }

  @override
  void dispose() {
    _tillSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _open(_Account a) {
    // Open inline instead of navigating
    setState(() {
      _selectedAccountId = a.id;
    });
  }

  void _closeDetails() {
    setState(() {
      _selectedAccountId = null;
    });
  }

  Future<void> _addAccount(List<_Account> all) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccountDialog(takenNames: all.map((a) => a.name.toLowerCase()).toSet()),
    );
    if (saved == true && mounted) _toast(context, 'Account created');
  }

  Future<void> _setUgx(List<_Account> wrong) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final a in wrong) {
        batch.update(db.collection('accounts').doc(a.id), {'currency': 'UGX'});
      }
      await batch.commit();
      await _audit('accounts_currency_ugx', 'Set ${wrong.length} account(s) to UGX');
      if (mounted) _toast(context, 'All accounts now use UGX');
    } catch (e) {
      if (mounted) _toast(context, _errText(e), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If an account is selected, show its details instead
    if (_selectedAccountId != null) {
      return _AccountDetailsView(
        accountId: _selectedAccountId!,
        onBack: _closeDetails,
      );
    }

    return Scaffold(
      backgroundColor: _K.bg,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Empty(
                icon: Icons.error_outline,
                title: 'Could not load accounts',
                message: '${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final all = snap.data!.docs.map(_Account.from).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final active = all.where((a) => a.active).toList();
          double sum(Iterable<_Account> l) => l.fold<double>(0, (s, a) => s + a.balance);
          final total = sum(active);
          final cash = sum(active.where((a) => a.type != 'bank'));
          final bank = sum(active.where((a) => a.type == 'bank'));
          final wrongCurrency = all.where((a) => a.currency.toUpperCase() != 'UGX').toList();

          final q = _search.text.trim().toLowerCase();
          final visible = all.where((a) {
            if (!_showInactive && !a.active) return false;
            if (_filter != 'all' && a.type != _filter) return false;
            if (q.isNotEmpty &&
                !a.name.toLowerCase().contains(q) &&
                !(a.number ?? '').toLowerCase().contains(q)) {
              return false;
            }
            return true;
          }).toList();

          return LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 720;
            return SingleChildScrollView(
              padding: _pagePad(box.maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _PageHeader(
                  title: 'Cash & Bank',
                  subtitle: 'Where the SACCO\'s money is held  ·  ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}',
                  actions: [_primaryBtn('New account', Icons.add, () => _addAccount(all))],
                ),
                const SizedBox(height: 16),
                if (wrongCurrency.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${wrongCurrency.length} account${wrongCurrency.length == 1 ? ' is' : 's are'} '
                          'saved with a different currency. All amounts here are shown in UGX.',
                          style: _t(12.5, FontWeight.w400, const Color(0xFF92400E)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _setUgx(wrongCurrency),
                        child: Text('Set to UGX',
                            style: _t(13, FontWeight.w600, const Color(0xFFD97706))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                _StatGrid([
                  _Stat('Total funds', _ugx(total), sub: 'All active accounts', color: total < 0 ? _K.neg : null),
                  _Stat('Cash & mobile money', _ugx(cash),
                      sub: '${active.where((a) => a.type != 'bank').length} accounts'),
                  _Stat('Bank', _ugx(bank),
                      sub: '${active.where((a) => a.type == 'bank').length} accounts'),
                  _Stat('Accounts', '${active.length}',
                      sub: all.length == active.length
                          ? 'All active'
                          : '${all.length - active.length} inactive'),
                ]),
                const SizedBox(height: 16),
                _Panel(
                  title: 'Accounts',
                  subtitle: '${visible.length} of ${all.length}',
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final f in const [
                            ('all', 'All'),
                            ('cash', 'Cash'),
                            ('bank', 'Bank'),
                            ('till', 'Till / Mobile'),
                          ])
                            ChoiceChip(
                              label: Text(f.$2),
                              selected: _filter == f.$1,
                              showCheckmark: false,
                              labelStyle: _t(12, FontWeight.w600,
                                  _filter == f.$1 ? Colors.white : _K.sub),
                              selectedColor: _K.accent,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: _filter == f.$1 ? _K.accent : _K.line),
                              onSelected: (_) => setState(() => _filter = f.$1),
                            ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              style: _t(13.5, FontWeight.w400, _K.ink),
                              decoration: _dec('Search accounts').copyWith(
                                prefixIcon: const Icon(Icons.search, size: 18, color: _K.muted),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Switch(
                              value: _showInactive,
                              activeColor: _K.accent,
                              onChanged: (v) => setState(() => _showInactive = v),
                            ),
                            Text('Show inactive', style: _t(12.5, FontWeight.w400, _K.sub)),
                          ]),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _K.line),
                    if (all.isEmpty)
                      _Empty(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No accounts yet',
                        message: 'Add your cash box, bank and mobile money accounts to start tracking funds.',
                        action: _primaryBtn('New account', Icons.add, () => _addAccount(all)),
                      )
                    else if (visible.isEmpty)
                      const _Empty(
                        icon: Icons.search_off,
                        title: 'No accounts match',
                        message: 'Try a different filter or search.',
                      )
                    else ...[
                      if (wide)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Row(children: [
                            const SizedBox(width: 52),
                            Expanded(flex: 4, child: _hdr('Account')),
                            Expanded(flex: 2, child: _hdr('Type')),
                            Expanded(flex: 2, child: _hdr('Last activity')),
                            Expanded(
                                flex: 3,
                                child: Align(
                                    alignment: Alignment.centerRight, child: _hdr('Balance'))),
                            const SizedBox(width: 30),
                          ]),
                        ),
                      for (int i = 0; i < visible.length; i++) ...[
                        if (i > 0 || wide) const Divider(height: 1, color: _K.line),
                        _accountRow(visible[i], wide),
                      ],
                    ],
                  ]),
                ),
              ]),
            );
          });
        },
      ),
    );
  }

  Widget _hdr(String s) =>
      Text(s.toUpperCase(), style: _t(10.5, FontWeight.w600, _K.muted, ls: 0.6));

  Widget _accountRow(_Account a, bool wide) {
    final color = _typeColor(a.type);
    final dim = !a.active;
    return InkWell(
      onTap: () => _open(a),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(dim ? 0.05 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(a.type), size: 20, color: dim ? _K.muted : color),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(13.5, FontWeight.w600, dim ? _K.muted : _K.ink)),
                ),
                if (dim) ...[const SizedBox(width: 8), const _Pill('Inactive', _K.muted)],
              ]),
              const SizedBox(height: 2),
              Text(
                wide
                    ? (a.number ?? '—')
                    : '${_typeLabel(a.type)}${a.number == null ? '' : '  ·  ${a.number}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(12, FontWeight.w400, _K.muted),
              ),
            ]),
          ),
          if (wide) ...[
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _Pill(_typeLabel(a.type), color))),
            Expanded(
              flex: 2,
              child: Text(
                a.lastMovement == null ? '—' : DateFormat('d MMM yyyy').format(a.lastMovement!),
                style: _t(12.5, FontWeight.w400, _K.muted, tab: true),
              ),
            ),
          ],
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(_ugx(a.balance),
                    style: _t(14, FontWeight.w700, a.balance < 0 ? _K.neg : _K.ink, tab: true)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: _K.muted),
        ]),
      ),
    );
  }
}

// ── Create / edit account ────────────────────────────────────────────────────
class _AccountDialog extends StatefulWidget {
  final _Account? existing;
  final Set<String> takenNames;
  const _AccountDialog({this.existing, this.takenNames = const {}});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _name;
  late final TextEditingController _number;
  final _opening = TextEditingController();
  late String _type;
  late bool _active;
  bool _busy = false;
  String? _error;

  bool get _edit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _number = TextEditingController(text: e?.number ?? '');
    _type = e?.type ?? 'cash';
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final opening = double.tryParse(_opening.text.trim().replaceAll(',', '')) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Enter an account name.');
      return;
    }
    if (widget.takenNames.contains(name.toLowerCase())) {
      setState(() => _error = 'An account with this name already exists.');
      return;
    }
    if (!_edit && opening < 0) {
      setState(() => _error = 'Opening balance cannot be negative.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final number = _number.text.trim();
      if (_edit) {
        await db.collection('accounts').doc(widget.existing!.id).update({
          'name': name,
          'type': _type,
          'accountNumber': number,
          'isActive': _active,
          'currency': 'UGX',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _audit('account_updated', 'Updated account "$name"',
            meta: {'accountId': widget.existing!.id});
      } else {
        final ref = db.collection('accounts').doc();
        final batch = db.batch();
        batch.set(ref, {
          'name': name,
          'type': _type,
          'accountNumber': number,
          'balance': opening,
          'currency': 'UGX',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseService.sessionUid,
          if (opening > 0) 'lastMovementAt': FieldValue.serverTimestamp(),
        });
        if (opening > 0) {
          batch.set(ref.collection('movements').doc(), {
            'type': 'opening',
            'amount': opening,
            'description': 'Opening balance',
            'date': FieldValue.serverTimestamp(),
            'balanceAfter': opening,
            'createdBy': FirebaseService.sessionUid,
          });
        }
        await batch.commit();
        await _audit('account_created', 'Created account "$name" (${_typeLabel(_type)}) with ${_ugx(opening)}',
            meta: {'accountId': ref.id});
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_edit ? 'Edit account' : 'New account', style: _t(17, FontWeight.w700, _K.ink)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            TextField(controller: _name, decoration: _dec('Account name')),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: _dec('Account type'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'bank', child: Text('Bank')),
                DropdownMenuItem(value: 'till', child: Text('Till / Mobile money')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'cash'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _number,
              decoration: _dec('Account number / reference (optional)'),
            ),
            if (!_edit) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _opening,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: _dec('Opening balance', prefix: 'UGX '),
              ),
            ] else ...[
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                activeColor: _K.accent,
                title: Text('Active', style: _t(13.5, FontWeight.w500, _K.ink)),
                subtitle: Text('Inactive accounts are hidden from payments and totals.',
                    style: _t(12, FontWeight.w400, _K.muted)),
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
            _errorLine(_error),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        _primaryBtn(_busy ? 'Saving…' : (_edit ? 'Save changes' : 'Create account'),
            Icons.check, _busy ? null : _save),
      ],
    );
  }
}

// ── Deposit / withdrawal ─────────────────────────────────────────────────────
class _MoneyDialog extends StatefulWidget {
  final _Account account;
  final bool deposit;
  const _MoneyDialog({required this.account, required this.deposit});

  @override
  State<_MoneyDialog> createState() => _MoneyDialogState();
}

class _MoneyDialogState extends State<_MoneyDialog> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    final desc = _desc.text.trim();
    if (amt <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (desc.isEmpty) {
      setState(() => _error = 'Enter a description.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('accounts').doc(widget.account.id);
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw const _Fail('This account no longer exists.');
        final current = _d(snap.data()?['balance']);
        if (!widget.deposit && amt > current + 0.5) {
          throw _Fail('Insufficient balance. Available: ${_ugx(current)}.');
        }
        _post(tx, ref, current,
            inflow: widget.deposit,
            amount: amt,
            description: desc,
            type: widget.deposit ? 'deposit' : 'withdrawal');
      });
      await _audit(
          widget.deposit ? 'account_deposit' : 'account_withdrawal',
          '${widget.deposit ? 'Deposited' : 'Withdrew'} ${_ugx(amt)} ${widget.deposit ? 'into' : 'from'} "${widget.account.name}": $desc',
          meta: {'accountId': widget.account.id, 'amount': amt});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dep = widget.deposit;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(dep ? 'Deposit' : 'Withdrawal', style: _t(17, FontWeight.w700, _K.ink)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.account.name}  ·  Balance ${_ugx(widget.account.balance)}',
                style: _t(12.5, FontWeight.w400, _K.muted)),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: _dec('Amount', prefix: 'UGX '),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: _dec('Description', hint: dep ? 'e.g. Cash banked' : 'e.g. Office petty cash'),
            ),
            _errorLine(_error),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        _primaryBtn(_busy ? 'Saving…' : (dep ? 'Record deposit' : 'Record withdrawal'),
            dep ? Icons.add : Icons.remove, _busy ? null : _save),
      ],
    );
  }
}

// ── Transfer between accounts ────────────────────────────────────────────────
class _TransferDialog extends StatefulWidget {
  final _Account from;
  const _TransferDialog({required this.from});

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _toId;
  List<_Account> _targets = [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (_toId == null) {
      setState(() => _error = 'Choose the account to transfer to.');
      return;
    }
    if (amt <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    final to = _targets.firstWhere((a) => a.id == _toId);
    final note = _note.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final fromRef = db.collection('accounts').doc(widget.from.id);
      final toRef = db.collection('accounts').doc(to.id);
      await db.runTransaction((tx) async {
        final a = await tx.get(fromRef);
        final b = await tx.get(toRef);
        if (!a.exists || !b.exists) throw const _Fail('One of the accounts no longer exists.');
        final fromBal = _d(a.data()?['balance']);
        final toBal = _d(b.data()?['balance']);
        if (amt > fromBal + 0.5) {
          throw _Fail('Insufficient balance. Available: ${_ugx(fromBal)}.');
        }
        final suffix = note.isEmpty ? '' : ' ($note)';
        _post(tx, fromRef, fromBal,
            inflow: false,
            amount: amt,
            description: 'Transfer to ${to.name}$suffix',
            type: 'transfer_out');
        _post(tx, toRef, toBal,
            inflow: true,
            amount: amt,
            description: 'Transfer from ${widget.from.name}$suffix',
            type: 'transfer_in');
      });
      await _audit('account_transfer',
          'Transferred ${_ugx(amt)} from "${widget.from.name}" to "${to.name}"',
          meta: {'from': widget.from.id, 'to': to.id, 'amount': amt});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('Transfer funds', style: _t(17, FontWeight.w700, _K.ink)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('From ${widget.from.name}  ·  Balance ${_ugx(widget.from.balance)}',
                style: _t(12.5, FontWeight.w400, _K.muted)),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('accounts')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator(minHeight: 2);
                _targets = snap.data!.docs
                    .map(_Account.from)
                    .where((a) => a.id != widget.from.id)
                    .toList()
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                if (_targets.isEmpty) {
                  return Text('There is no other active account to transfer to.',
                      style: _t(12.5, FontWeight.w500, _K.warn));
                }
                return DropdownButtonFormField<String>(
                  value: _toId,
                  isExpanded: true,
                  decoration: _dec('Transfer to'),
                  items: [
                    for (final a in _targets)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name}  ·  ${_ugx(a.balance)}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _toId = v),
                );
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: _dec('Amount', prefix: 'UGX '),
            ),
            const SizedBox(height: 14),
            TextField(controller: _note, decoration: _dec('Note (optional)')),
            _errorLine(_error),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        _primaryBtn(_busy ? 'Transferring…' : 'Transfer', Icons.swap_horiz,
            _busy ? null : _save),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT DETAILS (Inline View - no navigation)
// Compact, top-aligned layout: header, balance card, stats, transactions.
// ─────────────────────────────────────────────────────────────────────────────
class _AccountDetailsView extends StatefulWidget {
  final String accountId;
  final VoidCallback onBack;
  const _AccountDetailsView({required this.accountId, required this.onBack});

  @override
  State<_AccountDetailsView> createState() => _AccountDetailsViewState();
}

class _AccountDetailsViewState extends State<_AccountDetailsView> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _accStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _movStream;

  @override
  void initState() {
    super.initState();
    final ref = FirebaseFirestore.instance.collection('accounts').doc(widget.accountId);
    _accStream = ref.snapshots();
    _movStream =
        ref.collection('movements').orderBy('date', descending: true).limit(200).snapshots();
  }

  Future<void> _money(_Account a, bool deposit) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MoneyDialog(account: a, deposit: deposit),
    );
    if (ok == true && mounted) _toast(context, deposit ? 'Deposit recorded' : 'Withdrawal recorded');
  }

  Future<void> _transfer(_Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferDialog(from: a),
    );
    if (ok == true && mounted) _toast(context, 'Transfer completed');
  }

  Future<void> _edit(_Account a) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccountDialog(existing: a, takenNames: const {}),
    );
    if (saved == true && mounted) _toast(context, 'Account updated');
  }

  Future<void> _toggleActive(_Account a) async {
    try {
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(a.id)
          .update({'isActive': !a.active});
      await _audit('account_${a.active ? 'deactivate' : 'activate'}', a.name);
      if (mounted) _toast(context, a.active ? 'Account deactivated' : 'Account activated');
    } catch (e) {
      if (mounted) _toast(context, _errText(e), ok: false);
    }
  }

  static const _inTypes = {'deposit', 'transfer_in', 'opening'};

  static String _label(String t) => switch (t) {
        'withdrawal' => 'Withdrawal',
        'transfer_in' => 'Transfer in',
        'transfer_out' => 'Transfer out',
        'opening' => 'Opening balance',
        _ => 'Deposit',
      };

  Widget _hdr(String s) =>
      Text(s.toUpperCase(), style: _t(10.5, FontWeight.w600, _K.muted, ls: 0.6));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _K.bg,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _accStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Empty(
              icon: Icons.error_outline,
              title: 'Could not load account',
              message: '${snap.error}',
              action: _primaryBtn('Back', Icons.arrow_back, widget.onBack),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) {
            return _Empty(
              icon: Icons.search_off,
              title: 'Account not found',
              message: 'This account may have been deleted.',
              action: _primaryBtn('Back', Icons.arrow_back, widget.onBack),
            );
          }
          final acc = _Account.from(snap.data!);
          final color = _typeColor(acc.type);

          return LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 720;
            final pad = _pagePad(box.maxWidth);

            final actions = Wrap(spacing: 8, runSpacing: 8, children: [
              _ghostBtn('Edit', Icons.edit_outlined, () => _edit(acc)),
              _ghostBtn(
                acc.active ? 'Deactivate' : 'Activate',
                acc.active ? Icons.block : Icons.check_circle_outline,
                () => _toggleActive(acc),
                color: acc.active ? _K.neg : _K.pos,
              ),
            ]);

            final title = Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(acc.type), color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(acc.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t(wide ? 20 : 17, FontWeight.w700, _K.ink, ls: -0.3)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    _Pill(_typeLabel(acc.type), color),
                    _Pill(acc.active ? 'Active' : 'Inactive', acc.active ? _K.pos : _K.muted),
                    if (acc.number != null) _Pill(acc.number!, _K.muted),
                  ]),
                ]),
              ),
            ]);

            final balanceCard = Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _K.line),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 14,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('CURRENT BALANCE',
                        style: _t(10.5, FontWeight.w600, _K.muted, ls: 0.6)),
                    const SizedBox(height: 6),
                    Text(_ugx(acc.balance),
                        style: _t(wide ? 32 : 26, FontWeight.w700,
                            acc.balance < 0 ? _K.neg : _K.ink,
                            tab: true, ls: -0.5)),
                    const SizedBox(height: 2),
                    Text(
                      acc.lastMovement == null
                          ? 'No activity yet'
                          : 'Last activity ${DateFormat('d MMM yyyy, HH:mm').format(acc.lastMovement!)}',
                      style: _t(12, FontWeight.w400, _K.muted),
                    ),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _primaryBtn('Deposit', Icons.add,
                        acc.active ? () => _money(acc, true) : null),
                    _ghostBtn('Withdraw', Icons.remove,
                        acc.active ? () => _money(acc, false) : null),
                    _ghostBtn('Transfer', Icons.swap_horiz,
                        acc.active ? () => _transfer(acc) : null),
                  ]),
                ],
              ),
            );

            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(5, 5, pad.right, pad.bottom),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Header
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: _K.ink),
                        tooltip: 'Back to accounts',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: title),
                      if (wide) ...[const SizedBox(width: 12), actions],
                    ]),
                    if (!wide) ...[
                      const SizedBox(height: 10),
                      Padding(padding: const EdgeInsets.only(left: 8), child: actions),
                    ],
                    const SizedBox(height: 14),
                    balanceCard,
                    const SizedBox(height: 14),
                    _movements(wide),
                  ]),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _movements(bool wide) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _movStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Panel(
            title: 'Transactions',
            child: _Empty(
              icon: Icons.error_outline,
              title: 'Could not load transactions',
              message: '${snap.error}',
            ),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        double moneyIn = 0, moneyOut = 0;
        for (final d in docs) {
          final m = d.data();
          final amt = _d(m['amount']);
          if (_inTypes.contains((m['type'] ?? 'deposit').toString())) {
            moneyIn += amt;
          } else {
            moneyOut += amt;
          }
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatGrid([
            _Stat('Money in', _ugx(moneyIn), sub: 'Last ${docs.length} transactions', color: _K.pos),
            _Stat('Money out', _ugx(moneyOut), sub: 'Last ${docs.length} transactions', color: _K.neg),
            _Stat('Net movement', _ugx(moneyIn - moneyOut),
                color: moneyIn - moneyOut < 0 ? _K.neg : null),
          ]),
          const SizedBox(height: 14),
          _Panel(
            title: 'Transactions',
            subtitle: '${docs.length} shown',
            padding: EdgeInsets.zero,
            child: docs.isEmpty
                ? const _Empty(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Deposits, withdrawals and transfers will appear here.',
                  )
                : Column(children: [
                    if (wide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Row(children: [
                          SizedBox(width: 110, child: _hdr('Date')),
                          Expanded(flex: 5, child: _hdr('Description')),
                          Expanded(flex: 2, child: _hdr('Type')),
                          Expanded(
                              flex: 3,
                              child: Align(
                                  alignment: Alignment.centerRight, child: _hdr('Amount'))),
                          Expanded(
                              flex: 3,
                              child: Align(
                                  alignment: Alignment.centerRight, child: _hdr('Balance'))),
                        ]),
                      ),
                    for (int i = 0; i < docs.length; i++) ...[
                      const Divider(height: 1, color: _K.line),
                      _movementRow(docs[i].data(), wide),
                    ],
                  ]),
          ),
        ]);
      },
    );
  }

  Widget _movementRow(Map<String, dynamic> m, bool wide) {
    final type = (m['type'] ?? 'deposit').toString();
    final inflow = _inTypes.contains(type);
    final amount = _d(m['amount']);
    final after = m['balanceAfter'];
    final desc = (m['description'] ?? '').toString();
    final date = _dt(m['date']);
    final c = inflow ? _K.pos : _K.neg;
    final label = _label(type);
    final amountText = '${inflow ? '+' : '-'}${_ugx(amount)}';

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(inflow ? Icons.south_west : Icons.north_east, size: 16, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(desc.isEmpty ? label : desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _t(13, FontWeight.w500, _K.ink)),
              const SizedBox(height: 2),
              Text(
                '$label${date == null ? '' : '  ·  ${DateFormat('d MMM yyyy, HH:mm').format(date)}'}',
                style: _t(11.5, FontWeight.w400, _K.muted),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amountText, style: _t(13.5, FontWeight.w700, c, tab: true)),
            if (after != null) ...[
              const SizedBox(height: 2),
              Text('Bal ${_ugx(_d(after))}',
                  style: _t(11.5, FontWeight.w400, _K.muted, tab: true)),
            ],
          ]),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(date == null ? '—' : DateFormat('d MMM yyyy').format(date),
              style: _t(12.5, FontWeight.w400, _K.muted, tab: true)),
        ),
        Expanded(
          flex: 5,
          child: Text(desc.isEmpty ? label : desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _t(13, FontWeight.w500, _K.ink)),
        ),
        Expanded(
          flex: 2,
          child: Align(alignment: Alignment.centerLeft, child: _Pill(label, c)),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(amountText, style: _t(13.5, FontWeight.w700, c, tab: true)),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(after == null ? '—' : _ugx(_d(after)),
                style: _t(13, FontWeight.w400, _K.muted, tab: true)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT DETAILS (standalone, pushed as its own route)
// ─────────────────────────────────────────────────────────────────────────────
class AccountDetailsScreen extends StatefulWidget {
  final String accountId;
  const AccountDetailsScreen({super.key, required this.accountId});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _accStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _movStream;

  @override
  void initState() {
    super.initState();
    final ref = FirebaseFirestore.instance.collection('accounts').doc(widget.accountId);
    _accStream = ref.snapshots();
    _movStream = ref.collection('movements').orderBy('date', descending: true).limit(200).snapshots();
  }

  Future<void> _money(_Account a, bool deposit) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MoneyDialog(account: a, deposit: deposit),
    );
    if (ok == true && mounted) {
      _toast(context, deposit ? 'Deposit recorded' : 'Withdrawal recorded');
    }
  }

  Future<void> _transfer(_Account a) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferDialog(from: a),
    );
    if (ok == true && mounted) _toast(context, 'Transfer completed');
  }

  Future<void> _edit(_Account a) async {
    final snap = await FirebaseFirestore.instance.collection('accounts').get();
    final taken = snap.docs
        .where((d) => d.id != a.id)
        .map((d) => (d.data()['name'] ?? '').toString().toLowerCase())
        .toSet();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AccountDialog(existing: a, takenNames: taken),
    );
    if (ok == true && mounted) _toast(context, 'Account updated');
  }

  Future<void> _delete(_Account a) async {
    final db = FirebaseFirestore.instance;
    final hist = await db.collection('accounts').doc(a.id).collection('movements').limit(1).get();
    if (!mounted) return;
    if (hist.docs.isNotEmpty || a.balance.abs() > 0.5) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Can\'t delete this account', style: _t(17, FontWeight.w700, _K.ink)),
          content: Text(
            'It has a balance or transaction history, which the books depend on. '
            'Deactivate it instead (Edit → Active off) to hide it without losing records.',
            style: _t(13.5, FontWeight.w400, _K.sub),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete "${a.name}"?', style: _t(17, FontWeight.w700, _K.ink)),
        content: Text('This account is empty and has no history. This cannot be undone.',
            style: _t(13.5, FontWeight.w400, _K.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _K.neg),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await db.collection('accounts').doc(a.id).delete();
      await _audit('account_deleted', 'Deleted account "${a.name}"', meta: {'accountId': a.id});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast(context, _errText(e), ok: false);
    }
  }

  PreferredSizeWidget _bar(List<Widget> actions) => AppBar(
        elevation: 0,
        backgroundColor: _K.accent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Account details', style: _t(18, FontWeight.w600, Colors.white)),
        actions: actions,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _accStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
              backgroundColor: _K.bg,
              appBar: _bar(const []),
              body: _Empty(
                  icon: Icons.error_outline,
                  title: 'Could not load account',
                  message: '${snap.error}'));
        }
        if (!snap.hasData) {
          return Scaffold(
              backgroundColor: _K.bg,
              appBar: _bar(const []),
              body: const Center(child: CircularProgressIndicator()));
        }
        if (!snap.data!.exists) {
          return Scaffold(
              backgroundColor: _K.bg,
              appBar: _bar(const []),
              body: const _Empty(
                  icon: Icons.search_off,
                  title: 'Account not found',
                  message: 'It may have been deleted.'));
        }
        final a = _Account.from(snap.data!);
        final color = _typeColor(a.type);

        return Scaffold(
          backgroundColor: _K.bg,
          appBar: _bar([
            IconButton(
                tooltip: 'Edit account',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _edit(a)),
            IconButton(
                tooltip: 'Delete account',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(a)),
          ]),
          body: LayoutBuilder(builder: (context, box) {
            return SingleChildScrollView(
              padding: _pagePad(box.maxWidth),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _K.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 14,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_typeIcon(a.type), color: color),
                              ),
                              const SizedBox(width: 14),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(a.name, style: _t(20, FontWeight.w700, _K.ink, ls: -0.3)),
                                const SizedBox(height: 4),
                                Wrap(spacing: 8, children: [
                                  _Pill(_typeLabel(a.type), color),
                                  _Pill(a.active ? 'Active' : 'Inactive',
                                      a.active ? _K.pos : _K.muted),
                                  if (a.number != null) _Pill(a.number!, _K.muted),
                                ]),
                              ]),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('CURRENT BALANCE',
                                  style: _t(10.5, FontWeight.w600, _K.muted, ls: 0.6)),
                              const SizedBox(height: 4),
                              Text(_ugx(a.balance),
                                  style: _t(28, FontWeight.w700,
                                      a.balance < 0 ? _K.neg : _K.ink, tab: true, ls: -0.5)),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _primaryBtn('Deposit', Icons.add, a.active ? () => _money(a, true) : null),
                          _ghostBtn('Withdraw', Icons.remove,
                              a.active ? () => _money(a, false) : null),
                          _ghostBtn('Transfer', Icons.swap_horiz,
                              a.active ? () => _transfer(a) : null),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _movements(),
                  ]),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _movements() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _movStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Panel(
              title: 'Transactions',
              child: _Empty(
                  icon: Icons.error_outline,
                  title: 'Could not load transactions',
                  message: '${snap.error}'));
        }
        if (!snap.hasData) {
          return const Padding(
              padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs;
        const inTypes = {'deposit', 'transfer_in', 'opening'};
        double moneyIn = 0, moneyOut = 0;
        for (final d in docs) {
          final m = d.data();
          final amt = _d(m['amount']);
          if (inTypes.contains((m['type'] ?? 'deposit').toString())) {
            moneyIn += amt;
          } else {
            moneyOut += amt;
          }
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatGrid([
            _Stat('Money in', _ugx(moneyIn), sub: 'Last ${docs.length} transactions', color: _K.pos),
            _Stat('Money out', _ugx(moneyOut), sub: 'Last ${docs.length} transactions', color: _K.neg),
            _Stat('Net movement', _ugx(moneyIn - moneyOut),
                color: moneyIn - moneyOut < 0 ? _K.neg : null),
          ]),
          const SizedBox(height: 16),
          _Panel(
            title: 'Transactions',
            subtitle: '${docs.length} shown',
            padding: EdgeInsets.zero,
            child: docs.isEmpty
                ? const _Empty(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    message: 'Deposits, withdrawals, transfers, income and expenses will appear here.')
                : Column(children: [
                    for (int i = 0; i < docs.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _K.line),
                      _movementRow(docs[i].data(), inTypes),
                    ],
                  ]),
          ),
        ]);
      },
    );
  }

  Widget _movementRow(Map<String, dynamic> m, Set<String> inTypes) {
    final type = (m['type'] ?? 'deposit').toString();
    final inflow = inTypes.contains(type);
    final amount = _d(m['amount']);
    final desc = (m['description'] ?? '').toString();
    final date = _dt(m['date']);
    final after = m['balanceAfter'];
    final label = switch (type) {
      'withdrawal' => 'Withdrawal',
      'transfer_in' => 'Transfer in',
      'transfer_out' => 'Transfer out',
      'opening' => 'Opening balance',
      _ => 'Deposit',
    };
    final c = inflow ? _K.pos : _K.neg;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: c.withOpacity(0.10), shape: BoxShape.circle),
          child: Icon(inflow ? Icons.south_west : Icons.north_east, size: 16, color: c),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc.isEmpty ? label : desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _t(13, FontWeight.w500, _K.ink)),
            const SizedBox(height: 2),
            Text(
              '$label${date == null ? '' : '  ·  ${DateFormat('d MMM yyyy, HH:mm').format(date)}'}',
              style: _t(11.5, FontWeight.w400, _K.muted),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${inflow ? '+' : '-'}${_ugx(amount)}',
              style: _t(13.5, FontWeight.w700, c, tab: true)),
          if (after != null) ...[
            const SizedBox(height: 2),
            Text('Bal ${_ugx(_d(after))}', style: _t(11.5, FontWeight.w400, _K.muted, tab: true)),
          ],
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INCOME & EXPENSES (one shared ledger view, two configurations)
// ─────────────────────────────────────────────────────────────────────────────
class _Entry {
  final String id;
  final DateTime? date;
  final double amount;
  final String category, description, party, method;
  final bool auto;
  final DocumentReference<Map<String, dynamic>>? ref;
  final String? accountId;

  const _Entry({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.description,
    this.party = '',
    this.method = '',
    this.auto = false,
    this.ref,
    this.accountId,
  });

  factory _Entry.manual(QueryDocumentSnapshot<Map<String, dynamic>> d, bool income) {
    final m = d.data();
    final party = (m['party'] ?? (income ? m['source'] : m['payee']) ?? '').toString();
    return _Entry(
      id: d.id,
      date: _dt(m['date']),
      amount: _d(m['amount']),
      category: (m['category'] ?? 'Other').toString(),
      description: (m['description'] ?? '').toString(),
      party: party,
      method: (m['method'] ?? '').toString(),
      ref: d.reference,
      accountId: (m['accountId'] ?? '').toString(),
    );
  }
}

/// Loan interest and charges taken straight from the repayments ledger.
Future<List<_Entry>> _loadRepaymentIncome() async {
  final snap = await FirebaseFirestore.instance.collection(AppConstants.repaymentsCol).get();
  final out = <_Entry>[];
  for (final d in snap.docs) {
    final m = d.data();
    if (m['reversed'] == true ||
        m['isReversed'] == true ||
        (m['status'] ?? '').toString().toLowerCase() == 'reversed') {
      continue;
    }
    final date = _dt(m['paymentDate'] ?? m['date'] ?? m['createdAt']);
    final who = (m['memberName'] ?? m['farmerName'] ?? '').toString();
    final method = (m['paymentMethod'] ?? m['method'] ?? '').toString();
    final interest = _d(m['interestAmount']);
    final charges = _d(m['chargesAmount']);
    final desc = who.isEmpty ? 'Loan repayment' : 'Loan repayment · $who';
    if (interest > 0.5) {
      out.add(_Entry(
          id: '${d.id}-i',
          date: date,
          amount: interest,
          category: 'Loan Interest',
          description: desc,
          party: who,
          method: method,
          auto: true));
    }
    if (charges > 0.5) {
      out.add(_Entry(
          id: '${d.id}-c',
          date: date,
          amount: charges,
          category: 'Loan Charges',
          description: desc,
          party: who,
          method: method,
          auto: true));
    }
  }
  return out;
}

class _LedgerConfig {
  final bool income;
  final String collection, title, subtitle, addLabel, partyLabel, noun;
  final List<String> categories;
  final Color color;
  final Future<List<_Entry>> Function()? autoLoader;

  const _LedgerConfig({
    required this.income,
    required this.collection,
    required this.title,
    required this.subtitle,
    required this.addLabel,
    required this.partyLabel,
    required this.noun,
    required this.categories,
    required this.color,
    this.autoLoader,
  });
}

final _incomeConfig = _LedgerConfig(
  income: true,
  collection: 'income',
  title: 'Income',
  subtitle: 'Money earned by the SACCO',
  addLabel: 'Record income',
  partyLabel: 'Received from',
  noun: 'income',
  categories: const [
    'Membership Fees',
    'Service Charges',
    'Loan Processing Fees',
    'Penalties',
    'Investment Income',
    'Other',
  ],
  color: _K.pos,
  autoLoader: _loadRepaymentIncome,
);

const _expenseConfig = _LedgerConfig(
  income: false,
  collection: 'expenses',
  title: 'Expenses',
  subtitle: 'Money spent running the SACCO',
  addLabel: 'Record expense',
  partyLabel: 'Paid to',
  noun: 'expense',
  categories: [
    'Salaries',
    'Rent',
    'Utilities',
    'Transport',
    'Airtime & Data',
    'Stationery',
    'Marketing',
    'Equipment',
    'Bank Charges',
    'Professional Fees',
    'Operational',
    'Other',
  ],
  color: _K.neg,
);

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});
  @override
  Widget build(BuildContext context) => _LedgerView(config: _incomeConfig);
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});
  @override
  Widget build(BuildContext context) => const _LedgerView(config: _expenseConfig);
}

class _LedgerView extends StatefulWidget {
  final _LedgerConfig config;
  const _LedgerView({required this.config});

  @override
  State<_LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends State<_LedgerView> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  final _search = TextEditingController();
  _Range _range = _Range.thisMonth;
  DateTimeRange? _custom;
  String _category = 'All';
  int _limit = 100;

  List<_Entry> _auto = [];
  bool _autoLoading = false;
  String? _autoError;

  _LedgerConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection(cfg.collection)
        .orderBy('date', descending: true)
        .snapshots();
    _loadAuto();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadAuto() async {
    final loader = cfg.autoLoader;
    if (loader == null) return;
    setState(() {
      _autoLoading = true;
      _autoError = null;
    });
    try {
      final list = await loader();
      if (!mounted) return;
      setState(() {
        _auto = list;
        _autoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _autoLoading = false;
        _autoError = e.toString();
      });
    }
  }

  Future<void> _pickCustom() async {
    final r = await _pickRange(context, _custom);
    if (r != null) {
      setState(() {
        _custom = r;
        _range = _Range.custom;
        _limit = 100;
      });
    }
  }

  Future<void> _add() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EntryDialog(cfg: cfg),
    );
    if (ok == true && mounted) {
      _toast(context, '${cfg.income ? 'Income' : 'Expense'} recorded');
    }
  }

  Future<void> _reverse(_Entry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reverse this ${cfg.noun}?', style: _t(17, FontWeight.w700, _K.ink)),
        content: Text(
          '${e.description}  ·  ${_ugx(e.amount)}\n\n'
          'The record is removed and ${cfg.income ? 'the money is taken back out of' : 'the money is returned to'} '
          'the account. This is written to the audit trail.',
          style: _t(13.5, FontWeight.w400, _K.sub),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _K.neg),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );
    if (ok != true || e.ref == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final accId = e.accountId;
      await db.runTransaction((tx) async {
        final entSnap = await tx.get(e.ref!);
        if (!entSnap.exists) throw const _Fail('This record was already removed.');
        DocumentReference<Map<String, dynamic>>? accRef;
        var current = 0.0;
        var hasAcc = false;
        if (accId != null && accId.isNotEmpty) {
          accRef = db.collection('accounts').doc(accId);
          final s = await tx.get(accRef);
          if (s.exists) {
            hasAcc = true;
            current = _d(s.data()?['balance']);
          }
        }
        if (hasAcc) {
          if (cfg.income && e.amount > current + 0.5) {
            throw _Fail('The account only has ${_ugx(current)}, so this income can\'t be taken back out.');
          }
          _post(tx, accRef!, current,
              inflow: !cfg.income,
              amount: e.amount,
              description: 'Reversal: ${e.description}',
              type: cfg.income ? 'withdrawal' : 'deposit');
        }
        tx.delete(e.ref!);
      });
      await _audit('${cfg.noun}_reversed', 'Reversed ${cfg.noun} of ${_ugx(e.amount)}: ${e.description}',
          meta: {'entryId': e.id, 'amount': e.amount});
      if (mounted) _toast(context, '${cfg.income ? 'Income' : 'Expense'} reversed');
    } catch (err) {
      if (mounted) _toast(context, _errText(err), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _K.bg,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Empty(
                icon: Icons.error_outline,
                title: 'Could not load ${cfg.noun} records',
                message: '${snap.error}');
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final manual = snap.data!.docs.map((d) => _Entry.manual(d, cfg.income)).toList();
          final everything = [...manual, ..._auto];

          final r = _resolve(_range, _custom);
          bool inRange(_Entry e) {
            if (r == null) return true;
            final d = e.date;
            if (d == null) return false;
            return !d.isBefore(r.start) && d.isBefore(r.end);
          }

          final inPeriod = everything.where(inRange).toList();
          final byCat = <String, double>{};
          for (final e in inPeriod) {
            byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
          }
          final catOrder = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          if (_category != 'All' && !byCat.containsKey(_category)) _category = 'All';

          final q = _search.text.trim().toLowerCase();
          final filtered = inPeriod.where((e) {
            if (_category != 'All' && e.category != _category) return false;
            if (q.isEmpty) return true;
            return e.description.toLowerCase().contains(q) ||
                e.party.toLowerCase().contains(q) ||
                e.category.toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) => (b.date ?? DateTime(2000)).compareTo(a.date ?? DateTime(2000)));

          final total = filtered.fold<double>(0, (s, e) => s + e.amount);
          final periodTotal = inPeriod.fold<double>(0, (s, e) => s + e.amount);

          final List<_Stat> stats;
          if (cfg.income) {
            final interest = byCat['Loan Interest'] ?? 0;
            stats = [
              _Stat('Total income', _ugx(periodTotal), sub: _rangeLabel(), color: _K.pos),
              _Stat('Loan interest', _ugx(interest), sub: 'From repayments (automatic)'),
              _Stat('Fees & other income', _ugx(periodTotal - interest),
                  sub: 'Charges, fees, investments'),
              _Stat('Transactions', '${inPeriod.length}', sub: _rangeLabel()),
            ];
          } else {
            final top = catOrder.isEmpty ? null : catOrder.first;
            final biggest = inPeriod.isEmpty
                ? 0.0
                : inPeriod.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
            stats = [
              _Stat('Total expenses', _ugx(periodTotal), sub: _rangeLabel(), color: _K.neg),
              _Stat('Largest category', top == null ? '—' : _ugx(top.value),
                  sub: top?.key ?? 'No expenses in this period'),
              _Stat('Biggest single expense', _ugx(biggest)),
              _Stat('Transactions', '${inPeriod.length}', sub: _rangeLabel()),
            ];
          }

          return LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 1000;
            final listPanel = _listPanel(filtered, total, catOrder);
            final sidePanel = _breakdownPanel(catOrder, periodTotal);
            return SingleChildScrollView(
              padding: _pagePad(box.maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _PageHeader(
                  title: cfg.title,
                  subtitle: '${cfg.subtitle}  ·  ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}',
                  actions: [
                    if (cfg.autoLoader != null)
                      _ghostBtn(_autoLoading ? 'Refreshing…' : 'Refresh',
                          Icons.refresh, _autoLoading ? null : _loadAuto),
                    _primaryBtn(cfg.addLabel, Icons.add, _add),
                  ],
                ),
                const SizedBox(height: 16),
                _RangeChips(
                  value: _range,
                  custom: _custom,
                  onChanged: (v) => setState(() {
                    _range = v;
                    _limit = 100;
                  }),
                  onCustom: _pickCustom,
                ),
                const SizedBox(height: 16),
                _StatGrid(stats),
                const SizedBox(height: 16),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: listPanel),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: sidePanel),
                  ])
                else ...[
                  sidePanel,
                  const SizedBox(height: 16),
                  listPanel,
                ],
              ]),
            );
          });
        },
      ),
    );
  }

  String _rangeLabel() => switch (_range) {
        _Range.thisMonth => DateFormat('MMMM yyyy').format(DateTime.now()),
        _Range.lastMonth =>
          DateFormat('MMMM yyyy').format(DateTime(DateTime.now().year, DateTime.now().month - 1, 1)),
        _Range.thisYear => '${DateTime.now().year}',
        _Range.allTime => 'All time',
        _Range.custom => _custom == null
            ? 'Custom range'
            : '${DateFormat('d MMM').format(_custom!.start)} – ${DateFormat('d MMM yyyy').format(_custom!.end)}',
      };

  // ── Category breakdown ─────────────────────────────────────────────────────
  Widget _breakdownPanel(List<MapEntry<String, double>> cats, double periodTotal) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Panel(
        title: 'By category',
        subtitle: _rangeLabel(),
        child: cats.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('Nothing recorded in this period.',
                        style: _t(12.5, FontWeight.w400, _K.muted))),
              )
            : Column(children: [
                for (final e in cats)
                  InkWell(
                    onTap: () => setState(() => _category = _category == e.key ? 'All' : e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: Text(e.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _t(12.5, _category == e.key ? FontWeight.w700 : FontWeight.w500,
                                    _K.ink)),
                          ),
                          Text(_ugx(e.value), style: _t(12.5, FontWeight.w600, _K.ink, tab: true)),
                          SizedBox(
                            width: 48,
                            child: Text(
                              periodTotal > 0
                                  ? '${(e.value / periodTotal * 100).toStringAsFixed(0)}%'
                                  : '—',
                              textAlign: TextAlign.right,
                              style: _t(12, FontWeight.w400, _K.muted, tab: true),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: periodTotal > 0 ? (e.value / periodTotal).clamp(0.0, 1.0) : 0,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: AlwaysStoppedAnimation(cfg.color),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ]),
      ),
      if (cfg.income) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FA),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD5DEEA)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 18, color: _K.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _autoError != null
                    ? 'Could not read loan repayments, so loan interest and charges are missing. $_autoError'
                    : 'Loan interest and charges are picked up automatically from recorded loan '
                        'repayments. Use "Record income" for fees and other income only, so nothing is counted twice.',
                style: _t(12, FontWeight.w400, _autoError != null ? _K.neg : _K.sub),
              ),
            ),
          ]),
        ),
      ],
    ]);
  }

  // ── Transactions list ──────────────────────────────────────────────────────
  Widget _listPanel(List<_Entry> items, double total, List<MapEntry<String, double>> cats) {
    final shown = items.take(_limit).toList();
    return _Panel(
      title: 'Transactions',
      subtitle: '${items.length} record${items.length == 1 ? '' : 's'}  ·  ${_ugx(total)}',
      padding: EdgeInsets.zero,
      trailing: _autoLoading
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() => _limit = 100),
                style: _t(13.5, FontWeight.w400, _K.ink),
                decoration: _dec('Search').copyWith(
                  prefixIcon: const Icon(Icons.search, size: 18, color: _K.muted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                decoration: _dec('Category').copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All categories')),
                  for (final c in cats) DropdownMenuItem(value: c.key, child: Text(c.key)),
                ],
                onChanged: (v) => setState(() {
                  _category = v ?? 'All';
                  _limit = 100;
                }),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: _K.line),
        if (items.isEmpty)
          _Empty(
            icon: Icons.receipt_long_outlined,
            title: 'No ${cfg.noun} records',
            message: 'Nothing matches this period and filter.',
            action: _primaryBtn(cfg.addLabel, Icons.add, _add),
          )
        else
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 620;
            return Column(children: [
              if (wide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(children: [
                    SizedBox(width: 96, child: _hdr('Date')),
                    Expanded(flex: 5, child: _hdr('Description')),
                    Expanded(flex: 3, child: _hdr('Category')),
                    Expanded(
                        flex: 3,
                        child: Align(alignment: Alignment.centerRight, child: _hdr('Amount'))),
                    const SizedBox(width: 40),
                  ]),
                ),
              for (int i = 0; i < shown.length; i++) ...[
                const Divider(height: 1, color: _K.line),
                _row(shown[i], wide),
              ],
              if (items.length > shown.length) ...[
                const Divider(height: 1, color: _K.line),
                TextButton(
                  onPressed: () => setState(() => _limit += 100),
                  child: Text('Show more (${items.length - shown.length} remaining)',
                      style: _t(13, FontWeight.w600, _K.accent)),
                ),
              ],
            ]);
          }),
      ]),
    );
  }

  Widget _hdr(String s) =>
      Text(s.toUpperCase(), style: _t(10.5, FontWeight.w600, _K.muted, ls: 0.6));

  Widget _row(_Entry e, bool wide) {
    final sub = [
      if (e.party.isNotEmpty) e.party,
      if (e.method.isNotEmpty) e.method,
    ].join('  ·  ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 96,
          child: Text(e.date == null ? '—' : DateFormat('d MMM yyyy').format(e.date!),
              style: _t(12, FontWeight.w400, _K.muted, tab: true)),
        ),
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(e.description.isEmpty ? e.category : e.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(13, FontWeight.w500, _K.ink)),
              ),
              if (e.auto) ...[const SizedBox(width: 8), const _Pill('Auto', _K.accent)],
            ]),
            if (sub.isNotEmpty || !wide) ...[
              const SizedBox(height: 2),
              Text(
                wide ? sub : [e.category, if (sub.isNotEmpty) sub].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(11.5, FontWeight.w400, _K.muted),
              ),
            ],
          ]),
        ),
        if (wide)
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerLeft, child: _Pill(e.category, cfg.color)),
          ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text('${cfg.income ? '+' : '-'}${_ugx(e.amount)}',
                  style: _t(13.5, FontWeight.w700, cfg.color, tab: true)),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: e.auto || e.ref == null
              ? null
              : IconButton(
                  tooltip: 'Reverse',
                  icon: const Icon(Icons.undo, size: 18, color: _K.muted),
                  onPressed: () => _reverse(e),
                ),
        ),
      ]),
    );
  }
}

// ── Record income / expense ──────────────────────────────────────────────────
class _EntryDialog extends StatefulWidget {
  final _LedgerConfig cfg;
  const _EntryDialog({required this.cfg});

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _amount = TextEditingController();
  final _party = TextEditingController();
  final _desc = TextEditingController();
  final _reference = TextEditingController();
  late String _category;
  String _method = 'Cash';
  DateTime _date = DateTime.now();
  String? _accountId;
  List<_Account> _accounts = [];
  bool _busy = false;
  String? _error;

  _LedgerConfig get cfg => widget.cfg;

  @override
  void initState() {
    super.initState();
    _category = cfg.categories.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _party.dispose();
    _desc.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (p != null) setState(() => _date = p);
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    final desc = _desc.text.trim();
    final party = _party.text.trim();
    if (amt <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (!cfg.income && party.isEmpty) {
      setState(() => _error = 'Enter who was paid.');
      return;
    }
    if (desc.isEmpty) {
      setState(() => _error = 'Enter a description.');
      return;
    }
    if (_accountId == null) {
      setState(() => _error = cfg.income
          ? 'Choose the account the money went into.'
          : 'Choose the account the money was paid from.');
      return;
    }
    final acc = _accounts.firstWhere((a) => a.id == _accountId);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final accRef = db.collection('accounts').doc(acc.id);
      final entRef = db.collection(cfg.collection).doc();
      await db.runTransaction((tx) async {
        final s = await tx.get(accRef);
        if (!s.exists) throw const _Fail('That account no longer exists.');
        final current = _d(s.data()?['balance']);
        if (!cfg.income && amt > current + 0.5) {
          throw _Fail('Insufficient balance in "${acc.name}". Available: ${_ugx(current)}.');
        }
        _post(tx, accRef, current,
            inflow: cfg.income,
            amount: amt,
            description: '${cfg.income ? 'Income' : 'Expense'}: $desc',
            type: cfg.income ? 'deposit' : 'withdrawal');
        tx.set(entRef, {
          'amount': amt,
          'category': _category,
          'description': desc,
          'party': party,
          if (cfg.income) 'source': party else 'payee': party,
          'method': _method,
          'reference': _reference.text.trim(),
          'accountId': acc.id,
          'accountName': acc.name,
          'currency': 'UGX',
          'date': Timestamp.fromDate(DateTime(_date.year, _date.month, _date.day, 12)),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': FirebaseService.sessionUid,
        });
      });
      await _audit('${cfg.noun}_recorded',
          'Recorded ${cfg.noun} of ${_ugx(amt)} ($_category): $desc',
          meta: {'entryId': entRef.id, 'accountId': acc.id, 'amount': amt});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(cfg.addLabel, style: _t(17, FontWeight.w700, _K.ink)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: _dec('Amount', prefix: 'UGX '),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  isExpanded: true,
                  decoration: _dec('Category'),
                  items: [
                    for (final c in cfg.categories) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: _dec('Date'),
                    child: Row(children: [
                      Expanded(
                          child: Text(DateFormat('d MMM yyyy').format(_date),
                              style: _t(13.5, FontWeight.w400, _K.ink))),
                      const Icon(Icons.calendar_today_outlined, size: 16, color: _K.muted),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            TextField(controller: _party, decoration: _dec(cfg.partyLabel)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _method,
                  isExpanded: true,
                  decoration: _dec('Method'),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  ],
                  onChanged: (v) => setState(() => _method = v ?? _method),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _reference, decoration: _dec('Reference (optional)'))),
            ]),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('accounts')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator(minHeight: 2);
                _accounts = snap.data!.docs.map(_Account.from).toList()
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                if (_accounts.isEmpty) {
                  return Text('Create an account in Cash & Bank first.',
                      style: _t(12.5, FontWeight.w500, _K.warn));
                }
                return DropdownButtonFormField<String>(
                  value: _accountId,
                  isExpanded: true,
                  decoration: _dec(cfg.income ? 'Deposit to account' : 'Pay from account'),
                  items: [
                    for (final a in _accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.name}  ·  ${_ugx(a.balance)}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                );
              },
            ),
            const SizedBox(height: 14),
            TextField(controller: _desc, maxLines: 2, decoration: _dec('Description')),
            _errorLine(_error),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        _primaryBtn(_busy ? 'Saving…' : 'Save', Icons.check, _busy ? null : _save),
      ],
    );
  }
}
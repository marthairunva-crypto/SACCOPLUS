import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/teller_service.dart';
import '../../services/till_service.dart';
import '../../models/till_session.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import 'till_reports_screen.dart';
import 'till_management_screen.dart';
import 'till_ui.dart';

// Extra accent colours that match the Till design system (till_ui.dart).
const _cyan = Color(0xFF0E7490);
const _lime = Color(0xFF4D7C0F);
const _brown = Color(0xFF92400E);
const _indigo = Color(0xFF4338CA);
const _pink = Color(0xFFBE185D);
const _orange = Color(0xFFC2410C);

String _pretty(String s) {
  final t = s.replaceAll('_', ' ').trim();
  return t.isEmpty ? '' : '${t[0].toUpperCase()}${t.substring(1)}';
}

double _dialogWidth(BuildContext c, double max) =>
    math.min(max, MediaQuery.of(c).size.width - 32 - 48);

const _dlgInset = EdgeInsets.symmetric(horizontal: 16, vertical: 24);

ShapeBorder get _dlgShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

Widget _kv(String label, String value, {Color c = TC.text, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ts(13, c: TC.muted)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: ts(13.5, w: bold ? FontWeight.w700 : FontWeight.w600, c: c)),
          ),
        ],
      ),
    );

/// Professional Teller Center
class TellerCenterReorganized extends StatefulWidget {
  final Function(String loanId, Map<String, dynamic>? loanData)? onLoanTap;
  final Function(String screen)? onNavigate;

  const TellerCenterReorganized({super.key, this.onLoanTap, this.onNavigate});

  @override
  State<TellerCenterReorganized> createState() => _TellerCenterReorganizedState();
}

class _TellerCenterReorganizedState extends State<TellerCenterReorganized> {
  final _timeFmt = DateFormat('hh:mm a');

  int _selectedTab = 0;
  String? _selectedCategory;

  // Live till state
  TillSession? _till;
  bool _tillLoaded = false;
  Object? _tillError;
  StreamSubscription<TillSession?>? _tillSub;

  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = TellerService.getTransactionHistory(limit: 100);
    _listenTill();
  }

  @override
  void dispose() {
    _tillSub?.cancel();
    super.dispose();
  }

  void _listenTill() {
    _tillSub?.cancel();
    setState(() {
      _tillLoaded = false;
      _tillError = null;
    });
    _tillSub = TillService.watchOpenSession(FirebaseService.sessionUid).listen(
      (s) {
        if (!mounted) return;
        setState(() {
          _till = s;
          _tillLoaded = true;
          _tillError = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _tillLoaded = true;
          _tillError = e;
        });
      },
    );
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = TellerService.getTransactionHistory(limit: 100);
    });
  }

  void _openTillManagement() {
    // If we have a navigation callback (embedded in dashboard), use it
    if (widget.onNavigate != null) {
      widget.onNavigate!('till_management');
    } else {
      // Otherwise open as a separate screen (standalone mode)
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TillManagementScreen()));
    }
  }

  void _comingSoon(String name) {
    tillToast(context, '$name - available in the next update', warn: true);
  }

  /// Cash transactions need an open till so the balance can update.
  bool _requireTill() {
    if (_till != null) return true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        title: dialogTitle(Icons.lock_outline_rounded, TC.amber, 'Your till is closed'),
        content: Text(
          'Open your till before processing cash transactions, so every deposit and withdrawal is reflected in your till balance.',
          style: ts(13, c: TC.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not now')),
          ElevatedButton(
            style: primaryButton(TC.navy),
            onPressed: () {
              Navigator.pop(ctx);
              _openTillManagement();
            },
            child: const Text('Open till'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<T?> _withLoading<T>(String message, Future<T> Function() job) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 16),
              Expanded(child: Text(message, style: ts(14))),
            ],
          ),
        ),
      ),
    );
    try {
      final r = await job();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      return r;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) tillToast(context, cleanError(e), error: true);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg,
      appBar: AppBar(
        backgroundColor: TC.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Teller Center',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(17, w: FontWeight.w700, c: Colors.white)),
                  Text(DateFormat('EEE, d MMM yyyy').format(DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(11.5, c: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Till management',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: _openTillManagement,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Column(
            children: [
              _tabBar(w),
              Expanded(child: _content(w)),
            ],
          );
        },
      ),
    );
  }

  Widget _tabBar(double w) {
    final compact = w < 600;
    Widget tab(int i, String label, IconData icon) {
      final sel = _selectedTab == i;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _selectedTab = i;
            _selectedCategory = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? TC.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? TC.navy : TC.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: sel ? Colors.white : TC.muted),
                const SizedBox(width: 7),
                Text(label, style: ts(13, w: FontWeight.w600, c: sel ? Colors.white : TC.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TC.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              tab(0, 'New transaction', Icons.add_circle_outline),
              tab(1, 'History', Icons.history),
              tab(2, 'Requests', Icons.inbox_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(double w) {
    switch (_selectedTab) {
      case 1:
        return _historyView(w);
      case 2:
        return _requestsView(w);
      default:
        return _newTransactionView(w);
    }
  }

  /// Shared page shell: scroll view, centred max width, live till bar on top.
  Widget _page(double w, List<Widget> children) {
    final compact = w < 600;
    final pad = compact ? 12.0 : 24.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tillBar(),
          SizedBox(height: compact ? 16 : 24),
          ...children,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIVE TILL BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _tillBar() {
    if (!_tillLoaded) {
      return Container(
        height: 104,
        decoration: cardDeco(),
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_tillError != null) {
      return _tillNotice(
        icon: Icons.error_outline,
        color: TC.red,
        title: 'Could not load your till',
        message: cleanError(_tillError!),
        action: 'Retry',
        onTap: _listenTill,
      );
    }
    final s = _till;
    if (s == null) {
      return _tillNotice(
        icon: Icons.lock_outline_rounded,
        color: TC.amber,
        title: 'Your till is closed',
        message: 'Open your till to process cash deposits and withdrawals. Your balance updates live once it is open.',
        action: 'Open till',
        onTap: _openTillManagement,
      );
    }

    final expected = TillService.expectedCashOf(s);

    Widget stat(String label, String value, IconData icon, Color iconColor) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(11, w: FontWeight.w500, c: Colors.white70)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: ts(14.5, w: FontWeight.w700, c: Colors.white)),
            ),
          ],
        );

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 760;
      final compact = box.maxWidth < 480;

      final head = Row(
        children: [
          const StatusPill('OPEN', TC.green, solid: true),
          const SizedBox(width: 10),
          Flexible(
            child: Text('Opened ${_timeFmt.format(s.openedAt)}  •  Live',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, c: Colors.white70)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _openTillManagement,
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: Text(compact ? 'Manage' : 'Manage till', style: ts(12.5, w: FontWeight.w600, c: Colors.white)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );

      final balance = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TILL BALANCE', style: ts(10.5, w: FontWeight.w600, c: Colors.white70, ls: 1)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(ugx(expected), style: ts(compact ? 26 : 32, w: FontWeight.w800, c: Colors.white)),
          ),
        ],
      );

      final inStat = stat('Cash in', ugx(s.totalIn), Icons.south_west_rounded, const Color(0xFF86EFAC));
      final outStat = stat('Cash out', ugx(s.totalOut), Icons.north_east_rounded, const Color(0xFFFCA5A5));
      final floatStat = stat('Opening float', ugx(s.openingFloat), Icons.flag_outlined, Colors.white70);

      return Container(
        padding: EdgeInsets.all(compact ? 16 : 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [TC.navy, Color(0xFF16407A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            SizedBox(height: compact ? 14 : 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: balance),
                  Container(width: 1, height: 44, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: inStat),
                  Expanded(flex: 2, child: outStat),
                  Expanded(flex: 2, child: floatStat),
                ],
              )
            else ...[
              balance,
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withOpacity(0.15)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: inStat),
                  const SizedBox(width: 12),
                  Expanded(child: outStat),
                  const SizedBox(width: 12),
                  Expanded(child: floatStat),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _tillNotice({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String action,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 520;
      final iconBox = Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      );
      final texts = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: ts(15, w: FontWeight.w700, c: TC.navy)),
          const SizedBox(height: 2),
          Text(message, style: ts(12.5, c: TC.muted)),
        ],
      );
      final button = ElevatedButton(
        onPressed: onTap,
        style: primaryButton(TC.navy),
        child: Text(action),
      );

      return Container(
        padding: EdgeInsets.all(narrow ? 16 : 20),
        decoration: cardDeco(color: color.withOpacity(0.05), border: color.withOpacity(0.35)),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: texts),
                  ]),
                  const SizedBox(height: 14),
                  button,
                ],
              )
            : Row(
                children: [
                  iconBox,
                  const SizedBox(width: 16),
                  Expanded(child: texts),
                  const SizedBox(width: 16),
                  button,
                ],
              ),
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED UI PIECES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ts(18, w: FontWeight.w700, c: TC.navy)),
          const SizedBox(height: 2),
          Text(subtitle, style: ts(12.5, c: TC.muted)),
        ],
      );

  Widget _breadcrumb(String current) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _selectedCategory = null),
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text('Categories', style: ts(13, w: FontWeight.w600, c: TC.blue)),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        ),
        Text('/', style: ts(13, c: TC.muted)),
        const SizedBox(width: 8),
        Text(current, style: ts(13, w: FontWeight.w600, c: TC.navy)),
      ],
    );
  }

  Widget _grid(
    List<Widget> children, {
    double minTileWidth = 300,
    double tileHeight = 92,
    int maxColumns = 3,
  }) {
    return LayoutBuilder(builder: (context, c) {
      final cols = math.max(1, math.min(maxColumns, (c.maxWidth / minTileWidth).floor()));
      return GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: tileHeight,
        ),
        children: children,
      );
    });
  }

  Widget _tile({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool soon = false,
    double iconSize = 22,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TC.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(14, w: FontWeight.w700, c: TC.navy)),
                        ),
                        if (soon) ...[
                          const SizedBox(width: 8),
                          const StatusPill('Soon', TC.muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(description,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11.5, c: TC.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: TC.muted.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NEW TRANSACTION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _newTransactionView(double w) {
    switch (_selectedCategory) {
      case 'client':
        return _typesPage(w, 'Client transaction', _clientTypes());
      case 'general':
        return _typesPage(w, 'General ledger', _generalTypes());
      case 'till':
        return _typesPage(w, 'Till administration', _tillAdminTypes());
      case 'bulk':
        return _typesPage(w, 'Bulk transaction', _bulkTypes());
      case 'income':
        return _typesPage(w, 'Income', _incomeTypes());
      case 'expense':
        return _typesPage(w, 'Expense', _expenseTypes());
      default:
        return _categorySelection(w);
    }
  }

  Widget _categorySelection(double w) {
    Widget cat(String id, String title, String desc, IconData icon, Color color) => _tile(
          title: title,
          description: desc,
          icon: icon,
          color: color,
          iconSize: 26,
          onTap: () => setState(() => _selectedCategory = id),
        );

    return _page(w, [
      _sectionHeader('Choose a category', 'What would you like to process?'),
      const SizedBox(height: 16),
      _grid(
        [
          cat('client', 'Client transaction', 'Record transactions for an individual member.',
              Icons.person_outline, TC.blue),
          cat('general', 'General ledger', 'Internal entries such as expenses or journal postings.',
              Icons.account_balance_wallet_outlined, TC.purple),
          cat('till', 'Till administration', 'Open, close, view and reconcile your till.',
              Icons.point_of_sale_outlined, TC.amber),
          cat('bulk', 'Bulk transaction', 'Process many member transactions in one operation.',
              Icons.cloud_upload_outlined, TC.green),
          cat('income', 'Income', 'Record income received that increases till balance.',
              Icons.trending_up, TC.green),
          cat('expense', 'Expense', 'Record expenses paid that decrease till balance.',
              Icons.trending_down, TC.red),
        ],
        minTileWidth: 420,
        tileHeight: 104,
        maxColumns: 2,
      ),
    ]);
  }

  Widget _typesPage(double w, String category, List<Widget> tiles) {
    return _page(w, [
      _breadcrumb(category),
      const SizedBox(height: 8),
      _sectionHeader('Choose a type', category),
      const SizedBox(height: 16),
      _grid(tiles),
    ]);
  }

  List<Widget> _clientTypes() => [
        _tile(
          title: 'Shares deposit',
          description: 'Add funds to a member\'s share account.',
          icon: Icons.add_circle_outline,
          color: TC.green,
          onTap: () => _cashTxn(isDeposit: true, accountType: 'shares', title: 'Shares deposit'),
        ),
        _tile(
          title: 'Shares withdrawal',
          description: 'Withdraw funds from a member\'s share account.',
          icon: Icons.remove_circle_outline,
          color: TC.red,
          onTap: () => _cashTxn(isDeposit: false, accountType: 'shares', title: 'Shares withdrawal'),
        ),
        _tile(
          title: 'Savings deposit',
          description: 'Add funds to a member\'s savings account.',
          icon: Icons.savings_outlined,
          color: TC.blue,
          onTap: () => _cashTxn(isDeposit: true, accountType: 'savings', title: 'Savings deposit'),
        ),
        _tile(
          title: 'Savings withdrawal',
          description: 'Withdraw funds from a member\'s savings account.',
          icon: Icons.money_off_outlined,
          color: TC.amber,
          onTap: () => _cashTxn(isDeposit: false, accountType: 'savings', title: 'Savings withdrawal'),
        ),
        _tile(
          title: 'Fixed deposit',
          description: 'Create a fixed deposit with a maturity date.',
          icon: Icons.account_balance_outlined,
          color: _cyan,
          onTap: _fixedDepositFlow,
        ),
        _tile(
          title: 'Mature fixed deposit',
          description: 'Mature a fixed deposit and move it to savings.',
          icon: Icons.check_circle_outline,
          color: _lime,
          onTap: _matureFlow,
        ),
        _tile(
          title: 'Loan repayment',
          description: 'Record a payment made towards a loan.',
          icon: Icons.payment_outlined,
          color: TC.purple,
          onTap: () => _loanFlow(repayment: true),
        ),
        _tile(
          title: 'Disburse loan',
          description: 'Release funds for an approved loan.',
          icon: Icons.send_outlined,
          color: TC.teal,
          onTap: () => _loanFlow(repayment: false),
        ),
        _tile(
          title: 'Apply fee / penalty',
          description: 'Apply a fee, penalty or application charge.',
          icon: Icons.receipt_outlined,
          color: _brown,
          soon: true,
          onTap: () => _comingSoon('Apply fee'),
        ),
        _tile(
          title: 'Reverse fee / penalty',
          description: 'Reverse a previously applied charge.',
          icon: Icons.undo_outlined,
          color: _indigo,
          soon: true,
          onTap: () => _comingSoon('Reverse fee'),
        ),
        _tile(
          title: 'Loan application fee',
          description: 'Collect fees for loan applications.',
          icon: Icons.request_page_outlined,
          color: _pink,
          soon: true,
          onTap: () => _comingSoon('Loan application fee'),
        ),
        _tile(
          title: 'Error correction',
          description: 'Correct a previously recorded transaction.',
          icon: Icons.edit_outlined,
          color: _orange,
          soon: true,
          onTap: () => _comingSoon('Error correction'),
        ),
      ];

  List<Widget> _generalTypes() => [
        _tile(
          title: 'Journal entry',
          description: 'Record general journal entries for accounting.',
          icon: Icons.book_outlined,
          color: TC.purple,
          onTap: _journalEntry,
        ),
        _tile(
          title: 'Expense payment',
          description: 'Record organisational expenses and bills.',
          icon: Icons.receipt_long_outlined,
          color: TC.red,
          onTap: _expensePayment,
        ),
        _tile(
          title: 'Revenue entry',
          description: 'Record non-member income and revenues.',
          icon: Icons.trending_up_outlined,
          color: TC.green,
          onTap: _revenueEntry,
        ),
      ];

  List<Widget> _bulkTypes() => [
        _tile(
          title: 'Bulk deposits',
          description: 'Process many member deposits from a CSV file.',
          icon: Icons.upload_file_outlined,
          color: TC.green,
          soon: true,
          onTap: () => _comingSoon('Bulk deposits'),
        ),
        _tile(
          title: 'Bulk loan repayments',
          description: 'Process many loan payments from a CSV file.',
          icon: Icons.payment_outlined,
          color: TC.purple,
          soon: true,
          onTap: () => _comingSoon('Bulk loan repayments'),
        ),
        _tile(
          title: 'Bulk dividends',
          description: 'Distribute dividends to many members.',
          icon: Icons.money_outlined,
          color: TC.blue,
          soon: true,
          onTap: () => _comingSoon('Bulk dividends'),
        ),
      ];

  List<Widget> _incomeTypes() => [
        _tile(
          title: 'Record income',
          description: 'Record income received that increases till balance.',
          icon: Icons.add_circle_outline,
          color: TC.green,
          onTap: _revenueEntry, // Reuse the existing revenue entry function
        ),
      ];

  List<Widget> _expenseTypes() => [
        _tile(
          title: 'Record expense',
          description: 'Record expense paid that decreases till balance.',
          icon: Icons.remove_circle_outline,
          color: TC.red,
          onTap: _expensePayment, // Reuse the existing expense payment function
        ),
      ];

  List<Widget> _tillAdminTypes() => [
        _tile(
          title: 'Open / close till',
          description: 'Open your till for the day or close at end of shift.',
          icon: Icons.vpn_key_outlined,
          color: TC.blue,
          onTap: _openTillManagement,
        ),
        _tile(
          title: 'View summary',
          description: 'Live till figures: float, cash in, cash out.',
          icon: Icons.summarize_outlined,
          color: _cyan,
          onTap: _showTillSummary,
        ),
        _tile(
          title: 'Cash check',
          description: 'Count your cash and compare it with the till.',
          icon: Icons.checklist_outlined,
          color: TC.green,
          onTap: _showCashCheck,
        ),
        _tile(
          title: 'Till report',
          description: 'View sessions, variances and approvals.',
          icon: Icons.assessment_outlined,
          color: TC.purple,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const TillReportsScreen())),
        ),
      ];

  // ═══════════════════════════════════════════════════════════════════════════
  // TILL DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════
  void _showTillSummary() {
    if (!_requireTill()) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        title: dialogTitle(Icons.summarize_outlined, _cyan, 'Till summary'),
        content: SizedBox(
          width: _dialogWidth(ctx, 400),
          child: StreamBuilder<TillSession?>(
            stream: TillService.watchOpenSession(FirebaseService.sessionUid),
            initialData: _till,
            builder: (context, snap) {
              final s = snap.data;
              if (s == null) {
                return Text('Your till is closed.', style: ts(13, c: TC.muted));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _kv('Opening float', ugx(s.openingFloat)),
                  _kv('Cash in', ugx(s.totalIn), c: TC.green),
                  _kv('Cash out', ugx(s.totalOut), c: TC.red),
                  const Divider(height: 24),
                  _kv('Till balance', ugx(TillService.expectedCashOf(s)), c: TC.navy, bold: true),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCashCheck() {
    if (!_requireTill()) return;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final expected = _till != null ? TillService.expectedCashOf(_till!) : 0;
          final counted = int.tryParse(ctrl.text.trim()) ?? 0;
          final diff = counted - expected;
          final ok = ctrl.text.trim().isNotEmpty && diff == 0;
          final dColor = ctrl.text.trim().isEmpty ? TC.muted : (ok ? TC.green : TC.red);

          return AlertDialog(
            shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
            insetPadding: _dlgInset,
            title: dialogTitle(Icons.checklist_outlined, TC.green, 'Cash check'),
            content: SizedBox(
              width: _dialogWidth(ctx, 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Count the cash in your till and enter the total. Nothing is saved here.',
                        style: ts(13, c: TC.muted)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: fieldDeco('Cash counted', prefix: 'UGX '),
                      onChanged: (_) => setD(() {}),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: dColor.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          _kv('Till balance', ugx(expected), c: TC.navy),
                          _kv('Counted', ugx(counted), c: TC.blue),
                          const Divider(height: 18),
                          _kv(
                            ctrl.text.trim().isEmpty
                                ? 'Difference'
                                : (diff == 0 ? 'Balanced' : (diff > 0 ? 'Over by' : 'Short by')),
                            ctrl.text.trim().isEmpty ? '-' : ugx(diff.abs()),
                            c: dColor,
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ElevatedButton(
                style: primaryButton(TC.navy),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openTillManagement();
                },
                child: const Text('Close till'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CASH DEPOSIT / WITHDRAWAL
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _cashTxn({
    required bool isDeposit,
    required String accountType,
    required String title,
  }) async {
    if (!_requireTill()) return;

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CashTxnDialog(
        isDeposit: isDeposit,
        accountType: accountType,
        title: title,
        tillCash: TillService.expectedCashOf(_till!),
      ),
    );
    if (res == null || !mounted) return;

    final member = res['member'] as Map<String, dynamic>;
    final amount = res['amount'] as int;

    final till = _till;
    if (till == null) {
      tillToast(context, 'Your till was closed. Open it and try again.', error: true);
      return;
    }

    final result = await _withLoading<Map<String, dynamic>>(
      isDeposit ? 'Processing deposit...' : 'Processing withdrawal...',
      () => isDeposit
          ? TellerService.processDeposit(
              memberId: member['id'],
              memberName: member['name'],
              memberPhone: member['phone'],
              amount: amount,
              accountType: accountType,
              tellerName: currentTellerName(),
              tellerId: FirebaseService.sessionUid,
              tillSession: till,
            )
          : TellerService.processWithdrawal(
              memberId: member['id'],
              memberName: member['name'],
              memberPhone: member['phone'],
              amount: amount,
              accountType: accountType,
              tellerName: currentTellerName(),
              tellerId: FirebaseService.sessionUid,
              tillSession: till,
            ),
    );
    if (result == null || !mounted) return;

    if (result['success'] == true) {
      final txn = (result['transaction'] as Map?) ?? const {};
      _showReceipt(
        type: isDeposit ? 'Deposit' : 'Withdrawal',
        amount: amount,
        memberName: member['name'].toString(),
        accountType: accountType,
        accountNumber: (member['accountNumber'] ?? member['memberNumber'] ?? member['phone'] ?? '').toString(),
        receiptNumber: (txn['receiptNumber'] ?? '').toString(),
      );
      setState(() {
        _selectedTab = 1;
        _selectedCategory = null;
      });
      _refreshHistory();
    } else {
      tillToast(context, (result['message'] ?? 'Transaction failed').toString(), error: true);
    }
  }

  void _showReceipt({
    required String type,
    required int amount,
    required String memberName,
    required String accountType,
    required String accountNumber,
    required String receiptNumber,
  }) {
    final last3 = accountNumber.length >= 3 ? accountNumber.substring(accountNumber.length - 3) : accountNumber;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: TC.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: TC.green, size: 38),
                ),
                const SizedBox(height: 14),
                Text('$type successful', style: ts(19, w: FontWeight.w700, c: TC.navy)),
                const SizedBox(height: 4),
                Text('Your till balance has been updated.', style: ts(12.5, c: TC.muted)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TC.border),
                  ),
                  child: Column(
                    children: [
                      _kv('Amount', ugx(amount), c: TC.navy, bold: true),
                      const Divider(height: 8),
                      _kv('Account', '${_pretty(accountType)} • ending $last3'),
                      const Divider(height: 8),
                      _kv('Member', memberName),
                      const Divider(height: 8),
                      _kv('Receipt no.', receiptNumber.isEmpty ? '-' : receiptNumber),
                      const Divider(height: 8),
                      _kv('Date', DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: primaryButton(TC.green),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAL LEDGER ENTRIES
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _journalEntry() async {
    if (!_requireTill()) return;

    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dlgShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(Icons.book_outlined, TC.purple, 'Journal entry'),
          content: SizedBox(
            width: _dialogWidth(ctx, 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record a general journal entry for accounting purposes.', style: ts(13, c: TC.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: fieldDeco('Description', error: err),
                    onChanged: (_) => setD(() => err = null),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDeco('Amount (UGX)', prefix: 'UGX '),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: fieldDeco('Notes (optional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: primaryButton(TC.purple),
              onPressed: () {
                if (descCtrl.text.trim().isEmpty) {
                  setD(() => err = 'Enter a description');
                  return;
                }
                if (int.tryParse(amountCtrl.text.trim()) == null) {
                  setD(() => err = 'Enter amount');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Record entry'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final description = descCtrl.text.trim();
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();

    await _withLoading('Recording journal entry...', () async {
      await TellerService.recordJournalEntry(
        description: description,
        amount: amount,
        notes: notes.isEmpty ? null : notes,
        tellerName: currentTellerName(),
        tellerId: FirebaseService.sessionUid,
      );
    });

    if (mounted) {
      _refreshHistory();
      tillToast(context, 'Journal entry recorded successfully');
    }
  }

  Future<void> _expensePayment() async {
    if (!_requireTill()) return;

    final till = _till;
    if (till == null) {
      tillToast(context, 'Your till was closed. Open it and try again.', error: true);
      return;
    }

    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dlgShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(Icons.receipt_long_outlined, TC.red, 'Expense payment'),
          content: SizedBox(
            width: _dialogWidth(ctx, 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record an organizational expense or bill payment.', style: ts(13, c: TC.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: fieldDeco('Expense description', error: err),
                    onChanged: (_) => setD(() => err = null),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: categoryCtrl,
                    decoration: fieldDeco('Category (e.g., Rent, Utilities, Salaries)'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDeco('Amount paid (UGX)', prefix: 'UGX '),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: fieldDeco('Additional notes (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: TC.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Cash will be deducted from your till balance.',
                              style: ts(11, c: TC.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: primaryButton(TC.red),
              onPressed: () {
                if (descCtrl.text.trim().isEmpty) {
                  setD(() => err = 'Enter expense description');
                  return;
                }
                final amt = int.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) {
                  setD(() => err = 'Enter valid amount');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Record expense'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final description = descCtrl.text.trim();
    final category = categoryCtrl.text.trim();
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();

    await _withLoading('Recording expense payment...', () async {
      await TellerService.recordExpensePayment(
        description: description,
        category: category.isEmpty ? null : category,
        amount: amount,
        notes: notes.isEmpty ? null : notes,
        tellerName: currentTellerName(),
        tellerId: FirebaseService.sessionUid,
        tillSession: till,
      );
    });

    if (mounted) {
      _refreshHistory();
      tillToast(context, 'Expense payment recorded successfully');
    }
  }

  Future<void> _revenueEntry() async {
    if (!_requireTill()) return;

    final till = _till;
    if (till == null) {
      tillToast(context, 'Your till was closed. Open it and try again.', error: true);
      return;
    }

    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final sourceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String? err;
    String selectedSource = 'Buying shares';
    bool showOtherField = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dlgShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(Icons.trending_up_outlined, TC.green, 'Revenue entry'),
          content: SizedBox(
            width: _dialogWidth(ctx, 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Record non-member income and organizational revenues.', style: ts(13, c: TC.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: fieldDeco('Revenue description', error: err),
                    onChanged: (_) => setD(() => err = null),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSource,
                    decoration: fieldDeco('Source'),
                    items: [
                      'Buying shares',
                      'Passbook',
                      'Donation',
                      'Opening account',
                      'Others (Specify)',
                    ].map((source) => DropdownMenuItem(value: source, child: Text(source))).toList(),
                    onChanged: (value) {
                      setD(() {
                        selectedSource = value ?? 'Buying shares';
                        showOtherField = selectedSource == 'Others (Specify)';
                        if (!showOtherField) {
                          sourceCtrl.clear();
                        }
                      });
                    },
                  ),
                  if (showOtherField) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: sourceCtrl,
                      decoration: fieldDeco('Specify source'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDeco('Amount received (UGX)', prefix: 'UGX '),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: fieldDeco('Additional notes (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: TC.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Cash will be added to your till balance.',
                              style: ts(11, c: TC.green)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: primaryButton(TC.green),
              onPressed: () {
                if (descCtrl.text.trim().isEmpty) {
                  setD(() => err = 'Enter revenue description');
                  return;
                }
                final amt = int.tryParse(amountCtrl.text.trim());
                if (amt == null || amt <= 0) {
                  setD(() => err = 'Enter valid amount');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Record revenue'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final description = descCtrl.text.trim();
    final source = showOtherField ? sourceCtrl.text.trim() : selectedSource;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();

    await _withLoading('Recording revenue entry...', () async {
      await TellerService.recordRevenueEntry(
        description: description,
        source: source.isEmpty ? null : source,
        amount: amount,
        notes: notes.isEmpty ? null : notes,
        tellerName: currentTellerName(),
        tellerId: FirebaseService.sessionUid,
        tillSession: till,
      );
    });

    if (mounted) {
      _refreshHistory();
      tillToast(context, 'Revenue entry recorded successfully');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEMBER PICKER (shared)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> _pickMember(String title, IconData icon, Color color, String hint) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        title: dialogTitle(icon, color, title),
        content: SizedBox(
          width: _dialogWidth(ctx, 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hint, style: ts(13, c: TC.muted)),
                const SizedBox(height: 14),
                _MemberSearch(autofocus: true, onSelected: (m) => Navigator.pop(ctx, m)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOANS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loansFor(
    Map<String, dynamic> member, {
    String? status,
  }) async {
    final col = FirebaseFirestore.instance.collection(AppConstants.loansCol);
    final tenant = FirebaseService.sessionTenantId;

    bool statusOk(Map<String, dynamic> d) =>
        status == null || (d['status'] ?? '').toString().toLowerCase() == status.toLowerCase();

    var snap = await col
        .where('farmerId', isEqualTo: member['id'])
        .where('tenantId', isEqualTo: tenant)
        .get();
    var docs = snap.docs.where((d) => statusOk(d.data())).toList();
    if (docs.isNotEmpty) return docs;

    final acct = member['accountNumber'];
    if (acct != null && acct.toString().isNotEmpty) {
      snap = await col
          .where('accountNumber', isEqualTo: acct)
          .where('tenantId', isEqualTo: tenant)
          .get();
      docs = snap.docs.where((d) => statusOk(d.data())).toList();
      if (docs.isNotEmpty) return docs;
    }

    // Fallback: match on member name
    snap = await col.where('tenantId', isEqualTo: tenant).get();
    final name = member['name'].toString().toLowerCase();
    return snap.docs
        .where((d) =>
            (d.data()['memberName'] ?? '').toString().toLowerCase() == name && statusOk(d.data()))
        .toList();
  }

  void _openLoan(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = {'id': doc.id, ...doc.data()};
    if (widget.onLoanTap != null) {
      widget.onLoanTap!(doc.id, data);
    } else {
      Navigator.pushNamed(context, '/loan-details',
          arguments: {'loanId': doc.id, 'initialLoanData': data});
    }
  }

  Future<void> _loanFlow({required bool repayment}) async {
    final member = await _pickMember(
      repayment ? 'Loan repayment' : 'Disburse loan',
      repayment ? Icons.payment_outlined : Icons.send_outlined,
      repayment ? TC.purple : TC.teal,
      repayment
          ? 'Search for the member to view their loans.'
          : 'Search for the member to view their approved loans.',
    );
    if (member == null || !mounted) return;

    final docs = await _withLoading('Loading loans...',
        () => _loansFor(member, status: repayment ? null : 'approved'));
    if (docs == null || !mounted) return;

    if (docs.isEmpty) {
      tillToast(
        context,
        repayment
            ? 'No loans found for ${member['name']}'
            : 'No approved loans awaiting disbursement for ${member['name']}',
        warn: true,
      );
      return;
    }
    if (docs.length == 1) {
      _openLoan(docs.first);
      return;
    }

    final chosen = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        title: dialogTitle(Icons.account_balance, TC.blue, 'Select loan'),
        content: SizedBox(
          width: _dialogWidth(ctx, 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${member['name']} has ${docs.length} loans', style: ts(13, c: TC.muted)),
                const SizedBox(height: 12),
                for (final doc in docs)
                  Builder(builder: (_) {
                    final loan = doc.data();
                    final amount = ((loan['loanAmount'] ?? loan['amount'] ?? 0) as num).toInt();
                    final outstanding = ((loan['principalOutstanding'] ?? 0) as num).toInt();
                    final ref = loan['referenceNumber'] ?? doc.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: cardDeco(),
                      child: ListTile(
                        onTap: () => Navigator.pop(ctx, doc),
                        leading: CircleAvatar(
                          backgroundColor: TC.blue.withOpacity(0.1),
                          child: const Icon(Icons.account_balance, color: TC.blue, size: 20),
                        ),
                        title: Text('Loan $ref', style: ts(13.5, w: FontWeight.w700, c: TC.navy)),
                        subtitle: Text(
                          'Amount: ${ugx(amount)}\nOutstanding: ${ugx(outstanding)}\nStatus: ${_pretty((loan['status'] ?? '').toString())}',
                          style: ts(11.5, c: TC.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (chosen != null && mounted) _openLoan(chosen);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIXED DEPOSITS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _fixedDepositFlow() async {
    final member = await _pickMember('Create fixed deposit', Icons.account_balance_outlined, _cyan,
        'Search for the member opening the fixed deposit.');
    if (member == null || !mounted) return;

    final form = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FixedDepositForm(member: member),
    );
    if (form == null || !mounted) return;

    final res = await _withLoading<Map<String, dynamic>>(
      'Creating fixed deposit...',
      () => TellerService.createFixedDeposit(
        memberId: member['id'],
        memberName: member['name'],
        amount: (form['amount'] as num).toDouble(),
        months: form['months'] as int,
      ),
    );
    if (res == null || !mounted) return;

    if (res['success'] == true) {
      tillToast(context, 'Fixed deposit created - receipt ${res['receiptNumber'] ?? ''}');
      _refreshHistory();
    } else {
      tillToast(context, (res['message'] ?? 'Could not create fixed deposit').toString(), error: true);
    }
  }

  Future<void> _matureFlow() async {
    final member = await _pickMember('Mature fixed deposit', Icons.check_circle_outline, _lime,
        'Search for the member whose fixed deposit is maturing.');
    if (member == null || !mounted) return;

    final all = await _withLoading('Loading fixed deposits...',
        () => TellerService.getMemberFixedDeposits(member['id']));
    if (all == null || !mounted) return;

    final active = all.where((d) => (d['status'] ?? '').toString().toLowerCase() != 'matured').toList();
    if (active.isEmpty) {
      tillToast(context, 'No active fixed deposits found for ${member['name']}', warn: true);
      return;
    }

    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        title: dialogTitle(Icons.check_circle_outline, _lime, 'Select fixed deposit'),
        content: SizedBox(
          width: _dialogWidth(ctx, 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in active)
                  Builder(builder: (_) {
                    final amount = ((d['amount'] ?? 0) as num).toInt();
                    final mat = d['maturityDate'] is Timestamp
                        ? (d['maturityDate'] as Timestamp).toDate()
                        : DateTime.now();
                    final isMatured = DateTime.now().isAfter(mat);
                    final c = isMatured ? TC.green : TC.amber;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: cardDeco(),
                      child: ListTile(
                        onTap: () => Navigator.pop(ctx, d),
                        leading: CircleAvatar(
                          backgroundColor: c.withOpacity(0.1),
                          child: Icon(isMatured ? Icons.check_circle : Icons.schedule, color: c, size: 20),
                        ),
                        title: Text(ugx(amount), style: ts(14, w: FontWeight.w700, c: TC.navy)),
                        subtitle: Text('Matures ${DateFormat('MMM dd, yyyy').format(mat)}',
                            style: ts(11.5, c: TC.muted)),
                        trailing: StatusPill(isMatured ? 'Matured' : 'Early', c),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (chosen == null || !mounted) return;

    final res = await _withLoading<Map<String, dynamic>>(
      'Maturing fixed deposit...',
      () => TellerService.matureFixedDeposit(
        fixedDepositId: chosen['id'],
        tellerId: FirebaseService.sessionUid,
        tellerName: currentTellerName(),
      ),
    );
    if (res == null || !mounted) return;

    if (res['success'] == true) {
      tillToast(context, (res['message'] ?? 'Fixed deposit matured').toString());
      _refreshHistory();
    } else {
      tillToast(context, (res['message'] ?? 'Could not mature fixed deposit').toString(), error: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _historyView(double w) {
    final compact = w < 600;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snap) {
        Widget body;
        if (snap.connectionState == ConnectionState.waiting) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        } else {
          final txns = snap.data ?? [];
          if (txns.isEmpty) {
            body = Container(
              decoration: cardDeco(),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const TillStateMessage(
                icon: Icons.history,
                color: TC.muted,
                title: 'No transactions yet',
                message: 'Start processing transactions to see your history here.',
              ),
            );
          } else {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final t in txns) _historyTile(t, compact)],
            );
          }
        }

        return _page(w, [
          Row(
            children: [
              Expanded(
                child: _sectionHeader('Transaction history', 'Latest 100 transactions - teller and mobile app'),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded, color: TC.navy),
                onPressed: _refreshHistory,
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ]);
      },
    );
  }

  Widget _historyTile(Map<String, dynamic> txn, bool compact) {
    final type = (txn['type'] ?? '').toString();
    final isIn = type == 'deposit' || type == 'fixed_deposit_maturity';
    final color = isIn ? TC.green : TC.red;
    final isMobileApp = (txn['source'] ?? 'teller') == 'mobile_app';
    final method = (txn['paymentMethod'] ?? 'Cash').toString();
    final stamp = txn['timestamp'] is DateTime ? txn['timestamp'] as DateTime : null;
    final when = (stamp == null || stamp.millisecondsSinceEpoch == 0)
        ? ''
        : DateFormat('MMM d, y  •  h:mm a').format(stamp);
    final name = (txn['memberName'] ?? txn['accountName'] ?? 'Unknown').toString();
    final acct = _pretty((txn['accountType'] ?? type).toString());
    final amount = (txn['amount'] as num?) ?? 0;
    final receipt = (txn['receiptNumber'] ?? '').toString();

    Widget detail(String label, String value, IconData icon) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: TC.muted),
              const SizedBox(width: 8),
              Text('$label: ', style: ts(12, c: TC.muted)),
              Expanded(child: Text(value, style: ts(12, w: FontWeight.w600))),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 19,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(isIn ? Icons.south_west_rounded : Icons.north_east_rounded, color: color, size: 19),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, w: FontWeight.w600)),
              ),
              if (isMobileApp) ...[
                const SizedBox(width: 6),
                const StatusPill('Mobile', TC.blue),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(when.isEmpty ? acct : '$acct  •  $when',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, c: TC.muted)),
          ),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 104 : 150),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text('${isIn ? '+' : '-'} ${ugx(amount)}',
                      style: ts(13.5, w: FontWeight.w700, c: color)),
                ),
                if (receipt.isNotEmpty)
                  Text(receipt,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10, c: TC.muted)),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: TC.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  detail('Source', isMobileApp ? 'Mobile app' : 'Teller', Icons.source_outlined),
                  detail('Payment method', method, Icons.payment),
                  if (txn['telecomProvider'] != null)
                    detail('Telecom provider', txn['telecomProvider'].toString(), Icons.phone_android),
                  if (txn['phoneNumber'] != null)
                    detail('Phone number', txn['phoneNumber'].toString(), Icons.phone),
                  detail('Member phone', (txn['memberPhone'] ?? 'N/A').toString(), Icons.contact_phone_outlined),
                  if (!isMobileApp && txn['tellerName'] != null)
                    detail('Teller', txn['tellerName'].toString(), Icons.person_outline),
                  if (txn['notes'] != null && txn['notes'].toString().isNotEmpty)
                    detail('Notes', txn['notes'].toString(), Icons.note_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REQUESTS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _requestsView(double w) {
    return _page(w, [
      _sectionHeader('Requests', 'Approvals waiting for you'),
      const SizedBox(height: 16),
      Container(
        decoration: cardDeco(),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: const TillStateMessage(
          icon: Icons.inbox_outlined,
          color: TC.muted,
          title: 'No pending requests',
          message: 'Approval requests will appear here.',
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMBER SEARCH FIELD (debounced)
// ═══════════════════════════════════════════════════════════════════════════════
class _MemberSearch extends StatefulWidget {
  final void Function(Map<String, dynamic> member) onSelected;
  final String Function(Map<String, dynamic> member)? trailingBuilder;
  final bool autofocus;

  const _MemberSearch({required this.onSelected, this.trailingBuilder, this.autofocus = false});

  @override
  State<_MemberSearch> createState() => _MemberSearchState();
}

class _MemberSearchState extends State<_MemberSearch> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final r = await TellerService.searchMembers(q);
      if (!mounted || _ctrl.text.trim() != q) return;
      setState(() {
        _results = r;
        _searching = false;
        _searched = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: widget.autofocus,
          decoration: fieldDeco('Search member (name or phone)')
              .copyWith(prefixIcon: const Icon(Icons.search, size: 20)),
          onChanged: _onChanged,
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: cardDeco(),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: TC.border),
              itemBuilder: (context, i) {
                final m = _results[i];
                final name = (m['name'] ?? 'Unknown').toString();
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: TC.blue.withOpacity(0.1),
                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: ts(13, w: FontWeight.w700, c: TC.blue)),
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, w: FontWeight.w600)),
                  subtitle: Text((m['phone'] ?? '').toString(), style: ts(11.5, c: TC.muted)),
                  trailing: widget.trailingBuilder == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(widget.trailingBuilder!(m),
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ts(11, c: TC.muted)),
                        ),
                  onTap: () => widget.onSelected(m),
                );
              },
            ),
          )
        else if (_searched && !_searching)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('No members found', textAlign: TextAlign.center, style: ts(12.5, c: TC.muted)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CASH DEPOSIT / WITHDRAWAL DIALOG  (form -> confirm, all in one dialog)
// ═══════════════════════════════════════════════════════════════════════════════
class _CashTxnDialog extends StatefulWidget {
  final bool isDeposit;
  final String accountType;
  final String title;
  final int tillCash;

  const _CashTxnDialog({
    required this.isDeposit,
    required this.accountType,
    required this.title,
    required this.tillCash,
  });

  @override
  State<_CashTxnDialog> createState() => _CashTxnDialogState();
}

class _CashTxnDialogState extends State<_CashTxnDialog> {
  final _amountCtrl = TextEditingController();
  Map<String, dynamic>? _member;
  String? _error;
  bool _confirm = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Color get _color => widget.isDeposit ? TC.green : TC.red;
  String get _label => _pretty(widget.accountType);
  int get _amount => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  int _balance(Map<String, dynamic> m) {
    final v = widget.accountType == 'shares'
        ? (m['sharesBalance'] ?? m['sharesValue'] ?? 0)
        : (m['${widget.accountType}Balance'] ?? 0);
    return (v as num).toInt();
  }

  void _continue() {
    final a = _amount;
    if (a <= 0) {
      setState(() => _error = 'Enter an amount greater than zero');
      return;
    }
    if (!widget.isDeposit) {
      final bal = _balance(_member!);
      if (a > bal) {
        setState(() => _error = 'Insufficient balance. Available ${ugx(bal)}');
        return;
      }
      if (a > widget.tillCash) {
        setState(() => _error = 'Not enough cash in till. Available ${ugx(widget.tillCash)}');
        return;
      }
    }
    setState(() => _confirm = true);
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final name = (m['name'] ?? 'Unknown').toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _color.withOpacity(0.12),
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                style: ts(14, w: FontWeight.w700, c: _color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, w: FontWeight.w700, c: TC.navy)),
                Text((m['phone'] ?? '').toString(), style: ts(11.5, c: TC.muted)),
                const SizedBox(height: 2),
                Text('$_label balance: ${ugx(_balance(m))}', style: ts(11.5, w: FontWeight.w600, c: TC.text)),
              ],
            ),
          ),
          if (!_confirm)
            TextButton(
              onPressed: () => setState(() {
                _member = null;
                _amountCtrl.clear();
                _error = null;
              }),
              child: const Text('Change'),
            ),
        ],
      ),
    );
  }

  Widget _formBody() {
    if (_member == null) {
      return _MemberSearch(
        autofocus: true,
        trailingBuilder: (m) => '$_label: ${money(_balance(m))}',
        onSelected: (m) => setState(() => _member = m),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _memberCard(_member!),
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: fieldDeco('Amount', prefix: 'UGX ', error: _error),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (!widget.isDeposit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Cash available in till: ${ugx(widget.tillCash)}', style: ts(11.5, c: TC.muted)),
          ),
      ],
    );
  }

  Widget _confirmBody() {
    final m = _member!;
    final bal = _balance(m);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Please confirm this ${widget.title.toLowerCase()}.', style: ts(13, c: TC.muted)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TC.border),
          ),
          child: Column(
            children: [
              _kv('Member', (m['name'] ?? '').toString()),
              _kv('Phone', (m['phone'] ?? '').toString()),
              _kv('Account', _label),
              const Divider(height: 12),
              _kv(widget.isDeposit ? 'Deposit amount' : 'Withdrawal amount', ugx(_amount),
                  c: _color, bold: true),
              if (!widget.isDeposit) _kv('New balance', ugx(bal - _amount), c: TC.green),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      insetPadding: _dlgInset,
      title: dialogTitle(
        widget.isDeposit ? Icons.add_circle_outline : Icons.remove_circle_outline,
        _color,
        _confirm ? 'Confirm ${widget.title.toLowerCase()}' : widget.title,
      ),
      content: SizedBox(
        width: _dialogWidth(context, 460),
        child: SingleChildScrollView(child: _confirm ? _confirmBody() : _formBody()),
      ),
      actions: _confirm
          ? [
              TextButton(onPressed: () => setState(() => _confirm = false), child: const Text('Back')),
              ElevatedButton(
                style: primaryButton(_color),
                onPressed: () => Navigator.pop(context, {'member': _member, 'amount': _amount}),
                child: Text(widget.isDeposit ? 'Confirm & process' : 'Confirm & withdraw'),
              ),
            ]
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: primaryButton(_color),
                onPressed: _member == null ? null : _continue,
                child: const Text('Continue'),
              ),
            ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIXED DEPOSIT FORM
// ═══════════════════════════════════════════════════════════════════════════════
class _FixedDepositForm extends StatefulWidget {
  final Map<String, dynamic> member;
  const _FixedDepositForm({required this.member});

  @override
  State<_FixedDepositForm> createState() => _FixedDepositFormState();
}

class _FixedDepositFormState extends State<_FixedDepositForm> {
  final _amountCtrl = TextEditingController();
  final _monthsCtrl = TextEditingController(text: '12');
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _monthsCtrl.dispose();
    super.dispose();
  }

  int get _months => int.tryParse(_monthsCtrl.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final savings = ((m['savingsBalance'] ?? 0) as num).toInt();
    final maturity = DateTime.now().add(Duration(days: (_months > 0 ? _months : 12) * 30));

    return AlertDialog(
      shape: _dlgShape,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      insetPadding: _dlgInset,
      title: dialogTitle(Icons.account_balance_outlined, _cyan, 'Create fixed deposit'),
      content: SizedBox(
        width: _dialogWidth(context, 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _cyan.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cyan.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((m['name'] ?? '').toString(), style: ts(13.5, w: FontWeight.w700, c: TC.navy)),
                    Text((m['phone'] ?? '').toString(), style: ts(11.5, c: TC.muted)),
                    const SizedBox(height: 2),
                    Text('Savings balance: ${ugx(savings)}', style: ts(11.5, w: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: fieldDeco('Deposit amount', prefix: 'UGX ', error: _error,
                    helper: 'Funded from the member\'s savings'),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _monthsCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: fieldDeco('Term (months)', helper: 'Interest: 10% per annum'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Text('Maturity date: ${DateFormat('MMM dd, yyyy').format(maturity)}',
                  style: ts(12.5, w: FontWeight.w600, c: TC.muted)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: primaryButton(_cyan),
          onPressed: () {
            final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
            if (amount <= 0) {
              setState(() => _error = 'Enter an amount greater than zero');
              return;
            }
            if (amount > savings) {
              setState(() => _error = 'Exceeds savings balance (${ugx(savings)})');
              return;
            }
            if (_months <= 0) {
              setState(() => _error = 'Enter a valid term in months');
              return;
            }
            Navigator.pop(context, {'amount': amount, 'months': _months});
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
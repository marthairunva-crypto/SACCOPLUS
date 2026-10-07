import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../models/till_session.dart';
import '../../models/till_entry.dart';
import '../../services/till_service.dart';
import 'till_reports_screen.dart';
import 'till_ui.dart';

/// Till Management - open, run and close a till session.
class TillManagementScreen extends StatefulWidget {
  final bool embedded;

  const TillManagementScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<TillManagementScreen> createState() => _TillManagementScreenState();
}

class _Action {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Action(this.title, this.subtitle, this.icon, this.color, this.onTap);
}

/// Layout breakpoints (based on the width actually available to this screen,
/// so it behaves correctly inside the sidebar shell too).
class _Bp {
  static const double compact = 600; // phones
  static const double medium = 900; // small tablets / narrow windows
  static const double wide = 1100; // desktop: actions move to a side panel
  static const double maxContent = 1240;
}

class _TillManagementScreenState extends State<TillManagementScreen> {
  final _timeFmt = DateFormat('hh:mm a');
  final _dateFmt = DateFormat('EEE, d MMM yyyy');

  late Stream<TillSession?> _sessionStream;
  Stream<List<TillEntry>>? _entriesStream;
  String? _entriesSessionId;
  final Set<String> _repaired = {};
  Timer? _ticker;
  String _filter = 'all'; // all | in | out

  @override
  void initState() {
    super.initState();
    _sessionStream = TillService.watchOpenSession(FirebaseService.sessionUid);
    // keeps "running for 2h 15m" fresh
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _sessionStream = TillService.watchOpenSession(FirebaseService.sessionUid);
      _entriesSessionId = null;
    });
  }

  Stream<List<TillEntry>> _entriesFor(String sessionId) {
    if (_entriesSessionId != sessionId || _entriesStream == null) {
      _entriesSessionId = sessionId;
      _entriesStream = TillService.watchSessionEntries(sessionId);
    }
    return _entriesStream!;
  }

  /// Heals sessions whose totals were corrupted by the old double-count bug.
  void _maybeRepair(TillSession s) {
    if (_repaired.add(s.id)) {
      TillService.repairSessionTotals(s.id).catchError((e) {
        print('⚠️ Could not repair till totals: $e');
        return null;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<TillSession?>(
      stream: _sessionStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return TillStateMessage(
            icon: Icons.error_outline,
            color: TC.red,
            title: 'Could not load your till',
            message: cleanError(snap.error!),
            actionLabel: 'Retry',
            onAction: _reload,
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final session = snap.data;
        if (session == null) return _buildNoSession();
        _maybeRepair(session);
        return _buildActive(session);
      },
    );

    if (widget.embedded) {
      return Container(color: TC.bg, width: double.infinity, height: double.infinity, child: body);
    }

    return Scaffold(
      backgroundColor: TC.bg,
      appBar: AppBar(
        title: Text('Till Management', style: ts(18, w: FontWeight.w600, c: Colors.white)),
        backgroundColor: TC.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: body,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NO SESSION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNoSession() {
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFE8EEF7), shape: BoxShape.circle),
                child: Text('$n', style: ts(11, w: FontWeight.w700, c: TC.navy)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(text, style: ts(12.5, c: TC.muted)),
              )),
            ],
          ),
        );

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < _Bp.compact;
        final pad = compact ? 16.0 : 24.0;
        final minH = c.maxHeight.isFinite ? math.max(0.0, c.maxHeight - pad * 2) : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: EdgeInsets.all(compact ? 24 : 36),
                  decoration: cardDeco(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: compact ? 72 : 88,
                        height: compact ? 72 : 88,
                        decoration: BoxDecoration(color: TC.amber.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(Icons.lock_outline_rounded, size: compact ? 34 : 42, color: TC.amber),
                      ),
                      SizedBox(height: compact ? 16 : 20),
                      Text('Your till is closed',
                          textAlign: TextAlign.center,
                          style: ts(compact ? 20 : 22, w: FontWeight.w700, c: TC.navy)),
                      const SizedBox(height: 8),
                      Text(
                        'Open your till before processing cash deposits or withdrawals.',
                        textAlign: TextAlign.center,
                        style: ts(13.5, c: TC.muted),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openTill,
                          icon: const Icon(Icons.lock_open_rounded, size: 18),
                          label: const Text('Open till'),
                          style: primaryButton(TC.navy),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(height: 1, color: TC.border),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            step(1, 'Open with your starting cash (opening float).'),
                            step(2, 'Every cash deposit / withdrawal posts to your till automatically.'),
                            step(3, 'Count your cash at the end of the shift and close the till.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVE SESSION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildActive(TillSession s) {
    return StreamBuilder<List<TillEntry>>(
      stream: _entriesFor(s.id),
      builder: (context, es) {
        final entries = es.data ?? const <TillEntry>[];
        final expected = TillService.expectedCashOf(s);
        final err = es.hasError ? cleanError(es.error!) : null;

        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final compact = w < _Bp.compact;
            final wide = w >= _Bp.wide;
            final pad = compact ? 12.0 : (w < _Bp.medium ? 16.0 : 24.0);
            final gap = compact ? 12.0 : 16.0;

            final actions = _actionItems(s);

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(s, expected, compact),
                SizedBox(height: gap),
                _kpis(s, expected, w, compact, gap),
                SizedBox(height: gap),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _activity(entries, err, compact)),
                      SizedBox(width: gap),
                      SizedBox(width: 320, child: _actionsPanel(actions)),
                    ],
                  )
                else ...[
                  _actionsGrid(actions, w, compact, gap),
                  SizedBox(height: gap),
                  _activity(entries, err, compact),
                ],
              ],
            );

            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: SizedBox(width: double.infinity, child: content),
            );
          },
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _header(TillSession s, int expected, bool compact) {
    final dur = DateTime.now().difference(s.openedAt);
    final running = dur.inHours > 0 ? '${dur.inHours}h ${dur.inMinutes % 60}m' : '${dur.inMinutes}m';

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const StatusPill('OPEN', TC.green, solid: true),
            Text(_dateFmt.format(s.openedAt), style: ts(12, c: Colors.white70)),
          ],
        ),
        const SizedBox(height: 12),
        Text(s.tellerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ts(compact ? 20 : 24, w: FontWeight.w700, c: Colors.white)),
        const SizedBox(height: 3),
        Text('Opened at ${_timeFmt.format(s.openedAt)}  •  running for $running',
            style: ts(12.5, c: Colors.white70)),
      ],
    );

    final amount = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text('CASH THAT SHOULD BE IN THE TILL',
            style: ts(10.5, w: FontWeight.w600, c: Colors.white70, ls: 1)),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(ugx(expected), style: ts(compact ? 28 : 34, w: FontWeight.w800, c: Colors.white)),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TC.navy, Color(0xFF16407A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 14),
                amount,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: info),
                const SizedBox(width: 24),
                amount,
              ],
            ),
    );
  }

  // ─── KPIs ──────────────────────────────────────────────────────────────────
  Widget _kpis(TillSession s, int expected, double w, bool compact, double gap) {
    final cols = w >= _Bp.medium ? 4 : 2;
    return _equalGrid([
      _KpiCard(
        label: 'Opening float',
        value: ugx(s.openingFloat),
        sub: 'Cash you started with',
        icon: Icons.flag_outlined,
        color: TC.blue,
        compact: compact,
        onEdit: () => _editOpeningFloat(s),
      ),
      _KpiCard(
        label: 'Cash in',
        value: ugx(s.totalIn),
        sub: 'Deposits & top-ups',
        icon: Icons.south_west_rounded,
        color: TC.green,
        compact: compact,
      ),
      _KpiCard(
        label: 'Cash out',
        value: ugx(s.totalOut),
        sub: 'Withdrawals & sweeps',
        icon: Icons.north_east_rounded,
        color: TC.red,
        compact: compact,
      ),
      _KpiCard(
        label: 'Expected cash',
        value: ugx(expected),
        sub: 'Float + in - out',
        icon: Icons.account_balance_wallet_outlined,
        color: TC.navy,
        highlight: true,
        compact: compact,
      ),
    ], cols, gap);
  }

  /// Lays children out in rows of [cols] with identical widths AND heights.
  Widget _equalGrid(List<Widget> items, int cols, double gap) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final slice = items.sublist(i, math.min(i + cols, items.length));
      final cells = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        cells.add(Expanded(child: j < slice.length ? slice[j] : const SizedBox.shrink()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  List<_Action> _actionItems(TillSession s) => <_Action>[
        _Action('Cash top-up', 'Add cash from the vault', Icons.south_west_rounded, TC.green,
            () => _cashMovement(s, topUp: true)),
        _Action('Cash sweep', 'Move excess cash to the vault', Icons.north_east_rounded, TC.amber,
            () => _cashMovement(s, topUp: false)),
        _Action('Till reports', 'Sessions & variances', Icons.assessment_outlined, TC.blue, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TillReportsScreen()));
        }),
        _Action('Close till', 'Count cash & end shift', Icons.lock_outline_rounded, TC.red, () => _closeTill(s)),
      ];

  /// Used on phones / tablets / narrow windows: a grid above the activity list.
  Widget _actionsGrid(List<_Action> items, double w, bool compact, double gap) {
    final cols = w >= _Bp.medium ? 4 : 2;
    return _equalGrid(
      [for (final a in items) _actionTile(a, stacked: compact)],
      cols,
      gap,
    );
  }

  /// Used on desktop: a quick-actions panel beside the activity list.
  Widget _actionsPanel(List<_Action> items) {
    return Container(
      decoration: cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick actions', style: ts(15, w: FontWeight.w700, c: TC.navy)),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _actionTile(items[i], chevron: true),
          ],
        ],
      ),
    );
  }

  Widget _actionTile(_Action a, {bool stacked = false, bool chevron = false}) {
    final iconBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: a.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(a.icon, color: a.color, size: 22),
    );

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(a.title, style: ts(13.5, w: FontWeight.w700, c: TC.navy)),
        const SizedBox(height: 2),
        Text(a.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11.5, c: TC.muted)),
      ],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: a.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: TC.border),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconBox, const SizedBox(height: 12), texts],
                )
              : Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 12),
                    Expanded(child: texts),
                    if (chevron) Icon(Icons.chevron_right_rounded, color: TC.muted.withOpacity(0.7)),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── Activity ──────────────────────────────────────────────────────────────
  Widget _activity(List<TillEntry> all, String? error, bool compact) {
    final sorted = [...all]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final list = sorted.where((e) {
      final opening = e.entryType == TillService.openingFloatType;
      if (_filter == 'in') return !opening && e.amount > 0;
      if (_filter == 'out') return !opening && e.amount < 0;
      return true;
    }).toList();
    final txnCount = all.where((e) => e.entryType != TillService.openingFloatType).length;

    Widget chip(String key, String label) {
      final sel = _filter == key;
      return ChoiceChip(
        label: Text(label, style: ts(12, w: FontWeight.w600, c: sel ? Colors.white : TC.navy)),
        selected: sel,
        selectedColor: TC.navy,
        backgroundColor: const Color(0xFFF1F5F9),
        showCheckmark: false,
        side: BorderSide.none,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => setState(() => _filter = key),
      );
    }

    final title = Text(
      'Till activity ($txnCount transaction${txnCount == 1 ? '' : 's'})',
      style: ts(15, w: FontWeight.w700, c: TC.navy),
    );
    final chips = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [chip('all', 'All'), chip('in', 'Cash in'), chip('out', 'Cash out')],
    );

    return Container(
      decoration: cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 16, compact ? 16 : 20, 14),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), chips],
                  )
                : Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      chips,
                    ],
                  ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load transactions: $error',
                  textAlign: TextAlign.center, style: ts(12.5, c: TC.red)),
            )
          else if (list.isEmpty)
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.border))),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 38, color: TC.muted.withOpacity(0.6)),
                  const SizedBox(height: 8),
                  Text('No transactions yet', style: ts(13.5, w: FontWeight.w600, c: TC.muted)),
                  const SizedBox(height: 2),
                  Text('Cash deposits and withdrawals will appear here as they happen.',
                      textAlign: TextAlign.center, style: ts(12, c: TC.muted)),
                ],
              ),
            )
          else
            for (final e in list) _entryTile(e, compact),
        ],
      ),
    );
  }

  Widget _entryTile(TillEntry e, bool compact) {
    final m = entryMeta(e.entryType, e.amount);
    final isOpening = e.entryType == TillService.openingFloatType;
    final positive = e.amount >= 0;
    final amtColor = isOpening ? TC.blue : (positive ? TC.green : TC.red);
    final who = (e.memberName ?? '').trim();
    final sub = [if (who.isNotEmpty) who, _timeFmt.format(e.createdAt)].join('  •  ');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.border))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: m.color.withOpacity(0.1),
            child: Icon(m.icon, color: m.color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, c: TC.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isOpening ? ugx(e.amount) : '${positive ? '+' : '-'} ${ugx(e.amount.abs())}',
            style: ts(13.5, w: FontWeight.w700, c: amtColor),
          ),
          // Delete button for non-opening transactions
          if (!isOpening) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: TC.red,
              tooltip: 'Delete transaction',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: () => _confirmDeleteTransaction(e),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  static const _dlgInset = EdgeInsets.symmetric(horizontal: 16, vertical: 24);

  /// Dialog content width that never overflows small screens.
  double _dlgW(double max) => math.min(max, MediaQuery.of(context).size.width - 32 - 48);

  Future<T?> _withLoading<T>(String message, Future<T> Function() job, {String? success}) async {
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
      if (success != null && mounted) tillToast(context, success);
      return r;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) tillToast(context, cleanError(e), error: true);
      return null;
    }
  }

  ShapeBorder get _dialogShape => RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  // ═══════════════════════════════════════════════════════════════════════════
  // EDIT OPENING FLOAT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _editOpeningFloat(TillSession session) async {
    final floatCtrl = TextEditingController(text: session.openingFloat.toString());
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dialogShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(Icons.edit_outlined, TC.blue, 'Edit opening float'),
          content: SizedBox(
            width: _dlgW(420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Current opening float: ${ugx(session.openingFloat)}',
                  style: ts(13, c: TC.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: floatCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: inputDeco(
                    label: 'New opening float (UGX)',
                    hint: 'e.g. 100000',
                    prefix: const Icon(Icons.flag_outlined, size: 18),
                    error: err,
                  ),
                  onChanged: (_) => setD(() => err = null),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This will update the opening float but won\'t affect existing transactions.',
                          style: ts(12, c: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: ts(14, c: TC.muted)),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = floatCtrl.text.trim();
                if (raw.isEmpty) {
                  setD(() => err = 'Enter opening float amount');
                  return;
                }
                final amt = int.tryParse(raw);
                if (amt == null || amt < 0) {
                  setD(() => err = 'Invalid amount');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: btnStyle(TC.blue),
              child: Text('Update', style: ts(14, w: FontWeight.w600, c: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    final newFloat = int.parse(floatCtrl.text.trim());
    if (newFloat == session.openingFloat) {
      tillToast(context, 'No change made', error: false);
      return;
    }

    await _withLoading(
      'Updating opening float...',
      () => TillService.updateOpeningFloat(
        tillSessionId: session.id,
        newOpeningFloat: newFloat,
        updatedBy: FirebaseService.sessionUid,
      ),
      success: 'Opening float updated successfully',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DELETE TRANSACTION
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _confirmDeleteTransaction(TillEntry entry) async {
    final reasonCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dialogShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(Icons.delete_outline, TC.red, 'Delete transaction'),
          content: SizedBox(
            width: _dlgW(420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TC.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TC.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transaction details:', style: ts(12, w: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Type: ${entryMeta(entry.entryType, entry.amount).label}', style: ts(12)),
                      Text('Amount: ${ugx(entry.amount.abs())}', style: ts(12)),
                      if (entry.memberName != null)
                        Text('Member: ${entry.memberName}', style: ts(12)),
                      Text('Time: ${_timeFmt.format(entry.createdAt)}', style: ts(12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: inputDeco(
                    label: 'Reason for deletion (required)',
                    hint: 'e.g. Duplicate entry, wrong amount',
                    error: err,
                  ),
                  onChanged: (_) => setD(() => err = null),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The amount will be rolled back from the till totals. This action cannot be undone.',
                          style: ts(12, c: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: ts(14, c: TC.muted)),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  setD(() => err = 'Please provide a reason');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: btnStyle(TC.red),
              child: Text('Delete', style: ts(14, w: FontWeight.w600, c: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;

    await _withLoading(
      'Deleting transaction...',
      () => TillService.deleteTransaction(
        tillSessionId: entry.tillSessionId,
        entryId: entry.id,
        deletedBy: FirebaseService.sessionUid,
        reason: reasonCtrl.text.trim(),
      ),
      success: 'Transaction deleted and amount rolled back',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OPEN TILL
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _openTill() async {
    final floatCtrl = TextEditingController(text: '100000');
    final notesCtrl = TextEditingController();
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dialogShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(Icons.lock_open_rounded, TC.green, 'Open till'),
          content: SizedBox(
            width: _dlgW(420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Enter the cash you are starting your shift with.', style: ts(13, c: TC.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: floatCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDeco('Opening float', prefix: 'UGX ', error: err),
                    onChanged: (_) => setD(() => err = null),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final v in [50000, 100000, 200000, 500000])
                        ActionChip(
                          label: Text(money(v), style: ts(12, w: FontWeight.w600, c: TC.navy)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          onPressed: () => setD(() {
                            floatCtrl.text = '$v';
                            err = null;
                          }),
                        ),
                    ],
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
              style: primaryButton(TC.green),
              onPressed: () {
                if (int.tryParse(floatCtrl.text.trim()) == null) {
                  setD(() => err = 'Enter the opening float');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Open till'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final amount = int.tryParse(floatCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim();

    await _withLoading(
      'Opening till...',
      () => TillService.openSession(
        tellerId: FirebaseService.sessionUid,
        tellerName: currentTellerName(),
        openingFloat: amount,
        notes: notes.isEmpty ? null : notes,
      ),
      success: 'Till opened with ${ugx(amount)}',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP-UP / SWEEP
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _cashMovement(TillSession s, {required bool topUp}) async {
    final available = TillService.expectedCashOf(s);
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final color = topUp ? TC.green : TC.amber;
    String? err;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: _dialogShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: _dlgInset,
          title: dialogTitle(
            topUp ? Icons.south_west_rounded : Icons.north_east_rounded,
            color,
            topUp ? 'Cash top-up' : 'Cash sweep',
          ),
          content: SizedBox(
            width: _dlgW(420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      topUp
                          ? 'Cash received from the vault is added to your till.'
                          : 'Available in till: ${ugx(available)}. Cash swept out is moved to the vault.',
                      style: ts(12.5, c: TC.text),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: fieldDeco('Amount', prefix: 'UGX ', error: err),
                    onChanged: (_) => setD(() => err = null),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: notesCtrl, decoration: fieldDeco('Notes (optional)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: primaryButton(color),
              onPressed: () {
                final v = int.tryParse(amountCtrl.text.trim()) ?? 0;
                if (v <= 0) {
                  setD(() => err = 'Enter an amount greater than zero');
                  return;
                }
                if (!topUp && v > available) {
                  setD(() => err = 'Cannot sweep more than ${ugx(available)}');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(topUp ? 'Top up' : 'Sweep'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
    final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();

    await _withLoading(
      topUp ? 'Processing top-up...' : 'Processing sweep...',
      () => topUp
          ? TillService.vaultTopUp(
              tillSessionId: s.id,
              amount: amount,
              tellerId: FirebaseService.sessionUid,
              tellerName: currentTellerName(),
              notes: notes,
            )
          : TillService.vaultSweep(
              tillSessionId: s.id,
              amount: amount,
              tellerId: FirebaseService.sessionUid,
              tellerName: currentTellerName(),
              notes: notes,
            ),
      success: topUp ? 'Top-up of ${ugx(amount)} recorded' : 'Sweep of ${ugx(amount)} recorded',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOSE TILL
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _closeTill(TillSession s) async {
    // Make sure the expected figure is right before the teller counts.
    TillSession fresh = s;
    try {
      fresh = await TillService.repairSessionTotals(s.id) ?? s;
    } catch (_) {}
    if (!mounted) return;

    final expected = TillService.expectedCashOf(fresh);

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CloseTillDialog(expected: expected),
    );
    if (res == null || !mounted) return;

    final denominations = res['denominations'] as Map<String, int>;
    final reason = (res['reason'] as String).trim();

    final result = await _withLoading<CloseResult>(
      'Closing till...',
      () => TillService.closeSession(
        tillSessionId: s.id,
        tellerId: FirebaseService.sessionUid,
        denominations: denominations,
        varianceReason: reason.isEmpty ? null : reason,
      ),
    );

    if (result != null && mounted) _showCloseResult(result);
  }

  void _showCloseResult(CloseResult r) {
    final pending = r.needsApproval;
    final color = pending ? TC.amber : TC.green;

    Widget row(String label, String value, {Color c = TC.text, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: ts(13, c: TC.muted)),
              Text(value, style: ts(13.5, w: bold ? FontWeight.w700 : FontWeight.w600, c: c)),
            ],
          ),
        );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: _dialogShape,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        insetPadding: _dlgInset,
        title: dialogTitle(
          pending ? Icons.hourglass_top_rounded : Icons.check_circle_outline,
          color,
          pending ? 'Closed - awaiting approval' : 'Till closed',
        ),
        content: SizedBox(
          width: _dlgW(400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('Expected cash', ugx(r.expectedCash)),
              row('Counted cash', ugx(r.actualCash)),
              const Divider(),
              row(
                r.variance == 0 ? 'Variance' : (r.variance > 0 ? 'Over by' : 'Short by'),
                r.variance == 0 ? 'None' : ugx(r.variance.abs()),
                c: r.variance == 0 ? TC.green : (pending ? TC.red : TC.amber),
                bold: true,
              ),
              if (pending) ...[
                const SizedBox(height: 10),
                Text(
                  'The variance is above the tolerance, so a supervisor must approve this session in Till Reports.',
                  style: ts(12, c: TC.muted),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: primaryButton(TC.navy),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KPI card - horizontal on roomy layouts, stacked on phones so values never
// get squeezed.
// ═══════════════════════════════════════════════════════════════════════════════
class _KpiCard extends StatelessWidget {
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  final bool highlight;
  final bool compact;
  final VoidCallback? onEdit;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.highlight = false,
    this.compact = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : TC.navy;
    final muted = highlight ? Colors.white70 : TC.muted;

    final iconBox = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? Colors.white.withOpacity(0.14) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: highlight ? Colors.white : color, size: 22),
    );

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: ts(11.5, w: FontWeight.w500, c: muted)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: ts(compact ? 16 : 18, w: FontWeight.w700, c: fg)),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11, c: muted)),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: cardDeco(color: highlight ? TC.navy : Colors.white, border: highlight ? TC.navy : null),
      child: Stack(
        children: [
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconBox, const SizedBox(height: 12), texts],
                )
              : Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 14),
                    Expanded(child: texts),
                  ],
                ),
          if (onEdit != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: highlight ? Colors.white70 : TC.muted),
                tooltip: 'Edit',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLOSE TILL DIALOG - fixed header + footer, scrollable count table in between
// ═══════════════════════════════════════════════════════════════════════════════
class _CloseTillDialog extends StatefulWidget {
  final int expected;
  const _CloseTillDialog({required this.expected});

  static const denoms = [50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100, 50];

  @override
  State<_CloseTillDialog> createState() => _CloseTillDialogState();
}

class _CloseTillDialogState extends State<_CloseTillDialog> {
  late final Map<int, TextEditingController> _ctrls = {
    for (final d in _CloseTillDialog.denoms) d: TextEditingController(),
  };
  final _reasonCtrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _reasonCtrl.dispose();
    super.dispose();
  }

  int _qty(int d) => int.tryParse(_ctrls[d]!.text) ?? 0;
  int get _counted => _CloseTillDialog.denoms.fold(0, (sum, d) => sum + d * _qty(d));
  int get _pieces => _CloseTillDialog.denoms.fold(0, (sum, d) => sum + _qty(d));

  void _clearAll() {
    for (final c in _ctrls.values) {
      c.clear();
    }
    setState(() => _err = null);
  }

  void _submit(bool needsReason) {
    if (needsReason && _reasonCtrl.text.trim().isEmpty) {
      setState(() => _err = 'Explain the variance to close the till');
      return;
    }
    Navigator.pop(context, {
      'denominations': <String, int>{
        for (final d in _CloseTillDialog.denoms) '$d': _qty(d),
      },
      'reason': _reasonCtrl.text,
    });
  }

  // ─── Pieces ────────────────────────────────────────────────────────────────
  Widget _summary(int counted, int variance, bool needsReason) {
    final vColor = variance == 0 ? TC.green : (needsReason ? TC.red : TC.amber);
    final vLabel = variance == 0
        ? 'Balanced'
        : (variance > 0 ? 'Over by ${ugx(variance)}' : 'Short by ${ugx(-variance)}');
    final vIcon = variance == 0
        ? Icons.check_circle_rounded
        : (needsReason ? Icons.error_rounded : Icons.info_rounded);

    Widget cell(String label, String value, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ts(10.5, w: FontWeight.w600, c: TC.muted, ls: 0.6)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: ts(17, w: FontWeight.w700, c: c)),
              ),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                cell('EXPECTED', ugx(widget.expected), TC.navy),
                Container(width: 1, height: 34, color: TC.border),
                const SizedBox(width: 16),
                cell('COUNTED', ugx(counted), TC.blue),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: vColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
            ),
            child: Row(
              children: [
                Icon(vIcon, size: 18, color: vColor),
                const SizedBox(width: 8),
                Expanded(child: Text(vLabel, style: ts(13, w: FontWeight.w700, c: vColor))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(double qtyW, double amtW) {
    Widget head(String t, {double? width, TextAlign align = TextAlign.left}) {
      final txt = Text(t, textAlign: align, style: ts(10.5, w: FontWeight.w600, c: TC.muted, ls: 0.6));
      return width == null ? Expanded(child: txt) : SizedBox(width: width, child: txt);
    }

    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c, width: w),
        );

    Widget row(int d, int index) {
      final q = _qty(d);
      final isNote = d >= 1000;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: q > 0 ? TC.blue.withOpacity(0.04) : Colors.white,
          border: const Border(top: BorderSide(color: TC.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: (isNote ? TC.green : TC.amber).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isNote ? Icons.payments_outlined : Icons.toll_outlined,
                        size: 16, color: isNote ? TC.green : TC.amber),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('UGX ${money(d)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w600)),
                        Text(isNote ? 'Note' : 'Coin', style: ts(10.5, c: TC.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: qtyW,
              height: 38,
              child: TextField(
                controller: _ctrls[d],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: ts(13.5, w: FontWeight.w700, c: TC.navy),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: '0',
                  hintStyle: ts(13.5, c: TC.muted.withOpacity(0.6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  enabledBorder: b(q > 0 ? TC.blue.withOpacity(0.5) : const Color(0xFFD5DCE6)),
                  focusedBorder: b(TC.blue, 1.6),
                  border: b(const Color(0xFFD5DCE6)),
                ),
                onChanged: (_) => setState(() => _err = null),
              ),
            ),
            SizedBox(
              width: amtW,
              child: Text(
                q > 0 ? money(d * q) : '-',
                textAlign: TextAlign.right,
                style: ts(13, w: FontWeight.w600, c: q > 0 ? TC.navy : TC.muted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                head('DENOMINATION'),
                head('QTY', width: qtyW, align: TextAlign.center),
                head('AMOUNT (UGX)', width: amtW, align: TextAlign.right),
              ],
            ),
          ),
          for (var i = 0; i < _CloseTillDialog.denoms.length; i++) row(_CloseTillDialog.denoms[i], i),
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text('Total counted', style: ts(13, w: FontWeight.w700, c: TC.navy))),
                SizedBox(
                  width: qtyW,
                  child: Text('$_pieces', textAlign: TextAlign.center, style: ts(13, w: FontWeight.w700, c: TC.navy)),
                ),
                SizedBox(
                  width: amtW,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(money(_counted), style: ts(14, w: FontWeight.w800, c: TC.navy)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogW = math.min(560.0, size.width - 32);
    final narrow = dialogW < 420;
    final qtyW = narrow ? 72.0 : 92.0;
    final amtW = narrow ? 88.0 : 112.0;

    final counted = _counted;
    final variance = counted - widget.expected;
    final needsReason = variance.abs() > TillService.varianceTolerance;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: size.height - 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 14),
              child: Row(
                children: [
                  Expanded(child: dialogTitle(Icons.lock_outline_rounded, TC.red, 'Close till')),
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close_rounded, color: TC.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: TC.border),

            // ── Body (scrolls) ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Count the cash in your till and enter how many of each note and coin you have.',
                        style: ts(12.5, c: TC.muted)),
                    const SizedBox(height: 14),
                    _summary(counted, variance, needsReason),
                    const SizedBox(height: 18),
                    _table(qtyW, amtW),
                    if (variance != 0) ...[
                      const SizedBox(height: 18),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 2,
                        decoration: fieldDeco(
                          needsReason ? 'Variance reason (required)' : 'Variance reason (optional)',
                          error: _err,
                        ),
                        onChanged: (_) => setState(() => _err = null),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (needsReason ? TC.amber : TC.blue).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: needsReason ? TC.amber : TC.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A variance above ${ugx(TillService.varianceTolerance)} needs a reason and supervisor approval.',
                              style: ts(11.5, c: TC.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer ──
            const Divider(height: 1, color: TC.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: counted == 0 ? null : _clearAll,
                    child: const Text('Clear all'),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: primaryButton(TC.red),
                    onPressed: () => _submit(needsReason),
                    child: const Text('Close till'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/sacco_service.dart';
import '../../models/till_session.dart';
import '../../models/till_entry.dart';
import '../../services/till_service.dart';
import 'till_ui.dart';

/// Till Reports - review sessions, cash counts and variances.
///
/// NOTE: the Firestore query only filters on `tenantId` (an automatic
/// single-field index). Date range, status and teller are filtered in memory,
/// so this screen never needs a composite index.
class TillReportsScreen extends StatefulWidget {
  final bool embedded;

  const TillReportsScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<TillReportsScreen> createState() => _TillReportsScreenState();
}

/// A session plus the raw tellerId from its document.
class _Rec {
  final TillSession s;
  final String tellerId;
  _Rec(this.s, this.tellerId);

  String get tellerKey => tellerId.isNotEmpty ? tellerId : s.tellerName;
}

class _TillReportsScreenState extends State<TillReportsScreen> {
  static const _pageSize = 25;
  static const _tableBreakpoint = 1000.0;

  final _dateFmt = DateFormat('MMM dd, yyyy');
  final _timeFmt = DateFormat('hh:mm a');

  late Stream<QuerySnapshot> _stream;
  late DateTime _start;
  late DateTime _end;
  String _status = 'all'; // all | open | closed | pending_approval
  String? _teller; // tellerKey
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day);
    _start = _end.subtract(const Duration(days: 7));
    _stream = _open();
  }

  Stream<QuerySnapshot> _open() => FirebaseFirestore.instance
      .collection(AppConstants.tillSessionsCol)
      .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
      .snapshots();

  void _apply(VoidCallback f) => setState(() {
        f();
        _visible = _pageSize;
      });

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return TillStateMessage(
            icon: Icons.error_outline,
            color: TC.red,
            title: 'Could not load till reports',
            message: cleanError(snap.error!),
            actionLabel: 'Retry',
            onAction: () => setState(() => _stream = _open()),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final all = snap.data!.docs.map((d) {
          final data = (d.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};
          return _Rec(TillSession.fromFirestore(d), (data['tellerId'] ?? '').toString());
        }).toList()
          ..sort((a, b) => b.s.openedAt.compareTo(a.s.openedAt));

        return LayoutBuilder(builder: (context, c) => _content(all, c.maxWidth));
      },
    );

    if (widget.embedded) {
      return Container(color: TC.bg, width: double.infinity, height: double.infinity, child: body);
    }

    return Scaffold(
      backgroundColor: TC.bg,
      appBar: AppBar(
        title: Text('Till Reports', style: ts(18, w: FontWeight.w600, c: Colors.white)),
        backgroundColor: TC.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: body,
    );
  }

  Widget _content(List<_Rec> all, double w) {
    final compact = w < 600;
    final pad = compact ? 12.0 : (w < 900 ? 16.0 : 24.0);
    final gap = compact ? 12.0 : 16.0;

    // Teller options come from the sessions themselves.
    final tellers = <String, String>{};
    for (final r in all) {
      tellers.putIfAbsent(r.tellerKey, () => r.s.tellerName);
    }

    // In-memory filters (no Firestore index needed).
    final from = DateTime(_start.year, _start.month, _start.day);
    final to = DateTime(_end.year, _end.month, _end.day + 1);
    final inScope = all.where((r) {
      final t = r.s.openedAt;
      if (t.isBefore(from) || !t.isBefore(to)) return false;
      if (_teller != null && r.tellerKey != _teller) return false;
      return true;
    }).toList();

    final counts = <String, int>{
      'all': inScope.length,
      'open': inScope.where((r) => r.s.status == 'open').length,
      'closed': inScope.where((r) => r.s.status == 'closed').length,
      'pending_approval': inScope.where((r) => r.s.status == 'pending_approval').length,
    };

    final sessions =
        _status == 'all' ? inScope : inScope.where((r) => r.s.status == _status).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Till reports', style: ts(20, w: FontWeight.w700, c: TC.navy)),
                      const SizedBox(height: 2),
                      Text('Review sessions, cash counts and variances.', style: ts(12.5, c: TC.muted)),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _exportToPDF(sessions),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Export PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TC.blue,
                      side: BorderSide(color: TC.blue.withOpacity(0.3)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _printReport(sessions),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TC.navy,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            if (compact) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportToPDF(sessions),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Export PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TC.blue,
                        side: BorderSide(color: TC.blue.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _printReport(sessions),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TC.navy,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: gap),
            _filters(w, tellers, counts),
            SizedBox(height: gap),
            _kpis(sessions),
            SizedBox(height: gap),
            _sessionList(sessions, w),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _filters(double w, Map<String, String> tellers, Map<String, int> counts) {
    final compact = w < 600;

    Widget dateField(String label, DateTime d, void Function(DateTime) onPick) => InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: d,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (p != null) onPick(DateTime(p.year, p.month, p.day));
          },
          child: InputDecorator(
            decoration: fieldDeco(label,
                suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: TC.muted)),
            child: Text(_dateFmt.format(d), style: ts(13.5)),
          ),
        );

    final startField = dateField('Start date', _start, (p) => _apply(() {
          _start = p;
          if (_end.isBefore(_start)) _end = _start;
        }));
    final endField = dateField('End date', _end, (p) => _apply(() {
          _end = p;
          if (_start.isAfter(_end)) _start = _end;
        }));

    final tellerField = DropdownButtonFormField<String?>(
      value: tellers.containsKey(_teller) ? _teller : null,
      isExpanded: true,
      decoration: fieldDeco('Teller'),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('All tellers', style: ts(13.5))),
        for (final e in tellers.entries)
          DropdownMenuItem<String?>(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis, style: ts(13.5)),
          ),
      ],
      onChanged: (v) => _apply(() => _teller = v),
    );

    Widget statusChip(String key, String label) {
      final sel = _status == key;
      return ChoiceChip(
        label: Text('$label (${counts[key] ?? 0})',
            style: ts(12, w: FontWeight.w600, c: sel ? Colors.white : TC.navy)),
        selected: sel,
        selectedColor: TC.navy,
        backgroundColor: const Color(0xFFF1F5F9),
        showCheckmark: false,
        side: BorderSide.none,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) => _apply(() => _status = key),
      );
    }

    Widget preset(String label, DateTime start) => ActionChip(
          label: Text(label, style: ts(12, w: FontWeight.w600, c: TC.blue)),
          backgroundColor: TC.blue.withOpacity(0.08),
          side: BorderSide.none,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => _apply(() {
            final now = DateTime.now();
            _end = DateTime(now.year, now.month, now.day);
            _start = start;
          }),
        );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final statusWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        statusChip('all', 'All'),
        statusChip('open', 'Open'),
        statusChip('closed', 'Closed'),
        statusChip('pending_approval', 'Pending approval'),
      ],
    );
    final presetWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        preset('Today', today),
        preset('Last 7 days', today.subtract(const Duration(days: 6))),
        preset('Last 30 days', today.subtract(const Duration(days: 29))),
        preset('This month', DateTime(now.year, now.month, 1)),
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            startField,
            const SizedBox(height: 12),
            endField,
            const SizedBox(height: 12),
            tellerField,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: startField),
                const SizedBox(width: 12),
                Expanded(child: endField),
                const SizedBox(width: 12),
                Expanded(child: tellerField),
              ],
            ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: TC.border),
          const SizedBox(height: 14),
          if (w >= 1000)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statusWrap),
                const SizedBox(width: 16),
                presetWrap,
              ],
            )
          else ...[
            statusWrap,
            const SizedBox(height: 10),
            presetWrap,
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KPIs
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _kpis(List<_Rec> sessions) {
    final open = sessions.where((r) => r.s.status == 'open').length;
    final closed = sessions.where((r) => r.s.status == 'closed').length;
    final pending = sessions.where((r) => r.s.status == 'pending_approval').length;

    final counted = sessions.where((r) => r.s.actualCash != null);
    final totalCash = counted.fold<int>(0, (sum, r) => sum + (r.s.actualCash ?? 0));
    final totalVariance = counted.fold<int>(0, (sum, r) => sum + (r.s.variance ?? 0));

    final vColor = totalVariance == 0 ? TC.green : (totalVariance < 0 ? TC.red : TC.amber);

    return TillKpiGrid(children: [
      TillKpi(
        label: 'Sessions',
        value: '${sessions.length}',
        sub: '$open open  •  $closed closed  •  $pending pending',
        icon: Icons.receipt_long_outlined,
        color: TC.blue,
      ),
      TillKpi(
        label: 'Cash counted',
        value: ugx(totalCash),
        sub: 'Across counted sessions',
        icon: Icons.payments_outlined,
        color: TC.teal,
      ),
      TillKpi(
        label: 'Net variance',
        value: totalVariance == 0 ? 'UGX 0' : '${totalVariance > 0 ? '+' : '-'} ${ugx(totalVariance.abs())}',
        sub: totalVariance == 0 ? 'All balanced' : (totalVariance > 0 ? 'Overall over' : 'Overall short'),
        icon: Icons.balance_outlined,
        color: vColor,
      ),
      TillKpi(
        label: 'Awaiting approval',
        value: '$pending',
        sub: pending == 0 ? 'Nothing to review' : 'Supervisor action needed',
        icon: Icons.hourglass_top_rounded,
        color: pending == 0 ? TC.muted : TC.amber,
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION LIST
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _sessionList(List<_Rec> sessions, double w) {
    if (sessions.isEmpty) {
      return Container(
        decoration: cardDeco(),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: const TillStateMessage(
          icon: Icons.receipt_long_outlined,
          color: TC.muted,
          title: 'No till sessions found',
          message: 'Try a wider date range or clear the status and teller filters.',
        ),
      );
    }

    final shown = sessions.take(_visible).toList();
    final remaining = sessions.length - shown.length;
    final table = w >= _tableBreakpoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (table)
          _table(shown)
        else
          for (final r in shown) _sessionCard(r),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _visible += _pageSize),
                icon: const Icon(Icons.expand_more_rounded),
                label: Text('Show ${math.min(_pageSize, remaining)} more  ($remaining remaining)'),
              ),
            ),
          ),
      ],
    );
  }

  Color _varColor(int v) =>
      v == 0 ? TC.green : (v.abs() > TillService.varianceTolerance ? TC.red : TC.amber);

  String _varText(int v) => v == 0 ? '0' : '${v > 0 ? '+' : '-'}${money(v.abs())}';

  Widget _avatar(String name, {double r = 14}) => CircleAvatar(
        radius: r,
        backgroundColor: TC.blue.withOpacity(0.1),
        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
            style: ts(r - 2, w: FontWeight.w700, c: TC.blue)),
      );

  // ─── Desktop table ─────────────────────────────────────────────────────────
  Widget _table(List<_Rec> rows) {
    Widget head(String t, int flex, {bool right = false}) => Expanded(
          flex: flex,
          child: Padding(
            padding: EdgeInsets.only(left: right ? 8 : 0),
            child: Text(t,
                textAlign: right ? TextAlign.right : TextAlign.left,
                style: ts(10.5, w: FontWeight.w600, c: TC.muted, ls: 0.6)),
          ),
        );

    return Container(
      decoration: cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                head('OPENED', 3),
                head('TELLER', 3),
                head('STATUS', 2),
                head('OPENING', 2, right: true),
                head('CASH IN', 2, right: true),
                head('CASH OUT', 2, right: true),
                head('EXPECTED', 2, right: true),
                head('COUNTED', 2, right: true),
                head('VARIANCE', 2, right: true),
                const SizedBox(width: 28),
              ],
            ),
          ),
          for (final r in rows) _tableRow(r),
        ],
      ),
    );
  }

  Widget _tableRow(_Rec r) {
    final s = r.s;

    Widget num(int? v, {Color c = TC.text, bool bold = false, String Function(int)? fmt}) => Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              v == null ? '-' : (fmt ?? money)(v),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(12.5, w: bold ? FontWeight.w700 : FontWeight.w500, c: v == null ? TC.muted : c),
            ),
          ),
        );

    return InkWell(
      onTap: () => _openDetails(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.border))),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_dateFmt.format(s.openedAt), style: ts(13, w: FontWeight.w600)),
                  Text(_timeFmt.format(s.openedAt), style: ts(11.5, c: TC.muted)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _avatar(s.tellerName),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(s.tellerName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(statusLabel(s.status), statusColor(s.status)),
              ),
            ),
            num(s.openingFloat),
            num(s.totalIn, c: TC.green),
            num(s.totalOut, c: TC.red),
            num(s.expectedCash, c: TC.navy, bold: true),
            num(s.actualCash, c: TC.teal, bold: true),
            num(s.variance, c: _varColor(s.variance ?? 0), bold: true, fmt: _varText),
            const SizedBox(width: 28, child: Icon(Icons.chevron_right_rounded, color: TC.muted)),
          ],
        ),
      ),
    );
  }

  // ─── Phone / tablet cards ──────────────────────────────────────────────────
  Widget _sessionCard(_Rec r) {
    final s = r.s;

    Widget mini(String label, String value, Color c) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ts(10.5, w: FontWeight.w500, c: TC.muted)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: ts(13, w: FontWeight.w700, c: c)),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDetails(r),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(statusLabel(s.status), statusColor(s.status)),
                    const Spacer(),
                    Text('${_dateFmt.format(s.openedAt)}  •  ${_timeFmt.format(s.openedAt)}',
                        style: ts(11.5, c: TC.muted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _avatar(s.tellerName, r: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.tellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(14, w: FontWeight.w700, c: TC.navy)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: TC.muted),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TC.border),
                  ),
                  child: Column(
                    children: [
                      Row(children: [
                        mini('Opening float', ugx(s.openingFloat), TC.text),
                        mini('Expected cash', ugx(s.expectedCash), TC.navy),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        mini('Cash in', ugx(s.totalIn), TC.green),
                        mini('Cash out', ugx(s.totalOut), TC.red),
                      ]),
                      if (s.actualCash != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: TC.border),
                        ),
                        Row(children: [
                          mini('Counted', ugx(s.actualCash!), TC.teal),
                          mini(
                            'Variance',
                            (s.variance ?? 0) == 0 ? 'Balanced' : '${_varText(s.variance ?? 0)}',
                            _varColor(s.variance ?? 0),
                          ),
                        ]),
                      ],
                    ],
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
  // DETAILS (dialog on desktop, bottom sheet on phones)
  // ═══════════════════════════════════════════════════════════════════════════
  void _openDetails(_Rec r) {
    final size = MediaQuery.of(context).size;
    final details = _SessionDetails(session: r.s, dateFmt: _dateFmt, timeFmt: _timeFmt);

    if (size.width < 700) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SizedBox(
          height: size.height * 0.9,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Material(color: Colors.white, child: details),
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 680, maxHeight: size.height - 48),
            child: details,
          ),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF EXPORT & PRINT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _exportToPDF(List<_Rec> sessions) async {
    try {
      final pdf = await _generatePDF(sessions);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Till_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );
      if (mounted) {
        tillToast(context, 'PDF exported successfully');
      }
    } catch (e) {
      if (mounted) {
        tillToast(context, 'Failed to export PDF: ${cleanError(e)}', error: true);
      }
    }
  }

  Future<void> _printReport(List<_Rec> sessions) async {
    try {
      final pdf = await _generatePDF(sessions);
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Till_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        tillToast(context, 'Failed to print: ${cleanError(e)}', error: true);
      }
    }
  }

  Future<pw.Document> _generatePDF(List<_Rec> sessions) async {
    final pdf = pw.Document();
    
    // Calculate summary stats
    final open = sessions.where((r) => r.s.status == 'open').length;
    final closed = sessions.where((r) => r.s.status == 'closed').length;
    final pending = sessions.where((r) => r.s.status == 'pending_approval').length;
    final counted = sessions.where((r) => r.s.actualCash != null);
    final totalCash = counted.fold<int>(0, (sum, r) => sum + (r.s.actualCash ?? 0));
    final totalVariance = counted.fold<int>(0, (sum, r) => sum + (r.s.variance ?? 0));

    final saccoName = SaccoService.current.saccoName;
    final reportDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final dateRange = '${_dateFmt.format(_start)} - ${_dateFmt.format(_end)}';
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  saccoName,
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Till Sessions Report', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Period: $dateRange', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Generated: $reportDate', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SUMMARY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfStat('Total Sessions', '${sessions.length}'),
                    _pdfStat('Open', '$open'),
                    _pdfStat('Closed', '$closed'),
                    _pdfStat('Pending', '$pending'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _pdfStat('Cash Counted', ugx(totalCash)),
                    _pdfStat('Net Variance', totalVariance == 0 ? 'Balanced' : '${totalVariance > 0 ? '+' : ''}${ugx(totalVariance)}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),

          // Filters applied
          if (_status != 'all' || _teller != null) ...[
            pw.Text('FILTERS APPLIED:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            if (_status != 'all')
              pw.Text('• Status: ${statusLabel(_status)}', style: const pw.TextStyle(fontSize: 9)),
            if (_teller != null)
              pw.Text('• Teller: ${sessions.firstWhere((r) => r.tellerKey == _teller, orElse: () => sessions.first).s.tellerName}',
                  style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 15),
          ],

          // Sessions table
          pw.Text('SESSIONS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if (sessions.isEmpty)
            pw.Text('No till sessions found for the selected period and filters.', style: const pw.TextStyle(fontSize: 10))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.3),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1.3),
                6: const pw.FlexColumnWidth(1.3),
                7: const pw.FlexColumnWidth(1.3),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfTableHeader('Date & Time'),
                    _pdfTableHeader('Teller'),
                    _pdfTableHeader('Status'),
                    _pdfTableHeader('Opening'),
                    _pdfTableHeader('Cash In'),
                    _pdfTableHeader('Cash Out'),
                    _pdfTableHeader('Expected'),
                    _pdfTableHeader('Variance'),
                  ],
                ),
                // Data rows
                for (final r in sessions)
                  pw.TableRow(
                    children: [
                      _pdfTableCell('${_dateFmt.format(r.s.openedAt)}\n${_timeFmt.format(r.s.openedAt)}'),
                      _pdfTableCell(r.s.tellerName),
                      _pdfTableCell(statusLabel(r.s.status)),
                      _pdfTableCell(ugx(r.s.openingFloat), align: pw.TextAlign.right),
                      _pdfTableCell(ugx(r.s.totalIn), align: pw.TextAlign.right),
                      _pdfTableCell(ugx(r.s.totalOut), align: pw.TextAlign.right),
                      _pdfTableCell(ugx(r.s.expectedCash), align: pw.TextAlign.right),
                      _pdfTableCell(
                        r.s.variance == null ? '-' : (r.s.variance == 0 ? '0' : '${r.s.variance! > 0 ? '+' : ''}${ugx(r.s.variance!)}'),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
              ],
            ),

          pw.SizedBox(height: 30),

          // Footer
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Printed by: ${FirebaseService.sessionUsername}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Page ', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _pdfStat(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      );

  pw.Widget _pdfTableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget _pdfTableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9), textAlign: align),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SESSION DETAILS CONTENT
// ═══════════════════════════════════════════════════════════════════════════════
class _SessionDetails extends StatefulWidget {
  final TillSession session;
  final DateFormat dateFmt;
  final DateFormat timeFmt;

  const _SessionDetails({required this.session, required this.dateFmt, required this.timeFmt});

  @override
  State<_SessionDetails> createState() => _SessionDetailsState();
}

class _SessionDetailsState extends State<_SessionDetails> {
  late Future<List<TillEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = TillService.getSessionEntries(widget.session.id);
  }

  Widget _kv(String label, String value, {Color c = TC.text, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: ts(12.5, c: TC.muted)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: ts(13, w: bold ? FontWeight.w700 : FontWeight.w600, c: c)),
            ),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(), style: ts(10.5, w: FontWeight.w700, c: TC.muted, ls: 0.8)),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );

  Widget _entryTile(TillEntry e) {
    final m = entryMeta(e.entryType, e.amount);
    final isOpening = e.entryType == TillService.openingFloatType;
    final positive = e.amount >= 0;
    final c = isOpening ? TC.blue : (positive ? TC.green : TC.red);
    final who = (e.memberName ?? '').trim();
    final sub = [if (who.isNotEmpty) who, widget.timeFmt.format(e.createdAt)].join('  •  ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.border))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: m.color.withOpacity(0.1),
            child: Icon(m.icon, color: m.color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w600)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, c: TC.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isOpening ? ugx(e.amount) : '${positive ? '+' : '-'} ${ugx(e.amount.abs())}',
            style: ts(13, w: FontWeight.w700, c: c),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final variance = s.variance;
    final vColor = variance == null
        ? TC.muted
        : (variance == 0
            ? TC.green
            : (variance.abs() > TillService.varianceTolerance ? TC.red : TC.amber));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [TC.navy, Color(0xFF16407A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(statusLabel(s.status), statusColor(s.status), solid: true),
                        Text(widget.dateFmt.format(s.openedAt), style: ts(12, c: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(s.tellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(20, w: FontWeight.w700, c: Colors.white)),
                    Text('Till session', style: ts(12.5, c: Colors.white70)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // ── Body ──
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('Session', [
                  _kv('Business date', s.businessDate.toString().isEmpty ? '-' : s.businessDate.toString()),
                  _kv('Opened', '${widget.dateFmt.format(s.openedAt)}, ${widget.timeFmt.format(s.openedAt)}'),
                  if (s.closedAt != null)
                    _kv('Closed', '${widget.dateFmt.format(s.closedAt!)}, ${widget.timeFmt.format(s.closedAt!)}'),
                ]),
                const SizedBox(height: 14),
                _section('Cash summary', [
                  _kv('Opening float', ugx(s.openingFloat)),
                  _kv('Total in', ugx(s.totalIn), c: TC.green),
                  _kv('Total out', ugx(s.totalOut), c: TC.red),
                  _kv('Expected cash', ugx(s.expectedCash), c: TC.navy, bold: true),
                  if (s.actualCash != null) ...[
                    const Divider(height: 14, color: TC.border),
                    _kv('Counted cash', ugx(s.actualCash!), c: TC.teal, bold: true),
                    _kv(
                      variance == null || variance == 0
                          ? 'Variance'
                          : (variance > 0 ? 'Over by' : 'Short by'),
                      variance == null || variance == 0 ? 'Balanced' : ugx(variance.abs()),
                      c: vColor,
                      bold: true,
                    ),
                  ],
                ]),
                const SizedBox(height: 20),
                FutureBuilder<List<TillEntry>>(
                  future: _entries,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      );
                    }
                    if (snap.hasError) {
                      return Text('Could not load transactions: ${cleanError(snap.error!)}',
                          style: ts(12.5, c: TC.red));
                    }
                    final list = [...(snap.data ?? const <TillEntry>[])]
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    final txnCount = list.where((e) => e.entryType != TillService.openingFloatType).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Transactions ($txnCount)', style: ts(15, w: FontWeight.w700, c: TC.navy)),
                        const SizedBox(height: 8),
                        if (list.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text('No transactions in this session.',
                                textAlign: TextAlign.center, style: ts(12.5, c: TC.muted)),
                          )
                        else
                          for (final e in list) _entryTile(e),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
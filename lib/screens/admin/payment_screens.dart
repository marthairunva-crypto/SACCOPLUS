import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';

/// Palette matched to the Cash & Bank screen.
class _MM {
  static const bg = Color(0xFFF5F7FA);
  static const navy = Color(0xFF16345A);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const line = Color(0xFFE5E7EB);
  static const headerBg = Color(0xFFFAFAFB);

  static const green = Color(0xFF2F8F6B);
  static const greenBg = Color(0xFFE6F4EE);
  static const amber = Color(0xFFB7791F);
  static const amberBg = Color(0xFFFDF3E0);
  static const red = Color(0xFFC0392B);
  static const redBg = Color(0xFFFCE8E6);
}

enum _Filter { all, pending, completed, rejected }

const _filterLabels = {
  _Filter.all: 'All',
  _Filter.pending: 'Pending',
  _Filter.completed: 'Completed',
  _Filter.rejected: 'Rejected',
};

class _Txn {
  final String id;
  final Map<String, dynamic> data;
  _Txn(this.id, this.data);

  /// Normalised to: pending | completed | rejected
  String get status {
    final s = (data['status'] as String?)?.toLowerCase() ?? 'pending';
    if (s == 'approved' || s == 'completed') return 'completed';
    if (s == 'rejected') return 'rejected';
    return 'pending';
  }

  double get amount => (data['amount'] as num?)?.toDouble() ?? 0;
  String get member =>
      (data['memberName'] ?? data['clientName'] ?? 'Unknown member').toString();
  String get provider => (data['provider'] ?? 'Mobile money').toString();
  String get phone => (data['phoneNumber'] ?? '—').toString();
  String? get reference => data['reference']?.toString();
  String? get description => data['description']?.toString();
  DateTime? get createdAt {
    final t = data['createdAt'];
    return t is Timestamp ? t.toDate() : null;
  }
}

// Mobile Money Screen
class MobileMoneyScreen extends StatefulWidget {
  const MobileMoneyScreen({super.key});

  @override
  State<MobileMoneyScreen> createState() => _MobileMoneyScreenState();
}

class _MobileMoneyScreenState extends State<MobileMoneyScreen> {
  final _money = NumberFormat('#,###', 'en_US');
  final _searchCtrl = TextEditingController();
  _Filter _filter = _Filter.pending;
  String _query = '';

  // One simple stream (tenant only). Filtering and sorting happen in memory,
  // so no composite Firestore index is needed.
  late final Stream<QuerySnapshot> _stream = FirebaseFirestore.instance
      .collection('mobileMoneyTransactions')
      .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
      .snapshots();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MM.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            debugPrint('Mobile money stream error: ${snap.error}');
            return _errorView(snap.error.toString());
          }

          final loading = !snap.hasData;
          final all = (snap.data?.docs ?? const <QueryDocumentSnapshot>[])
              .map((d) => _Txn(d.id, d.data() as Map<String, dynamic>))
              .toList()
            ..sort((a, b) {
              final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            });

          final shown = all.where((t) {
            if (_filter != _Filter.all && t.status != _filter.name) return false;
            if (_query.isEmpty) return true;
            final hay =
                '${t.member} ${t.phone} ${t.provider} ${t.reference ?? ''}'
                    .toLowerCase();
            return hay.contains(_query);
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 20),
                _stats(all),
                const SizedBox(height: 16),
                _tableCard(all, shown, loading),
              ],
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── header ─────────────────────────

  Widget _header() {
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mobile Money',
            style: GoogleFonts.inter(
                fontSize: 24, fontWeight: FontWeight.w700, color: _MM.ink)),
        const SizedBox(height: 4),
        Text('Member mobile money deposits awaiting approval  ·  $today',
            style: GoogleFonts.inter(fontSize: 13, color: _MM.muted)),
      ],
    );
  }

  // ───────────────────────── stat cards ─────────────────────────

  Widget _stats(List<_Txn> all) {
    double pendingAmt = 0, doneAmt = 0, rejAmt = 0;
    int pendingN = 0, doneN = 0, rejN = 0;
    for (final t in all) {
      switch (t.status) {
        case 'pending':
          pendingAmt += t.amount;
          pendingN++;
          break;
        case 'completed':
          doneAmt += t.amount;
          doneN++;
          break;
        case 'rejected':
          rejAmt += t.amount;
          rejN++;
          break;
      }
    }

    String n(int c) => '$c transaction${c == 1 ? '' : 's'}';
    final cards = [
      _statCard('PENDING APPROVAL', 'UGX ${_money.format(pendingAmt)}', n(pendingN)),
      _statCard('COMPLETED', 'UGX ${_money.format(doneAmt)}', n(doneN)),
      _statCard('REJECTED', 'UGX ${_money.format(rejAmt)}', n(rejN)),
      _statCard('ALL TRANSACTIONS', '${all.length}', 'All statuses'),
    ];

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 900) {
        return Row(children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ]
        ]);
      }
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final card in cards) SizedBox(width: w, child: card)],
      );
    });
  }

  Widget _statCard(String label, String value, String caption) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: _MM.muted)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w700, color: _MM.ink)),
          ),
          const SizedBox(height: 10),
          Text(caption,
              style: GoogleFonts.inter(fontSize: 12, color: _MM.faint)),
        ],
      ),
    );
  }

  // ───────────────────────── table card ─────────────────────────

  Widget _tableCard(List<_Txn> all, List<_Txn> shown, bool loading) {
    return Container(
      decoration: _box(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Text('Transactions',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _MM.ink)),
                const SizedBox(width: 10),
                Text('${shown.length} of ${all.length}',
                    style: GoogleFonts.inter(fontSize: 12, color: _MM.muted)),
              ],
            ),
          ),
          const Divider(height: 1, color: _MM.line),
          Padding(padding: const EdgeInsets.all(16), child: _filterBar()),
          const Divider(height: 1, color: _MM.line),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 56),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (shown.isEmpty)
            _emptyState()
          else
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 820;
              return Column(
                children: [
                  if (wide) _tableHeader(),
                  for (var i = 0; i < shown.length; i++) ...[
                    if (i > 0 || wide) const Divider(height: 1, color: _MM.line),
                    wide ? _wideRow(shown[i]) : _narrowRow(shown[i]),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return LayoutBuilder(builder: (context, c) {
      final chips = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final f in _Filter.values) _chip(f)],
      );
      final search = TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        style: GoogleFonts.inter(fontSize: 13, color: _MM.ink),
        decoration: InputDecoration(
          hintText: 'Search transactions',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _MM.faint),
          prefixIcon: const Icon(Icons.search, size: 18, color: _MM.muted),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _MM.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _MM.navy, width: 1.4),
          ),
        ),
      );

      if (c.maxWidth >= 700) {
        return Row(children: [
          Expanded(child: chips),
          const SizedBox(width: 12),
          SizedBox(width: 280, child: search),
        ]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [chips, const SizedBox(height: 12), search],
      );
    });
  }

  Widget _chip(_Filter f) {
    final selected = _filter == f;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _MM.navy : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _MM.navy : _MM.line),
          ),
          child: Text(
            _filterLabels[f]!,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _MM.ink,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── rows ─────────────────────────

  static const _actionsWidth = 210.0;

  Widget _tableHeader() {
    TextStyle s() => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: _MM.muted);
    return Container(
      color: _MM.headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('MEMBER', style: s())),
          Expanded(flex: 2, child: Text('PHONE', style: s())),
          Expanded(flex: 2, child: Text('DATE', style: s())),
          Expanded(flex: 2, child: Text('STATUS', style: s())),
          Expanded(
              flex: 2,
              child: Text('AMOUNT', style: s(), textAlign: TextAlign.right)),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }

  Widget _wideRow(_Txn t) {
    final date = t.createdAt;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: _memberCell(t)),
          Expanded(
            flex: 2,
            child: Text(t.phone,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, color: _MM.ink)),
          ),
          Expanded(
            flex: 2,
            child: date == null
                ? Text('—',
                    style: GoogleFonts.inter(fontSize: 13, color: _MM.muted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('d MMM yyyy').format(date),
                          style:
                              GoogleFonts.inter(fontSize: 13, color: _MM.ink)),
                      const SizedBox(height: 2),
                      Text(DateFormat('h:mm a').format(date),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: _MM.faint)),
                    ],
                  ),
          ),
          Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerLeft, child: _badge(t.status)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'UGX ${_money.format(t.amount)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _MM.ink),
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: t.status == 'pending'
                ? Align(alignment: Alignment.centerRight, child: _actions(t))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _narrowRow(_Txn t) {
    final date = t.createdAt;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _memberCell(t)),
              const SizedBox(width: 8),
              Text('UGX ${_money.format(t.amount)}',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _MM.ink)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _badge(t.status),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  [
                    t.phone,
                    if (date != null) DateFormat('d MMM yyyy').format(date),
                  ].join('  ·  '),
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: _MM.muted),
                ),
              ),
            ],
          ),
          if (t.status == 'pending') ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: _actions(t)),
          ],
        ],
      ),
    );
  }

  Widget _memberCell(_Txn t) {
    final (bg, fg, icon) = switch (t.status) {
      'completed' => (_MM.greenBg, _MM.green, Icons.smartphone_rounded),
      'rejected' => (_MM.redBg, _MM.red, Icons.smartphone_rounded),
      _ => (_MM.amberBg, _MM.amber, Icons.smartphone_rounded),
    };
    final sub = [t.provider, if (t.reference != null) t.reference!].join('  ·  ');
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.member,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _MM.ink)),
              const SizedBox(height: 2),
              Text(sub,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: _MM.muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String status) {
    final (bg, fg, label) = switch (status) {
      'completed' => (_MM.greenBg, _MM.green, 'Completed'),
      'rejected' => (_MM.redBg, _MM.red, 'Rejected'),
      _ => (_MM.amberBg, _MM.amber, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _actions(_Txn t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: () => _rejectTransaction(t.id),
          style: OutlinedButton.styleFrom(
            foregroundColor: _MM.red,
            side: const BorderSide(color: Color(0xFFF0C4BE)),
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle:
                GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Reject'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _approveTransaction(t.id, t.data),
          style: ElevatedButton.styleFrom(
            backgroundColor: _MM.navy,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle:
                GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }

  // ───────────────────────── empty / error ─────────────────────────

  Widget _emptyState() {
    final title = _query.isNotEmpty
        ? 'No matching transactions'
        : switch (_filter) {
            _Filter.pending => 'No pending transactions',
            _Filter.completed => 'No completed transactions',
            _Filter.rejected => 'No rejected transactions',
            _Filter.all => 'No transactions yet',
          };
    final sub = _query.isNotEmpty
        ? 'Try a different name, phone number or reference'
        : 'Member mobile money deposits will appear here';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.smartphone_rounded,
                size: 28, color: _MM.faint),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _MM.ink)),
          const SizedBox(height: 4),
          Text(sub,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _MM.muted)),
        ],
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: _box(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: _MM.red),
            const SizedBox(height: 12),
            Text('Could not load transactions',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _MM.ink)),
            const SizedBox(height: 6),
            Text(message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _MM.muted)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: _MM.navy,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _MM.line),
      );

  // ───────────────────────── actions (logic unchanged) ─────────────────────────

  String get _actor =>
      FirebaseService.sessionProfile?['name'] as String? ??
      FirebaseService.sessionProfile?['fullName'] as String? ??
      'Admin';

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _approveTransaction(
      String docId, Map<String, dynamic> txn) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Update member's savings balance
      final memberId = txn['memberId'] as String?;
      if (memberId != null && memberId.isNotEmpty) {
        final memberRef = FirebaseFirestore.instance
            .collection('saccoplus-members')
            .doc(memberId);
        final memberSnap = await memberRef.get();

        if (memberSnap.exists) {
          final currentSavings =
              (memberSnap.data()?['savingsBalance'] ?? 0).toDouble();
          final amount = (txn['amount'] ?? 0).toDouble();

          await memberRef.update({'savingsBalance': currentSavings + amount});

          // Record in savings transactions
          await FirebaseFirestore.instance
              .collection('saccoplus-savings-transactions')
              .add({
            'tenantId': FirebaseService.sessionTenantId,
            'memberId': memberId,
            'memberName': txn['memberName'] ?? 'Unknown',
            'type': 'Deposit',
            'amount': amount,
            'balanceAfter': currentSavings + amount,
            'method': 'Mobile Money',
            'provider': txn['provider'],
            'phoneNumber': txn['phoneNumber'],
            'reference': txn['reference'],
            'description': txn['description'] ?? 'Mobile money deposit',
            'status': 'Approved',
            'approvedBy': _actor,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update transaction status
      await FirebaseFirestore.instance
          .collection('mobileMoneyTransactions')
          .doc(docId)
          .update({
        'status': 'completed',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _actor,
      });

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _toast('Transaction approved successfully', _MM.green);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _toast('Error: $e', _MM.red);
    }
  }

  Future<void> _rejectTransaction(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reject transaction?',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: _MM.ink)),
        content: Text(
          'Are you sure you want to reject this transaction? This action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, color: _MM.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: _MM.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _MM.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('mobileMoneyTransactions')
          .doc(docId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _actor,
      });
      _toast('Transaction rejected', _MM.amber);
    } catch (e) {
      _toast('Error: $e', _MM.red);
    }
  }
}


// Bank Transfers Screen - Matching Mobile Money style
class BankTransfersScreen extends StatefulWidget {
  const BankTransfersScreen({super.key});

  @override
  State<BankTransfersScreen> createState() => _BankTransfersScreenState();
}

class _BankTransfersScreenState extends State<BankTransfersScreen> {
  String _selectedFilter = 'all';
  final _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank Transfers',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              'Track cash movements between bank and SACCO',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 70,
      ),
      body: Column(
        children: [
          _buildStatusCards(),
          _buildFilterButtons(),
          Expanded(child: _buildTransfersList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordTransferDialog(context),
        backgroundColor: const Color(0xFF2F8F6B),
        icon: const Icon(Icons.add),
        label: const Text('Record Transfer'),
      ),
    );
  }

  Widget _buildStatusCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bank-transfers')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snapshot) {
        double pending = 0, completed = 0, all = 0;
        int pendingCount = 0, completedCount = 0, allCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0).toDouble();
            final status = data['status'] as String? ?? 'completed';

            allCount++;
            all += amount;

            if (status == 'pending') {
              pending += amount;
              pendingCount++;
            } else {
              completed += amount;
              completedCount++;
            }
          }
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  'PENDING APPROVAL',
                  'UGX ${_currencyFormat.format(pending)}',
                  '$pendingCount transactions',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  'COMPLETED',
                  'UGX ${_currencyFormat.format(completed)}',
                  '$completedCount transactions',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusCard(
                  'ALL TRANSACTIONS',
                  '$allCount',
                  'All statuses',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transactions  1 of 0',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFilterButton('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterButton('Cash In', 'cash_in'),
              const SizedBox(width: 8),
              _buildFilterButton('Cash Out', 'cash_out'),
              const SizedBox(width: 8),
              _buildFilterButton('Pending', 'pending'),
              const Spacer(),
              SizedBox(
                width: 200,
                height: 36,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search transactions',
                    hintStyle: GoogleFonts.poppins(fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2F8F6B) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildTransfersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bank-transfers')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading transfers', style: GoogleFonts.poppins(color: Colors.red)),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var transfers = snapshot.data!.docs;

        // Filter
        if (_selectedFilter == 'cash_in') {
          transfers = transfers.where((doc) =>
              (doc.data() as Map)['type'] == 'cash_in').toList();
        } else if (_selectedFilter == 'cash_out') {
          transfers = transfers.where((doc) =>
              (doc.data() as Map)['type'] == 'cash_out').toList();
        } else if (_selectedFilter == 'pending') {
          transfers = transfers.where((doc) =>
              ((doc.data() as Map)['status'] ?? 'completed') == 'pending').toList();
        }

        if (transfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No ${_selectedFilter == 'all' ? '' : _selectedFilter} transactions',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Member mobile money deposits will appear here',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final data = transfers[index].data() as Map<String, dynamic>;
            return _buildTransferCard(data);
          },
        );
      },
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer) {
    final type = transfer['type'] as String? ?? 'cash_in';
    final isCashIn = type == 'cash_in';
    final color = isCashIn ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCashIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer['description'] ?? (isCashIn ? 'Cash from Bank' : 'Cash to Bank'),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  transfer['recordedBy'] ?? 'Admin',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            'UGX ${_currencyFormat.format(transfer['amount'])}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ],
      ),
    );
  }

  void _showRecordTransferDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _RecordTransferDialog(),
    );
  }
}

// Dialog for recording a new bank transfer
class _RecordTransferDialog extends StatefulWidget {
  const _RecordTransferDialog();

  @override
  State<_RecordTransferDialog> createState() => _RecordTransferDialogState();
}

class _RecordTransferDialogState extends State<_RecordTransferDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'cash_in';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    final description = _descriptionController.text.trim();

    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    if (description.isEmpty) {
      _showError('Enter a description');
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('bank-transfers').add({
        'tenantId': FirebaseService.sessionTenantId,
        'type': _type,
        'amount': amount,
        'description': description,
        'recordedBy': 'Admin', // TODO: Get actual user name
        'recordedById': FirebaseService.sessionUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transfer recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save: $e');
      setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Record Bank Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(
                labelText: 'Transfer Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'cash_in', child: Text('Cash from Bank (Bank → Cash)')),
                DropdownMenuItem(value: 'cash_out', child: Text('Cash to Bank (Cash → Bank)')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: 'UGX ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Weekly banking, Petty cash withdrawal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

// Reconciliation Screen
class ReconciliationScreen extends StatelessWidget {
  const ReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Reconciliation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.balance, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Reconciliation',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Reconcile SACCO accounts with bank statements',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterAction = 'All';

  static const _actionFilters = <String, IconData>{
    'All': Icons.apps_rounded,
    'LOAN': Icons.request_quote_rounded,
    'KYC': Icons.verified_user_rounded,
    'WALLET': Icons.account_balance_wallet_rounded,
    'SAVINGS': Icons.savings_rounded,
    'SHARE': Icons.pie_chart_rounded,
    'FD': Icons.account_balance_rounded,
    'USER': Icons.person_rounded,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> d) {
    final action = (d['action'] as String? ?? '').toUpperCase();
    if (_filterAction != 'All' && !action.contains(_filterAction)) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (d['actorName'] as String? ?? '').toLowerCase().contains(q) ||
        (d['description'] as String? ?? '').toLowerCase().contains(q) ||
        (d['targetName'] as String? ?? '').toLowerCase().contains(q) ||
        action.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: canPop
          ? AppBar(
              title: Text('Audit Trail',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.auditLogCol)
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary));
                }
                final all = snap.data?.docs ?? [];
                final filtered = all
                    .map((d) => d.data() as Map<String, dynamic>)
                    .where(_matches)
                    .toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    message: 'No audit logs found.',
                    icon: Icons.history_rounded,
                  );
                }

                final items = _groupByDay(filtered);

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(
                          '${filtered.length} ${filtered.length == 1 ? 'event' : 'events'}',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      );
                    }
                    final item = items[i - 1];
                    if (item is String) return _DayHeader(label: item);
                    return _AuditTile(data: item as Map<String, dynamic>);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            cursorColor: Colors.white,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search actor, action or description',
              hintStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.16),
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _actionFilters.entries.map((e) {
                final selected = _filterAction == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _filterAction = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(e.value,
                            size: 15,
                            color: selected ? AppTheme.primary : Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          e.key,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppTheme.primary : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _dateOf(Map<String, dynamic> d) {
    final ts = d['timestamp'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  List<Object> _groupByDay(List<Map<String, dynamic>> logs) {
    final out = <Object>[];
    String? last;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final d in logs) {
      final dt = _dateOf(d);
      String label = 'Earlier';
      if (dt != null) {
        final day = DateTime(dt.year, dt.month, dt.day);
        final diff = today.difference(day).inDays;
        label = diff == 0
            ? 'Today'
            : diff == 1
                ? 'Yesterday'
                : DateFormat('EEEE, MMM d, yyyy').format(dt);
      }
      if (label != last) {
        out.add(label);
        last = label;
      }
      out.add(d);
    }
    return out;
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppTheme.textSecondary)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: Color(0xFFE2E7EF))),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AuditTile({required this.data});

  String get _action => (data['action'] as String? ?? '').toUpperCase();

  Color get _color {
    final a = _action;
    if (a.contains('APPROVED') || a.contains('DEPOSIT') || a.contains('LOGIN')) {
      return AppTheme.success;
    }
    if (a.contains('REJECTED') || a.contains('WITHDRAWAL')) return AppTheme.error;
    if (a.contains('LOAN') || a.contains('REPAYMENT')) return AppTheme.primary;
    if (a.contains('KYC')) return AppTheme.warning;
    return AppTheme.textSecondary;
  }

  IconData get _icon {
    final a = _action;
    if (a.contains('LOAN')) return Icons.request_quote_rounded;
    if (a.contains('KYC')) return Icons.verified_user_rounded;
    if (a.contains('WALLET')) return Icons.account_balance_wallet_rounded;
    if (a.contains('SAVINGS')) return Icons.savings_rounded;
    if (a.contains('SHARE')) return Icons.pie_chart_rounded;
    if (a.contains('FD')) return Icons.account_balance_rounded;
    if (a.contains('LOGIN')) return Icons.login_rounded;
    if (a.contains('PIN')) return Icons.dialpad_rounded;
    if (a.contains('NOTIF')) return Icons.notifications_rounded;
    return Icons.history_rounded;
  }

  String get _timeStr {
    final ts = data['timestamp'];
    if (ts is Timestamp) return DateFormat('HH:mm:ss').format(ts.toDate());
    return data['timestampLocal'] as String? ?? '—';
  }

  String get _fullTimeStr {
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      return DateFormat('EEE, MMM d, yyyy • HH:mm:ss').format(ts.toDate());
    }
    return data['timestampLocal'] as String? ?? '—';
  }

  String _pretty(String a) =>
      a.isEmpty ? '—' : a.replaceAll('_', ' ').toLowerCase().split(' ').map((w) {
            return w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);
          }).join(' ');

  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFDDE2EA),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon, color: _color, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_pretty(data['action'] as String? ?? ''),
                            style: GoogleFonts.poppins(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(_fullTimeStr,
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _row('Description', data['description'] as String? ?? '—'),
              _row('Performed by', data['actorName'] as String? ?? '—'),
              _row('Role', data['actorRole'] as String? ?? '—'),
              if (data['targetName'] != null)
                _row('Target', data['targetName'] as String),
              if (data['metadata'] != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE2E7EF)),
                const SizedBox(height: 16),
                Text('DETAILS',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                _buildMetadata(data['metadata'] as Map<String, dynamic>),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(Map<String, dynamic> metadata) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: metadata.entries.map((e) {
          String value;
          if (e.value is Map || e.value is List) {
            value = e.value.toString();
          } else {
            value = e.value?.toString() ?? '—';
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    _pretty(e.key),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final action = data['action'] as String? ?? '—';
    final description = data['description'] as String? ?? '—';
    final actorName = data['actorName'] as String? ?? '—';
    final actorRole = data['actorRole'] as String? ?? '—';
    final targetName = data['targetName'] as String?;

    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2937).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon, color: _color, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      action,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          color: _color,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.schedule_rounded,
                                    size: 11, color: AppTheme.textSecondary),
                                const SizedBox(width: 3),
                                Text(_timeStr,
                                    style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 13, color: AppTheme.textSecondary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '$actorName · $actorRole',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                                if (targetName != null) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.arrow_right_alt_rounded,
                                      size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      targetName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
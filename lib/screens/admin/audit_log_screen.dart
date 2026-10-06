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

  static const _actionFilters = [
    'All', 'LOAN', 'KYC', 'WALLET', 'SAVINGS', 'SHARE', 'FD', 'USER',
  ];

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
      backgroundColor: AppTheme.surface,
      appBar: canPop ? AppBar(
        title: const Text('Audit Trail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ) : null,
      body: Column(
        children: [
          // ── Search + filter ──────────────────────────────────────────
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              TextField(
                controller: _searchCtrl,
                style: GoogleFonts.poppins(color: Colors.white),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by actor, action, description…',
                  hintStyle: GoogleFonts.poppins(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                          onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _actionFilters.map((f) {
                    final selected = _filterAction == f;
                    return GestureDetector(
                      onTap: () => setState(() => _filterAction = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.accent : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(f,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),

          // ── Log list ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.auditLogCol)
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }
                final all = snap.data?.docs ?? [];
                final filtered = all.where((d) => _matches(d.data() as Map<String, dynamic>)).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    message: 'No audit logs found.',
                    icon: Icons.history_rounded,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final data = filtered[i].data() as Map<String, dynamic>;
                    return _AuditTile(data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AuditTile({required this.data});

  Color get _color {
    final a = (data['action'] as String? ?? '').toUpperCase();
    if (a.contains('APPROVED') || a.contains('DEPOSIT') || a.contains('LOGIN')) return AppTheme.success;
    if (a.contains('REJECTED') || a.contains('WITHDRAWAL')) return AppTheme.error;
    if (a.contains('LOAN') || a.contains('REPAYMENT')) return AppTheme.primary;
    if (a.contains('KYC')) return AppTheme.warning;
    return AppTheme.textSecondary;
  }

  IconData get _icon {
    final a = (data['action'] as String? ?? '').toUpperCase();
    if (a.contains('LOAN'))    return Icons.account_balance_wallet_rounded;
    if (a.contains('KYC'))     return Icons.verified_user_rounded;
    if (a.contains('WALLET'))  return Icons.account_balance_wallet_outlined;
    if (a.contains('SAVINGS')) return Icons.savings_rounded;
    if (a.contains('SHARE'))   return Icons.pie_chart_rounded;
    if (a.contains('FD'))      return Icons.account_balance_rounded;
    if (a.contains('LOGIN'))   return Icons.login_rounded;
    if (a.contains('PIN'))     return Icons.dialpad_rounded;
    if (a.contains('NOTIF'))   return Icons.notifications_rounded;
    return Icons.history_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final action      = data['action'] as String? ?? '—';
    final description = data['description'] as String? ?? '—';
    final actorName   = data['actorName'] as String? ?? '—';
    final actorRole   = data['actorRole'] as String? ?? '—';
    final targetName  = data['targetName'] as String?;
    final ts          = data['timestamp'];
    String timeStr = data['timestampLocal'] as String? ?? '—';
    if (ts is Timestamp) {
      timeStr = DateFormat('MMM d, yyyy  HH:mm:ss').format(ts.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(action,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                fontSize: 9, color: _color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(timeStr,
                        style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(
                  'By: $actorName ($actorRole)${targetName != null ? '  •  Target: $targetName' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';

const _kBorder = Color(0xFFE5E7EB);
const _kContentMaxWidth = 720.0;
const _kSaccoName = 'MBADIFA SACCO';

TextStyle _text(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppTheme.textPrimary,
      height: height,
    );

String _memberName(Map<String, dynamic> m) =>
    (m['name'] ?? m['fullName'] ?? 'Unknown').toString().trim();

String _memberPhone(Map<String, dynamic> m) =>
    (m['phone'] ?? '').toString().trim();

OutlineInputBorder _border(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );

InputDecoration _decoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: _text(14, color: AppTheme.textSecondary.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      counterStyle: _text(11, color: AppTheme.textSecondary),
      border: _border(_kBorder),
      enabledBorder: _border(_kBorder),
      focusedBorder: _border(AppTheme.primary, width: 1.5),
    );

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  static const _maxTitle = 80;
  static const _maxMessage = 500;

  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  late final TabController _tabController;

  bool _sending = false;
  bool _sendToAll = true;
  bool _loadingMembers = false;
  Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _allMembers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await FirebaseService.getAllFarmersOnce();
      if (mounted) {
        setState(() {
          _allMembers = members;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _pickMembers() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MemberPicker(
        members: _allMembers,
        initial: _selectedIds,
      ),
    );
    if (result != null && mounted) setState(() => _selectedIds = result);
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();

    if (title.isEmpty || msg.isEmpty) {
      _showSnackBar('Please fill in both title and message.', isError: true);
      return;
    }

    if (!_sendToAll && _selectedIds.isEmpty) {
      _showSnackBar('Please select at least one member.', isError: true);
      return;
    }

    setState(() => _sending = true);
    try {
      List<String> targetMemberIds;

      if (_sendToAll) {
        final snap = await FirebaseService.getAllFarmers().first;
        targetMemberIds = snap.docs.map((doc) => doc.id).toList();
      } else {
        targetMemberIds = _selectedIds.toList();
      }

      int sentCount = 0;
      int skippedCount = 0;

      for (final memberId in targetMemberIds) {
        final member = _allMembers.firstWhere(
          (m) => m['id'] == memberId,
          orElse: () => <String, dynamic>{},
        );

        final farmerName = (member['name'] as String? ??
                member['fullName'] as String? ??
                'Member')
            .trim();
        final phone = member['phone'] as String? ?? '';

        if (phone.isEmpty) {
          skippedCount++;
          continue;
        }

        // Every outgoing message starts with the SACCO name, before the
        // title and the "Dear ..." greeting.
        final brandedTitle = '$_kSaccoName - $title';
        final personalMsg = 'Dear $farmerName, $msg';
        await FirebaseService.sendNotification(
            memberId, brandedTitle, personalMsg);
        FirebaseService.sendSmsToPhone(phone, '$brandedTitle: $personalMsg');
        sentCount++;
      }

      if (mounted) {
        _titleCtrl.clear();
        _msgCtrl.clear();
        setState(() {
          _selectedIds = {};
          _sendToAll = true;
        });

        String resultMsg = 'Sent to $sentCount member(s)';
        if (skippedCount > 0) {
          resultMsg += ' · $skippedCount skipped (no phone number)';
        }
        _showSnackBar(resultMsg, isError: false);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: _text(13, color: Colors.white)),
          backgroundColor: isError ? AppTheme.error : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
  }

  // ── Layout ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildComposeTab(), _buildHistoryTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications',
                        style: _text(20, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Send messages to members',
                        style: _text(13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: _text(14, weight: FontWeight.w600),
                unselectedLabelStyle: _text(14, weight: FontWeight.w500),
                tabs: const [Tab(text: 'Compose'), Tab(text: 'History')],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compose ────────────────────────────────────────────────────────────

  Widget _buildComposeTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
              child: Container(
                padding: EdgeInsets.all(wide ? 24 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Title'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      maxLength: _maxTitle,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      style: _text(14),
                      decoration: _decoration('e.g. Annual general meeting'),
                    ),
                    const SizedBox(height: 12),
                    _label('Message'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _msgCtrl,
                      maxLength: _maxMessage,
                      minLines: 4,
                      maxLines: 8,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: _text(14, height: 1.5),
                      decoration: _decoration('Write your message'),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: _kBorder),
                    const SizedBox(height: 20),
                    _label('Recipients'),
                    const SizedBox(height: 8),
                    _buildRecipientToggle(),
                    const SizedBox(height: 12),
                    if (!_sendToAll) ...[
                      _buildSelectTile(),
                      const SizedBox(height: 12),
                    ],
                    _buildRecipientNote(),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: wide ? 220 : double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : _sendNotification,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _kBorder,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _sending ? 'Sending…' : 'Send notification',
                            style: _text(14,
                                weight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text) =>
      Text(text, style: _text(13, weight: FontWeight.w600));

  Widget _buildRecipientToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          _segment('All members', _sendToAll,
              () => setState(() => _sendToAll = true)),
          _segment('Selected members', !_sendToAll,
              () => setState(() => _sendToAll = false)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text(
                13,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectTile() {
    final names = _allMembers
        .where((m) => _selectedIds.contains(m['id']))
        .map(_memberName)
        .toList();
    final preview = names.isEmpty
        ? 'Tap to choose recipients'
        : names.length <= 2
            ? names.join(', ')
            : '${names.take(2).join(', ')} +${names.length - 2} more';
    final count = _selectedIds.length;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _loadingMembers ? null : _pickMembers,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 20, color: AppTheme.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loadingMembers
                          ? 'Loading members…'
                          : count == 0
                              ? 'Choose members'
                              : '$count selected',
                      style: _text(14, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_loadingMembers)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientNote() {
    String text;
    if (_loadingMembers) {
      text = 'Loading members…';
    } else if (_allMembers.isEmpty) {
      text = 'Members without a phone number on file are skipped.';
    } else {
      final reachable =
          _allMembers.where((m) => _memberPhone(m).isNotEmpty).length;
      text = _sendToAll
          ? '$reachable of ${_allMembers.length} members have a phone number '
              'and will receive this. The rest are skipped.'
          : 'Members without a phone number are skipped.';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded,
              size: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: _text(12, color: AppTheme.textSecondary, height: 1.4)),
        ),
      ],
    );
  }

  // ── History ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications yet',
            subtitle: 'Messages you send will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
                child: _HistoryTile(data: data),
              ),
            );
          },
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// History tile
// ═════════════════════════════════════════════════════════════════════════

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'No title').toString();
    final message = (data['message'] ?? '').toString();
    final ts = data['timestamp'];
    final date = ts is Timestamp
        ? DateFormat('d MMM yyyy, HH:mm').format(ts.toDate())
        : 'Unknown date';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _text(14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(date, style: _text(12, color: AppTheme.textSecondary)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _text(13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Empty state
// ═════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textSecondary.withOpacity(0.6)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: _text(15, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: _text(13, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Member picker (bottom sheet; width-capped on tablets / desktop)
// ═════════════════════════════════════════════════════════════════════════

class _MemberPicker extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Set<String> initial;
  const _MemberPicker({required this.members, required this.initial});

  @override
  State<_MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<_MemberPicker> {
  final _searchCtrl = TextEditingController();
  late final List<Map<String, dynamic>> _sorted;
  late Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.members]..sort((a, b) =>
        _memberName(a).toLowerCase().compareTo(_memberName(b).toLowerCase()));
    _selected = {...widget.initial};
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _sorted;
    return _sorted
        .where((m) =>
            _memberName(m).toLowerCase().contains(q) ||
            _memberPhone(m).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final visible = _visible;
    final visibleIds = visible.map((m) => m['id'].toString()).toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selected.contains);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.85,
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Select members',
                        style: _text(17, weight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                style: _text(14),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: _decoration('Search by name or phone').copyWith(
                  counterText: '',
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppTheme.textSecondary),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Count + select all
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selected.length} of ${widget.members.length} selected',
                      style: _text(12, color: AppTheme.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: visibleIds.isEmpty
                        ? null
                        : () => setState(() {
                              if (allVisibleSelected) {
                                _selected.removeAll(visibleIds);
                              } else {
                                _selected.addAll(visibleIds);
                              }
                            }),
                    child: Text(
                      allVisibleSelected ? 'Clear' : 'Select all',
                      style: _text(13,
                          weight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            // List
            Expanded(
              child: visible.isEmpty
                  ? const _EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No members found',
                      subtitle: 'Try a different name or number.',
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 20, endIndent: 20, color: _kBorder),
                      itemBuilder: (context, i) {
                        final m = visible[i];
                        final id = m['id'].toString();
                        final phone = _memberPhone(m);
                        return CheckboxListTile(
                          value: _selected.contains(id),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          activeColor: AppTheme.primary,
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          title: Text(
                            _memberName(m),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _text(14, weight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            phone.isEmpty ? 'No phone number' : phone,
                            style: _text(
                              12,
                              color: phone.isEmpty
                                  ? AppTheme.warning
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _kBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: _kBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Cancel',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: _text(14,
                                weight: FontWeight.w600,
                                color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, _selected),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            _selected.isEmpty
                                ? 'Done'
                                : 'Done (${_selected.length})',
                            style: _text(14,
                                weight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
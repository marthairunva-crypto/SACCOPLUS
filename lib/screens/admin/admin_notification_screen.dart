import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/constants.dart';

// ═════════════════════════════════════════════════════════════════════════
// Design tokens
// ═════════════════════════════════════════════════════════════════════════

const _kBorder = Color(0xFFE5E7EB);
const _kSaccoName = 'MBADIFA SACCO';

/// Breakpoints
const _kMediumBreakpoint = 600.0; // tablets / large phones
const _kWideBreakpoint = 960.0; // desktop / landscape tablets

/// Max content widths
const _kNarrowMax = 720.0;
const _kWideMax = 1120.0;

double _gutter(double width) => width >= _kMediumBreakpoint ? 24 : 16;
double _maxWidthFor(double width) =>
    width >= _kWideBreakpoint ? _kWideMax : _kNarrowMax;

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

String _greetingName(Map<String, dynamic> m) {
  final raw = (m['name'] ?? m['fullName'] ?? '').toString().trim();
  return raw.isEmpty ? 'Member' : raw;
}

String _memberPhone(Map<String, dynamic> m) =>
    (m['phone'] ?? '').toString().trim();

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

int _smsParts(int length) {
  if (length == 0) return 0;
  if (length <= 160) return 1;
  return (length / 153).ceil();
}

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

// ═════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════

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
  int _progressDone = 0;
  int _progressTotal = 0;
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

  // ── Derived data ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _selectedMembers => _allMembers
      .where((m) => _selectedIds.contains(m['id'].toString()))
      .toList();

  List<Map<String, dynamic>> get _targets =>
      _sendToAll ? _allMembers : _selectedMembers;

  int get _reachableCount =>
      _targets.where((m) => _memberPhone(m).isNotEmpty).length;

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
    final width = MediaQuery.of(context).size.width;
    Set<String>? result;

    if (width >= _kMediumBreakpoint) {
      // Tablet / desktop: centered dialog
      result = await showDialog<Set<String>>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
            child: _MemberPicker(
              members: _allMembers,
              initial: _selectedIds,
              asDialog: true,
            ),
          ),
        ),
      );
    } else {
      // Phone: bottom sheet
      result = await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final mq = MediaQuery.of(ctx);
          final available = mq.size.height - mq.viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: SizedBox(
              height: math.min(available * 0.9, 720),
              child: _MemberPicker(
                members: _allMembers,
                initial: _selectedIds,
                asDialog: false,
              ),
            ),
          );
        },
      );
    }

    if (result != null && mounted) setState(() => _selectedIds = result!);
  }

  Future<bool?> _confirmSend(int count, int skipped) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Send notification?',
            style: _text(17, weight: FontWeight.w700)),
        content: Text(
          'This will send an SMS and an in-app notification to '
          '${_plural(count, 'member')}.'
          '${skipped > 0 ? ' ${_plural(skipped, 'member')} without a phone number will be skipped.' : ''}',
          style: _text(14, color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: _text(14,
                    weight: FontWeight.w600, color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Send',
                style: _text(14, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (_sending) return;

    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();

    if (title.isEmpty || msg.isEmpty) {
      _showSnackBar('Please fill in both title and message.', isError: true);
      return;
    }
    if (_loadingMembers) {
      _showSnackBar('Members are still loading. Try again in a moment.',
          isError: true);
      return;
    }
    if (!_sendToAll && _selectedIds.isEmpty) {
      _showSnackBar('Please select at least one member.', isError: true);
      return;
    }

    final targets = _targets;
    final reachable =
        targets.where((m) => _memberPhone(m).isNotEmpty).toList();
    final skippedCount = targets.length - reachable.length;

    if (reachable.isEmpty) {
      _showSnackBar('None of the chosen members have a phone number.',
          isError: true);
      return;
    }

    final confirmed = await _confirmSend(reachable.length, skippedCount);
    if (confirmed != true || !mounted) return;

    setState(() {
      _sending = true;
      _progressDone = 0;
      _progressTotal = reachable.length;
    });

    int sentCount = 0;
    int failedCount = 0;

    try {
      // Every outgoing message starts with the SACCO name, before the
      // title and the "Dear ..." greeting.
      final brandedTitle = '$_kSaccoName - $title';

      for (final member in reachable) {
        final memberId = member['id'].toString();
        final phone = _memberPhone(member);
        final personalMsg = 'Dear ${_greetingName(member)}, $msg';

        try {
          await FirebaseService.sendNotification(
              memberId, brandedTitle, personalMsg);
          FirebaseService.sendSmsToPhone(phone, '$brandedTitle: $personalMsg');
          sentCount++;
        } catch (_) {
          failedCount++;
        }

        if (mounted) {
          setState(() => _progressDone = sentCount + failedCount);
        }
      }

      if (mounted) {
        if (sentCount > 0) {
          _titleCtrl.clear();
          _msgCtrl.clear();
          setState(() {
            _selectedIds = {};
            _sendToAll = true;
          });
        }

        String resultMsg = 'Sent to ${_plural(sentCount, 'member')}';
        if (skippedCount > 0) {
          resultMsg += ' · $skippedCount skipped (no phone number)';
        }
        if (failedCount > 0) {
          resultMsg += ' · $failedCount failed';
        }
        _showSnackBar(resultMsg, isError: sentCount == 0 && failedCount > 0);
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
      body: LayoutBuilder(
        builder: (context, c) {
          final maxW = _maxWidthFor(c.maxWidth);
          return Column(
            children: [
              _buildHeader(maxW, c.maxWidth),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildComposeTab(maxW),
                    _buildHistoryTab(maxW),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(double maxW, double screenW) {
    final gutter = _gutter(screenW);
    final tabsMaxWidth = screenW >= _kMediumBreakpoint ? 320.0 : double.infinity;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notifications',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(20, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Send messages to members',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (_allMembers.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              _plural(_allMembers.length, 'member'),
                              style: _text(12,
                                  weight: FontWeight.w600,
                                  color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenW >= _kMediumBreakpoint ? gutter - 16 : 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: tabsMaxWidth),
                  child: TabBar(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Compose ────────────────────────────────────────────────────────────

  Widget _buildComposeTab(double maxW) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final wide = w >= _kWideBreakpoint;
        final gutter = _gutter(w);

        final Widget body;
        if (wide) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: _buildMessageCard(wide: true)),
              const SizedBox(width: 20),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRecipientsCard(),
                    const SizedBox(height: 20),
                    _buildPreviewCard(),
                  ],
                ),
              ),
            ],
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMessageCard(wide: false),
              const SizedBox(height: 16),
              _buildRecipientsCard(),
              const SizedBox(height: 16),
              _buildPreviewCard(),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.all(gutter),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW - gutter * 2),
                    child: body,
                  ),
                ),
              ),
            ),
            _buildActionBar(maxW, w),
          ],
        );
      },
    );
  }

  Widget _card({required Widget child}) {
    return LayoutBuilder(builder: (context, c) {
      final pad = MediaQuery.of(context).size.width >= _kMediumBreakpoint
          ? 20.0
          : 16.0;
      return Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      );
    });
  }

  Widget _sectionHeader(IconData icon, String title, {String? subtitle}) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _text(15, weight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _text(12, color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) =>
      Text(text, style: _text(13, weight: FontWeight.w600));

  Widget _buildMessageCard({required bool wide}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.edit_note_rounded, 'Message',
              subtitle: 'What do you want members to know?'),
          const SizedBox(height: 20),
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
          const SizedBox(height: 8),
          _label('Message'),
          const SizedBox(height: 8),
          TextField(
            controller: _msgCtrl,
            maxLength: _maxMessage,
            minLines: wide ? 10 : 5,
            maxLines: wide ? 14 : 8,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: _text(14, height: 1.5),
            decoration: _decoration('Write your message'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientsCard() {
    final selected = _selectedMembers;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.groups_2_outlined, 'Recipients',
              subtitle: 'Who should receive this?'),
          const SizedBox(height: 16),
          _buildRecipientToggle(),
          if (!_sendToAll) ...[
            const SizedBox(height: 12),
            _buildSelectTile(),
            if (selected.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSelectedChips(selected),
            ],
          ],
          const SizedBox(height: 14),
          _buildRecipientNote(),
        ],
      ),
    );
  }

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
    final names = _selectedMembers.map(_memberName).toList();
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

  Widget _buildSelectedChips(List<Map<String, dynamic>> selected) {
    const maxChips = 8;
    final shown = selected.take(maxChips).toList();
    final extra = selected.length - shown.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in shown)
          InputChip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                _memberName(m),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _text(12, weight: FontWeight.w500),
              ),
            ),
            backgroundColor: AppTheme.primary.withOpacity(0.07),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            deleteIcon: Icon(Icons.close_rounded,
                size: 14, color: AppTheme.textSecondary),
            onDeleted: () => setState(
                () => _selectedIds.remove(m['id'].toString())),
          ),
        if (extra > 0)
          Chip(
            label: Text('+$extra more',
                style: _text(12,
                    weight: FontWeight.w600, color: AppTheme.textSecondary)),
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: _kBorder),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildRecipientNote() {
    final total = _allMembers.length;
    final targets = _targets;
    final reachable = _reachableCount;
    final skipped = targets.length - reachable;

    String text;
    bool warn = false;

    if (_loadingMembers) {
      text = 'Loading members…';
    } else if (total == 0) {
      text = 'Members without a phone number on file are skipped.';
    } else if (_sendToAll) {
      if (skipped == 0) {
        text = 'All $total members have a phone number and will receive this.';
      } else {
        text = '$reachable of $total members have a phone number and will '
            'receive this. The other $skipped are skipped.';
        warn = true;
      }
    } else if (_selectedIds.isEmpty) {
      text = 'Choose who should receive this message.';
    } else if (skipped == 0) {
      text = 'All ${targets.length} selected members will receive this.';
    } else {
      text = '$reachable of ${targets.length} selected members will receive '
          'this. The other $skipped have no phone number.';
      warn = true;
    }

    final color = warn ? AppTheme.warning : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warn ? AppTheme.warning.withOpacity(0.08) : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: warn ? AppTheme.warning.withOpacity(0.3) : _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              warn ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: _text(12, color: AppTheme.textSecondary, height: 1.45)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.sms_outlined, 'Preview',
              subtitle: 'How members will see it'),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: Listenable.merge([_titleCtrl, _msgCtrl]),
            builder: (context, _) {
              final title = _titleCtrl.text.trim();
              final msg = _msgCtrl.text.trim();

              if (title.isEmpty && msg.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Text(
                    'Your message preview appears here as you type.',
                    textAlign: TextAlign.center,
                    style: _text(13, color: AppTheme.textSecondary),
                  ),
                );
              }

              final sample = (!_sendToAll && _selectedMembers.length == 1)
                  ? _greetingName(_selectedMembers.first)
                  : '[Member name]';
              final sms = '$_kSaccoName - ${title.isEmpty ? '…' : title}: '
                  'Dear $sample, ${msg.isEmpty ? '…' : msg}';
              final parts = _smsParts(sms.length);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.15)),
                    ),
                    child: Text(sms, style: _text(13, height: 1.5)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${sms.length} characters · ${_plural(parts, 'SMS part')} '
                    '· also sent as an in-app notification',
                    style: _text(11.5, color: AppTheme.textSecondary),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(double maxW, double screenW) {
    final gutter = _gutter(screenW);
    final compact = screenW < _kMediumBreakpoint;
    final reachable = _reachableCount;
    final skipped = _targets.length - reachable;

    final headline = _loadingMembers
        ? 'Loading members…'
        : _sending
            ? 'Sending $_progressDone of $_progressTotal…'
            : reachable == 0
                ? 'No recipients yet'
                : '${_plural(reachable, 'member')} will be notified';
    final subline = _sending
        ? 'Please keep this screen open'
        : skipped > 0
            ? '${_plural(skipped, 'member')} skipped · no phone number'
            : 'SMS and in-app notification';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _text(13.5, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(subline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _text(12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _sendNotification,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kBorder,
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 18 : 24),
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
                        _sending
                            ? 'Sending…'
                            : compact
                                ? 'Send'
                                : 'Send notification',
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
      ),
    );
  }

  // ── History ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab(double maxW) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.notificationsCol)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _EmptyState(
            icon: Icons.error_outline_rounded,
            title: "Couldn't load history",
            subtitle: 'Check your connection and try again.',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications yet',
            subtitle: 'All messages sent will appear here.',
          );
        }

        final items = docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList(growable: false);

        return LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final gutter = _gutter(w);
            final wide = w >= _kWideBreakpoint;

            if (!wide) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: ListView.separated(
                    padding: EdgeInsets.all(gutter),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _HistoryTile(data: items[i]),
                  ),
                ),
              );
            }

            // Wide screens: two balanced columns
            final left = <Widget>[];
            final right = <Widget>[];
            for (var i = 0; i < items.length; i++) {
              final tile = Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _HistoryTile(data: items[i]),
              );
              (i.isEven ? left : right).add(tile);
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(gutter),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW - gutter * 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: left)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(children: right)),
                    ],
                  ),
                ),
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

class _TypeStyle {
  final String? badge;
  final Color color;
  final IconData icon;
  _TypeStyle(this.badge, this.color, this.icon);
}

_TypeStyle _styleFor(String type) {
  switch (type) {
    case 'message':
      return _TypeStyle(null, AppTheme.primary, Icons.campaign_outlined);
    case 'deposit':
      return _TypeStyle('Deposit', AppTheme.success, Icons.south_west_rounded);
    case 'withdrawal':
      return _TypeStyle(
          'Withdrawal', AppTheme.warning, Icons.north_east_rounded);
    case 'loan_payment':
      return _TypeStyle(
          'Loan Payment', AppTheme.primary, Icons.payments_outlined);
    case 'loan_disbursement':
      return _TypeStyle(
          'Loan Disbursed', AppTheme.info, Icons.account_balance_outlined);
    default:
      return _TypeStyle(type.toUpperCase(), AppTheme.textSecondary,
          Icons.notifications_none_rounded);
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryTile({required this.data});

  String get _title => (data['title'] ?? 'No title').toString();
  String get _message => (data['message'] ?? '').toString();
  String get _recipient => (data['recipientName'] ?? '').toString();
  String get _type => (data['type'] ?? 'message').toString();

  String get _date {
    // createdAt for transactions, timestamp for broadcasts
    final ts = data['createdAt'] ?? data['timestamp'];
    return ts is Timestamp
        ? DateFormat('d MMM yyyy, HH:mm').format(ts.toDate())
        : 'Unknown date';
  }

  void _showDetails(BuildContext context) {
    final style = _styleFor(_type);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_title,
                            style: _text(16, weight: FontWeight.w700)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_date,
                          style: _text(12, color: AppTheme.textSecondary)),
                      if (_recipient.isNotEmpty)
                        Text('• $_recipient',
                            style: _text(12, color: AppTheme.textSecondary)),
                      if (style.badge != null)
                        _Badge(label: style.badge!, color: style.color),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: _kBorder),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectableText(
                      _message.isEmpty ? 'No message content.' : _message,
                      style: _text(14, height: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(_type);

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _kBorder),
      ),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(style.icon, size: 19, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _text(14, weight: FontWeight.w600),
                          ),
                        ),
                        if (style.badge != null) ...[
                          const SizedBox(width: 8),
                          _Badge(label: style.badge!, color: style.color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(_date,
                            style: _text(12, color: AppTheme.textSecondary)),
                        if (_recipient.isNotEmpty) ...[
                          Text(' • ',
                              style:
                                  _text(12, color: AppTheme.textSecondary)),
                          Expanded(
                            child: Text(
                              _recipient,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _text(12, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _text(13,
                            color: AppTheme.textSecondary, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: _text(11, weight: FontWeight.w600, color: color),
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
            Icon(icon,
                size: 40, color: AppTheme.textSecondary.withOpacity(0.6)),
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
// Member picker (bottom sheet on phones, dialog on tablets / desktop)
// ═════════════════════════════════════════════════════════════════════════

class _MemberPicker extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Set<String> initial;
  final bool asDialog;
  const _MemberPicker({
    required this.members,
    required this.initial,
    required this.asDialog,
  });

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
    final visible = _visible;
    final visibleIds = visible.map((m) => m['id'].toString()).toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selected.contains);

    return Column(
      children: [
        // Drag handle (sheet only)
        if (!widget.asDialog)
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
          padding: EdgeInsets.fromLTRB(20, widget.asDialog ? 12 : 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('Select members',
                    style: _text(17, weight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
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
                        _selected.isEmpty ? 'Done' : 'Done (${_selected.length})',
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
    );
  }
}
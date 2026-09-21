import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';

/// A full-screen picker that lets a member search for and select
/// up to [maxGuarantors] registered SACCO members as guarantors.
/// Returns a List<Map<String,dynamic>> of selected guarantor profiles.
class GuarantorPickerScreen extends StatefulWidget {
  final int maxGuarantors;
  final List<Map<String, dynamic>> alreadySelected;

  const GuarantorPickerScreen({
    super.key,
    this.maxGuarantors = 2,
    this.alreadySelected = const [],
  });

  @override
  State<GuarantorPickerScreen> createState() => _GuarantorPickerScreenState();
}

class _GuarantorPickerScreenState extends State<GuarantorPickerScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _selected = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.alreadySelected);
    _loadMembers();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final members = await FirebaseService.getAllMembersForGuarantor();
    final myUid = FirebaseService.sessionUid;
    // Exclude self
    final others = members.where((m) => m['uid'] != myUid).toList();
    if (mounted) {
      setState(() {
        _allMembers = others;
        _filtered = others;
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allMembers
          : _allMembers.where((m) {
              final name = (m['name'] as String? ?? '').toLowerCase();
              final phone = (m['phone'] as String? ?? '').toLowerCase();
              final membNo = (m['memberNumber'] as String? ?? '').toLowerCase();
              return name.contains(q) ||
                  phone.contains(q) ||
                  membNo.contains(q);
            }).toList();
    });
  }

  bool _isSelected(Map<String, dynamic> member) =>
      _selected.any((s) => s['uid'] == member['uid']);

  void _toggle(Map<String, dynamic> member) {
    setState(() {
      if (_isSelected(member)) {
        _selected.removeWhere((s) => s['uid'] == member['uid']);
      } else {
        if (_selected.length >= widget.maxGuarantors) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'You can select up to ${widget.maxGuarantors} guarantors.'),
            backgroundColor: AppTheme.warning,
          ));
          return;
        }
        _selected.add(member);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          'Select Guarantors (${_selected.length}/${widget.maxGuarantors})',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, _selected),
              child: Text(
                'Confirm',
                style: GoogleFonts.poppins(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, phone or member no.',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // ── Selected chips ───────────────────────────────────────────────
          if (_selected.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.accent.withOpacity(0.08),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _selected.map((m) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppTheme.accent,
                      child: Text(
                        (m['name'] as String? ?? '?')[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    label: Text(
                      m['name'] as String? ?? 'Member',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => _toggle(m),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: AppTheme.accent.withOpacity(0.4)),
                  );
                }).toList(),
              ),
            ),

          // ── Member list ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _filtered.isEmpty
                    ? const EmptyState(
                        message: 'No members found.',
                        icon: Icons.people_outline_rounded)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final m = _filtered[i];
                          final selected = _isSelected(m);
                          return _MemberTile(
                            member: m,
                            selected: selected,
                            onTap: () => _toggle(m),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  label:
                      'Confirm ${_selected.length} Guarantor${_selected.length > 1 ? 's' : ''}',
                  icon: Icons.check_circle_rounded,
                  onPressed: () => Navigator.pop(context, _selected),
                ),
              ),
            )
          : null,
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool selected;
  final VoidCallback onTap;

  const _MemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = member['name'] as String? ?? 'Member';
    final phone = member['phone'] as String? ?? '';
    final memberNo = member['memberNumber'] as String? ?? '';
    final idStatus = member['idStatus'] as String? ?? '';
    final isVerified = idStatus == 'approved';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withOpacity(0.5)
                : AppTheme.divider,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            size: 15, color: AppTheme.success),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  if (memberNo.isNotEmpty)
                    Text(
                      'Member #$memberNo',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                ],
              ),
            ),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.divider,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

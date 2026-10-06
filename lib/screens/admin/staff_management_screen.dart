import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/audit_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});
  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _roles = [
    AppConstants.roleMember,
    AppConstants.roleTeller,
    AppConstants.roleLoanOfficer,
    AppConstants.roleManager,
    AppConstants.roleAdmin,
    AppConstants.roleSuperAdmin,
  ];

  static const _roleLabels = {
    AppConstants.roleMember:      'Member',
    AppConstants.roleTeller:      'Teller',
    AppConstants.roleLoanOfficer: 'Loan Officer',
    AppConstants.roleManager:     'Manager',
    AppConstants.roleAdmin:       'Admin',
    AppConstants.roleSuperAdmin:  'Super Admin',
  };

  static const _roleColors = {
    AppConstants.roleMember:      Color(0xFF6B7A99),
    AppConstants.roleTeller:      Color(0xFF0D9488),
    AppConstants.roleLoanOfficer: Color(0xFF7C3AED),
    AppConstants.roleManager:     Color(0xFF0D2B6B),
    AppConstants.roleAdmin:       Color(0xFFF47920),
    AppConstants.roleSuperAdmin:  Color(0xFFDC2626),
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: (canPop || !isMobile) ? AppBar(
        title: const Text('Staff & Roles'),
        leading: canPop ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ) : null,
        automaticallyImplyLeading: canPop,
      ) : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.usersCol)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data?.docs ?? [];
          final filtered = _query.isEmpty
              ? all
              : all.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final q = _query.toLowerCase();
                  return (data['name'] as String? ?? '').toLowerCase().contains(q) ||
                      (data['phone'] as String? ?? '').toLowerCase().contains(q) ||
                      (data['role'] as String? ?? '').toLowerCase().contains(q);
                }).toList();

          // Count by role
          final roleCounts = <String, int>{};
          for (final d in all) {
            final role = (d.data() as Map<String, dynamic>)['role'] as String? ?? AppConstants.roleMember;
            roleCounts[role] = (roleCounts[role] ?? 0) + 1;
          }

          return Column(
            children: [
              // Search bar
              Container(
                color: AppTheme.primary,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(children: [
                  TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.poppins(color: Colors.white),
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or role…',
                      hintStyle: GoogleFonts.poppins(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
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
                  // Role summary chips
                  SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _roles.where((r) => (roleCounts[r] ?? 0) > 0).map((r) {
                        final color = _roleColors[r] ?? AppTheme.textSecondary;
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.5)),
                          ),
                          child: Text(
                            '${_roleLabels[r]}: ${roleCounts[r]}',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ]),
              ),

              // Member list
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(message: 'No users found.', icon: Icons.people_outline_rounded)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final doc  = filtered[i];
                          final data = doc.data() as Map<String, dynamic>;
                          return _StaffTile(
                            docId: doc.id,
                            data: data,
                            roles: _roles,
                            roleLabels: _roleLabels,
                            roleColors: _roleColors,
                            onRoleChanged: (newRole) => _changeRole(doc.id, data, newRole),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeRole(String docId, Map<String, dynamic> data, String newRole) async {
    final oldRole = data['role'] as String? ?? AppConstants.roleMember;
    if (oldRole == newRole) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Change Role', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Change ${data['name'] ?? 'this user'}\'s role from '
          '${_roleLabels[oldRole] ?? oldRole} to ${_roleLabels[newRole] ?? newRole}?',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('Confirm', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection(AppConstants.usersCol)
        .doc(docId)
        .update({'role': newRole});

    AuditService.log(
      action: 'ROLE_CHANGED',
      description: 'Role changed from $oldRole to $newRole',
      targetId: docId,
      targetName: data['name'] as String? ?? '',
      meta: {'oldRole': oldRole, 'newRole': newRole},
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Role updated to ${_roleLabels[newRole] ?? newRole}',
            style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

class _StaffTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final List<String> roles;
  final Map<String, String> roleLabels;
  final Map<String, Color> roleColors;
  final ValueChanged<String> onRoleChanged;

  const _StaffTile({
    required this.docId, required this.data,
    required this.roles, required this.roleLabels,
    required this.roleColors, required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final name    = data['name'] as String? ?? 'Member';
    final phone   = data['phone'] as String? ?? '';
    final role    = data['role'] as String? ?? AppConstants.roleMember;
    final imgUrl  = data['profileImage'] as String? ?? '';
    final color   = roleColors[role] ?? AppTheme.textSecondary;
    final isAdmin = role == AppConstants.roleAdmin || role == AppConstants.roleSuperAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isAdmin ? Border.all(color: color.withOpacity(0.4)) : Border.all(color: AppTheme.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.15),
            backgroundImage: imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
            child: imgUrl.isEmpty
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                    style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 16))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(phone, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
          ),
          // Role dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: roles.contains(role) ? role : AppConstants.roleMember,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down_rounded, color: color, size: 18),
                style: GoogleFonts.poppins(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                items: roles.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(roleLabels[r] ?? r,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: roleColors[r] ?? AppTheme.textSecondary,
                          fontWeight: FontWeight.w600)),
                )).toList(),
                onChanged: (v) { if (v != null) onRoleChanged(v); },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

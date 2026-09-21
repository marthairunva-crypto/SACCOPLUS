import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/audit_service.dart';
import '../../widgets/app_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MEMBER MANAGEMENT + KYC VERIFICATION
// ═══════════════════════════════════════════════════════════════════════════

class FarmerManagementScreen extends StatefulWidget {
  final bool embedded;
  const FarmerManagementScreen({super.key, this.embedded = false});
  @override
  State<FarmerManagementScreen> createState() => _FarmerManagementScreenState();
}

class _FarmerManagementScreenState extends State<FarmerManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _name(Map<String, dynamic> d) =>
      (d['name'] as String? ?? d['fullName'] as String? ?? '').trim();

  List<QueryDocumentSnapshot> _filter(
      List<QueryDocumentSnapshot> docs, String? idStatusFilter) {
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      if (idStatusFilter != null) {
        if ((data['idStatus'] as String? ?? '') != idStatusFilter) return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return _name(data).toLowerCase().contains(q) ||
          (data['phone'] as String? ?? '').toLowerCase().contains(q) ||
          (data['village'] as String? ?? '').toLowerCase().contains(q) ||
          (data['memberNumber'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Member Management'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'KYC Pending'),
            Tab(text: 'Verified'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getAllFarmers(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          final all = snap.data?.docs ?? [];
          final pending = all.where((d) =>
              (d.data() as Map<String, dynamic>)['idStatus'] == 'pending').length;
          final verified = all.where((d) =>
              (d.data() as Map<String, dynamic>)['idStatus'] == 'approved').length;

          return Column(
            children: [
              // Search + stats
              Container(
                color: AppTheme.primary,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      style: GoogleFonts.poppins(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search name, phone, location…',
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
                    Row(children: [
                      _pill('Total', '${all.length}', Colors.white),
                      const SizedBox(width: 8),
                      _pill('KYC Pending', '$pending', AppTheme.warning),
                      const SizedBox(width: 8),
                      _pill('Verified', '$verified', AppTheme.success),
                    ]),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _MemberList(docs: _filter(all, null), onTap: _open),
                    _MemberList(docs: _filter(all, 'pending'), onTap: _open,
                        emptyMsg: 'No pending KYC verifications.'),
                    _MemberList(docs: _filter(all, 'approved'), onTap: _open,
                        emptyMsg: 'No verified members yet.'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pill(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text('$label: $value',
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
  );

  void _open(String docId, Map<String, dynamic> data) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MemberDetailScreen(docId: docId, initialData: data)));
  }
}

// ─── Member List ──────────────────────────────────────────────────────────────
class _MemberList extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final void Function(String docId, Map<String, dynamic> data) onTap;
  final String emptyMsg;

  const _MemberList({
    required this.docs,
    required this.onTap,
    this.emptyMsg = 'No members found.',
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return EmptyState(message: emptyMsg, icon: Icons.people_outline_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] as String? ?? data['fullName'] as String? ?? 'Member').trim();
        final phone = data['phone'] as String? ?? '';
        final village = data['village'] as String? ?? '';
        final idStatus = data['idStatus'] as String? ?? '';
        final profileImage = data['profileImage'] as String? ?? '';
        final memberNo = data['memberNumber'] as String? ?? '';

        Color statusColor;
        IconData statusIcon;
        String statusLabel;
        switch (idStatus) {
          case 'approved':
            statusColor = AppTheme.success;
            statusIcon = Icons.verified_rounded;
            statusLabel = 'Verified';
            break;
          case 'pending':
            statusColor = AppTheme.warning;
            statusIcon = Icons.schedule_rounded;
            statusLabel = 'KYC Pending';
            break;
          case 'rejected':
            statusColor = AppTheme.error;
            statusIcon = Icons.cancel_rounded;
            statusLabel = 'Rejected';
            break;
          default:
            statusColor = AppTheme.textSecondary;
            statusIcon = Icons.person_outline_rounded;
            statusLabel = 'No KYC';
        }

        return GestureDetector(
          onTap: () => onTap(doc.id, data),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: idStatus == 'pending'
                  ? Border.all(color: AppTheme.warning.withOpacity(0.4))
                  : Border.all(color: AppTheme.divider),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  backgroundImage: profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                  child: profileImage.isEmpty
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                          style: GoogleFonts.poppins(
                              color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 18))
                      : null,
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        [if (phone.isNotEmpty) phone, if (village.isNotEmpty) village]
                            .join('  •  '),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      if (memberNo.isNotEmpty)
                        Text('Member #$memberNo',
                            style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // KYC badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Member Detail Screen (Full KYC) ─────────────────────────────────────────
class MemberDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initialData;

  const MemberDetailScreen({super.key, required this.docId, required this.initialData});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  bool _updating = false;
  final fmt = NumberFormat('#,###', 'en_US');

  Future<void> _updateKyc(String status, {String? note}) async {
    setState(() => _updating = true);
    try {
      await FirebaseService.updateIdVerificationStatus(widget.docId, status);
      AuditService.log(
        action: status == 'approved' ? AuditService.kKycApproved : AuditService.kKycRejected,
        description: 'KYC ${status} for member',
        targetId: widget.docId,
        targetName: widget.initialData['name'] as String? ?? '',
        meta: note != null ? {'note': note} : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved'
              ? 'KYC approved. Member notified via SMS.'
              : 'KYC rejected. Member notified via SMS.'),
          backgroundColor: status == 'approved' ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _showRejectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Reject KYC',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason (optional). The member will be notified via SMS.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. ID image is blurry, please resubmit',
                hintStyle: GoogleFonts.poppins(fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateKyc('rejected', note: ctrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseService.getUserProfileStream(widget.docId),
        builder: (context, snap) {
          final f = (snap.hasData && snap.data!.exists)
              ? snap.data!.data() as Map<String, dynamic>
              : widget.initialData;

          final name = (f['name'] as String? ?? f['fullName'] as String? ?? 'Member').trim();
          final phone = f['phone'] as String? ?? '—';
          final village = f['village'] as String? ?? '—';
          final occupation = f['occupation'] as String? ?? f['district'] as String? ?? '—';
          final memberType = f['memberType'] as String? ?? f['farmType'] as String? ?? '—';
          final nextOfKin = f['nextOfKin'] as String? ?? '—';
          final memberStatus = f['memberStatus'] as String? ?? 'Active';
          final memberNo = f['memberNumber'] as String? ?? '—';
          final idStatus = f['idStatus'] as String? ?? '';
          final idType = f['idType'] as String? ?? '—';
          final frontUrl = f['idFrontUrl'] as String? ?? '';
          final backUrl = f['idBackUrl'] as String? ?? '';
          final profileImage = f['profileImage'] as String? ?? '';
          final createdAt = f['createdAt'];
          String joinDate = '—';
          if (createdAt is String && createdAt.isNotEmpty) {
            try {
              joinDate = DateFormat('MMM d, yyyy').format(DateTime.parse(createdAt));
            } catch (_) {}
          }

          // KYC status styling
          Color kycColor;
          IconData kycIcon;
          String kycLabel;
          switch (idStatus) {
            case 'approved':
              kycColor = AppTheme.success; kycIcon = Icons.verified_rounded; kycLabel = 'KYC VERIFIED';
              break;
            case 'pending':
              kycColor = AppTheme.warning; kycIcon = Icons.schedule_rounded; kycLabel = 'KYC PENDING';
              break;
            case 'rejected':
              kycColor = AppTheme.error; kycIcon = Icons.cancel_rounded; kycLabel = 'KYC REJECTED';
              break;
            default:
              kycColor = AppTheme.textSecondary; kycIcon = Icons.help_outline_rounded; kycLabel = 'NOT SUBMITTED';
          }

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppTheme.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  // KYC status badge in app bar
                  Container(
                    margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kycColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kycColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(kycIcon, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(kycLabel,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryDark, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Profile photo
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: profileImage.isNotEmpty
                                    ? NetworkImage(profileImage) : null,
                                child: profileImage.isEmpty
                                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 32))
                                    : null,
                              ),
                              if (idStatus == 'approved')
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: AppTheme.success, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(name,
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(phone,
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                          if (memberNo != '—')
                            Text('Member #$memberNo',
                                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Personal Info ──────────────────────────────────
                      _section('Personal Information'),
                      _infoCard([
                        _row(Icons.phone_outlined, 'Phone', phone),
                        _row(Icons.location_on_outlined, 'Village / Location', village),
                        _row(Icons.work_outline_rounded, 'Occupation', occupation),
                        _row(Icons.people_outline_rounded, 'Next of Kin', nextOfKin),
                        _row(Icons.calendar_today_outlined, 'Joined', joinDate),
                      ]),

                      const SizedBox(height: 16),

                      // ── Membership ─────────────────────────────────────
                      _section('Membership'),
                      _infoCard([
                        _row(Icons.badge_outlined, 'Member Number', memberNo),
                        _row(Icons.category_outlined, 'Member Type', memberType),
                        _row(Icons.verified_user_outlined, 'Account Status', memberStatus),
                      ]),

                      const SizedBox(height: 16),

                      // ── KYC / ID Verification ──────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _section('KYC / ID Verification', noBottom: true),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kycColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kycColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(kycIcon, size: 12, color: kycColor),
                                const SizedBox(width: 4),
                                Text(kycLabel,
                                    style: GoogleFonts.poppins(
                                        fontSize: 10, color: kycColor, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (idStatus.isEmpty && frontUrl.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('This member has not submitted ID documents yet.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: AppTheme.textSecondary)),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        _infoCard([
                          _row(Icons.badge_outlined, 'ID Type', idType),
                        ]),
                        const SizedBox(height: 12),

                        // ID images — full width, zoomable
                        if (frontUrl.isNotEmpty || backUrl.isNotEmpty) ...[
                          Text('ID Documents',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (frontUrl.isNotEmpty)
                                Expanded(child: _idImage('Front', frontUrl)),
                              if (frontUrl.isNotEmpty && backUrl.isNotEmpty)
                                const SizedBox(width: 10),
                              if (backUrl.isNotEmpty)
                                Expanded(child: _idImage('Back', backUrl)),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── KYC Action Buttons ─────────────────────────
                        if (_updating)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: AppTheme.primary),
                          ))
                        else if (idStatus == 'pending') ...[
                          // Prominent approve/reject for pending
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.pending_actions_rounded,
                                      color: AppTheme.warning, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Action Required',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14, color: AppTheme.warning)),
                                ]),
                                const SizedBox(height: 6),
                                Text('Review the ID documents above and approve or reject this member\'s KYC.',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(height: 14),
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _showRejectDialog,
                                      icon: const Icon(Icons.close_rounded, size: 16),
                                      label: const Text('Reject'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                        side: const BorderSide(color: AppTheme.error),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _updateKyc('approved'),
                                      icon: const Icon(Icons.verified_rounded, size: 16),
                                      label: const Text('Approve KYC'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.success,
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ] else if (idStatus == 'approved') ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.verified_rounded, color: AppTheme.success, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('KYC Approved',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700, color: AppTheme.success)),
                                  Text('This member is fully verified and can apply for loans.',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: AppTheme.textSecondary)),
                                ]),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _showRejectDialog,
                            icon: const Icon(Icons.undo_rounded, size: 16),
                            label: const Text('Revoke KYC Approval'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ] else if (idStatus == 'rejected') ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('KYC Rejected',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700, color: AppTheme.error)),
                                  Text('Member has been notified to resubmit documents.',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: AppTheme.textSecondary)),
                                ]),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _updateKyc('approved'),
                            icon: const Icon(Icons.verified_rounded, size: 16),
                            label: const Text('Approve Anyway'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, {bool noBottom = false}) => Padding(
    padding: EdgeInsets.only(bottom: noBottom ? 0 : 8),
    child: Text(title,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
  );

  Widget _infoCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.divider),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(children: rows),
  );

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppTheme.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        ]),
      ),
    ]),
  );

  Widget _idImage(String label, String url) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => _ImageViewerScreen(title: label, url: url))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36)),
                  ),
                ),
              ),
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Full-screen Image Viewer ─────────────────────────────────────────────────
class _ImageViewerScreen extends StatelessWidget {
  final String title;
  final String url;
  const _ImageViewerScreen({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

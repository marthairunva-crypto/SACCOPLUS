import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';
import '../auth/professional_login_screen.dart';
import '../common/about_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const ProfileScreen({super.key, this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    // Pre-load profile into _profile so StreamBuilder has initial data
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = FirebaseService.sessionUid;
      if (uid.isNotEmpty) {
        final p = await FirebaseService.getUserProfile(uid);
        if (mounted) setState(() => _profile = p);
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await FirebaseService.uploadImageBytesToImgbb(bytes);
      if (url != null) {
        await FirebaseService.updateUserProfile({'profileImage': url});
        if (mounted) setState(() => _profile?['profileImage'] = url);
      }
    } catch (_) {}
    if (mounted) setState(() => _uploading = false);
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _profile?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: _profile?['phone'] ?? '');
    final villageCtrl = TextEditingController(text: _profile?['village'] ?? '');
    final farmSizeCtrl = TextEditingController(text: _profile?['farmSize']?.toString() ?? '');
    final cropCtrl = TextEditingController(text: _profile?['mainCrop'] ?? '');
    String farmType = _profile?['farmType'] ?? 'Crops';
    bool saving = false;

    // Pre-populate dateOfBirth from profile
    DateTime? dobValue;
    final dobStr = _profile?['dateOfBirth'] as String?;
    if (dobStr != null && dobStr.isNotEmpty) {
      try { dobValue = DateTime.parse(dobStr); } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Edit Profile',
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 16),
                _editField(nameCtrl, 'Full Name', Icons.person_outline),
                const SizedBox(height: 12),
                _editField(phoneCtrl, 'Phone', Icons.phone_outlined,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                _editField(villageCtrl, 'Village / Sub-county',
                    Icons.location_on_outlined),
                const SizedBox(height: 12),
                _editField(farmSizeCtrl, 'Farm Size (acres)',
                    Icons.landscape_outlined,
                    type: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: farmType,
                  decoration: const InputDecoration(
                    labelText: 'Farm Type',
                    prefixIcon: Icon(Icons.agriculture_outlined),
                  ),
                  items: ['Crops', 'Livestock', 'Mixed']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setModal(() => farmType = v!),
                ),
                const SizedBox(height: 12),
                _editField(cropCtrl, 'Main Crop(s) / Livestock',
                    Icons.grass_outlined),
                const SizedBox(height: 12),
                // ─── Date of Birth ──────────────────────────────────────────
                _ProfileDobPicker(
                  value: dobValue,
                  onChanged: (d) => setModal(() => dobValue = d),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setModal(() => saving = true);
                            try {
                              await FirebaseService.updateUserProfile({
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'village': villageCtrl.text.trim(),
                                'farmSize': farmSizeCtrl.text.trim(),
                                'farmType': farmType,
                                'mainCrop': cropCtrl.text.trim(),
                                if (dobValue != null)
                                  'dateOfBirth': dobValue!.toIso8601String(),
                              });
                              if (mounted) {
                                setState(() {
                                  _profile?['name'] = nameCtrl.text.trim();
                                  _profile?['phone'] = phoneCtrl.text.trim();
                                  _profile?['village'] = villageCtrl.text.trim();
                                  _profile?['farmSize'] = farmSizeCtrl.text.trim();
                                  _profile?['farmType'] = farmType;
                                  _profile?['mainCrop'] = cropCtrl.text.trim();
                                  if (dobValue != null) {
                                    _profile?['dateOfBirth'] = dobValue!.toIso8601String();
                                  }
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                            } catch (_) {
                              setModal(() => saving = false);
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Save Changes',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  void _showIdVerification() {
    XFile? frontFile;
    XFile? backFile;
    String idType = 'National ID';
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('ID Verification',
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Upload a clear photo of the front and back of your ID. '
                  'Your application will be reviewed within 24 hours.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: idType,
                  decoration: const InputDecoration(
                    labelText: 'ID Type',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: ['National ID', 'Driving Permit', 'Passport']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setModal(() => idType = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _idImagePicker(
                        label: 'Front Side',
                        xfile: frontFile,
                        onPick: () async {
                          final f = await _pickIdImage();
                          if (f != null) setModal(() => frontFile = f);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _idImagePicker(
                        label: 'Back Side',
                        xfile: backFile,
                        onPick: () async {
                          final f = await _pickIdImage();
                          if (f != null) setModal(() => backFile = f);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (uploading || frontFile == null || backFile == null)
                        ? null
                        : () async {
                            setModal(() => uploading = true);
                            try {
                              final frontBytes = await frontFile!.readAsBytes();
                              final backBytes = await backFile!.readAsBytes();
                              await FirebaseService.submitIdVerificationBytes(
                                frontBytes: frontBytes,
                                backBytes: backBytes,
                                idType: idType,
                              );
                              if (mounted) {
                                setState(() {
                                  _profile?['idStatus'] = 'pending';
                                  _profile?['idType'] = idType;
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'ID submitted for verification. You will be notified once approved.'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                            } catch (_) {
                              setModal(() => uploading = false);
                            }
                          },
                    child: uploading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text('Submit for Verification',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<XFile?> _pickIdImage() async {
    final picker = ImagePicker();
    return picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
  }

  Widget _idImagePicker({
    required String label,
    required XFile? xfile,
    required VoidCallback onPick,
  }) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: xfile != null
                ? AppTheme.success
                : AppTheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: xfile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: FutureBuilder<Uint8List>(
                  future: xfile.readAsBytes(),
                  builder: (_, snap) => snap.hasData
                      ? Image.memory(snap.data!, fit: BoxFit.cover,
                          width: double.infinity)
                      : const Center(child: CircularProgressIndicator()),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseService.sessionUid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseService.getUserProfileStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && _profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          );
        }
        // Keep local state in sync with Firestore
        if (snap.hasData && snap.data!.exists) {
          _profile = snap.data!.data() as Map<String, dynamic>?;
        }
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final profile = _profile ?? {};
    final name = profile['name'] ?? 'Member';
    final email = profile['email'] ?? '—';
    final phone = profile['phone'] ?? '—';
    final village = profile['village'] ?? '—';
    final occupation = profile['occupation'] ?? profile['farmType'] ?? '—';
    final memberType = profile['memberType'] ?? profile['farmType'] ?? '—';
    final nextOfKin = profile['nextOfKin'] ?? '—';
    final memberStatus = profile['memberStatus'] ?? 'Active';
    final imageUrl = profile['profileImage'] as String?;
    final idStatus = profile['idStatus'] as String?;
    final idType = profile['idType'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppTheme.primary,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                tooltip: 'Edit Profile',
                onPressed: _showEditProfile,
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () => _confirmLogout(context),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.white24,
                            backgroundImage: (imageUrl != null &&
                                    imageUrl.isNotEmpty)
                                ? NetworkImage(imageUrl)
                                : null,
                            child: (imageUrl == null || imageUrl.isEmpty)
                                ? const Icon(Icons.person_rounded,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                          if (_uploading)
                            const Positioned.fill(
                              child: CircleAvatar(
                                backgroundColor: Colors.black38,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(name,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                    Text((profile['role'] as String? ?? AppConstants.roleMember).toUpperCase(),
                        style: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 11,
                            letterSpacing: 1.2)),
                  ],
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
                  _section('Personal Information', [
                    InfoRow(icon: Icons.person_outline, label: 'Full Name', value: name),
                    InfoRow(icon: Icons.email_outlined, label: 'Email', value: email),
                    InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
                    InfoRow(icon: Icons.location_on_outlined, label: 'Location', value: village),
                    InfoRow(icon: Icons.work_outline_rounded, label: 'Occupation', value: occupation),
                    InfoRow(icon: Icons.people_outline_rounded, label: 'Next of Kin', value: nextOfKin),
                  ]),
                  const SizedBox(height: 16),
                  _section('Membership Details', [
                    InfoRow(icon: Icons.badge_outlined, label: 'Member Type', value: memberType),
                    InfoRow(icon: Icons.verified_user_outlined, label: 'Status', value: memberStatus),
                  ]),
                  const SizedBox(height: 16),

                  // ── ID Verification card ──────────────────────────────
                  _idVerificationCard(idStatus, idType),

                  const SizedBox(height: 16),

                  _menuTile(Icons.edit_rounded, 'Edit Profile', _showEditProfile),
                  _menuTile(Icons.info_outline_rounded, 'About App', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()));
                  }),
                  _menuTile(Icons.logout_rounded, 'Sign Out',
                      () => _confirmLogout(context),
                      color: AppTheme.error),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idVerificationCard(String? idStatus, String? idType) {
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
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'Under Review';
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected — Resubmit';
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.badge_outlined;
        statusLabel = 'Not Submitted';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ID Verification',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.primary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          if (idType != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Type: $idType',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
          Text(
          idStatus == 'approved'
                ? 'Your identity has been verified. You can apply for loans.'
                : idStatus == 'pending'
                    ? 'Your ID is under review. Loan applications will be enabled once verified.'
                    : 'You must verify your identity before applying for a loan. Upload the front and back of your National ID, Driving Permit, or Passport.',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (idStatus != 'approved') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showIdVerification,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: Text(
                  idStatus == 'pending'
                      ? 'Resubmit ID'
                      : 'Upload ID Documents',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.primary)),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: Icon(icon, color: color ?? AppTheme.primary),
          title: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: color ?? AppTheme.textPrimary,
                  fontWeight: FontWeight.w500)),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseService.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfessionalLoginScreen()),
                  (r) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─── Date of Birth Picker (reusable inside profile modal) ────────────────────
class _ProfileDobPicker extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _ProfileDobPicker({required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 10, now.month, now.day),
      helpText: 'Select Date of Birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = value != null
        ? '${value!.day.toString().padLeft(2, '0')}/'
            '${value!.month.toString().padLeft(2, '0')}/'
            '${value!.year}'
        : 'Date of Birth (tap to set)';
    return GestureDetector(
      onTap: () => _pick(context),
      child: AbsorbPointer(
        child: TextField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.cake_outlined),
            suffixIcon: value != null
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => onChanged(null),
                  )
                : const Icon(Icons.calendar_today_outlined, size: 18),
          ),
        ),
      ),
    );
  }
}

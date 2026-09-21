/// Platform Super Admin — manage all SACCOs on the SACCOPLUS platform.
///
/// Only accessible to users with role = 'super_admin'.
/// Regular SACCO admins never reach this screen.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/sacco_profile.dart';
import '../../core/sacco_service.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';
import 'admin_dashboard.dart';

class PlatformAdminScreen extends StatefulWidget {
  const PlatformAdminScreen({super.key});

  @override
  State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
  List<SaccoProfile> _saccos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await SaccoService.listAllSaccos();
    if (mounted) setState(() { _saccos = list; _loading = false; });
  }

  // ── Enter a SACCO as its admin ────────────────────────────────────────────
  Future<void> _enterSacco(SaccoProfile sacco) async {
    await SaccoService.loadById(sacco.tenantId);
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()));
  }

  // ── Create new SACCO ──────────────────────────────────────────────────────
  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSaccoSheet(onCreated: (tenantId) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('SACCO created! ID: $tenantId',
              style: GoogleFonts.poppins()),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
      }),
    );
  }

  // ── Toggle active / inactive ──────────────────────────────────────────────
  Future<void> _toggleStatus(SaccoProfile s) async {
    final newStatus = s.status == 'active' ? 'inactive' : 'active';
    await SaccoService.setSaccoStatus(s.tenantId, newStatus);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SACCOPLUS Platform',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text('Super Admin — Manage all SACCOs',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () async {
              SaccoService.clear();
              await FirebaseService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: Text('New SACCO',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _saccos.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No SACCOs yet',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('Tap "+ New SACCO" to onboard the first SACCO.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );

  Widget _buildList() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _saccos.length,
        itemBuilder: (_, i) => _SaccoCard(
          sacco: _saccos[i],
          onEnter: () => _enterSacco(_saccos[i]),
          onToggle: () => _toggleStatus(_saccos[i]),
          onEdit: () => _showEditSheet(_saccos[i]),
        ),
      );

  void _showEditSheet(SaccoProfile s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSaccoSheet(
        sacco: s,
        onSaved: (_) => _load(),
      ),
    );
  }
}

// ─── SACCO Card ────────────────────────────────────────────────────────────────

class _SaccoCard extends StatelessWidget {
  final SaccoProfile sacco;
  final VoidCallback onEnter;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _SaccoCard({
    required this.sacco,
    required this.onEnter,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = sacco.status == 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                // Brand color dot + logo placeholder
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: sacco.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: sacco.logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(sacco.logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.business_rounded,
                                      color: sacco.primaryColor, size: 24)))
                      : Icon(Icons.business_rounded,
                          color: sacco.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sacco.saccoName,
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      if (sacco.registrationNo.isNotEmpty)
                        Text('Reg: ${sacco.registrationNo}',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.success.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppTheme.success
                            : Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),

          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _infoChip(Icons.tag_rounded,
                    sacco.tenantId, Colors.grey.shade400),
                const SizedBox(width: 8),
                _infoChip(Icons.public_rounded,
                    '${sacco.country} · ${sacco.currency}',
                    sacco.primaryColor),
              ],
            ),
          ),

          const Divider(height: 1),

          // Action buttons
          Row(
            children: [
              _actionBtn(Icons.open_in_new_rounded, 'Enter', AppTheme.primary,
                  onEnter),
              _dividerV(),
              _actionBtn(Icons.edit_rounded, 'Edit', AppTheme.info, onEdit),
              _dividerV(),
              _actionBtn(
                isActive
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                isActive ? 'Deactivate' : 'Activate',
                isActive ? AppTheme.warning : AppTheme.success,
                onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );

  Widget _actionBtn(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 3),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
        ),
      );

  Widget _dividerV() => Container(
      width: 1, height: 40, color: const Color(0xFFE4E8F0));
}

// ─── Create SACCO sheet ────────────────────────────────────────────────────────

class _CreateSaccoSheet extends StatefulWidget {
  final ValueChanged<String> onCreated;
  const _CreateSaccoSheet({required this.onCreated});

  @override
  State<_CreateSaccoSheet> createState() => _CreateSaccoSheetState();
}

class _CreateSaccoSheetState extends State<_CreateSaccoSheet> {
  final _nameCtrl    = TextEditingController();
  final _shortCtrl   = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _regCtrl     = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _adminNameCtrl  = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();

  String _country  = 'UG';
  String _currency = 'UGX';
  bool   _creating = false;
  XFile? _logoImageFile;  // Use XFile for web compatibility
  bool _uploadingLogo = false;

  static const _countries = [
    {'code': 'UG', 'name': 'Uganda', 'currency': 'UGX'},
    {'code': 'KE', 'name': 'Kenya', 'currency': 'KES'},
    {'code': 'RW', 'name': 'Rwanda', 'currency': 'RWF'},
    {'code': 'CD', 'name': 'DR Congo', 'currency': 'CDF'},
    {'code': 'ZM', 'name': 'Zambia', 'currency': 'ZMW'},
    {'code': 'TZ', 'name': 'Tanzania', 'currency': 'TZS'},
  ];

  @override
  void dispose() {
    for (final c in [_nameCtrl, _shortCtrl, _taglineCtrl, _regCtrl,
        _phoneCtrl, _emailCtrl, _addressCtrl,
        _adminNameCtrl, _adminPhoneCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _logoImageFile = pickedFile);
      }
    } catch (e) {
      _snack('Error picking image: $e', AppTheme.error);
    }
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('SACCO name is required', AppTheme.error);
      return;
    }
    setState(() => _creating = true);
    try {
      // Upload logo if selected
      String logoUrl = '';
      if (_logoImageFile != null) {
        setState(() => _uploadingLogo = true);
        if (kIsWeb) {
          // Web: read bytes and upload
          final bytes = await _logoImageFile!.readAsBytes();
          logoUrl = await FirebaseService.uploadImageBytesToImgbb(
                  bytes, _logoImageFile!.name) ??
              '';
        } else {
          // Mobile: use File path
          logoUrl = await FirebaseService.uploadImageToImgbb(
                  File(_logoImageFile!.path)) ??
              '';
        }
        setState(() => _uploadingLogo = false);
      }

      final tenantId = await SaccoService.createSacco(
        saccoName:      _nameCtrl.text.trim(),
        shortName:      _shortCtrl.text.trim(),
        tagline:        _taglineCtrl.text.trim(),
        registrationNo: _regCtrl.text.trim(),
        phone:          _phoneCtrl.text.trim(),
        email:          _emailCtrl.text.trim(),
        address:        _addressCtrl.text.trim(),
        country:        _country,
        currency:       _currency,
      );

      // Update logo URL if uploaded
      if (logoUrl.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('saccoplus-saccos')
            .doc(tenantId)
            .update({'logoUrl': logoUrl});
      }

      // Create SACCO admin if phone provided
      if (_adminPhoneCtrl.text.trim().isNotEmpty) {
        final adminPhone = FirebaseService.formatPhone(
            _adminPhoneCtrl.text.trim());
        await SaccoService.createSaccoAdmin(
          saccoTenantId: tenantId,
          name:  _adminNameCtrl.text.trim().isNotEmpty
              ? _adminNameCtrl.text.trim()
              : 'Admin',
          phone: adminPhone,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(tenantId);
      }
    } catch (e) {
      _snack('Error: ${e.toString().replaceAll('Exception: ', '')}',
          AppTheme.error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Text('Create New SACCO',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  _section('SACCO Information'),
                  _field(_nameCtrl, 'SACCO Name *', Icons.business_rounded),
                  _field(_shortCtrl, 'Short Name (e.g. MUS)',
                      Icons.short_text_rounded),
                  _field(_taglineCtrl, 'Tagline / Motto',
                      Icons.format_quote_rounded),
                  _field(_regCtrl, 'Registration Number',
                      Icons.badge_outlined),

                  const SizedBox(height: 8),
                  _section('Logo (Optional)'),
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4E8F0)),
                      ),
                      child: _logoImageFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('Tap to upload logo',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(_logoImageFile!.path,
                                      fit: BoxFit.contain)
                                  : Image.file(File(_logoImageFile!.path),
                                      fit: BoxFit.contain)),
                    ),
                  ),
                  if (_uploadingLogo)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('Uploading logo...',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppTheme.info)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  _field(_phoneCtrl, 'Phone', Icons.phone_rounded,
                      type: TextInputType.phone),
                  _field(_emailCtrl, 'Email', Icons.email_outlined,
                      type: TextInputType.emailAddress),
                  _field(_addressCtrl, 'Address', Icons.location_on_outlined),

                  const SizedBox(height: 8),
                  _section('Country & Currency'),
                  DropdownButtonFormField<String>(
                    value: _country,
                    decoration: const InputDecoration(
                        labelText: 'Country',
                        prefixIcon: Icon(Icons.public_rounded)),
                    items: _countries.map((c) => DropdownMenuItem(
                      value: c['code'],
                      child: Text('${c['name']} (${c['currency']})'),
                    )).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final c = _countries.firstWhere(
                          (x) => x['code'] == v);
                      setState(() {
                        _country  = v;
                        _currency = c['currency']!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  _section('SACCO Admin (optional)'),
                  Text(
                    'Create the first admin for this SACCO. '
                    'They will need to set a PIN on first login.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _field(_adminNameCtrl, 'Admin Full Name',
                      Icons.person_rounded),
                  _field(_adminPhoneCtrl, 'Admin Phone (07XX…)',
                      Icons.phone_android_rounded,
                      type: TextInputType.phone),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creating ? null : _create,
                      icon: _creating
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: Text(_creating
                          ? 'Creating...' : 'Create SACCO',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: AppTheme.primary, letterSpacing: 0.3)),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon)),
        ),
      );
}

// ─── Edit SACCO sheet ──────────────────────────────────────────────────────────

class _EditSaccoSheet extends StatefulWidget {
  final SaccoProfile sacco;
  final ValueChanged<SaccoProfile> onSaved;
  const _EditSaccoSheet({required this.sacco, required this.onSaved});

  @override
  State<_EditSaccoSheet> createState() => _EditSaccoSheetState();
}

class _EditSaccoSheetState extends State<_EditSaccoSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _regCtrl;
  bool _saving = false;
  XFile? _logoImageFile;  // Use XFile for web compatibility
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.sacco.saccoName);
    _taglineCtrl = TextEditingController(text: widget.sacco.tagline);
    _phoneCtrl   = TextEditingController(text: widget.sacco.phone);
    _emailCtrl   = TextEditingController(text: widget.sacco.email);
    _addressCtrl = TextEditingController(text: widget.sacco.address);
    _regCtrl     = TextEditingController(text: widget.sacco.registrationNo);
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _taglineCtrl, _phoneCtrl,
        _emailCtrl, _addressCtrl, _regCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _logoImageFile = pickedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      // Upload logo if a new one was selected
      String? newLogoUrl;
      if (_logoImageFile != null) {
        setState(() => _uploadingLogo = true);
        if (kIsWeb) {
          final bytes = await _logoImageFile!.readAsBytes();
          newLogoUrl = await FirebaseService.uploadImageBytesToImgbb(
              bytes, _logoImageFile!.name);
        } else {
          newLogoUrl = await FirebaseService.uploadImageToImgbb(
              File(_logoImageFile!.path));
        }
        setState(() => _uploadingLogo = false);
      }

      final updated = widget.sacco.copyWith(
        saccoName:      _nameCtrl.text.trim(),
        tagline:        _taglineCtrl.text.trim(),
        phone:          _phoneCtrl.text.trim(),
        email:          _emailCtrl.text.trim(),
        address:        _addressCtrl.text.trim(),
        registrationNo: _regCtrl.text.trim(),
      );

      // Update in Firestore
      final updateData = updated.toMap();
      if (newLogoUrl != null && newLogoUrl.isNotEmpty) {
        updateData['logoUrl'] = newLogoUrl;
      }

      await FirebaseFirestore.instance
          .collection('saccoplus-saccos')
          .doc(updated.tenantId)
          .set(updateData, SetOptions(merge: true));
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(updated);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 12),
            Text('Edit ${widget.sacco.saccoName}',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            
            // Logo upload
            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E8F0)),
                ),
                child: _logoImageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(_logoImageFile!.path,
                                fit: BoxFit.contain)
                            : Image.file(File(_logoImageFile!.path),
                                fit: BoxFit.contain))
                    : widget.sacco.logoUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(widget.sacco.logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded,
                                            size: 32, color: Colors.grey.shade400),
                                        const SizedBox(height: 4),
                                        Text('Tap to change logo',
                                            style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: AppTheme.textSecondary)),
                                      ],
                                    )))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  size: 32, color: Colors.grey.shade400),
                              const SizedBox(height: 4),
                              Text('Tap to upload logo',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary)),
                            ],
                          ),
              ),
            ),
            if (_uploadingLogo)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Uploading...',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppTheme.info)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            
            _f(_nameCtrl,    'SACCO Name',       Icons.business_rounded),
            _f(_taglineCtrl, 'Tagline',          Icons.format_quote_rounded),
            _f(_regCtrl,     'Reg Number',       Icons.badge_outlined),
            _f(_phoneCtrl,   'Phone',            Icons.phone_rounded),
            _f(_emailCtrl,   'Email',            Icons.email_outlined),
            _f(_addressCtrl, 'Address',          Icons.location_on_outlined),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(_saving ? 'Saving…' : 'Save Changes',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _f(TextEditingController c, String label, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
              labelText: label, prefixIcon: Icon(icon)),
        ),
      );
}

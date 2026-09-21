/// SaccoService — tenant management for the SACCOPLUS multi-SACCO platform.
///
/// One codebase → many SACCOs → separate data → dynamic branding.
///
/// Usage:
///   await SaccoService.loadForUser(userProfile);   // after login
///   SaccoService.current.saccoName                 // anywhere in app
///   SaccoService.tenantId                          // for Firestore queries

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';
import 'sacco_profile.dart';

class SaccoService {
  SaccoService._();

  static final _db = FirebaseFirestore.instance;

  // ── Session state ──────────────────────────────────────────────────────────
  static SaccoProfile _current = SaccoProfile.defaultSacco;

  static SaccoProfile get current  => _current;
  static String       get tenantId => _current.tenantId;

  // ── Load at login ──────────────────────────────────────────────────────────

  /// Call after successful PIN login. Reads tenantId from userProfile,
  /// loads the matching SACCO config, falls back to sacco_001 if absent.
  static Future<void> loadForUser(Map<String, dynamic> userProfile) async {
    final tid = userProfile['tenantId'] as String? ?? 'sacco_001';
    await loadById(tid);
  }

  /// Load a SACCO by tenantId and set it as the session SACCO.
  static Future<SaccoProfile> loadById(String tid) async {
    // 1. Try the direct tenantId doc
    try {
      final doc = await _db
          .collection(AppConstants.saccoCol)
          .doc(tid)
          .get(const GetOptions(source: Source.server));
      if (doc.exists) {
        _current = SaccoProfile.fromMap({...doc.data()!, 'tenantId': tid});
        return _current;
      }
    } catch (_) {}

    // 2. Fall back to legacy 'config' doc (existing single-SACCO data)
    try {
      final cfg = await _db
          .collection(AppConstants.saccoCol)
          .doc('config')
          .get(const GetOptions(source: Source.server));
      if (cfg.exists) {
        _current = SaccoProfile.fromMap({...cfg.data()!, 'tenantId': tid});
        // Silently migrate to the proper tenantId doc
        _db
            .collection(AppConstants.saccoCol)
            .doc(tid)
            .set({..._current.toMap(), 'migratedFromConfig': true},
                SetOptions(merge: true))
            .catchError((_) {});
        return _current;
      }
    } catch (_) {}

    // 3. Ultimate fallback
    _current = SaccoProfile(
      tenantId:  tid,
      saccoName: tid == 'sacco_001' ? 'SACCOPLUS Pro' : 'SACCO',
      country:   'UG',
      currency:  'UGX',
    );
    return _current;
  }

  static void clear() => _current = SaccoProfile.defaultSacco;

  // ── Platform Admin queries ─────────────────────────────────────────────────

  static Future<List<SaccoProfile>> listAllSaccos() async {
    try {
      final q = await _db
          .collection(AppConstants.saccoCol)
          .get(const GetOptions(source: Source.server));
      return q.docs
          .where((d) => d.id != 'config')
          .map((d) => SaccoProfile.fromMap({...d.data(), 'tenantId': d.id}))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Stream<QuerySnapshot> allSaccosStream() =>
      _db.collection(AppConstants.saccoCol).snapshots();

  // ── Create a new SACCO ─────────────────────────────────────────────────────

  static Future<String> createSacco({
    required String saccoName,
    String shortName      = '',
    String tagline        = '',
    String registrationNo = '',
    String phone          = '',
    String email          = '',
    String address        = '',
    String country        = 'UG',
    String currency       = 'UGX',
    Color  primaryColor   = const Color(0xFF0D2B6B),
    Color  accentColor    = const Color(0xFFF47920),
  }) async {
    final slug = saccoName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final tenantId = '${slug}_${DateTime.now().millisecondsSinceEpoch}';

    final profile = SaccoProfile(
      tenantId:       tenantId,
      saccoName:      saccoName,
      shortName:      shortName,
      tagline:        tagline,
      registrationNo: registrationNo,
      phone:          phone,
      email:          email,
      address:        address,
      country:        country,
      currency:       currency,
      primaryColor:   primaryColor,
      accentColor:    accentColor,
      status:         'active',
    );
    final data = profile.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection(AppConstants.saccoCol).doc(tenantId).set(data);
    return tenantId;
  }

  // ── Update / activate / deactivate ────────────────────────────────────────

  static Future<void> updateSacco(SaccoProfile profile) async {
    await _db
        .collection(AppConstants.saccoCol)
        .doc(profile.tenantId)
        .set(profile.toMap(), SetOptions(merge: true));
    if (profile.tenantId == _current.tenantId) _current = profile;
  }

  static Future<void> setSaccoStatus(String tid, String status) async {
    await _db.collection(AppConstants.saccoCol).doc(tid).update({
      'status':    status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Create a SACCO admin user ──────────────────────────────────────────────

  static Future<void> createSaccoAdmin({
    required String saccoTenantId,
    required String name,
    required String phone,       // normalised 256XXXXXXXXX
    String email = '',
    String role  = AppConstants.roleAdmin,
  }) async {
    final docId = 'phone_$phone';
    await _db.collection(AppConstants.usersCol).doc(docId).set({
      'uid':          docId,
      'name':         name,
      'phone':        phone,
      'email':        email,
      'role':         role,
      'tenantId':     saccoTenantId,
      'memberStatus': 'Active',
      'createdAt':    FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Dynamic ThemeData from SACCO branding ──────────────────────────────────

  static ThemeData buildTheme(SaccoProfile sacco) {
    final p = sacco.primaryColor;
    final a = sacco.accentColor;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor:  p,
        primary:    p,
        secondary:  a,
        surface:    const Color(0xFFF4F6FA),
        error:      const Color(0xFFEF4444),
        brightness: Brightness.light,
      ),
      textTheme:              GoogleFonts.poppinsTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      appBarTheme: AppBarTheme(
        backgroundColor: p,
        foregroundColor: Colors.white,
        elevation:       0,
        titleTextStyle:  GoogleFonts.poppins(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: a,
          foregroundColor: Colors.white,
          elevation:       0,
          padding:         const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:         true,
        fillColor:      Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: a, width: 2),
        ),
        prefixIconColor: p,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:      Colors.white,
        selectedItemColor:    a,
        unselectedItemColor:  const Color(0xFF9EACC0),
        selectedLabelStyle:   GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

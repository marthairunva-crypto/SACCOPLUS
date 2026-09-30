import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'constants.dart';
import 'audit_service.dart';
import 'payment_countries.dart';
import 'sacco_service.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Auth ────────────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static Future<void> signOut() async {
    _loggedInUid = null;
    _loggedInProfile = null;
    await _auth.signOut();
  }

  // Cached session for phone+PIN login (no Firebase Auth session)
  static String? _loggedInUid;
  static Map<String, dynamic>? _loggedInProfile;

  static String get sessionUid =>
      _loggedInUid ?? currentUser?.uid ?? '';

  static Map<String, dynamic>? get sessionProfile => _loggedInProfile;

  /// tenantId for the current session — used to scope every Firestore query.
  /// Falls back to 'saccoplus' to match existing Firebase data.
  static String get sessionTenantId =>
      _loggedInProfile?['tenantId'] as String? ?? 'saccoplus';

  /// Call this after successful PIN verification to cache the session.
  static void setSession(String uid, Map<String, dynamic> profile) {
    _loggedInUid = uid;
    _loggedInProfile = profile;
  }

  // Email/password (kept for admin accounts)
  static Future<UserCredential> signInWithEmail(
          String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<UserCredential> registerWithEmail(
          String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  static Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ─── EgoSMS OTP ───────────────────────────────────────────────────────────

  // In-memory OTP store: phone → {code, expiry}
  static final Map<String, Map<String, dynamic>> _otpStore = {};

  static const String _egoUsername = 'INFINITECH';
  static const String _egoPassword = 'Moses,123##';
  // SMS sender is the current SACCO name (max 11 chars for EgoSMS)
  static String get _egoSender {
    final name = SaccoService.current.shortName.isNotEmpty
        ? SaccoService.current.shortName
        : SaccoService.current.saccoName;
    // EgoSMS sender ID max 11 alphanumeric chars, no spaces
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return cleaned.length > 11
        ? cleaned.substring(0, 11)
        : cleaned.isNotEmpty
            ? cleaned
            : 'SACCOPLUS';
  }

  /// Normalise phone to Uganda format: 256XXXXXXXXX (no + prefix) — used for EgoSMS
  static String formatPhone(String raw) {
    raw = raw.replaceAll(RegExp(r'\s+'), '').replaceAll('+', '');
    if (raw.startsWith('0')) raw = '256${raw.substring(1)}';
    if (!raw.startsWith('256')) raw = '256$raw';
    return raw;
  }

  /// Normalise phone to MarzPay E.164 format for Uganda: +256XXXXXXXXX
  /// Kept for backward compatibility — use formatPhoneForCountry() for
  /// multi-country flows.
  static String formatPhoneForMarzPay(String raw) {
    return PaymentCountries.formatPhone(raw, PaymentCountries.uganda);
  }

  /// Normalise phone to E.164 for the given country.
  /// Examples:
  ///   Uganda  (+256): 0712345678 → +256712345678
  ///   Kenya   (+254): 0710000000 → +254710000000
  ///   DRC     (+243): 0812345678 → +243812345678
  static String formatPhoneForCountry(String raw, PaymentCountry country) {
    return PaymentCountries.formatPhone(raw, country);
  }

  /// Send a raw SMS via EgoSMS GET API.
  static Future<bool> _sendEgoSms(String number, String message) async {
    try {
      final uri = Uri.parse(
        'https://www.egosms.co/api/v1/plain/'
        '?number=${Uri.encodeComponent(number)}'
        '&message=${Uri.encodeComponent(message)}'
        '&username=${Uri.encodeComponent(_egoUsername)}'
        '&password=${Uri.encodeComponent(_egoPassword)}'
        '&sender=${Uri.encodeComponent(_egoSender)}',
      );
      final res = await http.get(uri);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Public: send an SMS to any phone number (used for admin broadcasts).
  static Future<void> sendSmsToPhone(String phone, String message) async {
    phone = formatPhone(phone);
    await _sendEgoSms(phone, message);
  }

  /// Generate a 6-digit OTP, store it in memory (5 min TTL), send via EgoSMS.
  /// Always returns true after storing — SMS delivery is confirmed by the user
  /// receiving it; the EgoSMS API may return non-200 even on success.
  static Future<bool> generateAndSendOtp(String phone) async {
    phone = formatPhone(phone);
    final code = (100000 + Random().nextInt(900000)).toString();
    _otpStore[phone] = {
      'code': code,
      'expiry': DateTime.now().add(const Duration(minutes: 5)),
    };
    // Fire and forget — don't block on the HTTP result
    _sendEgoSms(
      phone,
      'Your SACCOPLUS Pro verification code is: $code. Valid for 5 minutes.',
    );
    return true;
  }

  /// Alias for generateAndSendOtp for backward compatibility
  static Future<void> sendOtp(String phone) async {
    await generateAndSendOtp(phone);
  }

  /// Returns true if [enteredCode] matches the stored OTP for [phone].
  static bool verifyEgoOtp(String phone, String enteredCode) {
    phone = formatPhone(phone);
    final entry = _otpStore[phone];
    if (entry == null) return false;
    final expiry = entry['expiry'] as DateTime;
    if (DateTime.now().isAfter(expiry)) {
      _otpStore.remove(phone);
      return false;
    }
    final ok = entry['code'] == enteredCode.trim();
    if (ok) _otpStore.remove(phone); // one-time use
    return ok;
  }

  // ─── PIN helpers ─────────────────────────────────────────────────────────

  static String _hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  /// Save hashed PIN — writes to the saccoplus-members doc (primary)
  /// and also patches the agro-loans-users doc (legacy fallback).
  static Future<void> savePin(String pin, {required String phone}) async {
    phone = formatPhone(phone);
    final hash = _hashPin(pin);
    final docId = 'phone_$phone';

    // Write to new collection (primary)
    await _db
        .collection(AppConstants.usersCol)
        .doc(docId)
        .set({'phone': phone, 'pinHash': hash}, SetOptions(merge: true));

    // Also patch legacy collection so old data stays consistent
    try {
      await _db
          .collection('agro-loans-users')
          .doc(docId)
          .set({'pinHash': hash}, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal — legacy collection may not exist
    }
  }

  /// Returns true if the supplied PIN matches the stored hash.
  static Future<bool> verifyPin(String uid, String pin) async {
    final hash = _hashPin(pin);

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // Try saccoplus-members first (where your data is!)
        var doc = await _db
            .collection(AppConstants.usersCol)
            .doc(uid)
            .get(const GetOptions(source: Source.server));

        var stored = doc.data()?['pinHash'] as String?;

        // pinHash found — verify it
        if (stored != null && stored.isNotEmpty) {
          return stored == hash;
        }

        // Try users collection (legacy)
        doc = await _db
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));

        stored = doc.data()?['pinHash'] as String?;

        // pinHash found in the primary doc — use it
        if (stored != null && stored.isNotEmpty) {
          return stored == hash;
        }

        // pinHash missing from primary doc — this means the user's profile
        // was migrated but savePin wrote to a doc that didn't get merged.
        // Look up by the phone field to find the correct doc.
        final phone = doc.data()?['phone'] as String? ?? '';
        if (phone.isNotEmpty) {
          final formatted = formatPhone(phone);
          // Try both possible doc ID patterns in both collections
          for (final collection in ['saccoplus-members', AppConstants.usersCol]) {
            for (final docId in ['phone_$formatted', formatted]) {
              if (docId == uid) continue;
              final altDoc = await _db
                  .collection(collection)
                  .doc(docId)
                  .get(const GetOptions(source: Source.server));
              final altHash = altDoc.data()?['pinHash'] as String?;
              if (altHash != null && altHash.isNotEmpty) {
                return altHash == hash;
              }
            }
          }
        }

        return false;
      } catch (e) {
        if (attempt == 2) rethrow;
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    return false;
  }

  /// Check whether a phone number already has a profile in Firestore.
  /// Tries the formatted phone first, then falls back to the raw doc-ID
  /// pattern (phone_256XXXXXXXXX) used by the old agro-loans data.
  static Future<Map<String, dynamic>?> getProfileByPhone(
      String phone) async {
    phone = formatPhone(phone); // always normalise to 256XXXXXXXXX

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // ── 1. Try saccoplus-members collection first (new data) ──────────
        var q = await _db
            .collection(AppConstants.usersCol)
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get(const GetOptions(source: Source.server));

        if (q.docs.isNotEmpty) {
          final data = q.docs.first.data();
          // Ensure uid is always populated — fall back to doc ID
          if (data['uid'] == null || (data['uid'] as String).isEmpty) {
            data['uid'] = q.docs.first.id;
          }
          return data;
        }

        // ── 2. Try users collection (legacy data) ──────────────────────────
        q = await _db
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get(const GetOptions(source: Source.server));

        if (q.docs.isNotEmpty) {
          final data = q.docs.first.data();
          // Ensure uid is always populated — fall back to doc ID
          if (data['uid'] == null || (data['uid'] as String).isEmpty) {
            data['uid'] = q.docs.first.id;
          }
          return data;
        }

        // ── 3. Fall back: direct doc-ID lookup (phone_256XXXXXXXXX) ─────
        final docId = 'phone_$phone';
        
        // Try saccoplus-members first
        var doc = await _db
            .collection(AppConstants.usersCol)
            .doc(docId)
            .get(const GetOptions(source: Source.server));

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['uid'] = docId;
          return data;
        }

        // Try users collection
        doc = await _db
            .collection('users')
            .doc(docId)
            .get(const GetOptions(source: Source.server));

        if (doc.exists) {
          final data = doc.data()!;
          if (data['uid'] == null || (data['uid'] as String).isEmpty) {
            data['uid'] = doc.id;
          }
          return data;
        }

        return null; // genuinely not found
      } catch (e) {
        if (attempt == 2) rethrow;
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    return null;
  }

  // ─── Users ───────────────────────────────────────────────────────────────

  static Future<void> createUserProfile(Map<String, dynamic> data) async {
    final phone = data['phone'] as String? ?? '';
    final docId = phone.isNotEmpty ? 'phone_$phone' : const Uuid().v4();
    // Ensure every member record carries a tenantId
    final tid = data['tenantId'] as String? ?? sessionTenantId;
    // merge: true preserves the pinHash written in the previous step
    await _db
        .collection(AppConstants.usersCol)
        .doc(docId)
        .set({...data, 'uid': docId, 'tenantId': tid}, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc =
        await _db.collection(AppConstants.usersCol).doc(uid).get();
    return doc.data();
  }

  static Stream<DocumentSnapshot> getUserProfileStream(String uid) => _db
      .collection(AppConstants.usersCol)
      .doc(uid)
      .snapshots();

  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final uid = sessionUid;
    if (uid.isEmpty) return;
    await _db.collection(AppConstants.usersCol).doc(uid).update(data);
  }

  static Stream<QuerySnapshot> getAllFarmers() => _db
      .collection(AppConstants.usersCol)
      .where('tenantId', isEqualTo: sessionTenantId)
      .where('role', isEqualTo: AppConstants.roleMember)
      .snapshots();

  // ─── Loans ───────────────────────────────────────────────────────────────

  static Future<void> applyLoan(Map<String, dynamic> data) async {
    final id = const Uuid().v4();
    await _db.collection(AppConstants.loansCol).doc(id).set({
      ...data,
      'id': id,
      'memberId': sessionUid,
      'tenantId': sessionTenantId,
      'status': AppConstants.statusPending,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ── Save guarantors as sub-documents ─────────────────────────────────
    final guarantors = data['guarantors'] as List<dynamic>? ?? [];
    for (final g in guarantors) {
      final gMap = g as Map<String, dynamic>;
      final gId = const Uuid().v4();
      await _db.collection(AppConstants.guarantorsCol).doc(gId).set({
        'id': gId,
        'loanId': id,
        'borrowerId': sessionUid,
        'guarantorId': gMap['uid'] ?? '',
        'guarantorName': gMap['name'] ?? '',
        'guarantorPhone': gMap['phone'] ?? '',
        'guarantorMemberNo': gMap['memberNumber'] ?? '',
        'consentStatus': 'pending', // pending | accepted | declined
        'smsSentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─── Guarantors ──────────────────────────────────────────────────────────

  /// Fetch all verified members suitable for guarantor selection.
  /// Excludes the current user. Returns lightweight profiles.
  static Future<List<Map<String, dynamic>>> getAllMembersForGuarantor() async {
    for (int i = 0; i < 3; i++) {
      try {
        final q = await _db
            .collection(AppConstants.usersCol)
            .where('role', isEqualTo: AppConstants.roleMember)
            .where('tenantId', isEqualTo: sessionTenantId)
            .get(const GetOptions(source: Source.server));
        return q.docs.map((d) {
          final data = d.data();
          return {
            'uid': data['uid'] ?? d.id,
            'name': data['name'] ?? '',
            'phone': data['phone'] ?? '',
            'memberNumber': data['memberNumber'] ?? '',
            'idStatus': data['idStatus'] ?? '',
          };
        }).toList();
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  /// Get guarantors for a specific loan.
  static Future<List<Map<String, dynamic>>> getLoanGuarantors(
      String loanId) async {
    for (int i = 0; i < 3; i++) {
      try {
        final q = await _db
            .collection(AppConstants.guarantorsCol)
            .where('loanId', isEqualTo: loanId)
            .get(const GetOptions(source: Source.server));
        return q.docs.map((d) => d.data()).toList();
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  /// Update guarantor consent status (accepted / declined).
  static Future<void> updateGuarantorConsent(
      String guarantorDocId, String status) async {
    await _db
        .collection(AppConstants.guarantorsCol)
        .doc(guarantorDocId)
        .update({
      'consentStatus': status,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of guarantors for a loan — used in admin approval screen.
  static Stream<QuerySnapshot> getLoanGuarantorsStream(String loanId) => _db
      .collection(AppConstants.guarantorsCol)
      .where('loanId', isEqualTo: loanId)
      .snapshots();

  static Stream<QuerySnapshot> getFarmerLoans(String memberId) => _db
      .collection(AppConstants.loansCol)
      .where('memberId', isEqualTo: memberId)
      .orderBy('createdAt', descending: true)
      .snapshots();

  static Stream<QuerySnapshot> getAllLoans() => _db
      .collection(AppConstants.loansCol)
      .where('tenantId', isEqualTo: sessionTenantId)
      // TODO: Add composite index for tenantId + createdAt in Firebase Console
      // .orderBy('createdAt', descending: true)
      .snapshots();

  static Stream<QuerySnapshot> getLoansByStatus(String status) => _db
      .collection(AppConstants.loansCol)
      .where('tenantId', isEqualTo: sessionTenantId)
      .where('status', isEqualTo: status)
      // TODO: Add composite index for tenantId + status + createdAt
      // .orderBy('createdAt', descending: true)
      .snapshots();

  static Future<void> updateLoanStatus(String loanId, String status,
      {String? note}) async {
    await _db.collection(AppConstants.loansCol).doc(loanId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (note != null) 'adminNote': note,
    });
  }

  // ─── Repayments ──────────────────────────────────────────────────────────

  static Future<void> makeRepayment(Map<String, dynamic> data) async {
    final id = const Uuid().v4();
    await _db.collection(AppConstants.repaymentsCol).doc(id).set({
      ...data,
      'id': id,
      'memberId': sessionUid,
      'tenantId': sessionTenantId,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> getFarmerRepayments(String memberId) => _db
      .collection(AppConstants.repaymentsCol)
      .where('memberId', isEqualTo: memberId)
      .orderBy('paidAt', descending: true)
      .snapshots();

  static Stream<QuerySnapshot> getAllRepayments() => _db
      .collection(AppConstants.repaymentsCol)
      .where('tenantId', isEqualTo: sessionTenantId)
      .orderBy('paidAt', descending: true)
      .snapshots();

  // ─── Notifications ───────────────────────────────────────────────────────

  static Future<void> sendNotification(
      String recipientId, String title, String message, {String? type}) async {
    final id = const Uuid().v4();
    await _db.collection(AppConstants.notificationsCol).doc(id).set({
      'id': id,
      'recipientId': recipientId,
      'tenantId': sessionTenantId,
      'title': title,
      'message': message,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (type != null) 'type': type,
    });
  }

  static Stream<QuerySnapshot> getUserNotifications(String uid) => _db
      .collection(AppConstants.notificationsCol)
      .where('recipientId', isEqualTo: uid)
      .snapshots();

  static Future<void> markNotificationRead(String notifId) async {
    await _db
        .collection(AppConstants.notificationsCol)
        .doc(notifId)
        .update({'read': true});
  }

  static Stream<QuerySnapshot> getAllNotifications() => _db
      .collection(AppConstants.notificationsCol)
      .where('tenantId', isEqualTo: sessionTenantId)
      .orderBy('createdAt', descending: true)
      .snapshots();

  // ─── IMGBB Image Upload ──────────────────────────────────────────────────

  static Future<String?> uploadImageToImgbb(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return uploadImageBytesToImgbb(bytes);
    } catch (_) {}
    return null;
  }

  static Future<String?> uploadImageBytesToImgbb(List<int> bytes,
      [String? filename]) async {
    try {
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse(
            '${AppConstants.imgbbUploadUrl}?key=${AppConstants.imgbbApiKey}'),
        body: {'image': base64Image},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ─── ID Verification ─────────────────────────────────────────────────────

  /// Upload front & back ID images (File-based, for mobile)
  static Future<void> submitIdVerification({
    required File frontImage,
    required File backImage,
    required String idType,
  }) async {
    final frontBytes = await frontImage.readAsBytes();
    final backBytes = await backImage.readAsBytes();
    return submitIdVerificationBytes(
        frontBytes: frontBytes, backBytes: backBytes, idType: idType);
  }

  /// Upload front & back ID images (bytes-based, works on web + mobile)
  static Future<void> submitIdVerificationBytes({
    required List<int> frontBytes,
    required List<int> backBytes,
    required String idType,
  }) async {
    final frontUrl = await uploadImageBytesToImgbb(frontBytes);
    final backUrl  = await uploadImageBytesToImgbb(backBytes);
    final uid = sessionUid;
    if (uid.isEmpty) throw Exception('Not signed in');
    await _db.collection(AppConstants.usersCol).doc(uid).update({
      'idType': idType,
      'idFrontUrl': frontUrl ?? '',
      'idBackUrl': backUrl ?? '',
      'idStatus': 'pending',
      'idSubmittedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateIdVerificationStatus(
      String uid, String status) async {
    await _db.collection(AppConstants.usersCol).doc(uid).update({
      'idStatus': status,
      'idReviewedAt': FieldValue.serverTimestamp(),
    });
    // Send in-app notification to the farmer
    final title = status == 'approved'
        ? 'ID Verification Approved'
        : 'ID Verification Rejected';
    final message = status == 'approved'
        ? 'Your identity has been verified. You can now apply for loans.'
        : 'Your ID verification was rejected. Please resubmit clear photos of your ID.';
    await sendNotification(uid, title, message);
    // Also send SMS
    final doc = await _db.collection(AppConstants.usersCol).doc(uid).get();
    final phone = doc.data()?['phone'] as String? ?? '';
    if (phone.isNotEmpty) {
      sendSmsToPhone(phone, '$title: $message');
    }
  }

  // ─── MarzPay ─────────────────────────────────────────────────────────────

  /// Initiates a mobile money collection via MarzPay.
  /// Returns the transaction UUID on success, throws on failure.
  ///
  /// [countryCode]   — MarzPay country code e.g. 'UG', 'KE', 'CD'. Defaults
  ///                   to 'UG' so all existing Uganda callers keep working.
  /// [currencyCode]  — ISO currency. Only required for DRC ('CDF' or 'USD').
  ///                   Ignored for single-currency markets.
  static Future<Map<String, dynamic>> marzPayCollect({
    required String phoneNumber,
    required int amount,
    required String description,
    String countryCode = AppConstants.marzPayCountry,
    String? currencyCode,
    String? callbackUrl,
  }) async {
    final reference = const Uuid().v4();
    final country = PaymentCountries.byCode(countryCode);
    final resolvedCurrency = PaymentCountries.resolveCurrency(
      country,
      currencyOverride: currencyCode,
    );

    final payload = <String, dynamic>{
      'phone_number': phoneNumber,
      'amount': amount,
      'country': countryCode,
      'reference': reference,
      'description': description,
      // Only send currency for DRC (dual-currency market)
      if (country.isDualCurrency) 'currency': resolvedCurrency,
      if (callbackUrl != null) 'callback_url': callbackUrl,
    };
    final responseBody = await _marzPayRequest('POST', 'collect', payload);
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    if (json['status'] != 'success') {
      throw Exception(json['message'] ?? 'MarzPay payment failed');
    }
    return {
      'reference': reference,
      'uuid': (json['data']?['transaction']?['uuid'] ?? ''),
      'provider': (json['data']?['collection']?['provider'] ?? ''),
      'country': countryCode,
      'currency': resolvedCurrency,
    };
  }

  static Future<String> marzPayCheckStatus(String uuid) async {
    final responseBody = await _marzPayRequest('GET', 'status', {}, uuid: uuid);
    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    // Try every possible location MarzPay might put the status
    final candidates = [
      json['data']?['transaction']?['status'],
      json['data']?['collection']?['status'],
      json['data']?['status'],
      json['transaction']?['status'],
      json['collection']?['status'],
      json['status'],
    ];

    final rawStatus = candidates
        .whereType<String>()
        .map((s) => s.toLowerCase().trim())
        .firstWhere((s) => s.isNotEmpty, orElse: () => 'unknown');

    // Broad success matching — MarzPay uses different words per provider
    const successWords = {
      'successful', 'completed', 'success', 'complete',
      'paid', 'approved', 'confirmed', 'processed',
      'sandbox', // sandbox always counts as success
    };
    if (successWords.contains(rawStatus)) return 'completed';

    const failWords = {
      'failed', 'cancelled', 'rejected', 'fail',
      'declined', 'expired', 'error', 'timeout',
    };
    if (failWords.contains(rawStatus)) return 'failed';

    return rawStatus; // 'pending', 'processing', etc.
  }

  /// Routes MarzPay calls through proxy (fixed whitelisted IP 185.27.134.46)
  /// Works on both web and Android regardless of network
  static Future<String> _marzPayRequest(
    String method,
    String action,
    Map<String, dynamic> body, {
    String? uuid,
    Map<String, String>? queryParams,
  }) async {
    final String proxyUrl;
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Proxy-Key': AppConstants.marzPayProxyKey,
      'Cache-Control': 'no-cache, no-store',
    };

    if (AppConstants.useRenderProxy) {
      // Render proxy — clean REST endpoints
      final base = AppConstants.renderProxyUrl;
      
      // Handle bill payment routes
      if (action.startsWith('bill-payment')) {
        proxyUrl = '$base/$action';
      }
      // Handle phone verification routes
      else if (action.startsWith('phone-verification')) {
        if (action == 'phone-verification/verify') {
          proxyUrl = '$base/phone-verification/verify';
        } else if (action == 'phone-verification/service-info') {
          proxyUrl = '$base/phone-verification/service-info';
        } else if (action == 'phone-verification/subscription-status') {
          proxyUrl = '$base/phone-verification/subscription-status';
        } else {
          proxyUrl = '$base/$action';
        }
      }
      // Handle bank transfer routes
      else if (action.startsWith('bank-transfer')) {
        if (action == 'bank-transfer/banks') {
          proxyUrl = '$base/bank-transfer/banks';
        } else if (action == 'bank-transfer/validate') {
          proxyUrl = '$base/bank-transfer/validate';
        } else if (action == 'bank-transfer/services') {
          proxyUrl = '$base/bank-transfer/services';
        } else if (action == 'bank-transfer') {
          proxyUrl = '$base/bank-transfer';
        } else if (action.startsWith('bank-transfer/')) {
          // bank-transfer/{reference}
          final ref = action.substring('bank-transfer/'.length);
          proxyUrl = '$base/bank-transfer/$ref';
        } else {
          proxyUrl = '$base/$action';
        }
      } else {
        // Original mobile money routes
        final endpointMap = {
          'collect': '$base/collect',
          'withdraw': '$base/withdraw',
          'status': uuid != null ? '$base/status/$uuid' : '$base/status',
          'collect-money/services': '$base/collect-money/services',
          'send-money/services': '$base/send-money/services',
          'withdraw-status': uuid != null ? '$base/withdraw-status/$uuid' : '$base/withdraw-status',
        };
        proxyUrl = endpointMap[action] ?? '$base/$action';
      }
    } else {
      // PHP proxy
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final base = AppConstants.marzPayProxyUrl;
      proxyUrl = uuid != null
          ? '$base?action=$action&uuid=${Uri.encodeComponent(uuid)}&_cb=$cb'
          : '$base?action=$action&_cb=$cb';
    }

    // Build URI — append query params if provided (e.g. ?country=KE)
    Uri uri;
    if (queryParams != null && queryParams.isNotEmpty) {
      final rawUri = Uri.parse(proxyUrl);
      uri = rawUri.replace(
        queryParameters: {...rawUri.queryParameters, ...queryParams},
      );
    } else {
      uri = Uri.parse(proxyUrl);
    }

    // Call the Render proxy directly — it has CORS headers for both web and Android.
    // corsproxy.io is no longer used (it now requires a paid API key).
    final res = method == 'GET'
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));

    return res.body;
  }

  /// Returns the set of uid keys to query against for the current session.
  /// Migrated accounts may have data stored under either the session uid
  /// OR the legacy phone_256XXXXXXXXX doc ID — we check both.
  static Set<String> _uidKeys(String uid) {
    final keys = <String>{uid};
    final phone = _loggedInProfile?['phone'] as String? ?? '';
    if (phone.isNotEmpty) {
      keys.add('phone_${formatPhone(phone)}');
    }
    return keys;
  }

  static Future<List<Map<String, dynamic>>> getFarmerLoansOnce(String memberId) async {
    final keys = _uidKeys(memberId);
    for (int i = 0; i < 3; i++) {
      try {
        final allDocs = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final key in keys) {
          final q = await _db
              .collection(AppConstants.loansCol)
              .where('memberId', isEqualTo: key)
              .get(const GetOptions(source: Source.server));
          for (final doc in q.docs) {
            if (seenIds.add(doc.id)) allDocs.add(doc.data());
          }
        }
        allDocs.sort((a, b) {
          final ta = a['createdAt'];
          final tb = b['createdAt'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
        return allDocs;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getFarmerRepaymentsOnce(String memberId) async {
    final keys = _uidKeys(memberId);
    for (int i = 0; i < 3; i++) {
      try {
        final allDocs = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final key in keys) {
          final q = await _db
              .collection(AppConstants.repaymentsCol)
              .where('memberId', isEqualTo: key)
              .get(const GetOptions(source: Source.server));
          for (final doc in q.docs) {
            if (seenIds.add(doc.id)) allDocs.add(doc.data());
          }
        }
        allDocs.sort((a, b) {
          final ta = a['paidAt'];
          final tb = b['paidAt'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
        return allDocs;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllLoansOnce() async {
    print('🔍 getAllLoansOnce: sessionTenantId = $sessionTenantId');
    for (int i = 0; i < 3; i++) {
      try {
        final q = await _db
            .collection(AppConstants.loansCol)
            .where('tenantId', isEqualTo: sessionTenantId)
            .get(const GetOptions(source: Source.server));
        final docs = q.docs.map((d) => d.data()).toList();
        print('📥 getAllLoansOnce: Found ${docs.length} loans');
        docs.sort((a, b) {
          final ta = a['createdAt'];
          final tb = b['createdAt'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
        return docs;
      } catch (e) {
        print('❌ getAllLoansOnce attempt ${i + 1} failed: $e');
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    print('❌ getAllLoansOnce: All attempts failed, returning empty list');
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllRepaymentsOnce() async {
    for (int i = 0; i < 3; i++) {
      try {
        final q = await _db
            .collection(AppConstants.repaymentsCol)
            .where('tenantId', isEqualTo: sessionTenantId)
            .get(const GetOptions(source: Source.server));
        final docs = q.docs.map((d) => d.data()).toList();
        docs.sort((a, b) {
          final ta = a['paidAt'];
          final tb = b['paidAt'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
        return docs;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAllFarmersOnce() async {
    print('🔍 getAllFarmersOnce: sessionTenantId = $sessionTenantId, roleMember = ${AppConstants.roleMember}');
    for (int i = 0; i < 3; i++) {
      try {
        final q = await _db
            .collection(AppConstants.usersCol)
            .where('role', isEqualTo: AppConstants.roleMember)
            .where('tenantId', isEqualTo: sessionTenantId)
            .get(const GetOptions(source: Source.server));
        final members = q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        print('📥 getAllFarmersOnce: Found ${members.length} members');
        return members;
      } catch (e) {
        print('❌ getAllFarmersOnce attempt ${i + 1} failed: $e');
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    print('❌ getAllFarmersOnce: All attempts failed, returning empty list');
    return [];
  }

  // ─── Wallet ───────────────────────────────────────────────────────────────

  /// Get or create wallet for current user.
  /// Falls back to phone_* doc ID if the uid-based doc doesn't exist —
  /// handles migrated accounts where the wallet was stored under a different key.
  static Future<Map<String, dynamic>> getWallet(String uid) async {
    // ── 1. Try the uid directly ───────────────────────────────────────────
    var doc = await _db.collection(AppConstants.walletCol).doc(uid).get();

    // ── 2. If not found, try phone_256XXXXXXXXX pattern ───────────────────
    if (!doc.exists) {
      final phone = _loggedInProfile?['phone'] as String? ?? '';
      if (phone.isNotEmpty) {
        final phoneDocId = 'phone_${formatPhone(phone)}';
        if (phoneDocId != uid) {
          doc = await _db.collection(AppConstants.walletCol).doc(phoneDocId).get();
        }
      }
    }

    if (!doc.exists) {
      // Create a fresh wallet under the canonical uid
      final wallet = {
        'uid': uid,
        'balance': 0,
        'totalDeposited': 0,
        'totalWithdrawn': 0,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection(AppConstants.walletCol).doc(uid).set(wallet);
      return {'balance': 0, 'totalDeposited': 0, 'totalWithdrawn': 0};
    }
    return doc.data()!;
  }

  /// Get today's total withdrawn amount
  static Future<int> getTodayWithdrawn(String uid) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final keys = _uidKeys(uid);
    try {
      int total = 0;
      final seenIds = <String>{};
      for (final key in keys) {
        final q = await _db
            .collection(AppConstants.walletTxnCol)
            .where('uid', isEqualTo: key)
            .where('type', isEqualTo: 'withdrawal')
            .get();
        for (final doc in q.docs) {
          if (!seenIds.add(doc.id)) continue;
          final ts = doc['createdAt'];
          if (ts is Timestamp && ts.toDate().isAfter(startOfDay)) {
            total += (doc['amount'] as num?)?.toInt() ?? 0;
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Deposit money into wallet via MarzPay collection.
  ///
  /// [countryCode]  — defaults to 'UG' so existing Uganda callers are unaffected.
  /// [currencyCode] — only needed for DRC (CDF or USD).
  static Future<Map<String, dynamic>> walletDeposit({
    required String uid,
    required int amount,
    required String phoneNumber,
    String countryCode = AppConstants.marzPayCountry,
    String? currencyCode,
  }) async {
    final country = PaymentCountries.byCode(countryCode);
    final resolvedCurrency = PaymentCountries.resolveCurrency(
      country,
      currencyOverride: currencyCode,
    );

    // 1. Initiate MarzPay collection
    final marzResult = await marzPayCollect(
      phoneNumber: phoneNumber,
      amount: amount,
      description: 'Wallet deposit - SACCOPLUS Pro',
      countryCode: countryCode,
      currencyCode: resolvedCurrency,
    );

    // 2. Record pending transaction (now includes country + currency)
    final txnId = const Uuid().v4();
    await _db.collection(AppConstants.walletTxnCol).doc(txnId).set({
      'id': txnId,
      'uid': uid,
      'type': 'deposit',
      'amount': amount,
      'phone': phoneNumber,
      'status': 'pending',
      'tenantId': sessionTenantId,
      'country': countryCode,
      'currency': resolvedCurrency,
      'marzUuid': marzResult['uuid'],
      'marzReference': marzResult['reference'],
      'provider': marzResult['provider'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {...marzResult, 'txnId': txnId};
  }

  /// Confirm deposit after MarzPay confirms payment
  static Future<void> confirmWalletDeposit({
    required String uid,
    required String txnId,
    required int amount,
  }) async {
    // Update transaction status
    await _db.collection(AppConstants.walletTxnCol).doc(txnId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    // Credit wallet balance
    await _db.collection(AppConstants.walletCol).doc(uid).set({
      'uid': uid,
      'balance': FieldValue.increment(amount),
      'totalDeposited': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  /// Force-confirm a pending deposit by marzUuid — used when polling times out
  /// but the user confirms money was deducted from their phone.
  static Future<bool> forceConfirmPendingDeposit(String marzUuid) async {
    try {
      final uid = sessionUid;
      if (uid.isEmpty) return false;
      final keys = _uidKeys(uid);

      // Find the pending transaction by marzUuid across all uid keys
      QueryDocumentSnapshot? found;
      for (final key in keys) {
        final q = await _db
            .collection(AppConstants.walletTxnCol)
            .where('uid', isEqualTo: key)
            .where('marzUuid', isEqualTo: marzUuid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) { found = q.docs.first; break; }
      }

      if (found == null) return false;
      final data = found.data() as Map<String, dynamic>;
      final txnId = found.id;
      // amount stored is totalCollected (amount + charge); we credit only amount
      final totalCollected = (data['amount'] as num?)?.toInt() ?? 0;
      // charge was stored separately if available, otherwise estimate 3.2%
      final charge = (data['charge'] as num?)?.toInt() ??
          (totalCollected * AppConstants.walletDepositChargePercent).ceil()
              .clamp(AppConstants.walletMinCharge, 999999);
      final creditAmount = totalCollected - charge;

      await confirmWalletDeposit(
          uid: uid, txnId: txnId, amount: creditAmount);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Withdraw money from wallet via MarzPay send-money.
  ///
  /// [countryCode]  — defaults to 'UG' so existing Uganda callers are unaffected.
  /// [currencyCode] — only needed for DRC (CDF or USD).
  static Future<Map<String, dynamic>> walletWithdraw({
    required String uid,
    required int amount,
    required String phoneNumber,
    required String recipientName,
    int chargeAmount = 0,
    String countryCode = AppConstants.marzPayCountry,
    String? currencyCode,
  }) async {
    final country = PaymentCountries.byCode(countryCode);
    final resolvedCurrency = PaymentCountries.resolveCurrency(
      country,
      currencyOverride: currencyCode,
    );

    final totalDeduct = amount + chargeAmount;
    // 1. Check balance FIRST before touching anything
    final wallet = await getWallet(uid);
    final balance = (wallet['balance'] as num?)?.toInt() ?? 0;
    if (totalDeduct > balance) throw Exception('Insufficient wallet balance');

    // 2. Check daily limit (kept in UGX for Uganda; other markets use their
    //    local currency amounts — limit is checked in local currency units)
    final todayWithdrawn = await getTodayWithdrawn(uid);
    if (todayWithdrawn + amount > AppConstants.walletDailyLimit) {
      final remaining = AppConstants.walletDailyLimit - todayWithdrawn;
      throw Exception(
          'Daily limit exceeded. You can withdraw ${country.currencySymbol} $remaining more today.');
    }

    // 3. Try MarzPay FIRST — only deduct if successful
    final reference = const Uuid().v4();
    final responseBody = await _marzPayRequest('POST', 'withdraw', {
      'phone_number': phoneNumber,
      'amount': amount,
      'country': countryCode,
      'reference': reference,
      'description': 'Wallet withdrawal - SACCOPLUS Pro',
      // Only send currency for DRC
      if (country.isDualCurrency) 'currency': resolvedCurrency,
    });

    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    if (json['status'] != 'success') {
      throw Exception(json['message'] ?? 'Withdrawal failed');
    }

    // 4. MarzPay succeeded — deduct amount + charge from wallet
    await _db.collection(AppConstants.walletCol).doc(uid).update({
      'balance': FieldValue.increment(-totalDeduct),
      'totalWithdrawn': FieldValue.increment(totalDeduct),
    });

    // 5. Record transaction (now includes country + currency)
    final txnId = const Uuid().v4();
    // send-money create uses 'withdrawal' key; callbacks use 'disbursement'
    final disbursementData = json['data']?['withdrawal'] as Map<String, dynamic>?
        ?? json['data']?['disbursement'] as Map<String, dynamic>?
        ?? {};
    await _db.collection(AppConstants.walletTxnCol).doc(txnId).set({
      'id': txnId,
      'uid': uid,
      'type': 'withdrawal',
      'amount': amount,
      'charge': chargeAmount,
      'totalDeducted': totalDeduct,
      'phone': phoneNumber,
      'recipientName': recipientName,
      'status': 'completed',
      'country': countryCode,
      'currency': resolvedCurrency,
      'marzUuid': json['data']?['transaction']?['uuid'] ?? '',
      'marzReference': reference,
      'provider': disbursementData['provider'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'txnId': txnId, 'reference': reference};
  }

  /// Update wallet transaction status (e.g. mark as failed after timeout)
  static Future<void> updateWalletTxnStatus(String txnId, String status) async {
    try {
      await _db.collection(AppConstants.walletTxnCol).doc(txnId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Get wallet transaction history — tries both uid and phone_* doc ID pattern.
  static Future<List<Map<String, dynamic>>> getWalletTransactions(String uid) async {
    // Build the list of uid values to query against
    final uidsToTry = <String>{uid};
    final phone = _loggedInProfile?['phone'] as String? ?? '';
    if (phone.isNotEmpty) {
      uidsToTry.add('phone_${formatPhone(phone)}');
    }

    for (int i = 0; i < 3; i++) {
      try {
        final allDocs = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        for (final uidKey in uidsToTry) {
          final q = await _db
              .collection(AppConstants.walletTxnCol)
              .where('uid', isEqualTo: uidKey)
              .get(const GetOptions(source: Source.server));
          for (final doc in q.docs) {
            if (!seenIds.contains(doc.id)) {
              seenIds.add(doc.id);
              allDocs.add(doc.data());
            }
          }
        }

        allDocs.sort((a, b) {
          final ta = a['createdAt'];
          final tb = b['createdAt'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
        return allDocs;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  static Future<Map<String, int>> getDashboardStats() async {
    final loans = await _db.collection(AppConstants.loansCol).get();
    final users = await _db
        .collection(AppConstants.usersCol)
        .where('role', isEqualTo: AppConstants.roleMember)
        .get();
    final repayments =
        await _db.collection(AppConstants.repaymentsCol).get();

    int pending = 0, approved = 0, rejected = 0, paid = 0;
    for (final doc in loans.docs) {
      final status = doc['status'] as String? ?? '';
      if (status == AppConstants.statusPending) pending++;
      if (status == AppConstants.statusApproved) approved++;
      if (status == AppConstants.statusRejected) rejected++;
      if (status == AppConstants.statusPaid) paid++;
    }

    return {
      'totalFarmers': users.docs.length,
      'totalLoans': loans.docs.length,
      'pendingLoans': pending,
      'approvedLoans': approved,
      'rejectedLoans': rejected,
      'paidLoans': paid,
      'totalRepayments': repayments.docs.length,
    };
  }

  // ─── Bank Transfer ───────────────────────────────────────────────────────
  // ─── Phone Verification ──────────────────────────────────────────────────────

  /// Verify phone number and retrieve registered subscriber name (KYC).
  ///
  /// Per MarzPay docs, phone verification is currently supported for Uganda
  /// (and expanding). For non-Uganda countries this returns a graceful
  /// unverified result rather than blocking the flow.
  ///
  /// [countryCode] defaults to 'UG'. For Uganda, pass the number without
  /// the leading '+' as MarzPay expects '256XXXXXXXXX'. For other countries,
  /// the method returns {success:false, verified:false} gracefully.
  static Future<Map<String, dynamic>> verifyPhoneNumber(
    String phoneNumber, {
    String countryCode = 'UG',
  }) async {
    // Phone verification is Uganda-primary. For other markets, return
    // a graceful "not available" so the UI can still allow proceeding.
    if (countryCode != 'UG') {
      return {
        'success': false,
        'verified': false,
        'phone_number': phoneNumber,
        'message': 'Phone verification not yet available for this country',
        'countryCode': countryCode,
      };
    }

    try {
      final formattedPhone = formatPhoneForMarzPay(phoneNumber).replaceAll('+', '');
      
      final responseBody = await _marzPayRequest('POST', 'phone-verification/verify', {
        'phone_number': formattedPhone,
      });
      
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      
      if (json['success'] == true) {
        final data = json['data'] as Map<String, dynamic>? ?? {};
        return {
          'success': true,
          'verified': true,
          'phone_number': data['phone_number'] ?? phoneNumber,
          'first_name': data['first_name'] ?? '',
          'last_name': data['last_name'] ?? '',
          'full_name': data['full_name'] ?? '',
          'verification_status': data['verification_status'] ?? 'verified',
          'verified_at': json['verified_at'] ?? DateTime.now().toIso8601String(),
          'countryCode': countryCode,
        };
      }
      
      return {
        'success': false,
        'verified': false,
        'phone_number': phoneNumber,
        'message': json['message'] ?? 'Phone number not found or not registered',
        'countryCode': countryCode,
      };
    } catch (e) {
      return {
        'success': false,
        'verified': false,
        'phone_number': phoneNumber,
        'message': 'Verification unavailable: $e',
        'countryCode': countryCode,
      };
    }
  }

  /// Get phone verification service information
  static Future<Map<String, dynamic>> getPhoneVerificationServiceInfo() async {
    try {
      final responseBody = await _marzPayRequest('GET', 'phone-verification/service-info', {});
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json;
    } catch (e) {
      return {'success': false, 'message': 'Failed to get service info: $e'};
    }
  }

  /// Get available collection (mobile money) services for a given country.
  /// Returns the raw MarzPay services list so the UI can show provider names.
  static Future<List<Map<String, dynamic>>> getCollectionServices({
    String countryCode = AppConstants.marzPayCountry,
  }) async {
    try {
      final responseBody = await _marzPayRequest(
        'GET', 'collect-money/services', {},
        queryParams: {'country': countryCode},
      );
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final services = json['data']?['services'] as List<dynamic>?
            ?? json['data'] as List<dynamic>?
            ?? [];
        return services.map((s) => s as Map<String, dynamic>).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── Forex Rates ─────────────────────────────────────────────────────────────

  /// Fetch live exchange rates from [baseCurrency] to all other currencies.
  /// Uses the Render proxy's /forex/rates endpoint which caches for 1 hour.
  /// Returns a map like {'RWF': 14.2, 'KES': 0.29, ...}
  /// Returns empty map on failure so callers can gracefully degrade.
  ///
  /// Attribution: Rates By Exchange Rate API — https://www.exchangerate-api.com
  static Future<Map<String, double>> getForexRates({
    String baseCurrency = 'UGX',
  }) async {
    try {
      final responseBody = await _marzPayRequest(
        'GET', 'forex/rates', {},
        queryParams: {'base': baseCurrency},
      );
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final raw = json['rates'] as Map<String, dynamic>? ?? {};
        return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Convert [amount] from [fromCurrency] to [toCurrency] using live rates.
  /// Returns null if rates are unavailable.
  static Future<double?> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return amount;
    final rates = await getForexRates(baseCurrency: fromCurrency);
    if (rates.isEmpty) return null;
    final rate = rates[toCurrency];
    if (rate == null) return null;
    return amount * rate;
  }

  // ─── Bill Payments ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getBillPaymentServices() async {
    try {
      final body = await _marzPayRequest('GET', 'bill-payment/services', {});
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final list = json['data']?['available_utilities'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<List<String>> getNwscAreas() async {
    try {
      final body = await _marzPayRequest('GET', 'bill-payment/nwsc/areas', {});
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final areas = json['data']?['areas'] as List<dynamic>? ?? [];
        return areas.cast<String>();
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getDstvBouquets() async {
    try {
      final body = await _marzPayRequest('GET', 'bill-payment/dstv/bouquet-codes', {});
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final list = json['data']?['bouquet_details'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<List<Map<String, dynamic>>> getGotvBouquets() async {
    try {
      final body = await _marzPayRequest('GET', 'bill-payment/gotv/bouquet-codes', {});
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final list = json['data']?['bouquet_details'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> verifyBillMeter({
    required String utilityCode,
    required String meterNumber,
    String? area,
  }) async {
    final payload = <String, dynamic>{
      'utility_code': utilityCode,
      'meter_number': meterNumber,
      if (area != null) 'area': area,
    };
    final body = await _marzPayRequest('POST', 'bill-payment/verify', payload);
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['status'] == 'success') {
      return json['data']?['customer_details'] as Map<String, dynamic>? ?? {};
    }
    throw Exception(json['message'] ?? 'Verification failed');
  }

  static Future<Map<String, dynamic>> payBill({
    required String utilityCode,
    required String meterNumber,
    required String phoneNumber,
    required int amount,
    String? area,
    String? bouquetCode,
    String? customerName,
    String? tokenPhone, // alternate phone to receive electricity token
  }) async {
    final uid = sessionUid;
    if (uid.isEmpty) throw Exception('Not signed in');

    // ── 1. Check wallet balance BEFORE calling the API ──────────────────────
    const int serviceCharge = 1500;
    final total = amount + serviceCharge;
    final wallet = await getWallet(uid);
    final balance = (wallet['balance'] as num?)?.toInt() ?? 0;
    if (total > balance) {
      throw Exception(
          'Insufficient wallet balance. You need UGX ${total - balance} more.');
    }

    // ── 2. Call MarzPay bill-payment API ────────────────────────────────────
    final reference = const Uuid().v4();
    final payload = <String, dynamic>{
      'reference': reference,
      'utility_code': utilityCode,
      'meter_number': meterNumber,
      'phone_number': phoneNumber,
      'amount': amount,
      if (area != null) 'area': area,
      if (bouquetCode != null) 'bouquet_code': bouquetCode,
      if (customerName != null && customerName.isNotEmpty) 'customer_name': customerName,
    };
    final body = await _marzPayRequest('POST', 'bill-payment', payload);
    final json = jsonDecode(body) as Map<String, dynamic>;

    // ── 3. Treat success, completed, pending, processing as accepted ────────
    final apiStatus = (json['status'] as String? ?? '').toLowerCase();
    final txnStatus = (
      json['data']?['transaction']?['status'] as String? ??
      json['data']?['bill_payment']?['status'] as String? ??
      ''
    ).toLowerCase();

    // Bill payments are often async — 'pending' / 'processing' means accepted
    const acceptedStatuses = {
      'success', 'completed', 'complete', 'paid', 'approved',
      'confirmed', 'processed', 'pending', 'processing', 'queued',
      'sandbox',
    };
    final isAccepted = acceptedStatuses.contains(apiStatus) ||
        acceptedStatuses.contains(txnStatus);

    // Hard failures only
    const failStatuses = {'failed', 'fail', 'error', 'rejected', 'cancelled', 'declined'};
    final isFailed = failStatuses.contains(apiStatus) && !isAccepted;

    if (isFailed) {
      throw Exception(json['message'] ?? 'Bill payment failed');
    }

    if (isAccepted) {
      final txn  = json['data']?['transaction']  as Map<String, dynamic>? ?? {};
      final bill = json['data']?['bill_payment']  as Map<String, dynamic>? ?? {};

      final paidAmount  = (bill['amount']?['raw']       as num?)?.toInt() ?? amount;
      final paidCharge  = (bill['charge']?['raw']        as num?)?.toInt() ?? serviceCharge;
      final paidTotal   = (bill['total_amount']?['raw']  as num?)?.toInt() ?? total;
      final resolvedRef = (txn['reference'] as String?)?.isNotEmpty == true
          ? txn['reference'] as String
          : reference;

      // ── 4. Deduct wallet balance ─────────────────────────────────────────
      await _db.collection(AppConstants.walletCol).doc(uid).update({
        'balance': FieldValue.increment(-paidTotal),
        'totalWithdrawn': FieldValue.increment(paidTotal),
      });

      // ── 5. Record bill-payment transaction ───────────────────────────────
      final txnId = const Uuid().v4();
      await _db.collection(AppConstants.walletTxnCol).doc(txnId).set({
        'id': txnId,
        'uid': uid,
        'type': 'bill_payment',
        'utilityCode': utilityCode,
        'meterNumber': meterNumber,
        'amount': paidAmount,
        'charge': paidCharge,
        'total': paidTotal,
        'reference': resolvedRef,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── 6. For electricity: send token-delivery SMS ──────────────────────
      String? tokenSmsPhone;
      if (utilityCode == 'LIGHT') {
        // Prefer alternate phone if provided, else fall back to registered phone
        final profile = _loggedInProfile;
        final registeredPhone = profile?['phone'] as String? ?? '';
        tokenSmsPhone = (tokenPhone != null && tokenPhone.isNotEmpty)
            ? tokenPhone
            : registeredPhone;
        if (tokenSmsPhone.isNotEmpty) {
          final smsNumber = formatPhone(tokenSmsPhone);
          _sendEgoSms(
            smsNumber,
            'Your UEDCL electricity token for meter $meterNumber '
            '(UGX ${amount.toString()}) has been processed. '
            'Your token will be delivered to this number by UEDCL shortly. '
            'Ref: $resolvedRef',
          );
        }
      }

      return {
        'reference': resolvedRef,
        'uuid': txn['uuid'] ?? '',
        'status': 'completed',
        'amount': paidAmount,
        'charge': paidCharge,
        'total': paidTotal,
        'customerName': bill['customer_name'] ?? customerName ?? '',
        'utilityCode': utilityCode,
        'meterNumber': meterNumber,
        if (utilityCode == 'LIGHT' && tokenSmsPhone != null)
          'tokenPhone': tokenSmsPhone,
      };
    }

    // Unknown status — payment was submitted, treat as pending/processing
    // (don't throw — the bill was accepted by the API)
    return {
      'reference': reference,
      'uuid': '',
      'status': 'processing',
      'amount': amount,
      'charge': serviceCharge,
      'total': total,
      'customerName': customerName ?? '',
      'utilityCode': utilityCode,
      'meterNumber': meterNumber,
    };
  }

  // ─── Bank Transfer ───────────────────────────────────────────────────────────

  /// Get list of supported banks for bank transfers
  static Future<List<Map<String, dynamic>>> getBankList() async {
    try {
      final responseBody = await _marzPayRequest('GET', 'bank-transfer/banks', {});
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        final banks = json['data']?['banks'] as List<dynamic>? ?? [];
        return banks.map((b) => b as Map<String, dynamic>).toList();
      }
      throw Exception(json['message'] ?? 'Failed to fetch banks');
    } catch (e) {
      throw Exception('Failed to fetch bank list: $e');
    }
  }

  /// Validate bank account before transfer
  static Future<Map<String, dynamic>> validateBankAccount({
    required String bankName,
    required String accountNumber,
  }) async {
    try {
      final responseBody = await _marzPayRequest('POST', 'bank-transfer/validate', {
        'bank_name': bankName,
        'account_number': accountNumber,
      });
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      // MarzPay may return success with data in multiple structures
      final isSuccess = json['status'] == 'success' || json['status'] == 'completed';
      final data = json['data'] as Map<String, dynamic>? ?? {};

      // Try every possible location for account name
      final accountName = (
        data['account_name'] as String? ??
        data['accountName'] as String? ??
        data['bank_details']?['account_name'] as String? ??
        data['bank_account_name'] as String? ??
        json['account_name'] as String? ??
        ''
      ).trim();

      // Try every possible location for valid flag
      final isValid = (isSuccess && accountName.isNotEmpty) ||
          data['valid'] == true ||
          data['is_valid'] == true ||
          data['account_valid'] == true;

      if (isValid && accountName.isNotEmpty) {
        return {
          'valid': true,
          'account_name': accountName,
          'bank_name': bankName,
          'account_number': accountNumber,
        };
      }

      // Not valid — return gracefully so user can still proceed
      return {
        'valid': false,
        'account_name': '',
        'bank_name': bankName,
        'account_number': accountNumber,
        'error': json['message'] as String? ?? 'Account could not be verified',
        'raw': json, // keep raw for debugging
      };
    } catch (e) {
      return {
        'valid': false,
        'account_name': '',
        'bank_name': bankName,
        'account_number': accountNumber,
        'error': 'Verification unavailable',
      };
    }
  }

  /// Get bank transfer service availability and settings
  static Future<Map<String, dynamic>> getBankTransferSettings() async {
    try {
      final responseBody = await _marzPayRequest('GET', 'bank-transfer/services', {});
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        return json['data'] as Map<String, dynamic>;
      }
      throw Exception(json['message'] ?? 'Failed to fetch settings');
    } catch (e) {
      throw Exception('Failed to fetch bank transfer settings: $e');
    }
  }

  /// Create a bank transfer from wallet to bank account
  static Future<Map<String, dynamic>> createBankTransfer({
    required int amount,
    required String description,
    required String bankName,
    required String bankAccountNumber,
    String? bankAccountName,
    String? bankBranch,
    String walletSource = 'main',
  }) async {
    try {
      final payload = <String, dynamic>{
        'amount': amount,
        'description': description,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'wallet_source': walletSource,
      };
      if (bankAccountName != null) payload['bank_account_name'] = bankAccountName;
      if (bankBranch != null) payload['bank_branch'] = bankBranch;

      final responseBody = await _marzPayRequest('POST', 'bank-transfer', payload);
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      
      // Handle both success and error responses more gracefully
      if (json['status'] == 'success' || json['status'] == 'completed') {
        // Try multiple possible response structures
        final data = json['data']?['bank_transfer'] as Map<String, dynamic>? 
                  ?? json['data'] as Map<String, dynamic>?
                  ?? json;
        
        // Extract reference from multiple possible locations
        final reference = data['reference'] as String? 
                       ?? data['transaction_uuid'] as String?
                       ?? data['uuid'] as String?
                       ?? '';
        
        // Extract status - if money was deducted, it's at least processing
        final status = data['status'] as String? ?? 'processing';
        
        // Extract charge and total amounts with fallback calculations
        final chargeRaw = data['charge_amount']?['raw'] as num?
                       ?? data['charge'] as num?
                       ?? 0;
        final charge = chargeRaw.toInt();
        
        final totalRaw = data['total_amount']?['raw'] as num?
                      ?? data['total'] as num?
                      ?? (amount + charge);
        final total = totalRaw.toInt();
        
        // Extract account name from bank details or use provided name
        final accountName = data['bank_details']?['account_name'] as String?
                         ?? data['account_name'] as String?
                         ?? bankAccountName 
                         ?? '';
        
        return {
          'reference': reference,
          'status': status,
          'amount': amount,
          'charge': charge,
          'total': total,
          'bankName': bankName,
          'accountNumber': bankAccountNumber,
          'accountName': accountName,
        };
      }
      
      // If status is not success, throw with the error message
      final errorMsg = json['message'] as String? ?? 'Bank transfer failed';
      throw Exception(errorMsg);
    } catch (e) {
      // Provide more detailed error information
      if (e.toString().contains('Exception:')) {
        rethrow; // Re-throw our own exceptions
      }
      throw Exception('Failed to create bank transfer: $e');
    }
  }

  // ─── Marz Pay — Airtime & Data Bundles ───────────────────────────────────────

  /// Low-level Marz Pay API request helper.
  /// Routes through the Render proxy to avoid CORS on web and to keep the
  /// Marz Pay API key server-side.
  static Future<Map<String, dynamic>> _marzPayAirtimeRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final base = AppConstants.renderProxyUrl;
    // Call Render proxy directly — it has CORS headers for web and Android.
    final proxyUrl = '$base/marzpay/airtime/$path';
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Proxy-Key': AppConstants.marzPayProxyKey,
      'Cache-Control': 'no-cache, no-store',
    };

    final uri = Uri.parse(proxyUrl);

    try {
      final http.Response res;
      if (method == 'GET') {
        res = await http.get(uri, headers: headers);
      } else {
        res = await http.post(uri, headers: headers, body: jsonEncode(body ?? {}));
      }
      
      // Check if response is JSON
      if (res.body.trim().startsWith('<') || res.body.trim().startsWith('<!DOCTYPE')) {
        throw Exception('Proxy server returned HTML. Status: ${res.statusCode}. Make sure proxy is running and CORS is enabled.');
      }
      
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      if (e.toString().contains('HTML')) rethrow;
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Fetch the full MarzPay airtime-data catalog for Uganda.
  /// Returns the `data` block from the API response.
  static Future<Map<String, dynamic>> getMarzPayCatalog() async {
    try {
      final json = await _marzPayAirtimeRequest('GET', 'catalog');
      if (json['status'] == 'success') {
        return json['data'] as Map<String, dynamic>;
      }
      throw Exception(json['message'] ?? 'Failed to load catalog');
    } catch (e) {
      throw Exception('Failed to load bundles: ${e.toString()}');
    }
  }

  /// Returns bundle list for [productCode] (e.g. 'MTN_UG_INTERNET',
  /// 'AIRTEL_UG_INTERNET').  Lyca has no data bundles.
  ///
  /// Catalog structure (from /airtime-data/catalog):
  ///   data.mtn.bundles.data.items   — MTN data bundles
  ///   data.airtel.bundles.data.items — Airtel data bundles
  static Future<List<Map<String, dynamic>>> getRelworxPriceList(
      String productCode) async {
    try {
      final catalog = await getMarzPayCatalog();

      // Determine which network block to use
      final String networkKey;
      if (productCode.startsWith('MTN')) {
        networkKey = 'mtn';
      } else if (productCode.startsWith('AIRTEL')) {
        networkKey = 'airtel';
      } else {
        throw Exception('No bundles available for this network');
      }

      final networkBlock =
          catalog[networkKey] as Map<String, dynamic>? ?? {};
      final bundlesBlock =
          networkBlock['bundles'] as Map<String, dynamic>? ?? {};

      // Collect all bundle categories (data, voice, combo, weekly, monthly …)
      final allItems = <Map<String, dynamic>>[];
      bundlesBlock.forEach((category, categoryData) {
        if (categoryData is Map) {
          final items = categoryData['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            if (item is Map) {
              allItems.add({
                'code': item['product_id'] ?? '',
                'name': item['name'] ?? item['label'] ?? 'Bundle',
                'amount': (item['price'] as num?)?.toInt() ?? 0,
                'price': (item['price'] as num?)?.toInt() ?? 0,
                'description': item['name'] ?? '',
                'validity': item['validity'] ?? '',
                'category': category,
              });
            }
          }
        }
      });

      if (allItems.isEmpty) {
        throw Exception('No bundles available for this network');
      }

      // Sort: cheapest first
      allItems.sort((a, b) =>
          (a['amount'] as int).compareTo(b['amount'] as int));

      return allItems;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Purchase airtime or a data bundle via Marz Pay, deducting from the wallet.
  ///
  /// MarzPay behaviour:
  ///   MTN & Airtel/Lyca airtime → synchronous (completed/failed in response)
  ///   Airtel data bundles       → may return pending (HTTP 202); poll until final
  ///
  /// [productCode]  — e.g. "MTN_UG_AIRTIME", "AIRTEL_UG_INTERNET"
  /// [phoneNumber]  — recipient phone (Uganda format)
  /// [amount]       — UGX amount for airtime purchases
  /// [priceCode]    — bundle product_id from catalog (for data bundles)
  static Future<Map<String, dynamic>> purchaseAirtimeOrBundle({
    required String productCode,
    required String phoneNumber,
    int amount = 0,        // airtime amount OR bundle price (both required)
    String? priceCode,
  }) async {
    final uid = sessionUid;
    if (uid.isEmpty) throw Exception('Not signed in');

    final isAirtime = productCode.contains('AIRTIME');

    // amount is required for both airtime and bundles
    if (amount <= 0) throw Exception('Please enter a valid amount');

    // ── 1. Check wallet balance upfront for BOTH airtime and bundles ──────
    final wallet = await getWallet(uid);
    final balance = (wallet['balance'] as num?)?.toInt() ?? 0;
    if (amount > balance) {
      throw Exception(
          'Insufficient wallet balance. You need UGX ${_formatCurrency(amount - balance)} more.');
    }

    // ── 2. Build purchase payload ─────────────────────────────────────────
    final reference = const Uuid().v4();
    final purchasePayload = <String, dynamic>{
      'reference': reference,
      'purchase_type': isAirtime ? 'airtime' : 'bundle',
      'msisdn': phoneNumber,
      if (isAirtime) 'amount': amount,
      if (!isAirtime && priceCode != null) 'bundle_id': priceCode,
    };

    // ── 3. Submit to MarzPay via proxy ────────────────────────────────────
    final purchaseJson =
        await _marzPayAirtimeRequest('POST', 'purchase', body: purchasePayload);

    if (purchaseJson['status'] != 'success') {
      throw Exception(
          purchaseJson['message'] as String? ?? 'Purchase failed');
    }

    var data = purchaseJson['data'] as Map<String, dynamic>? ?? {};
    var transactionStatus =
        (data['status'] as String? ?? '').toLowerCase();

    // ── 4. Poll for pending Airtel data bundles (async delivery) ──────────
    if (transactionStatus == 'pending') {
      const maxAttempts = 12;
      const pollInterval = Duration(seconds: 5);
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        await Future.delayed(pollInterval);
        try {
          final statusJson =
              await _marzPayAirtimeRequest('GET', 'status/$reference');
          if (statusJson['status'] == 'success') {
            final statusData =
                statusJson['data'] as Map<String, dynamic>? ?? {};
            final newStatus =
                (statusData['status'] as String? ?? '').toLowerCase();
            if (newStatus != 'pending') {
              data = statusData;
              transactionStatus = newStatus;
              break;
            }
          }
        } catch (_) {
          // ignore transient poll errors; keep polling
        }
      }
    }

    if (transactionStatus == 'failed') {
      final airtimeInfo =
          data['airtime_data'] as Map<String, dynamic>? ?? {};
      final errMsg =
          airtimeInfo['error_message'] as String? ?? 'Purchase failed';
      throw Exception(errMsg);
    }

    if (transactionStatus == 'pending') {
      throw Exception(
          'Purchase is taking longer than expected. Check your transaction history for the final status.');
    }

    // ── 5. Actual cost = what MarzPay charged, fallback to passed amount ──
    final actualCost =
        ((data['amount'] as Map<String, dynamic>?)?['raw'] as num?)
            ?.toInt() ??
        amount;

    // ── 6. Deduct from wallet ─────────────────────────────────────────────
    await _db.collection(AppConstants.walletCol).doc(uid).update({
      'balance': FieldValue.increment(-actualCost),
      'totalWithdrawn': FieldValue.increment(actualCost),
    });

    // Also record a wallet transaction so it shows in transaction history
    final walletTxnId = const Uuid().v4();
    final isBundle = !isAirtime;
    final airtimeDataBlock =
        data['airtime_data'] as Map<String, dynamic>? ?? {};
    final productName = airtimeDataBlock['product_name'] as String? ?? '';
    final network = airtimeDataBlock['network'] as String? ??
        (productCode.startsWith('MTN')
            ? 'MTN'
            : productCode.startsWith('AIRTEL')
                ? 'AIRTEL'
                : 'LYCA');
    await _db.collection(AppConstants.walletTxnCol).doc(walletTxnId).set({
      'id': walletTxnId,
      'uid': uid,
      'type': 'debit',
      'amount': actualCost,
      'description': isBundle
          ? '$network Bundle${productName.isNotEmpty ? ' — $productName' : ''}'
          : '$network Airtime — $phoneNumber',
      'phone': phoneNumber,
      'status': 'completed',
      'category': isBundle ? 'bundle' : 'airtime',
      'network': network,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ── 7. Record airtime transaction ─────────────────────────────────────
    final txnId = const Uuid().v4();
    final marzUuid = data['uuid'] as String? ?? '';
    final providerRef = data['provider_reference'] as String? ?? '';

    await _db.collection(AppConstants.airtimeTxnCol).doc(txnId).set({
      'id': txnId,
      'uid': uid,
      'productCode': productCode,
      'phoneNumber': phoneNumber,
      'amount': actualCost,
      'reference': reference,
      'marzUuid': marzUuid,
      'providerReference': providerRef,
      if (priceCode != null) 'bundleId': priceCode,
      'purchaseType': isAirtime ? 'airtime' : 'bundle',
      'network': network,
      'productName': productName,
      'status': 'completed',
      'provider': 'marzpay',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'success': true,
      'txnId': txnId,
      'reference': reference,
      'marzUuid': marzUuid,
      'providerReference': providerRef,
      'amount': actualCost,
      'productCode': productCode,
      'phoneNumber': phoneNumber,
      'message':
          purchaseJson['message'] as String? ?? 'Purchase successful',
    };
  }

  /// Get airtime/data transaction history for a user.
  static Future<List<Map<String, dynamic>>> getAirtimeTransactions(
      String uid) async {
    final keys = _uidKeys(uid);
    for (int i = 0; i < 3; i++) {
      try {
        final allDocs = <Map<String, dynamic>>[];
        final seenIds = <String>{};
        for (final key in keys) {
          final q = await _db
              .collection(AppConstants.airtimeTxnCol)
              .where('uid', isEqualTo: key)
              .get(const GetOptions(source: Source.server));
          for (final doc in q.docs) {
            if (seenIds.add(doc.id)) allDocs.add(doc.data());
          }
        }
        allDocs.sort((a, b) {
          final ta = a['createdAt'];
          final tb = b['createdAt'];
          if (ta == null || tb == null) return 0;
          return (tb as Timestamp).compareTo(ta as Timestamp);
        });
        return allDocs;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return [];
  }

  /// Check bank transfer status by reference
  static Future<Map<String, dynamic>> checkBankTransferStatus(String reference) async {
    try {
      final responseBody = await _marzPayRequest(
        'GET',
        'bank-transfer/$reference',
        {},
      );
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      
      if (json['status'] == 'success') {
        final data = json['data']?['bank_transfer_request'] as Map<String, dynamic>?;
        if (data == null) throw Exception('Invalid response format');
        return {
          'status': data['status'] ?? 'unknown',
          'amount': (data['amount']?['raw'] as num?)?.toInt() ?? 0,
          'charge': (data['charge_amount']?['raw'] as num?)?.toInt() ?? 0,
          'total': (data['total_amount']?['raw'] as num?)?.toInt() ?? 0,
          'description': data['description'] ?? '',
          'bankDetails': data['bank_details'] ?? {},
          'createdAt': data['timeline']?['created_at'] ?? '',
        };
      }
      throw Exception(json['message'] ?? 'Failed to check status');
    } catch (e) {
      throw Exception('Failed to check bank transfer status: $e');
    }
  }

  // ─── SAVINGS MANAGEMENT ──────────────────────────────────────────────────

  /// Deposit money to savings account (SECURE - requires PIN + OTP)
  static Future<void> depositToSavings({
    required String uid,
    required int amount,
    required String savingsType,
    required String pin,
    required String otpCode,
    String? description,
  }) async {
    // 1. Verify PIN first using proper hashed verification
    if (!await verifyPin(uid, pin)) {
      throw Exception('Invalid PIN. Transaction cancelled for security.');
    }

    final profile = await getUserProfile(uid);
    if (profile == null) throw Exception('User not found');

    // 2. Verify OTP
    final phone = profile['phone'] as String?;
    if (phone == null) throw Exception('Phone number not found');
    
    final normalizedPhone = formatPhone(phone);
    if (!_otpStore.containsKey(normalizedPhone)) {
      throw Exception('No OTP found. Please request a new OTP.');
    }
    
    final otpData = _otpStore[normalizedPhone]!;
    final storedOtp = otpData['code'] as String;
    final expiry = otpData['expiry'] as DateTime;
    
    if (DateTime.now().isAfter(expiry)) {
      _otpStore.remove(normalizedPhone);
      throw Exception('OTP expired. Please request a new OTP.');
    }
    
    if (storedOtp != otpCode) {
      throw Exception('Invalid OTP. Transaction cancelled for security.');
    }

    // 3. Check wallet balance (deduct from wallet)
    final walletDoc = await _db.collection(AppConstants.walletCol).doc(uid).get();
    if (!walletDoc.exists) {
      throw Exception('Wallet not found. Please contact support.');
    }
    
    final walletBalance = (walletDoc.data()?['balance'] as int?) ?? 0;
    if (walletBalance < amount) {
      throw Exception('Insufficient wallet balance. Current balance: UGX ${_formatCurrency(walletBalance)}');
    }

    // 4. All verifications passed - proceed with transaction
    final batch = _db.batch();
    final savingsId = const Uuid().v4();
    final now = DateTime.now();

    // Deduct from wallet
    final walletRef = _db.collection(AppConstants.walletCol).doc(uid);
    batch.update(walletRef, {
      'balance': FieldValue.increment(-amount),
    });

    // Record wallet transaction
    final walletTxnId = const Uuid().v4();
    final walletTxnRef = _db.collection(AppConstants.walletTxnCol).doc(walletTxnId);
    batch.set(walletTxnRef, {
      'id': walletTxnId,
      'uid': uid,
      'type': 'debit',
      'amount': amount,
      'description': 'Transfer to $savingsType savings',
      'timestamp': FieldValue.serverTimestamp(),
      'timestampLocal': now.toIso8601String(),
      'status': 'completed',
      'category': 'savings_transfer',
    });

    // Create savings transaction (AUTOMATICALLY APPROVED)
    final savingsTxnRef = _db.collection(AppConstants.savingsTxnCol).doc(savingsId);
    batch.set(savingsTxnRef, {
      'id': savingsId,
      'uid': uid,
      'memberId': uid, // For admin queries
      'memberName': profile['name'] ?? profile['fullName'] ?? profile['firstName'] ?? 
                    (uid.length >= 8 ? 'Member ${uid.substring(0, 8)}' : 'Member $uid'),
      'memberPhone': phone,
      'memberNumber': profile['memberNumber'] ?? profile['memberNo'] ?? '',
      'type': 'deposit',
      'amount': amount,
      'savingsType': savingsType,
      'description': description ?? 'Savings deposit via mobile app',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(), // For compatibility
      'timestampLocal': now.toIso8601String(),
      'status': 'Approved', // AUTOMATICALLY APPROVED
      'approvedAt': FieldValue.serverTimestamp(),
      'autoApproved': true, // Flag to show it was auto-approved
      'securityVerified': true,
      'verificationMethod': 'PIN+OTP',
    });

    // Update or create savings account
    final savingsRef = _db.collection(AppConstants.savingsCol).doc(uid);
    final savingsDoc = await savingsRef.get();
    
    if (savingsDoc.exists) {
      batch.update(savingsRef, {
        'totalBalance': FieldValue.increment(amount),
        '${savingsType.toLowerCase()}Balance': FieldValue.increment(amount),
        'lastDeposit': amount,
        'lastDepositDate': FieldValue.serverTimestamp(),
        'transactionCount': FieldValue.increment(1),
      });
    } else {
      batch.set(savingsRef, {
        'uid': uid,
        'totalBalance': amount,
        '${savingsType.toLowerCase()}Balance': amount,
        'voluntaryBalance': savingsType == 'Voluntary' ? amount : 0,
        'compulsoryBalance': savingsType == 'Compulsory' ? amount : 0,
        'lastDeposit': amount,
        'lastDepositDate': FieldValue.serverTimestamp(),
        'transactionCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // 5. Clear used OTP
    _otpStore.remove(normalizedPhone);

    // 6. Get updated balance for confirmation
    final updatedSavings = await getSavingsAccount(uid);
    final newBalance = updatedSavings?['${savingsType.toLowerCase()}Balance'] ?? amount;
    final totalBalance = updatedSavings?['totalBalance'] ?? amount;

    // 7. Log audit trail
    await AuditService.log(
      action: AuditService.kSavingsDeposit,
      description: 'SECURE: Deposited UGX ${_formatCurrency(amount)} to $savingsType savings (PIN+OTP verified)',
      targetId: uid,
      targetName: profile['name'] as String?,
      meta: {
        'amount': amount, 
        'savingsType': savingsType,
        'securityLevel': 'HIGH',
        'verificationMethod': 'PIN+OTP'
      },
    );

    // 8. Send confirmation SMS with actual balance
    final saccoName = SaccoService.current.saccoName;
    await sendSmsToPhone(
      phone,
      '$saccoName: UGX ${_formatCurrency(amount)} deposited to your $savingsType savings. Your $savingsType balance is now UGX ${_formatCurrency(newBalance)}. Total savings: UGX ${_formatCurrency(totalBalance)}. Thank you!'
    );
  }

  // ─── SAVINGS WITHDRAWAL ───────────────────────────────────────────────────

  /// Withdraw from savings — to wallet or directly to mobile money.
  /// Charges [AppConstants.walletWithdrawChargePercent] (3.5%) on the amount.
  static Future<Map<String, dynamic>> withdrawFromSavings({
    required String uid,
    required int amount,
    required String savingsType,   // 'Voluntary' | 'Compulsory'
    required String pin,
    required String otpCode,
    required String destination,   // 'wallet' | 'mobile_money'
    String? description,
  }) async {
    // 1. Verify PIN
    if (!await verifyPin(uid, pin)) {
      throw Exception('Invalid PIN. Transaction cancelled for security.');
    }

    final profile = await getUserProfile(uid);
    if (profile == null) throw Exception('User not found');

    final phone = profile['phone'] as String?;
    if (phone == null) throw Exception('Phone number not found');

    // 2. Verify OTP
    final normalizedPhone = formatPhone(phone);
    final otpData = _otpStore[normalizedPhone];
    if (otpData == null) throw Exception('No OTP found. Please request a new OTP.');
    final expiry = otpData['expiry'] as DateTime;
    if (DateTime.now().isAfter(expiry)) {
      _otpStore.remove(normalizedPhone);
      throw Exception('OTP expired. Please request a new OTP.');
    }
    if (otpData['code'] != otpCode) {
      throw Exception('Invalid OTP. Transaction cancelled for security.');
    }
    _otpStore.remove(normalizedPhone); // one-time use

    // 3. Check savings balance
    final savingsDoc = await getSavingsAccount(uid);
    final balanceKey = '${savingsType.toLowerCase()}Balance';
    final savingsBalance = (savingsDoc?[balanceKey] as num?)?.toInt() ?? 0;
    if (savingsBalance < amount) {
      throw Exception(
          'Insufficient $savingsType savings. Available: UGX ${_formatCurrency(savingsBalance)}');
    }

    // 4. Calculate charge (12%)
    final charge = (amount * AppConstants.walletWithdrawChargePercent)
        .ceil()
        .clamp(AppConstants.walletMinCharge, 999999);
    final netAmount = amount - charge; // what user actually receives

    // 5. Deduct from savings balance
    final batch = _db.batch();
    final savingsRef = _db.collection(AppConstants.savingsCol).doc(uid);
    batch.set(savingsRef, {
      balanceKey: FieldValue.increment(-amount),
      'totalBalance': FieldValue.increment(-amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 6. Record savings withdrawal transaction
    final txnId = const Uuid().v4();
    final txnRef = _db.collection(AppConstants.savingsTxnCol).doc(txnId);
    batch.set(txnRef, {
      'id': txnId,
      'uid': uid,
      'memberId': uid,
      'memberName': profile['name'] ?? profile['fullName'] ?? 'Member',
      'memberPhone': phone,
      'memberNumber': profile['memberNumber'] ?? '',
      'type': 'withdrawal',
      'txnType': 'debit',
      'amount': amount,
      'charge': charge,
      'netAmount': netAmount,
      'savingsType': savingsType,
      'destination': destination,
      'description': description ?? 'Savings withdrawal',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'Approved',
      'autoApproved': true,
      'securityVerified': true,
      'verificationMethod': 'PIN+OTP',
    });

    await batch.commit();

    // 7. Credit destination
    if (destination == 'wallet') {
      // Credit net amount to wallet
      await _db.collection(AppConstants.walletCol).doc(uid).set({
        'uid': uid,
        'balance': FieldValue.increment(netAmount),
        'totalDeposited': FieldValue.increment(netAmount),
      }, SetOptions(merge: true));

      // Record wallet credit transaction
      final walletTxnId = const Uuid().v4();
      await _db.collection(AppConstants.walletTxnCol).doc(walletTxnId).set({
        'id': walletTxnId,
        'uid': uid,
        'type': 'credit',
        'amount': netAmount,
        'charge': charge,
        'description': 'Savings withdrawal to wallet ($savingsType)',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'category': 'savings_withdrawal',
      });
    }
    // mobile_money: caller handles MarzPay disbursement separately

    // 8. Audit log
    await AuditService.log(
      action: 'SAVINGS_WITHDRAWAL',
      description: 'Withdrew UGX ${_formatCurrency(amount)} from $savingsType savings to $destination (charge: UGX ${_formatCurrency(charge)})',
      targetId: uid,
      targetName: profile['name'] as String?,
      meta: {
        'amount': amount,
        'charge': charge,
        'netAmount': netAmount,
        'savingsType': savingsType,
        'destination': destination,
      },
    );

    // 9. SMS confirmation
    final saccoName = SaccoService.current.saccoName;
    await sendSmsToPhone(
      phone,
      '$saccoName: UGX ${_formatCurrency(netAmount)} withdrawn from your $savingsType savings (charge: UGX ${_formatCurrency(charge)}). Destination: $destination. Thank you!',
    );

    return {
      'txnId': txnId,
      'amount': amount,
      'charge': charge,
      'netAmount': netAmount,
      'destination': destination,
    };
  }

  /// Get savings account details
  static Future<Map<String, dynamic>?> getSavingsAccount(String uid) async {
    final uidsToTry = _uidKeys(uid);

    for (final uidKey in uidsToTry) {
      try {
        final doc = await _db
            .collection(AppConstants.savingsCol)
            .doc(uidKey)
            .get(const GetOptions(source: Source.server));
        if (doc.exists) return doc.data();
      } catch (e) {
        print('ERROR getSavingsAccount for $uidKey: $e');
      }
    }

    // Return zeroed structure so UI doesn't crash
    return {
      'uid': uid,
      'totalBalance': 0,
      'voluntaryBalance': 0,
      'compulsoryBalance': 0,
      'transactionCount': 0,
    };
  }

  /// Get savings transactions
  static Future<List<Map<String, dynamic>>> getSavingsTransactions(String uid) async {
    final uidsToTry = _uidKeys(uid);
    final allTransactions = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final uidKey in uidsToTry) {
      try {
        // No orderBy — avoids needing a composite index
        final query = await _db
            .collection(AppConstants.savingsTxnCol)
            .where('uid', isEqualTo: uidKey)
            .get(const GetOptions(source: Source.server));

        for (final doc in query.docs) {
          if (seenIds.add(doc.id)) {
            allTransactions.add(doc.data());
          }
        }
      } catch (e) {
        print('ERROR getSavingsTransactions for $uidKey: $e');
      }
    }

    // Sort client-side — no index needed
    allTransactions.sort((a, b) {
      final ta = a['timestamp'] ?? a['createdAt'];
      final tb = b['timestamp'] ?? b['createdAt'];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return (tb as Timestamp).compareTo(ta as Timestamp);
    });

    return allTransactions;
  }

  // ─── SHARES MANAGEMENT ────────────────────────────────────────────────────

  /// Purchase shares (SECURE - requires PIN + OTP + wallet deduction)
  static Future<void> purchaseShares({
    required String uid,
    required int numberOfShares,
    required int pricePerShare,
    required String pin,
    required String otpCode,
    String? description,
  }) async {
    final totalAmount = numberOfShares * pricePerShare;

    // 1. Verify PIN first using proper hashed verification
    if (!await verifyPin(uid, pin)) {
      throw Exception('Invalid PIN. Transaction cancelled for security.');
    }

    final profile = await getUserProfile(uid);
    if (profile == null) throw Exception('User not found');

    // 2. Verify OTP
    final phone = profile['phone'] as String?;
    if (phone == null) throw Exception('Phone number not found');
    
    final normalizedPhone = formatPhone(phone);
    if (!_otpStore.containsKey(normalizedPhone)) {
      throw Exception('No OTP found. Please request a new OTP.');
    }
    
    final otpData = _otpStore[normalizedPhone]!;
    final storedOtp = otpData['code'] as String;
    final expiry = otpData['expiry'] as DateTime;
    
    if (DateTime.now().isAfter(expiry)) {
      _otpStore.remove(normalizedPhone);
      throw Exception('OTP expired. Please request a new OTP.');
    }
    
    if (storedOtp != otpCode) {
      throw Exception('Invalid OTP. Transaction cancelled for security.');
    }

    // 3. Check wallet balance
    final walletDoc = await _db.collection(AppConstants.walletCol).doc(uid).get();
    if (!walletDoc.exists) {
      throw Exception('Wallet not found. Please contact support.');
    }
    
    final walletBalance = (walletDoc.data()?['balance'] as int?) ?? 0;
    if (walletBalance < totalAmount) {
      throw Exception('Insufficient wallet balance. Required: UGX ${_formatCurrency(totalAmount)}, Available: UGX ${_formatCurrency(walletBalance)}');
    }

    // 4. All verifications passed - proceed with transaction
    final batch = _db.batch();
    final shareId = const Uuid().v4();
    final now = DateTime.now();

    // Deduct from wallet
    final walletRef = _db.collection(AppConstants.walletCol).doc(uid);
    batch.update(walletRef, {
      'balance': FieldValue.increment(-totalAmount),
    });

    // Record wallet transaction
    final walletTxnId = const Uuid().v4();
    final walletTxnRef = _db.collection(AppConstants.walletTxnCol).doc(walletTxnId);
    batch.set(walletTxnRef, {
      'id': walletTxnId,
      'uid': uid,
      'type': 'debit',
      'amount': totalAmount,
      'description': 'Share purchase - $numberOfShares shares',
      'timestamp': FieldValue.serverTimestamp(),
      'timestampLocal': now.toIso8601String(),
      'status': 'completed',
      'category': 'share_purchase',
    });

    // Create share transaction
    final sharesTxnRef = _db.collection(AppConstants.sharesCol).doc(shareId);
    batch.set(sharesTxnRef, {
      'id': shareId,
      'uid': uid,
      'type': 'purchase',
      'numberOfShares': numberOfShares,
      'pricePerShare': pricePerShare,
      'totalAmount': totalAmount,
      'description': description ?? 'Share purchase via mobile app',
      'timestamp': FieldValue.serverTimestamp(),
      'timestampLocal': now.toIso8601String(),
      'status': 'completed',
      'securityVerified': true,
      'verificationMethod': 'PIN+OTP',
    });

    // Update member's share holdings
    final memberSharesRef = _db.collection(AppConstants.usersCol).doc(uid);
    final memberDoc = await memberSharesRef.get();
    final currentShares = (memberDoc.data()?['totalShares'] as int?) ?? 0;
    
    batch.update(memberSharesRef, {
      'totalShares': currentShares + numberOfShares,
      'shareValue': (currentShares + numberOfShares) * pricePerShare,
      'lastSharePurchase': numberOfShares,
      'lastSharePurchaseDate': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 5. Clear used OTP
    _otpStore.remove(normalizedPhone);

    // 6. Log audit trail
    await AuditService.log(
      action: AuditService.kSharePurchase,
      description: 'SECURE: Purchased $numberOfShares shares for UGX ${_formatCurrency(totalAmount)} (PIN+OTP verified)',
      targetId: uid,
      targetName: profile['name'] as String?,
      meta: {
        'numberOfShares': numberOfShares, 
        'totalAmount': totalAmount,
        'securityLevel': 'HIGH',
        'verificationMethod': 'PIN+OTP'
      },
    );

    // 7. Send confirmation SMS
    final saccoName = SaccoService.current.saccoName;
    await sendSmsToPhone(
      phone,
      '$saccoName: You purchased $numberOfShares shares for UGX ${_formatCurrency(totalAmount)}. Your shareholding has been updated. Thank you!'
    );
  }

  /// Get member's share holdings
  static Future<Map<String, dynamic>> getShareHoldings(String uid) async {
    // Get member's total shares from profile
    final memberDoc = await _db.collection(AppConstants.usersCol).doc(uid).get();
    final memberData = memberDoc.data() ?? {};
    
    // Get share transactions
    final txnQuery = await _db
        .collection(AppConstants.sharesCol)
        .where('uid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    
    final transactions = txnQuery.docs.map((doc) => doc.data()).toList();
    
    return {
      'totalShares': memberData['totalShares'] ?? 0,
      'shareValue': memberData['shareValue'] ?? 0,
      'transactions': transactions,
    };
  }

  // ─── FIXED DEPOSITS MANAGEMENT ────────────────────────────────────────────

  /// Approve fixed deposit
  static Future<void> approveFD({
    required String fdId,
    required String adminUid,
    String? notes,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();

    // 1. Update FD status
    final fdRef = _db.collection(AppConstants.fixedDepositCol).doc(fdId);
    final fdDoc = await fdRef.get();
    
    if (!fdDoc.exists) {
      throw Exception('Fixed deposit not found');
    }
    
    final fdData = fdDoc.data()!;
    final principal = fdData['principal'] as int;
    final termMonths = fdData['termMonths'] as int;
    final interestRate = fdData['interestRate'] as double;
    
    // Calculate maturity date and amount
    final maturityDate = now.add(Duration(days: termMonths * 30));
    final interestAmount = (principal * interestRate * termMonths / 12 / 100).round();
    final maturityAmount = principal + interestAmount;

    batch.update(fdRef, {
      'status': 'Active',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvalNotes': notes,
      'maturityDate': Timestamp.fromDate(maturityDate),
      'maturityAmount': maturityAmount,
      'interestAmount': interestAmount,
    });

    await batch.commit();

    // 2. Log audit trail
    await AuditService.log(
      action: AuditService.kFdApproved,
      description: 'Approved fixed deposit of UGX ${_formatCurrency(principal)}',
      targetId: fdId,
      targetName: fdData['memberName'] as String?,
      meta: {'principal': principal, 'maturityAmount': maturityAmount},
    );

    // 3. Send notification to member
    await sendNotification(
      fdData['uid'] as String,
      'Fixed Deposit Approved',
      'Your fixed deposit of UGX ${_formatCurrency(principal)} has been approved and is now active.',
    );
  }

  /// Reject fixed deposit
  static Future<void> rejectFD({
    required String fdId,
    required String adminUid,
    required String reason,
  }) async {
    final batch = _db.batch();

    // 1. Update FD status
    final fdRef = _db.collection(AppConstants.fixedDepositCol).doc(fdId);
    final fdDoc = await fdRef.get();
    
    if (!fdDoc.exists) {
      throw Exception('Fixed deposit not found');
    }
    
    final fdData = fdDoc.data()!;

    batch.update(fdRef, {
      'status': 'Rejected',
      'rejectedBy': adminUid,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });

    await batch.commit();

    // 2. Log audit trail
    await AuditService.log(
      action: AuditService.kFdRejected,
      description: 'Rejected fixed deposit: $reason',
      targetId: fdId,
      targetName: fdData['memberName'] as String?,
      meta: {'reason': reason},
    );

    // 3. Send notification to member
    await sendNotification(
      fdData['uid'] as String,
      'Fixed Deposit Rejected',
      'Your fixed deposit application was rejected. Reason: $reason',
    );
  }

  /// Get all fixed deposits for admin
  static Future<List<Map<String, dynamic>>> getAllFixedDeposits() async {
    final query = await _db
        .collection(AppConstants.fixedDepositCol)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  /// Create fixed deposit (SECURE - requires PIN + OTP + wallet deduction)
  static Future<void> createFixedDeposit({
    required String uid,
    required int principal,
    required int termMonths,
    required double interestRate,
    required String pin,
    required String otpCode,
    bool rollover = false,
    String? description,
  }) async {
    // 1. Verify PIN first using proper hashed verification
    if (!await verifyPin(uid, pin)) {
      throw Exception('Invalid PIN. Transaction cancelled for security.');
    }

    final profile = await getUserProfile(uid);
    if (profile == null) throw Exception('User not found');

    // 2. Verify OTP
    final phone = profile['phone'] as String?;
    if (phone == null) throw Exception('Phone number not found');
    
    final normalizedPhone = formatPhone(phone);
    if (!_otpStore.containsKey(normalizedPhone)) {
      throw Exception('No OTP found. Please request a new OTP.');
    }
    
    final otpData = _otpStore[normalizedPhone]!;
    final storedOtp = otpData['code'] as String;
    final expiry = otpData['expiry'] as DateTime;
    
    if (DateTime.now().isAfter(expiry)) {
      _otpStore.remove(normalizedPhone);
      throw Exception('OTP expired. Please request a new OTP.');
    }
    
    if (storedOtp != otpCode) {
      throw Exception('Invalid OTP. Transaction cancelled for security.');
    }

    // 3. Check wallet balance
    final walletDoc = await _db.collection(AppConstants.walletCol).doc(uid).get();
    if (!walletDoc.exists) {
      throw Exception('Wallet not found. Please contact support.');
    }
    
    final walletBalance = (walletDoc.data()?['balance'] as int?) ?? 0;
    if (walletBalance < principal) {
      throw Exception('Insufficient wallet balance. Required: UGX ${_formatCurrency(principal)}, Available: UGX ${_formatCurrency(walletBalance)}');
    }

    // 4. All verifications passed - proceed with transaction
    final batch = _db.batch();
    final fdId = const Uuid().v4();
    final now = DateTime.now();
    final maturityDate = now.add(Duration(days: termMonths * 30));
    final interestAmount = (principal * interestRate * termMonths / 12 / 100).round();
    final maturityAmount = principal + interestAmount;

    // Deduct from wallet
    final walletRef = _db.collection(AppConstants.walletCol).doc(uid);
    batch.update(walletRef, {
      'balance': FieldValue.increment(-principal),
    });

    // Record wallet transaction
    final walletTxnId = const Uuid().v4();
    final walletTxnRef = _db.collection(AppConstants.walletTxnCol).doc(walletTxnId);
    batch.set(walletTxnRef, {
      'id': walletTxnId,
      'uid': uid,
      'type': 'debit',
      'amount': principal,
      'description': 'Fixed deposit creation - ${termMonths} months',
      'timestamp': FieldValue.serverTimestamp(),
      'timestampLocal': now.toIso8601String(),
      'status': 'completed',
      'category': 'fixed_deposit',
    });

    // Create fixed deposit
    final fdRef = _db.collection(AppConstants.fixedDepositCol).doc(fdId);
    batch.set(fdRef, {
      'id': fdId,
      'uid': uid,
      'memberName': profile['name'] ?? profile['fullName'] ?? profile['firstName'] ?? 
                    (uid.length >= 8 ? 'Member ${uid.substring(0, 8)}' : 'Member $uid'),
      'principal': principal,
      'termMonths': termMonths,
      'interestRate': interestRate,
      'interestAmount': interestAmount,
      'maturityAmount': maturityAmount,
      'maturityDate': Timestamp.fromDate(maturityDate),
      'rollover': rollover,
      'description': description ?? 'Fixed deposit via mobile app',
      'status': 'Pending', // Requires admin approval
      'createdAt': FieldValue.serverTimestamp(),
      'securityVerified': true,
      'verificationMethod': 'PIN+OTP',
    });

    await batch.commit();

    // 5. Clear used OTP
    _otpStore.remove(normalizedPhone);

    // 6. Log audit trail
    await AuditService.log(
      action: 'FD_CREATED',
      description: 'SECURE: Created fixed deposit of UGX ${_formatCurrency(principal)} for ${termMonths} months (PIN+OTP verified)',
      targetId: uid,
      targetName: profile['name'] as String?,
      meta: {
        'principal': principal,
        'termMonths': termMonths,
        'interestRate': interestRate,
        'maturityAmount': maturityAmount,
        'securityLevel': 'HIGH',
        'verificationMethod': 'PIN+OTP'
      },
    );

    // 7. Send confirmation SMS
    final saccoName = SaccoService.current.saccoName;
    await sendSmsToPhone(
      phone,
      '$saccoName: Fixed deposit of UGX ${_formatCurrency(principal)} created for ${termMonths} months. Pending admin approval. Thank you!'
    );
  }

  /// Process matured fixed deposits (call this periodically)
  static Future<void> processMaturedFDs() async {
    final now = Timestamp.now();
    final query = await _db
        .collection(AppConstants.fixedDepositCol)
        .where('status', isEqualTo: 'Active')
        .where('maturityDate', isLessThanOrEqualTo: now)
        .get();

    final batch = _db.batch();
    
    for (final doc in query.docs) {
      final fdData = doc.data();
      final fdRef = doc.reference;
      
      // Mark as matured
      batch.update(fdRef, {
        'status': 'Matured',
        'maturedAt': FieldValue.serverTimestamp(),
      });

      // Log audit
      await AuditService.log(
        action: AuditService.kFdMatured,
        description: 'Fixed deposit matured - UGX ${_formatCurrency(fdData['maturityAmount'] as int)}',
        targetId: doc.id,
        targetName: fdData['memberName'] as String?,
        meta: {'maturityAmount': fdData['maturityAmount']},
      );

      // Notify member
      await sendNotification(
        fdData['uid'] as String,
        'Fixed Deposit Matured',
        'Your fixed deposit has matured. Amount: UGX ${_formatCurrency(fdData['maturityAmount'] as int)}',
      );
    }

    await batch.commit();
  }

  // ─── INTEREST CALCULATION ENGINE ──────────────────────────────────────────

  /// Calculate and apply interest to savings accounts
  static Future<void> calculateSavingsInterest() async {
    final savingsQuery = await _db.collection(AppConstants.savingsCol).get();
    final batch = _db.batch();
    final now = DateTime.now();

    for (final doc in savingsQuery.docs) {
      final savingsData = doc.data();
      final uid = savingsData['uid'] as String;
      final totalBalance = (savingsData['totalBalance'] as int?) ?? 0;
      
      if (totalBalance <= 0) continue;

      // Calculate monthly interest (example: 2% per annum = 0.167% per month)
      const annualRate = 2.0; // 2% per annum
      const monthlyRate = annualRate / 12 / 100;
      final interestAmount = (totalBalance * monthlyRate).round();

      if (interestAmount > 0) {
        // Add interest to savings
        batch.update(doc.reference, {
          'totalBalance': FieldValue.increment(interestAmount),
          'voluntaryBalance': FieldValue.increment(interestAmount),
          'lastInterestAmount': interestAmount,
          'lastInterestDate': FieldValue.serverTimestamp(),
        });

        // Record interest transaction
        final interestId = const Uuid().v4();
        final interestTxnRef = _db.collection(AppConstants.savingsTxnCol).doc(interestId);
        batch.set(interestTxnRef, {
          'id': interestId,
          'uid': uid,
          'type': 'interest',
          'amount': interestAmount,
          'savingsType': 'Interest',
          'description': 'Monthly savings interest',
          'timestamp': FieldValue.serverTimestamp(),
          'timestampLocal': now.toIso8601String(),
          'status': 'completed',
        });
      }
    }

    await batch.commit();
  }

  // ─── DIVIDEND DISTRIBUTION ────────────────────────────────────────────────

  /// Distribute dividends to all shareholders
  static Future<void> distributeDividends({
    required double dividendPerShare,
    required String description,
    required String adminUid,
  }) async {
    // Get all members with shares
    final membersQuery = await _db
        .collection(AppConstants.usersCol)
        .where('totalShares', isGreaterThan: 0)
        .get();

    final batch = _db.batch();
    final now = DateTime.now();
    final dividendId = const Uuid().v4();

    int totalSharesDistributed = 0;
    int totalAmountDistributed = 0;

    for (final memberDoc in membersQuery.docs) {
      final memberData = memberDoc.data();
      final uid = memberData['uid'] as String;
      final totalShares = (memberData['totalShares'] as int?) ?? 0;
      
      if (totalShares <= 0) continue;

      final dividendAmount = (totalShares * dividendPerShare).round();
      
      // Record dividend transaction
      final memberDividendId = '${dividendId}_$uid';
      final dividendRef = _db.collection(AppConstants.dividendsCol).doc(memberDividendId);
      batch.set(dividendRef, {
        'id': memberDividendId,
        'dividendBatchId': dividendId,
        'uid': uid,
        'memberName': memberData['name'],
        'totalShares': totalShares,
        'dividendPerShare': dividendPerShare,
        'dividendAmount': dividendAmount,
        'description': description,
        'distributedBy': adminUid,
        'timestamp': FieldValue.serverTimestamp(),
        'timestampLocal': now.toIso8601String(),
        'status': 'distributed',
      });

      // Add dividend to member's savings (or wallet)
      final savingsRef = _db.collection(AppConstants.savingsCol).doc(uid);
      batch.set(savingsRef, {
        'totalBalance': FieldValue.increment(dividendAmount),
        'voluntaryBalance': FieldValue.increment(dividendAmount),
        'lastDividend': dividendAmount,
        'lastDividendDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send notification
      await sendNotification(
        uid,
        'Dividend Distributed',
        'You received UGX ${_formatCurrency(dividendAmount)} dividend for $totalShares shares.',
      );

      totalSharesDistributed += totalShares;
      totalAmountDistributed += dividendAmount;
    }

    await batch.commit();

    // Log audit trail
    await AuditService.log(
      action: 'DIVIDEND_DISTRIBUTED',
      description: 'Distributed UGX ${_formatCurrency(totalAmountDistributed)} to $totalSharesDistributed shares',
      meta: {
        'dividendPerShare': dividendPerShare,
        'totalAmount': totalAmountDistributed,
        'totalShares': totalSharesDistributed,
        'description': description,
      },
    );
  }

  // ─── UTILITY METHODS ──────────────────────────────────────────────────────

  /// Format currency for display
  static String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

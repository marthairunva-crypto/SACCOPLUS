import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/firebase_service.dart';
import '../core/constants.dart';
import '../models/till_session.dart';
import '../models/till_entry.dart';

/// Custom exceptions for till operations
class TillClosedException implements Exception {
  final String message;
  TillClosedException(this.message);
  @override
  String toString() => 'TillClosedException: $message';
}

class InsufficientCashException implements Exception {
  final String message;
  final int required;
  final int available;
  InsufficientCashException(this.message, this.required, this.available);
  @override
  String toString() => 'InsufficientCashException: $message (required: $required, available: $available)';
}

class NoOpenSessionException implements Exception {
  final String message;
  NoOpenSessionException(this.message);
  @override
  String toString() => 'NoOpenSessionException: $message';
}

/// Service for managing till sessions and cash handling.
/// Single source of truth for all till operations.
/// All cash transactions MUST go through this service.
class TillService {
  static final _db = FirebaseFirestore.instance;

  // Use FirebaseService.sessionTenantId for consistency
  static String get _tenantId => FirebaseService.sessionTenantId;

  // Variance tolerance in UGX (±5000)
  static const int varianceTolerance = 5000;

  // ─── Open Till Session ────────────────────────────────────────────────────
  /// Opens a new till session for the teller.
  /// Throws if teller already has an open session.
  static Future<TillSession> openSession({
    required String tellerId,
    required String tellerName,
    required int openingFloat,
    String? notes,
  }) async {
    try {
      // Check if teller already has an open session
      final existingQuery = await _db
          .collection(AppConstants.tillSessionsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('tellerId', isEqualTo: tellerId)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('Teller already has an open till session');
      }

      final now = DateTime.now();
      final businessDate = _formatBusinessDate(now);
      final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc();

      final session = TillSession(
        id: sessionRef.id,
        tenantId: _tenantId,
        tellerId: tellerId,
        tellerName: tellerName,
        businessDate: businessDate,
        status: 'open',
        openingFloat: openingFloat,
        totalIn: 0,
        totalOut: 0,
        openedAt: now,
        notes: notes,
      );

      await sessionRef.set(session.toFirestore());

      // Post opening float entry if > 0
      if (openingFloat > 0) {
        final entryInput = TillEntryInput(
          entryType: 'opening_float',
          amount: openingFloat,
          affectsCash: true,
          paymentMethod: 'Cash',
          notes: 'Opening float for session ${session.id}',
        );
        await postEntry(
          tillSessionId: session.id,
          tellerId: tellerId,
          tellerName: tellerName,
          input: entryInput,
        );
      }

      print('✅ Till session opened: ${session.id} for $tellerName');
      return session;
    } catch (e) {
      print('❌ Error opening till session: $e');
      rethrow;
    }
  }

  // ─── Watch Open Session ───────────────────────────────────────────────────
  /// Returns a stream of the teller's open session.
  static Stream<TillSession?> watchOpenSession(String tellerId) {
    return _db
        .collection(AppConstants.tillSessionsCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tellerId', isEqualTo: tellerId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return TillSession.fromFirestore(snapshot.docs.first);
    });
  }

  // ─── Get Open Session ─────────────────────────────────────────────────────
  /// Gets the teller's current open session.
  static Future<TillSession?> getOpenSession(String tellerId) async {
    final query = await _db
        .collection(AppConstants.tillSessionsCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tellerId', isEqualTo: tellerId)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return TillSession.fromFirestore(query.docs.first);
  }

  // ─── Post Entry ───────────────────────────────────────────────────────────
  /// Posts a new entry to the till ledger and updates session totals.
  static Future<TillEntry> postEntry({
    required String tillSessionId,
    required String tellerId,
    required String tellerName,
    required TillEntryInput input,
  }) async {
    try {
      // Get current session
      final sessionDoc = await _db
          .collection(AppConstants.tillSessionsCol)
          .doc(tillSessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Till session not found: $tillSessionId');
      }

      final session = TillSession.fromFirestore(sessionDoc);

      // Verify session is open
      if (session.status != 'open') {
        throw TillClosedException('Cannot post to ${session.status} session');
      }

      // Check sufficient cash for withdrawals
      if (input.affectsCash && input.amount < 0) {
        final availableCash = session.expectedCash;
        final withdrawalAmount = input.amount.abs();
        if (withdrawalAmount > availableCash) {
          throw InsufficientCashException(
            'Insufficient cash in till',
            withdrawalAmount,
            availableCash,
          );
        }
      }

      final now = DateTime.now();
      final entryRef = _db.collection(AppConstants.tillEntriesCol).doc();

      // Create till entry
      final entry = TillEntry(
        id: entryRef.id,
        tenantId: _tenantId,
        tillSessionId: tillSessionId,
        tellerId: tellerId,
        tellerName: tellerName,
        entryType: input.entryType,
        amount: input.amount,
        affectsCash: input.affectsCash,
        paymentMethod: input.paymentMethod,
        memberId: input.memberId,
        memberName: input.memberName,
        businessRecordId: input.businessRecordId,
        businessRecordType: input.businessRecordType,
        reversesEntryId: input.reversesEntryId,
        notes: input.notes,
        createdAt: now,
        createdBy: tellerId,
      );

      // Atomic write: entry + session update
      final batch = _db.batch();

      // Write entry
      batch.set(entryRef, entry.toFirestore());

      // Update session totals (only if affectsCash is true)
      if (input.affectsCash) {
        final Map<String, dynamic> updates = {};
        if (input.amount > 0) {
          updates['totalIn'] = FieldValue.increment(input.amount);
        } else {
          updates['totalOut'] = FieldValue.increment(input.amount.abs());
        }
        batch.update(sessionDoc.reference, updates);
      }

      await batch.commit();

      print('✅ Till entry posted: ${entry.entryType} ${entry.amount}');
      return entry;
    } catch (e) {
      print('❌ Error posting till entry: $e');
      rethrow;
    }
  }

  // ─── Get Session Entries ──────────────────────────────────────────────────
  static Future<List<TillEntry>> getSessionEntries(String tillSessionId) async {
    final query = await _db
        .collection(AppConstants.tillEntriesCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tillSessionId', isEqualTo: tillSessionId)
        .orderBy('createdAt', descending: false)
        .get();

    return query.docs.map((doc) => TillEntry.fromFirestore(doc)).toList();
  }

  // ─── Watch Session Entries ────────────────────────────────────────────────
  static Stream<List<TillEntry>> watchSessionEntries(String tillSessionId) {
    return _db
        .collection(AppConstants.tillEntriesCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tillSessionId', isEqualTo: tillSessionId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TillEntry.fromFirestore(doc)).toList();
    });
  }

  // ─── Get Session by ID ────────────────────────────────────────────────────
  static Future<TillSession?> getSessionById(String sessionId) async {
    final doc = await _db
        .collection(AppConstants.tillSessionsCol)
        .doc(sessionId)
        .get();

    if (!doc.exists) return null;
    return TillSession.fromFirestore(doc);
  }

  // ─── Close Session ────────────────────────────────────────────────────────
  static Future<CloseResult> closeSession({
    required String tillSessionId,
    required String tellerId,
    required Map<String, int> denominations,
    String? varianceReason,
  }) async {
    try {
      final sessionDoc = await _db
          .collection(AppConstants.tillSessionsCol)
          .doc(tillSessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Till session not found: $tillSessionId');
      }

      final session = TillSession.fromFirestore(sessionDoc);

      if (session.status != 'open') {
        throw Exception('Session is already ${session.status}');
      }

      if (session.tellerId != tellerId) {
        throw Exception('Cannot close another teller\'s session');
      }

      final actualCash = _calculateCashFromDenominations(denominations);
      final expectedCash = session.expectedCash;
      final variance = actualCash - expectedCash;
      final varianceAbs = variance.abs();

      final needsApproval = varianceAbs > varianceTolerance;

      if (needsApproval && (varianceReason == null || varianceReason.trim().isEmpty)) {
        throw Exception(
          'Variance of UGX ${_formatCurrency(varianceAbs)} exceeds tolerance. Please provide a reason.',
        );
      }

      final now = DateTime.now();
      final newStatus = needsApproval ? 'pending_approval' : 'closed';

      final updates = {
        'status': newStatus,
        'actualCash': actualCash,
        'denominations': denominations,
        'closedAt': Timestamp.fromDate(now),
      };

      if (varianceReason != null && varianceReason.trim().isNotEmpty) {
        updates['varianceReason'] = varianceReason.trim();
      }

      await sessionDoc.reference.update(updates);

      final updatedSession = session.copyWith(
        status: newStatus,
        actualCash: actualCash,
        denominations: denominations,
        varianceReason: varianceReason,
        closedAt: now,
      );

      print('✅ Till session closed: $tillSessionId');
      return CloseResult(
        session: updatedSession,
        expectedCash: expectedCash,
        actualCash: actualCash,
        variance: variance,
        needsApproval: needsApproval,
      );
    } catch (e) {
      print('❌ Error closing till session: $e');
      rethrow;
    }
  }

  // ─── Approve Variance ─────────────────────────────────────────────────────
  static Future<TillSession> approveVariance({
    required String tillSessionId,
    required String supervisorId,
    required String supervisorName,
  }) async {
    try {
      final sessionDoc = await _db
          .collection(AppConstants.tillSessionsCol)
          .doc(tillSessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception('Till session not found: $tillSessionId');
      }

      final session = TillSession.fromFirestore(sessionDoc);

      if (session.status != 'pending_approval') {
        throw Exception('Session is not pending approval');
      }

      final now = DateTime.now();
      await sessionDoc.reference.update({
        'status': 'closed',
        'approvedBy': supervisorId,
        'approvedByName': supervisorName,
        'approvedAt': Timestamp.fromDate(now),
      });

      print('✅ Variance approved for session $tillSessionId');

      return session.copyWith(
        status: 'closed',
        approvedBy: supervisorId,
        approvedByName: supervisorName,
        approvedAt: now,
      );
    } catch (e) {
      print('❌ Error approving variance: $e');
      rethrow;
    }
  }

  // ─── Vault Top-Up ─────────────────────────────────────────────────────────
  static Future<TillEntry> vaultTopUp({
    required String tillSessionId,
    required int amount,
    required String tellerId,
    required String tellerName,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('Top-up amount must be positive');
    }

    final input = TillEntryInput(
      entryType: 'vault_topup',
      amount: amount,
      affectsCash: true,
      paymentMethod: 'Cash',
      notes: notes ?? 'Vault top-up of UGX ${_formatCurrency(amount)}',
    );

    final entry = await postEntry(
      tillSessionId: tillSessionId,
      tellerId: tellerId,
      tellerName: tellerName,
      input: input,
    );

    print('✅ Vault top-up: UGX ${_formatCurrency(amount)}');
    return entry;
  }

  // ─── Vault Sweep ──────────────────────────────────────────────────────────
  static Future<TillEntry> vaultSweep({
    required String tillSessionId,
    required int amount,
    required String tellerId,
    required String tellerName,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('Sweep amount must be positive');
    }

    final session = await getSessionById(tillSessionId);
    if (session == null) {
      throw Exception('Till session not found: $tillSessionId');
    }

    if (session.expectedCash < amount) {
      throw InsufficientCashException(
        'Cannot sweep more than available cash',
        amount,
        session.expectedCash,
      );
    }

    final input = TillEntryInput(
      entryType: 'vault_sweep',
      amount: -amount,
      affectsCash: true,
      paymentMethod: 'Cash',
      notes: notes ?? 'Vault sweep of UGX ${_formatCurrency(amount)}',
    );

    final entry = await postEntry(
      tillSessionId: tillSessionId,
      tellerId: tellerId,
      tellerName: tellerName,
      input: input,
    );

    print('✅ Vault sweep: UGX ${_formatCurrency(amount)}');
    return entry;
  }

  // ─── Reverse Entry ────────────────────────────────────────────────────────
  static Future<TillEntry> reverseEntry({
    required String originalEntryId,
    required String tellerId,
    required String tellerName,
    required String reason,
  }) async {
    try {
      final originalDoc = await _db
          .collection(AppConstants.tillEntriesCol)
          .doc(originalEntryId)
          .get();

      if (!originalDoc.exists) {
        throw Exception('Original entry not found: $originalEntryId');
      }

      final originalEntry = TillEntry.fromFirestore(originalDoc);

      if (originalEntry.isReversal) {
        throw Exception('Cannot reverse a reversal entry');
      }

      final existingReversalQuery = await _db
          .collection(AppConstants.tillEntriesCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('reversesEntryId', isEqualTo: originalEntryId)
          .limit(1)
          .get();

      if (existingReversalQuery.docs.isNotEmpty) {
        throw Exception('Entry has already been reversed');
      }

      final reversingInput = TillEntryInput(
        entryType: 'reversal',
        amount: -originalEntry.amount,
        affectsCash: originalEntry.affectsCash,
        paymentMethod: originalEntry.paymentMethod,
        memberId: originalEntry.memberId,
        memberName: originalEntry.memberName,
        businessRecordId: originalEntry.businessRecordId,
        businessRecordType: originalEntry.businessRecordType,
        reversesEntryId: originalEntryId,
        notes: 'Reversal of ${originalEntry.entryType} entry $originalEntryId. Reason: $reason',
      );

      final reversingEntry = await postEntry(
        tillSessionId: originalEntry.tillSessionId,
        tellerId: tellerId,
        tellerName: tellerName,
        input: reversingInput,
      );

      print('✅ Entry reversed: $originalEntryId');
      return reversingEntry;
    } catch (e) {
      print('❌ Error reversing entry: $e');
      rethrow;
    }
  }

  // ─── Get Entry by ID ──────────────────────────────────────────────────────
  static Future<TillEntry?> getEntryById(String entryId) async {
    final doc = await _db
        .collection(AppConstants.tillEntriesCol)
        .doc(entryId)
        .get();

    if (!doc.exists) return null;
    return TillEntry.fromFirestore(doc);
  }

  // ─── Check if Entry is Reversed ───────────────────────────────────────────
  static Future<bool> isEntryReversed(String entryId) async {
    final query = await _db
        .collection(AppConstants.tillEntriesCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('reversesEntryId', isEqualTo: entryId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // ─── Helper: Format Business Date ─────────────────────────────────────────
  static String _formatBusinessDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // ─── Helper: Get Current Business Date ────────────────────────────────────
  static String getCurrentBusinessDate() {
    return _formatBusinessDate(DateTime.now());
  }

  // ─── Helper: Calculate Cash from Denominations ────────────────────────────
  static int _calculateCashFromDenominations(Map<String, int> denominations) {
    int total = 0;
    denominations.forEach((denomination, count) {
      final value = int.tryParse(denomination) ?? 0;
      total += value * count;
    });
    return total;
  }

  // ─── Helper: Format Currency ──────────────────────────────────────────────
  static String _formatCurrency(int amount) {
    final str = amount.abs().toString();
    final parts = <String>[];
    for (int i = str.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      parts.insert(0, str.substring(start, i));
    }
    final formatted = parts.join(',');
    return amount < 0 ? '-$formatted' : formatted;
  }
}

/// Result of closing a till session
class CloseResult {
  final TillSession session;
  final int expectedCash;
  final int actualCash;
  final int variance;
  final bool needsApproval;

  CloseResult({
    required this.session,
    required this.expectedCash,
    required this.actualCash,
    required this.variance,
    required this.needsApproval,
  });

  bool get isBalanced => variance == 0;
  bool get isWithinTolerance => variance.abs() <= TillService.varianceTolerance;
}

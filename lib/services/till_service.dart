import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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
///
/// Cash maths (one rule, used everywhere):
///   expected cash = openingFloat + totalIn - totalOut
/// The opening float is stored on the session itself, so the 'opening_float'
/// ledger entry is recorded for the audit trail but NEVER counted in totalIn
/// (it used to be counted twice, which doubled the expected cash).
///
/// No query here needs a composite index: everything filters by tenantId (and
/// equality fields) only, and sorting / date filtering happens in memory.
class TillService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;

  // Variance tolerance in UGX (±5000)
  static const int varianceTolerance = 5000;

  static const String openingFloatType = 'opening_float';

  // ─── Cash maths ───────────────────────────────────────────────────────────
  static int expectedCashOf(TillSession s) => s.openingFloat + s.totalIn - s.totalOut;

  /// counted - expected (null until the till has been counted)
  static int? varianceOf(TillSession s) =>
      s.actualCash == null ? null : s.actualCash! - expectedCashOf(s);

  // ─── Open Till Session ────────────────────────────────────────────────────
  static Future<TillSession> openSession({
    required String tellerId,
    required String tellerName,
    required int openingFloat,
    String? notes,
  }) async {
    try {
      if (openingFloat < 0) throw Exception('Opening float cannot be negative');

      final existingQuery = await _db
          .collection(AppConstants.tillSessionsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('tellerId', isEqualTo: tellerId)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('You already have an open till session');
      }

      // ── VALIDATION: Opening float must match last closing balance ──────────
      final lastClosedSession = await _getLastClosedSession(tellerId);
      if (lastClosedSession != null) {
        // Use actualCash (what was counted at close) or expectedCash as fallback
        final expectedOpening = lastClosedSession.actualCash ?? lastClosedSession.expectedCash;
        
        if (openingFloat != expectedOpening) {
          final fmt = NumberFormat('#,###', 'en_US');
          throw Exception(
            'Opening balance mismatch!\n\n'
            'Your last till closed with UGX ${fmt.format(expectedOpening)}.\n'
            'You must open with exactly UGX ${fmt.format(expectedOpening)}, not UGX ${fmt.format(openingFloat)}.\n\n'
            'This ensures accountability and prevents cash discrepancies.'
          );
        }
      }

      final now = DateTime.now();
      final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc();

      final session = TillSession(
        id: sessionRef.id,
        tenantId: _tenantId,
        tellerId: tellerId,
        tellerName: tellerName,
        businessDate: _formatBusinessDate(now),
        status: 'open',
        openingFloat: openingFloat,
        totalIn: 0,
        totalOut: 0,
        openedAt: now,
        notes: notes,
      );

      await sessionRef.set(session.toFirestore());

      // Audit-trail entry only. It does not move totals (see class comment).
      if (openingFloat > 0) {
        await postEntry(
          tillSessionId: session.id,
          tellerId: tellerId,
          tellerName: tellerName,
          input: TillEntryInput(
            entryType: openingFloatType,
            amount: openingFloat,
            affectsCash: true,
            paymentMethod: 'Cash',
            notes: 'Opening float for session ${session.id}',
          ),
        );
      }

      print('✅ Till session opened: ${session.id} for $tellerName');
      return session;
    } catch (e) {
      print('❌ Error opening till session: $e');
      rethrow;
    }
  }

  /// Get the teller's most recent closed session
  static Future<TillSession?> _getLastClosedSession(String tellerId) async {
    try {
      // Fetch all closed sessions for this teller (no index needed)
      final query = await _db
          .collection(AppConstants.tillSessionsCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('tellerId', isEqualTo: tellerId)
          .where('status', isEqualTo: 'closed')
          .get();

      if (query.docs.isEmpty) return null;

      // Sort in memory to find the most recent
      final sessions = query.docs
          .map((doc) => TillSession.fromFirestore(doc))
          .toList();
      
      sessions.sort((a, b) {
        if (a.closedAt == null && b.closedAt == null) return 0;
        if (a.closedAt == null) return 1;
        if (b.closedAt == null) return -1;
        return b.closedAt!.compareTo(a.closedAt!);
      });

      return sessions.first;
    } catch (e) {
      print('⚠️ Could not fetch last closed session: $e');
      return null;
    }
  }

  /// PUBLIC: Get the last closed session balance for UI display
  static Future<Map<String, dynamic>?> getLastClosedSessionBalance(String tellerId) async {
    final session = await _getLastClosedSession(tellerId);
    if (session == null) return null;
    
    // Use actualCash (counted at close) or expectedCash as fallback
    final closingBalance = session.actualCash ?? session.expectedCash;
    
    return {
      'sessionId': session.id,
      'closedAt': session.closedAt,
      'closingBalance': closingBalance,
      'businessDate': session.businessDate,
    };
  }

  // ─── Watch / Get Open Session ─────────────────────────────────────────────
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

  // ─── Get Teller's Sessions (for history browsing) ──────────────────────────
  static Future<List<TillSession>> getTellerSessions(
    String tellerId, {
    int limit = 50,
  }) async {
    final query = await _db
        .collection(AppConstants.tillSessionsCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tellerId', isEqualTo: tellerId)
        .orderBy('openedAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) => TillSession.fromFirestore(doc)).toList();
  }

  // ─── All sessions for this SACCO (reports) ────────────────────────────────
  /// Newest first. Date / status / teller filtering is done by the caller in
  /// memory, so no composite index is required.
  static Stream<List<TillSession>> watchTenantSessions() {
    return _db
        .collection(AppConstants.tillSessionsCol)
        .where('tenantId', isEqualTo: _tenantId)
        .snapshots()
        .map((snap) {
      final list = <TillSession>[];
      for (final d in snap.docs) {
        try {
          list.add(TillSession.fromFirestore(d));
        } catch (e) {
          print('⚠️ Skipping unreadable till session ${d.id}: $e');
        }
      }
      list.sort((a, b) => b.openedAt.compareTo(a.openedAt));
      return list;
    });
  }

  // ─── Post Entry (atomic) ──────────────────────────────────────────────────
  static Future<TillEntry> postEntry({
    required String tillSessionId,
    required String tellerId,
    required String tellerName,
    required TillEntryInput input,
  }) async {
    try {
      final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId);
      final entryRef = _db.collection(AppConstants.tillEntriesCol).doc();
      final now = DateTime.now();
      late TillEntry entry;

      await _db.runTransaction((tx) async {
        final snap = await tx.get(sessionRef);
        if (!snap.exists) {
          throw Exception('Till session not found: $tillSessionId');
        }
        final session = TillSession.fromFirestore(snap);

        if (session.status != 'open') {
          throw TillClosedException('This till session is ${session.status}. Open a new till to continue.');
        }

        final movesCash = input.affectsCash && input.entryType != openingFloatType;

        if (movesCash && input.amount < 0) {
          final available = expectedCashOf(session);
          if (input.amount.abs() > available) {
            throw InsufficientCashException('Insufficient cash in till', input.amount.abs(), available);
          }
        }

        entry = TillEntry(
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
          memberPhone: input.memberPhone,
          businessRecordId: input.businessRecordId,
          businessRecordType: input.businessRecordType,
          reversesEntryId: input.reversesEntryId,
          notes: input.notes,
          createdAt: now,
          createdBy: tellerId,
        );

        tx.set(entryRef, entry.toFirestore());

        if (movesCash && input.amount != 0) {
          tx.update(sessionRef, {
            if (input.amount > 0)
              'totalIn': FieldValue.increment(input.amount)
            else
              'totalOut': FieldValue.increment(input.amount.abs()),
          });
        }
      });

      print('✅ Till entry posted: ${entry.entryType} ${entry.amount}');
      return entry;
    } catch (e) {
      print('❌ Error posting till entry: $e');
      rethrow;
    }
  }

  // ─── Entries ──────────────────────────────────────────────────────────────
  static Future<List<TillEntry>> getSessionEntries(String tillSessionId) async {
    final query = await _db
        .collection(AppConstants.tillEntriesCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tillSessionId', isEqualTo: tillSessionId)
        .get();

    final list = query.docs.map((doc) => TillEntry.fromFirestore(doc)).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  static Stream<List<TillEntry>> watchSessionEntries(String tillSessionId) {
    return _db
        .collection(AppConstants.tillEntriesCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('tillSessionId', isEqualTo: tillSessionId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => TillEntry.fromFirestore(doc)).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  static Future<TillSession?> getSessionById(String sessionId) async {
    final doc = await _db.collection(AppConstants.tillSessionsCol).doc(sessionId).get();
    if (!doc.exists) return null;
    return TillSession.fromFirestore(doc);
  }

  // ─── Repair totals ────────────────────────────────────────────────────────
  /// Recomputes totalIn / totalOut of an OPEN session from its ledger entries
  /// and fixes the session if they differ (this heals sessions that were
  /// opened before the double-counted opening float was fixed).
  /// Returns the up-to-date session.
  static Future<TillSession?> repairSessionTotals(String sessionId) async {
    final ref = _db.collection(AppConstants.tillSessionsCol).doc(sessionId);
    final snap = await ref.get();
    if (!snap.exists) return null;
    final session = TillSession.fromFirestore(snap);
    if (session.status != 'open') return session;

    final entries = await getSessionEntries(sessionId);
    int tin = 0, tout = 0;
    for (final e in entries) {
      if (!e.affectsCash || e.entryType == openingFloatType) continue;
      if (e.amount > 0) {
        tin += e.amount;
      } else {
        tout += -e.amount;
      }
    }

    if (tin != session.totalIn || tout != session.totalOut) {
      await ref.update({'totalIn': tin, 'totalOut': tout});
      print('🔧 Till totals repaired for $sessionId (in $tin, out $tout)');
      return getSessionById(sessionId);
    }
    return session;
  }

  // ─── Edit Opening Float ───────────────────────────────────────────────────
  /// Updates the opening float for an OPEN till session.
  /// Only allowed if the session is still open.
  static Future<void> updateOpeningFloat({
    required String tillSessionId,
    required int newOpeningFloat,
    required String updatedBy,
  }) async {
    try {
      if (newOpeningFloat < 0) {
        throw Exception('Opening float cannot be negative');
      }

      final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId);
      final snap = await sessionRef.get();
      
      if (!snap.exists) {
        throw Exception('Till session not found: $tillSessionId');
      }

      final session = TillSession.fromFirestore(snap);

      if (session.status != 'open') {
        throw Exception('Cannot edit opening float for a ${session.status} session. Only open sessions can be edited.');
      }

      final oldFloat = session.openingFloat;

      await sessionRef.update({
        'openingFloat': newOpeningFloat,
        'updatedAt': DateTime.now(),
        'updatedBy': updatedBy,
      });

      // Create audit trail entry
      await _db.collection(AppConstants.tillEntriesCol).add({
        'tenantId': _tenantId,
        'tillSessionId': tillSessionId,
        'tellerId': updatedBy,
        'tellerName': session.tellerName,
        'entryType': 'opening_float_edit',
        'amount': newOpeningFloat - oldFloat,
        'affectsCash': false,
        'paymentMethod': 'N/A',
        'notes': 'Opening float edited from ${_formatCurrency(oldFloat)} to ${_formatCurrency(newOpeningFloat)}',
        'createdAt': DateTime.now(),
        'createdBy': updatedBy,
      });

      print('✅ Opening float updated for session $tillSessionId: ${_formatCurrency(oldFloat)} → ${_formatCurrency(newOpeningFloat)}');
    } catch (e) {
      print('❌ Error updating opening float: $e');
      rethrow;
    }
  }

  // ─── Delete Transaction ───────────────────────────────────────────────────
  /// Deletes a till entry and rolls back the amount from the session totals.
  /// Only allowed for open sessions and non-opening-float transactions.
  static Future<void> deleteTransaction({
    required String tillSessionId,
    required String entryId,
    required String deletedBy,
    String? reason,
  }) async {
    try {
      final entryRef = _db.collection(AppConstants.tillEntriesCol).doc(entryId);
      final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId);

      await _db.runTransaction((tx) async {
        final entrySnap = await tx.get(entryRef);
        if (!entrySnap.exists) {
          throw Exception('Transaction not found: $entryId');
        }

        final entry = TillEntry.fromFirestore(entrySnap);

        // Prevent deletion of opening float
        if (entry.entryType == openingFloatType) {
          throw Exception('Cannot delete opening float transaction. Use "Edit Opening Float" instead.');
        }

        final sessionSnap = await tx.get(sessionRef);
        if (!sessionSnap.exists) {
          throw Exception('Till session not found: $tillSessionId');
        }

        final session = TillSession.fromFirestore(sessionSnap);

        if (session.status != 'open') {
          throw Exception('Cannot delete transactions from a ${session.status} session. Only open sessions can be edited.');
        }

        // Rollback the amount if it affects cash
        if (entry.affectsCash && entry.amount != 0) {
          if (entry.amount > 0) {
            // Was cash in, so reduce totalIn
            tx.update(sessionRef, {
              'totalIn': FieldValue.increment(-entry.amount),
            });
          } else {
            // Was cash out, so reduce totalOut
            tx.update(sessionRef, {
              'totalOut': FieldValue.increment(entry.amount.abs()),
            });
          }
        }

        // Delete the entry
        tx.delete(entryRef);

        // Create audit trail entry
        final auditRef = _db.collection(AppConstants.tillEntriesCol).doc();
        tx.set(auditRef, {
          'tenantId': _tenantId,
          'tillSessionId': tillSessionId,
          'tellerId': deletedBy,
          'tellerName': session.tellerName,
          'entryType': 'transaction_deleted',
          'amount': 0,
          'affectsCash': false,
          'paymentMethod': 'N/A',
          'notes': 'Deleted ${entry.entryType} transaction of ${_formatCurrency(entry.amount.abs())} - ${reason ?? "No reason provided"}',
          'businessRecordId': entry.id,
          'createdAt': DateTime.now(),
          'createdBy': deletedBy,
        });
      });

      print('✅ Transaction deleted: $entryId');
    } catch (e) {
      print('❌ Error deleting transaction: $e');
      rethrow;
    }
  }

  // ─── Delete All Transactions (Sweep/Reset) ────────────────────────────────
  /// Deletes all transactions from an open till session and resets totals to zero.
  /// DANGEROUS: Only use in case of major errors. Opening float is preserved.
  static Future<void> deleteAllTransactions({
    required String tillSessionId,
    required String deletedBy,
    required String reason,
  }) async {
    try {
      if (reason.trim().isEmpty) {
        throw Exception('Reason is required for deleting all transactions');
      }

      final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId);
      final sessionSnap = await sessionRef.get();
      
      if (!sessionSnap.exists) {
        throw Exception('Till session not found: $tillSessionId');
      }

      final session = TillSession.fromFirestore(sessionSnap);

      if (session.status != 'open') {
        throw Exception('Cannot delete transactions from a ${session.status} session. Only open sessions can be edited.');
      }

      // Get all entries except opening float
      final entriesQuery = await _db
          .collection(AppConstants.tillEntriesCol)
          .where('tenantId', isEqualTo: _tenantId)
          .where('tillSessionId', isEqualTo: tillSessionId)
          .get();

      final entriesToDelete = entriesQuery.docs
          .map((d) => TillEntry.fromFirestore(d))
          .where((e) => e.entryType != openingFloatType)
          .toList();

      if (entriesToDelete.isEmpty) {
        throw Exception('No transactions to delete');
      }

      // Delete all entries and reset totals in a batch
      final batch = _db.batch();

      for (final entry in entriesToDelete) {
        final entryRef = _db.collection(AppConstants.tillEntriesCol).doc(entry.id);
        batch.delete(entryRef);
      }

      // Reset totals to zero
      batch.update(sessionRef, {
        'totalIn': 0,
        'totalOut': 0,
        'updatedAt': DateTime.now(),
        'updatedBy': deletedBy,
      });

      // Create audit trail entry
      final auditRef = _db.collection(AppConstants.tillEntriesCol).doc();
      batch.set(auditRef, {
        'tenantId': _tenantId,
        'tillSessionId': tillSessionId,
        'tellerId': deletedBy,
        'tellerName': session.tellerName,
        'entryType': 'all_transactions_deleted',
        'amount': 0,
        'affectsCash': false,
        'paymentMethod': 'N/A',
        'notes': 'Deleted all ${entriesToDelete.length} transactions - Reason: $reason',
        'createdAt': DateTime.now(),
        'createdBy': deletedBy,
      });

      await batch.commit();

      print('✅ All transactions deleted: ${entriesToDelete.length} entries removed');
    } catch (e) {
      print('❌ Error deleting all transactions: $e');
      rethrow;
    }
  }

  // ─── Close Session ────────────────────────────────────────────────────────
  static Future<CloseResult> closeSession({
    required String tillSessionId,
    required String tellerId,
    required Map<String, int> denominations,
    String? varianceReason,
  }) async {
    try {
      var session = await repairSessionTotals(tillSessionId);
      if (session == null) {
        throw Exception('Till session not found: $tillSessionId');
      }

      if (session.status != 'open') {
        throw Exception('Session is already ${session.status}');
      }

      if (session.tellerId != tellerId) {
        throw Exception('Cannot close another teller\'s session');
      }

      final actualCash = _calculateCashFromDenominations(denominations);
      final expectedCash = expectedCashOf(session);
      final variance = actualCash - expectedCash;
      final needsApproval = variance.abs() > varianceTolerance;

      if (needsApproval && (varianceReason == null || varianceReason.trim().isEmpty)) {
        throw Exception(
          'Variance of UGX ${_formatCurrency(variance.abs())} exceeds the tolerance of UGX ${_formatCurrency(varianceTolerance)}. Please provide a reason.',
        );
      }

      final now = DateTime.now();
      final newStatus = needsApproval ? 'pending_approval' : 'closed';

      final updates = <String, dynamic>{
        'status': newStatus,
        'actualCash': actualCash,
        'expectedCash': expectedCash,
        'variance': variance,
        'denominations': denominations,
        'closedAt': Timestamp.fromDate(now),
      };
      if (varianceReason != null && varianceReason.trim().isNotEmpty) {
        updates['varianceReason'] = varianceReason.trim();
      }

      await _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId).update(updates);

      final updatedSession = session.copyWith(
        status: newStatus,
        actualCash: actualCash,
        denominations: denominations,
        varianceReason: varianceReason,
        closedAt: now,
      );

      print('✅ Till session closed: $tillSessionId ($newStatus)');
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
      final session = await getSessionById(tillSessionId);
      if (session == null) {
        throw Exception('Till session not found: $tillSessionId');
      }
      if (session.status != 'pending_approval') {
        throw Exception('Session is not pending approval');
      }

      final now = DateTime.now();
      await _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId).update({
        'status': 'closed',
        'approvedBy': supervisorId,
        'approvedByName': supervisorName,
        'approvedAt': Timestamp.fromDate(now),
      });

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

  // ─── Vault Top-Up / Sweep ─────────────────────────────────────────────────
  static Future<TillEntry> vaultTopUp({
    required String tillSessionId,
    required int amount,
    required String tellerId,
    required String tellerName,
    String? notes,
  }) async {
    if (amount <= 0) throw Exception('Top-up amount must be greater than zero');

    return postEntry(
      tillSessionId: tillSessionId,
      tellerId: tellerId,
      tellerName: tellerName,
      input: TillEntryInput(
        entryType: 'vault_topup',
        amount: amount,
        affectsCash: true,
        paymentMethod: 'Cash',
        notes: notes ?? 'Vault top-up of UGX ${_formatCurrency(amount)}',
      ),
    );
  }

  static Future<TillEntry> vaultSweep({
    required String tillSessionId,
    required int amount,
    required String tellerId,
    required String tellerName,
    String? notes,
  }) async {
    if (amount <= 0) throw Exception('Sweep amount must be greater than zero');

    // postEntry re-checks the available cash atomically.
    return postEntry(
      tillSessionId: tillSessionId,
      tellerId: tellerId,
      tellerName: tellerName,
      input: TillEntryInput(
        entryType: 'vault_sweep',
        amount: -amount,
        affectsCash: true,
        paymentMethod: 'Cash',
        notes: notes ?? 'Vault sweep of UGX ${_formatCurrency(amount)}',
      ),
    );
  }

  // ─── Reverse Entry ────────────────────────────────────────────────────────
  static Future<TillEntry> reverseEntry({
    required String originalEntryId,
    required String tellerId,
    required String tellerName,
    required String reason,
  }) async {
    try {
      final originalDoc =
          await _db.collection(AppConstants.tillEntriesCol).doc(originalEntryId).get();

      if (!originalDoc.exists) {
        throw Exception('Original entry not found: $originalEntryId');
      }

      final originalEntry = TillEntry.fromFirestore(originalDoc);

      if (originalEntry.isReversal) {
        throw Exception('Cannot reverse a reversal entry');
      }
      if (originalEntry.entryType == openingFloatType) {
        throw Exception('The opening float cannot be reversed');
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

      return postEntry(
        tillSessionId: originalEntry.tillSessionId,
        tellerId: tellerId,
        tellerName: tellerName,
        input: TillEntryInput(
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
        ),
      );
    } catch (e) {
      print('❌ Error reversing entry: $e');
      rethrow;
    }
  }

  static Future<TillEntry?> getEntryById(String entryId) async {
    final doc = await _db.collection(AppConstants.tillEntriesCol).doc(entryId).get();
    if (!doc.exists) return null;
    return TillEntry.fromFirestore(doc);
  }

  static Future<bool> isEntryReversed(String entryId) async {
    final query = await _db
        .collection(AppConstants.tillEntriesCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('reversesEntryId', isEqualTo: entryId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static String _formatBusinessDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String getCurrentBusinessDate() => _formatBusinessDate(DateTime.now());

  static int _calculateCashFromDenominations(Map<String, int> denominations) {
    int total = 0;
    denominations.forEach((denomination, count) {
      total += (int.tryParse(denomination) ?? 0) * count;
    });
    return total;
  }

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

  // ─── Recount Cash (Edit actualCash for Closed Till) ──────────────────────
  /// Allows updating the counted cash (actualCash) on an already-closed till.
  /// Used for accountability corrections when the cash was miscounted at closing.
  static Future<TillSession> recountCash({
    required String tillSessionId,
    required Map<String, int> denominations,
    required String recountedBy,
    String? reason,
  }) async {
    try {
      final session = await getSessionById(tillSessionId);
      if (session == null) {
        throw Exception('Till session not found: $tillSessionId');
      }

      if (session.status != 'closed' && session.status != 'pending_approval') {
        throw Exception('Can only recount cash on closed or pending approval tills');
      }

      final newActualCash = _calculateCashFromDenominations(denominations);
      final expectedCash = expectedCashOf(session);
      final newVariance = newActualCash - expectedCash;
      final needsApproval = newVariance.abs() > varianceTolerance;
      final newStatus = needsApproval ? 'pending_approval' : 'closed';

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'actualCash': newActualCash,
        'variance': newVariance,
        'denominations': denominations,
        'recountedAt': Timestamp.fromDate(now),
        'recountedBy': recountedBy,
        'status': newStatus,
      };

      if (reason != null && reason.trim().isNotEmpty) {
        updates['recountReason'] = reason.trim();
      }

      // If it was previously approved but now needs approval again, clear approval
      if (needsApproval && session.status == 'closed') {
        updates['approvedBy'] = FieldValue.delete();
        updates['approvedByName'] = FieldValue.delete();
        updates['approvedAt'] = FieldValue.delete();
      }

      await _db.collection(AppConstants.tillSessionsCol).doc(tillSessionId).update(updates);

      print('✅ Cash recounted for session $tillSessionId: UGX ${_formatCurrency(newActualCash)} (variance: ${_formatCurrency(newVariance)})');

      return session.copyWith(
        actualCash: newActualCash,
        denominations: denominations,
        status: newStatus,
      );
    } catch (e) {
      print('❌ Error recounting cash: $e');
      rethrow;
    }
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
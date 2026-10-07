# Till Management & Cash Handling — Design Document

**Project:** MBADIFA SACCO (SACCOPLUS)  
**Feature:** Till Management with Blind Count Reconciliation  
**Version:** 1.0  
**Date:** 2026-10-06  
**References:** `requirements.md`

---

## 1. Architecture Overview

### 1.1 Design Principles

1. **Single Source of Truth:** `TillService` is the ONLY entry point for till operations
2. **Append-Only Ledger:** Till entries are never updated or deleted; corrections are new entries
3. **Atomic Writes:** Business record + till entry written in one Firestore batch/transaction
4. **Derived State:** Expected cash is always computed, never stored as user input
5. **Separation of Concerns:** Cash vs non-cash tracked separately; only cash affects expected balance
6. **Blind Reconciliation:** Expected cash not visible during count to ensure honest reconciliation

### 1.2 Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ TellerScreen │  │ AllTillsView │  │ DailySummary │      │
│  │  (UI State)  │  │  (Supervisor)│  │   (Reports)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
┌─────────┼──────────────────┼──────────────────┼─────────────┐
│         │      Business Logic Layer           │             │
│    ┌────▼─────────┐  ┌────▼─────────┐  ┌────▼─────────┐   │
│    │ TillService  │  │TellerService │  │LoanDisbursmt │   │
│    │ (Till Ops)   │  │(Dep/With)    │  │   Service    │   │
│    └────┬─────────┘  └────┬─────────┘  └────┬─────────┘   │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
┌─────────▼──────────────────▼──────────────────▼─────────────┐
│                      Data Layer                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐│
│  │ till-sessions  │  │  till-entries  │  │  business docs ││
│  │   (state)      │  │   (ledger)     │  │ (savings/loans)││
│  └────────────────┘  └────────────────┘  └────────────────┘│
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Data Model (Detailed)

### 2.1 Firestore Collections

#### `saccoplus-till-sessions`
Primary collection for till session state.

**Document ID:** Auto-generated UUID  
**Indexes Required:**
- `tenantId + tellerId + status` (find teller's open session)
- `tenantId + businessDate + status` (daily reporting)
- `tenantId + status + openedAt` (supervisor dashboard)

```typescript
interface TillSession {
  // Identity
  id: string;                    // UUID
  tenantId: string;              // Multi-tenancy
  branchId?: string;             // Optional: for multi-branch orgs
  
  // Teller info
  tellerId: string;              // Session user UID
  tellerName: string;            // Display name
  
  // Status & dates
  status: 'open' | 'pending_float_approval' | 'pending_review' | 'closed';
  businessDate: string;          // 'YYYY-MM-DD' in EAT
  openedAt: Timestamp;           // Server timestamp
  openedBy: string;              // Usually same as tellerId
  floatIssuedBy: string;         // Supervisor who issued float
  lastActivityAt: Timestamp;     // Updated on every transaction
  
  // Running totals (incremented via FieldValue.increment)
  openingFloat: number;          // Integer UGX
  totalIn: number;               // Cash in (deposits, repayments, vault top-ups)
  totalOut: number;              // Cash out (withdrawals, disbursements, vault sweeps)
  nonCashTotal: number;          // MM/bank transactions (for audit only)
  txnCount: number;              // Total entries (cash + non-cash)
  
  // Closing data (set at close)
  closedAt?: Timestamp;
  denominations?: {
    '50000': number;             // Count of each denomination
    '20000': number;
    '10000': number;
    '5000': number;
    '2000': number;
    '1000': number;
    '500': number;
    '200': number;
    '100': number;
    '50': number;
  };
  countedCash?: number;          // Sum of denominations
  expectedCash?: number;         // Snapshot: openingFloat + totalIn - totalOut
  variance?: number;             // countedCash - expectedCash
  varianceReason?: string;       // Required if |variance| > tolerance
  
  // Review (for pending_review status)
  reviewedBy?: string;           // Head teller UID
  reviewedAt?: Timestamp;
  reviewNote?: string;
  
  // Integrity flag
  integrityWarning?: boolean;    // True if ledger totals ≠ running totals
}
```

**Computed Field (never stored):**
```typescript
expectedCash = openingFloat + totalIn - totalOut
```

#### `saccoplus-till-entries`
Append-only ledger of all till movements.

**Document ID:** Auto-generated UUID  
**Indexes Required:**
- `tenantId + tillSessionId + createdAt` (session ledger chronologically)
- `tenantId + tellerId + createdAt` (teller history)
- `tenantId + type + createdAt` (transaction type reports)
- `tenantId + createdAt` (all entries chronologically)

```typescript
interface TillEntry {
  // Identity
  id: string;                    // UUID
  tenantId: string;
  tillSessionId: string;         // Parent session
  tellerId: string;
  
  // Transaction classification
  type: 'deposit' | 'withdrawal' | 'loan_repayment' | 'loan_disbursement'
      | 'share_purchase' | 'fee' | 'expense' | 'vault_topup' | 'vault_sweep'
      | 'reversal' | 'adjustment';
  direction: 'in' | 'out';       // Money flow direction
  
  // Amount & cash flag
  amount: number;                // Integer UGX, always positive
  affectsCash: boolean;          // true = cash, false = MM/bank/savings transfer
  method: 'Cash' | 'Mobile Money' | 'Bank' | 'Savings Transfer';
  
  // References to business documents
  refCollection?: string;        // e.g., 'saccoplus-savings-transactions'
  refId?: string;                // Document ID in refCollection
  
  // Member info (if applicable)
  memberId?: string;
  memberName?: string;
  receiptNumber?: string;        // From business transaction
  
  // Reversal tracking
  reversalOf?: string;           // Till entry ID being reversed
  crossSession?: boolean;        // True if reversal in different session
  
  // Vault movements
  approvedBy?: string;           // Supervisor who approved vault transfer
  
  // Metadata
  note?: string;
  createdAt: Timestamp;          // Server timestamp
  createdBy: string;             // Teller UID
}
```

#### Modified: `saccoplus-savings-transactions`
Add `tillSessionId` field to link transactions to till sessions.

```typescript
interface SavingsTransaction {
  // ... existing fields ...
  tillSessionId?: string;        // NEW: links to till session
}
```

#### Modified: `saccoplus-repayments` (Loan Repayments)
```typescript
interface LoanRepayment {
  // ... existing fields ...
  tillSessionId?: string;        // NEW
}
```

#### Modified: Loan Disbursement Records
```typescript
interface LoanDisbursement {
  // ... existing fields ...
  tillSessionId?: string;        // NEW
}
```

### 2.2 Settings Document

**Path:** `saccoplus-settings/{tenantId}`

Add these fields (with defaults):
```typescript
{
  // ... existing settings ...
  
  // Till management settings
  tillVarianceTolerance: 5000,      // UGX (default ±5,000)
  tillMaxCash: 10000000,            // UGX (default 10M)
  tellerTxnLimit: 5000000,          // UGX (default 5M, Phase 2)
  requireFloatApproval: false,      // bool (default false)
}
```

---

## 3. Service Layer Design

### 3.1 TillService (`lib/services/till_service.dart`)

Single entry point for all till operations. No other service should directly write to `till-sessions` or `till-entries`.

#### 3.1.1 Core Data Classes

```dart
class TillSession {
  final String id;
  final String tenantId;
  final String tellerId;
  final String tellerName;
  final String status;
  final String businessDate;
  final DateTime openedAt;
  final int openingFloat;
  final int totalIn;
  final int totalOut;
  final int nonCashTotal;
  final int txnCount;
  final DateTime? closedAt;
  final int? countedCash;
  final int? expectedCash;
  final int? variance;
  final Map<String, int>? denominations;
  final bool? integrityWarning;
  
  TillSession({/* ... */});
  
  factory TillSession.fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore();
}

class TillEntryInput {
  final String type;
  final String direction;
  final int amount;
  final bool affectsCash;
  final String method;
  final String? refCollection;
  final String? refId;
  final String? memberId;
  final String? memberName;
  final String? receiptNumber;
  final String? note;
  final String? reversalOf;
  final bool crossSession;
  final String? approvedBy;
  
  TillEntryInput({/* ... */});
}

class TillClosedException implements Exception {
  final String message;
  TillClosedException([this.message = 'Till is not open']);
}

class InsufficientCashException implements Exception {
  final int expected;
  final int requested;
  InsufficientCashException(this.expected, this.requested);
}

class CloseResult {
  final bool success;
  final int countedCash;
  final int expectedCash;
  final int variance;
  final bool needsReview;
  final String? message;
  
  CloseResult({/* ... */});
}
```

#### 3.1.2 Public API Methods

```dart
class TillService {
  static final _db = FirebaseFirestore.instance;
  static String get _tenantId => FirebaseService.sessionTenantId;
  static String get _userId => FirebaseService.sessionUid;
  
  // ─── Session Management ──────────────────────────────────────────────────
  
  /// Get teller's current open session (status = 'open')
  /// Returns null if no open session found.
  static Future<TillSession?> getOpenSession(String tellerId);
  
  /// Stream teller's open session for live updates.
  /// Returns null stream value if no open session.
  static Stream<TillSession?> watchOpenSession(String tellerId);
  
  /// Open a new till session.
  /// Throws TillClosedException if teller already has open/pending_review session.
  /// Uses Firestore transaction to guarantee one session per teller.
  static Future<TillSession> openSession({
    required int openingFloat,
    required String floatIssuedBy,
    String? branchId,
  });
  
  /// Check if session is from previous business day (stale).
  /// Returns true if session's businessDate < today's EAT date.
  static bool isStaleSession(TillSession session);
  
  /// Throws TillClosedException if session is null or not 'open'.
  /// Use this at the start of every transaction method.
  static void requireOpenSession(TillSession? session);
  
  // ─── Transaction Recording ───────────────────────────────────────────────
  
  /// Compute current expected cash for a session.
  /// Formula: openingFloat + totalIn - totalOut
  static int expectedCash(TillSession session) {
    return session.openingFloat + session.totalIn - session.totalOut;
  }
  
  /// Add a till entry to an EXISTING Firestore batch/transaction.
  /// This allows the caller to write the business record + till entry atomically.
  /// 
  /// Updates session running totals (totalIn/totalOut/nonCashTotal/txnCount).
  /// Does NOT commit the batch; caller must call batch.commit().
  static void postEntry(
    WriteBatch batch,
    TillSession session,
    TillEntryInput entry,
  ) {
    // 1. Create till entry document
    final entryDoc = _db.collection(AppConstants.tillEntriesCol).doc();
    batch.set(entryDoc, {
      'id': entryDoc.id,
      'tenantId': _tenantId,
      'tillSessionId': session.id,
      'tellerId': session.tellerId,
      'type': entry.type,
      'direction': entry.direction,
      'amount': entry.amount,
      'affectsCash': entry.affectsCash,
      'method': entry.method,
      if (entry.refCollection != null) 'refCollection': entry.refCollection,
      if (entry.refId != null) 'refId': entry.refId,
      if (entry.memberId != null) 'memberId': entry.memberId,
      if (entry.memberName != null) 'memberName': entry.memberName,
      if (entry.receiptNumber != null) 'receiptNumber': entry.receiptNumber,
      if (entry.note != null) 'note': entry.note,
      if (entry.reversalOf != null) 'reversalOf': entry.reversalOf,
      'crossSession': entry.crossSession,
      if (entry.approvedBy != null) 'approvedBy': entry.approvedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _userId,
    });
    
    // 2. Update session running totals
    final sessionRef = _db.collection(AppConstants.tillSessionsCol).doc(session.id);
    
    final updates = <String, dynamic>{
      'txnCount': FieldValue.increment(1),
      'lastActivityAt': FieldValue.serverTimestamp(),
    };
    
    if (entry.affectsCash) {
      if (entry.direction == 'in') {
        updates['totalIn'] = FieldValue.increment(entry.amount);
      } else {
        updates['totalOut'] = FieldValue.increment(entry.amount);
      }
    } else {
      updates['nonCashTotal'] = FieldValue.increment(entry.amount);
    }
    
    batch.update(sessionRef, updates);
  }
  
  /// Check if a cash-out transaction can proceed (sufficient cash).
  /// Throws InsufficientCashException if amount > expected cash.
  static void checkSufficientCash(TillSession session, int amount) {
    final expected = expectedCash(session);
    if (amount > expected) {
      throw InsufficientCashException(expected, amount);
    }
  }
  
  // ─── Vault Transfers ─────────────────────────────────────────────────────
  
  /// Record vault top-up (cash in from vault).
  static Future<void> vaultTopUp({
    required TillSession session,
    required int amount,
    required String approvedBy,
    String? note,
  }) async {
    requireOpenSession(session);
    
    final batch = _db.batch();
    
    postEntry(batch, session, TillEntryInput(
      type: 'vault_topup',
      direction: 'in',
      amount: amount,
      affectsCash: true,
      method: 'Cash',
      note: note ?? 'Vault top-up',
      approvedBy: approvedBy,
      crossSession: false,
    ));
    
    await batch.commit();
    
    await AuditService.log(
      action: 'VAULT_TOPUP',
      details: 'Vault top-up of UGX $amount to till',
      userId: _userId,
      metadata: {
        'tillSessionId': session.id,
        'amount': amount,
        'approvedBy': approvedBy,
      },
    );
  }
  
  /// Record vault sweep (cash out to vault).
  static Future<void> vaultSweep({
    required TillSession session,
    required int amount,
    required String approvedBy,
    String? note,
  }) async {
    requireOpenSession(session);
    checkSufficientCash(session, amount);
    
    final batch = _db.batch();
    
    postEntry(batch, session, TillEntryInput(
      type: 'vault_sweep',
      direction: 'out',
      amount: amount,
      affectsCash: true,
      method: 'Cash',
      note: note ?? 'Vault sweep',
      approvedBy: approvedBy,
      crossSession: false,
    ));
    
    await batch.commit();
    
    await AuditService.log(
      action: 'VAULT_SWEEP',
      details: 'Vault sweep of UGX $amount from till',
      userId: _userId,
      metadata: {
        'tillSessionId': session.id,
        'amount': amount,
        'approvedBy': approvedBy,
      },
    );
  }
  
  // ─── Reversal ────────────────────────────────────────────────────────────
  
  /// Reverse a till entry.
  /// Creates a new reversing entry in the teller's current open session.
  /// If no open session, marks reversal as crossSession for supervisor review.
  static Future<void> reverseEntry({
    required String originalEntryId,
    required String reason,
  }) async {
    // 1. Get original entry
    final entryDoc = await _db
        .collection(AppConstants.tillEntriesCol)
        .doc(originalEntryId)
        .get();
    
    if (!entryDoc.exists) {
      throw Exception('Original till entry not found');
    }
    
    final originalEntry = entryDoc.data()!;
    
    // 2. Get current teller's open session
    final openSession = await getOpenSession(_userId);
    
    final isCrossSession = openSession == null ||
        openSession.id != originalEntry['tillSessionId'];
    
    // 3. Create reversing entry
    final batch = _db.batch();
    
    if (openSession != null) {
      postEntry(batch, openSession, TillEntryInput(
        type: 'reversal',
        direction: originalEntry['direction'] == 'in' ? 'out' : 'in',
        amount: originalEntry['amount'],
        affectsCash: originalEntry['affectsCash'],
        method: originalEntry['method'],
        reversalOf: originalEntryId,
        crossSession: isCrossSession,
        note: 'Reversal: $reason',
        memberId: originalEntry['memberId'],
        memberName: originalEntry['memberName'],
      ));
      
      await batch.commit();
    } else {
      // No open session - create orphan reversal for supervisor review
      final entryDoc = _db.collection(AppConstants.tillEntriesCol).doc();
      batch.set(entryDoc, {
        'id': entryDoc.id,
        'tenantId': _tenantId,
        'tillSessionId': 'PENDING_ASSIGNMENT', // Supervisor will assign
        'tellerId': _userId,
        'type': 'reversal',
        'direction': originalEntry['direction'] == 'in' ? 'out' : 'in',
        'amount': originalEntry['amount'],
        'affectsCash': originalEntry['affectsCash'],
        'method': originalEntry['method'],
        'reversalOf': originalEntryId,
        'crossSession': true,
        'note': 'Reversal (no open session): $reason',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _userId,
      });
      
      await batch.commit();
      
      // Notify head tellers
      await _notifyHeadTellers(
        'Cross-Session Reversal Pending',
        'Reversal of UGX ${originalEntry['amount']} requires assignment to a till session.',
      );
    }
    
    await AuditService.log(
      action: 'TILL_ENTRY_REVERSED',
      details: 'Reversed till entry: $reason',
      userId: _userId,
      metadata: {
        'originalEntryId': originalEntryId,
        'amount': originalEntry['amount'],
        'crossSession': isCrossSession,
      },
    );
  }
  
  // ─── Close Till ──────────────────────────────────────────────────────────
  
  /// Close till with blind count reconciliation.
  /// 
  /// [denominations] - Map of denomination string to count (e.g., {'50000': 10})
  /// [varianceReason] - Required if |variance| > tolerance
  /// 
  /// Returns CloseResult with variance and review status.
  static Future<CloseResult> closeSession({
    required String sessionId,
    required Map<String, int> denominations,
    String? varianceReason,
  }) async {
    // 1. Get session
    final sessionDoc = await _db
        .collection(AppConstants.tillSessionsCol)
        .doc(sessionId)
        .get();
    
    if (!sessionDoc.exists) {
      throw Exception('Till session not found');
    }
    
    final sessionData = sessionDoc.data()!;
    
    if (sessionData['status'] == 'closed') {
      throw TillClosedException('Till is already closed');
    }
    
    // 2. Compute counted cash from denominations
    final countedCash = _computeCountedCash(denominations);
    
    // 3. Recompute expected cash from ledger (integrity check)
    final ledgerExpected = await _recomputeFromLedger(sessionId);
    final sessionExpected = (sessionData['openingFloat'] as int) +
        (sessionData['totalIn'] as int) -
        (sessionData['totalOut'] as int);
    
    final integrityWarning = (ledgerExpected - sessionExpected).abs() > 1;
    final expectedCash = ledgerExpected; // Use ledger as source of truth
    
    // 4. Compute variance
    final variance = countedCash - expectedCash;
    
    // 5. Get tolerance setting
    final settingsDoc = await _db
        .collection('saccoplus-settings')
        .doc(_tenantId)
        .get();
    final tolerance = settingsDoc.data()?['tillVarianceTolerance'] ?? 5000;
    
    // 6. Determine status
    final needsReview = variance.abs() > tolerance;
    final newStatus = needsReview ? 'pending_review' : 'closed';
    
    if (needsReview && (varianceReason == null || varianceReason.trim().length < 10)) {
      throw Exception('Variance reason required (min 10 characters)');
    }
    
    // 7. Update session
    await _db.collection(AppConstants.tillSessionsCol).doc(sessionId).update({
      'status': newStatus,
      'closedAt': FieldValue.serverTimestamp(),
      'denominations': denominations,
      'countedCash': countedCash,
      'expectedCash': expectedCash,
      'variance': variance,
      if (varianceReason != null) 'varianceReason': varianceReason,
      if (integrityWarning) 'integrityWarning': true,
    });
    
    // 8. Audit log
    await AuditService.log(
      action: 'TILL_CLOSED',
      details: 'Till closed with variance UGX $variance',
      userId: _userId,
      metadata: {
        'tillSessionId': sessionId,
        'countedCash': countedCash,
        'expectedCash': expectedCash,
        'variance': variance,
        'status': newStatus,
        'integrityWarning': integrityWarning,
      },
    );
    
    // 9. Notify head tellers if needs review
    if (needsReview) {
      await _notifyHeadTellers(
        'Till Variance Pending Review',
        'Teller ${sessionData['tellerName']} has a variance of UGX $variance (${variance > 0 ? 'over' : 'short'}).',
      );
    }
    
    return CloseResult(
      success: true,
      countedCash: countedCash,
      expectedCash: expectedCash,
      variance: variance,
      needsReview: needsReview,
      message: needsReview
          ? 'Variance exceeds tolerance. Pending supervisor review.'
          : 'Till closed successfully.',
    );
  }
  
  /// Approve a pending variance (head_teller or admin only).
  static Future<void> approveVariance({
    required String sessionId,
    required String reviewNote,
  }) async {
    // Check role
    final profile = FirebaseService.sessionProfile;
    final role = profile?['role'] as String?;
    
    if (role != 'head_teller' && role != 'admin') {
      throw Exception('Only head tellers and admins can approve variances');
    }
    
    await _db.collection(AppConstants.tillSessionsCol).doc(sessionId).update({
      'status': 'closed',
      'reviewedBy': _userId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewNote': reviewNote,
    });
    
    await AuditService.log(
      action: 'VARIANCE_APPROVED',
      details: 'Till variance approved: $reviewNote',
      userId: _userId,
      metadata: {'tillSessionId': sessionId},
    );
  }
  
  // ─── Queries & Reports ───────────────────────────────────────────────────
  
  /// Get all sessions for a date (for reporting).
  static Future<List<TillSession>> getSessionsByDate(String businessDate);
  
  /// Get all pending review sessions (for supervisors).
  static Stream<QuerySnapshot> watchPendingReviewSessions();
  
  /// Get all till entries for a session (ledger).
  static Future<List<Map<String, dynamic>>> getSessionEntries(String sessionId);
  
  /// Get variance history for a teller (last N days).
  static Future<List<Map<String, dynamic>>> getVarianceHistory({
    required String tellerId,
    int days = 30,
  });
  
  // ─── Private Helpers ─────────────────────────────────────────────────────
  
  static int _computeCountedCash(Map<String, int> denominations) {
    return (denominations['50000'] ?? 0) * 50000 +
        (denominations['20000'] ?? 0) * 20000 +
        (denominations['10000'] ?? 0) * 10000 +
        (denominations['5000'] ?? 0) * 5000 +
        (denominations['2000'] ?? 0) * 2000 +
        (denominations['1000'] ?? 0) * 1000 +
        (denominations['500'] ?? 0) * 500 +
        (denominations['200'] ?? 0) * 200 +
        (denominations['100'] ?? 0) * 100 +
        (denominations['50'] ?? 0) * 50;
  }
  
  static Future<int> _recomputeFromLedger(String sessionId) async {
    final entries = await _db
        .collection(AppConstants.tillEntriesCol)
        .where('tillSessionId', isEqualTo: sessionId)
        .where('affectsCash', isEqualTo: true)
        .get();
    
    final session = await _db
        .collection(AppConstants.tillSessionsCol)
        .doc(sessionId)
        .get();
    
    final openingFloat = session.data()?['openingFloat'] as int? ?? 0;
    
    int totalIn = 0;
    int totalOut = 0;
    
    for (final doc in entries.docs) {
      final data = doc.data();
      final amount = data['amount'] as int;
      final direction = data['direction'] as String;
      
      if (direction == 'in') {
        totalIn += amount;
      } else {
        totalOut += amount;
      }
    }
    
    return openingFloat + totalIn - totalOut;
  }
  
  static Future<void> _notifyHeadTellers(String title, String message) async {
    final headTellers = await _db
        .collection(AppConstants.usersCol)
        .where('tenantId', isEqualTo: _tenantId)
        .where('role', whereIn: ['head_teller', 'admin'])
        .get();
    
    for (final doc in headTellers.docs) {
      await FirebaseService.sendNotification(
        doc.id,
        title,
        message,
        type: 'till_alert',
      );
    }
  }
  
  /// Get current EAT business date (YYYY-MM-DD).
  static String _getBusinessDate() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3)); // EAT = UTC+3
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
```

### 3.2 TellerService Integration

Refactor existing methods to accept till session and use `TillService.postEntry`.

```dart
class TellerService {
  // ... existing code ...
  
  static Future<Map<String, dynamic>> processDeposit({
    required TillSession? tillSession,  // NEW: required parameter
    required String memberId,
    required String memberName,
    required String memberPhone,
    required int amount,
    required String accountType,
    required String tellerName,
    required String tellerId,
    String? notes,
    String? paymentMethod,
    // ... other params ...
  }) async {
    // 1. Check till is open
    TillService.requireOpenSession(tillSession);
    
    // 2. Determine if cash affects till
    final isCash = (paymentMethod ?? 'Cash') == 'Cash';
    
    try {
      final batch = _db.batch();
      
      // 3. Create business transaction (savings/shares)
      final txnRef = _db.collection(AppConstants.savingsTxnCol).doc();
      batch.set(txnRef, {
        // ... existing fields ...
        'tillSessionId': tillSession!.id,  // NEW: link to till
      });
      
      // 4. Update member balance
      final memberRef = _db.collection('saccoplus-members').doc(memberId);
      batch.update(memberRef, {
        // ... existing balance updates ...
      });
      
      // 5. Record till entry
      TillService.postEntry(batch, tillSession, TillEntryInput(
        type: 'deposit',
        direction: 'in',
        amount: amount,
        affectsCash: isCash,
        method: paymentMethod ?? 'Cash',
        refCollection: AppConstants.savingsTxnCol,
        refId: txnRef.id,
        memberId: memberId,
        memberName: memberName,
        receiptNumber: transaction['receiptNumber'],
        note: notes,
        crossSession: false,
      ));
      
      // 6. Commit atomic write
      await batch.commit();
      
      // 7. Non-critical: notifications, SMS, audit (fire and forget)
      // ... existing notification code ...
      
      return {'success': true, 'transaction': transaction};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  static Future<Map<String, dynamic>> processWithdrawal({
    required TillSession? tillSession,  // NEW
    required String memberId,
    required String memberName,
    required String memberPhone,
    required int amount,
    required String accountType,
    required String tellerName,
    required String tellerId,
    String? notes,
  }) async {
    // 1. Check till is open
    TillService.requireOpenSession(tillSession);
    
    // 2. Check sufficient cash for cash withdrawals
    TillService.checkSufficientCash(tillSession!, amount);
    
    try {
      final batch = _db.batch();
      
      // 3. Create withdrawal transaction
      final txnRef = _db.collection(AppConstants.savingsTxnCol).doc();
      batch.set(txnRef, {
        // ... existing fields ...
        'tillSessionId': tillSession.id,
      });
      
      // 4. Update member balance
      final memberRef = _db.collection('saccoplus-members').doc(memberId);
      batch.update(memberRef, {
        // ... existing balance updates ...
      });
      
      // 5. Record till entry
      TillService.postEntry(batch, tillSession, TillEntryInput(
        type: 'withdrawal',
        direction: 'out',
        amount: amount,
        affectsCash: true,  // Withdrawals are always cash
        method: 'Cash',
        refCollection: AppConstants.savingsTxnCol,
        refId: txnRef.id,
        memberId: memberId,
        memberName: memberName,
        receiptNumber: transaction['receiptNumber'],
        note: notes,
        crossSession: false,
      ));
      
      await batch.commit();
      
      // Non-critical: notifications
      // ... existing code ...
      
      return {'success': true, 'transaction': transaction};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
```

### 3.3 Loan Payment Integration

Update `LoanPaymentCashDialog` and loan details screen to record till entry.

```dart
// In loan_details_screen.dart, after recording payment:

if (paymentMethod == 'Cash' && tillSession != null) {
  final batch = _db.batch();
  
  TillService.postEntry(batch, tillSession, TillEntryInput(
    type: 'loan_repayment',
    direction: 'in',
    amount: totalPaid.toInt(),
    affectsCash: true,
    method: 'Cash',
    refCollection: AppConstants.repaymentsCol,
    refId: repaymentDocId,
    memberId: loanData['memberId'],
    memberName: loanData['memberName'],
    receiptNumber: receiptNumber,
    note: 'Loan repayment',
    crossSession: false,
  ));
  
  await batch.commit();
}
```

### 3.4 Loan Disbursement Integration

Update `LoanDisbursementService` to record till entry for cash disbursements.

```dart
// In loan_disbursement_service.dart:

if (destinationType == 'cash' && tillSession != null) {
  TillService.checkSufficientCash(tillSession, amount.toInt());
  
  final batch = _db.batch();
  
  // ... existing disbursement code ...
  
  TillService.postEntry(batch, tillSession, TillEntryInput(
    type: 'loan_disbursement',
    direction: 'out',
    amount: amount.toInt(),
    affectsCash: true,
    method: 'Cash',
    refCollection: 'loan-disbursements',
    refId: disbursementId,
    memberId: memberId,
    memberName: loanData['memberName'],
    note: 'Loan disbursement',
    crossSession: false,
  ));
  
  await batch.commit();
}
```

---

## 4. UI Design

### 4.1 Teller Screen State Management

```dart
class _TellerScreenState extends State<TellerScreen> {
  TillSession? _currentSession;
  StreamSubscription? _sessionSub;
  
  @override
  void initState() {
    super.initState();
    _watchSession();
  }
  
  void _watchSession() {
    final tellerId = FirebaseService.sessionUid;
    _sessionSub = TillService.watchOpenSession(tellerId).listen((session) {
      if (mounted) {
        setState(() => _currentSession = session);
        
        // Check for stale session
        if (session != null && TillService.isStaleSession(session)) {
          _showStaleSessionDialog();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }
  
  // UI gating
  bool get _canTransact => _currentSession != null && 
      _currentSession!.status == 'open' &&
      !TillService.isStaleSession(_currentSession!);
  
  // ... rest of UI code ...
}
```

### 4.2 Till Bar Component

```dart
Widget _buildTillBar() {
  if (_currentSession == null) {
    return _buildClosedTillBanner();
  }
  
  if (TillService.isStaleSession(_currentSession!)) {
    return _buildStaleTillWarning();
  }
  
  final expectedCash = TillService.expectedCash(_currentSession!);
  final overMax = _getSettings()['tillMaxCash'] as int? ?? 10000000;
  final showMaxWarning = expectedCash > overMax;
  
  return Container(
    padding: const EdgeInsets.all(16),
    color: Colors.white,
    child: Column(
      children: [
        Row(
          children: [
            _statusChip('Till Open', Colors.green),
            const Spacer(),
            Text(_currentSession!.tellerName),
            const SizedBox(width: 16),
            _menuButton(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Opening', _currentSession!.openingFloat)),
            const SizedBox(width: 8),
            Expanded(child: _statCard('Cash In', _currentSession!.totalIn)),
            const SizedBox(width: 8),
            Expanded(child: _statCard('Cash Out', _currentSession!.totalOut)),
            const SizedBox(width: 8),
            Expanded(child: _statCard('Expected', expectedCash, bold: true)),
          ],
        ),
        if (showMaxWarning) ...[
          const SizedBox(height: 12),
          _warningBanner('Till over maximum capacity. Please sweep excess cash to vault.'),
        ],
      ],
    ),
  );
}
```

### 4.3 Blind Close Dialog

**Step 1: Denomination Count**
```dart
class _DenominationCountDialog extends StatefulWidget {
  final String sessionId;
  
  @override
  _DenominationCountDialogState createState() => _DenominationCountDialogState();
}

class _DenominationCountDialogState extends State<_DenominationCountDialog> {
  final Map<String, int> _counts = {
    '50000': 0, '20000': 0, '10000': 0, '5000': 0, '2000': 0,
    '1000': 0, '500': 0, '200': 0, '100': 0, '50': 0,
  };
  
  int get _countedTotal => TillService._computeCountedCash(_counts);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Count Cash'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter denomination counts', style: muted),
            const SizedBox(height: 16),
            ..._counts.keys.map((denom) => _denominationRow(denom)),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Counted Total:', style: bold),
                Text('UGX ${_fmt.format(_countedTotal)}', style: largeBold),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _countedTotal > 0 ? _submitCount : null,
          child: const Text('Submit Count'),
        ),
      ],
    );
  }
  
  Widget _denominationRow(String denom) {
    final value = int.parse(denom);
    final count = _counts[denom]!;
    final lineTotal = value * count;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('UGX ${_fmt.format(value)}')),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: count > 0 ? () => setState(() => _counts[denom] = count - 1) : null,
          ),
          SizedBox(
            width: 60,
            child: TextField(
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: count.toString()),
              onChanged: (v) {
                final newCount = int.tryParse(v) ?? 0;
                setState(() => _counts[denom] = newCount);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _counts[denom] = count + 1),
          ),
          const Spacer(),
          Text('UGX ${_fmt.format(lineTotal)}', style: monospace),
        ],
      ),
    );
  }
  
  Future<void> _submitCount() async {
    final result = await TillService.closeSession(
      sessionId: widget.sessionId,
      denominations: _counts,
    );
    
    if (!mounted) return;
    
    if (result.needsReview) {
      _showVarianceReasonDialog(result);
    } else {
      _showVarianceResult(result);
    }
  }
}
```

**Step 2: Variance Result**
```dart
void _showVarianceResult(CloseResult result) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(
            result.variance == 0 ? Icons.check_circle : Icons.info,
            color: result.variance == 0 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          const Text('Till Closed'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _resultRow('Counted Cash', result.countedCash),
          _resultRow('Expected Cash', result.expectedCash),
          const Divider(),
          _resultRow(
            'Variance',
            result.variance,
            color: result.variance == 0 ? Colors.green :
                   result.variance.abs() <= 5000 ? Colors.orange : Colors.red,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pop(context); // Close till screen
          },
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
```

### 4.4 All Tills Dashboard (Supervisor)

```dart
class AllTillsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: TillService.watchAllTillsToday(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        
        final sessions = snapshot.data!.docs
            .map((doc) => TillSession.fromFirestore(doc))
            .toList();
        
        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, i) => _tillCard(sessions[i]),
        );
      },
    );
  }
  
  Widget _tillCard(TillSession session) {
    final expectedCash = TillService.expectedCash(session);
    final isStale = TillService.isStaleSession(session);
    
    return Card(
      child: ListTile(
        leading: _statusChip(session.status),
        title: Text(session.tellerName),
        subtitle: Text('Last activity: ${_timeAgo(session.lastActivityAt)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Expected: UGX ${_fmt.format(expectedCash)}', style: bold),
            Text('${session.txnCount} transactions', style: muted),
          ],
        ),
        onTap: () => _showSessionDetails(session),
        tileColor: isStale ? Colors.red.shade50 : null,
      ),
    );
  }
}
```

---

## 5. Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function sameTenant() {
      return request.auth != null &&
             request.resource.data.tenantId == get(/databases/$(database)/documents/saccoplus-members/$(request.auth.uid)).data.tenantId;
    }
    
    function isTeller() {
      let profile = get(/databases/$(database)/documents/saccoplus-members/$(request.auth.uid)).data;
      return profile.role in ['teller', 'head_teller', 'admin'];
    }
    
    function isHeadTeller() {
      let profile = get(/databases/$(database)/documents/saccoplus-members/$(request.auth.uid)).data;
      return profile.role in ['head_teller', 'admin'];
    }
    
    function sessionIsOpen(sessionId) {
      let session = get(/databases/$(database)/documents/saccoplus-till-sessions/$(sessionId)).data;
      return session.status == 'open';
    }
    
    // Till Sessions
    match /saccoplus-till-sessions/{sessionId} {
      allow read: if request.auth != null && sameTenant();
      
      allow create: if isTeller() &&
                      request.resource.data.status == 'open' &&
                      request.resource.data.tellerId == request.auth.uid &&
                      sameTenant();
      
      allow update: if resource.data.status != 'closed' &&
                      (resource.data.tellerId == request.auth.uid || isHeadTeller());
      
      allow delete: if false; // Never delete sessions
    }
    
    // Till Entries (Append-Only)
    match /saccoplus-till-entries/{entryId} {
      allow read: if request.auth != null && sameTenant();
      
      allow create: if isTeller() &&
                      sameTenant() &&
                      sessionIsOpen(request.resource.data.tillSessionId);
      
      allow update, delete: if false; // Append-only: never update or delete
    }
  }
}
```

---

## 6. Firestore Indexes

**File:** `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "saccoplus-till-sessions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "tellerId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "saccoplus-till-sessions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "businessDate", "order": "DESCENDING"},
        {"fieldPath": "openedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "saccoplus-till-sessions",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "openedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "saccoplus-till-entries",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "tillSessionId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "saccoplus-till-entries",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "tellerId", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "saccoplus-till-entries",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "type", "order": "ASCENDING"},
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## 7. Constants Update

**File:** `lib/core/constants.dart`

Add new collection name constants:

```dart
class AppConstants {
  // ... existing constants ...
  
  // Till Management
  static const String tillSessionsCol = 'saccoplus-till-sessions';
  static const String tillEntriesCol  = 'saccoplus-till-entries';
}
```

---

## 8. Migration Strategy

### 8.1 Phase 1: Non-Breaking Addition
- Deploy `TillService` with all methods
- Add `tillSessionId` field to transaction collections (nullable, not required)
- Deploy security rules (allow reads, block writes to new collections until UI ready)
- Deploy Firestore indexes

### 8.2 Phase 2: Parallel Operation
- Update `TellerService` methods to accept optional `tillSession` parameter
- If `tillSession` provided, record till entry; if null, skip (backward compatible)
- Tellers can choose to use old or new flow

### 8.3 Phase 3: Enforcement
- Make `tillSession` required in all transaction methods
- UI enforces: no open session = no transactions
- Old transactions without `tillSessionId` marked as `legacy: true` via migration script

### 8.4 Backfill Script (Optional)
For existing transactions, create a one-time script to:
- Find transactions without `tillSessionId`
- Mark them with `legacy: true` flag
- Do NOT create retroactive till entries (would corrupt cash reconciliation)

---

**END OF DESIGN DOCUMENT**

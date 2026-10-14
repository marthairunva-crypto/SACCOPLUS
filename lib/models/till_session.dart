import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a till session owned by a teller.
/// Sessions are opened at shift start, accumulate cash movements,
/// and are reconciled at close via blind count.
class TillSession {
  /// Unique session ID (Firestore document ID)
  final String id;

  /// Tenant/SACCO identifier
  final String tenantId;

  /// Teller user ID who owns this session
  final String tellerId;

  /// Teller display name
  final String tellerName;

  /// Business date this session is associated with (YYYY-MM-DD format)
  final String businessDate;

  /// Session status: 'open', 'pending_approval', 'closed'
  final String status;

  /// Opening float amount (UGX)
  final int openingFloat;

  /// Total cash-in entries (deposits, loan repayments, etc.)
  final int totalIn;

  /// Total cash-out entries (withdrawals, loan disbursements, etc.)
  final int totalOut;

  /// Expected cash = openingFloat + totalIn - totalOut (always derived)
  int get expectedCash => openingFloat + totalIn - totalOut;

  /// Actual cash counted during close (null until counted)
  final int? actualCash;

  /// Cash variance = actualCash - expectedCash (null until counted)
  int? get variance => actualCash != null ? actualCash! - expectedCash : null;

  /// Denomination breakdown (map of note/coin value to count)
  /// Example: {'50000': 5, '20000': 10, '10000': 3} = UGX 450,000
  final Map<String, int>? denominations;

  /// Reason provided for variance (required if beyond tolerance)
  final String? varianceReason;

  /// Supervisor who approved variance (if needed)
  final String? approvedBy;

  /// Supervisor display name
  final String? approvedByName;

  /// When variance was approved
  final DateTime? approvedAt;

  /// When session was opened
  final DateTime openedAt;

  /// When session was closed (null if still open)
  final DateTime? closedAt;

  /// Additional notes or remarks
  final String? notes;

  TillSession({
    required this.id,
    required this.tenantId,
    required this.tellerId,
    required this.tellerName,
    required this.businessDate,
    required this.status,
    required this.openingFloat,
    required this.totalIn,
    required this.totalOut,
    this.actualCash,
    this.denominations,
    this.varianceReason,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.openedAt,
    this.closedAt,
    this.notes,
  });

  /// Create TillSession from Firestore document
  factory TillSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TillSession(
      id: doc.id,
      tenantId: data['tenantId'] as String,
      tellerId: data['tellerId'] as String,
      tellerName: data['tellerName'] as String,
      businessDate: data['businessDate'] as String,
      status: data['status'] as String,
      openingFloat: (data['openingFloat'] as num).toInt(),
      totalIn: (data['totalIn'] as num).toInt(),
      totalOut: (data['totalOut'] as num).toInt(),
      actualCash: data['actualCash'] != null ? (data['actualCash'] as num).toInt() : null,
      denominations: data['denominations'] != null
          ? Map<String, int>.from(data['denominations'] as Map)
          : null,
      varianceReason: data['varianceReason'] as String?,
      approvedBy: data['approvedBy'] as String?,
      approvedByName: data['approvedByName'] as String?,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      openedAt: (data['openedAt'] as Timestamp).toDate(),
      closedAt: data['closedAt'] != null
          ? (data['closedAt'] as Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
    );
  }

  /// Convert TillSession to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'tellerId': tellerId,
      'tellerName': tellerName,
      'businessDate': businessDate,
      'status': status,
      'openingFloat': openingFloat,
      'totalIn': totalIn,
      'totalOut': totalOut,
      if (actualCash != null) 'actualCash': actualCash,
      if (denominations != null) 'denominations': denominations,
      if (varianceReason != null) 'varianceReason': varianceReason,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedByName != null) 'approvedByName': approvedByName,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      'openedAt': Timestamp.fromDate(openedAt),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      if (notes != null) 'notes': notes,
    };
  }

  /// Copy with method for creating modified copies
  TillSession copyWith({
    String? id,
    String? tenantId,
    String? tellerId,
    String? tellerName,
    String? businessDate,
    String? status,
    int? openingFloat,
    int? totalIn,
    int? totalOut,
    int? actualCash,
    Map<String, int>? denominations,
    String? varianceReason,
    String? approvedBy,
    String? approvedByName,
    DateTime? approvedAt,
    DateTime? openedAt,
    DateTime? closedAt,
    String? notes,
  }) {
    return TillSession(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      tellerId: tellerId ?? this.tellerId,
      tellerName: tellerName ?? this.tellerName,
      businessDate: businessDate ?? this.businessDate,
      status: status ?? this.status,
      openingFloat: openingFloat ?? this.openingFloat,
      totalIn: totalIn ?? this.totalIn,
      totalOut: totalOut ?? this.totalOut,
      actualCash: actualCash ?? this.actualCash,
      denominations: denominations ?? this.denominations,
      varianceReason: varianceReason ?? this.varianceReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvedAt: approvedAt ?? this.approvedAt,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'TillSession(id: $id, teller: $tellerName, date: $businessDate, '
        'status: $status, expected: $expectedCash, actual: $actualCash)';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a waiver request for a loan charge
class ChargeWaiver {
  /// Unique waiver ID (Firestore document ID)
  final String id;

  /// Charge this waiver applies to
  final String chargeId;

  /// Loan ID (denormalized)
  final String loanId;

  /// Member ID (denormalized)
  final String memberId;

  /// Tenant/SACCO identifier
  final String tenantId;

  /// Amount to waive (UGX)
  final int amount;

  /// Reason for waiver (required)
  final String reason;

  /// User ID who requested the waiver
  final String requestedBy;

  /// Display name of requester
  final String requestedByName;

  /// When waiver was requested
  final DateTime requestedAt;

  /// Waiver status: 'pending', 'approved', 'rejected'
  final String status;

  /// User ID who approved/rejected
  final String? reviewedBy;

  /// Display name of reviewer
  final String? reviewedByName;

  /// When waiver was reviewed
  final DateTime? reviewedAt;

  /// Reviewer's notes
  final String? reviewerNotes;

  ChargeWaiver({
    required this.id,
    required this.chargeId,
    required this.loanId,
    required this.memberId,
    required this.tenantId,
    required this.amount,
    required this.reason,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedAt,
    required this.status,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewerNotes,
  });

  /// Create ChargeWaiver from Firestore document
  factory ChargeWaiver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChargeWaiver(
      id: doc.id,
      chargeId: data['chargeId'] as String,
      loanId: data['loanId'] as String,
      memberId: data['memberId'] as String,
      tenantId: data['tenantId'] as String,
      amount: (data['amount'] as num).toInt(),
      reason: data['reason'] as String,
      requestedBy: data['requestedBy'] as String,
      requestedByName: data['requestedByName'] as String,
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      status: data['status'] as String? ?? 'pending',
      reviewedBy: data['reviewedBy'] as String?,
      reviewedByName: data['reviewedByName'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewerNotes: data['reviewerNotes'] as String?,
    );
  }

  /// Convert ChargeWaiver to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'chargeId': chargeId,
      'loanId': loanId,
      'memberId': memberId,
      'tenantId': tenantId,
      'amount': amount,
      'reason': reason,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': status,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (reviewedByName != null) 'reviewedByName': reviewedByName,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewerNotes != null) 'reviewerNotes': reviewerNotes,
    };
  }

  @override
  String toString() {
    return 'ChargeWaiver(id: $id, chargeId: $chargeId, amount: $amount, '
        'status: $status)';
  }
}

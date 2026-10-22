import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a charge applied to a loan
class LoanCharge {
  /// Unique charge ID (Firestore document ID)
  final String id;

  /// Loan this charge belongs to
  final String loanId;

  /// Member/Farmer ID
  final String memberId;

  /// Tenant/SACCO identifier
  final String tenantId;

  /// Reference to charge type
  final String chargeTypeId;

  /// Charge type name (denormalized for display)
  final String chargeTypeName;

  /// Schedule item ID if this charge relates to a specific instalment (nullable)
  final String? scheduleItemId;

  /// Instalment number if this charge relates to a specific instalment (nullable)
  final int? instalmentNumber;

  /// Total charge amount (UGX)
  final int amount;

  /// Amount paid towards this charge (UGX)
  final int amountPaid;

  /// Amount waived (UGX)
  final int amountWaived;

  /// Charge status: 'pending', 'partial', 'paid', 'waived', 'reversed'
  final String status;

  /// Date the charge was applied
  final DateTime chargeDate;

  /// Required notes explaining why this charge was applied
  final String notes;

  /// User ID who applied this charge
  final String appliedBy;

  /// Display name of user who applied charge
  final String appliedByName;

  /// When this charge was created
  final DateTime createdAt;

  /// When this charge was last updated
  final DateTime? updatedAt;

  /// If reversed, who reversed it
  final String? reversedBy;

  /// If reversed, when it was reversed
  final DateTime? reversedAt;

  /// If reversed, reason for reversal
  final String? reversalReason;

  /// Outstanding amount on this charge
  int get amountOutstanding => amount - amountPaid - amountWaived;

  /// Whether charge is fully settled
  bool get isFullySettled => amountOutstanding <= 0;

  LoanCharge({
    required this.id,
    required this.loanId,
    required this.memberId,
    required this.tenantId,
    required this.chargeTypeId,
    required this.chargeTypeName,
    this.scheduleItemId,
    this.instalmentNumber,
    required this.amount,
    required this.amountPaid,
    required this.amountWaived,
    required this.status,
    required this.chargeDate,
    required this.notes,
    required this.appliedBy,
    required this.appliedByName,
    required this.createdAt,
    this.updatedAt,
    this.reversedBy,
    this.reversedAt,
    this.reversalReason,
  });

  /// Create LoanCharge from Firestore document
  factory LoanCharge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    try {
      return LoanCharge(
        id: doc.id,
        loanId: data['loanId'] as String? ?? '',
        memberId: data['memberId'] as String? ?? '',
        tenantId: data['tenantId'] as String? ?? '',
        chargeTypeId: data['chargeTypeId'] as String? ?? '',
        chargeTypeName: data['chargeTypeName'] as String? ?? 'Unknown Charge',
        scheduleItemId: data['scheduleItemId'] as String?,
        instalmentNumber: (data['instalmentNumber'] as num?)?.toInt(),
        amount: (data['amount'] as num?)?.toInt() ?? 0,
        amountPaid: (data['amountPaid'] as num?)?.toInt() ?? 0,
        amountWaived: (data['amountWaived'] as num?)?.toInt() ?? 0,
        status: data['status'] as String? ?? 'pending',
        chargeDate: (data['chargeDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        notes: data['notes'] as String? ?? '',
        appliedBy: data['appliedBy'] as String? ?? 'unknown',
        appliedByName: data['appliedByName'] as String? ?? 'Unknown',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        reversedBy: data['reversedBy'] as String?,
        reversedAt: (data['reversedAt'] as Timestamp?)?.toDate(),
        reversalReason: data['reversalReason'] as String?,
      );
    } catch (e) {
      print('❌ Error parsing charge document ${doc.id}: $e');
      print('   Data: $data');
      rethrow;
    }
  }

  /// Convert LoanCharge to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'loanId': loanId,
      'memberId': memberId,
      'tenantId': tenantId,
      'chargeTypeId': chargeTypeId,
      'chargeTypeName': chargeTypeName,
      if (scheduleItemId != null) 'scheduleItemId': scheduleItemId,
      if (instalmentNumber != null) 'instalmentNumber': instalmentNumber,
      'amount': amount,
      'amountPaid': amountPaid,
      'amountWaived': amountWaived,
      'status': status,
      'chargeDate': Timestamp.fromDate(chargeDate),
      'notes': notes,
      'appliedBy': appliedBy,
      'appliedByName': appliedByName,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (reversedBy != null) 'reversedBy': reversedBy,
      if (reversedAt != null) 'reversedAt': Timestamp.fromDate(reversedAt!),
      if (reversalReason != null) 'reversalReason': reversalReason,
    };
  }

  /// Copy with method for creating modified copies
  LoanCharge copyWith({
    String? id,
    String? loanId,
    String? memberId,
    String? tenantId,
    String? chargeTypeId,
    String? chargeTypeName,
    String? scheduleItemId,
    int? instalmentNumber,
    int? amount,
    int? amountPaid,
    int? amountWaived,
    String? status,
    DateTime? chargeDate,
    String? notes,
    String? appliedBy,
    String? appliedByName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reversedBy,
    DateTime? reversedAt,
    String? reversalReason,
  }) {
    return LoanCharge(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      memberId: memberId ?? this.memberId,
      tenantId: tenantId ?? this.tenantId,
      chargeTypeId: chargeTypeId ?? this.chargeTypeId,
      chargeTypeName: chargeTypeName ?? this.chargeTypeName,
      scheduleItemId: scheduleItemId ?? this.scheduleItemId,
      instalmentNumber: instalmentNumber ?? this.instalmentNumber,
      amount: amount ?? this.amount,
      amountPaid: amountPaid ?? this.amountPaid,
      amountWaived: amountWaived ?? this.amountWaived,
      status: status ?? this.status,
      chargeDate: chargeDate ?? this.chargeDate,
      notes: notes ?? this.notes,
      appliedBy: appliedBy ?? this.appliedBy,
      appliedByName: appliedByName ?? this.appliedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reversedBy: reversedBy ?? this.reversedBy,
      reversedAt: reversedAt ?? this.reversedAt,
      reversalReason: reversalReason ?? this.reversalReason,
    );
  }

  @override
  String toString() {
    return 'LoanCharge(id: $id, loanId: $loanId, type: $chargeTypeName, '
        'amount: $amount, outstanding: $amountOutstanding, status: $status)';
  }
}

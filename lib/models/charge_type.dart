import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a type of charge that can be applied to loans
/// Examples: late_payment, demand_letter, recovery_fee, legal_fee, rescheduling_fee
class ChargeType {
  /// Unique charge type ID (Firestore document ID)
  final String id;

  /// Tenant/SACCO identifier
  final String tenantId;

  /// Display name (e.g., "Late Payment Fee")
  final String name;

  /// Unique code (e.g., "late_payment")
  final String code;

  /// Calculation basis: 'flat', 'pct_overdue_instalment', 'pct_arrears', 
  /// 'pct_outstanding_principal', 'manual_amount'
  final String calcBasis;

  /// Default amount for flat charges (UGX)
  final int defaultAmount;

  /// Default rate for percentage charges (e.g., 2.0 for 2%)
  final double defaultRate;

  /// Whether this charge type is active and can be used
  final bool isActive;

  /// Description of the charge
  final String? description;

  /// When this charge type was created
  final DateTime createdAt;

  /// When this charge type was last updated
  final DateTime? updatedAt;

  /// User who created this charge type
  final String? createdBy;

  ChargeType({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.code,
    required this.calcBasis,
    required this.defaultAmount,
    required this.defaultRate,
    required this.isActive,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Create ChargeType from Firestore document
  factory ChargeType.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChargeType(
      id: doc.id,
      tenantId: data['tenantId'] as String? ?? '',
      name: data['name'] as String,
      code: data['code'] as String,
      calcBasis: data['calcBasis'] as String? ?? 'flat',
      defaultAmount: (data['defaultAmount'] as num?)?.toInt() ?? 0,
      defaultRate: (data['defaultRate'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? true,
      description: data['description'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  /// Convert ChargeType to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'name': name,
      'code': code,
      'calcBasis': calcBasis,
      'defaultAmount': defaultAmount,
      'defaultRate': defaultRate,
      'isActive': isActive,
      if (description != null) 'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (createdBy != null) 'createdBy': createdBy,
    };
  }

  /// Copy with method for creating modified copies
  ChargeType copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? code,
    String? calcBasis,
    int? defaultAmount,
    double? defaultRate,
    bool? isActive,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ChargeType(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      code: code ?? this.code,
      calcBasis: calcBasis ?? this.calcBasis,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      defaultRate: defaultRate ?? this.defaultRate,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'ChargeType(id: $id, name: $name, code: $code, '
        'calcBasis: $calcBasis, active: $isActive)';
  }
}

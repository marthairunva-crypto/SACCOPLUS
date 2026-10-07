import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single cash movement in a till session.
/// All entries are append-only (no updates/deletes allowed).
/// Corrections are made by posting reversing entries.
class TillEntry {
  /// Unique entry ID (Firestore document ID)
  final String id;

  /// Tenant/SACCO identifier
  final String tenantId;

  /// Till session this entry belongs to
  final String tillSessionId;

  /// Teller who posted this entry
  final String tellerId;

  /// Teller display name
  final String tellerName;

  /// Entry type: 'deposit', 'withdrawal', 'loan_disbursement', 'loan_repayment',
  /// 'vault_topup', 'vault_sweep', 'opening_float', 'reversal', etc.
  final String entryType;

  /// Amount in UGX (positive for in, negative for out)
  /// - Deposits, repayments, topups: positive
  /// - Withdrawals, disbursements, sweeps: negative
  final int amount;

  /// Whether this entry affects physical cash in the till
  /// true = cash transaction, false = mobile money/bank (recorded but doesn't affect till)
  final bool affectsCash;

  /// Payment method: 'Cash', 'Mobile Money', 'Bank Transfer'
  final String paymentMethod;

  /// Member ID (if transaction involves a member)
  final String? memberId;

  /// Member name (if transaction involves a member)
  final String? memberName;

  /// Related business transaction ID (deposit, loan, etc.)
  final String? businessRecordId;

  /// Related business transaction type ('deposit', 'withdrawal', 'loan', etc.)
  final String? businessRecordType;

  /// ID of the entry being reversed (if this is a reversal)
  final String? reversesEntryId;

  /// Notes or description
  final String notes;

  /// When this entry was created (append-only, never changes)
  final DateTime createdAt;

  /// User who created this entry
  final String createdBy;

  TillEntry({
    required this.id,
    required this.tenantId,
    required this.tillSessionId,
    required this.tellerId,
    required this.tellerName,
    required this.entryType,
    required this.amount,
    required this.affectsCash,
    required this.paymentMethod,
    this.memberId,
    this.memberName,
    this.businessRecordId,
    this.businessRecordType,
    this.reversesEntryId,
    required this.notes,
    required this.createdAt,
    required this.createdBy,
  });

  /// Create TillEntry from Firestore document
  factory TillEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TillEntry(
      id: doc.id,
      tenantId: data['tenantId'] as String,
      tillSessionId: data['tillSessionId'] as String,
      tellerId: data['tellerId'] as String,
      tellerName: data['tellerName'] as String,
      entryType: data['entryType'] as String,
      amount: (data['amount'] as num).toInt(),
      affectsCash: data['affectsCash'] as bool,
      paymentMethod: data['paymentMethod'] as String,
      memberId: data['memberId'] as String?,
      memberName: data['memberName'] as String?,
      businessRecordId: data['businessRecordId'] as String?,
      businessRecordType: data['businessRecordType'] as String?,
      reversesEntryId: data['reversesEntryId'] as String?,
      notes: data['notes'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
    );
  }

  /// Convert TillEntry to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'tillSessionId': tillSessionId,
      'tellerId': tellerId,
      'tellerName': tellerName,
      'entryType': entryType,
      'amount': amount,
      'affectsCash': affectsCash,
      'paymentMethod': paymentMethod,
      if (memberId != null) 'memberId': memberId,
      if (memberName != null) 'memberName': memberName,
      if (businessRecordId != null) 'businessRecordId': businessRecordId,
      if (businessRecordType != null) 'businessRecordType': businessRecordType,
      if (reversesEntryId != null) 'reversesEntryId': reversesEntryId,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  /// Helper to check if entry is a cash-in (positive amount affecting cash)
  bool get isCashIn => affectsCash && amount > 0;

  /// Helper to check if entry is a cash-out (negative amount affecting cash)
  bool get isCashOut => affectsCash && amount < 0;

  /// Helper to check if entry is a reversal
  bool get isReversal => entryType == 'reversal';

  /// Copy with method for creating modified copies
  TillEntry copyWith({
    String? id,
    String? tenantId,
    String? tillSessionId,
    String? tellerId,
    String? tellerName,
    String? entryType,
    int? amount,
    bool? affectsCash,
    String? paymentMethod,
    String? memberId,
    String? memberName,
    String? businessRecordId,
    String? businessRecordType,
    String? reversesEntryId,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return TillEntry(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      tillSessionId: tillSessionId ?? this.tillSessionId,
      tellerId: tellerId ?? this.tellerId,
      tellerName: tellerName ?? this.tellerName,
      entryType: entryType ?? this.entryType,
      amount: amount ?? this.amount,
      affectsCash: affectsCash ?? this.affectsCash,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      businessRecordId: businessRecordId ?? this.businessRecordId,
      businessRecordType: businessRecordType ?? this.businessRecordType,
      reversesEntryId: reversesEntryId ?? this.reversesEntryId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'TillEntry(id: $id, type: $entryType, amount: $amount, '
        'affectsCash: $affectsCash, session: $tillSessionId)';
  }
}

/// Input data for posting a new till entry
/// Used by TillService.postEntry() to avoid passing too many parameters
class TillEntryInput {
  final String entryType;
  final int amount;
  final bool affectsCash;
  final String paymentMethod;
  final String? memberId;
  final String? memberName;
  final String? businessRecordId;
  final String? businessRecordType;
  final String? reversesEntryId;
  final String notes;

  TillEntryInput({
    required this.entryType,
    required this.amount,
    required this.affectsCash,
    this.paymentMethod = 'Cash',
    this.memberId,
    this.memberName,
    this.businessRecordId,
    this.businessRecordType,
    this.reversesEntryId,
    this.notes = '',
  });

  /// Create input for a cash deposit
  factory TillEntryInput.deposit({
    required int amount,
    required String memberId,
    required String memberName,
    required String businessRecordId,
    String paymentMethod = 'Cash',
    String notes = '',
  }) {
    return TillEntryInput(
      entryType: 'deposit',
      amount: amount,
      affectsCash: paymentMethod == 'Cash',
      paymentMethod: paymentMethod,
      memberId: memberId,
      memberName: memberName,
      businessRecordId: businessRecordId,
      businessRecordType: 'deposit',
      notes: notes,
    );
  }

  /// Create input for a cash withdrawal
  factory TillEntryInput.withdrawal({
    required int amount,
    required String memberId,
    required String memberName,
    required String businessRecordId,
    String paymentMethod = 'Cash',
    String notes = '',
  }) {
    return TillEntryInput(
      entryType: 'withdrawal',
      amount: -amount.abs(), // Ensure negative
      affectsCash: paymentMethod == 'Cash',
      paymentMethod: paymentMethod,
      memberId: memberId,
      memberName: memberName,
      businessRecordId: businessRecordId,
      businessRecordType: 'withdrawal',
      notes: notes,
    );
  }

  /// Create input for a loan disbursement
  factory TillEntryInput.loanDisbursement({
    required int amount,
    required String memberId,
    required String memberName,
    required String loanId,
    String paymentMethod = 'Cash',
    String notes = '',
  }) {
    return TillEntryInput(
      entryType: 'loan_disbursement',
      amount: -amount.abs(), // Ensure negative (cash out)
      affectsCash: paymentMethod == 'Cash',
      paymentMethod: paymentMethod,
      memberId: memberId,
      memberName: memberName,
      businessRecordId: loanId,
      businessRecordType: 'loan',
      notes: notes,
    );
  }

  /// Create input for a loan repayment
  factory TillEntryInput.loanRepayment({
    required int amount,
    required String memberId,
    required String memberName,
    required String repaymentId,
    String paymentMethod = 'Cash',
    String notes = '',
  }) {
    return TillEntryInput(
      entryType: 'loan_repayment',
      amount: amount.abs(), // Ensure positive (cash in)
      affectsCash: paymentMethod == 'Cash',
      paymentMethod: paymentMethod,
      memberId: memberId,
      memberName: memberName,
      businessRecordId: repaymentId,
      businessRecordType: 'repayment',
      notes: notes,
    );
  }
}

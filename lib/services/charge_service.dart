import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/firebase_service.dart';
import '../models/loan_charge.dart';
import '../models/charge_type.dart';
import '../models/charge_waiver.dart';
import 'audit_service.dart';
import 'loan_math.dart';

/// Service for managing loan charges
/// IMPORTANT: Charges are NEVER applied automatically - only manually by staff
class ChargeService {
  static final _db = FirebaseFirestore.instance;
  static final _uuid = const Uuid();

  // ══════════════════════════════════════════════════════════════════════════
  // CHARGE TYPE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all charge types for a tenant
  static Future<List<ChargeType>> getChargeTypes({
    String? tenantId,
    bool activeOnly = true,
  }) async {
    try {
      final tid = tenantId ?? FirebaseService.sessionTenantId;
      var query = _db
          .collection('charge_types')
          .where('tenantId', isEqualTo: tid);

      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => ChargeType.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error getting charge types: $e');
      return [];
    }
  }

  /// Delete a charge type
  static Future<Map<String, dynamic>> deleteChargeType(String chargeTypeId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      
      // Check if charge type is in use
      final chargesUsingType = await _db
          .collectionGroup('charges')
          .where('chargeTypeId', isEqualTo: chargeTypeId)
          .limit(1)
          .get();
      
      if (chargesUsingType.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Cannot delete charge type that is in use. Deactivate it instead.'
        };
      }

      // Get charge type details for audit
      final chargeTypeDoc = await _db.collection('charge_types').doc(chargeTypeId).get();
      final chargeTypeName = chargeTypeDoc.data()?['name'] ?? 'Unknown';

      // Delete the charge type
      await _db.collection('charge_types').doc(chargeTypeId).delete();

      await AuditService.log(
        action: 'CHARGE_TYPE_DELETED',
        details: 'Deleted charge type: $chargeTypeName',
        userId: uid,
        metadata: {'chargeTypeId': chargeTypeId},
      );

      return {'success': true, 'message': 'Charge type deleted successfully'};
    } catch (e) {
      print('❌ Error deleting charge type: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Bulk delete all charges from a loan (reset loan to normal)
  static Future<Map<String, dynamic>> deleteAllChargesFromLoan({
    required String loanId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return {'success': false, 'message': 'Reason is required'};
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      // Get loan details
      final loanRef = _db.collection(AppConstants.loansCol).doc(loanId);
      final loanSnap = await loanRef.get();

      if (!loanSnap.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanSnap.data()!;
      final memberId = loanData['memberId'] as String;

      // Get all charges for this loan
      final chargesSnapshot = await _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .get();

      if (chargesSnapshot.docs.isEmpty) {
        return {'success': false, 'message': 'No charges to delete'};
      }

      int totalChargesDeleted = 0;
      int totalAmountRemoved = 0;

      // Execute as transaction
      await _db.runTransaction((transaction) async {
        // 1. Delete all charge documents
        for (final chargeDoc in chargesSnapshot.docs) {
          final charge = LoanCharge.fromFirestore(chargeDoc);
          
          // Only delete unpaid charges, skip paid ones
          if (charge.amountPaid == 0 && charge.status != 'reversed') {
            transaction.delete(chargeDoc.reference);
            totalChargesDeleted++;
            totalAmountRemoved += charge.amountOutstanding;
          }
        }

        // 2. Reset loan charge totals to zero
        transaction.update(loanRef, {
          'charges': 0,
          'chargesExpected': 0,
          'chargesPaid': 0,
          'chargesWaived': 0,
          'chargesOutstanding': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Recalculate totalOutstanding
        final principalOut = LoanMath.d(loanData['principalOutstanding']);
        final interestOut = LoanMath.d(loanData['interestOutstanding']);
        final newTotalOut = (principalOut + interestOut).toInt();

        transaction.update(loanRef, {
          'totalOutstanding': newTotalOut,
          'outstandingBalance': newTotalOut,
          'remainingBalance': newTotalOut,
        });
      });

      await AuditService.log(
        action: 'BULK_CHARGES_DELETED',
        details: 'Deleted all charges from loan. Count: $totalChargesDeleted, Amount: UGX ${_formatMoney(totalAmountRemoved)}. Reason: $reason',
        userId: uid,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'chargesDeleted': totalChargesDeleted,
          'amountRemoved': totalAmountRemoved,
          'reason': reason,
        },
      );

      return {
        'success': true,
        'message': 'Deleted $totalChargesDeleted charge(s) successfully. Loan reset to normal.',
        'chargesDeleted': totalChargesDeleted,
      };
    } catch (e) {
      print('❌ Error deleting all charges: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Seed default charge types for a tenant
  static Future<void> seedDefaultChargeTypes(String tenantId) async {
    try {
      final defaults = [
        {
          'name': 'Late Payment Fee',
          'code': 'late_payment',
          'calcBasis': 'pct_overdue_instalment',
          'defaultAmount': 0,
          'defaultRate': 2.0,
          'description': 'Penalty for overdue instalment payments'
        },
        {
          'name': 'Demand Letter Fee',
          'code': 'demand_letter',
          'calcBasis': 'flat',
          'defaultAmount': 50000,
          'defaultRate': 0.0,
          'description': 'Cost of sending demand letter to borrower'
        },
        {
          'name': 'Recovery Fee',
          'code': 'recovery_fee',
          'calcBasis': 'pct_arrears',
          'defaultAmount': 0,
          'defaultRate': 5.0,
          'description': 'Fee for loan recovery actions'
        },
        {
          'name': 'Legal Fee',
          'code': 'legal_fee',
          'calcBasis': 'manual_amount',
          'defaultAmount': 0,
          'defaultRate': 0.0,
          'description': 'Legal costs for loan enforcement'
        },
        {
          'name': 'Rescheduling Fee',
          'code': 'rescheduling_fee',
          'calcBasis': 'flat',
          'defaultAmount': 100000,
          'defaultRate': 0.0,
          'description': 'Administrative fee for loan rescheduling'
        },
      ];

      final batch = _db.batch();
      for (final def in defaults) {
        final id = _uuid.v4();
        final ref = _db.collection('charge_types').doc(id);
        batch.set(ref, {
          ...def,
          'tenantId': tenantId,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('✅ Seeded ${defaults.length} default charge types for tenant $tenantId');
    } catch (e) {
      print('❌ Error seeding charge types: $e');
    }
  }

  /// Create or update a charge type
  static Future<Map<String, dynamic>> saveChargeType({
    String? id,
    required String name,
    required String code,
    required String calcBasis,
    required int defaultAmount,
    required double defaultRate,
    required bool isActive,
    String? description,
  }) async {
    try {
      final tenantId = FirebaseService.sessionTenantId;
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final now = DateTime.now();

      final data = {
        'tenantId': tenantId,
        'name': name,
        'code': code,
        'calcBasis': calcBasis,
        'defaultAmount': defaultAmount,
        'defaultRate': defaultRate,
        'isActive': isActive,
        if (description != null) 'description': description,
        'updatedAt': Timestamp.fromDate(now),
      };

      if (id == null) {
        // Create new
        final docId = _uuid.v4();
        data['createdAt'] = Timestamp.fromDate(now);
        data['createdBy'] = uid;
        await _db.collection('charge_types').doc(docId).set(data);

        await AuditService.log(
          action: 'CHARGE_TYPE_CREATED',
          details: 'Created charge type: $name ($code)',
          userId: uid,
          metadata: {'chargeTypeId': docId, 'code': code},
        );

        return {'success': true, 'id': docId};
      } else {
        // Update existing
        await _db.collection('charge_types').doc(id).update(data);

        await AuditService.log(
          action: 'CHARGE_TYPE_UPDATED',
          details: 'Updated charge type: $name ($code)',
          userId: uid,
          metadata: {'chargeTypeId': id, 'code': code},
        );

        return {'success': true, 'id': id};
      }
    } catch (e) {
      print('❌ Error saving charge type: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHARGE CALCULATION & SUGGESTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Suggest charge amount based on charge type and loan data
  /// IMPORTANT: This ONLY returns a suggestion - never writes anything
  static int suggestAmount({
    required Map<String, dynamic> loan,
    required ChargeType chargeType,
    Map<String, dynamic>? scheduleItem,
  }) {
    try {
      final principal = LoanMath.d(loan['loanAmount']);
      final instalment = LoanMath.d(loan['installment']);
      final arrears = LoanMath.d(loan['arrears']);
      final principalOut = LoanMath.d(loan['principalOutstanding']);

      switch (chargeType.calcBasis) {
        case 'flat':
          return chargeType.defaultAmount;

        case 'pct_overdue_instalment':
          if (scheduleItem != null) {
            final schedInstalment = LoanMath.d(scheduleItem['amount']);
            return (schedInstalment * chargeType.defaultRate / 100).round();
          }
          return (instalment * chargeType.defaultRate / 100).round();

        case 'pct_arrears':
          return (arrears * chargeType.defaultRate / 100).round();

        case 'pct_outstanding_principal':
          return (principalOut * chargeType.defaultRate / 100).round();

        case 'manual_amount':
        default:
          return 0; // Staff must enter amount manually
      }
    } catch (e) {
      print('❌ Error calculating suggested amount: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHARGE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Add a charge to a loan
  /// Validates inputs and writes charge + ledger entry + loan totals in ONE transaction
  static Future<Map<String, dynamic>> addCharge({
    required String loanId,
    required String chargeTypeId,
    required String chargeTypeName,
    String? scheduleItemId,
    int? instalmentNumber,
    required int amount,
    required DateTime chargeDate,
    required String notes,
  }) async {
    if (amount <= 0) {
      return {'success': false, 'message': 'Charge amount must be greater than zero'};
    }

    if (notes.trim().isEmpty) {
      return {'success': false, 'message': 'Notes are required'};
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final profile = FirebaseService.sessionProfile;
      final userName = profile?['name'] as String? ?? 'Unknown';
      final tenantId = FirebaseService.sessionTenantId;

      // Load loan to validate and check for duplicates
      final loanRef = _db.collection(AppConstants.loansCol).doc(loanId);
      final loanSnap = await loanRef.get();

      if (!loanSnap.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanSnap.data()!;
      final status = (loanData['status'] ?? '').toString().toLowerCase();

      // Block adding charges to closed or written-off loans
      if (status == 'closed' || status == 'paid' || status == 'written off') {
        return {
          'success': false,
          'message': 'Cannot add charges to $status loans'
        };
      }

      // Check for duplicate charge on same instalment same day
      if (scheduleItemId != null) {
        final existingCharges = await _db
            .collection(AppConstants.loansCol)
            .doc(loanId)
            .collection('charges')
            .where('chargeTypeId', isEqualTo: chargeTypeId)
            .where('scheduleItemId', isEqualTo: scheduleItemId)
            .where('chargeDate',
                isEqualTo: Timestamp.fromDate(
                    DateTime(chargeDate.year, chargeDate.month, chargeDate.day)))
            .get();

        if (existingCharges.docs.isNotEmpty) {
          // Warn but don't block (return special flag for UI confirmation)
          return {
            'success': false,
            'warning': true,
            'message':
                'A ${chargeTypeName} charge was already added to this instalment today. Add another?'
          };
        }
      }

      final memberId = loanData['memberId'] ?? loanData['farmerId'];
      final now = DateTime.now();
      final chargeId = _uuid.v4();

      // Prepare charge document
      final chargeData = {
        'loanId': loanId,
        'memberId': memberId,
        'tenantId': tenantId,
        'chargeTypeId': chargeTypeId,
        'chargeTypeName': chargeTypeName,
        if (scheduleItemId != null) 'scheduleItemId': scheduleItemId,
        if (instalmentNumber != null) 'instalmentNumber': instalmentNumber,
        'amount': amount,
        'amountPaid': 0,
        'amountWaived': 0,
        'status': 'pending',
        'chargeDate': Timestamp.fromDate(chargeDate),
        'notes': notes,
        'appliedBy': uid,
        'appliedByName': userName,
        'createdAt': Timestamp.fromDate(now),
      };

      // Prepare ledger entry
      final ledgerId = _uuid.v4();
      final ledgerData = {
        'id': ledgerId,
        'tenantId': tenantId,
        'memberId': memberId,
        'loanId': loanId,
        'type': 'charge_posted',
        'description': 'Charge: $chargeTypeName',
        'charges': amount,
        'principal': 0,
        'interest': 0,
        'date': Timestamp.fromDate(chargeDate),
        'recordedBy': uid,
        'recordedByName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'chargeId': chargeId,
          'chargeTypeId': chargeTypeId,
          'chargeTypeName': chargeTypeName,
          if (instalmentNumber != null) 'instalmentNumber': instalmentNumber,
          'notes': notes,
        },
      };

      // Calculate new loan totals
      final currentCharges = LoanMath.d(loanData['charges']);
      final currentChargesPaid = LoanMath.d(loanData['chargesPaid']);
      final currentChargesWaived = LoanMath.d(loanData['chargesWaived']);
      
      final newChargesExpected = (currentCharges + amount).toInt();
      final newChargesOut = (newChargesExpected - currentChargesPaid - currentChargesWaived).toInt();
      
      final principal = LoanMath.d(loanData['loanAmount']);
      final interest = LoanMath.d(loanData['interestAmount']);
      final waived = LoanMath.d(loanData['interestWaived']);
      final newTotalPayable = (principal + interest + newChargesExpected - waived).toInt();
      
      final totalPaid = LoanMath.d(loanData['totalRepaid']);
      final newOutstandingBalance = (newTotalPayable - totalPaid).toInt();

      // Execute as transaction
      await _db.runTransaction((transaction) async {
        // 1. Create charge
        transaction.set(
          _db
              .collection(AppConstants.loansCol)
              .doc(loanId)
              .collection('charges')
              .doc(chargeId),
          chargeData,
        );

        // 2. Create ledger entry
        transaction.set(
          _db.collection(AppConstants.ledgerCol).doc(ledgerId),
          ledgerData,
        );

        // 3. Update loan totals
        transaction.update(loanRef, {
          'charges': newChargesExpected,
          'chargesExpected': newChargesExpected,
          'chargesOutstanding': newChargesOut,
          'totalPayable': newTotalPayable,
          'outstandingBalance': newOutstandingBalance,
          'remainingBalance': newOutstandingBalance,
          'totalOutstanding': newOutstandingBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Audit log
      await AuditService.log(
        action: 'CHARGE_ADDED',
        details:
            'Added charge: $chargeTypeName (UGX ${_formatMoney(amount)}) to loan $loanId',
        userId: uid,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'chargeId': chargeId,
          'chargeTypeId': chargeTypeId,
          'amount': amount,
          if (instalmentNumber != null) 'instalmentNumber': instalmentNumber,
        },
      );

      // Send SMS notification to borrower
      try {
        // Get member phone number
        final memberDoc = await _db.collection(AppConstants.usersCol).doc(memberId).get();
        final memberPhone = memberDoc.data()?['phone'] as String? ?? '';
        
        if (memberPhone.isNotEmpty) {
          final saccoName = 'MBADIFA SACCO'; // Could get from SaccoService
          final formattedAmount = _formatMoney(amount);
          final newTotalDemanded = _formatMoney(newOutstandingBalance);
          
          // Build SMS message
          final smsMessage = '$saccoName: Charge added to your loan.\n'
              'Charge: $chargeTypeName\n'
              'Amount: UGX $formattedAmount\n'
              '${notes.isNotEmpty ? 'Reason: $notes\n' : ''}'
              'New total due: UGX $newTotalDemanded';
          
          // Send SMS notification - await to ensure it's attempted
          try {
            await FirebaseService.sendSmsToPhone(memberPhone, smsMessage);
          } catch (e) {
            // SMS failed but don't block charge operation
          }
        }
      } catch (e) {
        // SMS send failed - don't block charge operation
      }

      return {
        'success': true,
        'chargeId': chargeId,
        'message': 'Charge added successfully'
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get all charges for a loan
  static Future<List<LoanCharge>> getChargesForLoan(String loanId) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .orderBy('chargeDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => LoanCharge.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get charge totals for a loan
  static Future<Map<String, int>> getChargeTotals(String loanId) async {
    try {
      final charges = await getChargesForLoan(loanId);
      
      int expected = 0;
      int paid = 0;
      int waived = 0;

      for (final charge in charges) {
        if (charge.status != 'reversed') {
          expected += charge.amount;
          paid += charge.amountPaid;
          waived += charge.amountWaived;
        }
      }

      return {
        'expected': expected,
        'paid': paid,
        'waived': waived,
        'outstanding': expected - paid - waived,
      };
    } catch (e) {
      print('❌ Error calculating charge totals: $e');
      return {'expected': 0, 'paid': 0, 'waived': 0, 'outstanding': 0};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENT ALLOCATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Allocate a payment to charges first, then interest, then principal
  /// Called from repayment service
  static Future<Map<String, int>> allocatePayment({
    required String loanId,
    required int paymentAmount,
    required WriteBatch batch,
  }) async {
    try {
      // Get all unpaid charges
      final chargesSnap = await _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .where('status', whereIn: ['pending', 'partial'])
          .orderBy('chargeDate')
          .get();

      int remaining = paymentAmount;
      int allocatedToCharges = 0;

      for (final doc in chargesSnap.docs) {
        if (remaining <= 0) break;

        final charge = LoanCharge.fromFirestore(doc);
        final outstanding = charge.amountOutstanding;

        if (outstanding > 0) {
          final payment = remaining >= outstanding ? outstanding : remaining;
          final newPaid = charge.amountPaid + payment;
          final newStatus = newPaid >= charge.amount
              ? 'paid'
              : 'partial';

          batch.update(doc.reference, {
            'amountPaid': newPaid,
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          allocatedToCharges += payment;
          remaining -= payment;
        }
      }

      return {
        'charges': allocatedToCharges,
        'remaining': remaining,
      };
    } catch (e) {
      print('❌ Error allocating payment to charges: $e');
      return {'charges': 0, 'remaining': paymentAmount};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WAIVER OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Request a charge waiver
  static Future<Map<String, dynamic>> requestWaiver({
    required String chargeId,
    required String loanId,
    required int amount,
    required String reason,
  }) async {
    if (amount <= 0) {
      return {'success': false, 'message': 'Waiver amount must be greater than zero'};
    }

    if (reason.trim().isEmpty) {
      return {'success': false, 'message': 'Reason is required'};
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final profile = FirebaseService.sessionProfile;
      final userName = profile?['name'] as String? ?? 'Unknown';
      final tenantId = FirebaseService.sessionTenantId;

      // Load charge
      final chargeRef = _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId);
      final chargeSnap = await chargeRef.get();

      if (!chargeSnap.exists) {
        return {'success': false, 'message': 'Charge not found'};
      }

      final charge = LoanCharge.fromFirestore(chargeSnap);

      if (amount > charge.amountOutstanding) {
        return {
          'success': false,
          'message': 'Waiver amount exceeds outstanding charge amount'
        };
      }

      // Create waiver request
      final waiverId = _uuid.v4();
      final now = DateTime.now();

      await _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId)
          .collection('waivers')
          .doc(waiverId)
          .set({
        'chargeId': chargeId,
        'loanId': loanId,
        'memberId': charge.memberId,
        'tenantId': tenantId,
        'amount': amount,
        'reason': reason,
        'requestedBy': uid,
        'requestedByName': userName,
        'requestedAt': Timestamp.fromDate(now),
        'status': 'pending',
      });

      await AuditService.log(
        action: 'CHARGE_WAIVER_REQUESTED',
        details:
            'Requested waiver of UGX ${_formatMoney(amount)} for charge ${charge.chargeTypeName}',
        userId: uid,
        affectedUserId: charge.memberId,
        metadata: {
          'loanId': loanId,
          'chargeId': chargeId,
          'waiverId': waiverId,
          'amount': amount,
        },
      );

      return {
        'success': true,
        'waiverId': waiverId,
        'message': 'Waiver request submitted for approval'
      };
    } catch (e) {
      print('❌ Error requesting waiver: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Approve a charge waiver
  /// Must be a different user than the requester
  static Future<Map<String, dynamic>> approveWaiver({
    required String waiverId,
    required String chargeId,
    required String loanId,
    String? notes,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final profile = FirebaseService.sessionProfile;
      final userName = profile?['name'] as String? ?? 'Unknown';

      // Load waiver
      final waiverRef = _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId)
          .collection('waivers')
          .doc(waiverId);
      final waiverSnap = await waiverRef.get();

      if (!waiverSnap.exists) {
        return {'success': false, 'message': 'Waiver request not found'};
      }

      final waiverData = waiverSnap.data()!;
      final requestedBy = waiverData['requestedBy'] as String;

      // Prevent self-approval
      if (requestedBy == uid) {
        return {
          'success': false,
          'message': 'You cannot approve your own waiver request'
        };
      }

      final amount = (waiverData['amount'] as num).toInt();
      final memberId = waiverData['memberId'] as String;
      final tenantId = waiverData['tenantId'] as String;

      // Load charge and loan
      final chargeRef = _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId);
      final chargeSnap = await chargeRef.get();

      if (!chargeSnap.exists) {
        return {'success': false, 'message': 'Charge not found'};
      }

      final charge = LoanCharge.fromFirestore(chargeSnap);
      final loanRef = _db.collection(AppConstants.loansCol).doc(loanId);
      final loanSnap = await loanRef.get();

      if (!loanSnap.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanSnap.data()!;
      final now = DateTime.now();

      // Create ledger entry for waiver
      final ledgerId = _uuid.v4();
      final ledgerData = {
        'id': ledgerId,
        'tenantId': tenantId,
        'memberId': memberId,
        'loanId': loanId,
        'type': 'charge_waived',
        'description': 'Charge waived: ${charge.chargeTypeName}',
        'charges': -amount, // Negative for reduction
        'principal': 0,
        'interest': 0,
        'date': Timestamp.fromDate(now),
        'recordedBy': uid,
        'recordedByName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'chargeId': chargeId,
          'waiverId': waiverId,
          'waiverAmount': amount,
          'reason': waiverData['reason'],
        },
      };

      // Calculate new totals
      final newAmountWaived = charge.amountWaived + amount;
      final newOutstanding = charge.amount - charge.amountPaid - newAmountWaived;
      final newStatus = newOutstanding <= 0 ? 'waived' : charge.status;

      final currentChargesWaived = LoanMath.d(loanData['chargesWaived']);
      final newTotalChargesWaived = (currentChargesWaived + amount).toInt();
      
      final currentChargesOut = LoanMath.d(loanData['chargesOutstanding']);
      final newChargesOut = (currentChargesOut - amount).toInt();

      final currentTotalOut = LoanMath.d(loanData['totalOutstanding']);
      final newTotalOut = (currentTotalOut - amount).toInt();

      // Execute as transaction
      await _db.runTransaction((transaction) async {
        // 1. Update waiver status
        transaction.update(waiverRef, {
          'status': 'approved',
          'reviewedBy': uid,
          'reviewedByName': userName,
          'reviewedAt': Timestamp.fromDate(now),
          if (notes != null) 'reviewerNotes': notes,
        });

        // 2. Update charge
        transaction.update(chargeRef, {
          'amountWaived': newAmountWaived,
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Create ledger entry
        transaction.set(
          _db.collection(AppConstants.ledgerCol).doc(ledgerId),
          ledgerData,
        );

        // 4. Update loan totals
        transaction.update(loanRef, {
          'chargesWaived': newTotalChargesWaived,
          'chargesOutstanding': newChargesOut,
          'totalOutstanding': newTotalOut,
          'outstandingBalance': newTotalOut,
          'remainingBalance': newTotalOut,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await AuditService.log(
        action: 'CHARGE_WAIVER_APPROVED',
        details:
            'Approved waiver of UGX ${_formatMoney(amount)} for charge ${charge.chargeTypeName}',
        userId: uid,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'chargeId': chargeId,
          'waiverId': waiverId,
          'amount': amount,
        },
      );

      return {'success': true, 'message': 'Waiver approved successfully'};
    } catch (e) {
      print('❌ Error approving waiver: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Reject a charge waiver
  static Future<Map<String, dynamic>> rejectWaiver({
    required String waiverId,
    required String chargeId,
    required String loanId,
    required String reason,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final profile = FirebaseService.sessionProfile;
      final userName = profile?['name'] as String? ?? 'Unknown';
      final now = DateTime.now();

      await _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId)
          .collection('waivers')
          .doc(waiverId)
          .update({
        'status': 'rejected',
        'reviewedBy': uid,
        'reviewedByName': userName,
        'reviewedAt': Timestamp.fromDate(now),
        'reviewerNotes': reason,
      });

      await AuditService.log(
        action: 'CHARGE_WAIVER_REJECTED',
        details: 'Rejected charge waiver. Reason: $reason',
        userId: uid,
        metadata: {
          'loanId': loanId,
          'chargeId': chargeId,
          'waiverId': waiverId,
        },
      );

      return {'success': true, 'message': 'Waiver rejected'};
    } catch (e) {
      print('❌ Error rejecting waiver: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVERSAL
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE CHARGE (for unpaid charges only)
  // ══════════════════════════════════════════════════════════════════════════

  /// Delete an unpaid charge completely (no history kept)
  /// Only works for charges with amountPaid == 0
  static Future<Map<String, dynamic>> deleteCharge({
    required String chargeId,
    required String loanId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return {'success': false, 'message': 'Deletion reason is required'};
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final profile = FirebaseService.sessionProfile;
      final userName = profile?['name'] as String? ?? 'Unknown';

      // Load charge and loan
      final chargeRef = _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId);
      final chargeSnap = await chargeRef.get();

      if (!chargeSnap.exists) {
        return {'success': false, 'message': 'Charge not found'};
      }

      final charge = LoanCharge.fromFirestore(chargeSnap);

      if (charge.status == 'reversed') {
        return {'success': false, 'message': 'Cannot delete a reversed charge'};
      }

      if (charge.amountPaid > 0) {
        return {
          'success': false,
          'message':
              'Cannot delete a charge with payments. Use Reverse instead.'
        };
      }

      final loanRef = _db.collection(AppConstants.loansCol).doc(loanId);
      final loanSnap = await loanRef.get();

      if (!loanSnap.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanSnap.data()!;
      final tenantId = charge.tenantId;
      final memberId = charge.memberId;

      // Calculate new loan totals (remove this charge from totals)
      final currentCharges = LoanMath.d(loanData['charges']);
      final currentChargesWaived = LoanMath.d(loanData['chargesWaived']);
      
      final newChargesExpected = (currentCharges - charge.amount + charge.amountWaived).toInt();
      final newChargesWaived = (currentChargesWaived - charge.amountWaived).toInt();
      
      final currentChargesOut = LoanMath.d(loanData['chargesOutstanding']);
      final newChargesOut = (currentChargesOut - charge.amountOutstanding).toInt();

      final currentTotalOut = LoanMath.d(loanData['totalOutstanding']);
      final newTotalOut = (currentTotalOut - charge.amountOutstanding).toInt();

      // Execute as transaction
      await _db.runTransaction((transaction) async {
        // 1. Delete charge document
        transaction.delete(chargeRef);

        // 2. Update loan totals
        transaction.update(loanRef, {
          'charges': newChargesExpected,
          'chargesExpected': newChargesExpected,
          'chargesWaived': newChargesWaived,
          'chargesOutstanding': newChargesOut,
          'totalOutstanding': newTotalOut,
          'outstandingBalance': newTotalOut,
          'remainingBalance': newTotalOut,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await AuditService.log(
        action: 'CHARGE_DELETED',
        details:
            'Deleted charge: ${charge.chargeTypeName} (UGX ${_formatMoney(charge.amount)}). Reason: $reason',
        userId: uid,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'chargeId': chargeId,
          'amount': charge.amount,
          'reason': reason,
        },
      );

      return {'success': true, 'message': 'Charge deleted successfully'};
    } catch (e) {
      print('❌ Error deleting charge: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVERSE CHARGE (for paid charges - keeps history)
  // ══════════════════════════════════════════════════════════════════════════

  /// Reverse a charge (adds reversing ledger entries, never deletes history)
  static Future<Map<String, dynamic>> reverseCharge({
    required String chargeId,
    required String loanId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return {'success': false, 'message': 'Reversal reason is required'};
    }

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final profile = FirebaseService.sessionProfile;
      final userName = profile?['name'] as String? ?? 'Unknown';

      // Load charge and loan
      final chargeRef = _db
          .collection(AppConstants.loansCol)
          .doc(loanId)
          .collection('charges')
          .doc(chargeId);
      final chargeSnap = await chargeRef.get();

      if (!chargeSnap.exists) {
        return {'success': false, 'message': 'Charge not found'};
      }

      final charge = LoanCharge.fromFirestore(chargeSnap);

      if (charge.status == 'reversed') {
        return {'success': false, 'message': 'Charge is already reversed'};
      }

      if (charge.amountPaid > 0) {
        return {
          'success': false,
          'message':
              'Cannot reverse a charge that has payments. Please reverse the payments first.'
        };
      }

      final loanRef = _db.collection(AppConstants.loansCol).doc(loanId);
      final loanSnap = await loanRef.get();

      if (!loanSnap.exists) {
        return {'success': false, 'message': 'Loan not found'};
      }

      final loanData = loanSnap.data()!;
      final tenantId = charge.tenantId;
      final memberId = charge.memberId;
      final now = DateTime.now();

      // Create reversing ledger entry
      final ledgerId = _uuid.v4();
      final ledgerData = {
        'id': ledgerId,
        'tenantId': tenantId,
        'memberId': memberId,
        'loanId': loanId,
        'type': 'charge_reversed',
        'description': 'Charge reversed: ${charge.chargeTypeName}',
        'charges': -charge.amount, // Negative to reverse
        'principal': 0,
        'interest': 0,
        'date': Timestamp.fromDate(now),
        'recordedBy': uid,
        'recordedByName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'chargeId': chargeId,
          'originalAmount': charge.amount,
          'reversalReason': reason,
        },
      };

      // Calculate new loan totals (remove this charge from totals)
      final currentCharges = LoanMath.d(loanData['charges']);
      final currentChargesWaived = LoanMath.d(loanData['chargesWaived']);
      
      final newChargesExpected = (currentCharges - charge.amount + charge.amountWaived).toInt();
      final newChargesWaived = (currentChargesWaived - charge.amountWaived).toInt();
      
      final currentChargesOut = LoanMath.d(loanData['chargesOutstanding']);
      final newChargesOut = (currentChargesOut - charge.amountOutstanding).toInt();

      final currentTotalOut = LoanMath.d(loanData['totalOutstanding']);
      final newTotalOut = (currentTotalOut - charge.amountOutstanding).toInt();

      // Execute as transaction
      await _db.runTransaction((transaction) async {
        // 1. Mark charge as reversed
        transaction.update(chargeRef, {
          'status': 'reversed',
          'reversedBy': uid,
          'reversedAt': Timestamp.fromDate(now),
          'reversalReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Create reversing ledger entry
        transaction.set(
          _db.collection(AppConstants.ledgerCol).doc(ledgerId),
          ledgerData,
        );

        // 3. Update loan totals
        transaction.update(loanRef, {
          'charges': newChargesExpected,
          'chargesExpected': newChargesExpected,
          'chargesWaived': newChargesWaived,
          'chargesOutstanding': newChargesOut,
          'totalOutstanding': newTotalOut,
          'outstandingBalance': newTotalOut,
          'remainingBalance': newTotalOut,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await AuditService.log(
        action: 'CHARGE_REVERSED',
        details:
            'Reversed charge: ${charge.chargeTypeName} (UGX ${_formatMoney(charge.amount)}). Reason: $reason',
        userId: uid,
        affectedUserId: memberId,
        metadata: {
          'loanId': loanId,
          'chargeId': chargeId,
          'amount': charge.amount,
          'reason': reason,
        },
      );

      return {'success': true, 'message': 'Charge reversed successfully'};
    } catch (e) {
      print('❌ Error reversing charge: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}

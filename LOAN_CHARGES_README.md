# Loan Charges Feature - Implementation Guide

## Overview

This feature adds **manual loan charges** to the MBADIFA SACCO admin app. Charges are **NEVER applied automatically** - they exist only when staff explicitly add them.

## Key Principles

✅ **Manual only** - No scheduled jobs, no Cloud Functions, no auto-accrual  
✅ **Fully audited** - Every action logged with who/when/what/before/after  
✅ **Transactional** - Charge + ledger + loan totals updated atomically  
✅ **Reversible** - Reversals add reversing entries, never delete history  
✅ **Permission-gated** - Role-based access control for all operations  

## Data Model

### Firestore Collections

```
charge_types/{id}
├─ tenantId: string
├─ name: string (e.g., "Late Payment Fee")
├─ code: string (e.g., "late_payment")
├─ calcBasis: string ("flat" | "pct_overdue_instalment" | "pct_arrears" | "pct_outstanding_principal" | "manual_amount")
├─ defaultAmount: int (UGX)
├─ defaultRate: double (percentage)
├─ isActive: boolean
├─ description: string
└─ createdAt: timestamp

loans/{loanId}/charges/{chargeId}
├─ loanId: string
├─ memberId: string
├─ tenantId: string
├─ chargeTypeId: string
├─ chargeTypeName: string
├─ scheduleItemId: string? (optional link to specific instalment)
├─ instalmentNumber: int? (optional)
├─ amount: int (UGX)
├─ amountPaid: int
├─ amountWaived: int
├─ status: string ("pending" | "partial" | "paid" | "waived" | "reversed")
├─ chargeDate: timestamp
├─ notes: string (required)
├─ appliedBy: string (uid)
├─ appliedByName: string
├─ createdAt: timestamp
├─ reversedBy: string?
├─ reversedAt: timestamp?
└─ reversalReason: string?

loans/{loanId}/charges/{chargeId}/waivers/{waiverId}
├─ chargeId: string
├─ loanId: string
├─ memberId: string
├─ tenantId: string
├─ amount: int
├─ reason: string
├─ requestedBy: string (uid)
├─ requestedByName: string
├─ requestedAt: timestamp
├─ status: string ("pending" | "approved" | "rejected")
├─ reviewedBy: string?
├─ reviewedByName: string?
├─ reviewedAt: timestamp?
└─ reviewerNotes: string?
```

### Loan Document Updates

Denormalized totals on loan doc (updated in same transaction):
- `charges`: total expected charge amount
- `chargesExpected`: same as charges
- `chargesPaid`: sum of all amountPaid
- `chargesWaived`: sum of all amountWaived
- `chargesOutstanding`: charges - paid - waived
- `totalPayable`: principal + interest + charges - interest waived
- `outstandingBalance`: totalPayable - totalRepaid

### Ledger Entries

Every charge operation creates a ledger entry in `saccoplus-ledger`:

**Charge posted:**
```dart
{
  'type': 'charge_posted',
  'description': 'Charge: Late Payment Fee',
  'charges': 50000,
  'principal': 0,
  'interest': 0,
  'metadata': {...}
}
```

**Charge waived:**
```dart
{
  'type': 'charge_waived',
  'description': 'Charge waived: Late Payment Fee',
  'charges': -50000,  // Negative for reduction
  'principal': 0,
  'interest': 0,
  'metadata': {'waiverId': '...', 'reason': '...'}
}
```

**Charge reversed:**
```dart
{
  'type': 'charge_reversed',
  'description': 'Charge reversed: Late Payment Fee',
  'charges': -50000,  // Negative to reverse
  'principal': 0,
  'interest': 0,
  'metadata': {'reversalReason': '...'}
}
```

## Services

### ChargeService (`lib/services/charge_service.dart`)

**Charge Type Management:**
- `getChargeTypes()` - Fetch all charge types for tenant
- `seedDefaultChargeTypes(tenantId)` - Create default charge types
- `saveChargeType()` - Create/update charge type

**Charge Operations:**
- `suggestAmount(loan, chargeType, scheduleItem)` - Calculate suggested amount (read-only)
- `addCharge()` - Add charge + ledger + update loan totals (transaction)
- `getChargesForLoan(loanId)` - Fetch all charges
- `getChargeTotals(loanId)` - Calculate charge totals
- `allocatePayment()` - Allocate repayment to charges first (called from repayment service)

**Waiver Operations:**
- `requestWaiver()` - Request charge waiver (requires approval)
- `approveWaiver()` - Approve waiver (must be different user than requester)
- `rejectWaiver()` - Reject waiver request

**Reversal:**
- `reverseCharge()` - Reverse charge (adds reversing entries, never deletes)

## UI Components

### Loan Details Screen - Charges Tab

File: `lib/widgets/loan_charges_tab.dart`

Features:
- Table view (desktop) / Card view (mobile)
- Add charge button (permission-gated)
- Per-charge actions: Waive, Reverse
- Totals row showing Expected/Paid/Waived/Outstanding
- Empty state with explanation

### Add Charge Dialog

File: `lib/widgets/add_loan_charge_dialog.dart`

Features:
- Charge type dropdown (from active charge types)
- Optional instalment selector
- Amount field with suggested amount hint (editable)
- Charge date picker
- Notes field (required)
- Duplicate detection with confirmation
- Preview before final submission

### Waive Charge Dialog

File: `lib/widgets/waive_charge_dialog.dart`

Features:
- Charge details summary
- Amount to waive (max = outstanding)
- Reason field (required)
- Submits for approval (different user must approve)

## Integration Points

### 1. Update Loan Details Screen

Add charges tab to the tab controller:

```dart
// In loan_details_screen.dart, update tab controller length:
_tabController = TabController(length: 8, vsync: this);  // Was 7, now 8

// Add to TabBar:
const Tab(text: 'Charges'),

// Add to TabBarView:
LoanChargesTab(
  loanId: widget.loanId,
  loanData: _loanData!,
  onChargeChanged: _loadLoanData,
),
```

### 2. Update Balance Breakdown Card

The "Charges" row should show real data from `_snap`:

```dart
_infoRow('Charges', _chargesOut.round(), /* ... */),
```

### 3. Update Repayment Service

When recording a repayment, allocate to charges first:

```dart
// In repayment recording logic:
final batch = db.batch();

// 1. Allocate to charges first
final chargeAllocation = await ChargeService.allocatePayment(
  loanId: loanId,
  paymentAmount: totalAmount,
  batch: batch,
);

int remaining = chargeAllocation['remaining']!;
int toCharges = chargeAllocation['charges']!;

// 2. Then allocate remaining to interest/principal as before
// ...

// 3. Update repayment doc with breakdown
batch.set(repaymentRef, {
  'chargesAmount': toCharges,
  'interestAmount': toInterest,
  'principalAmount': toPrincipal,
  // ...
});

await batch.commit();
```

### 4. Seed Default Charge Types

Run once per tenant (e.g., on first login or in admin settings):

```dart
await ChargeService.seedDefaultChargeTypes(tenantId);
```

### 5. Add "Add charge" to More Actions Menu

In `loan_details_screen.dart`:

```dart
List<_Act> get _moreActions => !_isActive
    ? const []
    : [
        _Act('Add charge', Icons.add_card_outlined, _showAddChargeDialog),
        _Act('Loan top-up', Icons.add_circle_outline, _showTopUpDialog),
        // ... rest
      ];

void _showAddChargeDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AddLoanChargeDialog(
      loanId: widget.loanId,
      loanData: _loanData!,
      onSuccess: _loadLoanData,
    ),
  );
}
```

## Firestore Security Rules

Add to `firestore.rules`:

```javascript
// Charge types (SACCO-wide)
match /charge_types/{typeId} {
  allow read: if request.auth != null && 
                 get(/databases/$(database)/documents/saccoplus-members/$(request.auth.uid)).data.tenantId == resource.data.tenantId;
  allow write: if request.auth != null && 
                  hasPermission('chargeType.manage');
}

// Charges (subcollection of loans)
match /saccoplus-loans/{loanId}/charges/{chargeId} {
  allow read: if request.auth != null && 
                 get(/databases/$(database)/documents/saccoplus-loans/$(loanId)).data.tenantId == 
                 get(/databases/$(database)/documents/saccoplus-members/$(request.auth.uid)).data.tenantId;
  
  allow create: if request.auth != null && 
                   hasPermission('charge.add') &&
                   request.resource.data.appliedBy == request.auth.uid;
  
  allow update: if request.auth != null && 
                   (hasPermission('charge.reverse') || hasPermission('charge.waive'));
  
  allow delete: if false;  // Never delete, only reverse
  
  // Waivers (subcollection of charges)
  match /waivers/{waiverId} {
    allow read: if request.auth != null;
    
    allow create: if request.auth != null && 
                     hasPermission('charge.waive') &&
                     request.resource.data.requestedBy == request.auth.uid;
    
    allow update: if request.auth != null && 
                     hasPermission('charge.approveWaiver') &&
                     request.auth.uid != resource.data.requestedBy;  // No self-approval
  }
}

// Helper function (add to rules if not exists)
function hasPermission(perm) {
  let member = get(/databases/$(database)/documents/saccoplus-members/$(request.auth.uid)).data;
  let role = member.role;
  
  // Super admins have all permissions
  if (role == 'super_admin') return true;
  
  // Admin and manager permissions
  if (role in ['admin', 'manager']) {
    return perm in [
      'charge.add',
      'charge.waive',
      'charge.approveWaiver',
      'charge.reverse',
      'chargeType.manage'
    ];
  }
  
  // Loan officer permissions
  if (role == 'loan_officer') {
    return perm in ['charge.add', 'charge.waive'];
  }
  
  // Teller permissions
  if (role == 'teller') {
    return perm == 'charge.add';
  }
  
  return false;
}
```

## Firestore Indexes

Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "charges",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "loanId", "order": "ASCENDING"},
        {"fieldPath": "chargeDate", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "charges",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "loanId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "chargeDate", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "charges",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "chargeTypeId", "order": "ASCENDING"},
        {"fieldPath": "scheduleItemId", "order": "ASCENDING"},
        {"fieldPath": "chargeDate", "order": "ASCENDING"}
      ]
    },
    {
      "collectionGroup": "waivers",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "requestedAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "charge_types",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "tenantId", "order": "ASCENDING"},
        {"fieldPath": "isActive", "order": "ASCENDING"},
        {"fieldPath": "name", "order": "ASCENDING"}
      ]
    }
  ]
}
```

## Testing Guide

### Test 1: Add a Late Payment Charge

1. Navigate to loan account #922030001941 (the example overdue loan)
2. Click "Charges" tab
3. Click "Add charge"
4. Select "Late Payment Fee"
5. Observe suggested amount (e.g., 2% of overdue instalment)
6. Edit amount if needed
7. Select related instalment (optional)
8. Select charge date
9. Enter notes: "Payment overdue by 30 days"
10. Click "Add charge"
11. **Verify:** Charge appears in table with status "pending"
12. **Verify:** Loan totals updated (chargesOutstanding increased)
13. **Verify:** Ledger entry created (type: charge_posted)
14. **Verify:** Audit log entry created

### Test 2: Record Payment (Charges Allocated First)

1. On same loan, click "Record payment"
2. Enter amount = instalment amount
3. Record payment
4. **Verify:** Payment allocated to charges first
5. **Verify:** Charge status changed from "pending" to "paid" or "partial"
6. **Verify:** Remaining payment allocated to interest/principal
7. **Verify:** Loan totals updated correctly

### Test 3: Waive a Charge

1. On Charges tab, click "..." menu on a charge
2. Select "Waive charge"
3. Enter amount to waive (default = full outstanding)
4. Enter reason: "Financial hardship"
5. Click "Request waiver"
6. **Verify:** Waiver request created with status "pending"
7. Log in as different admin/manager user
8. Open same loan, Charges tab
9. Approve the waiver
10. **Verify:** Charge status changed to "waived"
11. **Verify:** Loan totals updated (chargesWaived increased, chargesOutstanding decreased)
12. **Verify:** Ledger entry created (type: charge_waived, negative amount)

### Test 4: Reverse a Charge

1. On Charges tab, click "..." menu on an unpaid charge
2. Select "Reverse"
3. Enter reason: "Added in error"
4. Click "Reverse"
5. **Verify:** Charge status changed to "reversed"
6. **Verify:** Loan totals updated (charge removed from totals)
7. **Verify:** Reversing ledger entry created (negative amount)
8. **Verify:** Cannot reverse a charge that has payments

### Test 5: Duplicate Detection

1. Add a late payment charge to instalment #3 today
2. Try to add another late payment charge to instalment #3 today
3. **Verify:** Warning shown: "A charge was already added to this instalment today"
4. Click "Add anyway" to confirm
5. **Verify:** Second charge added successfully

### Test 6: Edge Cases

**Closed loan:**
- Try to add charge to a closed/paid loan
- **Verify:** Blocked with message "Cannot add charges to paid loans"

**Self-approval:**
- Request a waiver
- Try to approve your own waiver with same user
- **Verify:** Blocked with message "You cannot approve your own waiver request"

**Invalid amount:**
- Try to waive more than outstanding amount
- **Verify:** Blocked with validation error

**Missing notes:**
- Try to add charge without notes
- **Verify:** Blocked with "Notes are required"

## Permissions

**charge.add** - Add charges to loans (admin, manager, loan_officer, teller)  
**charge.waive** - Request charge waiver (admin, manager, loan_officer)  
**charge.approveWaiver** - Approve waivers (admin, manager only)  
**charge.reverse** - Reverse charges (admin, manager only)  
**chargeType.manage** - Create/edit charge types (admin, manager only)  

## Migration Notes

For existing loans with imported charges:
1. Run a one-time script to create charge records from legacy data
2. Set `appliedBy` to "system" or migration user
3. Mark as `status: "paid"` if already settled
4. Create matching ledger entries

## Troubleshooting

**Charges not showing in tab:**
- Check Firestore rules allow read access
- Verify subcollection path: `loans/{loanId}/charges`

**Totals not updating:**
- Check that transaction completed successfully
- Verify loan doc has `charges`, `chargesPaid`, `chargesWaived` fields
- Run `LoanMath.recalculate(loanId)` to refresh

**Payment not allocating to charges:**
- Verify repayment service calls `ChargeService.allocatePayment()`
- Check charge status is "pending" or "partial"
- Ensure batch is committed after allocation

**Waiver approval not working:**
- Verify approver is different user than requester
- Check user has `charge.approveWaiver` permission
- Verify waiver status is "pending"

## Support

For issues or questions:
- Check audit logs for detailed action history
- Review Firestore console for data structure
- Check security rules for permission errors
- Review ledger entries for reconciliation

---

**Implementation complete!** ✅

All charges are manual, fully audited, transactional, and permission-gated.

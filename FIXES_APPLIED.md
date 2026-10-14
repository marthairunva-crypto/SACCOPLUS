# Fixes Applied - Oct 6, 2026

## 1. Fixed Text Cutoff Behind Sidebar (Loan Details Screen)
**Issue:** "Outstanding Balance" label and amount were being cut off/hidden behind the sidebar on narrow screens.

**Fix:** 
- Wrapped balance widget in `Flexible` widget to allow it to shrink properly
- Added `maxLines: 1` and `overflow: TextOverflow.ellipsis` to the label
- Wrapped amount in `FittedBox` to scale down if needed instead of overflowing

**File:** `lib/screens/admin/loan_details_screen.dart` (line ~1133)

## 2. Fixed Firestore Index URL Not Visible (Mobile Money Screen)
**Issue:** When Firestore index is required, the URL is only printed to console which is hard to see in production.

**Fix:**
- Enhanced error handling to extract the Firestore index URL from error message
- Display the URL in a selectable text box on the error screen
- Added "Copy URL" button to copy index URL to clipboard
- Show clear instructions: "Click the URL above, sign in to Firebase Console, and click 'Create Index'"
- Still print to console for development

**File:** `lib/screens/admin/payment_screens.dart` (line ~429)

## 3. Fixed Savings Edit/Delete Errors (Document Not Found)
**Issue:** Editing or deleting savings transactions threw errors like:
```
Error updating savings: [cloud_firestore/not-found] No document to update: 
projects/mwiza-projects/databases/(default)/documents/saccoplus-savings/phone__2567955595368
```

**Root Cause:** Code was trying to update savings summary documents that don't exist (using phone-based IDs or invalid member IDs).

**Fix:**
- Added document existence check before updating (`savingsDoc.get()`)
- If document exists, update it
- If document doesn't exist, create it with `set()` instead of throwing error
- Applied to both `_updateSavings()` and `_deleteSavings()` methods
- Only attempt updates if `memberId` is not empty

**Files:** 
- `lib/screens/admin/savings_admin_screen.dart` (`_updateSavings()` line ~191)
- `lib/screens/admin/savings_admin_screen.dart` (`_deleteSavings()` line ~292)

## 4. Loan Data Correction - Simplified to Total Outstanding
**Status:** In progress - Updated data loading and saving logic

**Changes:**
- Simplified from separate `principalOutstanding` and `interestOutstanding` to single `totalOutstanding` field
- Load: Combines existing principal + interest or uses stored `totalOutstanding`
- Save: Stores `totalOutstanding` as single value, distributes proportionally to maintain backward compatibility
- Table columns updated: removed Principal Paid, Interest Paid, Principal Outstanding, Interest Outstanding
- New columns: Total Outstanding, Arrears
- Card layout updated with info banner explaining teller will distribute during payment

**File:** `lib/screens/admin/loan_data_correction_screen.dart`

## Testing Notes
- Test loan details on narrow screens (< 640px width) - balance should not overflow
- Test Mobile Money screen when index is missing - should show copyable URL
- Test editing savings transactions - should work even if savings document doesn't exist
- Test deleting savings transactions - should not throw "document not found" errors
- Verify teller can still record payments with principal/interest distribution

## Known Issues to Address Next
- [ ] Add charges dropdown to loan payment dialog (Processing Fee, Late Payment, Insurance, Admin Fee, Others)
- [ ] Test totalOutstanding display in Member 360 and other screens
- [ ] Verify loan ledger calculations with new outstanding balance approach

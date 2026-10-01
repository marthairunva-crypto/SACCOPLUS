// Simple script to recalculate shares balances
// This needs to be run from Firebase Console or with proper setup

const tenantId = 'mbadifa';

console.log(`
SHARES BALANCE FIX INSTRUCTIONS
================================

Since you have a member with incorrect shares balance (100,000 UGX when they have no shares),
here's how to fix it:

OPTION 1: Fix Individual Member (Quick)
---------------------------------------
1. Go to Member 360 for the affected member
2. Check the "Shares" tab
3. If it shows no transactions but has a balance, the balance is wrong
4. You need to manually update the member document in Firestore:
   - Go to Firebase Console
   - Navigate to: saccoplus-members collection
   - Find the member document
   - Set sharesBalance to 0 (or correct value)

OPTION 2: Fix All Members (Recommended)
---------------------------------------
Run this Firestore query to recalculate all shares:

For each member in saccoplus-members where tenantId = '${tenantId}':
  1. Query saccoplus-shares where farmerId = memberID
  2. Sum all amounts
  3. Update member's sharesBalance to the sum

OPTION 3: Use the Migration Screen
----------------------------------
The shares migration screen already calculates balances correctly.
If you re-run the shares migration with the same CSV, it will:
- Skip duplicates
- Recalculate balances from transactions

Would you like me to create a Flutter screen to fix this instead?
`);

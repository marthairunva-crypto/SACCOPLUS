import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// One-time script to fix outstanding balance fields on existing loans
/// 
/// PROBLEM: Different services update different fields:
/// - Some use principalOutstanding + interestOutstanding
/// - Some use remainingBalance
/// - Dashboard reads principalOutstanding
/// - ArrearsService calculates remainingBalance
/// 
/// SOLUTION: Ensure all loans have consistent outstanding fields
class FixLoanOutstandingFields {
  static final _db = FirebaseFirestore.instance;

  /// Run the fix for all loans
  static Future<Map<String, int>> fixAllLoans() async {
    int fixed = 0;
    int skipped = 0;
    int errors = 0;

    try {
      print('🔧 Starting loan outstanding fields fix...');
      
      final loansSnapshot = await _db.collection(AppConstants.loansCol).get();
      
      print('📊 Found ${loansSnapshot.docs.length} loans to process');

      for (final doc in loansSnapshot.docs) {
        try {
          final data = doc.data();
          final loanId = doc.id;
          
          // Get current values
          final principalOut = _d(data['principalOutstanding']);
          final interestOut = _d(data['interestOutstanding']);
          final chargesOut = _d(data['chargesOutstanding']);
          
          final principalPaid = _d(data['principalPaid']);
          final interestPaid = _d(data['interestPaid']);
          final chargesPaid = _d(data['chargesPaid']);
          
          final loanAmount = _d(data['loanAmount'], _d(data['amount']));
          final interestAmount = _d(data['interestAmount'], _d(data['interest']));
          final totalAmount = _d(data['totalAmount']);
          
          // Calculate what outstanding should be
          final calculatedPrincipalOut = loanAmount - principalPaid;
          final calculatedInterestOut = interestAmount - interestPaid;
          final calculatedChargesOut = 0.0 - chargesPaid; // No charges in new loans
          
          final calculatedTotalOut = calculatedPrincipalOut + 
                                     calculatedInterestOut + 
                                     calculatedChargesOut;
          
          // Check if update needed
          final needsUpdate = 
            principalOut != calculatedPrincipalOut ||
            interestOut != calculatedInterestOut ||
            chargesOut != calculatedChargesOut ||
            !data.containsKey('remainingBalance') ||
            !data.containsKey('totalOutstanding') ||
            !data.containsKey('outstanding');
          
          if (!needsUpdate) {
            skipped++;
            continue;
          }
          
          // Update the loan
          final updateData = <String, dynamic>{
            'principalOutstanding': calculatedPrincipalOut,
            'interestOutstanding': calculatedInterestOut,
            'chargesOutstanding': calculatedChargesOut,
            'remainingBalance': calculatedTotalOut,
            'totalOutstanding': calculatedTotalOut,
            'outstanding': calculatedTotalOut,
          };
          
          // Ensure paid fields exist
          if (!data.containsKey('principalPaid')) {
            updateData['principalPaid'] = 0.0;
          }
          if (!data.containsKey('interestPaid')) {
            updateData['interestPaid'] = 0.0;
          }
          if (!data.containsKey('chargesPaid')) {
            updateData['chargesPaid'] = 0.0;
          }
          
          await _db.collection(AppConstants.loansCol).doc(loanId).update(updateData);
          
          fixed++;
          print('✅ Fixed loan $loanId: ${data['memberName']} - '
                'Outstanding: ${calculatedTotalOut.toStringAsFixed(0)}');
          
        } catch (e) {
          errors++;
          print('❌ Error fixing loan ${doc.id}: $e');
        }
      }
      
      print('');
      print('🎉 Loan outstanding fields fix complete!');
      print('   Fixed: $fixed');
      print('   Skipped: $skipped (already correct)');
      print('   Errors: $errors');
      
      return {
        'fixed': fixed,
        'skipped': skipped,
        'errors': errors,
        'total': loansSnapshot.docs.length,
      };
      
    } catch (e) {
      print('❌ Fatal error: $e');
      return {
        'fixed': fixed,
        'skipped': skipped,
        'errors': errors + 1,
        'total': 0,
      };
    }
  }
  
  /// Helper to safely parse numeric values
  static double _d(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

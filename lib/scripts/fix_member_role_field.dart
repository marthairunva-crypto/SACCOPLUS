import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';

/// One-time script to add missing 'role' field to members
/// 
/// PROBLEM: Some members don't have a 'role' field, so they don't show up
/// in the create loan member search (which filters by role = 'Member')
/// 
/// SOLUTION: Add role: 'Member' to all documents in saccoplus-members
/// collection that don't have a role field
class FixMemberRoleField {
  static final _db = FirebaseFirestore.instance;

  /// Run the fix for all members
  static Future<Map<String, int>> fixAllMembers() async {
    int fixed = 0;
    int skipped = 0;
    int errors = 0;

    try {
      print('🔧 Starting member role field fix...');
      
      final membersSnapshot = await _db.collection(AppConstants.usersCol).get();
      
      print('📊 Found ${membersSnapshot.docs.length} member documents to check');

      for (final doc in membersSnapshot.docs) {
        try {
          final data = doc.data();
          final memberId = doc.id;
          final name = data['name'] ?? data['fullName'] ?? 'Unknown';
          
          // Check if role field exists
          if (data.containsKey('role')) {
            final currentRole = data['role'];
            skipped++;
            print('⏭️  Skipped $name - already has role: $currentRole');
            continue;
          }
          
          // Add the role field
          await _db.collection(AppConstants.usersCol).doc(memberId).update({
            'role': AppConstants.roleMember, // 'Member' with capital M
          });
          
          fixed++;
          print('✅ Fixed $name - added role: ${AppConstants.roleMember}');
          
        } catch (e) {
          errors++;
          print('❌ Error fixing member ${doc.id}: $e');
        }
      }
      
      print('');
      print('🎉 Member role field fix complete!');
      print('   Fixed: $fixed');
      print('   Skipped: $skipped (already have role)');
      print('   Errors: $errors');
      
      return {
        'fixed': fixed,
        'skipped': skipped,
        'errors': errors,
        'total': membersSnapshot.docs.length,
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
}

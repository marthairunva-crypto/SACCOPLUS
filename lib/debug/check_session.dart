import '../core/firebase_service.dart';

/// Quick check to see what tenantId the current session is using
void checkCurrentSession() {
  print('\n' + '='*60);
  print('🔍 CURRENT SESSION INFO');
  print('='*60);
  print('Session UID: ${FirebaseService.sessionUid}');
  print('Session TenantId: ${FirebaseService.sessionTenantId}');
  print('Session Profile: ${FirebaseService.sessionProfile}');
  print('='*60 + '\n');
}

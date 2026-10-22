/// Diagnostic queries to help debug till and account balances
/// Run these in Firestore console or use this in debug mode

import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceDiagnostics {
  /// Shows all till sessions (open and closed) with their balances
  static Future<void> printAllTillSessions(String tenantId) async {
    print('\n🔍 ALL TILL SESSIONS FOR TENANT: $tenantId');
    print('=' * 80);
    
    final tillSessions = await FirebaseFirestore.instance
        .collection('saccoplus-till-sessions')
        .where('tenantId', isEqualTo: tenantId)
        .get();
    
    int totalOpen = 0;
    int totalClosed = 0;
    double totalOpenBalance = 0;
    double totalClosedBalance = 0;
    
    for (final doc in tillSessions.docs) {
      final data = doc.data();
      final status = data['status'] ?? 'unknown';
      final tellerName = data['tellerName'] ?? 'Unknown';
      final opening = (data['openingFloat'] ?? 0) as int;
      final totalIn = (data['totalIn'] ?? 0) as int;
      final totalOut = (data['totalOut'] ?? 0) as int;
      final expected = opening + totalIn - totalOut;
      
      print('$status | $tellerName | Opening: $opening | In: $totalIn | Out: $totalOut | Expected: $expected');
      
      if (status == 'open') {
        totalOpen++;
        totalOpenBalance += expected;
      } else {
        totalClosed++;
        totalClosedBalance += expected;
      }
    }
    
    print('-' * 80);
    print('SUMMARY:');
    print('  Open tills: $totalOpen with total balance: ${totalOpenBalance.toStringAsFixed(0)} UGX');
    print('  Closed tills: $totalClosed with total balance: ${totalClosedBalance.toStringAsFixed(0)} UGX');
    print('=' * 80);
  }
  
  /// Shows all accounts in the accounts collection
  static Future<void> printAllAccounts(String tenantId) async {
    print('\n🔍 ALL ACCOUNTS FOR TENANT: $tenantId');
    print('=' * 80);
    
    final accounts = await FirebaseFirestore.instance
        .collection('accounts')
        .where('tenantId', isEqualTo: tenantId)
        .get();
    
    double totalActive = 0;
    double totalInactive = 0;
    double totalCash = 0;
    double totalBank = 0;
    double totalTill = 0;
    
    for (final doc in accounts.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'Unknown';
      final type = data['type'] ?? 'unknown';
      final balance = (data['balance'] ?? 0).toDouble();
      final active = data['active'] ?? data['isActive'] ?? true;
      
      print('${active ? "✓" : "✗"} | $type | $name | Balance: ${balance.toStringAsFixed(0)} UGX');
      
      if (active) {
        totalActive += balance;
        if (type == 'bank') totalBank += balance;
        else if (type == 'till') totalTill += balance;
        else totalCash += balance;
      } else {
        totalInactive += balance;
      }
    }
    
    print('-' * 80);
    print('SUMMARY:');
    print('  Total active balance: ${totalActive.toStringAsFixed(0)} UGX');
    print('    - Till accounts: ${totalTill.toStringAsFixed(0)} UGX');
    print('    - Bank accounts: ${totalBank.toStringAsFixed(0)} UGX');
    print('    - Cash/Mobile Money: ${totalCash.toStringAsFixed(0)} UGX');
    print('  Total inactive balance: ${totalInactive.toStringAsFixed(0)} UGX');
    print('=' * 80);
  }
  
  /// Compare till sessions vs accounts to find discrepancies
  static Future<void> compareTillVsAccounts(String tenantId) async {
    print('\n🔍 COMPARING TILL SESSIONS VS ACCOUNTS');
    print('=' * 80);
    
    // Get open tills
    final openTills = await FirebaseFirestore.instance
        .collection('saccoplus-till-sessions')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: 'open')
        .get();
    
    // Get till accounts
    final tillAccounts = await FirebaseFirestore.instance
        .collection('accounts')
        .where('tenantId', isEqualTo: tenantId)
        .where('type', isEqualTo: 'till')
        .get();
    
    print('Open till sessions: ${openTills.docs.length}');
    print('Till accounts: ${tillAccounts.docs.length}');
    print('-' * 80);
    
    // Check each open till has a corresponding account
    for (final tillDoc in openTills.docs) {
      final data = tillDoc.data();
      final tellerId = data['tellerId'];
      final tellerName = data['tellerName'];
      final opening = (data['openingFloat'] ?? 0) as int;
      final totalIn = (data['totalIn'] ?? 0) as int;
      final totalOut = (data['totalOut'] ?? 0) as int;
      final expected = opening + totalIn - totalOut;
      
      final accountId = 'till_$tellerId';
      final matchingAccount = tillAccounts.docs
          .where((doc) => doc.id == accountId)
          .firstOrNull;
      
      if (matchingAccount != null) {
        final accountBalance = (matchingAccount.data()['balance'] ?? 0).toDouble();
        final matches = accountBalance == expected;
        print('${matches ? "✓" : "✗"} $tellerName: Till=$expected UGX | Account=$accountBalance UGX');
      } else {
        print('⚠️  $tellerName: Till=$expected UGX | NO MATCHING ACCOUNT');
      }
    }
    
    print('=' * 80);
  }
}

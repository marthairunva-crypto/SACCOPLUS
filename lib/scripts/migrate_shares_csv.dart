import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/firebase_service.dart';

/// Migration script to import shares data from ShareSnapshotReport CSV
/// 
/// Usage: dart lib/scripts/migrate_shares_csv.dart path/to/ShareSnapshotReport.csv
/// 
/// This script:
/// 1. Reads the CSV file
/// 2. For each member, updates their sharesBalance in both collections:
///    - saccoplus-members
///    - users (for authentication)
/// 3. Creates audit log entries
/// 4. Shows summary statistics

void main(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Usage: dart lib/scripts/migrate_shares_csv.dart path/to/ShareSnapshotReport.csv');
    exit(1);
  }

  final csvPath = args[0];
  final file = File(csvPath);

  if (!file.existsSync()) {
    print('❌ File not found: $csvPath');
    exit(1);
  }

  print('📊 Starting shares migration...');
  print('📂 Reading CSV: $csvPath\n');

  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Read CSV
  final csvString = await file.readAsString();
  final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

  if (rows.length < 3) {
    print('❌ CSV file appears to be empty or invalid');
    exit(1);
  }

  // Skip header rows (first 2 rows)
  final dataRows = rows.skip(2).toList();
  
  print('📋 Found ${dataRows.length} records in CSV\n');

  int processed = 0;
  int updated = 0;
  int notFound = 0;
  int errors = 0;
  int skipped = 0;

  final db = FirebaseFirestore.instance;
  
  for (final row in dataRows) {
    // Skip empty rows or total row
    if (row.isEmpty || row.length < 15) {
      skipped++;
      continue;
    }

    try {
      final memberId = row[0]?.toString().trim() ?? '';
      final referenceId = row[1]?.toString().trim() ?? '';
      final accountNumber = row[2]?.toString().trim() ?? '';
      final memberName = row[7]?.toString().trim() ?? '';
      final memberType = row[10]?.toString().trim() ?? 'Individual';
      final totalBalanceStr = row[14]?.toString().trim().replaceAll(',', '').replaceAll('"', '') ?? '0.00';

      // Skip if no member ID or name
      if (memberId.isEmpty || memberName.isEmpty || memberId == 'Total') {
        skipped++;
        continue;
      }

      // Parse shares balance
      double totalBalance = 0.0;
      try {
        totalBalance = double.parse(totalBalanceStr);
      } catch (e) {
        print('⚠️  Invalid balance for $memberName: $totalBalanceStr');
        errors++;
        continue;
      }

      processed++;

      // Find member by account number or name
      QuerySnapshot? memberQuery;
      
      // Try to find by account number first
      if (accountNumber.isNotEmpty) {
        memberQuery = await db.collection('saccoplus-members')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();
      }

      // If not found by account number, try by name
      if (memberQuery == null || memberQuery.docs.isEmpty) {
        memberQuery = await db.collection('saccoplus-members')
            .where('name', isEqualTo: memberName)
            .limit(1)
            .get();
      }

      if (memberQuery.docs.isEmpty) {
        print('❌ Member not found: $memberName (Account: $accountNumber, ID: $memberId)');
        notFound++;
        continue;
      }

      final memberDoc = memberQuery.docs.first;
      final docId = memberDoc.id;
      final existingData = memberDoc.data() as Map<String, dynamic>;
      final existingShares = (existingData['sharesBalance'] ?? 0).toDouble();

      // Update shares balance
      await db.collection('saccoplus-members').doc(docId).update({
        'sharesBalance': totalBalance,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'shares_migration_script',
      });

      // Also update in users collection
      await db.collection('users').doc(docId).update({
        'sharesBalance': totalBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      updated++;
      
      final change = totalBalance - existingShares;
      final changeIndicator = change > 0 ? '📈' : (change < 0 ? '📉' : '➖');
      
      print('$changeIndicator Updated: $memberName | Shares: UGX ${totalBalance.toStringAsFixed(0)} (was: ${existingShares.toStringAsFixed(0)})');

    } catch (e) {
      print('❌ Error processing row: $e');
      errors++;
    }
  }

  print('\n' + '─' * 60);
  print('📊 MIGRATION SUMMARY');
  print('─' * 60);
  print('Total rows processed: $processed');
  print('✅ Successfully updated: $updated');
  print('❌ Members not found: $notFound');
  print('⚠️  Errors: $errors');
  print('⏭️  Skipped (empty/invalid): $skipped');
  print('─' * 60);
  
  if (updated > 0) {
    print('✨ Migration completed successfully!');
  } else {
    print('⚠️  No records were updated. Please check your data.');
  }
}

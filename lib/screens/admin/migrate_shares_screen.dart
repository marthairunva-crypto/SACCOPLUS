import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import '../../core/theme.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class MigrateSharesScreen extends StatefulWidget {
  const MigrateSharesScreen({super.key});

  @override
  State<MigrateSharesScreen> createState() => _MigrateSharesScreenState();
}

class _MigrateSharesScreenState extends State<MigrateSharesScreen> {
  bool _isProcessing = false;
  bool _autoCreateMembers = true; // Toggle for auto-creating missing members
  List<String> _logs = [];
  int _processed = 0;
  int _updated = 0;
  int _created = 0;
  int _notFound = 0;
  int _errors = 0;

  void _addLog(String message) {
    setState(() => _logs.add(message));
  }

  Future<void> _pickAndProcessCSV() async {
    try {
      // Ensure Firebase is initialized
      if (firebase_core.Firebase.apps.isEmpty) {
        _addLog('❌ Firebase not initialized');
        return;
      }

      // Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _addLog('❌ Could not read file');
        return;
      }

      setState(() {
        _isProcessing = true;
        _logs.clear();
        _processed = 0;
        _updated = 0;
        _created = 0;
        _notFound = 0;
        _errors = 0;
      });

      _addLog('📊 Starting shares migration...');
      _addLog('📂 File: ${file.name}\n');

      // Parse CSV
      final csvString = utf8.decode(file.bytes!);
      final rows = _parseCsv(csvString);

      if (rows.length < 3) {
        _addLog('❌ CSV file appears to be empty or invalid');
        setState(() => _isProcessing = false);
        return;
      }

      // Skip header rows (first 2 rows)
      final dataRows = rows.skip(2).toList();
      _addLog('📋 Found ${dataRows.length} records in CSV\n');

      // Get Firestore instance safely
      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instance;
      } catch (e) {
        _addLog('❌ Error accessing Firestore: $e');
        setState(() => _isProcessing = false);
        return;
      }

      for (final row in dataRows) {
        // Skip empty rows or total row
        if (row.isEmpty || row.length < 15) continue;

        try {
          // Parse EXACT columns from ShareSnapshotReport CSV
          // 0=MemberId, 1=RefId, 2=AccountNo, 3=Branch, 4=Dependents, 5=Disability,
          // 6=ImpairmentType, 7=ClientName, 8=Group, 9=ProductName, 10=MemberType,
          // 11=OpeningBalance, 12=AvailableBalance, 13=ReservedBalance, 14=TotalBalance
          
          // Debug: Log row length
          if (_processed < 3) {
            _addLog('🔍 Debug: Row has ${row.length} columns');
          }
          
          final memberId = _cleanField(row[0]);             // Column 0: Member Id
          final referenceId = _cleanField(row[1]);          // Column 1: Reference Id
          final accountNumber = _cleanField(row[2]);        // Column 2: Account Number
          final branch = _cleanField(row[3]);               // Column 3: Branch
          final dependents = _cleanField(row[4]);           // Column 4: Number Of Dependents
          final disability = _cleanField(row[5]);           // Column 5: IsPersonWithDisability
          final impairmentType = _cleanField(row[6]);       // Column 6: ImpairmentType
          final clientName = _cleanField(row[7]);           // Column 7: Client Name
          final group = _cleanField(row[8]);                // Column 8: Group
          final productName = _cleanField(row[9]);          // Column 9: Product Name
          final memberType = _cleanField(row[10]);          // Column 10: Member Type
          final openingBalance = _parseAmount(_cleanField(row[11]));    // Column 11: Total Opening Balance
          final availableBalance = _parseAmount(_cleanField(row[12]));  // Column 12: Available Balance
          final reservedBalance = _parseAmount(_cleanField(row[13]));   // Column 13: Reserved Balance
          final totalBalance = _parseAmount(_cleanField(row[14]));      // Column 14: Total Balance

          // Debug: Log first few parsed values
          if (_processed < 3) {
            _addLog('🔍 Name: "$clientName", Total: $totalBalance, Account: $accountNumber');
          }

          // Skip if no client name or if it's the total row
          if (clientName.isEmpty || clientName == 'Total') {
            continue;
          }

          setState(() => _processed++);

          // Find member by account number first
          QuerySnapshot? memberQuery;
          
          if (accountNumber.isNotEmpty) {
            memberQuery = await db.collection('saccoplus-members')
                .where('accountNumber', isEqualTo: accountNumber)
                .limit(1)
                .get();
          }

          // If not found by account number, try by name
          if (memberQuery == null || memberQuery.docs.isEmpty) {
            memberQuery = await db.collection('saccoplus-members')
                .where('name', isEqualTo: clientName)
                .limit(1)
                .get();
          }

          if (memberQuery.docs.isEmpty) {
            if (_autoCreateMembers) {
              // Auto-create member record
              final newMemberId = db.collection('saccoplus-members').doc().id;
              
              final newMemberData = {
                'id': newMemberId,
                'memberId': memberId,
                'accountNumber': accountNumber,
                'name': clientName,
                'referenceId': referenceId,
                'branch': branch,
                'memberType': memberType.toLowerCase(),
                'productName': productName,
                'group': group,
                'dependents': dependents,
                'disability': disability,
                'impairmentType': impairmentType,
                'sharesBalance': totalBalance,
                'sharesAvailableBalance': availableBalance,
                'sharesReservedBalance': reservedBalance,
                'sharesOpeningBalance': openingBalance,
                'sharesProductName': productName,
                'sharesMemberId': memberId,
                'sharesReferenceId': referenceId,
                'status': 'active',
                'importedFrom': 'shares_csv_migration',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'createdBy': 'shares_migration',
              };

              // Create in saccoplus-members
              await db.collection('saccoplus-members').doc(newMemberId).set(newMemberData);

              // Create basic user record
              await db.collection('users').doc(newMemberId).set({
                'name': clientName,
                'accountNumber': accountNumber,
                'sharesBalance': totalBalance,
                'role': 'farmer',
                'status': 'active',
                'importedFrom': 'shares_csv_migration',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              setState(() => _created++);
              _addLog('✅ Created: $clientName | UGX ${totalBalance.toStringAsFixed(0)}');
            } else {
              _addLog('❌ Not found: $clientName (Account: $accountNumber)');
              setState(() => _notFound++);
            }
            continue;
          }

          final memberDoc = memberQuery.docs.first;
          final docId = memberDoc.id;
          final existingData = memberDoc.data() as Map<String, dynamic>;
          final existingShares = ((existingData['sharesBalance'] ?? 0) as num).toDouble();

          // Update member with shares data
          final updateData = {
            'sharesBalance': totalBalance,
            'sharesAvailableBalance': availableBalance,
            'sharesReservedBalance': reservedBalance,
            'sharesOpeningBalance': openingBalance,
            'sharesProductName': productName,
            'sharesMemberId': memberId,
            'sharesReferenceId': referenceId,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': 'shares_migration',
          };

          // Update in saccoplus-members collection
          await db.collection('saccoplus-members').doc(docId).update(updateData);

          // Also update in users collection
          await db.collection('users').doc(docId).update({
            'sharesBalance': totalBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() => _updated++);

          final change = totalBalance - existingShares;
          final changeIndicator = change > 0 ? '📈' : (change < 0 ? '📉' : '➖');

          _addLog('$changeIndicator $clientName | UGX ${totalBalance.toStringAsFixed(0)} (was: ${existingShares.toStringAsFixed(0)})');
        } catch (e) {
          _addLog('❌ Error: $e');
          setState(() => _errors++);
        }
      }

      _addLog('\n' + '─' * 40);
      _addLog('📊 MIGRATION SUMMARY');
      _addLog('─' * 40);
      _addLog('Processed: $_processed');
      _addLog('✅ Updated: $_updated');
      _addLog('🆕 Created: $_created');
      _addLog('❌ Not found: $_notFound');
      _addLog('⚠️  Errors: $_errors');
      _addLog('─' * 40);

      if (_updated + _created > 0) {
        _addLog('✨ Migration completed!');
      }
    } catch (e) {
      _addLog('❌ Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _cleanField(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  double _parseAmount(String value) {
    if (value.isEmpty) return 0.0;
    try {
      return double.parse(value.replaceAll(',', '').replaceAll('"', ''));
    } catch (e) {
      return 0.0;
    }
  }

  List<List<String>> _parseCsv(String csvString) {
    final lines = csvString.split('\n');
    final List<List<String>> result = [];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final fields = _parseCsvLine(line);
      result.add(fields);
    }

    return result;
  }

  /// Parse a CSV line respecting quoted fields with commas inside
  List<String> _parseCsvLine(String line) {
    final List<String> fields = [];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Add the last field
    fields.add(buffer.toString());

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Migrate Shares from CSV', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Text('Instructions', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Export ShareSnapshotReport to CSV (keep exact column order)\n'
                      '   Columns: MemberId, RefId, AccountNo, Branch, Dependents, Disability,\n'
                      '   ImpairmentType, ClientName, Group, ProductName, MemberType,\n'
                      '   OpeningBalance, AvailableBalance, ReservedBalance, TotalBalance\n\n'
                      '2. Click "Select CSV File" button below\n'
                      '3. System will match members by account number or name\n'
                      '4. Shares balances will be updated in database\n\n'
                      'All 15 columns from your ShareSnapshotReport are supported!',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Auto-create toggle
            Card(
              child: SwitchListTile(
                title: Text('Auto-create missing members', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  'Automatically create member records for entries not found in database',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                ),
                value: _autoCreateMembers,
                onChanged: _isProcessing ? null : (value) => setState(() => _autoCreateMembers = value),
                activeColor: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Action button
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickAndProcessCSV,
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(_isProcessing ? 'Processing...' : 'Select CSV File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 24),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatCard(label: 'Processed', value: _processed.toString(), color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Updated', value: _updated.toString(), color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Created', value: _created.toString(), color: Colors.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Not Found', value: _notFound.toString(), color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Errors', value: _errors.toString(), color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Logs section
              Expanded(
                child: Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('Migration Logs', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                _logs[index],
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.grey.shade800),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

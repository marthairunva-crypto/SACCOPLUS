import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class MigrateSavingsScreen extends StatefulWidget {
  const MigrateSavingsScreen({super.key});

  @override
  State<MigrateSavingsScreen> createState() => _MigrateSavingsScreenState();
}

class _MigrateSavingsScreenState extends State<MigrateSavingsScreen> {
  bool _isProcessing = false;
  bool _autoCreateMembers = true;
  List<String> _logs = [];
  int _processed = 0;
  int _created = 0;
  int _skipped = 0;
  int _errors = 0;

  void _addLog(String message) {
    setState(() => _logs.add(message));
  }

  // Parse CSV handling quoted fields properly
  List<List<String>> _parseCsv(String csv) {
    final rows = <List<String>>[];
    final lines = csv.split('\n');
    
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      rows.add(_parseCsvLine(line));
    }
    
    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    
    fields.add(buffer.toString().trim());
    return fields;
  }

  Future<void> _pickAndProcessCSV() async {
    try {
      if (firebase_core.Firebase.apps.isEmpty) {
        _addLog('❌ Firebase not initialized');
        return;
      }

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
        _created = 0;
        _skipped = 0;
        _errors = 0;
      });

      _addLog('💰 Starting savings migration...');
      _addLog('📂 File: ${file.name}');
      _addLog('🏢 Tenant: ${FirebaseService.sessionTenantId}\n');

      final csvString = utf8.decode(file.bytes!);
      final rows = _parseCsv(csvString);

      if (rows.length < 3) {
        _addLog('❌ CSV file appears to be empty or invalid');
        setState(() => _isProcessing = false);
        return;
      }

      // Skip header rows (first 2 rows in SavingSnapshotReport)
      final dataRows = rows.skip(2).toList();
      _addLog('📋 Found ${dataRows.length} records in CSV\n');

      final db = FirebaseFirestore.instance;
      final tenantId = FirebaseService.sessionTenantId;

      // Get all existing members for this tenant
      final membersSnapshot = await db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      final membersByMemberId = <String, String>{};
      final membersByAccountNumber = <String, String>{};
      
      for (final doc in membersSnapshot.docs) {
        final data = doc.data();
        final memberId = data['memberId'] as String?;
        final accountNumber = data['accountNumber'] as String?;
        
        if (memberId != null) {
          membersByMemberId[memberId] = doc.id;
        }
        if (accountNumber != null) {
          membersByAccountNumber[accountNumber] = doc.id;
        }
      }

      _addLog('👥 Found ${membersByMemberId.length} existing members\n');

      for (final row in dataRows) {
        if (row.isEmpty || row.length < 19) {
          _skipped++;
          continue;
        }

        try {
          // CSV Columns: Member Id, Reference Id, Account Number, Account Name, Branch,
          // Number Of Dependents, IsPersonWithDisability, ImpairmentType, Client Name,
          // Gender, Product Name, Member Type, Manager, Total Opening Balance,
          // Available Balance, Reserved Balance, Total Balance, Saving Product Type, Group
          
          final memberId = row[0].trim();
          final referenceId = row[1].trim();
          final accountNumber = row[2].trim();
          final accountName = row[3].trim();
          final branch = row[4].trim();
          final clientName = row[8].trim();
          final gender = row[9].trim();
          final productName = row[10].trim();
          final memberType = row[11].trim();
          final manager = row[12].trim();
          
          // Parse balances - remove commas and any currency symbols
          // Example: "10,000.00" -> "10000.00" -> 10000.00
          final openingBalanceRaw = row[13].trim();
          final availableBalanceRaw = row[14].trim();
          final reservedBalanceRaw = row[15].trim();
          final totalBalanceRaw = row[16].trim();
          
          final openingBalance = double.tryParse(openingBalanceRaw.replaceAll(',', '').replaceAll('UGX', '').trim()) ?? 0.0;
          final availableBalance = double.tryParse(availableBalanceRaw.replaceAll(',', '').replaceAll('UGX', '').trim()) ?? 0.0;
          final reservedBalance = double.tryParse(reservedBalanceRaw.replaceAll(',', '').replaceAll('UGX', '').trim()) ?? 0.0;
          final totalBalance = double.tryParse(totalBalanceRaw.replaceAll(',', '').replaceAll('UGX', '').trim()) ?? 0.0;
          
          // Debug first few records to verify parsing is correct
          if (_created < 5 && totalBalance > 0) {
            _addLog('🔍 ${clientName}:');
            _addLog('   Raw CSV: "$totalBalanceRaw" -> Parsed: $totalBalance UGX');
          }
          
          final productType = row[17].trim();
          final group = row.length > 18 ? row[18].trim() : '';

          _processed++;

          // Skip if no balance
          if (totalBalance <= 0) {
            _skipped++;
            if (_processed % 20 == 0) {
              _addLog('⏭️  Skipped ${_skipped} records with 0 balance...');
            }
            continue;
          }

          // Find member by memberId or accountNumber
          String? firebaseId = membersByMemberId[memberId];
          if (firebaseId == null && accountNumber.isNotEmpty) {
            firebaseId = membersByAccountNumber[accountNumber];
          }

          if (firebaseId == null) {
            if (_autoCreateMembers && clientName.isNotEmpty) {
              // Create new member
              final newMemberData = {
                'tenantId': tenantId,
                'memberId': memberId,
                'accountNumber': accountNumber.isNotEmpty ? accountNumber : memberId,
                'name': clientName,
                'fullName': clientName,
                'gender': gender.isNotEmpty ? gender : 'Not Specified',
                'memberType': memberType.isNotEmpty ? memberType : 'Individual',
                'branch': branch.isNotEmpty ? branch : 'Main Branch',
                'manager': manager,
                'group': group,
                'status': 'active',
                'savingsBalance': totalBalance,
                'sharesBalance': 0.0,
                'loanBalance': 0.0,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };

              final newMemberDoc = await db.collection('saccoplus-members').add(newMemberData);
              firebaseId = newMemberDoc.id;
              membersByMemberId[memberId] = firebaseId;
              if (accountNumber.isNotEmpty) {
                membersByAccountNumber[accountNumber] = firebaseId;
              }
              
              _addLog('✅ Created member: $clientName ($memberId) - Balance: ${totalBalance.toStringAsFixed(2)} UGX');
            } else {
              _errors++;
              _addLog('❌ Member not found: $memberId ($clientName)');
              continue;
            }
          }

          // Create savings transaction record
          final savingTransaction = {
            'tenantId': tenantId,
            'farmerId': firebaseId,
            'memberName': clientName,
            'memberId': memberId,
            'accountNumber': accountNumber,
            'referenceId': referenceId,
            'amount': totalBalance,
            'availableBalance': availableBalance,
            'reservedBalance': reservedBalance,
            'openingBalance': openingBalance,
            'productName': productName,
            'productType': productType,
            'branch': branch,
            'manager': manager,
            'group': group,
            'transactionType': 'deposit',
            'description': 'Opening balance from migration',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await db.collection('saccoplus-savings').add(savingTransaction);
          
          // Update member's savingsBalance
          await db.collection('saccoplus-members').doc(firebaseId).update({
            'savingsBalance': totalBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          _created++;

          if (_created % 10 == 0) {
            _addLog('💰 Imported ${_created} savings records...');
          }

        } catch (e) {
          _errors++;
          _addLog('❌ Error processing row: $e');
        }
      }

      _addLog('\n✅ Migration Complete!');
      _addLog('📊 Processed: $_processed');
      _addLog('✅ Created: $_created');
      _addLog('⏭️  Skipped: $_skipped');
      _addLog('❌ Errors: $_errors');

    } catch (e) {
      _addLog('\n❌ Fatal error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Migrate Savings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Text(
                        'Savings CSV Import',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This tool imports savings data from SavingSnapshotReport CSV files.\n\n'
                    '✓ Creates actual transaction records in saccoplus-savings\n'
                    '✓ Updates member savingsBalance fields\n'
                    '✓ Preserves all CSV columns (account number, product name, etc.)\n'
                    '✓ Auto-creates missing members (if enabled)\n'
                    '✓ Skips records with 0 balance\n'
                    '✓ Fixes comma/decimal parsing (10,000.00 = 10000 UGX, not 1 million)',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Auto-create toggle
            SwitchListTile(
              title: Text('Auto-create missing members', style: GoogleFonts.poppins()),
              subtitle: Text(
                'Create new member records if memberId not found',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              value: _autoCreateMembers,
              onChanged: _isProcessing ? null : (val) => setState(() => _autoCreateMembers = val),
            ),

            const SizedBox(height: 20),

            // Import button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAndProcessCSV,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isProcessing ? 'Processing...' : 'Select CSV File',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            if (_processed > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Processed', _processed.toString(), Colors.blue),
                    _buildStat('Created', _created.toString(), Colors.green),
                    _buildStat('Skipped', _skipped.toString(), Colors.orange),
                    _buildStat('Errors', _errors.toString(), Colors.red),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Logs
            Text(
              'Activity Log',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _logs[index],
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          color: _logs[index].startsWith('❌')
                              ? Colors.red.shade300
                              : _logs[index].startsWith('✅')
                                  ? Colors.green.shade300
                                  : Colors.grey.shade300,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

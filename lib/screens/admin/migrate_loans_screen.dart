import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class MigrateLoansScreen extends StatefulWidget {
  const MigrateLoansScreen({super.key});

  @override
  State<MigrateLoansScreen> createState() => _MigrateLoansScreenState();
}

class _MigrateLoansScreenState extends State<MigrateLoansScreen> {
  bool _isProcessing = false;
  List<String> _logs = [];
  int _processed = 0;
  int _created = 0;
  int _updated = 0;
  int _errors = 0;
  int _skipped = 0;

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
        _created = 0;
        _updated = 0;
        _errors = 0;
        _skipped = 0;
      });

      _addLog('📊 Starting loan migration...');
      _addLog('📂 File: ${file.name}\n');

      // Parse CSV
      final csvString = utf8.decode(file.bytes!);
      final rows = _parseCsv(csvString);

      if (rows.length < 2) {
        _addLog('❌ CSV file appears to be empty or invalid');
        setState(() => _isProcessing = false);
        return;
      }

      // Skip header row
      final dataRows = rows.skip(1).toList();
      _addLog('📋 Found ${dataRows.length} loan records in CSV\n');

      // Get Firestore instance safely
      FirebaseFirestore db;
      try {
        db = FirebaseFirestore.instance;
      } catch (e) {
        _addLog('❌ Error accessing Firestore: $e');
        setState(() => _isProcessing = false);
        return;
      }
      
      final tenantId = FirebaseService.sessionTenantId;

      for (final row in dataRows) {
        // Skip empty rows
        if (row.isEmpty || row.length < 27) {
          setState(() => _skipped++);
          continue;
        }

        try {
          // Parse EXACT columns from ActiveLoanReport CSV
          // CSV Structure (27 columns):
          // 0=AccountNumber, 1=ClientName, 2=ReferenceNumber, 3=LoanProduct, 4=Group,
          // 5=MemberType, 6=MembershipPolicy, 7=Gender, 8=Age, 9=Branch,
          // 10=Dependents, 11=Disability, 12=ImpairmentType, 13=LoanOfficer,
          // 14=TenureType, 15=Tenure, 16=CreationDate, 17=DisbursementDate,
          // 18=ExpiryDate, 19=TotalLoanAmount, 20=TotalInterestAmount, 21=DueDate,
          // 22=OutstandingCharges, 23=OutstandingPrincipal, 24=OutstandingInterest,
          // 25=OriginalDisbursedAmount, 26=OverdueDays
          
          final accountNumber = _cleanField(row[0]);            // Column 0: Account Number
          final memberName = _cleanField(row[1]);               // Column 1: Client Name
          final referenceNumber = _cleanField(row[2]);          // Column 2: Reference Number
          final loanProduct = _cleanField(row[3]);              // Column 3: Loan Product
          final group = _cleanField(row[4]);                    // Column 4: Group
          final memberType = _cleanField(row[5]);               // Column 5: Member Type
          final membershipPolicy = _cleanField(row[6]);         // Column 6: MembershipPolicy
          final gender = _cleanField(row[7]);                   // Column 7: Gender
          final age = _cleanField(row[8]);                      // Column 8: Age
          final branch = _cleanField(row[9]);                   // Column 9: Branch
          final dependents = _cleanField(row[10]);              // Column 10: Number Of Dependents
          final disability = _cleanField(row[11]);              // Column 11: IsPersonWithDisability
          final impairmentType = _cleanField(row[12]);          // Column 12: ImpairmentType
          final officer = _cleanField(row[13]);                 // Column 13: Loan Officer
          final tenureType = _cleanField(row[14]);              // Column 14: Tenure Type
          final tenure = _cleanField(row[15]);                  // Column 15: Tenure
          
          // Parse dates
          final creationDate = _parseDate(_cleanField(row[16]));      // Column 16: Creation Date
          final disbursementDate = _parseDate(_cleanField(row[17]));  // Column 17: Disbursement Date
          final expiryDate = _parseDate(_cleanField(row[18]));        // Column 18: Expiry Date
          
          // Parse amounts
          final totalLoanAmount = _parseAmount(_cleanField(row[19]));      // Column 19: Total Loan Amount
          final interestAmount = _parseAmount(_cleanField(row[20]));       // Column 20: Total Interest Amount
          final dueDate = _parseDate(_cleanField(row[21]));                // Column 21: Due Date
          final outstandingCharge = _parseAmount(_cleanField(row[22]));    // Column 22: Outstanding Charges
          final principalOutstanding = _parseAmount(_cleanField(row[23])); // Column 23: Outstanding Principal
          final interestOriginal = _parseAmount(_cleanField(row[24]));     // Column 24: Outstanding Interest
          final originalDisbursed = _parseAmount(_cleanField(row[25]));    // Column 25: OriginalDisbursedAmount
          final outstandingDays = _parseInt(_cleanField(row[26]));         // Column 26: Overdue Days

          // Skip if no reference number
          if (referenceNumber.isEmpty) {
            setState(() => _skipped++);
            continue;
          }

          setState(() => _processed++);

          // Find member by name
          QuerySnapshot? memberQuery;
          if (memberName.isNotEmpty) {
            memberQuery = await db
                .collection('saccoplus-members')
                .where('name', isEqualTo: memberName)
                .where('tenantId', isEqualTo: tenantId)
                .limit(1)
                .get();
          }

          String? memberId;
          if (memberQuery != null && memberQuery.docs.isNotEmpty) {
            memberId = memberQuery.docs.first.id;
          }

          // Check if loan already exists by reference number
          final existingLoan = await db
              .collection('saccoplus-loans')
              .where('referenceNumber', isEqualTo: referenceNumber)
              .where('tenantId', isEqualTo: tenantId)
              .limit(1)
              .get();

          // Calculate total outstanding
          final totalOutstanding = outstandingCharge + principalOutstanding + interestOriginal;

          // Determine loan status
          String status;
          if (totalOutstanding <= 0 && principalOutstanding <= 0) {
            status = 'paid';
          } else if (outstandingDays > 30) {
            status = 'overdue';
          } else if (disbursementDate != null) {
            status = 'active';
          } else {
            status = 'approved';
          }

          final loanData = {
            'tenantId': tenantId,
            'accountNumber': accountNumber,
            'referenceNumber': referenceNumber,
            'loanProduct': loanProduct,
            'group': group,
            'memberType': memberType,
            'membershipPolicy': membershipPolicy,
            'memberName': memberName,
            'farmerId': memberId,
            'gender': gender,
            'age': age,
            'branch': branch,
            'numberOfDependents': dependents,
            'isPersonWithDisability': disability,
            'impairmentType': impairmentType,
            'loanOfficer': officer,
            'tenureType': tenureType,
            'tenure': tenure,
            'amount': totalLoanAmount,
            'interestAmount': interestAmount,
            'totalAmount': totalLoanAmount + interestAmount,
            'outstandingCharge': outstandingCharge,
            'principalOutstanding': principalOutstanding,
            'interestOriginalBalance': interestOriginal,
            'originalDisbursedAmount': originalDisbursed,
            'totalOutstanding': totalOutstanding,
            'outstandingDays': outstandingDays,
            'createdAt': creationDate != null ? Timestamp.fromDate(creationDate) : FieldValue.serverTimestamp(),
            'disbursementDate': disbursementDate != null ? Timestamp.fromDate(disbursementDate) : null,
            'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate) : null,
            'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
            'migratedFrom': 'csv_import',
          };

          if (existingLoan.docs.isEmpty) {
            // Create new loan
            await db.collection('saccoplus-loans').add(loanData);
            setState(() => _created++);
            _addLog('✅ Created: $memberName - $referenceNumber (UGX ${totalLoanAmount.toStringAsFixed(0)})');
          } else {
            // Update existing loan
            await db.collection('saccoplus-loans').doc(existingLoan.docs.first.id).update(loanData);
            setState(() => _updated++);
            _addLog('🔄 Updated: $memberName - $referenceNumber (UGX ${totalLoanAmount.toStringAsFixed(0)})');
          }
        } catch (e) {
          _addLog('❌ Error processing row: $e');
          setState(() => _errors++);
        }
      }

      _addLog('\n' + '─' * 40);
      _addLog('📊 MIGRATION SUMMARY');
      _addLog('─' * 40);
      _addLog('Processed: $_processed');
      _addLog('✅ Created: $_created');
      _addLog('🔄 Updated: $_updated');
      _addLog('⏭️  Skipped: $_skipped');
      _addLog('⚠️  Errors: $_errors');
      _addLog('─' * 40);

      if (_created + _updated > 0) {
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

  int _parseInt(String value) {
    if (value.isEmpty) return 0;
    try {
      return int.parse(value.replaceAll(',', ''));
    } catch (e) {
      return 0;
    }
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    try {
      // Try parsing different date formats
      // Format: DD-MMM-YY or DD-MMM-YYYY
      final parts = value.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = _parseMonth(parts[1]);
        final yearStr = parts[2];
        int year = int.parse(yearStr);
        // Handle 2-digit years
        if (year < 100) {
          year = year < 50 ? 2000 + year : 1900 + year;
        }
        return DateTime(year, month, day);
      }
    } catch (e) {
      // Return null if parsing fails
    }
    return null;
  }

  int _parseMonth(String monthStr) {
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    return months[monthStr.toLowerCase()] ?? 1;
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
        // Don't add the quote character to the buffer
      } else if (char == ',' && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // Add the last field
    fields.add(buffer.toString().trim());

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Migrate Loans from CSV', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                      '1. Export ActiveLoanReport to CSV (keep exact column order)\n'
                      '   Columns: No, Reference, Product, Group, MemberType, Name, Gender,\n'
                      '   Age, Branch, Dependents, Disability, Officer, Period, Dates, Amounts\n\n'
                      '2. Click "Select CSV File" button below\n'
                      '3. System will match members automatically by name\n'
                      '4. Loans will be created or updated in database\n\n'
                      'Supported date format: DD-MMM-YY (e.g., 11-Nov-25)\n'
                      'All 23 columns from your ActiveLoanReport are supported!',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
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
                    child: _StatCard(label: 'Created', value: _created.toString(), color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(label: 'Updated', value: _updated.toString(), color: Colors.orange),
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

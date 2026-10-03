import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';

class LoanDataCorrectionScreen extends StatefulWidget {
  const LoanDataCorrectionScreen({Key? key}) : super(key: key);

  @override
  State<LoanDataCorrectionScreen> createState() => _LoanDataCorrectionScreenState();
}

class _LoanDataCorrectionScreenState extends State<LoanDataCorrectionScreen> {
  final _db = FirebaseFirestore.instance;
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  List<Map<String, dynamic>> _loans = [];
  bool _isLoading = true;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);
    
    final snapshot = await _db
        .collection(AppConstants.loansCol)
        .orderBy('createdAt', descending: true)
        .get();
    
    setState(() {
      _loans = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'memberName': data['memberName'] ?? 'N/A',
          'accountNumber': data['accountNumber'] ?? 'N/A',
          'loanAmount': (data['loanAmount'] ?? data['amount'] ?? 0).toDouble(),
          'disbursementDate': data['disbursementDate'] ?? data['disbursedAt'],
          'principalOutstanding': (data['principalOutstanding'] ?? 0).toDouble(),
          'interestOutstanding': (data['interestOutstanding'] ?? 0).toDouble(),
          'status': data['status'] ?? 'N/A',
          // Controllers for editing
          'disbursementDateCtrl': TextEditingController(
            text: data['disbursementDate'] != null || data['disbursedAt'] != null
                ? DateFormat('yyyy-MM-dd').format(
                    (data['disbursementDate'] ?? data['disbursedAt'] as Timestamp).toDate()
                  )
                : ''
          ),
          'principalOutstandingCtrl': TextEditingController(
            text: (data['principalOutstanding'] ?? 0).toString()
          ),
          'interestOutstandingCtrl': TextEditingController(
            text: (data['interestOutstanding'] ?? 0).toString()
          ),
          'principalPaidCtrl': TextEditingController(
            text: (data['principalPaid'] ?? 0).toString()
          ),
          'interestPaidCtrl': TextEditingController(
            text: (data['interestPaid'] ?? 0).toString()
          ),
          'isModified': false,
        };
      }).toList();
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    final modifiedLoans = _loans.where((loan) => loan['isModified'] == true).toList();
    
    if (modifiedLoans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    // Confirm before saving
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Update'),
        content: Text('Update ${modifiedLoans.length} loan(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    int successCount = 0;
    int failCount = 0;

    for (var loan in modifiedLoans) {
      try {
        final disbDateStr = loan['disbursementDateCtrl'].text.trim();
        final principalOut = double.tryParse(loan['principalOutstandingCtrl'].text) ?? 0;
        final interestOut = double.tryParse(loan['interestOutstandingCtrl'].text) ?? 0;
        final principalPaid = double.tryParse(loan['principalPaidCtrl'].text) ?? 0;
        final interestPaid = double.tryParse(loan['interestPaidCtrl'].text) ?? 0;
        
        final updateData = <String, dynamic>{
          'principalOutstanding': principalOut,
          'interestOutstanding': interestOut,
          'principalPaid': principalPaid,
          'interestPaid': interestPaid,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Update disbursement date if provided
        if (disbDateStr.isNotEmpty) {
          try {
            final disbDate = DateTime.parse(disbDateStr);
            updateData['disbursementDate'] = Timestamp.fromDate(disbDate);
            updateData['disbursedAt'] = Timestamp.fromDate(disbDate);
          } catch (e) {
            print('Invalid date format for loan ${loan['id']}: $disbDateStr');
          }
        }

        await _db.collection(AppConstants.loansCol).doc(loan['id']).update(updateData);
        successCount++;
      } catch (e) {
        print('Error updating loan ${loan['id']}: $e');
        failCount++;
      }
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated: $successCount, Failed: $failCount'),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
      
      // Reload data
      _loadLoans();
    }
  }

  @override
  void dispose() {
    for (var loan in _loans) {
      loan['disbursementDateCtrl']?.dispose();
      loan['principalOutstandingCtrl']?.dispose();
      loan['interestOutstandingCtrl']?.dispose();
      loan['principalPaidCtrl']?.dispose();
      loan['interestPaidCtrl']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Loan Data Correction',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save All Changes',
              onPressed: _saveChanges,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadLoans,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loans.isEmpty
              ? const Center(child: Text('No loans found'))
              : Column(
                  children: [
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Update loan disbursement dates and outstanding balances. Date format: YYYY-MM-DD (e.g., 2024-08-31)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Loans table
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                            columns: [
                              DataColumn(label: Text('Member', style: _headerStyle())),
                              DataColumn(label: Text('Account', style: _headerStyle())),
                              DataColumn(label: Text('Loan Amount', style: _headerStyle())),
                              DataColumn(label: Text('Disbursement Date\n(YYYY-MM-DD)', style: _headerStyle())),
                              DataColumn(label: Text('Principal\nOutstanding', style: _headerStyle())),
                              DataColumn(label: Text('Interest\nOutstanding', style: _headerStyle())),
                              DataColumn(label: Text('Principal\nPaid', style: _headerStyle())),
                              DataColumn(label: Text('Interest\nPaid', style: _headerStyle())),
                              DataColumn(label: Text('Status', style: _headerStyle())),
                            ],
                            rows: _loans.map((loan) => _buildLoanRow(loan)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      fontSize: 12,
    );
  }

  DataRow _buildLoanRow(Map<String, dynamic> loan) {
    final isModified = loan['isModified'] == true;
    final rowColor = isModified ? Colors.yellow.shade50 : Colors.white;
    
    return DataRow(
      color: MaterialStateProperty.all(rowColor),
      cells: [
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              loan['memberName'],
              style: GoogleFonts.inter(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Text(loan['accountNumber'], style: GoogleFonts.inter(fontSize: 12)),
        ),
        DataCell(
          Text(
            _currencyFormat.format(loan['loanAmount'].round()),
            style: GoogleFonts.inter(fontSize: 12),
          ),
        ),
        DataCell(
          SizedBox(
            width: 120,
            child: TextField(
              controller: loan['disbursementDateCtrl'],
              style: GoogleFonts.inter(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder(),
                hintText: '2024-08-31',
              ),
              onChanged: (value) {
                setState(() {
                  loan['isModified'] = true;
                });
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: TextField(
              controller: loan['principalOutstandingCtrl'],
              style: GoogleFonts.inter(fontSize: 12),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  loan['isModified'] = true;
                });
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: TextField(
              controller: loan['interestOutstandingCtrl'],
              style: GoogleFonts.inter(fontSize: 12),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  loan['isModified'] = true;
                });
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: TextField(
              controller: loan['principalPaidCtrl'],
              style: GoogleFonts.inter(fontSize: 12),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  loan['isModified'] = true;
                });
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 100,
            child: TextField(
              controller: loan['interestPaidCtrl'],
              style: GoogleFonts.inter(fontSize: 12),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  loan['isModified'] = true;
                });
              },
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(loan['status']),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              loan['status'],
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'disbursed':
        return Colors.green;
      case 'pending':
      case 'approved':
        return Colors.orange;
      case 'paid':
      case 'closed':
        return Colors.teal;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

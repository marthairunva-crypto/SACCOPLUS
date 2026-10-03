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
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _filteredLoans = [];
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentPage = 0;
  int _itemsPerPage = 20;
  
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
            text: () {
              final disbDate = data['disbursementDate'] ?? data['disbursedAt'];
              if (disbDate != null && disbDate is Timestamp) {
                return DateFormat('yyyy-MM-dd').format(disbDate.toDate());
              }
              return '';
            }()
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
      _filteredLoans = _loans;
      _isLoading = false;
    });
  }

  void _filterLoans(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLoans = _loans;
      } else {
        _filteredLoans = _loans.where((loan) {
          final memberName = loan['memberName'].toString().toLowerCase();
          final accountNumber = loan['accountNumber'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          return memberName.contains(searchLower) || accountNumber.contains(searchLower);
        }).toList();
      }
      _currentPage = 0; // Reset to first page when searching
    });
  }

  List<Map<String, dynamic>> _getPaginatedLoans() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredLoans.length);
    
    if (startIndex >= _filteredLoans.length) return [];
    return _filteredLoans.sublist(startIndex, endIndex);
  }

  int get _totalPages => (_filteredLoans.length / _itemsPerPage).ceil();

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
    _searchController.dispose();
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
                    // Search bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by member name or account number...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterLoans('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: _filterLoans,
                      ),
                    ),
                    
                    // Results count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${_getPaginatedLoans().length} of ${_filteredLoans.length} loans',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                          Text(
                            'Page ${_currentPage + 1} of ${_totalPages > 0 ? _totalPages : 1}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    
                    // Loans table
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
                              DataColumn(label: Text('Disbursement Date\n(Pick from calendar)', style: _headerStyle())),
                              DataColumn(label: Text('Principal\nOutstanding', style: _headerStyle())),
                              DataColumn(label: Text('Interest\nOutstanding', style: _headerStyle())),
                              DataColumn(label: Text('Principal\nPaid', style: _headerStyle())),
                              DataColumn(label: Text('Interest\nPaid', style: _headerStyle())),
                              DataColumn(label: Text('Status', style: _headerStyle())),
                            ],
                            rows: _getPaginatedLoans().map((loan) => _buildLoanRow(loan)).toList(),
                          ),
                        ),
                      ),
                    ),
                    
                    // Pagination controls
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.first_page),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage = 0)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Page ${_currentPage + 1} of ${_totalPages > 0 ? _totalPages : 1}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.last_page),
                            onPressed: _currentPage < _totalPages - 1
                                ? () => setState(() => _currentPage = _totalPages - 1)
                                : null,
                          ),
                        ],
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
            width: 140,
            child: InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: () {
                    try {
                      final dateStr = loan['disbursementDateCtrl'].text;
                      if (dateStr.isNotEmpty) {
                        return DateTime.parse(dateStr);
                      }
                    } catch (e) {}
                    return DateTime.now();
                  }(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                
                if (picked != null) {
                  setState(() {
                    loan['disbursementDateCtrl'].text = DateFormat('yyyy-MM-dd').format(picked);
                    loan['isModified'] = true;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        loan['disbursementDateCtrl'].text.isEmpty 
                            ? 'Pick date' 
                            : loan['disbursementDateCtrl'].text,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: loan['disbursementDateCtrl'].text.isEmpty 
                              ? Colors.grey.shade600 
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  ],
                ),
              ),
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

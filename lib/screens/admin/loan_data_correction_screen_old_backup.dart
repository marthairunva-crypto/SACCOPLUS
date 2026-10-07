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
  final _listScroll = ScrollController();
  List<Map<String, dynamic>>? _loans;
  List<Map<String, dynamic>>? _filteredLoans;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentPage = 0;
  final int _itemsPerPage = 20;

  // ---- Responsive breakpoints (based on the width the page actually gets,
  // i.e. AFTER the sidebar is subtracted, because we use LayoutBuilder). ----
  static const double _tableMinWidth = 1100; // below this -> cards
  static const double _twoColCardsMinWidth = 700; // below this -> 1 card/row
  static const double _maxContentWidth = 1800; // keep table sane on huge screens

  // Column flex ratios: member, account, loan, date, totalOut, arrears, status
  static const _flex = [3, 3, 2, 3, 3, 2, 2];

  @override
  void initState() {
    super.initState();
    _loans = [];
    _filteredLoans = [];
    _loadLoans();
  }

  void _disposeLoanControllers() {
    if (_loans == null) return;
    for (var loan in _loans!) {
      loan['disbursementDateCtrl']?.dispose();
      loan['totalOutstandingCtrl']?.dispose();
      loan['arrearsCtrl']?.dispose();
    }
  }

  Future<void> _loadLoans() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _db
          .collection(AppConstants.loansCol)
          .orderBy('createdAt', descending: true)
          .get();

      final newLoans = snapshot.docs.map((doc) {
        final data = doc.data();
        
        // Calculate total outstanding from existing principal + interest if totalOutstanding not set
        final principalOut = (data['principalOutstanding'] ?? 0).toDouble();
        final interestOut = (data['interestOutstanding'] ?? 0).toDouble();
        final totalOut = data.containsKey('totalOutstanding') 
            ? (data['totalOutstanding'] ?? 0).toDouble()
            : principalOut + interestOut;
        
        return <String, dynamic>{
          'id': doc.id,
          'memberName': data['memberName'] ?? 'N/A',
          'accountNumber': data['accountNumber'] ?? 'N/A',
          'loanAmount': (data['loanAmount'] ?? data['amount'] ?? 0).toDouble(),
          'disbursementDate': data['disbursementDate'] ?? data['disbursedAt'],
          'totalOutstanding': totalOut,
          'arrears': (data['arrears'] ?? 0).toDouble(),
          'status': data['status'] ?? 'N/A',
          'disbursementDateCtrl': TextEditingController(
            text: () {
              final disbDate = data['disbursementDate'] ?? data['disbursedAt'];
              if (disbDate != null && disbDate is Timestamp) {
                return DateFormat('yyyy-MM-dd').format(disbDate.toDate());
              }
              return '';
            }(),
          ),
          'totalOutstandingCtrl': TextEditingController(
              text: totalOut.toString()),
          'arrearsCtrl': TextEditingController(
              text: (data['arrears'] ?? 0).toString()),
          'isModified': false,
        };
      }).toList();

      if (!mounted) {
        for (final l in newLoans) {
          (l['disbursementDateCtrl'] as TextEditingController).dispose();
          (l['totalOutstandingCtrl'] as TextEditingController).dispose();
          (l['arrearsCtrl'] as TextEditingController).dispose();
        }
        return;
      }

      // Dispose the previous controllers (avoids leaks on reload).
      final old = _loans;
      setState(() {
        _loans = newLoans;
        _currentPage = 0;
        _isLoading = false;
      });
      _filterLoans(_searchController.text);
      if (old != null) {
        final tmp = _loans;
        _loans = old;
        _disposeLoanControllers();
        _loans = tmp;
      }

      if (mounted && snapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Loaded ${snapshot.docs.length} loans'),
              duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading loans: $e');
      if (!mounted) return;
      setState(() {
        _loans = [];
        _filteredLoans = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading loans: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterLoans(String query) {
    if (_loans == null) return;
    setState(() {
      if (query.isEmpty) {
        _filteredLoans = List<Map<String, dynamic>>.from(_loans!);
      } else {
        final q = query.toLowerCase();
        _filteredLoans = _loans!.where((loan) {
          return loan['memberName'].toString().toLowerCase().contains(q) ||
              loan['accountNumber'].toString().toLowerCase().contains(q);
        }).toList();
      }
      _currentPage = 0;
    });
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page.clamp(0, _totalPages - 1));
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
  }

  List<Map<String, dynamic>> _getPaginatedLoans() {
    if (_filteredLoans == null || _filteredLoans!.isEmpty) return [];
    final startIndex = _currentPage * _itemsPerPage;
    if (startIndex >= _filteredLoans!.length) return [];
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredLoans!.length);
    return _filteredLoans!.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    if (_filteredLoans == null || _filteredLoans!.isEmpty) return 1;
    final pages = (_filteredLoans!.length / _itemsPerPage).ceil();
    return pages > 0 ? pages : 1;
  }

  int get _filteredLoansCount => _filteredLoans?.length ?? 0;

  Future<void> _saveChanges() async {
    if (_loans == null) return;

    final modifiedLoans = _loans!.where((loan) => loan['isModified'] == true).toList();

    if (modifiedLoans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

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
        final totalOut = double.tryParse(loan['totalOutstandingCtrl'].text) ?? 0;
        final arrears = double.tryParse(loan['arrearsCtrl'].text) ?? 0;
        
        // Get the loan document to retrieve original amounts
        final loanDoc = await _db.collection(AppConstants.loansCol).doc(loan['id']).get();
        final loanData = loanDoc.data() ?? {};
        
        // Get original loan amount and interest
        final loanAmount = (loanData['loanAmount'] ?? loanData['amount'] ?? 0).toDouble();
        final totalInterest = (loanData['interest'] ?? 0).toDouble();
        final waived = (loanData['waived'] ?? 0).toDouble();
        final totalLoan = loanAmount + totalInterest;
        
        // Distribute total outstanding proportionally into principal and interest
        // This maintains backward compatibility with existing loan display logic
        final principalRatio = totalLoan > 0 ? loanAmount / totalLoan : 0.5;
        final interestRatio = totalLoan > 0 ? (totalInterest - waived) / totalLoan : 0.5;
        
        final principalOut = totalOut * principalRatio;
        final interestOut = totalOut * interestRatio;
        
        // Calculate paid amounts: Paid = Original - Outstanding
        final principalPaid = loanAmount - principalOut;
        final interestPaid = (totalInterest - waived) - interestOut;

        final updateData = <String, dynamic>{
          'totalOutstanding': totalOut, // Store the single total
          'principalOutstanding': principalOut > 0 ? principalOut : 0, // Distribute for compatibility
          'interestOutstanding': interestOut > 0 ? interestOut : 0, // Distribute for compatibility
          'arrears': arrears,
          'principalPaid': principalPaid > 0 ? principalPaid : 0,
          'interestPaid': interestPaid > 0 ? interestPaid : 0,
          'correctionDate': Timestamp.fromDate(DateTime(2026, 8, 31)), // Data as of Aug 31, 2026
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (disbDateStr.isNotEmpty) {
          try {
            final disbDate = DateTime.parse(disbDateStr);
            updateData['disbursementDate'] = Timestamp.fromDate(disbDate);
            updateData['disbursedAt'] = Timestamp.fromDate(disbDate);
          } catch (e) {
            debugPrint('Invalid date format for loan ${loan['id']}: $disbDateStr');
          }
        }

        await _db.collection(AppConstants.loansCol).doc(loan['id']).update(updateData);
        successCount++;
      } catch (e) {
        debugPrint('Error updating loan ${loan['id']}: $e');
        failCount++;
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: failCount == 0 ? Colors.green.shade50 : Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    failCount == 0 ? Icons.check_circle : Icons.warning,
                    size: 48,
                    color: failCount == 0 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  failCount == 0 ? 'Success!' : 'Partially Completed',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: failCount == 0 ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  failCount == 0
                      ? 'Successfully updated $successCount loan${successCount > 1 ? 's' : ''}!'
                      : 'Updated $successCount loan${successCount > 1 ? 's' : ''}, $failCount failed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 15, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _loadLoans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScroll.dispose();
    _disposeLoanControllers();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_loans == null || _loans!.isEmpty || _filteredLoans == null)
              ? const Center(child: Text('No loans found'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final useTable = w >= _tableMinWidth;
                    return useTable ? _buildTableLayout(w) : _buildCardLayout(w);
                  },
                ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF1E3A8A),
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loan Data Correction',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
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
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'Save All Changes',
            onPressed: _saveChanges,
          ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Reload',
          onPressed: _loadLoans,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Layouts
  // ---------------------------------------------------------------------------

  /// Wide: fixed header area + table that fills the width (never scrolls sideways).
  Widget _buildTableLayout(double w) {
    return Column(
      children: [
        _searchBar(),
        _countBar(),
        _infoBanner(),
        Expanded(
          child: Container(
            color: Colors.white,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: _buildTable(),
            ),
          ),
        ),
        _pagination(),
      ],
    );
  }

  /// Narrow / medium: everything scrolls together (so small or landscape
  /// screens still have room for the cards), cards in 1 or 2 columns.
  Widget _buildCardLayout(double w) {
    final rows = _getPaginatedLoans();
    final twoCols = w >= _twoColCardsMinWidth;
    const pad = 12.0;
    const gap = 12.0;
    final cardWidth = twoCols ? (w - pad * 2 - gap) / 2 : w - pad * 2;

    return Container(
      color: Colors.white,
      child: CustomScrollView(
        controller: _listScroll,
        slivers: [
          SliverToBoxAdapter(child: _searchBar()),
          SliverToBoxAdapter(child: _countBar()),
          SliverToBoxAdapter(child: _infoBanner()),
          if (rows.isEmpty)
            SliverToBoxAdapter(child: _emptyResults())
          else
            SliverPadding(
              padding: const EdgeInsets.all(pad),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final loan in rows)
                      SizedBox(width: cardWidth, child: _buildLoanCard(loan)),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: _pagination()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared top sections
  // ---------------------------------------------------------------------------
  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by member name or account number...',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                    onPressed: () {
                      _searchController.clear();
                      _filterLoans('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: _filterLoans,
        ),
      ),
    );
  }

  Widget _countBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Showing ${_getPaginatedLoans().length} of $_filteredLoansCount loans',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${_currentPage + 1} of $_totalPages',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.blue.shade50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Update disbursement dates and outstanding balances. Date format: YYYY-MM-DD',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No loans match your search',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _pagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      width: double.infinity,
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              onPressed: _currentPage > 0 ? () => _goToPage(0) : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed:
                  _currentPage < _totalPages - 1 ? () => _goToPage(_currentPage + 1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              onPressed:
                  _currentPage < _totalPages - 1 ? () => _goToPage(_totalPages - 1) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Wide-screen table (fills available width, no horizontal scroll)
  // ---------------------------------------------------------------------------
  Widget _buildTable() {
    final rows = _getPaginatedLoans();
    return Column(
      children: [
        _buildHeaderRow(),
        Expanded(
          child: rows.isEmpty
              ? ListView(children: [_emptyResults()])
              : ListView.separated(
                  controller: _listScroll,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, i) => _buildLoanRow(rows[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    const titles = [
      'Member',
      'Account',
      'Loan Amount',
      'Disbursement Date',
      'Total Outstanding',
      'Arrears',
      'Status',
    ];
    return Container(
      color: const Color(0xFF10B981),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: List.generate(titles.length, (i) {
          return Expanded(
            flex: _flex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                titles[i],
                style: _headerStyle(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoanRow(Map<String, dynamic> loan) {
    final isModified = loan['isModified'] == true;
    Widget cell(int i, Widget child) => Expanded(
          flex: _flex[i],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: child,
          ),
        );

    return Container(
      color: isModified ? const Color(0xFFFFFBEB) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          cell(
            0,
            Text(
              loan['memberName'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          cell(
            1,
            Text(
              loan['accountNumber'],
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2563EB),
              ),
            ),
          ),
          cell(
            2,
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currencyFormat.format(loan['loanAmount'].round()),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
          ),
          cell(3, _dateField(loan)),
          cell(4, _numField(loan, 'totalOutstandingCtrl')),
          cell(5, _numField(loan, 'arrearsCtrl')),
          cell(
            6,
            Align(
              alignment: Alignment.centerLeft,
              child: _statusChip(loan['status']),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card (narrow / medium screens)
  // ---------------------------------------------------------------------------
  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final isModified = loan['isModified'] == true;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isModified ? const Color(0xFFFFFBEB) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    loan['memberName'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calculate, size: 20),
                  color: Colors.blue,
                  tooltip: 'Distribute Total Balance',
                  onPressed: () => _showDistributeBalanceDialog(loan),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Flexible(child: _statusChip(loan['status'])),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    loan['accountNumber'],
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currencyFormat.format(loan['loanAmount'].round()),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _labeled('Disbursement Date', _dateField(loan)),
            const SizedBox(height: 10),
            _labeled('Total Outstanding Balance', _numField(loan, 'totalOutstandingCtrl')),
            const SizedBox(height: 10),
            _labeled('Arrears', _numField(loan, 'arrearsCtrl')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The teller will distribute this total into principal and interest when recording payments',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Two fields side by side; stacks vertically if the card is very narrow.
  Widget _pair(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 260) {
          return Column(children: [a, const SizedBox(height: 10), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      );

  // ---------------------------------------------------------------------------
  // Shared field widgets
  // ---------------------------------------------------------------------------
  Widget _dateField(Map<String, dynamic> loan) {
    final text = loan['disbursementDateCtrl'].text as String;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        DateTime initial = DateTime.now();
        try {
          if (text.isNotEmpty) initial = DateTime.parse(text);
        } catch (_) {}
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text.isEmpty ? 'Pick date' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: text.isEmpty ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.calendar_today, size: 15, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _numField(Map<String, dynamic> loan, String key) {
    return TextField(
      controller: loan[key],
      style: GoogleFonts.inter(fontSize: 12),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() => loan['isModified'] = true),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
      ),
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.inter(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      color: Colors.white,
      letterSpacing: 0.3,
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

  // Distribute Total Outstanding Balance Dialog
  void _showDistributeBalanceDialog(Map<String, dynamic> loan) async {
    final totalBalanceCtrl = TextEditingController();
    final loanAmount = loan['loanAmount'];
    
    // Get original loan data to calculate interest
    final loanDoc = await _db.collection(AppConstants.loansCol).doc(loan['id']).get();
    final loanData = loanDoc.data() ?? {};
    final totalInterest = (loanData['interest'] ?? 0).toDouble();
    final totalLoan = loanAmount + totalInterest;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calculate, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Distribute Outstanding Balance'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member: ${loan['memberName']}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Loan Amount: UGX ${_currencyFormat.format(loanAmount.round())}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Total Interest: UGX ${_currencyFormat.format(totalInterest.round())}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Total Loan: UGX ${_currencyFormat.format(totalLoan.round())}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Enter Total Outstanding Balance:',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: totalBalanceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Outstanding Balance',
                  hintText: 'e.g., 297000',
                  prefixText: 'UGX ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How it works:',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• The system will calculate how much principal and interest remain',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    Text(
                      '• Distribution is proportional to original amounts',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    Text(
                      '• Example: If total is 297K out of 390K, both principal and interest are reduced proportionally',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final totalOutstanding = double.tryParse(totalBalanceCtrl.text) ?? 0;
              if (totalOutstanding <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }

              // Calculate proportional distribution
              // If total loan was 390K (300K principal + 90K interest)
              // and outstanding is 297K, then:
              // - Principal: 300K * (297K / 390K) = 228.46K
              // - Interest: 90K * (297K / 390K) = 68.54K
              
              final principalRatio = loanAmount / totalLoan;
              final interestRatio = totalInterest / totalLoan;
              
              final principalOut = totalOutstanding * principalRatio;
              final interestOut = totalOutstanding * interestRatio;

              // Update the controllers
              loan['principalOutstandingCtrl'].text = principalOut.toStringAsFixed(0);
              loan['interestOutstandingCtrl'].text = interestOut.toStringAsFixed(0);
              loan['isModified'] = true;

              setState(() {});
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Distributed: Principal UGX ${_currencyFormat.format(principalOut.round())} + Interest UGX ${_currencyFormat.format(interestOut.round())}',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Distribute'),
          ),
        ],
      ),
    );
  }
}
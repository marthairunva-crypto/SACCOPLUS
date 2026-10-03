import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../services/loan_disbursement_service.dart';
import '../../services/loan_actions_service.dart';
import '../../services/arrears_service.dart';

class LoanDetailsScreen extends StatefulWidget {
  final String loanId;
  final Map<String, dynamic>? initialLoanData;

  const LoanDetailsScreen({
    Key? key,
    required this.loanId,
    this.initialLoanData,
  }) : super(key: key);

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  late TabController _tabController;
  Map<String, dynamic>? _loanData;
  Map<String, dynamic>? _arrearsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loanData = widget.initialLoanData;
    _loadLoanData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLoanData() async {
    setState(() => _isLoading = true);
    
    // Always fetch fresh data from Firestore
    final doc = await FirebaseFirestore.instance
        .collection(AppConstants.loansCol)
        .doc(widget.loanId)
        .get();
    
    if (doc.exists) {
      _loanData = {'id': doc.id, ...doc.data()!};
    }
    
    // Load arrears data
    final arrearsData = await ArrearsService.calculateLoanArrears(widget.loanId);
    
    setState(() {
      _arrearsData = arrearsData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _loanData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final memberName = _loanData!['memberName'] ?? 'N/A';
    final accountNumber = _loanData!['accountNumber'] ?? 'N/A';
    final status = _loanData!['status'] ?? 'N/A';
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberName,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'A/C: $accountNumber',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Action buttons based on loan status
          if (status == AppConstants.statusApproved)
            IconButton(
              icon: const Icon(Icons.attach_money),
              tooltip: 'Disburse Loan',
              onPressed: _showDisburseLoanDialog,
            ),
          if (status == AppConstants.statusDisbursed || status == 'Active')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'reschedule':
                    _showRescheduleLoanDialog();
                    break;
                  case 'topup':
                    _showTopUpDialog();
                    break;
                  case 'waive':
                    _showWaiveInterestDialog();
                    break;
                  case 'writeoff':
                    _showWriteOffDialog();
                    break;
                  case 'close':
                    _showCloseLoanDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reschedule',
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 20),
                      SizedBox(width: 12),
                      Text('Reschedule Loan'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'topup',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 20),
                      SizedBox(width: 12),
                      Text('Loan Top-Up'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'waive',
                  child: Row(
                    children: [
                      Icon(Icons.money_off, size: 20),
                      SizedBox(width: 12),
                      Text('Waive Interest'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'writeoff',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 20),
                      SizedBox(width: 12),
                      Text('Write Off'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 12),
                      Text('Close Loan'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Transactions'),
            Tab(text: 'Schedule'),
            Tab(text: 'Repayments'),
            Tab(text: 'Charges'),
            Tab(text: 'Guarantors'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildTransactionsTab(),
          _buildScheduleTab(),
          _buildRepaymentsTab(),
          _buildChargesTab(),
          _buildGuarantorsTab(),
          _buildDocumentsTab(),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: SUMMARY - Clean table-based layout
  // ============================================================================
  Widget _buildSummaryTab() {
    final principal = (_loanData!['loanAmount'] ?? _loanData!['amount'] ?? 0).toDouble();
    final interest = (_loanData!['interestAmount'] ?? 0).toDouble();
    final charges = (_loanData!['charges'] ?? 0).toDouble();
    final total = principal + interest + charges;
    
    final principalPaid = (_loanData!['principalPaid'] ?? 0).toDouble();
    final interestPaid = (_loanData!['interestPaid'] ?? 0).toDouble();
    final chargesPaid = (_loanData!['chargesPaid'] ?? 0).toDouble();
    final totalPaid = principalPaid + interestPaid + chargesPaid;
    
    final principalOutstanding = (_loanData!['principalOutstanding'] ?? (principal - principalPaid)).toDouble();
    final interestOutstanding = (_loanData!['interestOutstanding'] ?? (interest - interestPaid)).toDouble();
    final chargesOutstanding = charges - chargesPaid;
    final totalOutstanding = principalOutstanding + interestOutstanding + chargesOutstanding;
    
    // Get arrear balance from multiple sources
    final arrearBalance = (_loanData!['arrears'] ?? _arrearsData?['arrearsAmount'] ?? 0).toDouble();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loan Details - Simple table
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loan Details',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(3),
                    },
                    children: [
                      _buildTableRow('Client/Member Name', _loanData!['memberName'] ?? 'N/A'),
                      _buildTableRow('Member ID', _loanData!['memberId'] ?? 'N/A'),
                      _buildTableRow('Account Number', _loanData!['accountNumber'] ?? 'N/A'),
                      _buildTableRow('Status', _loanData!['status'] ?? 'N/A', valueColor: _getStatusColor(_loanData!['status'])),
                      _buildTableRow('Disbursement Date', _formatDate(_loanData!['disbursementDate'] ?? _loanData!['disbursedAt'])),
                      _buildTableRow('Branch', _loanData!['branch'] ?? 'Main Branch'),
                      _buildTableRow('Loan Amount (UGX)', _currencyFormat.format(principal.round())),
                      _buildTableRow('Nominal Interest Rate', '${_loanData!['interestRate'] ?? 0}% per ${_loanData!['paymentFrequency'] ?? 'month'}'),
                      _buildTableRow('Loan Officer', _loanData!['loanOfficer'] ?? _loanData!['approvedBy'] ?? 'N/A'),
                      _buildTableRow('Tenure', '${_loanData!['duration'] ?? 0} ${_getTenureLabel()}'),
                      _buildTableRow('Loan Type', _loanData!['loanType'] ?? 'N/A'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Additional Info
          if (_loanData!['purpose'] != null || _loanData!['description'] != null)
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Loan Information',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(3),
                      },
                      children: [
                        if (_loanData!['purpose'] != null)
                          _buildTableRow('Purpose', _loanData!['purpose'] ?? 'N/A'),
                        _buildTableRow('Description', _loanData!['description'] ?? 'N/A'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Balance Summary - Clean Table
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Balance Summary',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Clean data table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                      headingTextStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      dataTextStyle: GoogleFonts.inter(fontSize: 13),
                      columns: const [
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Principal (USh)'), numeric: true),
                        DataColumn(label: Text('Interest (USh)'), numeric: true),
                        DataColumn(label: Text('Charges (USh)'), numeric: true),
                        DataColumn(label: Text('Total (USh)'), numeric: true),
                      ],
                      rows: [
                        _buildDataRow('Total', principal, interest, charges, total, null),
                        _buildDataRow('Waived Off', 0, 0, 0, 0, Colors.orange.shade50),
                        _buildDataRow('Paid', principalPaid, interestPaid, chargesPaid, totalPaid, Colors.green.shade50),
                        _buildDataRow('Outstanding', principalOutstanding, interestOutstanding, chargesOutstanding, totalOutstanding, Colors.red.shade50, bold: true),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Arrear Balance
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Arrear Balance',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'UGX ${_currencyFormat.format(arrearBalance.round())}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Disbursement Details
          if (_loanData!['disbursedAt'] != null || _loanData!['disbursementDate'] != null)
            Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disbursement Details',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(3),
                      },
                      children: [
                        _buildTableRow('Destination Type', _loanData!['destinationType'] ?? 'Cash'),
                        _buildTableRow('Reference Number', _loanData!['referenceNumber'] ?? 'N/A'),
                        _buildTableRow('Disbursed By', _loanData!['disbursedBy'] ?? 'N/A'),
                        _buildTableRow('Disbursement Date', _formatDate(_loanData!['disbursedAt'] ?? _loanData!['disbursementDate'])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value, {Color? valueColor}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildDataRow(String category, double principal, double interest, double charges, double total, Color? color, {bool bold = false}) {
    final textStyle = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    
    return DataRow(
      color: color != null ? MaterialStateProperty.all(color) : null,
      cells: [
        DataCell(Text(category, style: textStyle)),
        DataCell(Text(_currencyFormat.format(principal.round()), style: textStyle)),
        DataCell(Text(_currencyFormat.format(interest.round()), style: textStyle)),
        DataCell(Text(_currencyFormat.format(charges.round()), style: textStyle)),
        DataCell(Text(_currencyFormat.format(total.round()), style: textStyle)),
      ],
    );
  }

  // ============================================================================
  // TAB 2: TRANSACTIONS
  // ============================================================================
  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loan_repayments')
          .where('loanId', isEqualTo: widget.loanId)
          .orderBy('paymentDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No transactions recorded'),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final txn = doc.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.payment, color: Colors.green.shade700),
                ),
                title: Text(
                  'Payment - UGX ${_currencyFormat.format((txn['amount'] ?? 0))}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_formatDate(txn['paymentDate'])),
                trailing: Text(
                  txn['paymentMethod'] ?? 'Cash',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // TAB 3: SCHEDULE
  // ============================================================================
  Widget _buildScheduleTab() {
    return Center(
      child: Text('Loan Schedule - Coming Soon'),
    );
  }

  // ============================================================================
  // TAB 4: REPAYMENTS
  // ============================================================================
  Widget _buildRepaymentsTab() {
    return _buildTransactionsTab(); // Same as transactions for now
  }

  // ============================================================================
  // TAB 5: CHARGES
  // ============================================================================
  Widget _buildChargesTab() {
    return Center(
      child: Text('Charges - Coming Soon'),
    );
  }

  // ============================================================================
  // TAB 6: GUARANTORS
  // ============================================================================
  Widget _buildGuarantorsTab() {
    final guarantors = _loanData!['guarantors'] as List? ?? [];
    
    if (guarantors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No guarantors added'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: guarantors.length,
      itemBuilder: (context, index) {
        final guarantor = guarantors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              child: Text('${index + 1}'),
            ),
            title: Text(guarantor['name'] ?? 'N/A'),
            subtitle: Text('A/C: ${guarantor['account'] ?? 'N/A'}'),
            trailing: Text(
              'UGX ${_currencyFormat.format((guarantor['savings'] ?? 0))}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 7: DOCUMENTS
  // ============================================================================
  Widget _buildDocumentsTab() {
    return Center(
      child: Text('Documents - Coming Soon'),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.blue;
      case 'disbursed':
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'paid':
      case 'closed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(date.toDate());
    }
    return 'N/A';
  }

  String _getTenureLabel() {
    final frequency = _loanData!['paymentFrequency'] ?? 'monthly';
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 'Days';
      case 'weekly':
        return 'Weeks';
      case 'monthly':
      default:
        return 'Months';
    }
  }

  // ============================================================================
  // DIALOGS - Loan Actions
  // ============================================================================
  
  Future<void> _showDisburseLoanDialog() async {
    final TextEditingController amountCtrl = TextEditingController(
      text: (_loanData!['loanAmount'] ?? _loanData!['amount'] ?? 0).toString()
    );
    final TextEditingController referenceCtrl = TextEditingController();
    final TextEditingController chequeCtrl = TextEditingController();
    final TextEditingController narrationCtrl = TextEditingController(
      text: 'Loan disbursement for ${_loanData!['memberName']}'
    );
    
    String destinationType = 'cash';
    
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.attach_money, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text('Disburse Loan'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loanData!['memberName'] ?? 'N/A',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'A/C: ${_loanData!['accountNumber']} • Ref: ${_loanData!['referenceNumber']}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Destination Type
                  Text(
                    'Destination Type *',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: destinationType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => destinationType = value);
                      }
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Amount
                  Text(
                    'Amount (UGX) *',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    readOnly: true,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reference Number
                  Text(
                    'Reference Number',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: referenceCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      hintText: 'Receipt/transaction number',
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cheque Number (if bank)
                  if (destinationType == 'bank') ...[
                    Text(
                      'Cheque Number',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: chequeCtrl,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        hintText: 'Cheque number',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Narration
                  Text(
                    'Narration / Description',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: narrationCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                amountCtrl.dispose();
                referenceCtrl.dispose();
                chequeCtrl.dispose();
                narrationCtrl.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid amount')),
                  );
                  return;
                }
                
                Navigator.pop(dialogContext);
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(child: CircularProgressIndicator()),
                );
                
                // Disburse loan
                final result = await LoanDisbursementService.disburseLoan(
                  loanId: widget.loanId,
                  destinationType: destinationType,
                  disbursedBy: 'CURRENT_USER_ID', // TODO: Get from auth
                  amount: amount,
                  referenceNumber: referenceCtrl.text.trim(),
                  chequeNumber: chequeCtrl.text.trim(),
                  narration: narrationCtrl.text.trim(),
                );
                
                // Close loading
                if (mounted) Navigator.pop(context);
                
                // Dispose controllers
                amountCtrl.dispose();
                referenceCtrl.dispose();
                chequeCtrl.dispose();
                narrationCtrl.dispose();
                
                // Show result
                if (result['success'] == true) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Loan disbursed successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadLoanData(); // Reload data
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Failed to disburse loan'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              icon: const Icon(Icons.check),
              label: const Text('Disburse'),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder methods for other actions
  Future<void> _showRescheduleLoanDialog() async {
    final TextEditingController durationCtrl = TextEditingController(
      text: (_loanData!['duration'] ?? 12).toString()
    );
    final TextEditingController reasonCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Reschedule Loan'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Duration: ${_loanData!['duration']} months',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  'New Duration (months) *',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Enter new duration in months',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Why is this loan being rescheduled?',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              durationCtrl.dispose();
              reasonCtrl.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final newDuration = int.tryParse(durationCtrl.text) ?? 0;
              
              if (newDuration <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid duration')),
                );
                return;
              }
              
              Navigator.pop(dialogContext);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );
              
              final result = await LoanActionsService.rescheduleLoan(
                loanId: widget.loanId,
                newDuration: newDuration,
                rescheduledBy: 'CURRENT_USER_ID',
                reason: reasonCtrl.text.trim(),
              );
              
              if (mounted) Navigator.pop(context);
              
              durationCtrl.dispose();
              reasonCtrl.dispose();
              
              if (result['success'] == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Loan rescheduled'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadLoanData();
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            icon: const Icon(Icons.check),
            label: const Text('Reschedule'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTopUpDialog() async {
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController reasonCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.arrow_upward, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Loan Top-Up'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Loan Amount: UGX ${_currencyFormat.format((_loanData!['loanAmount'] ?? 0))}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  'Top-Up Amount (UGX) *',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Enter additional amount',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Reason for top-up',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              amountCtrl.dispose();
              reasonCtrl.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid amount')),
                );
                return;
              }
              
              Navigator.pop(dialogContext);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );
              
              final result = await LoanActionsService.topUpLoan(
                loanId: widget.loanId,
                topUpAmount: amount,
                approvedBy: 'CURRENT_USER_ID',
                reason: reasonCtrl.text.trim(),
              );
              
              if (mounted) Navigator.pop(context);
              
              amountCtrl.dispose();
              reasonCtrl.dispose();
              
              if (result['success'] == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Loan topped up'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadLoanData();
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            icon: const Icon(Icons.check),
            label: const Text('Top Up'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWaiveInterestDialog() async {
    final interestOutstanding = (_loanData!['interestOutstanding'] ?? 0).toDouble();
    final TextEditingController amountCtrl = TextEditingController(
      text: interestOutstanding.round().toString()
    );
    final TextEditingController reasonCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.money_off, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Waive Interest'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding Interest: UGX ${_currencyFormat.format(interestOutstanding.round())}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Text(
                  'Waive Amount (UGX) *',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Enter amount to waive',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason *',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Why is interest being waived?',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              amountCtrl.dispose();
              reasonCtrl.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid amount')),
                );
                return;
              }
              
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason is required')),
                );
                return;
              }
              
              Navigator.pop(dialogContext);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );
              
              final result = await LoanActionsService.waiveInterest(
                loanId: widget.loanId,
                waiveAmount: amount,
                waivedBy: 'CURRENT_USER_ID',
                reason: reasonCtrl.text.trim(),
              );
              
              if (mounted) Navigator.pop(context);
              
              amountCtrl.dispose();
              reasonCtrl.dispose();
              
              if (result['success'] == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Interest waived'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadLoanData();
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
            icon: const Icon(Icons.check),
            label: const Text('Waive'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWriteOffDialog() async {
    final TextEditingController reasonCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Write Off Loan'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    '⚠️ Warning: This will mark the loan as uncollectable bad debt. This action cannot be undone.',
                    style: GoogleFonts.inter(color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reason *',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Explain why this loan is being written off',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              reasonCtrl.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reason is required')),
                );
                return;
              }
              
              Navigator.pop(dialogContext);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );
              
              final result = await LoanActionsService.writeOffLoan(
                loanId: widget.loanId,
                writtenOffBy: 'CURRENT_USER_ID',
                reason: reasonCtrl.text.trim(),
              );
              
              if (mounted) Navigator.pop(context);
              
              reasonCtrl.dispose();
              
              if (result['success'] == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Loan written off'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context); // Close details screen
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            icon: const Icon(Icons.warning),
            label: const Text('Write Off'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCloseLoanDialog() async {
    final TextEditingController reasonCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            const Text('Close Loan'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Why is this loan being closed?',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              reasonCtrl.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );
              
              final result = await LoanActionsService.closeLoan(
                loanId: widget.loanId,
                closedBy: 'CURRENT_USER_ID',
                reason: reasonCtrl.text.trim(),
              );
              
              if (mounted) Navigator.pop(context);
              
              reasonCtrl.dispose();
              
              if (result['success'] == true) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Loan closed'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadLoanData();
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
            icon: const Icon(Icons.check),
            label: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

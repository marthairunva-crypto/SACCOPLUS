import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/arrears_service.dart';
import 'loan_details_screen.dart';

class ArrearsManagementScreen extends StatefulWidget {
  const ArrearsManagementScreen({Key? key}) : super(key: key);

  @override
  State<ArrearsManagementScreen> createState() => _ArrearsManagementScreenState();
}

class _ArrearsManagementScreenState extends State<ArrearsManagementScreen> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  bool _isLoading = false;
  bool _isUpdating = false;
  List<Map<String, dynamic>> _loansWithArrears = [];

  @override
  void initState() {
    super.initState();
    _loadLoansWithArrears();
  }

  Future<void> _loadLoansWithArrears() async {
    setState(() => _isLoading = true);
    final loans = await ArrearsService.getLoansWithArrears();
    setState(() {
      _loansWithArrears = loans;
      _isLoading = false;
    });
  }

  Future<void> _updateAllArrears() async {
    setState(() => _isUpdating = true);
    
    final result = await ArrearsService.updateAllLoansArrears();
    
    setState(() => _isUpdating = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated ${result['success']} loans. Failed: ${result['failed']}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload the list
      _loadLoansWithArrears();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Arrears Management',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red.shade700,
        actions: [
          if (_isUpdating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _updateAllArrears,
              icon: const Icon(Icons.refresh),
              tooltip: 'Update All Arrears',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loansWithArrears.isEmpty
              ? _buildEmptyState()
              : _buildLoansList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
          const SizedBox(height: 16),
          Text(
            'No Loans in Arrears',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All loans are up to date!',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadLoansWithArrears,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansList() {
    // Calculate totals
    double totalArrears = 0;
    double totalPenalties = 0;
    
    for (var loan in _loansWithArrears) {
      totalArrears += (loan['arrears'] ?? 0).toDouble();
      totalPenalties += (loan['penalties'] ?? 0).toDouble();
    }

    return Column(
      children: [
        // Summary Cards
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Arrears',
                  'UGX ${_currencyFormat.format(totalArrears.round())}',
                  Icons.money_off,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Penalties',
                  'UGX ${_currencyFormat.format(totalPenalties.round())}',
                  Icons.warning,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Affected Loans',
                  '${_loansWithArrears.length}',
                  Icons.account_balance_wallet,
                  Colors.deepOrange,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Loans List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _loansWithArrears.length,
            itemBuilder: (context, index) {
              return _buildLoanCard(_loansWithArrears[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final memberName = loan['memberName'] ?? 'N/A';
    final accountNumber = loan['accountNumber'] ?? 'N/A';
    final referenceNumber = loan['referenceNumber'] ?? 'N/A';
    final arrears = (loan['arrears'] ?? 0).toDouble();
    final penalties = (loan['penalties'] ?? 0).toDouble();
    final monthsOverdue = loan['monthsOverdue'] ?? 0;
    final totalDue = (loan['totalDue'] ?? 0).toDouble();
    final phoneNumber = loan['phoneNumber'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LoanDetailsScreen(
                loanId: loan['loanId'],
                initialLoanData: loan,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.red.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memberName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'A/C: $accountNumber • Ref: $referenceNumber',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$monthsOverdue MO',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              // Financial Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailChip(
                      'Arrears',
                      'UGX ${_currencyFormat.format(arrears.round())}',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailChip(
                      'Penalties',
                      'UGX ${_currencyFormat.format(penalties.round())}',
                      Colors.red,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL DUE:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'UGX ${_currencyFormat.format(totalDue.round())}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (phoneNumber.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      phoneNumber,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

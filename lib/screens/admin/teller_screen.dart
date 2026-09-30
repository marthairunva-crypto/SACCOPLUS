import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/teller_service.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';

class TellerScreen extends StatefulWidget {
  final bool embedded;
  const TellerScreen({super.key, this.embedded = false});

  @override
  State<TellerScreen> createState() => _TellerScreenState();
}

class _TellerScreenState extends State<TellerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fmt = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Teller Operations', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: ModernTheme.primary,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.person_search), text: 'Member Lookup'),
            Tab(icon: Icon(Icons.account_balance), text: 'Bank Transfer'),
            Tab(icon: Icon(Icons.history), text: 'Transactions'),
            Tab(icon: Icon(Icons.analytics), text: 'Daily Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MemberLookupTab(fmt: _fmt),
          _BankTransferTab(fmt: _fmt),
          _TransactionHistoryTab(fmt: _fmt),
          _DailySummaryTab(fmt: _fmt),
        ],
      ),
    );
  }
}

// ─── Member Lookup Tab ────────────────────────────────────────────────────────
class _MemberLookupTab extends StatefulWidget {
  final NumberFormat fmt;
  const _MemberLookupTab({required this.fmt});

  @override
  State<_MemberLookupTab> createState() => _MemberLookupTabState();
}

class _MemberLookupTabState extends State<_MemberLookupTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedMember;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMembers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);
    final results = await TellerService.searchMembers(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  Future<void> _selectMember(String memberId) async {
    final member = await TellerService.getMemberDetails(memberId);
    if (mounted && member != null) {
      setState(() => _selectedMember = member);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build with AutomaticKeepAliveClientMixin
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Search Member',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),

        // Search field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Enter phone number or name',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _searchMembers,
        ),
        const SizedBox(height: 20),

        // Search results
        if (_searchResults.isNotEmpty) ...[
          Text(
            'Search Results (${_searchResults.length})',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._searchResults.map((member) {
            return GestureDetector(
              onTap: () => _selectMember(member['id']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: ModernTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: ModernTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['name'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            member['phone'],
                            style: GoogleFonts.poppins(fontSize: 13, color: ModernTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2, end: 0);
          }).toList(),
        ],

        // Selected member details
        if (_selectedMember != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Member Details',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selectedMember = null),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

                _buildDetailRow('Name', _selectedMember!['name']),
                _buildDetailRow('Phone', _selectedMember!['phone']),
                if (_selectedMember!['email'].isNotEmpty)
                  _buildDetailRow('Email', _selectedMember!['email']),
                
                const SizedBox(height: 16),
                Text(
                  'Account Balances',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                        'Wallet',
                        'UGX ${widget.fmt.format(_selectedMember!['walletBalance'])}',
                        Icons.account_balance_wallet,
                        ModernTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceCard(
                        'Savings',
                        'UGX ${widget.fmt.format(_selectedMember!['savingsBalance'])}',
                        Icons.savings,
                        ModernTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBalanceCard(
                  'Shares (${_selectedMember!['sharesCount']} shares)',
                  'UGX ${widget.fmt.format(_selectedMember!['sharesValue'])}',
                  Icons.pie_chart,
                  ModernTheme.accent,
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTransactionDialog('deposit'),
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Deposit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModernTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showTransactionDialog('withdrawal'),
                        icon: const Icon(Icons.remove_circle),
                        label: const Text('Withdrawal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ModernTheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ModernTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ModernTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(String type) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String accountType = 'wallet';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            type == 'deposit' ? 'Process Deposit' : 'Process Withdrawal',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member: ${_selectedMember!['name']}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),

                Text('Account Type', style: GoogleFonts.poppins(fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: accountType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                    const DropdownMenuItem(value: 'savings', child: Text('Savings')),
                    if (type == 'deposit') ...[
                      const DropdownMenuItem(value: 'shares', child: Text('Shares')),
                      const DropdownMenuItem(value: 'fixed_deposit', child: Text('Fixed Deposit')),
                      const DropdownMenuItem(value: 'loan_payment', child: Text('Loan Payment')),
                    ],
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => accountType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                Text('Amount (UGX)', style: GoogleFonts.poppins(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Notes (Optional)', style: GoogleFonts.poppins(fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add notes',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
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
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a valid amount', style: GoogleFonts.poppins()),
                      backgroundColor: ModernTheme.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                _processTransaction(type, accountType, amount, notesController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'deposit' ? ModernTheme.success : ModernTheme.error,
              ),
              child: Text(type == 'deposit' ? 'Deposit' : 'Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processTransaction(String type, String accountType, int amount, String notes) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Processing...', style: GoogleFonts.poppins()),
          ],
        ),
      ),
    );

    try {
      final result = type == 'deposit'
          ? await TellerService.processDeposit(
              memberId: _selectedMember!['id'],
              memberName: _selectedMember!['name'],
              memberPhone: _selectedMember!['phone'],
              amount: amount,
              accountType: accountType,
              tellerName: FirebaseService.sessionProfile?['name'] ?? 'Admin',
              tellerId: FirebaseService.sessionUid,
              notes: notes,
            )
          : await TellerService.processWithdrawal(
              memberId: _selectedMember!['id'],
              memberName: _selectedMember!['name'],
              memberPhone: _selectedMember!['phone'],
              amount: amount,
              accountType: accountType,
              tellerName: FirebaseService.sessionProfile?['name'] ?? 'Admin',
              tellerId: FirebaseService.sessionUid,
              notes: notes,
            );

      Navigator.pop(context); // Close loading

      if (result['success']) {
        // Show receipt
        _showReceipt(result['transaction']);
        // Refresh member details
        _selectMember(_selectedMember!['id']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'], style: GoogleFonts.poppins()),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}', style: GoogleFonts.poppins()),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  void _showReceipt(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: ModernTheme.success,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Transaction Successful',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReceiptRow('Receipt No.', transaction['receiptNumber']),
              _buildReceiptRow('Type', transaction['type'].toString().toUpperCase()),
              _buildReceiptRow('Member', transaction['memberName']),
              _buildReceiptRow('Account', transaction['accountType'].toString().toUpperCase()),
              _buildReceiptRow('Amount', 'UGX ${widget.fmt.format(transaction['amount'])}'),
              _buildReceiptRow('Teller', transaction['tellerName']),
              _buildReceiptRow(
                'Date & Time',
                DateFormat('dd/MM/yyyy HH:mm').format(transaction['timestamp']),
              ),
              if (transaction['notes']?.isNotEmpty ?? false)
                _buildReceiptRow('Notes', transaction['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: ModernTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction History Tab ──────────────────────────────────────────────────
class _TransactionHistoryTab extends StatefulWidget {
  final NumberFormat fmt;
  const _TransactionHistoryTab({required this.fmt});

  @override
  State<_TransactionHistoryTab> createState() => _TransactionHistoryTabState();
}

class _TransactionHistoryTabState extends State<_TransactionHistoryTab> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    
    // Debug: Check what transactions exist
    print('🔍 TELLER: Loading transactions for tellerId: ${FirebaseService.sessionUid}');
    
    final transactions = await TellerService.getTransactionHistory(
      // Don't filter by teller - show ALL transactions
      // tellerId: FirebaseService.sessionUid,
      limit: 100,
    );
    
    print('🔍 TELLER: Found ${transactions.length} transactions');
    if (transactions.isNotEmpty) {
      print('🔍 TELLER: First transaction: ${transactions[0]}');
    }
    
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Transaction History',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  'No transactions yet',
                  style: GoogleFonts.poppins(color: ModernTheme.textSecondary),
                ),
              ),
            )
          else
            ..._transactions.map((txn) {
              final isDeposit = txn['type'] == 'deposit';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: (isDeposit ? ModernTheme.success : ModernTheme.error).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDeposit ? Icons.add_circle : Icons.remove_circle,
                        color: isDeposit ? ModernTheme.success : ModernTheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn['memberName'],
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${txn['accountType'].toString().toUpperCase()} • ${txn['receiptNumber']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(txn['timestamp']),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isDeposit ? '+' : '-'} UGX ${widget.fmt.format(txn['amount'])}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDeposit ? ModernTheme.success : ModernTheme.error,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2, end: 0);
            }).toList(),
        ],
      ),
    );
  }
}

// ─── Daily Summary Tab ────────────────────────────────────────────────────────
class _DailySummaryTab extends StatefulWidget {
  final NumberFormat fmt;
  const _DailySummaryTab({required this.fmt});

  @override
  State<_DailySummaryTab> createState() => _DailySummaryTabState();
}

class _DailySummaryTabState extends State<_DailySummaryTab> {
  Map<String, dynamic>? _summary;
  bool _loading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    
    print('🔍 TELLER SUMMARY: Loading for date: $_selectedDate, teller: ${FirebaseService.sessionUid}');
    
    final summary = await TellerService.getDailySummary(
      // Show ALL transactions for the day, not just this teller's
      // tellerId: FirebaseService.sessionUid,
      date: _selectedDate,
    );
    
    print('🔍 TELLER SUMMARY: ${summary}');
    
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Daily Summary',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  _loadSummary();
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_summary != null) ...[
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _summary!['netCashFlow'] >= 0
                  ? ModernTheme.success.withOpacity(0.1)
                  : ModernTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _summary!['netCashFlow'] >= 0 ? ModernTheme.success : ModernTheme.error,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Net Cash Flow',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'UGX ${widget.fmt.format(_summary!['netCashFlow'])}',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: _summary!['netCashFlow'] >= 0 ? ModernTheme.success : ModernTheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSummaryCard(
            'Deposits',
            '${_summary!['deposits']['count']}',
            'UGX ${widget.fmt.format(_summary!['deposits']['amount'])}',
            Icons.add_circle,
            ModernTheme.success,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Withdrawals',
            '${_summary!['withdrawals']['count']}',
            'UGX ${widget.fmt.format(_summary!['withdrawals']['amount'])}',
            Icons.remove_circle,
            ModernTheme.error,
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            'Total Transactions',
            '${_summary!['totalTransactions']}',
            '',
            Icons.receipt_long,
            ModernTheme.info,
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(String title, String count, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 14, color: ModernTheme.textSecondary),
                ),
                if (amount.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
                Text(
                  '$count transactions',
                  style: GoogleFonts.poppins(fontSize: 12, color: ModernTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0);
  }
}


// ─── Bank Transfer Tab ────────────────────────────────────────────────────────
class _BankTransferTab extends StatefulWidget {
  final NumberFormat fmt;
  const _BankTransferTab({required this.fmt});

  @override
  State<_BankTransferTab> createState() => _BankTransferTabState();
}

class _BankTransferTabState extends State<_BankTransferTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _narrationController = TextEditingController();
  
  String? _selectedBank;
  List<Map<String, dynamic>> _banks = [];
  bool _loadingBanks = true;
  bool _verifying = false;
  bool _processing = false;
  Map<String, dynamic>? _verifiedAccount;
  String? _saccoAccountNumber;
  String? _saccoAccountName;
  String? _saccoBankName;
  String? _saccoBankBranch;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _loadSaccoBankSettings();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _loadingBanks = true);
    try {
      print('🏦 Loading banks from API via FirebaseService...');
      // Use FirebaseService.getBankList() like farmer screen does
      final banks = await FirebaseService.getBankList();
      print('🏦 Loaded ${banks.length} banks');
      
      setState(() {
        _banks = banks;
        _loadingBanks = false;
      });
    } catch (e) {
      print('❌ Error loading banks: $e');
      if (mounted) {
        setState(() => _loadingBanks = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading banks: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadSaccoBankSettings() async {
    try {
      final settings = await FirebaseFirestore.instance
          .collection('saccoplus-settings')
          .doc(FirebaseService.sessionTenantId)
          .get();
      
      if (settings.exists) {
        final data = settings.data();
        setState(() {
          _saccoAccountNumber = data?['bankAccountNumber'] as String?;
          _saccoAccountName = data?['bankAccountName'] as String?;
          _saccoBankName = data?['bankName'] as String?;
          _saccoBankBranch = data?['bankBranch'] as String?;
        });
      }
    } catch (e) {
      print('Error loading SACCO bank settings: $e');
    }
  }

  Future<void> _verifyAccount() async {
    if (_selectedBank == null || _accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select bank and enter account number')),
      );
      return;
    }

    setState(() {
      _verifying = true;
      _verifiedAccount = null;
    });

    try {
      // Use FirebaseService.validateBankAccount() like farmer screen does
      final bankName = _banks.firstWhere((b) => b['code'] == _selectedBank)['name'];
      final result = await FirebaseService.validateBankAccount(
        bankName: bankName,
        accountNumber: _accountNumberController.text.trim(),
      );

      print('🔍 Verification result: $result');

      if (result['valid'] == true && (result['account_name'] as String? ?? '').isNotEmpty) {
        setState(() {
          _verifiedAccount = result;
          _verifying = false;
        });
        
        if (mounted) {
          // Show centered dialog for success
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Account Verified',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Text(
                result['account_name'],
                style: GoogleFonts.poppins(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: ModernTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Could not verify account name');
      }
    } catch (e) {
      print('❌ Verification error: $e');
      if (mounted) {
        setState(() => _verifying = false);
        
        // Simple user-friendly error message
        String errorMessage = 'Could not verify account';
        
        if (e.toString().toLowerCase().contains('invalid')) {
          errorMessage = 'Invalid account number';
        } else if (e.toString().toLowerCase().contains('timeout')) {
          errorMessage = 'Request timed out';
        } else if (e.toString().toLowerCase().contains('network')) {
          errorMessage = 'Network error';
        }
        
        // Show centered dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Verification Failed',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _processTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify account first')),
      );
      return;
    }

    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: UGX ${widget.fmt.format(int.parse(_amountController.text))}'),
            const SizedBox(height: 8),
            Text('To: ${_verifiedAccount!['account_name']}'),
            Text('Account: ${_accountNumberController.text}'),
            Text('Bank: ${_banks.firstWhere((b) => b['code'] == _selectedBank)['name']}'),
            const SizedBox(height: 12),
            const Text('This will transfer money from SACCOPLUS to the member\'s bank account.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.primary),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processing = true);

    try {
      final amount = int.parse(_amountController.text);
      final bank = _banks.firstWhere((b) => b['code'] == _selectedBank);
      
      // Use FirebaseService.createBankTransfer() like farmer screen does
      final result = await FirebaseService.createBankTransfer(
        amount: amount,
        description: _narrationController.text.trim().isEmpty 
            ? 'Bank transfer to ${_verifiedAccount!['account_name']}'
            : _narrationController.text.trim(),
        bankName: bank['name'],
        bankAccountNumber: _accountNumberController.text.trim(),
        bankAccountName: _verifiedAccount!['account_name'],
        walletSource: 'main', // Transfer from SACCO main wallet
      );

      if (!mounted) return;

      if (result['success'] == true || result['status'] == 'success') {
        final reference = result['reference'] ?? result['transaction_uuid'] ?? 'N/A';
        
        // Show centered dialog for success
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Transfer Successful',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              'Reference: $reference',
              style: GoogleFonts.poppins(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );

        // Clear form
        _formKey.currentState!.reset();
        _amountController.clear();
        _accountNumberController.clear();
        _narrationController.clear();
        setState(() {
          _selectedBank = null;
          _verifiedAccount = null;
        });
      } else {
        throw Exception(result['message'] ?? 'Transfer failed');
      }
    } catch (e) {
      if (mounted) {
        // Simple user-friendly error message
        String errorMessage = 'Transfer could not be completed';
        
        if (e.toString().toLowerCase().contains('insufficient')) {
          errorMessage = 'Insufficient balance';
        } else if (e.toString().toLowerCase().contains('timeout')) {
          errorMessage = 'Request timed out';
        } else if (e.toString().toLowerCase().contains('network')) {
          errorMessage = 'Network error';
        }
        
        // Show centered dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Transfer Failed',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: ModernTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SACCO Bank Info Card
            if (_saccoAccountNumber != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'SACCOPLUS Bank Account',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _saccoBankName ?? 'Bank not set',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      'Account: $_saccoAccountNumber',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _saccoAccountName ?? '',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                    ),
                    if (_saccoBankBranch != null)
                      Text(
                        'Branch: $_saccoBankBranch',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),

            Text(
              'Transfer to Member Bank Account',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Send money from SACCOPLUS to member\'s bank account',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Bank Selection
            if (_loadingBanks)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<String>(
                value: _selectedBank,
                decoration: InputDecoration(
                  labelText: 'Select Bank',
                  prefixIcon: const Icon(Icons.account_balance),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _banks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank['code'] as String,
                    child: Text(bank['name'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value;
                    _verifiedAccount = null;
                  });
                },
                validator: (v) => v == null ? 'Please select a bank' : null,
              ),
            const SizedBox(height: 16),

            // Account Number + Verify Button (like farmer screen)
            Text(
              'Account Number',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _accountNumberController,
                    decoration: InputDecoration(
                      hintText: 'Enter account number',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.isEmpty ? 'Enter account number' : null,
                    onChanged: (v) {
                      if (_verifiedAccount != null) {
                        setState(() => _verifiedAccount = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _verifying ? null : _verifyAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verifiedAccount != null
                        ? Colors.green
                        : ModernTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _verifiedAccount != null ? 'Verified' : 'Verify',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
            if (_verifiedAccount != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _verifiedAccount!['account_name'],
                        style: GoogleFonts.poppins(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (UGX)',
                prefixIcon: const Icon(Icons.money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                final amount = int.tryParse(v);
                if (amount == null || amount <= 0) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Narration
            TextFormField(
              controller: _narrationController,
              decoration: InputDecoration(
                labelText: 'Narration (Optional)',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                hintText: 'e.g., Loan disbursement, Savings withdrawal',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Transfer Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _processing || _verifiedAccount == null ? null : _processTransfer,
                icon: _processing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _processing ? 'Processing...' : 'Transfer Money',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bank transfers are processed securely. Always verify the account before transferring.',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900),
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
}

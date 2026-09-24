import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';

class Member360Screen extends StatefulWidget {
  final String? memberId;
  
  Member360Screen({super.key, this.memberId});

  @override
  State<Member360Screen> createState() => _Member360ScreenState();
}

class _Member360ScreenState extends State<Member360Screen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedMemberId;
  Map<String, dynamic>? _memberData;
  bool _isLoading = false;
  List<Map<String, dynamic>> _members = [];
  
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _selectedMemberId = widget.memberId;
    _loadMembers();
    if (_selectedMemberId != null) {
      _loadMemberData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      print('🔍 Loading members for tenantId: ${FirebaseService.sessionTenantId}');
      
      // Use FirebaseService.getAllFarmersOnce() instead of direct query
      final members = await FirebaseService.getAllFarmersOnce();
      
      print('📥 Loaded ${members.length} members from Firebase');
      
      setState(() {
        _members = members;
        // Sort in memory
        _members.sort((a, b) => (a['name'] ?? a['fullName'] ?? '').toString().compareTo((b['name'] ?? b['fullName'] ?? '').toString()));
      });
    } catch (e) {
      print('❌ Error loading members: $e');
    }
  }

  Future<void> _loadMemberData() async {
    if (_selectedMemberId == null) return;
    
    print('🔍 Loading member data for ID: $_selectedMemberId');
    setState(() => _isLoading = true);
    
    try {
      // Load member profile
      final memberDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedMemberId)
          .get();
      
      print('📥 Member doc exists: ${memberDoc.exists}');
      
      if (!memberDoc.exists) {
        print('❌ Member not found!');
        setState(() => _isLoading = false);
        return;
      }
      
      final data = memberDoc.data()!;
      print('✅ Member loaded: ${data['name'] ?? data['fullName']}');
      
      setState(() {
        _memberData = {'id': memberDoc.id, ...data};
        _isLoading = false;
      });
      
      print('✅ State updated, _memberData is ${_memberData != null ? 'SET' : 'NULL'}');
    } catch (e) {
      print('❌ Error loading member: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading member: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Member 360° View', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_memberData != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadMemberData,
            ),
        ],
      ),
      body: Column(
        children: [
          // Member selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildMemberSelector(),
          ),
          
          if (_memberData != null) ...[
            // Member header card
            _buildMemberHeader(),
            
            // Tabs
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: ModernTheme.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                indicatorColor: ModernTheme.primary,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Savings'),
                  Tab(text: 'Shares'),
                  Tab(text: 'Loans'),
                  Tab(text: 'Transactions'),
                  Tab(text: 'Documents'),
                ],
              ),
            ),
            
            // Tab content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildSavingsTab(),
                        _buildSharesTab(),
                        _buildLoansTab(),
                        _buildTransactionsTab(),
                        _buildDocumentsTab(),
                      ],
                    ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_rounded, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Select a member to view details',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Member',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMemberId,
              hint: Text('Select a member...', style: GoogleFonts.poppins(color: Colors.grey.shade600)),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: _members.where((member) => member['id'] != null).map((member) {
                return DropdownMenuItem<String>(
                  value: member['id'] as String,
                  child: Text(
                    member['name'] ?? member['fullName'] ?? 'Unknown',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (String? memberId) {
                if (memberId != null) {
                  setState(() {
                    _selectedMemberId = memberId;
                    _memberData = null;
                  });
                  _loadMemberData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2C5282)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _memberData!['name'].toString()[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _memberData!['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member ID: ${_memberData!['id']}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildHeaderChip(Icons.phone, _memberData!['phone']),
                    const SizedBox(width: 12),
                    _buildHeaderChip(
                      Icons.calendar_today,
                      'Joined ${_formatDate(_memberData!['createdAt'])}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _memberData!['status'] == 'active'
                  ? Colors.green
                  : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (_memberData!['status'] ?? 'active').toString().toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial Summary
          _buildSectionTitle('Financial Summary'),
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Total Savings', '2,450,000', Icons.savings, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('Total Shares', '1,500,000', Icons.pie_chart, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Active Loans', '5,000,000', Icons.account_balance, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('Total Deposits', '500,000', Icons.account_balance_wallet, Colors.purple)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Personal Information
          _buildSectionTitle('Personal Information'),
          _buildInfoCard(),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          _buildSectionTitle('Recent Activity'),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildSavingsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('savings')
          .where('farmerId', isEqualTo: _selectedMemberId)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final savings = snapshot.data!.docs;
        
        if (savings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No savings records', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }
        
        final totalSavings = savings.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0).toDouble(),
        );
        
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF357ABD)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Savings', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                      Text(
                        _currencyFormat.format(totalSavings),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.savings, size: 48, color: Colors.white24),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: savings.length,
                itemBuilder: (context, index) {
                  final saving = savings[index].data() as Map<String, dynamic>;
                  return _buildTransactionTile(
                    saving['createdAt'],
                    saving['amount'],
                    saving['description'] ?? 'Savings Deposit',
                    Icons.savings,
                    Colors.green,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSharesTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('shares')
          .where('farmerId', isEqualTo: _selectedMemberId)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final shares = snapshot.data!.docs;
        
        if (shares.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No shares records', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }
        
        final totalShares = shares.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0).toDouble(),
        );
        
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Shares Value', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                      Text(
                        _currencyFormat.format(totalShares),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.pie_chart, size: 48, color: Colors.white24),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shares.length,
                itemBuilder: (context, index) {
                  final share = shares[index].data() as Map<String, dynamic>;
                  return _buildTransactionTile(
                    share['createdAt'],
                    share['amount'],
                    share['description'] ?? 'Shares Purchase',
                    Icons.pie_chart,
                    Colors.green,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoansTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('loans')
          .where('farmerId', isEqualTo: _selectedMemberId)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final loans = snapshot.data!.docs;
        
        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No loan records', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index].data() as Map<String, dynamic>;
            return _buildLoanCard(loan);
          },
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAllTransactions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final transactions = snapshot.data!;
        
        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No transactions', style: GoogleFonts.poppins(color: Colors.grey)),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];
            return _buildTransactionTile(
              txn['createdAt'],
              txn['amount'],
              txn['description'],
              txn['icon'],
              txn['color'],
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('Document management coming soon', style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            'KYC documents, contracts, and attachments',
            style: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAllTransactions() async {
    final List<Map<String, dynamic>> allTransactions = [];
    
    // Load savings
    final savingsSnap = await FirebaseFirestore.instance
        .collection('savings')
        .where('farmerId', isEqualTo: _selectedMemberId)
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .get();
    
    for (var doc in savingsSnap.docs) {
      final data = doc.data();
      allTransactions.add({
        'createdAt': data['createdAt'],
        'amount': data['amount'],
        'description': '💰 ${data['description'] ?? 'Savings Deposit'}',
        'icon': Icons.savings,
        'color': Colors.green,
      });
    }
    
    // Load shares
    final sharesSnap = await FirebaseFirestore.instance
        .collection('shares')
        .where('farmerId', isEqualTo: _selectedMemberId)
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .get();
    
    for (var doc in sharesSnap.docs) {
      final data = doc.data();
      allTransactions.add({
        'createdAt': data['createdAt'],
        'amount': data['amount'],
        'description': '📊 ${data['description'] ?? 'Shares Purchase'}',
        'icon': Icons.pie_chart,
        'color': Colors.blue,
      });
    }
    
    // Sort by date
    allTransactions.sort((a, b) => (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp));
    
    return allTransactions;
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.trending_up, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'UGX $value',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
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
      child: Column(
        children: [
          _buildInfoRow('Phone', _memberData!['phone'] ?? 'N/A'),
          _buildInfoRow('National ID', _memberData!['nationalId'] ?? 'N/A'),
          _buildInfoRow('Village', _memberData!['village'] ?? 'N/A'),
          _buildInfoRow('District', _memberData!['district'] ?? 'N/A'),
          _buildInfoRow('Next of Kin', _memberData!['nextOfKin'] ?? 'N/A'),
          _buildInfoRow('Next of Kin Phone', _memberData!['nextOfKinPhone'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
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
      child: Column(
        children: [
          _buildActivityItem('Savings Deposit', '250,000', '2 days ago', Icons.savings, Colors.green),
          const Divider(),
          _buildActivityItem('Loan Repayment', '150,000', '5 days ago', Icons.payment, Colors.orange),
          const Divider(),
          _buildActivityItem('Shares Purchase', '100,000', '1 week ago', Icons.pie_chart, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String amount, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(time, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text(
            'UGX $amount',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Timestamp timestamp, dynamic amount, String description, IconData icon, Color color) {
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  _formatDate(timestamp),
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Map<String, dynamic> loan) {
    final status = loan['status'] ?? 'pending';
    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'disbursed'
            ? Colors.blue
            : status == 'rejected'
                ? Colors.red
                : Colors.orange;
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loan Application',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Amount', _currencyFormat.format(loan['amount'] ?? 0)),
          _buildInfoRow('Interest Rate', '${loan['interestRate'] ?? 0}%'),
          _buildInfoRow('Duration', '${loan['durationMonths'] ?? 0} months'),
          _buildInfoRow('Applied', _formatDate(loan['createdAt'])),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    return 'N/A';
  }
}

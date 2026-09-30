import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
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
          .collection('saccoplus-members')
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
      print('💰 Savings Balance: ${data['savingsBalance']}');
      
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

  void _showEditMemberDialog() {
    if (_memberData == null) return;
    
    final nameController = TextEditingController(text: _memberData!['name'] ?? _memberData!['fullName'] ?? '');
    final phoneController = TextEditingController(text: _memberData!['phone'] ?? '');
    final ninController = TextEditingController(text: _memberData!['nationalId'] ?? '');
    final villageController = TextEditingController(text: _memberData!['village'] ?? '');
    final districtController = TextEditingController(text: _memberData!['district'] ?? '');
    final nextOfKinController = TextEditingController(text: _memberData!['nextOfKin'] ?? '');
    final nextOfKinPhoneController = TextEditingController(text: _memberData!['nextOfKinPhone'] ?? '');
    
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text('Edit Member Information', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ninController,
                    maxLength: 14,
                    decoration: InputDecoration(
                      labelText: 'National ID (NIN)',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Must be exactly 14 characters',
                      counterText: '${ninController.text.length}/14',
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        if (value.trim().length != 14) {
                          return 'NIN must be exactly 14 characters';
                        }
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Trigger rebuild to update counter
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: villageController,
                    decoration: InputDecoration(
                      labelText: 'Village',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: districtController,
                    decoration: InputDecoration(
                      labelText: 'District',
                      prefixIcon: const Icon(Icons.map),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nextOfKinController,
                    decoration: InputDecoration(
                      labelText: 'Next of Kin',
                      prefixIcon: const Icon(Icons.people),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nextOfKinPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Next of Kin Phone',
                      prefixIcon: const Icon(Icons.phone_android),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              
              try {
                await FirebaseFirestore.instance
                    .collection('saccoplus-members')
                    .doc(_selectedMemberId)
                    .update({
                  'name': nameController.text.trim(),
                  'fullName': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'nationalId': ninController.text.trim(),
                  'village': villageController.text.trim(),
                  'district': districtController.text.trim(),
                  'nextOfKin': nextOfKinController.text.trim(),
                  'nextOfKinPhone': nextOfKinPhoneController.text.trim(),
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Member information updated successfully!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  _loadMemberData(); // Reload data
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating member: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: Text('Save Changes', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if we're in a dialog
    final isDialog = ModalRoute.of(context)?.settings.name == null;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Member 360° View', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !isDialog,
        leading: isDialog ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ) : null,
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
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                indicatorColor: AppTheme.primary,
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
          'Search Member',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (member) => member['name'] ?? member['fullName'] ?? 'Unknown',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            final query = textEditingValue.text.toLowerCase();
            final results = _members.where((member) {
              if (member['id'] == null) return false;
              final name = (member['name'] ?? member['fullName'] ?? '').toString().toLowerCase();
              final phone = (member['phone'] ?? '').toString();
              final accountNumber = (member['accountNumber'] ?? '').toString();
              final memberNumber = (member['memberNumber'] ?? '').toString();
              return name.contains(query) || 
                     phone.contains(query) || 
                     accountNumber.contains(query) ||
                     memberNumber.contains(query);
            }).toList();
            
            print('🔍 Autocomplete: query="$query", results=${results.length}');
            if (results.isNotEmpty) {
              print('🔍 First result: ${results.first['name'] ?? results.first['fullName']}');
            }
            
            return results;
          },
          onSelected: (Map<String, dynamic> member) {
            setState(() {
              _selectedMemberId = member['id'];
              _memberData = null;
            });
            _loadMemberData();
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Type name, phone, account or member number...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
              ),
              onEditingComplete: onEditingComplete,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300, maxWidth: 500),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final member = options.elementAt(index);
                      final accountNum = member['accountNumber'] ?? '';
                      final phone = member['phone'] ?? 'No phone';
                      final subtitle = accountNum.isNotEmpty 
                          ? '$phone  •  Acc: $accountNum'
                          : phone;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(
                            ((member['name'] ?? member['fullName'] ?? 'U').toString()[0]).toUpperCase(),
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        title: Text(
                          member['name'] ?? member['fullName'] ?? 'Unknown',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        onTap: () => onSelected(member),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberHeader() {
    final memberName = _memberData!['name'] ?? _memberData!['fullName'] ?? 'Unknown';
    final memberPhone = _memberData!['phone'] ?? 'No phone';
    final accountNumber = _memberData!['accountNumber'] ?? 'N/A';
    final memberNumber = _memberData!['memberNumber'] ?? 'N/A';
    
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
              memberName[0].toUpperCase(),
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
                  memberName,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Account: $accountNumber  •  Member: $memberNumber',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildHeaderChip(Icons.phone, memberPhone),
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
    // Get real financial data from member document
    final savingsBalance = (_memberData!['savingsBalance'] ?? 0).toDouble();
    final sharesBalance = (_memberData!['sharesBalance'] ?? 0).toDouble();
    final loanBalance = (_memberData!['loanBalance'] ?? 0).toDouble();
    final walletBalance = (_memberData!['walletBalance'] ?? 0).toDouble();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Financial Summary'),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: _showEditMemberDialog,
                tooltip: 'Edit Member Info',
                color: AppTheme.primary,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Total Savings', _currencyFormat.format(savingsBalance), Icons.savings, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('Total Shares', _currencyFormat.format(sharesBalance), Icons.pie_chart, Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Active Loans', _currencyFormat.format(loanBalance), Icons.account_balance, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildSummaryCard('Wallet Balance', _currencyFormat.format(walletBalance), Icons.account_balance_wallet, Colors.purple)),
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
    // Get savings balance from member document
    final savingsBalance = (_memberData!['savingsBalance'] ?? 0).toDouble();
    
    // Also check if there are transactions in the savings collection
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('saccoplus-savings')
          .where('farmerId', isEqualTo: _selectedMemberId)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final savingsTransactions = snapshot.data!.docs;
        
        // Calculate total from transactions if any exist
        final transactionsTotal = savingsTransactions.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0).toDouble(),
        );
        
        // Use the higher of the two (member document balance or transaction sum)
        final displayBalance = savingsBalance > 0 ? savingsBalance : transactionsTotal;
        
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
                        _currencyFormat.format(displayBalance),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (savingsTransactions.isNotEmpty)
                        Text(
                          '${savingsTransactions.length} transactions',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                  const Icon(Icons.savings, size: 48, color: Colors.white24),
                ],
              ),
            ),
            if (savingsTransactions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.savings_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No transaction history', style: GoogleFonts.poppins(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        'Balance: ${_currencyFormat.format(displayBalance)}',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: savingsTransactions.length,
                  itemBuilder: (context, index) {
                    final saving = savingsTransactions[index].data() as Map<String, dynamic>;
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
    // Get shares balance from member document
    final sharesBalance = (_memberData!['sharesBalance'] ?? 0).toDouble();
    
    // Also check if there are transactions in the shares collection
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('saccoplus-shares')
          .where('farmerId', isEqualTo: _selectedMemberId)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final sharesTransactions = snapshot.data!.docs;
        
        // Calculate total from transactions if any exist
        final transactionsTotal = sharesTransactions.fold<double>(
          0,
          (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0).toDouble(),
        );
        
        // Use the higher of the two (member document balance or transaction sum)
        final displayBalance = sharesBalance > 0 ? sharesBalance : transactionsTotal;
        
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
                        _currencyFormat.format(displayBalance),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (sharesTransactions.isNotEmpty)
                        Text(
                          '${sharesTransactions.length} transactions',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                  const Icon(Icons.pie_chart, size: 48, color: Colors.white24),
                ],
              ),
            ),
            if (sharesTransactions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No transaction history', style: GoogleFonts.poppins(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        'Balance: ${_currencyFormat.format(displayBalance)}',
                        style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: sharesTransactions.length,
                  itemBuilder: (context, index) {
                    final share = sharesTransactions[index].data() as Map<String, dynamic>;
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
    final loanBalance = (_memberData!['loanBalance'] ?? 0).toDouble();
    
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .where('farmerId', isEqualTo: _selectedMemberId)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final loans = snapshot.data!.docs;
        
        // Calculate actual outstanding balance from loan records
        final actualOutstanding = loans.fold<double>(
          0,
          (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final principalOutstanding = (data['principalOutstanding'] ?? 0).toDouble();
            return sum + principalOutstanding;
          },
        );
        
        // Use the actual outstanding from loans if available, otherwise fall back to member document
        final displayBalance = actualOutstanding > 0 ? actualOutstanding : loanBalance;
        
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding Loan Balance', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                      Text(
                        _currencyFormat.format(displayBalance),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (loans.isNotEmpty)
                        Text(
                          '${loans.length} loan(s)',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                  const Icon(Icons.account_balance, size: 48, color: Colors.white24),
                ],
              ),
            ),
            if (loans.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No loan records', style: GoogleFonts.poppins(color: Colors.grey)),
                      if (loanBalance > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Outstanding: ${_currencyFormat.format(loanBalance)}',
                          style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: loans.length,
                  itemBuilder: (context, index) {
                    final loan = loans[index].data() as Map<String, dynamic>;
                    return _buildLoanCard(loan);
                  },
                ),
              ),
          ],
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
          Text('KYC documents, contracts, and attachments', style: GoogleFonts.poppins(color: Colors.grey)),
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
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
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
          _buildInfoRow('Account Number', _memberData!['accountNumber'] ?? 'N/A'),
          _buildInfoRow('Member Number', _memberData!['memberNumber'] ?? 'N/A'),
          const Divider(height: 20),
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

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: isError ? Colors.red.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_memberData == null) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Center(
          child: Text(
            'No recent activity',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('saccoplus-savings-transactions')
          .where('memberId', isEqualTo: _selectedMemberId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, savingsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('saccoplus-repayments')
              .where('memberId', isEqualTo: _selectedMemberId)
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, repaymentsSnapshot) {
            // Combine all activities
            List<Map<String, dynamic>> activities = [];

            // Add savings transactions
            if (savingsSnapshot.hasData) {
              for (var doc in savingsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                activities.add({
                  'title': 'Savings Deposit',
                  'amount': data['amount'] ?? 0,
                  'date': data['createdAt'],
                  'icon': Icons.savings,
                  'color': Colors.green,
                });
              }
            }

            // Add loan repayments
            if (repaymentsSnapshot.hasData) {
              for (var doc in repaymentsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                activities.add({
                  'title': 'Loan Repayment',
                  'amount': data['amount'] ?? 0,
                  'date': data['createdAt'],
                  'icon': Icons.payment,
                  'color': Colors.orange,
                });
              }
            }

            // Sort by date
            activities.sort((a, b) {
              final aDate = a['date'] as Timestamp?;
              final bDate = b['date'] as Timestamp?;
              if (aDate == null || bDate == null) return 0;
              return bDate.compareTo(aDate);
            });

            // Take only 5 most recent
            activities = activities.take(5).toList();

            if (activities.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
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
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'No recent activity',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

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
                children: activities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final activity = entry.value;
                  final timestamp = activity['date'] as Timestamp?;
                  final timeAgo = timestamp != null
                      ? _getTimeAgo(timestamp.toDate())
                      : 'Unknown';
                  
                  return Column(
                    children: [
                      if (index > 0) const Divider(),
                      _buildActivityItem(
                        activity['title'],
                        _currencyFormat.format(activity['amount']).replaceAll('UGX ', ''),
                        timeAgo,
                        activity['icon'],
                        activity['color'],
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
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
    final statusColor = status == 'paid' || status == 'cleared'
        ? Colors.green
        : status == 'active' || status == 'approved'
            ? Colors.blue
            : status == 'overdue'
                ? Colors.red
                : Colors.orange;
    
    final amount = (loan['amount'] ?? 0).toDouble();
    final principalOutstanding = (loan['principalOutstanding'] ?? 0).toDouble();
    final outstandingDays = loan['outstandingDays'] ?? 0;
    final referenceNumber = loan['referenceNumber'] ?? 'N/A';
    final loanProduct = loan['loanProduct'] ?? 'General Loan';
    final interestRate = loan['interestRate'] ?? 0;
    final durationMonths = loan['durationMonths'] ?? 0;
    
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loanProduct,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref: $referenceNumber',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
          _buildInfoRow('Loan Amount', _currencyFormat.format(amount)),
          _buildInfoRow('Principal Outstanding', _currencyFormat.format(principalOutstanding)),
          if (outstandingDays > 0)
            _buildInfoRow('Days Overdue', '$outstandingDays days', isError: true),
          if (interestRate > 0)
            _buildInfoRow('Interest Rate', '$interestRate%'),
          if (durationMonths > 0)
            _buildInfoRow('Duration', '$durationMonths months'),
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

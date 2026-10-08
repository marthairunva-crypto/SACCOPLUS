import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../services/till_service.dart';
import '../../models/till_entry.dart';

// Cash & Bank Screen
class CashBankScreen extends StatefulWidget {
  const CashBankScreen({super.key});

  @override
  State<CashBankScreen> createState() => _CashBankScreenState();
}

class _CashBankScreenState extends State<CashBankScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Cash & Bank', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildBalanceSummary(),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ModernTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              indicatorColor: ModernTheme.primary,
              tabs: const [
                Tab(text: 'Cash Accounts'),
                Tab(text: 'Bank Accounts'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCashAccounts(),
                _buildBankAccounts(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
        backgroundColor: ModernTheme.primary,
        heroTag: 'cash_bank_fab',
      ),
    );
  }

  Widget _buildBalanceSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('accounts')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        double cashBalance = 0;
        double bankBalance = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final balance = (data['balance'] ?? 0).toDouble();
          if (data['type'] == 'cash') {
            cashBalance += balance;
          } else {
            bankBalance += balance;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildBalanceCard('Cash Balance', cashBalance, Icons.money, Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard('Bank Balance', bankBalance, Icons.account_balance, Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceCard('Total', cashBalance + bankBalance, Icons.account_balance_wallet, Colors.purple),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          Text(
            _currencyFormat.format(amount),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashAccounts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('accounts')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('type', isEqualTo: 'cash')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final accounts = snapshot.data!.docs;

        if (accounts.isEmpty) {
          return _buildEmptyState('No cash accounts', Icons.money);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index].data() as Map<String, dynamic>;
            return _buildAccountCard(account, accounts[index].id);
          },
        );
      },
    );
  }

  Widget _buildBankAccounts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('accounts')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('type', isEqualTo: 'bank')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final accounts = snapshot.data!.docs;

        if (accounts.isEmpty) {
          return _buildEmptyState('No bank accounts', Icons.account_balance);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index].data() as Map<String, dynamic>;
            return _buildAccountCard(account, accounts[index].id);
          },
        );
      },
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account, String accountId) {
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
                      account['name'] ?? 'Unnamed Account',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (account['accountNumber'] != null)
                      Text(
                        'A/C: ${account['accountNumber']}',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Text(
                _currencyFormat.format(account['balance'] ?? 0),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ModernTheme.primary,
                ),
              ),
            ],
          ),
          if (account['bankName'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Bank: ${account['bankName']}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final accountNumberController = TextEditingController();
    final bankNameController = TextEditingController();
    final balanceController = TextEditingController(text: '0');
    String accountType = 'cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: accountType,
                  decoration: const InputDecoration(labelText: 'Account Type'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash Account')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                  ],
                  onChanged: (value) => setDialogState(() => accountType = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Account Name'),
                ),
                if (accountType == 'bank') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: bankNameController,
                    decoration: const InputDecoration(labelText: 'Bank Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accountNumberController,
                    decoration: const InputDecoration(labelText: 'Account Number'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  decoration: const InputDecoration(labelText: 'Opening Balance'),
                  keyboardType: TextInputType.number,
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
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter account name')),
                  );
                  return;
                }

                await FirebaseFirestore.instance.collection('accounts').add({
                  'tenantId': FirebaseService.sessionTenantId,
                  'type': accountType,
                  'name': nameController.text,
                  'bankName': accountType == 'bank' ? bankNameController.text : null,
                  'accountNumber': accountType == 'bank' ? accountNumberController.text : null,
                  'balance': double.tryParse(balanceController.text) ?? 0,
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': FirebaseService.sessionUid,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account added'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

// Income Screen
class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Income', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildIncomeSummary(currencyFormat),
          Expanded(
            child: _buildIncomeList(currencyFormat),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
        backgroundColor: Colors.green,
        heroTag: 'income_fab',
      ),
    );
  }

  Widget _buildIncomeSummary(NumberFormat currencyFormat) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('income')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        double totalIncome = 0;
        double monthIncome = 0;
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] ?? 0).toDouble();
          totalIncome += amount;

          final date = (data['createdAt'] as Timestamp).toDate();
          if (date.isAfter(monthStart)) {
            monthIncome += amount;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Total Income', totalIncome, Icons.trending_up, Colors.green, currencyFormat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('This Month', monthIncome, Icons.calendar_today, Colors.blue, currencyFormat),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, double amount, IconData icon, Color color, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          Text(
            currencyFormat.format(amount),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeList(NumberFormat currencyFormat) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('income')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final incomeList = snapshot.data!.docs;

        if (incomeList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No income records', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: incomeList.length,
          itemBuilder: (context, index) {
            final income = incomeList[index].data() as Map<String, dynamic>;
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
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_downward, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          income['category'] ?? 'Income',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          income['description'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format((income['createdAt'] as Timestamp).toDate()),
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(income['amount']),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddIncomeDialog(BuildContext context) {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Income', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid amount')),
                );
                return;
              }

              // Save income record
              final incomeDoc = await FirebaseFirestore.instance.collection('income').add({
                'tenantId': FirebaseService.sessionTenantId,
                'category': categoryController.text,
                'amount': amount,
                'description': descriptionController.text,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': FirebaseService.sessionUid,
              });

              // Post to till (increases till balance)
              try {
                final tellerId = FirebaseService.sessionUid;
                final tillSession = await TillService.getOpenSession(tellerId);
                
                if (tillSession != null) {
                  final profile = FirebaseService.sessionProfile;
                  final tellerName = (profile != null ? profile['name'] as String? : null) ?? 'User';
                  
                  await TillService.postEntry(
                    tillSessionId: tillSession.id,
                    tellerId: tellerId,
                    tellerName: tellerName,
                    input: TillEntryInput(
                      entryType: 'income',
                      amount: amount.toInt(), // Positive = cash in
                      affectsCash: true,
                      paymentMethod: 'Cash',
                      businessRecordId: incomeDoc.id,
                      businessRecordType: 'income',
                      notes: 'Income: ${categoryController.text} - ${descriptionController.text}',
                    ),
                  );
                  print('✅ Till entry posted for income');
                }
              } catch (e) {
                print('⚠️ Failed to post till entry for income: $e');
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Income added'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// Expenses Screen
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Expenses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildExpenseSummary(currencyFormat),
          Expanded(
            child: _buildExpenseList(currencyFormat),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: Colors.red,
        heroTag: 'expenses_fab',
      ),
    );
  }

  Widget _buildExpenseSummary(NumberFormat currencyFormat) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        double totalExpense = 0;
        double monthExpense = 0;
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] ?? 0).toDouble();
          totalExpense += amount;

          final date = (data['createdAt'] as Timestamp).toDate();
          if (date.isAfter(monthStart)) {
            monthExpense += amount;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard('Total Expenses', totalExpense, Icons.trending_down, Colors.red, currencyFormat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard('This Month', monthExpense, Icons.calendar_today, Colors.orange, currencyFormat),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, double amount, IconData icon, Color color, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          Text(
            currencyFormat.format(amount),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList(NumberFormat currencyFormat) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('expenses')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final expenseList = snapshot.data!.docs;

        if (expenseList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.money_off_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No expense records', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: expenseList.length,
          itemBuilder: (context, index) {
            final expense = expenseList[index].data() as Map<String, dynamic>;
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
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense['category'] ?? 'Expense',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          expense['description'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format((expense['createdAt'] as Timestamp).toDate()),
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(expense['amount']),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Expense', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid amount')),
                );
                return;
              }

              // Save expense record
              final expenseDoc = await FirebaseFirestore.instance.collection('expenses').add({
                'tenantId': FirebaseService.sessionTenantId,
                'category': categoryController.text,
                'amount': amount,
                'description': descriptionController.text,
                'createdAt': FieldValue.serverTimestamp(),
                'createdBy': FirebaseService.sessionUid,
              });

              // Post to till (decreases till balance)
              try {
                final tellerId = FirebaseService.sessionUid;
                final tillSession = await TillService.getOpenSession(tellerId);
                
                if (tillSession != null) {
                  final profile = FirebaseService.sessionProfile;
                  final tellerName = (profile != null ? profile['name'] as String? : null) ?? 'User';
                  
                  await TillService.postEntry(
                    tillSessionId: tillSession.id,
                    tellerId: tellerId,
                    tellerName: tellerName,
                    input: TillEntryInput(
                      entryType: 'expense',
                      amount: -amount.toInt(), // Negative = cash out
                      affectsCash: true,
                      paymentMethod: 'Cash',
                      businessRecordId: expenseDoc.id,
                      businessRecordType: 'expense',
                      notes: 'Expense: ${categoryController.text} - ${descriptionController.text}',
                    ),
                  );
                  print('✅ Till entry posted for expense');
                }
              } catch (e) {
                print('⚠️ Failed to post till entry for expense: $e');
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense added'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// General Ledger Screen
class GeneralLedgerScreen extends StatelessWidget {
  const GeneralLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'UGX ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('General Ledger', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildLedgerSummary(currencyFormat),
          Expanded(
            child: _buildLedgerEntries(currencyFormat),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerSummary(NumberFormat currencyFormat) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.book, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            'General Ledger',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete record of financial transactions',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerEntries(NumberFormat currencyFormat) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _combineLedgerEntries(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data!;

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No ledger entries', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _buildLedgerEntryCard(entry, currencyFormat);
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _combineLedgerEntries() async* {
    await for (final _ in Stream.periodic(const Duration(seconds: 1))) {
      final entries = <Map<String, dynamic>>[];

      // Get income
      final incomeSnap = await FirebaseFirestore.instance
          .collection('income')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      for (var doc in incomeSnap.docs) {
        final data = doc.data();
        entries.add({
          ...data,
          'type': 'credit',
          'accountType': 'Income',
        });
      }

      // Get expenses
      final expenseSnap = await FirebaseFirestore.instance
          .collection('expenses')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      for (var doc in expenseSnap.docs) {
        final data = doc.data();
        entries.add({
          ...data,
          'type': 'debit',
          'accountType': 'Expense',
        });
      }

      entries.sort((a, b) => (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp));

      yield entries;
      break;
    }
  }

  Widget _buildLedgerEntryCard(Map<String, dynamic> entry, NumberFormat currencyFormat) {
    final isCredit = entry['type'] == 'credit';
    final color = isCredit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCredit ? Icons.add_circle : Icons.remove_circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry['accountType']} - ${entry['category'] ?? 'General'}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (entry['description'] != null)
                  Text(
                    entry['description'],
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                Text(
                  DateFormat('MMM dd, yyyy').format((entry['createdAt'] as Timestamp).toDate()),
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isCredit ? 'CR' : 'DR',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                currencyFormat.format(entry['amount']),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

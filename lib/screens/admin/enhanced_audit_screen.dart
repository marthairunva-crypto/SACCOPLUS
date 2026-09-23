import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/audit_service.dart';
import '../../theme/modern_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../debug/generate_test_data.dart';

class EnhancedAuditScreen extends StatefulWidget {
  final bool embedded;
  const EnhancedAuditScreen({super.key, this.embedded = false});

  @override
  State<EnhancedAuditScreen> createState() => _EnhancedAuditScreenState();
}

class _EnhancedAuditScreenState extends State<EnhancedAuditScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = false;
  
  String? _filterAction;
  String? _filterUserId;
  DateTime? _startDate;
  DateTime? _endDate;
  
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final logs = await AuditService.getLogs(
      action: _filterAction,
      userId: _filterUserId,
      startDate: _startDate,
      endDate: _endDate,
      limit: 200,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchController.text.isEmpty) return _logs;
    
    final query = _searchController.text.toLowerCase();
    return _logs.where((log) {
      return (log['action']?.toString().toLowerCase().contains(query) ?? false) ||
          (log['details']?.toString().toLowerCase().contains(query) ?? false) ||
          (log['userName']?.toString().toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build with AutomaticKeepAliveClientMixin
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Audit Trail', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: ModernTheme.primary,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // DEBUG: Test data generator button
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Generate Test Data',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Generate Test Data?'),
                    content: const Text('This will create sample audit logs and transactions.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Generate'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generating test data...')),
                  );
                  
                  await TestDataGenerator.generateAll();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Done! Click Refresh to see data.'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                    _loadLogs();
                  }
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All Activity'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildStatisticsTab(),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by action, user, or details...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() {}),
          ),
        ),

        // Active filters
        if (_filterAction != null || _startDate != null || _endDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: ModernTheme.info.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_filterAction != null)
                        _buildFilterChip('Action: $_filterAction', () {
                          setState(() => _filterAction = null);
                          _loadLogs();
                        }),
                      if (_startDate != null)
                        _buildFilterChip(
                          'From: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
                          () {
                            setState(() => _startDate = null);
                            _loadLogs();
                          },
                        ),
                      if (_endDate != null)
                        _buildFilterChip(
                          'To: ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                          () {
                            setState(() => _endDate = null);
                            _loadLogs();
                          },
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterAction = null;
                      _filterUserId = null;
                      _startDate = null;
                      _endDate = null;
                    });
                    _loadLogs();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),

        // Logs list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No audit logs found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLogs,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          return _buildLogCard(_filteredLogs[index], index);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: Colors.white,
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final action = log['action'] as String? ?? 'UNKNOWN';
    final details = log['details'] as String? ?? '';
    final userName = log['userName'] as String? ?? 'System';
    final timestamp = log['timestamp'] as DateTime;
    final metadataRaw = log['metadata'];
    final metadata = metadataRaw != null 
        ? Map<String, dynamic>.from(metadataRaw as Map) 
        : <String, dynamic>{};

    final color = _getActionColor(action);
    final icon = _getActionIcon(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            action,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            details,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: ModernTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                userName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: ModernTheme.textSecondary,
                ),
              ),
              if (log['affectedUserId'] != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward, size: 14, color: ModernTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Affected User ID: ${log['affectedUserId']}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details:',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ModernTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...metadata.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildStatisticsTab() {
    // Calculate statistics
    final actionCounts = <String, int>{};
    final userCounts = <String, int>{};
    
    for (var log in _logs) {
      final action = log['action'] as String? ?? 'UNKNOWN';
      final user = log['userName'] as String? ?? 'System';
      
      actionCounts[action] = (actionCounts[action] ?? 0) + 1;
      userCounts[user] = (userCounts[user] ?? 0) + 1;
    }

    final sortedActions = actionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedUsers = userCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Audit Statistics',
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),

        // Summary cards
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ModernTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ModernTheme.primary.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Total Actions Logged',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '${_logs.length}',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: ModernTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Top actions
        Text(
          'Most Common Actions',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...sortedActions.take(10).map((entry) {
          final percentage = (_logs.isNotEmpty ? (entry.value / _logs.length * 100) : 0).toStringAsFixed(1);
          return Container(
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getActionColor(entry.key).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.key,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getActionColor(entry.key),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${entry.value} times',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' ($percentage%)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 24),

        // Top users
        Text(
          'Most Active Users',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...sortedUsers.take(10).map((entry) {
          final percentage = (_logs.isNotEmpty ? (entry.value / _logs.length * 100) : 0).toStringAsFixed(1);
          return Container(
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ModernTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: ModernTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${entry.value} actions',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' ($percentage%)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Audit Logs', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Action Type', style: GoogleFonts.poppins(fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _filterAction,
                decoration: InputDecoration(
                  hintText: 'All actions',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Actions')),
                  ...AuditService.ACTION_LOGIN.split('_').map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  const DropdownMenuItem(value: 'TELLER', child: Text('TELLER')),
                  const DropdownMenuItem(value: 'LOAN', child: Text('LOAN')),
                  const DropdownMenuItem(value: 'KYC', child: Text('KYC')),
                  const DropdownMenuItem(value: 'SAVINGS', child: Text('SAVINGS')),
                  const DropdownMenuItem(value: 'SHARES', child: Text('SHARES')),
                ],
                onChanged: (value) => _filterAction = value,
              ),
              const SizedBox(height: 16),

              Text('Date Range', style: GoogleFonts.poppins(fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _startDate != null
                            ? DateFormat('dd/MM/yyyy').format(_startDate!)
                            : 'Start Date',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _endDate != null
                            ? DateFormat('dd/MM/yyyy').format(_endDate!)
                            : 'End Date',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ),
                ],
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
            onPressed: () {
              Navigator.pop(context);
              _loadLogs();
            },
            style: ElevatedButton.styleFrom(backgroundColor: ModernTheme.primary),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    final upper = action.toUpperCase();
    if (upper.contains('APPROVED') || upper.contains('DEPOSIT') || upper.contains('LOGIN')) {
      return ModernTheme.success;
    }
    if (upper.contains('REJECTED') || upper.contains('WITHDRAWAL') || upper.contains('LOGOUT')) {
      return ModernTheme.error;
    }
    if (upper.contains('LOAN') || upper.contains('REPAYMENT')) {
      return ModernTheme.primary;
    }
    if (upper.contains('KYC') || upper.contains('TELLER')) {
      return ModernTheme.warning;
    }
    if (upper.contains('SETTINGS') || upper.contains('STAFF')) {
      return ModernTheme.accent;
    }
    return ModernTheme.textSecondary;
  }

  IconData _getActionIcon(String action) {
    final upper = action.toUpperCase();
    if (upper.contains('LOAN')) return Icons.account_balance_wallet;
    if (upper.contains('KYC')) return Icons.verified_user;
    if (upper.contains('TELLER')) return Icons.point_of_sale;
    if (upper.contains('SAVINGS')) return Icons.savings;
    if (upper.contains('SHARES')) return Icons.pie_chart;
    if (upper.contains('LOGIN')) return Icons.login;
    if (upper.contains('LOGOUT')) return Icons.logout;
    if (upper.contains('SETTINGS')) return Icons.settings;
    if (upper.contains('STAFF')) return Icons.manage_accounts;
    if (upper.contains('EXPORT')) return Icons.download;
    return Icons.history;
  }
}

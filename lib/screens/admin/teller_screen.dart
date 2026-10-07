import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/teller_service.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';
import '../../widgets/app_widgets.dart';

// ─── Responsive helpers ───────────────────────────────────────────────────────
const double _kMaxContentWidth = 1000;
const double _kDialogMaxWidth = 480;

bool _isNarrow(BuildContext context) => MediaQuery.of(context).size.width < 600;

double _pagePadding(BuildContext context) => _isNarrow(context) ? 16 : 24;

/// Dialog content width that never exceeds the screen.
double _dialogWidth(BuildContext context) {
  final available = MediaQuery.of(context).size.width - 80;
  return available < _kDialogMaxWidth ? available : _kDialogMaxWidth;
}

/// Returns the local part of a Ugandan number (without 0 / 256 / +256).
String _localUgPhone(String input) {
  final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (cleaned.startsWith('+256')) return cleaned.substring(4);
  if (cleaned.startsWith('256')) return cleaned.substring(3);
  if (cleaned.startsWith('0')) return cleaned.substring(1);
  return cleaned;
}

/// Centers content and limits its width on tablets / desktop / web.
class _ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const _ResponsiveCenter({required this.child, this.maxWidth = _kMaxContentWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

Future<void> _showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.error_outline,
  Color? color,
}) {
  final c = color ?? ModernTheme.error;
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(icon, color: c, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Text(message, style: GoogleFonts.poppins(fontSize: 15)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'OK',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: ModernTheme.primary),
          ),
        ),
      ],
    ),
  );
}

InputDecoration _dialogFieldDecoration({String? hint, Widget? suffixIcon, String? prefixText, TextStyle? prefixStyle}) {
  return InputDecoration(
    hintText: hint,
    prefixText: prefixText,
    prefixStyle: prefixStyle,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class TellerScreen extends StatefulWidget {
  final bool embedded;
  const TellerScreen({super.key, this.embedded = false});

  @override
  State<TellerScreen> createState() => _TellerScreenState();
}

class _TellerScreenState extends State<TellerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fmt = NumberFormat('#,###', 'en_US');

  // Till state
  double _tillOpeningBalance = 0;
  double _tillCurrentBalance = 0;
  int _tillTransactionCount = 0;
  bool _tillOpen = false;
  String? _tillSessionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Removed _loadTillStatus() - till management not needed
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTillStatus() async {
    try {
      // Till management disabled - not needed for this SACCO system  
      // final userId = FirebaseService.sessionUid;
      return;
      /*
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Check for today's till session
      final tillSnapshot = await FirebaseFirestore.instance
          .collection('saccoplus-till-sessions')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('tellerId', isEqualTo: userId)
          .where('date', isEqualTo: today)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (tillSnapshot.docs.isNotEmpty && mounted) {
        final tillData = tillSnapshot.docs.first.data();
        setState(() {
          _tillOpen = true;
          _tillSessionId = tillSnapshot.docs.first.id;
          _tillOpeningBalance = (tillData['openingBalance'] ?? 0).toDouble();
          _tillCurrentBalance = (tillData['currentBalance'] ?? 0).toDouble();
          _tillTransactionCount = (tillData['transactionCount'] ?? 0);
        });
      }
      */
    } catch (e) {
      print('Error loading till status: $e');
    }
  }

  Future<void> _showOpenTillDialog() async {
    final controller = TextEditingController();
    
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.point_of_sale, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            Text('Open Till', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter opening cash amount for your till',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Opening Balance (UGX)',
                hintText: '0',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount >= 0) {
                Navigator.pop(ctx, amount);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Till'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final userId = FirebaseService.sessionUid;
        final userName = FirebaseService.sessionProfile?['name'] as String? ?? 
                        FirebaseService.sessionProfile?['fullName'] as String? ?? 'Teller';
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        final docRef = await FirebaseFirestore.instance
            .collection('saccoplus-till-sessions')
            .add({
          'tenantId': FirebaseService.sessionTenantId,
          'tellerId': userId,
          'tellerName': userName,
          'date': today,
          'openingBalance': result,
          'currentBalance': result,
          'transactionCount': 0,
          'status': 'open',
          'openedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        setState(() {
          _tillOpen = true;
          _tillSessionId = docRef.id;
          _tillOpeningBalance = result;
          _tillCurrentBalance = result;
          _tillTransactionCount = 0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Till opened with UGX ${_fmt.format(result)}'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showMessageDialog(
            context,
            title: 'Error',
            message: 'Failed to open till: $e',
          );
        }
      }
    }
  }

  Future<void> _showCloseTillDialog() async {
    final controller = TextEditingController(text: _tillCurrentBalance.toStringAsFixed(0));
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.lock, color: Colors.red.shade700),
            ),
            const SizedBox(width: 12),
            Text('Close Till', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify closing cash amount',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildTillSummaryRow('Opening', _tillOpeningBalance),
                  const Divider(),
                  _buildTillSummaryRow('Transactions', _tillTransactionCount.toDouble(), isCount: true),
                  const Divider(),
                  _buildTillSummaryRow('Expected', _tillCurrentBalance),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Actual Closing Balance (UGX)',
                hintText: '0',
                prefixIcon: const Icon(Icons.money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final actualBalance = double.tryParse(controller.text);
              if (actualBalance != null && actualBalance >= 0) {
                final variance = actualBalance - _tillCurrentBalance;
                Navigator.pop(ctx, {
                  'actualBalance': actualBalance,
                  'variance': variance,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close Till'),
          ),
        ],
      ),
    );

    if (result != null && _tillSessionId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('saccoplus-till-sessions')
            .doc(_tillSessionId)
            .update({
          'status': 'closed',
          'closingBalance': result['actualBalance'],
          'variance': result['variance'],
          'closedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _tillOpen = false;
          _tillSessionId = null;
          _tillOpeningBalance = 0;
          _tillCurrentBalance = 0;
          _tillTransactionCount = 0;
        });

        if (mounted) {
          final variance = result['variance'] as double;
          final message = variance == 0
              ? 'Till closed successfully. No variance.'
              : 'Till closed. Variance: UGX ${_fmt.format(variance.abs())} ${variance > 0 ? 'over' : 'short'}';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: variance == 0 ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showMessageDialog(
            context,
            title: 'Error',
            message: 'Failed to close till: $e',
          );
        }
      }
    }
  }

  Widget _buildTillSummaryRow(String label, double value, {bool isCount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
        ),
        Text(
          isCount ? value.toInt().toString() : 'UGX ${_fmt.format(value)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Teller Operations',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (_tillOpen)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'TILL OPEN',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.search_rounded), text: 'Search Member'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Bank Transfer'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Transactions'),
            Tab(icon: Icon(Icons.assessment_rounded), text: 'Daily Summary'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Dynamic Till Header
          _buildTillHeader(),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MemberLookupTab(fmt: _fmt),
                _BankTransferTab(fmt: _fmt),
                _TransactionHistoryTab(fmt: _fmt),
                _DailySummaryTab(fmt: _fmt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTillHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade700, Colors.blue.shade900],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _tillOpen ? _buildOpenTillView() : _buildClosedTillView(),
      ),
    );
  }

  Widget _buildOpenTillView() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTillCard(
                'Opening Balance',
                'UGX ${_fmt.format(_tillOpeningBalance)}',
                Icons.account_balance_wallet,
                Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTillCard(
                'Current Balance',
                'UGX ${_fmt.format(_tillCurrentBalance)}',
                Icons.account_balance,
                Colors.greenAccent.shade100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTillCard(
                'Transactions',
                _tillTransactionCount.toString(),
                Icons.receipt_long,
                Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showCloseTillDialog,
                icon: const Icon(Icons.lock, size: 18),
                label: const Text('Close Till'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClosedTillView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.point_of_sale,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Till is Closed',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open your till to start accepting transactions',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showOpenTillDialog,
            icon: const Icon(Icons.lock_open, size: 18),
            label: const Text('Open Till'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTillCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
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
    final pad = _pagePadding(context);
    final narrow = _isNarrow(context);

    return _ResponsiveCenter(
      child: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          // Header card
          Container(
            padding: EdgeInsets.all(narrow ? 14 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.blue.shade200],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.search_rounded, color: Colors.blue.shade700, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: narrow ? 18 : 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        'Find member by phone number or name',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Search field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Enter phone number or name',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.search_rounded, color: Colors.blue.shade700, size: 20),
                ),
                suffixIcon: _searching
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade100, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                ),
              ),
              onChanged: _searchMembers,
            ),
          ),
          const SizedBox(height: 24),

          // Search results
          if (_searchResults.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_searchResults.length} Results',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._searchResults.map((member) {
              return GestureDetector(
                onTap: () => _selectMember(member['id']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(narrow ? 14 : 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${member['name']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${member['phone']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.blue.shade400, size: 18),
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
              padding: EdgeInsets.all(narrow ? 20 : 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blue.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Member Details',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.red.shade600),
                          onPressed: () => setState(() => _selectedMember = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow('Name', '${_selectedMember!['name']}'),
                        const Divider(height: 20),
                        _buildDetailRow('Phone', '${_selectedMember!['phone']}'),
                        if ('${_selectedMember!['email'] ?? ''}'.isNotEmpty) ...[
                          const Divider(height: 20),
                          _buildDetailRow('Email', '${_selectedMember!['email']}'),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_balance_wallet, color: Colors.green.shade700, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Account Balances',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Balance cards: side by side when there is room, stacked otherwise
                  LayoutBuilder(builder: (ctx, c) {
                    final savings = _buildBalanceCard(
                      'Savings Balance',
                      'UGX ${widget.fmt.format(_selectedMember!['savingsBalance'])}',
                      Icons.savings_outlined,
                      Colors.green.shade600,
                    );
                    final shares = _buildBalanceCard(
                      'Shares (${_selectedMember!['sharesCount']} shares)',
                      'UGX ${widget.fmt.format(_selectedMember!['sharesValue'])}',
                      Icons.pie_chart_outline,
                      Colors.purple.shade600,
                    );
                    if (c.maxWidth < 420) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [savings, const SizedBox(height: 12), shares],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: savings),
                        const SizedBox(width: 12),
                        Expanded(child: shares),
                      ],
                    );
                  }),

                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (ctx, c) {
                    final depositBtn = ElevatedButton.icon(
                      onPressed: () => _showTransactionDialog('deposit'),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: Text('Deposit', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                        elevation: 0,
                        shadowColor: Colors.green.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    final withdrawBtn = ElevatedButton.icon(
                      onPressed: () => _showTransactionDialog('withdrawal'),
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      label: Text('Withdrawal', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                        elevation: 0,
                        shadowColor: Colors.red.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    if (c.maxWidth < 300) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [depositBtn, const SizedBox(height: 12), withdrawBtn],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: depositBtn),
                        const SizedBox(width: 12),
                        Expanded(child: withdrawBtn),
                      ],
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(String type) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final phoneController = TextEditingController();
    String accountType = 'savings'; // Default to savings (wallet = savings in SACCO)
    String paymentMethod = 'Cash';
    String? selectedTelecom;
    String? verifiedName;
    bool verifyingPhone = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(
            type == 'deposit' ? 'Process Deposit' : 'Process Withdrawal',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: _dialogWidth(context),
            child: SingleChildScrollView(
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
                    isExpanded: true,
                    value: accountType,
                    decoration: _dialogFieldDecoration(),
                    items: [
                      const DropdownMenuItem(value: 'savings', child: Text('Savings')),
                      if (type == 'deposit') ...const [
                        DropdownMenuItem(value: 'shares', child: Text('Shares')),
                        DropdownMenuItem(value: 'fixed_deposit', child: Text('Fixed Deposit')),
                        DropdownMenuItem(value: 'loan_payment', child: Text('Loan Payment')),
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
                    decoration: _dialogFieldDecoration(hint: 'Enter amount'),
                  ),
                  const SizedBox(height: 16),

                  // Payment method for deposits only
                  if (type == 'deposit') ...[
                    Text('How Does Customer Want to Pay?',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: paymentMethod,
                      decoration: _dialogFieldDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            paymentMethod = value;
                            if (value == 'Cash') {
                              selectedTelecom = null;
                              verifiedName = null;
                              phoneController.clear();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Mobile Money fields
                  if (type == 'deposit' && paymentMethod == 'Mobile Money') ...[
                    Text('Select Telecom Provider',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedTelecom,
                      decoration: _dialogFieldDecoration(),
                      hint: const Text('Choose provider'),
                      items: const [
                        DropdownMenuItem(value: 'MTN', child: Text('MTN Mobile Money')),
                        DropdownMenuItem(value: 'Airtel', child: Text('Airtel Money')),
                        DropdownMenuItem(value: 'Africell', child: Text('Africell Money')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedTelecom = value;
                          verifiedName = null;
                          phoneController.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    Text('Customer Phone Number',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _dialogFieldDecoration(
                        hint: '0712345678',
                        prefixText: '+256 ',
                        prefixStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        suffixIcon: verifyingPhone
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (value) async {
                        final cleaned = _localUgPhone(value);

                        // Only verify if we have 9 digits and a provider is selected
                        if (cleaned.length == 9 && selectedTelecom != null) {
                          setDialogState(() {
                            verifyingPhone = true;
                            verifiedName = null;
                          });

                          try {
                            final fullPhone = '+256$cleaned';
                            print('🔍 TELLER: Verifying phone: $fullPhone');

                            final result = await FirebaseService.verifyPhoneNumber(fullPhone);
                            print('🔍 TELLER: Phone verification result: $result');

                            if (result['success'] == true &&
                                result['full_name'] != null &&
                                result['full_name'].toString().trim().isNotEmpty) {
                              setDialogState(() {
                                verifiedName = result['full_name'];
                                verifyingPhone = false;
                              });
                            } else {
                              setDialogState(() {
                                verifiedName = null;
                                verifyingPhone = false;
                              });
                            }
                          } catch (e) {
                            print('❌ TELLER: Verification error: $e');
                            setDialogState(() {
                              verifiedName = null;
                              verifyingPhone = false;
                            });
                          }
                        } else if (cleaned.length < 9) {
                          // Clear verification if user deletes digits
                          setDialogState(() {
                            verifiedName = null;
                            verifyingPhone = false;
                          });
                        }
                      },
                    ),
                    if (verifiedName != null) ...[
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
                            Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Name:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    verifiedName!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  Text('Notes (Optional)', style: GoogleFonts.poppins(fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: _dialogFieldDecoration(hint: 'Add notes'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (type == 'deposit' && paymentMethod == 'Mobile Money' && verifiedName != null)
              ElevatedButton.icon(
                onPressed: () async {
                  final amount = int.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    _showMessageDialog(context,
                        title: 'Invalid Amount', message: 'Please enter a valid amount');
                    return;
                  }

                  if (phoneController.text.isEmpty || selectedTelecom == null) {
                    _showMessageDialog(context,
                        title: 'Missing Information',
                        message: 'Please provide phone number and select telecom provider');
                    return;
                  }

                  // Show loading dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => WillPopScope(
                      onWillPop: () async => false,
                      child: AlertDialog(
                        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Waiting for customer to enter PIN...',
                              style: GoogleFonts.poppins(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Customer should check their phone',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  try {
                    final fullPhone = '+256${_localUgPhone(phoneController.text)}';
                    print('💰 TELLER: Initiating payment for: $fullPhone');

                    final marzPayResult = await FirebaseService.marzPayCollect(
                      phoneNumber: fullPhone,
                      amount: amount,
                      description:
                          'Deposit to ${accountType.toUpperCase()} - ${_selectedMember!['name']}',
                    );

                    if (marzPayResult['status'] != 'success') {
                      Navigator.pop(context); // Close loading
                      _showMessageDialog(context,
                          title: 'Payment Failed',
                          message: marzPayResult['message'] ?? 'Failed to initiate payment');
                      return;
                    }

                    // STK push sent successfully, now poll for status
                    final uuid = marzPayResult['uuid'];
                    if (uuid == null || uuid.isEmpty) {
                      Navigator.pop(context); // Close loading
                      _showMessageDialog(context,
                          title: 'Error', message: 'No transaction reference received');
                      return;
                    }

                    // Poll for payment status (max 60 seconds, check every 3 seconds)
                    bool paymentComplete = false;
                    String finalStatus = 'pending';

                    for (int i = 0; i < 20; i++) {
                      await Future.delayed(const Duration(seconds: 3));

                      try {
                        final status = await FirebaseService.marzPayCheckStatus(uuid);
                        print('💰 Payment status check $i: $status');

                        if (status == 'completed') {
                          finalStatus = 'completed';
                          paymentComplete = true;
                          break;
                        } else if (status == 'failed') {
                          finalStatus = 'failed';
                          break;
                        }
                        // Continue polling for 'pending' or 'processing'
                      } catch (e) {
                        print('❌ Status check error: $e');
                        // Continue polling even on error
                      }
                    }

                    Navigator.pop(context); // Close loading

                    if (paymentComplete && finalStatus == 'completed') {
                      _showMessageDialog(context,
                          title: 'Payment Successful!',
                          message: 'Now click "Save Payment" to record it',
                          icon: Icons.check_circle,
                          color: ModernTheme.success);
                    } else if (finalStatus == 'failed') {
                      _showMessageDialog(context,
                          title: 'Payment Failed',
                          message: 'Customer cancelled or payment failed');
                    } else {
                      _showMessageDialog(context,
                          title: 'Payment Pending',
                          message:
                              'Payment is taking longer than expected. Check status later before recording.',
                          icon: Icons.info_outline,
                          color: Colors.orange);
                    }
                  } catch (e) {
                    Navigator.pop(context); // Close loading
                    _showMessageDialog(context, title: 'Error', message: 'Error: ${e.toString()}');
                  }
                },
                icon: const Icon(Icons.phone_android),
                label: const Text('Initiate Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.black,
                ),
              ),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  _showMessageDialog(context,
                      title: 'Invalid Amount', message: 'Please enter a valid amount');
                  return;
                }

                Navigator.pop(context);

                // Format phone number before saving
                String? formattedPhoneForSave;
                if (phoneController.text.isNotEmpty) {
                  formattedPhoneForSave = '+256${_localUgPhone(phoneController.text)}';
                }

                _processTransaction(
                  type,
                  accountType,
                  amount,
                  notesController.text,
                  paymentMethod: paymentMethod,
                  telecomProvider: selectedTelecom,
                  phoneNumber: formattedPhoneForSave,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'deposit' ? ModernTheme.success : ModernTheme.error,
              ),
              child: Text(type == 'deposit' ? 'Save Payment' : 'Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processTransaction(
    String type,
    String accountType,
    int amount,
    String notes, {
    String? paymentMethod,
    String? telecomProvider,
    String? phoneNumber,
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Flexible(child: Text('Processing...', style: GoogleFonts.poppins())),
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
              tillSession: null, // TODO: Pass actual till session in Phase 3
              notes: notes,
              paymentMethod: paymentMethod,
              telecomProvider: telecomProvider,
              phoneNumber: phoneNumber,
            )
          : await TellerService.processWithdrawal(
              memberId: _selectedMember!['id'],
              memberName: _selectedMember!['name'],
              memberPhone: _selectedMember!['phone'],
              amount: amount,
              accountType: accountType,
              tellerName: FirebaseService.sessionProfile?['name'] ?? 'Admin',
              tellerId: FirebaseService.sessionUid,
              tillSession: null, // TODO: Pass actual till session in Phase 3
              notes: notes,
            );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success']) {
        _showReceipt(result['transaction']);
        _selectMember(_selectedMember!['id']); // Refresh member details
      } else {
        _showMessageDialog(context,
            title: 'Transaction Failed', message: '${result['message']}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      _showMessageDialog(context, title: 'Error', message: 'Error: ${e.toString()}');
    }
  }

  void _showReceipt(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ModernTheme.success, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Transaction Successful',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: _dialogWidth(context),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReceiptRow('Receipt No.', '${transaction['receiptNumber']}'),
                _buildReceiptRow('Type', transaction['type'].toString().toUpperCase()),
                _buildReceiptRow('Member', '${transaction['memberName']}'),
                _buildReceiptRow('Account', transaction['accountType'].toString().toUpperCase()),
                _buildReceiptRow('Amount', 'UGX ${widget.fmt.format(transaction['amount'])}'),
                if (transaction['paymentMethod'] != null)
                  _buildReceiptRow('Payment Method', '${transaction['paymentMethod']}'),
                if (transaction['telecomProvider'] != null)
                  _buildReceiptRow('Telecom', '${transaction['telecomProvider']}'),
                if (transaction['phoneNumber'] != null)
                  _buildReceiptRow('Phone Number', '${transaction['phoneNumber']}'),
                _buildReceiptRow('Teller', '${transaction['tellerName']}'),
                _buildReceiptRow(
                  'Date & Time',
                  DateFormat('dd/MM/yyyy HH:mm').format(transaction['timestamp']),
                ),
                if (transaction['notes']?.isNotEmpty ?? false)
                  _buildReceiptRow('Notes', '${transaction['notes']}'),
              ],
            ),
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
            width: 105,
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

    final transactions = await TellerService.getTransactionHistory(
      // Don't filter by teller - show ALL transactions
      limit: 100,
    );

    print('🔍 TELLER: Found ${transactions.length} transactions');

    if (mounted) {
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = _pagePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Amount column never takes more than ~38% of the card
    final maxAmountWidth = (screenWidth < _kMaxContentWidth ? screenWidth : _kMaxContentWidth) * 0.38;

    return _ResponsiveCenter(
      child: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
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
                final color = isDeposit ? ModernTheme.success : ModernTheme.error;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
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
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDeposit ? Icons.add_circle : Icons.remove_circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${txn['memberName']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${txn['accountType'].toString().toUpperCase()} • ${txn['receiptNumber']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxAmountWidth),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${isDeposit ? '+' : '-'} UGX ${widget.fmt.format(txn['amount'])}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2, end: 0);
              }).toList(),
          ],
        ),
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

    final summary = await TellerService.getDailySummary(
      // Show ALL transactions for the day, not just this teller's
      date: _selectedDate,
    );

    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = _pagePadding(context);

    return _ResponsiveCenter(
      child: ListView(
        padding: EdgeInsets.all(pad),
        children: [
          // Title + date picker (wraps on small screens)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Text(
                'Daily Summary',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
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
              width: double.infinity,
              padding: EdgeInsets.all(_isNarrow(context) ? 18 : 24),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'UGX ${widget.fmt.format(_summary!['netCashFlow'])}',
                      style: GoogleFonts.poppins(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        color: _summary!['netCashFlow'] >= 0
                            ? ModernTheme.success
                            : ModernTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary cards: 3 across on wide screens, stacked on narrow
            LayoutBuilder(builder: (ctx, c) {
              final deposits = _buildSummaryCard(
                'Deposits',
                '${_summary!['deposits']['count']}',
                'UGX ${widget.fmt.format(_summary!['deposits']['amount'])}',
                Icons.add_circle,
                ModernTheme.success,
              );
              final withdrawals = _buildSummaryCard(
                'Withdrawals',
                '${_summary!['withdrawals']['count']}',
                'UGX ${widget.fmt.format(_summary!['withdrawals']['amount'])}',
                Icons.remove_circle,
                ModernTheme.error,
              );
              final total = _buildSummaryCard(
                'Total Transactions',
                '${_summary!['totalTransactions']}',
                '',
                Icons.receipt_long,
                ModernTheme.info,
              );

              if (c.maxWidth >= 720) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: deposits),
                      const SizedBox(width: 12),
                      Expanded(child: withdrawals),
                      const SizedBox(width: 12),
                      Expanded(child: total),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  deposits,
                  const SizedBox(height: 12),
                  withdrawals,
                  const SizedBox(height: 12),
                  total,
                ],
              );
            }),
          ],
        ],
      ),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amount,
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
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
      final banks = await FirebaseService.getBankList();
      print('🏦 Loaded ${banks.length} banks');

      if (!mounted) return;
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

      if (settings.exists && mounted) {
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
          _showMessageDialog(
            context,
            title: 'Account Verified',
            message: result['account_name'],
            icon: Icons.check_circle,
            color: Colors.green.shade600,
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Could not verify account name');
      }
    } catch (e) {
      print('❌ Verification error: $e');
      if (mounted) {
        setState(() => _verifying = false);

        String errorMessage = 'Could not verify account';
        final err = e.toString().toLowerCase();
        if (err.contains('invalid')) {
          errorMessage = 'Invalid account number';
        } else if (err.contains('timeout')) {
          errorMessage = 'Request timed out';
        } else if (err.contains('network')) {
          errorMessage = 'Network error';
        }

        _showMessageDialog(
          context,
          title: 'Verification Failed',
          message: errorMessage,
          color: Colors.red.shade600,
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text('Confirm Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: _dialogWidth(context),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: UGX ${widget.fmt.format(int.parse(_amountController.text))}'),
                const SizedBox(height: 8),
                Text('To: ${_verifiedAccount!['account_name']}'),
                Text('Account: ${_accountNumberController.text}'),
                Text('Bank: ${_banks.firstWhere((b) => b['code'] == _selectedBank)['name']}'),
                const SizedBox(height: 12),
                const Text(
                    'This will transfer money from SACCOPLUS to the member\'s bank account.'),
              ],
            ),
          ),
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

        _showMessageDialog(
          context,
          title: 'Transfer Successful',
          message: 'Reference: $reference',
          icon: Icons.check_circle,
          color: Colors.green.shade600,
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
        String errorMessage = 'Transfer could not be completed';
        final err = e.toString().toLowerCase();
        if (err.contains('insufficient')) {
          errorMessage = 'Insufficient balance';
        } else if (err.contains('timeout')) {
          errorMessage = 'Request timed out';
        } else if (err.contains('network')) {
          errorMessage = 'Network error';
        }

        _showMessageDialog(
          context,
          title: 'Transfer Failed',
          message: errorMessage,
          color: Colors.red.shade600,
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
    final pad = _pagePadding(context);

    return _ResponsiveCenter(
      maxWidth: 700,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SACCO Bank Info Card
              if (_saccoAccountNumber != null)
                Container(
                  width: double.infinity,
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
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
                  isExpanded: true,
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
                      child: Text(
                        bank['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
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

              // Account Number + Verify Button
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _verifying ? null : _verifyAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _verifiedAccount != null ? Colors.green : ModernTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  ),
                ],
              ),
              if (_verifiedAccount != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
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
      ),
    );
  }
}
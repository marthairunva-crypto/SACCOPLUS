import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../models/till_session.dart';
import '../../models/till_entry.dart';
import '../../services/till_service.dart';

/// Till Reports Screen - View and export till session reports
class TillReportsScreen extends StatefulWidget {
  final bool embedded;
  
  const TillReportsScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<TillReportsScreen> createState() => _TillReportsScreenState();
}

class _TillReportsScreenState extends State<TillReportsScreen> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _timeFormat = DateFormat('hh:mm a');
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _statusFilter = 'all'; // all, open, closed, pending_approval
  String? _tellerFilter;
  
  List<Map<String, dynamic>> _tellers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTellers();
  }

  Future<void> _loadTellers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.staffCol)
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('role', isEqualTo: 'teller')
          .get();
      
      setState(() {
        _tellers = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
        }).toList();
        _loading = false;
      });
    } catch (e) {
      print('Error loading tellers: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _buildFilters(),
        Expanded(child: _buildReportContent()),
      ],
    );

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF6F8FB),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(
          'Till Reports',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: body,
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateFilter(
                  'Start Date',
                  _startDate,
                  (date) => setState(() => _startDate = date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateFilter(
                  'End Date',
                  _endDate,
                  (date) => setState(() => _endDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    DropdownMenuItem(value: 'pending_approval', child: Text('Pending Approval')),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _tellerFilter,
                  decoration: InputDecoration(
                    labelText: 'Teller',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Tellers')),
                    ..._tellers.map((t) => DropdownMenuItem(
                      value: t['id'],
                      child: Text(t['name']),
                    )),
                  ],
                  onChanged: (value) => setState(() => _tellerFilter = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(String label, DateTime date, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateFormat.format(date)),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data!.docs
            .map((doc) => TillSession.fromFirestore(doc))
            .toList();

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No till sessions found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildSummaryCards(sessions),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length,
                itemBuilder: (context, index) => _buildSessionCard(sessions[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    var query = FirebaseFirestore.instance
        .collection(AppConstants.tillSessionsCol)
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .where('openedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('openedAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate.add(const Duration(days: 1))));

    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    if (_tellerFilter != null) {
      query = query.where('tellerId', isEqualTo: _tellerFilter);
    }

    return query.orderBy('openedAt', descending: true).snapshots();
  }

  Widget _buildSummaryCards(List<TillSession> sessions) {
    final totalSessions = sessions.length;
    final openSessions = sessions.where((s) => s.status == 'open').length;
    final closedSessions = sessions.where((s) => s.status == 'closed').length;
    final pendingSessions = sessions.where((s) => s.status == 'pending_approval').length;
    
    final totalCash = sessions
        .where((s) => s.status == 'closed')
        .fold(0, (sum, s) => sum + (s.actualCash ?? 0));
    
    final totalVariance = sessions
        .where((s) => s.status == 'closed')
        .fold(0, (sum, s) => sum + (s.variance ?? 0));

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildSummaryCard('Total Sessions', '$totalSessions', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryCard('Open', '$openSessions', Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryCard('Closed', '$closedSessions', Colors.grey)),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryCard('Pending', '$pendingSessions', Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Cash',
                  'UGX ${_currencyFormat.format(totalCash)}',
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Total Variance',
                  'UGX ${_currencyFormat.format(totalVariance)}',
                  totalVariance < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(TillSession session) {
    final statusColor = session.status == 'open'
        ? Colors.green
        : session.status == 'pending_approval'
            ? Colors.orange
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      session.status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _dateFormat.format(session.openedAt),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    session.tellerName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSessionInfo('Opening', session.openingFloat),
                  ),
                  Expanded(
                    child: _buildSessionInfo('In', session.totalIn, Colors.green),
                  ),
                  Expanded(
                    child: _buildSessionInfo('Out', session.totalOut, Colors.red),
                  ),
                  Expanded(
                    child: _buildSessionInfo('Expected', session.expectedCash, Colors.blue),
                  ),
                ],
              ),
              if (session.actualCash != null) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSessionInfo('Actual', session.actualCash!, Colors.teal),
                    ),
                    Expanded(
                      child: _buildSessionInfo(
                        'Variance',
                        session.variance ?? 0,
                        (session.variance ?? 0) < 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfo(String label, int amount, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _showSessionDetails(TillSession session) async {
    // Load entries for this session
    final entries = await TillService.getSessionEntries(session.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Till Session Details',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            session.tellerName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDetailSection('Session Info', [
                      _buildDetailRow('Status', session.status.toUpperCase()),
                      _buildDetailRow('Business Date', session.businessDate),
                      _buildDetailRow('Opened At', '${_dateFormat.format(session.openedAt)} ${_timeFormat.format(session.openedAt)}'),
                      if (session.closedAt != null)
                        _buildDetailRow('Closed At', '${_dateFormat.format(session.closedAt!)} ${_timeFormat.format(session.closedAt!)}'),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Cash Summary', [
                      _buildDetailRow('Opening Float', 'UGX ${_currencyFormat.format(session.openingFloat)}'),
                      _buildDetailRow('Total In', 'UGX ${_currencyFormat.format(session.totalIn)}', Colors.green),
                      _buildDetailRow('Total Out', 'UGX ${_currencyFormat.format(session.totalOut)}', Colors.red),
                      _buildDetailRow('Expected Cash', 'UGX ${_currencyFormat.format(session.expectedCash)}', Colors.blue),
                      if (session.actualCash != null) ...[
                        const Divider(),
                        _buildDetailRow('Actual Cash', 'UGX ${_currencyFormat.format(session.actualCash!)}', Colors.teal),
                        _buildDetailRow(
                          'Variance',
                          'UGX ${_currencyFormat.format(session.variance!)}',
                          (session.variance ?? 0) < 0 ? Colors.red : Colors.green,
                        ),
                      ],
                    ]),
                    if (entries.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Transactions (${entries.length})',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...entries.map((entry) => _buildEntryCard(entry)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(TillEntry entry) {
    final isPositive = entry.amount > 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isPositive ? Icons.add : Icons.remove,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          entry.entryType.replaceAll('_', ' ').toUpperCase(),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${entry.memberName ?? ''} • ${_timeFormat.format(entry.createdAt)}',
          style: GoogleFonts.inter(fontSize: 10),
        ),
        trailing: Text(
          'UGX ${_currencyFormat.format(entry.amount.abs())}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

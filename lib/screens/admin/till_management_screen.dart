import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../models/till_session.dart';
import '../../models/till_entry.dart';
import '../../services/till_service.dart';

/// Till Management Screen - Open, Close, and Manage Till Sessions
class TillManagementScreen extends StatefulWidget {
  final bool embedded;
  
  const TillManagementScreen({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<TillManagementScreen> createState() => _TillManagementScreenState();
}

class _TillManagementScreenState extends State<TillManagementScreen> {
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _timeFormat = DateFormat('hh:mm a');
  
  @override
  Widget build(BuildContext context) {
    final body = StreamBuilder<TillSession?>(
      stream: TillService.watchOpenSession(FirebaseService.sessionUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final session = snapshot.data;

        if (session == null) {
          return _buildNoSessionView();
        }

        return _buildActiveSessionView(session);
      },
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
          'Till Management',
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

  Widget _buildNoSessionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: 60,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Till Session',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to open your till before processing transactions',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showOpenTillDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Open Till'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionView(TillSession session) {
    return StreamBuilder<List<TillEntry>>(
      stream: TillService.watchSessionEntries(session.id),
      builder: (context, entriesSnapshot) {
        final entries = entriesSnapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSessionHeader(session),
              const SizedBox(height: 16),
              _buildCashSummaryCard(session),
              const SizedBox(height: 16),
              _buildActionsCard(session),
              const SizedBox(height: 16),
              _buildTransactionsList(entries),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionHeader(TillSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'OPEN',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                session.businessDate,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session.tellerName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Opened at ${_timeFormat.format(session.openedAt)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSummaryCard(TillSession session) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cash Summary',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Opening Float', session.openingFloat, Colors.grey),
            const Divider(height: 24),
            _buildSummaryRow('Cash In', session.totalIn, Colors.green),
            _buildSummaryRow('Cash Out', session.totalOut, Colors.red),
            const Divider(height: 24),
            _buildSummaryRow(
              'Expected Cash',
              session.expectedCash,
              const Color(0xFF1E3A8A),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int amount, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black87 : Colors.grey[700],
            ),
          ),
          Text(
            'UGX ${_currencyFormat.format(amount)}',
            style: GoogleFonts.inter(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(TillSession session) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Till Actions',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Close Till',
                    Icons.lock,
                    Colors.red,
                    () => _showCloseTillDialog(session),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Top Up',
                    Icons.arrow_downward,
                    Colors.green,
                    () => _showVaultTopUpDialog(session),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Sweep',
                    Icons.arrow_upward,
                    Colors.orange,
                    () => _showVaultSweepDialog(session),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'View Report',
                    Icons.description,
                    Colors.blue,
                    () {
                      // Navigate to reports
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<TillEntry> entries) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Transactions (${entries.length})',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
              )
            else
              ...entries.map((entry) => _buildEntryTile(entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(TillEntry entry) {
    final isPositive = entry.amount > 0;
    final color = isPositive ? Colors.green : Colors.red;

    return ListTile(
      contentPadding: EdgeInsets.zero,
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
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${entry.memberName ?? 'System'} • ${_timeFormat.format(entry.createdAt)}',
        style: GoogleFonts.inter(fontSize: 11),
      ),
      trailing: Text(
        'UGX ${_currencyFormat.format(entry.amount.abs())}',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showOpenTillDialog() async {
    final openingFloatController = TextEditingController(text: '100000');
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Open Till',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: openingFloatController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Opening Float (UGX)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: 'UGX ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Open Till'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _showLoading('Opening till...');
      
      try {
        final openingFloat = int.tryParse(openingFloatController.text) ?? 0;
        
        await TillService.openSession(
          tellerId: FirebaseService.sessionUid,
          tellerName: FirebaseService.sessionProfile?['name'] ?? 'Teller',
          openingFloat: openingFloat,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context); // Close loading
          _showSuccess('Till opened successfully!');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          _showError(e.toString());
        }
      }
    }
  }

  Future<void> _showCloseTillDialog(TillSession session) async {
    final denominations = <String, int>{
      '50000': 0,
      '20000': 0,
      '10000': 0,
      '5000': 0,
      '2000': 0,
      '1000': 0,
    };

    final controllers = <String, TextEditingController>{};
    for (final denom in denominations.keys) {
      controllers[denom] = TextEditingController(text: '0');
    }

    final varianceReasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate total from denominations
          int totalCounted = 0;
          denominations.forEach((denom, count) {
            totalCounted += int.parse(denom) * count;
          });

          return AlertDialog(
            title: Text(
              'Close Till - Count Cash',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Counted:',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'UGX ${_currencyFormat.format(totalCounted)}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Count each denomination:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...denominations.keys.map((denom) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'UGX ${_currencyFormat.format(int.parse(denom))}',
                                style: GoogleFonts.inter(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: controllers[denom],
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  hintText: '0',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) {
                                  setDialogState(() {
                                    denominations[denom] = int.tryParse(value) ?? 0;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                '= ${_currencyFormat.format(int.parse(denom) * denominations[denom]!)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: varianceReasonController,
                      decoration: InputDecoration(
                        labelText: 'Variance Reason (if any)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'Explain any variance...',
                      ),
                      maxLines: 2,
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
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _showLoading('Closing till...');

                  try {
                    final result = await TillService.closeSession(
                      tillSessionId: session.id,
                      tellerId: FirebaseService.sessionUid,
                      denominations: denominations,
                      varianceReason: varianceReasonController.text.trim().isEmpty
                          ? null
                          : varianceReasonController.text.trim(),
                    );

                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      
                      if (result.needsApproval) {
                        _showWarning(
                          'Till closed - Variance of UGX ${_currencyFormat.format(result.variance.abs())} requires supervisor approval',
                        );
                      } else {
                        _showSuccess('Till closed successfully!');
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      _showError(e.toString());
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Close Till'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showVaultTopUpDialog(TillSession session) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Vault Top-Up',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount (UGX)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: 'UGX ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Top Up'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _showLoading('Processing top-up...');
      
      try {
        final amount = int.tryParse(amountController.text) ?? 0;
        
        await TillService.vaultTopUp(
          tillSessionId: session.id,
          amount: amount,
          tellerId: FirebaseService.sessionUid,
          tellerName: FirebaseService.sessionProfile?['name'] ?? 'Teller',
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context); // Close loading
          _showSuccess('Top-up successful!');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          _showError(e.toString());
        }
      }
    }
  }

  Future<void> _showVaultSweepDialog(TillSession session) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Vault Sweep',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Available: UGX ${_currencyFormat.format(session.expectedCash)}',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Amount (UGX)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: 'UGX ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sweep'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _showLoading('Processing sweep...');
      
      try {
        final amount = int.tryParse(amountController.text) ?? 0;
        
        await TillService.vaultSweep(
          tillSessionId: session.id,
          amount: amount,
          tellerId: FirebaseService.sessionUid,
          tellerName: FirebaseService.sessionProfile?['name'] ?? 'Teller',
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context); // Close loading
          _showSuccess('Sweep successful!');
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          _showError(e.toString());
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

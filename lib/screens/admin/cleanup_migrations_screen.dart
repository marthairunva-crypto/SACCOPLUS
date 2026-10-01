import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';

class CleanupMigrationsScreen extends StatefulWidget {
  const CleanupMigrationsScreen({super.key});

  @override
  State<CleanupMigrationsScreen> createState() => _CleanupMigrationsScreenState();
}

class _CleanupMigrationsScreenState extends State<CleanupMigrationsScreen> {
  bool _isProcessing = false;
  final List<String> _logs = [];
  int _deletedSavings = 0;
  int _deletedShares = 0;
  int _deletedLoans = 0;
  int _resetMembers = 0;

  void _addLog(String message) {
    setState(() => _logs.add(message));
  }

  Future<void> _cleanupAllMigrations() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Cleanup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will:\n\n'
          '• Delete ALL savings transaction records\n'
          '• Delete ALL shares transaction records\n'
          '• Delete ALL loan records\n'
          '• Reset ALL member balances to 0\n\n'
          'You will need to re-import your CSV files after this.\n\n'
          'Are you sure you want to continue?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _logs.clear();
      _deletedSavings = 0;
      _deletedShares = 0;
      _deletedLoans = 0;
      _resetMembers = 0;
    });

    try {
      final db = FirebaseFirestore.instance;
      final tenantId = FirebaseService.sessionTenantId;

      _addLog('🧹 Starting cleanup...');
      _addLog('🏢 Tenant: $tenantId\n');

      // 1. Delete savings transactions
      _addLog('💰 Deleting savings transactions...');
      final savingsSnapshot = await db
          .collection('saccoplus-savings')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in savingsSnapshot.docs) {
        await doc.reference.delete();
        _deletedSavings++;
        if (_deletedSavings % 10 == 0) {
          _addLog('   Deleted $_deletedSavings savings records...');
        }
      }
      _addLog('✅ Deleted $_deletedSavings savings records\n');

      // 2. Delete shares transactions
      _addLog('📊 Deleting shares transactions...');
      final sharesSnapshot = await db
          .collection('saccoplus-shares')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in sharesSnapshot.docs) {
        await doc.reference.delete();
        _deletedShares++;
        if (_deletedShares % 10 == 0) {
          _addLog('   Deleted $_deletedShares shares records...');
        }
      }
      _addLog('✅ Deleted $_deletedShares shares records\n');

      // 3. Delete loans
      _addLog('🏦 Deleting loan records...');
      final loansSnapshot = await db
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in loansSnapshot.docs) {
        await doc.reference.delete();
        _deletedLoans++;
        if (_deletedLoans % 10 == 0) {
          _addLog('   Deleted $_deletedLoans loan records...');
        }
      }
      _addLog('✅ Deleted $_deletedLoans loan records\n');

      // 4. Reset member balances
      _addLog('👥 Resetting member balances...');
      final membersSnapshot = await db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in membersSnapshot.docs) {
        await doc.reference.update({
          'savingsBalance': 0.0,
          'sharesBalance': 0.0,
          'loanBalance': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _resetMembers++;
        if (_resetMembers % 10 == 0) {
          _addLog('   Reset $_resetMembers members...');
        }
      }
      _addLog('✅ Reset $_resetMembers member balances\n');

      _addLog('✅ Cleanup Complete!');
      _addLog('📊 Summary:');
      _addLog('   • Savings deleted: $_deletedSavings');
      _addLog('   • Shares deleted: $_deletedShares');
      _addLog('   • Loans deleted: $_deletedLoans');
      _addLog('   • Members reset: $_resetMembers');
      _addLog('\n🎯 You can now re-import your CSV files with the fixed parser!');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _cleanupSavingsOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Savings Cleanup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will:\n\n'
          '• Delete ALL savings transaction records\n'
          '• Reset savingsBalance to 0 for all members\n\n'
          'Shares and loans will NOT be affected.\n\n'
          'Continue?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Delete Savings Only'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _logs.clear();
      _deletedSavings = 0;
      _resetMembers = 0;
    });

    try {
      final db = FirebaseFirestore.instance;
      final tenantId = FirebaseService.sessionTenantId;

      _addLog('💰 Cleaning up savings only...\n');

      // Delete savings transactions
      final savingsSnapshot = await db
          .collection('saccoplus-savings')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in savingsSnapshot.docs) {
        await doc.reference.delete();
        _deletedSavings++;
        if (_deletedSavings % 10 == 0) {
          _addLog('Deleted $_deletedSavings savings records...');
        }
      }

      // Reset savingsBalance only
      final membersSnapshot = await db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in membersSnapshot.docs) {
        await doc.reference.update({
          'savingsBalance': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _resetMembers++;
      }

      _addLog('\n✅ Savings cleanup complete!');
      _addLog('   • Savings deleted: $_deletedSavings');
      _addLog('   • Members reset: $_resetMembers');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _cleanupSharesOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Shares Cleanup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will:\n\n'
          '• Delete ALL shares transaction records\n'
          '• Reset sharesBalance to 0 for all members\n\n'
          'Savings and loans will NOT be affected.\n\n'
          'Continue?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Delete Shares Only'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _logs.clear();
      _deletedShares = 0;
      _resetMembers = 0;
    });

    try {
      final db = FirebaseFirestore.instance;
      final tenantId = FirebaseService.sessionTenantId;

      _addLog('📊 Cleaning up shares only...\n');

      // Delete shares transactions
      final sharesSnapshot = await db
          .collection('saccoplus-shares')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in sharesSnapshot.docs) {
        await doc.reference.delete();
        _deletedShares++;
        if (_deletedShares % 10 == 0) {
          _addLog('Deleted $_deletedShares shares records...');
        }
      }

      // Reset sharesBalance only
      final membersSnapshot = await db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in membersSnapshot.docs) {
        await doc.reference.update({
          'sharesBalance': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _resetMembers++;
      }

      _addLog('\n✅ Shares cleanup complete!');
      _addLog('   • Shares deleted: $_deletedShares');
      _addLog('   • Members reset: $_resetMembers');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _cleanupLoansOnly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Loans Cleanup', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will:\n\n'
          '• Delete ALL loan records\n'
          '• Reset loanBalance to 0 for all members\n\n'
          'Savings and shares will NOT be affected.\n\n'
          'Continue?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Delete Loans Only'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
      _logs.clear();
      _deletedLoans = 0;
      _resetMembers = 0;
    });

    try {
      final db = FirebaseFirestore.instance;
      final tenantId = FirebaseService.sessionTenantId;

      _addLog('🏦 Cleaning up loans only...\n');

      // Delete loans
      final loansSnapshot = await db
          .collection('saccoplus-loans')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in loansSnapshot.docs) {
        await doc.reference.delete();
        _deletedLoans++;
        if (_deletedLoans % 10 == 0) {
          _addLog('Deleted $_deletedLoans loan records...');
        }
      }

      // Reset loanBalance only
      final membersSnapshot = await db
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      for (final doc in membersSnapshot.docs) {
        await doc.reference.update({
          'loanBalance': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _resetMembers++;
      }

      _addLog('\n✅ Loans cleanup complete!');
      _addLog('   • Loans deleted: $_deletedLoans');
      _addLog('   • Members reset: $_resetMembers');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Cleanup Migrations', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danger Zone',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These actions will delete imported data and reset balances. '
                          'Use this to clean up bad imports caused by the CSV parser bug, '
                          'then re-import with the fixed parser.',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.red.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _cleanupAllMigrations,
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('Delete All (Savings + Shares + Loans)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _cleanupSavingsOnly,
                  icon: const Icon(Icons.savings),
                  label: const Text('Delete Savings Only'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _cleanupSharesOnly,
                  icon: const Icon(Icons.pie_chart),
                  label: const Text('Delete Shares Only'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _cleanupLoansOnly,
                  icon: const Icon(Icons.account_balance),
                  label: const Text('Delete Loans Only'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Logs
            Text(
              'Activity Log',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _logs.isEmpty
                    ? Center(
                        child: Text(
                          'No cleanup operations yet',
                          style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              _logs[index],
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                color: _logs[index].startsWith('❌')
                                    ? Colors.red.shade300
                                    : _logs[index].startsWith('✅')
                                        ? Colors.green.shade300
                                        : Colors.grey.shade300,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';

class FixSharesBalancesScreen extends StatefulWidget {
  const FixSharesBalancesScreen({super.key});

  @override
  State<FixSharesBalancesScreen> createState() => _FixSharesBalancesScreenState();
}

class _FixSharesBalancesScreenState extends State<FixSharesBalancesScreen> {
  bool _isProcessing = false;
  final List<String> _logs = [];
  int _totalChecked = 0;
  int _savingsFixed = 0;
  int _sharesFixed = 0;
  int _loansFixed = 0;

  final _currencyFormat = NumberFormat('#,###', 'en_US');

  Future<void> _fixAllBalances() async {
    setState(() {
      _isProcessing = true;
      _logs.clear();
      _totalChecked = 0;
      _savingsFixed = 0;
      _sharesFixed = 0;
      _loansFixed = 0;
    });

    _addLog('🔍 Starting balance recalculation for ALL members...');
    _addLog('Tenant: ${FirebaseService.sessionTenantId}');

    try {
      // Get all members
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .get();

      _addLog('📊 Found ${membersSnapshot.docs.length} members\n');

      for (final memberDoc in membersSnapshot.docs) {
        final memberId = memberDoc.id;
        final memberData = memberDoc.data();
        final memberName = memberData['name'] ?? memberData['fullName'] ?? 'Unknown';
        
        final currentSavings = (memberData['savingsBalance'] ?? 0).toDouble();
        final currentShares = (memberData['sharesBalance'] ?? 0).toDouble();
        final currentLoans = (memberData['loanBalance'] ?? 0).toDouble();

        // Calculate actual savings from transactions
        final savingsSnapshot = await FirebaseFirestore.instance
            .collection('saccoplus-savings')
            .where('farmerId', isEqualTo: memberId)
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .get();
        
        double actualSavings = 0;
        for (final doc in savingsSnapshot.docs) {
          actualSavings += (doc.data()['amount'] ?? 0).toDouble();
        }

        // Calculate actual shares from transactions
        final sharesSnapshot = await FirebaseFirestore.instance
            .collection('saccoplus-shares')
            .where('farmerId', isEqualTo: memberId)
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .get();
        
        double actualShares = 0;
        for (final doc in sharesSnapshot.docs) {
          actualShares += (doc.data()['amount'] ?? 0).toDouble();
        }

        // Calculate actual loan balance from loans
        final loansSnapshot = await FirebaseFirestore.instance
            .collection('saccoplus-loans')
            .where('farmerId', isEqualTo: memberId)
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .get();
        
        double actualLoans = 0;
        for (final doc in loansSnapshot.docs) {
          actualLoans += (doc.data()['principalOutstanding'] ?? 0).toDouble();
        }

        _totalChecked++;

        // Check if any balance needs updating
        bool needsUpdate = false;
        final Map<String, dynamic> updates = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (currentSavings != actualSavings) {
          updates['savingsBalance'] = actualSavings;
          needsUpdate = true;
          _savingsFixed++;
        }

        if (currentShares != actualShares) {
          updates['sharesBalance'] = actualShares;
          needsUpdate = true;
          _sharesFixed++;
        }

        if (currentLoans != actualLoans) {
          updates['loanBalance'] = actualLoans;
          needsUpdate = true;
          _loansFixed++;
        }

        if (needsUpdate) {
          _addLog('👤 $memberName');
          
          if (currentSavings != actualSavings) {
            _addLog('   💰 Savings: UGX ${_currencyFormat.format(currentSavings)} → ${_currencyFormat.format(actualSavings)}');
            if (actualSavings == 0 && currentSavings > 0) {
              _addLog('      ⚠️ Cleared incorrect balance (no transactions)');
            }
          }
          
          if (currentShares != actualShares) {
            _addLog('   📊 Shares: UGX ${_currencyFormat.format(currentShares)} → ${_currencyFormat.format(actualShares)}');
            if (actualShares == 0 && currentShares > 0) {
              _addLog('      ⚠️ Cleared incorrect balance (no transactions)');
            }
          }
          
          if (currentLoans != actualLoans) {
            _addLog('   🏦 Loans: UGX ${_currencyFormat.format(currentLoans)} → ${_currencyFormat.format(actualLoans)}');
          }

          await FirebaseFirestore.instance
              .collection('saccoplus-members')
              .doc(memberId)
              .update(updates);
          
          _addLog('   ✅ Updated\n');
        }
      }

      _addLog('\n✅ COMPLETE!');
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━');
      _addLog('Total members checked: $_totalChecked');
      _addLog('Savings balances fixed: $_savingsFixed');
      _addLog('Shares balances fixed: $_sharesFixed');
      _addLog('Loan balances fixed: $_loansFixed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Fixed balances for $_savingsFixed savings, $_sharesFixed shares, $_loansFixed loans'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      _addLog('\n❌ ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Fix All Balances', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Text(
                        'Balance Recalculation Tool',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This tool fixes incorrect balances from CSV migration:\n\n'
                    '💰 Savings: Recalculates from saccoplus-savings transactions\n'
                    '📊 Shares: Recalculates from saccoplus-shares transactions\n'
                    '🏦 Loans: Recalculates from saccoplus-loans outstanding\n\n'
                    '⚠️ Members with no transactions will have balances cleared to 0',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.orange.shade800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Fix Button
            if (!_isProcessing)
              ElevatedButton.icon(
                onPressed: _fixAllBalances,
                icon: const Icon(Icons.auto_fix_high),
                label: Text('Fix All Member Balances', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                ),
              ),

            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Processing $_totalChecked members...\nFixed: $_savingsFixed savings, $_sharesFixed shares, $_loansFixed loans',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Logs
            if (_logs.isNotEmpty) ...[
              Text(
                'Activity Log:',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[index],
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: Colors.greenAccent.shade100,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

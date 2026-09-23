import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/modern_theme.dart';
import '../../core/firebase_service.dart';

class DormantAccountsScreen extends StatefulWidget {
  const DormantAccountsScreen({super.key});

  @override
  State<DormantAccountsScreen> createState() => _DormantAccountsScreenState();
}

class _DormantAccountsScreenState extends State<DormantAccountsScreen> {
  int _dormancyPeriodMonths = 6; // Default dormancy period

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Dormant Accounts', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _dormancyPeriodMonths,
                items: [3, 6, 9, 12].map((months) {
                  return DropdownMenuItem(
                    value: months,
                    child: Text('$months months', style: GoogleFonts.poppins(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _dormancyPeriodMonths = value!);
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInfoBanner(),
          Expanded(child: _buildDormantAccountsList()),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dormant Account Criteria',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Accounts with no transactions in the last $_dormancyPeriodMonths months',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDormantAccountsList() {
    final cutoffDate = DateTime.now().subtract(Duration(days: _dormancyPeriodMonths * 30));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('farmers')
          .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!.docs;

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _findDormantAccounts(members, cutoffDate),
          builder: (context, dormantSnapshot) {
            if (!dormantSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final dormantAccounts = dormantSnapshot.data!;

            if (dormantAccounts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No dormant accounts found',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'All member accounts are active',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: dormantAccounts.length,
              itemBuilder: (context, index) {
                return _buildDormantAccountCard(dormantAccounts[index]);
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _findDormantAccounts(
    List<QueryDocumentSnapshot> members,
    DateTime cutoffDate,
  ) async {
    final List<Map<String, dynamic>> dormantAccounts = [];

    for (var memberDoc in members) {
      final memberId = memberDoc.id;
      final memberData = memberDoc.data() as Map<String, dynamic>;

      // Check last transaction date across savings, shares, and loans
      final lastActivity = await _getLastActivityDate(memberId);

      if (lastActivity == null || lastActivity.isBefore(cutoffDate)) {
        dormantAccounts.add({
          'id': memberId,
          'data': memberData,
          'lastActivity': lastActivity,
        });
      }
    }

    // Sort by last activity (oldest first)
    dormantAccounts.sort((a, b) {
      final aDate = a['lastActivity'] as DateTime?;
      final bDate = b['lastActivity'] as DateTime?;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return -1;
      if (bDate == null) return 1;
      return aDate.compareTo(bDate);
    });

    return dormantAccounts;
  }

  Future<DateTime?> _getLastActivityDate(String memberId) async {
    DateTime? lastDate;

    // Check savings
    final savingsSnap = await FirebaseFirestore.instance
        .collection('savings')
        .where('farmerId', isEqualTo: memberId)
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (savingsSnap.docs.isNotEmpty) {
      final timestamp = savingsSnap.docs.first.data()['createdAt'] as Timestamp?;
      if (timestamp != null) {
        lastDate = timestamp.toDate();
      }
    }

    // Check shares
    final sharesSnap = await FirebaseFirestore.instance
        .collection('shares')
        .where('farmerId', isEqualTo: memberId)
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (sharesSnap.docs.isNotEmpty) {
      final timestamp = sharesSnap.docs.first.data()['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final shareDate = timestamp.toDate();
        if (lastDate == null || shareDate.isAfter(lastDate)) {
          lastDate = shareDate;
        }
      }
    }

    // Check loans
    final loansSnap = await FirebaseFirestore.instance
        .collection('loans')
        .where('farmerId', isEqualTo: memberId)
        .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (loansSnap.docs.isNotEmpty) {
      final timestamp = loansSnap.docs.first.data()['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final loanDate = timestamp.toDate();
        if (lastDate == null || loanDate.isAfter(lastDate)) {
          lastDate = loanDate;
        }
      }
    }

    return lastDate;
  }

  Widget _buildDormantAccountCard(Map<String, dynamic> account) {
    final memberData = account['data'] as Map<String, dynamic>;
    final lastActivity = account['lastActivity'] as DateTime?;
    final daysDormant = lastActivity != null
        ? DateTime.now().difference(lastActivity).inDays
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: Text(
            memberData['name'].toString()[0].toUpperCase(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        title: Text(
          memberData['name'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberData['phone'] ?? 'No phone',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            if (daysDormant != null)
              Text(
                'Dormant for $daysDormant days',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'DORMANT',
            style: GoogleFonts.poppins(
              color: Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Phone', memberData['phone'] ?? 'N/A'),
                _buildDetailRow('National ID', memberData['nationalId'] ?? 'N/A'),
                _buildDetailRow('Village', memberData['village'] ?? 'N/A'),
                _buildDetailRow(
                  'Last Activity',
                  lastActivity != null
                      ? DateFormat('MMM dd, yyyy').format(lastActivity)
                      : 'No transactions',
                ),
                _buildDetailRow(
                  'Days Dormant',
                  daysDormant != null ? '$daysDormant days' : 'N/A',
                ),
                
                const Divider(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showReactivateDialog(account['id']),
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: const Text('Reactivate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showContactDialog(memberData),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Contact'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ModernTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReactivateDialog(String memberId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reactivate Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Mark this account as reactivated? This will update the account status.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('farmers').doc(memberId).update({
                'status': 'active',
                'reactivatedAt': FieldValue.serverTimestamp(),
                'reactivatedBy': FirebaseService.sessionUid,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account reactivated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog(Map<String, dynamic> memberData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Member', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(memberData['name'], style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 12),
            Text('Phone:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(memberData['phone'] ?? 'N/A', style: GoogleFonts.poppins(fontSize: 13)),
            const SizedBox(height: 16),
            Text(
              'Contact this member to encourage account reactivation.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
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
}

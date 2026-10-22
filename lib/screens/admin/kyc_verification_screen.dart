import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';

class KYCVerificationScreen extends StatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  State<KYCVerificationScreen> createState() => _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends State<KYCVerificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: Text('KYC & Verification', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Stats cards
          _buildStatsSection(),
          
          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'Rejected'),
                Tab(text: 'All'),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMembersList('pending'),
                _buildMembersList('verified'),
                _buildMembersList('rejected'),
                _buildMembersList('all'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.getAllFarmers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }

        final members = snapshot.data!.docs;
        final pending = members.where((d) => (d.data() as Map)['idStatus'] == 'pending').length;
        final verified = members.where((d) => (d.data() as Map)['idStatus'] == 'approved').length;
        final rejected = members.where((d) => (d.data() as Map)['idStatus'] == 'rejected').length;

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: _buildStatCard('Pending', pending, Colors.orange, Icons.hourglass_empty)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Verified', verified, Colors.green, Icons.verified)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Rejected', rejected, Colors.red, Icons.cancel)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.getAllFarmers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var members = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final idStatus = data['idStatus'] ?? 'pending';
          if (statusFilter == 'all') return true;
          if (statusFilter == 'verified') return idStatus == 'approved';
          return idStatus == statusFilter;
        }).toList();

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No members found',
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index].data() as Map<String, dynamic>;
            final memberId = members[index].id;
            return _buildMemberCard(memberId, member);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(String memberId, Map<String, dynamic> member) {
    try {
      final kycStatus = member['idStatus'] ?? 'pending';
      final statusColor = kycStatus == 'approved'
          ? Colors.green
          : kycStatus == 'rejected'
              ? Colors.red
              : Colors.orange;
      
      final memberName = member['name'] ?? member['fullName'] ?? 'Unknown';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Text(
              memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          title: Text(
            memberName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            member['nationalId']?.toString() ?? member['phone']?.toString() ?? 'No ID/Phone',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              kycStatus.toUpperCase(),
              style: GoogleFonts.poppins(
                color: statusColor,
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
                  _buildDetailRow('Phone', member['phone']?.toString() ?? 'N/A'),
                  _buildDetailRow('National ID', member['nationalId']?.toString() ?? 'Not provided'),
                  _buildDetailRow('Village', member['village']?.toString() ?? 'N/A'),
                  _buildDetailRow('District', member['district']?.toString() ?? 'N/A'),
                  _buildDetailRow('Next of Kin', member['nextOfKin']?.toString() ?? 'Not provided'),
                  _buildDetailRow('Next of Kin Phone', member['nextOfKinPhone']?.toString() ?? 'Not provided'),
                  
                  if (member['kycNotes'] != null && member['kycNotes'].toString().isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('Notes:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(member['kycNotes'].toString(), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                  
                  const Divider(height: 24),
                  
                  Row(
                    children: [
                      if (kycStatus != 'approved')
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateKYCStatus(memberId, 'approved'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (kycStatus != 'approved') const SizedBox(width: 12),
                      if (kycStatus != 'rejected')
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showRejectDialog(memberId),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
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
          ),
      );
    } catch (e, stackTrace) {
      print('❌ Error building member card for $memberId: $e');
      print('Stack trace: $stackTrace');
      print('Member data: $member');
      
      // Return a safe error widget
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error loading member',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  Text(
                    'ID: $memberId',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.red.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
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

  Future<void> _updateKYCStatus(String memberId, String status) async {
    try {
      print('🔍 Updating KYC status for member: $memberId to status: $status');
      
      // Update saccoplus-members collection with both fields
      final docRef = FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(memberId);
      
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        print('❌ Member not found: $memberId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Member not found. ID: $memberId'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      print('✅ Member found, updating status...');
      
      // Update both kycStatus and idStatus for compatibility
      await docRef.update({
        'kycStatus': status,
        'idStatus': status,
        'kycVerifiedAt': FieldValue.serverTimestamp(),
        'kycVerifiedBy': FirebaseService.sessionUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ KYC status updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KYC ${status == "approved" ? "approved" : "updated"} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error updating KYC: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating KYC: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRejectDialog(String memberId) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject KYC', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
              Navigator.pop(context);
              
              try {
                // Update saccoplus-members collection with both fields
                final docRef = FirebaseFirestore.instance
                    .collection('saccoplus-members')
                    .doc(memberId);
                
                final docSnapshot = await docRef.get();
                
                if (!docSnapshot.exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Member not found. ID: $memberId'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                
                // Update both kycStatus and idStatus for compatibility
                await docRef.update({
                  'kycStatus': 'rejected',
                  'idStatus': 'rejected',
                  'kycNotes': notesController.text,
                  'kycRejectedAt': FieldValue.serverTimestamp(),
                  'kycRejectedBy': FirebaseService.sessionUid,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('KYC rejected successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error rejecting KYC: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/constants.dart';
import '../../core/account_number_service.dart';
import '../../services/audit_service.dart';
import '../../widgets/professional_data_table.dart';
import '../../widgets/sweet_alert.dart';
import '../../widgets/firebase_index_error.dart';
import '../../utils/csv_export.dart';

class MembersDetailedScreen extends StatefulWidget {
  const MembersDetailedScreen({super.key});

  @override
  State<MembersDetailedScreen> createState() => _MembersDetailedScreenState();
}

class _MembersDetailedScreenState extends State<MembersDetailedScreen> {
  final _currencyFormat = NumberFormat('#,##0', 'en_US');
  bool _isUploadingPhoto = false;

  Future<void> _exportMembers(List<Map<String, dynamic>> members) async {
    try {
      // Format data for CsvExport utility
      final formattedMembers = members.map((m) => {
        'id': m['id'] ?? '',
        'memberNumber': m['accountNumber'] ?? '',
        'accountNumber': m['accountNumber'] ?? '',
        'name': m['fullName'] ?? '',
        'fullName': m['fullName'] ?? '',
        'phone': m['phone'] ?? '',
        'gender': m['gender'] ?? '',
        'branch': '',
        'memberType': '',
        'group': '',
        'idStatus': m['kycStatus'] ?? 'pending',
        'savingsBalance': m['savingsBalance'] ?? 0,
        'sharesBalance': m['sharesBalance'] ?? 0,
        'totalShares': 0,
        'loanBalance': m['loanBalance'] ?? 0,
        'walletBalance': 0,
        'registrationDate': null,
        'createdAt': null,
        'migratedFrom': '',
        'status': m['status'] ?? 'active',
      }).toList();

      CsvExport.exportMembers(formattedMembers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Members exported successfully! Check your Downloads folder.'),
            backgroundColor: Color(0xFF388E3C),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  Future<double> _calculateMemberLoanBalance(String memberId) async {
    try {
      final loansSnapshot = await FirebaseFirestore.instance
          .collection('saccoplus-loans')
          .where('memberId', isEqualTo: memberId)
          .get();

      double totalOutstanding = 0;
      for (final doc in loansSnapshot.docs) {
        final data = doc.data();
        final principalOut = (data['principalOutstanding'] ?? 0).toDouble();
        // Only count loans with outstanding balance
        if (principalOut > 0) {
          totalOutstanding += principalOut;
        }
      }

      return totalOutstanding;
    } catch (e) {
      print('Error calculating loan balance: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: isMobile ? null : AppBar(
        title: Text('All Members', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export Members',
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance
                  .collection('saccoplus-members')
                  .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
                  .get();
              
              final members = await Future.wait(snapshot.docs.map((doc) async {
                final data = doc.data();
                final loanBalance = await _calculateMemberLoanBalance(doc.id);
                return {
                  'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
                  'fullName': data['name'] ?? data['fullName'] ?? '',
                  'phone': data['phone'] ?? '',
                  'savingsBalance': (data['savingsBalance'] ?? 0).toDouble(),
                  'sharesBalance': (data['sharesBalance'] ?? 0).toDouble(),
                  'loanBalance': loanBalance,
                  'status': data['status'] ?? 'active',
                  'kycStatus': data['kycStatus'] ?? 'pending',
                };
              }).toList());

              _exportMembers(members);
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('saccoplus-members')
            .where('tenantId', isEqualTo: FirebaseService.sessionTenantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return FirebaseIndexError(error: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(snapshot.data!.docs.map((doc) async {
              final data = doc.data() as Map<String, dynamic>;
              
              // Calculate actual loan balance from active loans
              final loanBalance = await _calculateMemberLoanBalance(doc.id);

              return {
                'id': doc.id,
                'memberId': data['memberId'] ?? doc.id.substring(0, 13),
                'accountNumber': data['accountNumber'] ?? data['memberNumber'] ?? '',
                'fullName': data['name'] ?? data['fullName'] ?? '',
                'phone': data['phone'] ?? '',
                'photoUrl': data['photoUrl'],
                'village': data['village'],
                'district': data['district'],
                'gender': data['gender'],
                'savingsBalance': (data['savingsBalance'] ?? 0).toDouble(),
                'sharesBalance': (data['sharesBalance'] ?? 0).toDouble(),
                'loanBalance': loanBalance,
                'kycStatus': data['kycStatus'] ?? data['idStatus'] ?? 'pending',
                'status': data['status'] ?? 'active',
              };
            }).toList()),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!futureSnapshot.hasData || futureSnapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No members found',
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              final members = futureSnapshot.data!;

          return LayoutBuilder(
            builder: (context, constraints) {
              // Calculate available width
              final availableWidth = constraints.maxWidth - 32;
              
              return Container(
                margin: const EdgeInsets.all(16),
                constraints: BoxConstraints(
                  maxWidth: availableWidth,
                  maxHeight: constraints.maxHeight - 32,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: ProfessionalDataTable(
              tableKey: 'members_management',
              columns: [
                const DataTableColumn(key: 'accountNumber', label: 'Account No.', flex: 2),
                const DataTableColumn(key: 'fullName', label: 'Full Name', flex: 3),
                DataTableColumn(
                    key: 'phone',
                    label: 'Phone',
                    flex: 2,
                    builder: (row) {
                      final phone = row['phone'] as String;
                      final hasPhone = phone.isNotEmpty;
                      return Row(
                        children: [
                          if (!hasPhone)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B6B),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning, size: 12, color: Colors.white),
                            ),
                          Expanded(
                            child: Text(
                              hasPhone ? phone : 'Not Set',
                              style: TextStyle(
                                fontSize: 13,
                                color: hasPhone ? Colors.black87 : Colors.grey.shade500,
                                fontStyle: hasPhone ? FontStyle.normal : FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  DataTableColumn(
                    key: 'savingsBalance',
                    label: 'Savings',
                    flex: 2,
                    builder: (row) => Text(
                      _currencyFormat.format(row['savingsBalance']),
                      style: const TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DataTableColumn(
                    key: 'sharesBalance',
                    label: 'Shares',
                    flex: 2,
                    builder: (row) => Text(
                      _currencyFormat.format(row['sharesBalance']),
                      style: const TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1565C0),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  DataTableColumn(
                    key: 'loanBalance',
                    label: 'Loans',
                    flex: 2,
                    builder: (row) {
                      final amount = row['loanBalance'] as double;
                      return Text(
                        _currencyFormat.format(amount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: amount > 0 ? const Color(0xFFD32F2F) : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                  DataTableColumn(
                    key: 'kycStatus',
                    label: 'KYC',
                    flex: 1,
                    builder: (row) => _kycBadge(row['kycStatus'] as String),
                  ),
                  DataTableColumn(
                    key: 'status',
                    label: 'Status',
                    flex: 1,
                    builder: (row) => _statusBadge(row['status'] as String),
                  ),
                  DataTableColumn(
                    key: 'actions',
                    label: 'Actions',
                    flex: 2,
                    builder: (row) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _showEditMemberDialog(row),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1565C0)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _toggleMemberStatus(row),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: (row['status'] ?? 'active') == 'active' 
                                    ? const Color(0xFFFFEBEE) 
                                    : const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                (row['status'] ?? 'active') == 'active' 
                                    ? Icons.block 
                                    : Icons.check_circle_outline,
                                size: 14,
                                color: (row['status'] ?? 'active') == 'active' 
                                    ? const Color(0xFFC62828) 
                                    : const Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _showDeleteMemberDialog(row),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFD32F2F)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              data: members,
              searchPlaceholder: 'Search by name, member ID, or account number...',
            ),
              );
            },
          );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _kycBadge(String status) {
    final isApproved = status.toLowerCase() == 'approved';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isApproved ? 'Approved' : 'Pending',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isApproved ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF757575),
        ),
      ),
    );
  }

  void _showEditMemberDialog(Map<String, dynamic> member) {
    final nameController = TextEditingController(text: member['fullName']);
    final phoneController = TextEditingController(text: member['phone']);
    final villageController = TextEditingController(text: member['village']);
    final districtController = TextEditingController(text: member['district']);
    
    // Debug: Check what phone value we have
    debugPrint('🔍 Member Edit Dialog:');
    debugPrint('   Member ID: ${member['id']}');
    debugPrint('   Phone from member data: ${member['phone']}');
    debugPrint('   Phone controller text: ${phoneController.text}');
    String selectedGender = member['gender'] ?? 'Male';
    String selectedKycStatus = member['kycStatus'] ?? 'pending';
    
    // Check if phone number is missing
    final hasPhone = (member['phone'] as String).isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 650,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Edit Member',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  
                  // Phone Number Alert
                  if (!hasPhone)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF6B6B), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Action Required',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD32F2F),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Phone number is required for SMS notifications and account security',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Photo Section
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                            image: member['photoUrl'] != null && member['photoUrl'].toString().isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(member['photoUrl']),
                                    fit: BoxFit.cover,
                                  )
                                : const DecorationImage(
                                    image: AssetImage('assets/images/avatar.png'),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _isUploadingPhoto
                            ? const CircularProgressIndicator()
                            : TextButton.icon(
                                onPressed: () => _uploadPhoto(member['id']),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: const Text('Change Photo'),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Financial Summary Section
                  Text(
                    'Financial Summary',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFinancialCard(
                            'Savings',
                            _currencyFormat.format(member['savingsBalance']),
                            Icons.account_balance_wallet,
                            const Color(0xFF00BFA6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFinancialCard(
                            'Shares',
                            _currencyFormat.format(member['sharesBalance']),
                            Icons.pie_chart,
                            const Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFinancialCard(
                            'Loans',
                            _currencyFormat.format(member['loanBalance']),
                            Icons.money_off,
                            const Color(0xFFD32F2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Info
                  Text(
                    'Account Information',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoField('Account No.', member['accountNumber']),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoField('Member Since', 'Jan 2024'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Personal Details
                  Text(
                    'Personal Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          items: ['Male', 'Female'].map((gender) {
                            return DropdownMenuItem(value: gender, child: Text(gender));
                          }).toList(),
                          onChanged: (value) => setState(() => selectedGender = value!),
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            hintText: selectedGender,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number *',
                            hintText: '256XXXXXXXXX',
                            helperText: 'Format: 256XXXXXXXXX (12 digits)',
                            helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: !hasPhone ? const Color(0xFFD32F2F) : Colors.grey,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            prefixIcon: const Icon(Icons.phone, size: 20),
                            suffixIcon: !hasPhone 
                                ? const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 20)
                                : null,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: villageController,
                          decoration: InputDecoration(
                            labelText: 'Village',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: districtController,
                          decoration: InputDecoration(
                            labelText: 'District',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // KYC Status
                  Text(
                    'Verification',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    items: ['pending', 'approved', 'rejected'].map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status[0].toUpperCase() + status.substring(1)),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedKycStatus = value!),
                    decoration: InputDecoration(
                      labelText: 'KYC Status',
                      hintText: selectedKycStatus[0].toUpperCase() + selectedKycStatus.substring(1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      // Deactivate/Activate Button
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _toggleMemberStatus(member);
                        },
                        icon: Icon(
                          (member['status'] ?? 'active') == 'active' ? Icons.block : Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: Text((member['status'] ?? 'active') == 'active' ? 'Deactivate' : 'Activate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: (member['status'] ?? 'active') == 'active' 
                              ? const Color(0xFFD32F2F) 
                              : const Color(0xFF388E3C),
                          side: BorderSide(
                            color: (member['status'] ?? 'active') == 'active' 
                                ? const Color(0xFFD32F2F) 
                                : const Color(0xFF388E3C),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Phone number is required'),
                                backgroundColor: Color(0xFFD32F2F),
                              ),
                            );
                            return;
                          }
                          _updateMember(
                            member['id'],
                            nameController.text,
                            selectedGender,
                            phoneController.text,
                            villageController.text,
                            districtController.text,
                            selectedKycStatus,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _updateMember(
    String memberId,
    String name,
    String gender,
    String phone,
    String village,
    String district,
    String kycStatus,
  ) async {
    try {
      debugPrint('');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📝 UPDATING MEMBER');
      debugPrint('   Member ID: $memberId');
      debugPrint('   Name: $name');
      debugPrint('   Phone: "$phone"');
      debugPrint('   Village: $village');
      debugPrint('   District: $district');
      debugPrint('   KYC Status: $kycStatus');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final docRef = FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(memberId);
      
      debugPrint('📍 Document path: saccoplus-members/$memberId');
      
      // Check if document exists first
      final docSnapshot = await docRef.get();
      debugPrint('📄 Document exists: ${docSnapshot.exists}');
      
      if (!docSnapshot.exists) {
        throw Exception('Member document not found: $memberId');
      }
      
      // Perform update
      await docRef.update({
        'name': name,
        'fullName': name,
        'gender': gender,
        'phone': phone,
        'village': village,
        'district': district,
        'kycStatus': kycStatus,
        'idStatus': kycStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('');
      debugPrint('✅ Member updated successfully in Firestore');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');

      if (mounted) {
        Navigator.pop(context);
        SweetAlert.show(
          context: context,
          type: SweetAlertType.success,
          title: 'Updated Successfully!',
          message: 'Member information has been updated',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌ ERROR UPDATING MEMBER');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating member: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _toggleMemberStatus(Map<String, dynamic> member) async {
    final currentStatus = member['status'] ?? 'active';
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final memberId = member['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${newStatus == 'inactive' ? 'Deactivate' : 'Activate'} Member?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to ${newStatus == 'inactive' ? 'deactivate' : 'activate'} ${member['fullName']}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'inactive' ? const Color(0xFFD32F2F) : const Color(0xFF388E3C),
              foregroundColor: Colors.white,
            ),
            child: Text(newStatus == 'inactive' ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(memberId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        SweetAlert.show(
          context: context,
          type: SweetAlertType.success,
          title: newStatus == 'inactive' ? 'Member Deactivated' : 'Member Activated',
          message: '${member['fullName']} has been ${newStatus == 'inactive' ? 'deactivated' : 'activated'} successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating member status: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteMemberDialog(Map<String, dynamic> member) async {
    final memberId = member['id'];
    final memberName = member['fullName'];
    final hasBalances = (member['savingsBalance'] as double) > 0 || 
                        (member['sharesBalance'] as double) > 0 || 
                        (member['loanBalance'] as double) > 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Member Account?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete $memberName\'s account?',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9800)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      const Text(
                        'Account Summary',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE65100)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Savings: UGX ${_currencyFormat.format(member['savingsBalance'])}', 
                      style: const TextStyle(fontSize: 12)),
                  Text('Shares: UGX ${_currencyFormat.format(member['sharesBalance'])}', 
                      style: const TextStyle(fontSize: 12)),
                  Text('Loans: UGX ${_currencyFormat.format(member['loanBalance'])}', 
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (hasBalances) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD32F2F)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_rounded, color: Color(0xFFD32F2F), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Warning: Active Balances',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD32F2F)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This member has active balances. Ensure all transactions are settled before deletion.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFD32F2F)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              '⚠️ This action cannot be undone. All member data, transactions, and history will be permanently deleted.',
              style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete member document
      await FirebaseFirestore.instance
          .collection('saccoplus-members')
          .doc(memberId)
          .delete();

      // Optional: Delete related data (savings, shares, loans)
      // You might want to keep transaction history for audit purposes
      // Or move them to an "archived" collection instead of deleting

      if (mounted) {
        SweetAlert.show(
          context: context,
          type: SweetAlertType.success,
          title: 'Deleted Successfully!',
          message: 'Member account has been permanently deleted',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting member: $e'),
            backgroundColor: const Color(0xFFD32F2F),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _uploadPhoto(String memberId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      // Read image as bytes
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Upload to ImgBB
      final response = await http.post(
        Uri.parse(AppConstants.imgbbUploadUrl),
        body: {
          'key': AppConstants.imgbbApiKey,
          'image': base64Image,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final imageUrl = jsonResponse['data']['url'];

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('saccoplus-members')
            .doc(memberId)
            .update({
          'photoUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo uploaded successfully'),
              backgroundColor: Color(0xFF388E3C),
            ),
          );
        }
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e'),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showAddMemberDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final villageCtrl = TextEditingController();
    final districtCtrl = TextEditingController();
    final nextOfKinNameCtrl = TextEditingController();
    final nextOfKinPhoneCtrl = TextEditingController();
    final nextOfKinRelationCtrl = TextEditingController();
    
    String selectedGender = 'Male';
    DateTime? selectedDOB;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Add New Member', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (!isLoading)
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(builderContext)),
                    ],
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: phoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Phone Number *',
                              prefixIcon: const Icon(Icons.phone),
                              hintText: '256XXXXXXXXX',
                              helperText: 'Format: 256XXXXXXXXX (12 digits)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!RegExp(r'^256\d{9}$').hasMatch(v.trim())) return 'Must be 256 followed by 9 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailCtrl,
                            decoration: InputDecoration(
                              labelText: 'Email (Optional)',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedGender,
                                  decoration: InputDecoration(
                                    labelText: 'Gender *',
                                    prefixIcon: const Icon(Icons.wc),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                  onChanged: (v) => setState(() => selectedGender = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: dobCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Date of Birth *',
                                    prefixIcon: const Icon(Icons.calendar_today),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: builderContext,
                                      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
                                      firstDate: DateTime(1940),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        selectedDOB = date;
                                        dobCtrl.text = DateFormat('dd/MM/yyyy').format(date);
                                      });
                                    }
                                  },
                                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: villageCtrl,
                            decoration: InputDecoration(
                              labelText: 'Village *',
                              prefixIcon: const Icon(Icons.location_on),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: districtCtrl,
                            decoration: InputDecoration(
                              labelText: 'District *',
                              prefixIcon: const Icon(Icons.location_city_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nextOfKinNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Next of Kin Name *',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nextOfKinPhoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Next of Kin Phone *',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              hintText: '256XXXXXXXXX',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nextOfKinRelationCtrl,
                            decoration: InputDecoration(
                              labelText: 'Relationship *',
                              prefixIcon: const Icon(Icons.family_restroom),
                              hintText: 'e.g., Spouse, Parent, Sibling',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!isLoading)
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(builderContext), child: const Text('Cancel'))),
                      if (!isLoading) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setState(() => isLoading = true);
                            try {
                              await _createMember(
                                name: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gender: selectedGender,
                                dateOfBirth: selectedDOB!,
                                village: villageCtrl.text.trim(),
                                district: districtCtrl.text.trim(),
                                nextOfKinName: nextOfKinNameCtrl.text.trim(),
                                nextOfKinPhone: nextOfKinPhoneCtrl.text.trim(),
                                nextOfKinRelation: nextOfKinRelationCtrl.text.trim(),
                              );
                              if (builderContext.mounted) {
                                Navigator.pop(builderContext);
                                SweetAlert.show(
                                  context: builderContext,
                                  title: 'Member Added Successfully!',
                                  message: 'The new member has been added to the system',
                                  type: SweetAlertType.success,
                                );
                              }
                            } catch (e) {
                              if (builderContext.mounted) {
                                setState(() => isLoading = false);
                                SweetAlert.show(
                                  context: builderContext,
                                  title: 'Error',
                                  message: e.toString().replaceFirst('Exception: ', ''),
                                  type: SweetAlertType.error,
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Add Member', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createMember({
    required String name,
    required String phone,
    required String email,
    required String gender,
    required DateTime dateOfBirth,
    required String village,
    required String district,
    required String nextOfKinName,
    required String nextOfKinPhone,
    required String nextOfKinRelation,
  }) async {
    final memberId = 'phone_$phone';
    final tenantId = FirebaseService.sessionTenantId;
    
    final existing = await FirebaseFirestore.instance.collection(AppConstants.usersCol).doc(memberId).get();
    if (existing.exists) throw Exception('Member with this phone number already exists');
    
    final accountNumber = await AccountNumberService.generateNext();
    
    final membersCount = await FirebaseFirestore.instance
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: tenantId)
        .count()
        .get();
    final memberNumber = 'M${((membersCount.count ?? 0) + 1).toString().padLeft(6, '0')}';
    
    final random = Random();
    final pin = (1000 + random.nextInt(9000)).toString();
    
    final tempPassword = '${name.replaceAll(' ', '').substring(0, min(4, name.length)).toLowerCase()}${phone.substring(phone.length - 4)}';
    
    final now = Timestamp.now();
    
    final memberData = {
      'tenantId': tenantId,
      'memberNumber': memberNumber,
      'accountNumber': accountNumber,
      'name': name,
      'fullName': name,
      'phone': phone,
      'email': email.isNotEmpty ? email : null,
      'gender': gender,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'village': village,
      'district': district,
      'nextOfKin': {
        'name': nextOfKinName,
        'phone': nextOfKinPhone,
        'relationship': nextOfKinRelation,
      },
      'pin': pin,
      'tempPassword': tempPassword,
      'savingsBalance': 0,
      'sharesBalance': 0,
      'loanBalance': 0,
      'kycStatus': 'pending',
      'idStatus': 'pending',
      'role': 'farmer',
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
      'createdBy': FirebaseService.sessionUid,
    };
    
    await FirebaseFirestore.instance.collection('saccoplus-members').doc(memberId).set(memberData);
    await FirebaseFirestore.instance.collection(AppConstants.usersCol).doc(memberId).set(memberData);
    
    await AuditService.log(
      action: 'MEMBER_CREATED',
      details: 'Created new member: $name',
      userId: FirebaseService.sessionUid ?? '',
      affectedUserId: memberId,
      metadata: {'memberNumber': memberNumber, 'accountNumber': accountNumber},
    );
    
    debugPrint('📱 SMS would be sent to $phone:');
    debugPrint('Account: $accountNumber, Member: $memberNumber, PIN: $pin, Password: $tempPassword');
  }

}

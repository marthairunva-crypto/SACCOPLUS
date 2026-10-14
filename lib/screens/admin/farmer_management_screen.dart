import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/firebase_service.dart';
import '../../core/audit_service.dart';
import '../../core/sacco_service.dart';
import '../../core/account_number_service.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/professional_data_table.dart';
import '../../utils/csv_export.dart';
import '../../services/member_statement_service.dart';
import 'admin_statement_preview.dart';

class FarmerManagementScreen extends StatefulWidget {
  final bool embedded;
  const FarmerManagementScreen({super.key, this.embedded = false});
  
  @override
  State<FarmerManagementScreen> createState() => _FarmerManagementScreenState();
}

class _FarmerManagementScreenState extends State<FarmerManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Member Management'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(context),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Members',
            onPressed: _exportMembers,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getAllFarmers(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No members registered yet', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMemberDialog(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add First Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          final members = snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'memberNumber': data['memberNumber'] ?? 'N/A',
              'accountNumber': data['accountNumber'] ?? 'N/A',
              'name': data['name'] ?? data['fullName'] ?? 'N/A',
              'phone': data['phone'] ?? 'N/A',
              'village': data['village'] ?? 'N/A',
              'savingsBalance': data['savingsBalance'] ?? 0,
              'sharesBalance': data['sharesBalance'] ?? 0,
              'loanBalance': data['loanBalance'] ?? 0,
              'idStatus': data['idStatus'] ?? 'pending',
              'createdAt': data['createdAt'],
              'email': data['email'] ?? '',
              'gender': data['gender'] ?? '',
              'district': data['district'] ?? '',
            };
          }).toList();

          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1400),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ProfessionalDataTable(
                tableKey: 'farmers_list',
                columns: [
                  const DataTableColumn(key: 'memberNumber', label: 'Member No.', width: 120),
                  const DataTableColumn(key: 'accountNumber', label: 'Account No.', width: 130),
                  const DataTableColumn(key: 'name', label: 'Full Name', width: 180),
                  const DataTableColumn(key: 'phone', label: 'Phone', width: 130),
                  const DataTableColumn(key: 'village', label: 'Village', width: 130),
                  DataTableColumn(
                    key: 'savingsBalance',
                    label: 'Savings',
                    width: 120,
                    builder: (row) => Text(
                      'UGX ${fmt.format(row['savingsBalance'])}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success),
                    ),
                  ),
                  DataTableColumn(
                    key: 'sharesBalance',
                    label: 'Shares',
                    width: 120,
                    builder: (row) => Text(
                      'UGX ${fmt.format(row['sharesBalance'])}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                    ),
                  ),
                  DataTableColumn(
                    key: 'loanBalance',
                    label: 'Loan',
                    width: 120,
                    builder: (row) {
                      final loanBalance = row['loanBalance'] ?? 0;
                      return Text(
                        'UGX ${fmt.format(loanBalance)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: loanBalance > 0 ? AppTheme.error : Colors.grey,
                        ),
                      );
                    },
                  ),
                  DataTableColumn(
                    key: 'idStatus',
                    label: 'KYC Status',
                    width: 110,
                    builder: (row) {
                      final status = row['idStatus'] ?? 'pending';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: status == 'approved'
                              ? AppTheme.success.withOpacity(0.1)
                              : status == 'rejected'
                                  ? AppTheme.error.withOpacity(0.1)
                                  : AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status == 'approved'
                                ? AppTheme.success
                                : status == 'rejected'
                                    ? AppTheme.error
                                    : AppTheme.warning,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  DataTableColumn(
                    key: 'actions',
                    label: 'Actions',
                    width: 100,
                    builder: (row) => IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20),
                      color: AppTheme.primary,
                      onPressed: () => _showMemberDetailsDialog(context, row, fmt),
                      tooltip: 'View Details',
                    ),
                  ),
                ],
                data: members,
                onRowTap: (row) => _showMemberDetailsDialog(context, row, fmt),
                filters: const [
                  TableFilter(
                    key: 'idStatus',
                    label: 'KYC Status',
                    options: [
                      FilterOption(value: 'pending', label: 'Pending'),
                      FilterOption(value: 'approved', label: 'Approved'),
                      FilterOption(value: 'rejected', label: 'Rejected'),
                    ],
                  ),
                ],
                searchPlaceholder: 'Search by name, phone, member number...',
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMemberDetailsDialog(BuildContext context, Map<String, dynamic> member, NumberFormat fmt) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member['name'], style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(member['memberNumber'], style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection('Contact Information', [
                        _buildInfoRow('Phone', member['phone']),
                        _buildInfoRow('Email', member['email'].isEmpty ? 'N/A' : member['email']),
                        _buildInfoRow('Village', member['village']),
                        _buildInfoRow('District', member['district'].isEmpty ? 'N/A' : member['district']),
                        _buildInfoRow('Account Number', member['accountNumber']),
                      ]),
                      const SizedBox(height: 24),
                      _buildInfoSection('Financial Summary', [
                        _buildInfoRow('Savings Balance', 'UGX ${fmt.format(member['savingsBalance'])}', color: AppTheme.success),
                        _buildInfoRow('Shares Balance', 'UGX ${fmt.format(member['sharesBalance'])}', color: Colors.blue),
                        _buildInfoRow('Loan Balance', 'UGX ${fmt.format(member['loanBalance'])}', 
                            color: member['loanBalance'] > 0 ? AppTheme.error : Colors.grey),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Statement'),
                    onPressed: () async {
                      final memberId = member['id'] as String? ?? '';
                      if (memberId.isEmpty) return;
                      Navigator.pop(context); // close detail dialog first
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 30)),
                          end: DateTime.now(),
                        ),
                        helpText: 'Statement period for ${member['name']}',
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primary,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (range == null || !context.mounted) return;

                      bool dlgOpen = true;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PopScope(
                          canPop: false,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(color: Colors.white,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const CircularProgressIndicator(color: AppTheme.primary),
                                const SizedBox(height: 16),
                                Text('Generating statement…',
                                    style: GoogleFonts.poppins(fontSize: 14)),
                              ]),
                            ),
                          ),
                        ),
                      ).then((_) => dlgOpen = false);

                      void closeDlg() {
                        if (dlgOpen && context.mounted) {
                          dlgOpen = false;
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                      }

                      try {
                        final result = await MemberStatementService.generateForAdmin(
                            memberId: memberId,
                            from: range.start,
                            to: range.end);
                        closeDlg();
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AdminStatementPreview(
                              pdfBytes  : result.bytes,
                              filename  : result.filename,
                              memberName: member['name'] as String? ?? 'Member',
                              from: range.start,
                              to  : range.end,
                            ),
                          ));
                        }
                      } catch (e) {
                        closeDlg();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed: $e'),
                              backgroundColor: AppTheme.error));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
          Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final villageCtrl = TextEditingController();
    final parishCtrl = TextEditingController();
    final subcountyCtrl = TextEditingController();
    final districtCtrl = TextEditingController();
    final nextOfKinNameCtrl = TextEditingController();
    final nextOfKinPhoneCtrl = TextEditingController();
    final nextOfKinRelationCtrl = TextEditingController();
    
    String selectedGender = 'Male';
    String selectedMemberType = 'Individual';
    DateTime? selectedDOB;
    String? photoUrl;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_add, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Text('Add New Member', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (!isLoading)
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(height: 32),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Personal Information Section
                          Text('Personal Information', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          const SizedBox(height: 16),
                          
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
                              helperStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!RegExp(r'^256\d{9}$').hasMatch(v.trim())) {
                                return 'Must be 256 followed by 9 digits';
                              }
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
                                      context: context,
                                      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
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
                          const SizedBox(height: 24),
                          
                          // Address Section
                          Text('Address Information', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary)),
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
                            controller: parishCtrl,
                            decoration: InputDecoration(
                              labelText: 'Parish/Division *',
                              prefixIcon: const Icon(Icons.map),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          TextFormField(
                            controller: subcountyCtrl,
                            decoration: InputDecoration(
                              labelText: 'Subcounty/Division *',
                              prefixIcon: const Icon(Icons.location_city),
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
                          const SizedBox(height: 24),
                          
                          // Photo Upload
                          Text('Passport Photo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.photo_camera, color: Colors.grey.shade600),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    photoUrl != null ? 'Photo uploaded' : 'Upload passport photo',
                                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: null, // TODO: Implement photo upload
                                  icon: const Icon(Icons.upload, size: 18),
                                  label: const Text('Upload'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Next of Kin Section
                          Text('Next of Kin Details', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary)),
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
                          const SizedBox(height: 24),
                          
                          // Member Type Section
                          Text('Member Information', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<String>(
                            value: selectedMemberType,
                            decoration: InputDecoration(
                              labelText: 'Member Type *',
                              prefixIcon: const Icon(Icons.group),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: ['Individual', 'Group'].map((type) => 
                              DropdownMenuItem(value: type, child: Text(type))
                            ).toList(),
                            onChanged: (v) => setState(() => selectedMemberType = v!),
                          ),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Account number, PIN, and login credentials will be auto-generated and sent via SMS',
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!isLoading)
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                      if (!isLoading) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  // Show preview dialog before saving
                                  final confirmed = await _showMemberPreview(
                                    context: context,
                                    name: nameCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    gender: selectedGender,
                                    dateOfBirth: selectedDOB!,
                                    village: villageCtrl.text.trim(),
                                    parish: parishCtrl.text.trim(),
                                    subcounty: subcountyCtrl.text.trim(),
                                    district: districtCtrl.text.trim(),
                                    nextOfKinName: nextOfKinNameCtrl.text.trim(),
                                    nextOfKinPhone: nextOfKinPhoneCtrl.text.trim(),
                                    nextOfKinRelation: nextOfKinRelationCtrl.text.trim(),
                                    memberType: selectedMemberType,
                                  );
                                  
                                  if (confirmed != true) return;
                                  
                                  setState(() => isLoading = true);
                                  try {
                                    await _createMember(
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim(),
                                      email: emailCtrl.text.trim(),
                                      gender: selectedGender,
                                      dateOfBirth: selectedDOB!,
                                      village: villageCtrl.text.trim(),
                                      parish: parishCtrl.text.trim(),
                                      subcounty: subcountyCtrl.text.trim(),
                                      district: districtCtrl.text.trim(),
                                      nextOfKinName: nextOfKinNameCtrl.text.trim(),
                                      nextOfKinPhone: nextOfKinPhoneCtrl.text.trim(),
                                      nextOfKinRelation: nextOfKinRelationCtrl.text.trim(),
                                      memberType: selectedMemberType,
                                      photoUrl: photoUrl,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      // Show centered success dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Member Added',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            'Member has been successfully added to the system',
                                            style: GoogleFonts.poppins(fontSize: 15),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'OK',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      // Show centered error dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Row(
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Error',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            e.toString().replaceFirst('Exception: ', ''),
                                            style: GoogleFonts.poppins(fontSize: 15),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'OK',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => isLoading = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Add Member'),
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

  Future<bool?> _showMemberPreview({
    required BuildContext context,
    required String name,
    required String phone,
    required String email,
    required String gender,
    required DateTime dateOfBirth,
    required String village,
    required String parish,
    required String subcounty,
    required String district,
    required String nextOfKinName,
    required String nextOfKinPhone,
    required String nextOfKinRelation,
    required String memberType,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.preview, color: AppTheme.primary),
            const SizedBox(width: 12),
            Text('Preview Member Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please review the information before saving:', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              
              _previewSection('Personal Information', [
                _previewItem('Full Name', name),
                _previewItem('Phone', phone),
                if (email.isNotEmpty) _previewItem('Email', email),
                _previewItem('Gender', gender),
                _previewItem('Date of Birth', '${dateOfBirth.day}/${dateOfBirth.month}/${dateOfBirth.year}'),
              ]),
              
              _previewSection('Address', [
                _previewItem('Village', village),
                _previewItem('Parish/Division', parish),
                _previewItem('Subcounty/Division', subcounty),
                _previewItem('District', district),
              ]),
              
              _previewSection('Next of Kin', [
                _previewItem('Name', nextOfKinName),
                _previewItem('Phone', nextOfKinPhone),
                _previewItem('Relationship', nextOfKinRelation),
              ]),
              
              _previewSection('Member Type', [
                _previewItem('Type', memberType),
              ]),
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Account credentials will be auto-generated and sent via SMS',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
  }
  
  Widget _previewSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        const SizedBox(height: 8),
        ...items,
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _previewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
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
    required String parish,
    required String subcounty,
    required String district,
    required String nextOfKinName,
    required String nextOfKinPhone,
    required String nextOfKinRelation,
    required String memberType,
    String? photoUrl,
  }) async {
    final memberId = 'phone_$phone';
    final tenantId = FirebaseService.sessionTenantId;
    
    final existing = await FirebaseFirestore.instance.collection(AppConstants.usersCol).doc(memberId).get();
    if (existing.exists) throw Exception('Member with this phone number already exists');
    
    // Generate account number using the service
    final accountNumber = await AccountNumberService.generateNext();
    
    // Generate member number (simple sequential)
    final membersCount = await FirebaseFirestore.instance
        .collection('saccoplus-members')
        .where('tenantId', isEqualTo: tenantId)
        .count()
        .get();
    final memberNumber = 'M${((membersCount.count ?? 0) + 1).toString().padLeft(6, '0')}';
    
    // Generate random 4-digit PIN
    final random = Random();
    final pin = (1000 + random.nextInt(9000)).toString();
    
    // Generate temporary password (first 4 letters of name + last 4 digits of phone)
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
      'parish': parish,
      'subcounty': subcounty,
      'district': district,
      'photoUrl': photoUrl,
      'nextOfKin': {
        'name': nextOfKinName,
        'phone': nextOfKinPhone,
        'relationship': nextOfKinRelation,
      },
      'memberType': memberType,
      'pin': pin, // Store hashed in production
      'tempPassword': tempPassword,
      'savingsBalance': 0,
      'sharesBalance': 0,
      'loanBalance': 0,
      'idStatus': 'pending',
      'role': 'member',  // lowercase 'member' - consistent with database
      'status': 'active',
      'createdAt': now,
      'updatedAt': now,
      'createdBy': FirebaseService.sessionUid,
    };
    
    // Create member document
    await FirebaseFirestore.instance.collection('saccoplus-members').doc(memberId).set(memberData);
    
    // Also create in users collection for authentication
    await FirebaseFirestore.instance.collection(AppConstants.usersCol).doc(memberId).set(memberData);
    
    // Audit log
    await AuditService.log(
      action: 'MEMBER_CREATED',
      description: 'Created new member: $name',
      targetId: memberId,
      targetName: name,
      meta: {'memberNumber': memberNumber, 'accountNumber': accountNumber},
    );
    
    // TODO: Send SMS with credentials
    // SMS message format:
    // "Welcome to SACCOPLUS! Your account has been created.
    // Account No: $accountNumber
    // Member No: $memberNumber  
    // Username: $phone
    // PIN: $pin
    // Temp Password: $tempPassword
    // Please change your password on first login."
    
    print('📱 SMS would be sent to $phone:');
    print('Account: $accountNumber, Member: $memberNumber, PIN: $pin, Password: $tempPassword');
  }

  Future<void> _exportMembers() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting members...'), duration: Duration(seconds: 2)));
      final members = await FirebaseService.getAllFarmersOnce();
      if (members.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No members to export'), backgroundColor: Colors.orange));
        return;
      }
      CsvExport.exportMembers(members);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${members.length} members successfully!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: ${e.toString()}'), backgroundColor: AppTheme.error));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../services/account_number_service.dart';
import '../../services/audit_service.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Personal Information
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ninController = TextEditingController();
  String _gender = 'Male';
  DateTime? _dateOfBirth;

  // Step 2: Location Details
  final _villageController = TextEditingController();
  final _parishController = TextEditingController();
  final _subcountyController = TextEditingController();
  final _countyController = TextEditingController();
  final _districtController = TextEditingController();

  // Step 3: Next of Kin
  final _kinNameController = TextEditingController();
  final _kinPhoneController = TextEditingController();
  final _kinRelationshipController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ninController.dispose();
    _villageController.dispose();
    _parishController.dispose();
    _subcountyController.dispose();
    _countyController.dispose();
    _districtController.dispose();
    _kinNameController.dispose();
    _kinPhoneController.dispose();
    _kinRelationshipController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove any spaces or special characters
    phone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // If starts with 07, convert to 2567
    if (phone.startsWith('07') && phone.length == 10) {
      return '256${phone.substring(1)}';
    }
    
    // If starts with 7, add 256
    if (phone.startsWith('7') && phone.length == 9) {
      return '256$phone';
    }
    
    // If already starts with 256, return as is
    if (phone.startsWith('256')) {
      return phone;
    }
    
    return phone;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (!cleaned.startsWith('07') && !cleaned.startsWith('256')) {
      return 'Phone must start with 07';
    }
    
    if (cleaned.startsWith('07') && cleaned.length != 10) {
      return 'Phone must be 10 digits (07XXXXXXXX)';
    }
    
    if (cleaned.startsWith('256') && cleaned.length != 12) {
      return 'Phone must be 12 digits (256XXXXXXXXX)';
    }
    
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Format phone numbers
      final phone = _formatPhoneNumber(_phoneController.text.trim());
      final kinPhone = _formatPhoneNumber(_kinPhoneController.text.trim());

      // Generate account number and member number
      final accountNumber = await AccountNumberService.generateNext();
      
      // Generate member number in same format as existing (10-digit: 922XXXXXXX)
      // Use a counter to get the next number
      final memberCounterRef = FirebaseFirestore.instance
          .collection('saccoplus-counters')
          .doc('member_numbers_${FirebaseService.sessionTenantId}');
      
      int memberNumberInt = 9220000000;
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(memberCounterRef);
        if (snap.exists) {
          memberNumberInt = (snap.data()!['lastNumber'] as int? ?? 9219999999) + 1;
        }
        txn.set(memberCounterRef, {'lastNumber': memberNumberInt}, SetOptions(merge: true));
      });
      
      final memberNumber = memberNumberInt.toString(); // e.g., "9220000361"
      
      // Generate default PIN (last 4 digits of phone)
      final defaultPin = phone.substring(phone.length - 4);

      // Create member data
      final memberData = {
        'name': _fullNameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'phone': phone,
        'email': _emailController.text.trim(),
        'nationalId': _ninController.text.trim(),
        'nin': _ninController.text.trim(),
        'gender': _gender,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'village': _villageController.text.trim(),
        'parish': _parishController.text.trim(),
        'subcounty': _subcountyController.text.trim(),
        'county': _countyController.text.trim(),
        'district': _districtController.text.trim(),
        'nextOfKin': _kinNameController.text.trim(),
        'nextOfKinPhone': kinPhone,
        'nextOfKinRelationship': _kinRelationshipController.text.trim(),
        'accountNumber': accountNumber,
        'memberNumber': memberNumber,
        'pin': defaultPin,
        'role': 'farmer',
        'status': 'active',
        'idStatus': 'pending',
        'tenantId': FirebaseService.sessionTenantId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseService.sessionUid,
        'walletBalance': 0,
        'savingsBalance': 0,
        'sharesBalance': 0,
        'fixedDepositBalance': 0,
        'loanBalance': 0,
      };

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .add(memberData);

      // Audit log
      await AuditService.log(
        action: 'MEMBER_ADDED',
        details: 'Admin added new member: ${_fullNameController.text.trim()}',
        userId: FirebaseService.sessionUid,
        affectedUserId: docRef.id,
        metadata: {
          'memberNumber': memberNumber,
          'accountNumber': accountNumber,
        },
      );

      if (!mounted) return;

      // Show success message with account details
      _showSuccessDialog(memberNumber, accountNumber, phone, defaultPin);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog(String memberNumber, String accountNumber, String phone, String pin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green, size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                'Member Added Successfully!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Member Number', memberNumber),
              _buildInfoRow('Account Number', accountNumber),
              _buildInfoRow('Phone Number', phone),
              _buildInfoRow('Default PIN', pin),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The member can now login using their phone number and PIN',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close add member screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Add New Member', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  _buildProgressStep(0, 'Personal', Icons.person),
                  _buildProgressLine(0),
                  _buildProgressStep(1, 'Location', Icons.location_on),
                  _buildProgressLine(1),
                  _buildProgressStep(2, 'Next of Kin', Icons.people),
                ],
              ),
            ),
            
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildCurrentStep(),
                ),
              ),
            ),
            
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Back', style: GoogleFonts.poppins(fontSize: 16)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () {
                        if (_currentStep < 2) {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _currentStep++);
                          }
                        } else {
                          _submitForm();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _currentStep < 2 ? 'Next' : 'Add Member',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isActive ? Colors.white : Colors.grey.shade400, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppTheme.primary : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(int step) {
    final isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        color: isActive ? AppTheme.primary : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildNextOfKinStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the member\'s basic details',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        _buildTextField(
          controller: _fullNameController,
          label: 'Full Name',
          icon: Icons.person,
          validator: (v) => v!.isEmpty ? 'Name is required' : null,
        ),
        
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          icon: Icons.phone,
          hint: '07XXXXXXXX',
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
        ),
        
        _buildTextField(
          controller: _emailController,
          label: 'Email (Optional)',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        
        _buildTextField(
          controller: _ninController,
          label: 'National ID (NIN)',
          icon: Icons.badge,
          hint: 'CM1234567890123',
          validator: (v) {
            if (v == null || v.isEmpty) return 'NIN is required';
            if (v.length < 10) return 'Enter valid NIN';
            return null;
          },
        ),
        
        _buildDropdownField(
          value: _gender,
          label: 'Gender',
          icon: Icons.wc,
          items: ['Male', 'Female', 'Other'],
          onChanged: (v) => setState(() => _gender = v!),
        ),
        
        _buildDateField(),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Details',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Specify where the member is located',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        _buildTextField(
          controller: _villageController,
          label: 'Village',
          icon: Icons.home,
          validator: (v) => v!.isEmpty ? 'Village is required' : null,
        ),
        
        _buildTextField(
          controller: _parishController,
          label: 'Parish',
          icon: Icons.location_city,
          validator: (v) => v!.isEmpty ? 'Parish is required' : null,
        ),
        
        _buildTextField(
          controller: _subcountyController,
          label: 'Sub-county',
          icon: Icons.place,
          validator: (v) => v!.isEmpty ? 'Sub-county is required' : null,
        ),
        
        _buildTextField(
          controller: _countyController,
          label: 'County/Division',
          icon: Icons.map,
        ),
        
        _buildTextField(
          controller: _districtController,
          label: 'District',
          icon: Icons.location_on,
          validator: (v) => v!.isEmpty ? 'District is required' : null,
        ),
      ],
    );
  }

  Widget _buildNextOfKinStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next of Kin',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Emergency contact information',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        _buildTextField(
          controller: _kinNameController,
          label: 'Next of Kin Name',
          icon: Icons.person_outline,
          validator: (v) => v!.isEmpty ? 'Next of kin name is required' : null,
        ),
        
        _buildTextField(
          controller: _kinPhoneController,
          label: 'Next of Kin Phone',
          icon: Icons.phone_outlined,
          hint: '07XXXXXXXX',
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
        ),
        
        _buildTextField(
          controller: _kinRelationshipController,
          label: 'Relationship',
          icon: Icons.family_restroom,
          hint: 'e.g., Father, Mother, Spouse, Sibling',
          validator: (v) => v!.isEmpty ? 'Relationship is required' : null,
        ),
        
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-Generated Information',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '✓ Account Number: Will be generated automatically\n'
                '✓ Member Number: Will be assigned sequentially\n'
                '✓ Login PIN: Last 4 digits of phone number',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: GoogleFonts.poppins(fontSize: 14),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
            firstDate: DateTime(1950),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            setState(() => _dateOfBirth = date);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of Birth (Optional)',
            prefixIcon: Icon(Icons.cake, color: AppTheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: Text(
            _dateOfBirth != null
                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                : 'Select date of birth',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _dateOfBirth != null ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}

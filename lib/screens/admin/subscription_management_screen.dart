import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/sacco_service.dart';
import '../../theme/modern_theme.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  final bool embedded;
  
  const SubscriptionManagementScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  bool _loading = false;
  DateTime? _selectedDate;
  String _selectedPlan = 'Starter';

  final _plans = ['Free', 'Starter', 'Growth', 'Enterprise'];
  final _planPrices = {
    'Free': 0,
    'Starter': 100000,
    'Growth': 350000,
    'Enterprise': 750000,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = SaccoService.current.subscriptionEnd ?? DateTime.now().add(const Duration(days: 30));
    _selectedPlan = SaccoService.current.subscriptionPlan ?? 'Starter';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveSubscription() async {
    if (_selectedDate == null) {
      _showSnack('Please select an expiry date', Colors.red);
      return;
    }

    setState(() => _loading = true);

    try {
      final tenantId = SaccoService.current.tenantId;
      
      // Save to Firestore
      await FirebaseFirestore.instance.collection('saccoplus-saccos').doc(tenantId).set({
        'subscriptionEnd': Timestamp.fromDate(_selectedDate!.add(const Duration(hours: 23, minutes: 59))),
        'subscriptionPlan': _selectedPlan,
        'subscriptionStatus': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _loading = false);
        _showSnack('✅ Subscription saved! Restart app to see changes.', Colors.green);
        
        // Navigate back after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('❌ Failed: $e', Colors.red);
      }
    }
  }

  void _quickSet(int months) {
    setState(() => _selectedDate = DateTime.now().add(Duration(days: months * 30)));
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ModernTheme.primaryBlue,
        title: Text('Subscription Management', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatus(),
            const SizedBox(height: 24),
            Text('Update Subscription', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildPlanSelector(),
            const SizedBox(height: 16),
            _buildDateSelector(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatus() {
    final sacco = SaccoService.current;
    final expiry = sacco.subscriptionEnd;
    final daysLeft = sacco.daysUntilExpiry;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ModernTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shield, color: ModernTheme.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Subscription', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(sacco.saccoName, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow('Plan', sacco.subscriptionPlan ?? 'Not set'),
          const SizedBox(height: 8),
          _infoRow('Status', (sacco.subscriptionStatus ?? 'trial').toUpperCase(),
              valueColor: sacco.isSubscriptionExpired ? Colors.red : Colors.green),
          const SizedBox(height: 8),
          _infoRow('Expires', expiry != null ? DateFormat('d MMM yyyy').format(expiry) : 'Not set',
              valueColor: daysLeft != null && daysLeft < 7 ? Colors.orange : null),
          if (daysLeft != null) ...[
            const SizedBox(height: 8),
            _infoRow('Days Left', daysLeft < 0 ? 'EXPIRED' : '$daysLeft days',
                valueColor: daysLeft < 0 ? Colors.red : daysLeft <= 2 ? Colors.orange : Colors.green),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Plan', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _plans.map((plan) {
              final isSelected = _selectedPlan == plan;
              return InkWell(
                onTap: () => setState(() => _selectedPlan = plan),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? ModernTheme.primaryBlue : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(plan, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, 
                          color: isSelected ? Colors.white : Colors.black87)),
                      Text('UGX ${NumberFormat('#,###').format(_planPrices[plan])}/mo', 
                          style: GoogleFonts.poppins(fontSize: 11, color: isSelected ? Colors.white70 : Colors.grey.shade600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expiry Date', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_selectedDate != null ? DateFormat('EEEE, d MMMM yyyy').format(_selectedDate!) : 'Select date',
                      style: GoogleFonts.poppins(fontSize: 14)),
                  const Icon(Icons.calendar_today, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _quickButton('1 month', 1),
              _quickButton('3 months', 3),
              _quickButton('6 months', 6),
              _quickButton('1 year', 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _saveSubscription,
        style: ElevatedButton.styleFrom(
          backgroundColor: ModernTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Text('Save Subscription', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }

  Widget _quickButton(String label, int months) {
    return OutlinedButton(
      onPressed: () => _quickSet(months),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 12)),
    );
  }
}

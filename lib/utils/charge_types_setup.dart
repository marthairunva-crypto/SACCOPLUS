import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/charge_service.dart';
import '../core/firebase_service.dart';

/// Helper to check and prompt for charge types setup
class ChargeTypesSetup {
  static final _db = FirebaseFirestore.instance;

  /// Check if charge types exist for this tenant
  static Future<bool> hasChargeTypes() async {
    try {
      final tenantId = FirebaseService.sessionTenantId;
      final snapshot = await _db
          .collection('charge_types')
          .where('tenantId', isEqualTo: tenantId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Show setup dialog if charge types don't exist
  static Future<void> checkAndPrompt(BuildContext context) async {
    final hasTypes = await hasChargeTypes();
    if (!hasTypes && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _SetupDialog(),
      );
    }
  }
}

class _SetupDialog extends StatefulWidget {
  const _SetupDialog();

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  bool _loading = false;

  Future<void> _seed() async {
    setState(() => _loading = true);
    try {
      final tenantId = FirebaseService.sessionTenantId;
      await ChargeService.seedDefaultChargeTypes(tenantId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charge types created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_suggest, color: Colors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Setup Required', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To use loan charges, you need to set up charge types first.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Text(
            'This will create the following default charge types:',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _chargeTypeItem('Late Payment Fee', '2% of overdue instalment'),
          _chargeTypeItem('Demand Letter Fee', 'UGX 50,000 flat'),
          _chargeTypeItem('Recovery Fee', '5% of arrears'),
          _chargeTypeItem('Legal Fee', 'Manual amount'),
          _chargeTypeItem('Rescheduling Fee', 'UGX 100,000 flat'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You only need to do this once. You can add more charge types later in Settings.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.amber[900]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Skip for now'),
        ),
        FilledButton(
          onPressed: _loading ? null : _seed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            minimumSize: const Size(140, 44),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create charge types'),
        ),
      ],
    );
  }

  Widget _chargeTypeItem(String name, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.black54,
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

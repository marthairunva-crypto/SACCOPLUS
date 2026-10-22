import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/charge_service.dart';
import '../core/firebase_service.dart';

/// Button widget to seed default charge types
/// Can be added to Settings screen or Admin Dashboard
class SeedChargeTypesButton extends StatefulWidget {
  const SeedChargeTypesButton({Key? key}) : super(key: key);

  @override
  State<SeedChargeTypesButton> createState() => _SeedChargeTypesButtonState();
}

class _SeedChargeTypesButtonState extends State<SeedChargeTypesButton> {
  bool _loading = false;

  Future<void> _seedChargeTypes() async {
    setState(() => _loading = true);

    try {
      final tenantId = FirebaseService.sessionTenantId;
      await ChargeService.seedDefaultChargeTypes(tenantId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Default charge types created successfully!',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _seedChargeTypes,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.local_florist, size: 18),
      label: Text(_loading ? 'Creating...' : 'Seed Charge Types'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1E3A8A),
        minimumSize: const Size(180, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

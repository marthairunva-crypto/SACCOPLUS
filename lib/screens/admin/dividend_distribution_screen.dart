import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../core/theme.dart';
import '../../widgets/app_widgets.dart';

class DividendDistributionScreen extends StatefulWidget {
  const DividendDistributionScreen({super.key});
  @override
  State<DividendDistributionScreen> createState() => _DividendDistributionScreenState();
}

class _DividendDistributionScreenState extends State<DividendDistributionScreen> {
  final _dividendPerShareCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _loading = false;
  final fmt = NumberFormat('#,###', 'en_US');

  @override
  void dispose() {
    _dividendPerShareCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _distributeDividends() async {
    final dividendPerShare = double.tryParse(_dividendPerShareCtrl.text.trim());
    final description = _descriptionCtrl.text.trim();
    
    if (dividendPerShare == null || dividendPerShare <= 0) {
      _snack('Enter a valid dividend amount per share', AppTheme.error);
      return;
    }
    
    if (description.isEmpty) {
      _snack('Enter a description for this dividend distribution', AppTheme.error);
      return;
    }

    // Confirm action
    final confirmed = await _showConfirmDialog(dividendPerShare, description);
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final adminUid = FirebaseService.sessionUid;
      
      await FirebaseService.distributeDividends(
        dividendPerShare: dividendPerShare,
        description: description,
        adminUid: adminUid,
      );
      
      _snack('Dividends distributed successfully to all shareholders!', AppTheme.success);
      _dividendPerShareCtrl.clear();
      _descriptionCtrl.clear();
    } catch (e) {
      _snack('Error: ${e.toString()}', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showConfirmDialog(double dividendPerShare, String description) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Dividend Distribution', 
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to distribute dividends:', 
                style: GoogleFonts.poppins()),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount per share: UGX ${fmt.format(dividendPerShare.round())}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text('Description: $description',
                      style: GoogleFonts.poppins()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('This action cannot be undone. Continue?',
                style: GoogleFonts.poppins(color: AppTheme.warning)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Distribute'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Dividend Distribution'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Distribute dividends to all shareholders based on their share holdings. The amount will be added to their savings accounts.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.info),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Dividend Distribution',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('Enter the dividend amount per share and description.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.textSecondary)),
            
            const SizedBox(height: 20),

            TextField(
              controller: _dividendPerShareCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              decoration: const InputDecoration(
                labelText: 'Dividend per Share (UGX)',
                prefixIcon: Icon(Icons.monetization_on_rounded),
                hintText: 'e.g. 500',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_rounded),
                hintText: 'e.g. Annual dividend for 2024',
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Distribute Dividends',
              loading: _loading,
              onPressed: _distributeDividends,
              icon: Icons.share_rounded,
            ),

            const SizedBox(height: 16),

            // Warning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This action will immediately distribute dividends to all shareholders and cannot be undone. Ensure the amount is correct.',
                      style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
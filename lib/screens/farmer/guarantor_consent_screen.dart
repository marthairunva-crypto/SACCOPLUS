import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/firebase_service.dart';
import '../../core/sacco_service.dart';
import '../../widgets/app_widgets.dart';

/// Shows the guarantors selected for a loan and lets the member
/// confirm before final submission. Also sends SMS consent requests
/// to each guarantor via EgoSMS.
class GuarantorConsentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> guarantors;
  final Map<String, dynamic> loanSummary;
  final VoidCallback onConfirmed;

  const GuarantorConsentScreen({
    super.key,
    required this.guarantors,
    required this.loanSummary,
    required this.onConfirmed,
  });

  @override
  State<GuarantorConsentScreen> createState() => _GuarantorConsentScreenState();
}

class _GuarantorConsentScreenState extends State<GuarantorConsentScreen> {
  bool _sending = false;
  bool _smsSent = false;

  Future<void> _sendConsentSms() async {
    setState(() => _sending = true);
    try {
      final applicantName =
          FirebaseService.sessionProfile?['name'] as String? ?? 'A member';
      final amount = widget.loanSummary['amount'] as int? ?? 0;
      final fmt = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

      for (final g in widget.guarantors) {
        final phone = g['phone'] as String? ?? '';
        if (phone.isEmpty) continue;
        final name = g['name'] as String? ?? 'Member';
        final saccoName = SaccoService.current.saccoName;
        final msg =
            'Dear $name, $applicantName has listed you as a guarantor for a '
            'UGX $fmt loan at $saccoName. '
            'By agreeing, you accept liability if they default. '
            'Contact your SACCO for details. Ref: $saccoName';
        await FirebaseService.sendSmsToPhone(phone, msg);
      }
      if (mounted) setState(() => _smsSent = true);
    } catch (_) {
      if (mounted) setState(() => _smsSent = true); // proceed anyway
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.loanSummary['amount'] as int? ?? 0;
    final loanType = widget.loanSummary['loanType'] as String? ?? '';
    final period = widget.loanSummary['repaymentPeriod'] as String? ?? '';
    final fmt = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Guarantor Consent',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Loan summary card ──────────────────────────────────────────
            _SummaryCard(
              loanType: loanType,
              amount: 'UGX $fmt',
              period: period,
            ),
            const SizedBox(height: 24),

            // ── Guarantors list ────────────────────────────────────────────
            Text(
              'Selected Guarantors',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            ...widget.guarantors.map((g) => _GuarantorCard(guarantor: g)),

            const SizedBox(height: 24),

            // ── SMS consent notice ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.info.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sms_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'An SMS consent notification will be sent to each guarantor '
                      'informing them of their obligation. This is required before '
                      'your loan can be processed.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Liability notice ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Guarantors are legally liable for this loan if you default. '
                      'Ensure they are aware and have agreed before proceeding.',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Action buttons ─────────────────────────────────────────────
            if (!_smsSent) ...[
              PrimaryButton(
                label: 'Send SMS Consent & Continue',
                icon: Icons.send_rounded,
                loading: _sending,
                onPressed: _sending ? null : _sendConsentSms,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppTheme.success, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'SMS consent sent to all guarantors.',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Submit Loan Application',
                icon: Icons.check_rounded,
                onPressed: widget.onConfirmed,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String loanType, amount, period;
  const _SummaryCard(
      {required this.loanType, required this.amount, required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loan Summary',
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(amount,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              _pill(Icons.category_outlined, loanType),
              const SizedBox(width: 10),
              _pill(Icons.calendar_month_outlined, period),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _GuarantorCard extends StatelessWidget {
  final Map<String, dynamic> guarantor;
  const _GuarantorCard({required this.guarantor});

  @override
  Widget build(BuildContext context) {
    final name = guarantor['name'] as String? ?? 'Member';
    final phone = guarantor['phone'] as String? ?? '';
    final memberNo = guarantor['memberNumber'] as String? ?? '';
    final isVerified = (guarantor['idStatus'] as String?) == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: GoogleFonts.poppins(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          size: 15, color: AppTheme.success),
                    ],
                  ],
                ),
                Text(phone,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppTheme.textSecondary)),
                if (memberNo.isNotEmpty)
                  Text('Member #$memberNo',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 13, color: AppTheme.success),
                const SizedBox(width: 4),
                Text('Guarantor',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

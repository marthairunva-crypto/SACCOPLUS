import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.title, required this.value, required this.icon, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(title, style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textSecondary, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});
  Color get _color { switch (status) { case 'Approved': case 'Active': return const Color(0xFF4CAF50); case 'Pending': return const Color(0xFFFF9800); case 'Rejected': return const Color(0xFFF44336); case 'Paid': return const Color(0xFF2196F3); default: return const Color(0xFF9E9E9E); } }
  IconData get _icon { switch (status) { case 'Approved': case 'Active': return Icons.check_circle_rounded; case 'Pending': return Icons.schedule_rounded; case 'Rejected': return Icons.cancel_rounded; case 'Paid': return Icons.verified_rounded; default: return Icons.info_rounded; } }
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _color.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_icon, size: 13, color: _color), const SizedBox(width: 4), Text(status, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _color))]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: GoogleFonts.poppins(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w500))),
    ]);
  }
}

class LoanListTile extends StatelessWidget {
  final String loanId, amount, purpose, date, status;
  final VoidCallback? onTap;
  const LoanListTile({super.key, required this.loanId, required this.amount, required this.purpose, required this.date, required this.status, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(amount, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
            Text(purpose, style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondary)),
            Text(date, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
          ])),
          StatusBadge(status: status),
        ]),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)], Text(label)]),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const InfoRow({super.key, required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        ])),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text(message, style: GoogleFonts.poppins(fontSize: 15, color: AppTheme.textSecondary), textAlign: TextAlign.center),
    ]));
  }
}

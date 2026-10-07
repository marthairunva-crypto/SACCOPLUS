import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/firebase_service.dart';
import '../../services/till_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Shared design system for the Till / Teller screens.
// Put this file in the SAME folder as till_management_screen.dart.
// ═══════════════════════════════════════════════════════════════════════════════
class TC {
  static const navy = Color(0xFF0B2545);
  static const blue = Color(0xFF1D4ED8);
  static const bg = Color(0xFFF4F6FA);
  static const border = Color(0xFFE3E8EF);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const green = Color(0xFF15803D);
  static const red = Color(0xFFB91C1C);
  static const amber = Color(0xFFB45309);
  static const teal = Color(0xFF0F766E);
  static const purple = Color(0xFF6D28D9);
}

TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color c = TC.text, double? ls}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, letterSpacing: ls);

final NumberFormat _moneyFmt = NumberFormat('#,##0', 'en_US');
String money(num v) => _moneyFmt.format(v.round());
String ugx(num v) => v < 0 ? '-UGX ${money(v.abs())}' : 'UGX ${money(v)}';

BoxDecoration cardDeco({Color color = Colors.white, Color? border}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border ?? TC.border),
    );

InputDecoration fieldDeco(String label,
    {String? prefix, String? hint, String? error, Widget? suffix, String? helper}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    errorText: error,
    helperText: helper,
    suffixIcon: suffix,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    labelStyle: ts(13, c: TC.muted),
    border: b(TC.border),
    enabledBorder: b(TC.border),
    focusedBorder: b(TC.blue, 1.6),
    errorBorder: b(TC.red),
    focusedErrorBorder: b(TC.red, 1.6),
  );
}

void tillToast(BuildContext context, String msg, {bool error = false, bool warn = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: ts(13, c: Colors.white)),
      backgroundColor: error ? TC.red : (warn ? TC.amber : TC.green),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: (error || warn) ? 5 : 3),
    ));
}

String currentTellerName() {
  final p = FirebaseService.sessionProfile;
  final n = (p?['name'] ?? p?['fullName'])?.toString();
  return (n == null || n.trim().isEmpty) ? 'Teller' : n;
}

String cleanError(Object e) {
  if (e is InsufficientCashException) {
    return 'Insufficient cash in till. Available ${ugx(e.available)}, required ${ugx(e.required)}.';
  }
  var s = e.toString();
  for (final p in ['Exception: ', 'TillClosedException: ', 'NoOpenSessionException: ']) {
    s = s.replaceFirst(p, '');
  }
  return s;
}

// ─── Entry types ──────────────────────────────────────────────────────────────
class EntryMeta {
  final String label;
  final IconData icon;
  final Color color;
  const EntryMeta(this.label, this.icon, this.color);
}

EntryMeta entryMeta(String type, int amount) {
  switch (type) {
    case 'opening_float':
      return const EntryMeta('Opening float', Icons.flag_outlined, TC.blue);
    case 'vault_topup':
      return const EntryMeta('Vault top-up', Icons.south_west_rounded, TC.green);
    case 'vault_sweep':
      return const EntryMeta('Vault sweep', Icons.north_east_rounded, TC.amber);
    case 'deposit':
      return const EntryMeta('Member deposit', Icons.add_circle_outline, TC.green);
    case 'withdrawal':
      return const EntryMeta('Member withdrawal', Icons.remove_circle_outline, TC.red);
    case 'loan_repayment':
      return const EntryMeta('Loan repayment', Icons.payments_outlined, TC.green);
    case 'reversal':
      return const EntryMeta('Reversal', Icons.undo_rounded, TC.purple);
    default:
      final t = type.replaceAll('_', ' ');
      final label = t.isEmpty ? 'Entry' : '${t[0].toUpperCase()}${t.substring(1)}';
      return EntryMeta(label, amount >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
          amount >= 0 ? TC.green : TC.red);
  }
}

Color statusColor(String s) =>
    s == 'open' ? TC.green : (s == 'pending_approval' ? TC.amber : TC.muted);

String statusLabel(String s) {
  if (s == 'pending_approval') return 'Pending approval';
  if (s.isEmpty) return '';
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Widgets ──────────────────────────────────────────────────────────────────
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool solid;
  const StatusPill(this.label, this.color, {super.key, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: solid ? color : color.withOpacity(0.45)),
      ),
      child: Text(label, style: ts(11, w: FontWeight.w700, c: solid ? Colors.white : color)),
    );
  }
}

class TillKpi extends StatelessWidget {
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  final bool highlight;
  const TillKpi({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? Colors.white : TC.navy;
    final muted = highlight ? Colors.white70 : TC.muted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDeco(color: highlight ? TC.navy : Colors.white, border: highlight ? TC.navy : null),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withOpacity(0.14) : color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: highlight ? Colors.white : color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ts(11.5, w: FontWeight.w500, c: muted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: ts(18, w: FontWeight.w700, c: fg)),
                ),
                if (sub != null) Text(sub!, style: ts(11, c: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TillKpiGrid extends StatelessWidget {
  final List<Widget> children;
  final int maxCols;
  const TillKpiGrid({super.key, required this.children, this.maxCols = 4});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      var cols = w >= 900 ? maxCols : (w >= 560 ? 2 : 1);
      if (cols > maxCols) cols = maxCols;
      const gap = 12.0;
      final itemW = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children.map((e) => SizedBox(width: itemW, child: e)).toList(),
      );
    });
  }
}

class TillStateMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const TillStateMessage({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: ts(18, w: FontWeight.w700, c: TC.navy)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, style: ts(13, c: TC.muted)),
              if (actionLabel != null) ...[
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TC.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(actionLabel!, style: ts(13, w: FontWeight.w600, c: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Widget dialogTitle(IconData icon, Color color, String title) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Flexible(child: Text(title, style: ts(17, w: FontWeight.w700, c: TC.navy))),
    ],
  );
}

ButtonStyle primaryButton(Color color) => ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
    );

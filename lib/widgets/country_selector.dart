/// Reusable country selector widget for multi-country MarzPay payments.
///
/// Shows all 12 supported markets with flag + name. Uganda is default.
/// When a country is selected:
///  - [onCountryChanged] fires with the new PaymentCountry
///  - If DRC is selected, a currency picker (CDF / USD) appears
///
/// Usage:
///   CountrySelector(
///     selected: _selectedCountry,
///     selectedCurrency: _selectedCurrency,
///     onCountryChanged: (c) => setState(() => _selectedCountry = c),
///     onCurrencyChanged: (cur) => setState(() => _selectedCurrency = cur),
///   )

// Country selector widget for multi-country MarzPay payments.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/payment_countries.dart';

export '../core/payment_countries.dart' show PaymentCountry, PaymentCountries;

class CountrySelector extends StatelessWidget {
  final PaymentCountry selected;
  final String? selectedCurrency; // relevant for DRC only
  final ValueChanged<PaymentCountry> onCountryChanged;
  final ValueChanged<String>? onCurrencyChanged;
  final bool compact; // if true, shows a small chip instead of full card

  const CountrySelector({
    super.key,
    required this.selected,
    this.selectedCurrency,
    required this.onCountryChanged,
    this.onCurrencyChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildChip(context);
    return _buildCard(context);
  }

  // ── Full card (used in deposit/withdraw modals) ──────────────────────────

  Widget _buildCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country selector row
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Row(
              children: [
                Text(selected.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.name,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        '${selected.currencySymbol} · ${selected.networks.join(', ')}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade500),
              ],
            ),
          ),
        ),

        // DRC currency picker
        if (selected.isDualCurrency && onCurrencyChanged != null) ...[
          const SizedBox(height: 10),
          _buildDrcCurrencyPicker(),
        ],
      ],
    );
  }

  // ── Compact chip (used inline where space is limited) ───────────────────

  Widget _buildChip(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(selected.code,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  // ── DRC dual-currency toggle ─────────────────────────────────────────────

  Widget _buildDrcCurrencyPicker() {
    final cur = selectedCurrency ?? 'CDF';
    return Row(
      children: ['CDF', 'USD'].map((c) {
        final isSelected = cur == c;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onCurrencyChanged?.call(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(c,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey.shade700)),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Bottom-sheet picker ──────────────────────────────────────────────────

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        selected: selected,
        onSelected: (country) {
          Navigator.pop(context);
          onCountryChanged(country);
          // Reset currency to default when country changes
          if (onCurrencyChanged != null) {
            onCurrencyChanged!(country.currency);
          }
        },
      ),
    );
  }
}

// ── Full-screen country picker sheet ────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final PaymentCountry selected;
  final ValueChanged<PaymentCountry> onSelected;

  const _CountryPickerSheet({
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _search = '';

  List<PaymentCountry> get _filtered {
    if (_search.isEmpty) return PaymentCountries.all;
    final q = _search.toLowerCase();
    return PaymentCountries.all
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.currency.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text('Select Country',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade500),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search country…',
                  hintStyle: GoogleFonts.poppins(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            // Country list
            Expanded(
              child: Material(
                color: Colors.white,
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final c = _filtered[i];
                    final isSelected = c.code == widget.selected.code;
                    return ListTile(
                      onTap: () => widget.onSelected(c),
                      leading: Text(c.flag,
                          style: const TextStyle(fontSize: 26)),
                      title: Text(c.name,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF1565C0)
                                  : Colors.black87)),
                      subtitle: Text(
                        '${c.currencySymbol} · ${c.networks.join(', ')}',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF1565C0), size: 20)
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

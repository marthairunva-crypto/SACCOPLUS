/// AfricaPaymentsBanner
///
/// A full-width marketing card that communicates SACCOPLUS's 12-country
/// MarzPay payment capability. Drop it anywhere in the app:
///
///   AfricaPaymentsBanner()                        // default — full width
///   AfricaPaymentsBanner(compact: true)           // slim version for dashboards
///
/// Tapping it does nothing by default; pass [onTap] to navigate.

// Africa payments banner widget for SACCOPLUS 12-country marketing.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/payment_countries.dart';

class AfricaPaymentsBanner extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const AfricaPaymentsBanner({super.key, this.compact = false, this.onTap});

  // Brand colours
  static const Color _navy  = Color(0xFF0D1B3E);
  static const Color _blue  = Color(0xFF1565C0);
  static const Color _gold  = Color(0xFFF9A825);
  static const Color _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  // ── Full banner ────────────────────────────────────────────────────────────

  Widget _buildFull(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_navy, Color(0xFF1A2F5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _navy.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header area ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.public_rounded,
                            color: _gold, size: 13),
                        const SizedBox(width: 5),
                        Text('NOW LIVE · 12 AFRICAN COUNTRIES',
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _gold,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Headline
                  Text(
                    'NOW ACCEPTING PAYMENTS\nACROSS 12 AFRICAN\nCOUNTRIES',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _white,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Sub-headline
                  Text(
                    'One SACCO platform. Payments across Africa.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _white.withOpacity(0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Countries grid — 2 per row, fills banner width ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chipWidth = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PaymentCountries.all.map((c) {
                      return SizedBox(
                        width: chipWidth,
                        child: _CountryChip(country: c),
                      );
                    }).toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Divider ────────────────────────────────────────────────────
            Divider(color: _white.withOpacity(0.1), height: 1),

            // ── Footer ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  // MarzPay powered label — Flexible so it shrinks before chips
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: _white.withOpacity(0.6), size: 13),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text('Powered by MarzPay',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: _white.withOpacity(0.6),
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Mobile money icons — fixed, don't grow
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['MTN', 'M-Pesa', 'Airtel'].map((n) {
                      return Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(n,
                            style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _white.withOpacity(0.65))),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact slim banner (for dashboards / sidebars) ────────────────────────

  Widget _buildCompact(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_navy, _blue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.public_rounded, color: _gold, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payments in 12 African Countries',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _white)),
                  Text('Uganda · Kenya · Rwanda · DRC + 8 more',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _white.withOpacity(0.65))),
                ],
              ),
            ),
            // Flag strip
            Text(
              PaymentCountries.all.take(6).map((c) => c.flag).join(),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual country chip ────────────────────────────────────────────────────

class _CountryChip extends StatelessWidget {
  final PaymentCountry country;
  const _CountryChip({required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Text(country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  country.name,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  country.currencySymbol,
                  style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

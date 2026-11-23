import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/sacco_service.dart';

/// Warning banner shown when subscription is about to expire
/// Shows 7 days before expiry with countdown
class SubscriptionWarningBanner extends StatelessWidget {
  const SubscriptionWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sacco = SaccoService.current;
    final daysLeft = sacco.daysUntilExpiry;

    // Don't show if no expiry date or more than 7 days left
    if (daysLeft == null || daysLeft > 7) {
      return const SizedBox.shrink();
    }

    // Already expired - don't show banner (lock screen will show)
    if (daysLeft < 0) {
      return const SizedBox.shrink();
    }

    // Determine urgency level
    final isUrgent = daysLeft <= 2;
    final isCritical = daysLeft <= 1;

    final bgColor = isCritical
        ? const Color(0xFFDC2626) // Red for 1 day or less
        : isUrgent
            ? const Color(0xFFF59E0B) // Amber for 2 days
            : const Color(0xFFEF4444); // Orange for 3-7 days

    final expiryDate = sacco.subscriptionEnd!;
    final dateStr = DateFormat('d MMM yyyy').format(expiryDate);

    String message;
    IconData icon;

    if (daysLeft == 0) {
      message = 'Subscription expires TODAY!';
      icon = Icons.warning_amber_rounded;
    } else if (daysLeft == 1) {
      message = 'Subscription expires TOMORROW!';
      icon = Icons.warning_amber_rounded;
    } else if (daysLeft == 2) {
      message = 'Subscription expires in 2 days';
      icon = Icons.info_outline;
    } else {
      message = 'Subscription expires in $daysLeft days';
      icon = Icons.info_outline;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Renew before $dateStr to avoid service interruption',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Contact button
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Renew',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: bgColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

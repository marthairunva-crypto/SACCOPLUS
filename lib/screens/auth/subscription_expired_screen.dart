import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/sacco_service.dart';

/// Screen shown when SACCO subscription has expired.
/// Locks the entire system until subscription is renewed.
class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sacco = SaccoService.current;
    final expiry = sacco.subscriptionEnd;
    final expiryStr = expiry != null 
        ? DateFormat('d MMM yyyy').format(expiry)
        : 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Subscription Expired',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // SACCO Name
                Text(
                  sacco.saccoName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Message Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2d2d44),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.shade800.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 48,
                        color: Colors.amber.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your subscription expired on',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expiryStr,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'The system is now locked. Please renew your subscription to continue using SACCOPLUS.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Contact Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2d2d44),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'To renew your subscription, contact:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContactRow(
                        Icons.phone,
                        'Phone',
                        '+256 779 876 876',
                        Colors.green.shade400,
                      ),
                      const SizedBox(height: 12),
                      _buildContactRow(
                        Icons.email,
                        'Email',
                        'support@saccoplus.com',
                        Colors.blue.shade400,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Plan Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Plan: ${sacco.subscriptionPlan}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

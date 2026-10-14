import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SweetAlertType {
  success,
  error,
  warning,
  info,
}

class SweetAlert {
  static Future<void> show({
    required BuildContext context,
    required SweetAlertType type,
    required String title,
    String? message,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) {
    Color getColor() {
      switch (type) {
        case SweetAlertType.success:
          return const Color(0xFF4CAF50);
        case SweetAlertType.error:
          return const Color(0xFFF44336);
        case SweetAlertType.warning:
          return const Color(0xFFFF9800);
        case SweetAlertType.info:
          return const Color(0xFF2196F3);
      }
    }

    IconData getIcon() {
      switch (type) {
        case SweetAlertType.success:
          return Icons.check_circle_rounded;
        case SweetAlertType.error:
          return Icons.error_rounded;
        case SweetAlertType.warning:
          return Icons.warning_rounded;
        case SweetAlertType.info:
          return Icons.info_rounded;
      }
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SizedBox(
          width: 340,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with animation
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: getColor().withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getIcon(),
                        size: 32,
                        color: getColor(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Message
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Confirm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirm?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    confirmText,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }

  /// Confirmation dialog with Yes/No options
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    String? message,
    SweetAlertType type = SweetAlertType.warning,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) {
    Color getColor() {
      switch (type) {
        case SweetAlertType.success:
          return const Color(0xFF4CAF50);
        case SweetAlertType.error:
          return const Color(0xFFF44336);
        case SweetAlertType.warning:
          return const Color(0xFFFF9800);
        case SweetAlertType.info:
          return const Color(0xFF2196F3);
      }
    }

    IconData getIcon() {
      switch (type) {
        case SweetAlertType.success:
          return Icons.check_circle_rounded;
        case SweetAlertType.error:
          return Icons.error_rounded;
        case SweetAlertType.warning:
          return Icons.warning_rounded;
        case SweetAlertType.info:
          return Icons.info_rounded;
      }
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => Center(
        child: SizedBox(
          width: 340,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: getColor().withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getIcon(),
                  size: 32,
                  color: getColor(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Message
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: getColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        confirmText,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
        ),
      ),
    );
  }
}

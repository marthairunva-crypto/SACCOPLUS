import 'package:flutter/material.dart';

/// Centralized color palette for SACCOPLUS
/// Light Blue Theme - Professional & Clean
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY COLORS - Light Blue Theme
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Main background color for AppBars and headers
  static const Color primaryBackground = Color(0xFFE3F2FD); // blue.shade50
  
  /// Gradient start for headers and cards
  static const Color gradientStart = Color(0xFFBBDEFB); // blue.shade100
  
  /// Gradient end for headers and cards
  static const Color gradientEnd = Color(0xFF90CAF9); // blue.shade200
  
  /// Border color for cards and inputs
  static const Color border = Color(0xFF64B5F6); // blue.shade300
  
  /// Accent color for buttons and highlights
  static const Color accent = Color(0xFF42A5F5); // blue.shade400
  
  /// Primary blue color
  static const Color primary = Color(0xFF2196F3); // blue.shade500
  
  /// Darker blue for important elements
  static const Color primaryDark = Color(0xFF1E88E5); // blue.shade600
  
  /// Even darker blue for hover states
  static const Color primaryDarker = Color(0xFF1976D2); // blue.shade700
  
  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Main text color (dark blue)
  static const Color textPrimary = Color(0xFF0D47A1); // blue.shade900
  
  /// Secondary text color (medium blue)
  static const Color textSecondary = Color(0xFF1565C0); // blue.shade800
  
  /// Tertiary text color (lighter blue)
  static const Color textTertiary = Color(0xFF1976D2); // blue.shade700
  
  /// Disabled text color
  static const Color textDisabled = Color(0xFF90A4AE);
  
  /// Label text color
  static const Color textLabel = Color(0xFF757575);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SURFACE COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Main surface/background color
  static const Color surface = Color(0xFFF5F7FA);
  
  /// Card background color
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  /// Hover background color
  static const Color hoverBackground = Color(0xFFE3F2FD);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Success color (green)
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF16A34A);
  
  /// Warning color (orange/amber)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);
  
  /// Error color (red)
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);
  
  /// Info color (blue)
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Card shadow with blue tint
  static BoxShadow get cardShadow => BoxShadow(
    color: const Color(0xFF2196F3).withOpacity(0.08),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
  
  /// Subtle card shadow
  static BoxShadow get cardShadowSubtle => BoxShadow(
    color: const Color(0xFF2196F3).withOpacity(0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
  
  /// Elevated card shadow
  static BoxShadow get cardShadowElevated => BoxShadow(
    color: const Color(0xFF2196F3).withOpacity(0.12),
    blurRadius: 16,
    offset: const Offset(0, 6),
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Primary gradient for headers
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Subtle gradient for backgrounds
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [primaryBackground, gradientStart],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CHART COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const Color chart1 = Color(0xFF3B82F6); // Blue
  static const Color chart2 = Color(0xFF10B981); // Green
  static const Color chart3 = Color(0xFF8B5CF6); // Purple
  static const Color chart4 = Color(0xFFF59E0B); // Orange
  static const Color chart5 = Color(0xFF06B6D4); // Cyan
  static const Color chart6 = Color(0xFFEF4444); // Red
}

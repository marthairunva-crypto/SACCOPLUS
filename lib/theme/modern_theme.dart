import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Modern Neumorphic (Soft UI) theme for MBADIFA SACCO
/// Features soft shadows, subtle depth, and clean aesthetics
class ModernTheme {
  // DEPRECATED: Use AppColors instead
  // Keeping these for backward compatibility
  @Deprecated('Use AppColors.primary instead')
  static const primaryBlue = Color(0xFF1E88E5);
  
  @Deprecated('Use AppColors.primaryDark instead')
  static const primaryBlueLight = Color(0xFF42A5F5);
  
  @Deprecated('Use AppColors.success instead')
  static const accentGreen = Color(0xFF4CAF50);
  
  @Deprecated('Use AppColors.warning instead')
  static const accentOrange = Color(0xFFFF9800);
  
  @Deprecated('Use AppColors.warning instead')
  static const accent = Color(0xFFFF9800);
  
  // NEW: Use AppColors for all new code
  static Color get primary => AppColors.primary;
  static Color get primaryLight => AppColors.accent;
  static Color get primaryDark => AppColors.primaryDarker;
  static Color get surface => AppColors.surface;
  
  // Neumorphic background - soft light gray
  static const neumorphicBase = Color(0xFFE8EDF2);
  
  // Background colors
  static Color get bgWhite => AppColors.cardBackground;
  static Color get bgLight => neumorphicBase;
  static Color get bgCard => neumorphicBase;
  
  // Text colors  
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textLabel;
  static Color get textHint => AppColors.textDisabled;
  
  // Border colors
  static const borderLight = Color(0xFFE0E0E0);
  static const borderMedium = Color(0xFFBDBDBD);
  
  // Status colors
  static Color get success => AppColors.success;
  static Color get error => AppColors.error;
  static Color get warning => AppColors.warning;
  static Color get info => AppColors.info;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NEUMORPHIC SHADOWS - The essence of soft UI
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Light shadow (top-left) - gives raised effect
  static BoxShadow get neumorphicLightShadow => BoxShadow(
    color: Colors.white.withOpacity(0.9),
    offset: const Offset(-6, -6),
    blurRadius: 12,
    spreadRadius: 0,
  );
  
  /// Dark shadow (bottom-right) - gives depth
  static BoxShadow get neumorphicDarkShadow => BoxShadow(
    color: Colors.black.withOpacity(0.15),
    offset: const Offset(6, 6),
    blurRadius: 12,
    spreadRadius: 0,
  );
  
  /// Subtle light shadow for less prominent elements
  static BoxShadow get neumorphicLightShadowSubtle => BoxShadow(
    color: Colors.white.withOpacity(0.7),
    offset: const Offset(-3, -3),
    blurRadius: 6,
    spreadRadius: 0,
  );
  
  /// Subtle dark shadow for less prominent elements
  static BoxShadow get neumorphicDarkShadowSubtle => BoxShadow(
    color: Colors.black.withOpacity(0.1),
    offset: const Offset(3, 3),
    blurRadius: 6,
    spreadRadius: 0,
  );
  
  /// Inset/pressed effect shadows (inverted)
  static BoxShadow get neumorphicInsetLight => BoxShadow(
    color: Colors.black.withOpacity(0.15),
    offset: const Offset(-4, -4),
    blurRadius: 8,
    spreadRadius: 0,
  );
  
  static BoxShadow get neumorphicInsetDark => BoxShadow(
    color: Colors.white.withOpacity(0.7),
    offset: const Offset(4, 4),
    blurRadius: 8,
    spreadRadius: 0,
  );
  
  /// Standard neumorphic shadow list
  static List<BoxShadow> get neumorphicShadow => [
    neumorphicLightShadow,
    neumorphicDarkShadow,
  ];
  
  /// Subtle neumorphic shadow list
  static List<BoxShadow> get neumorphicShadowSubtle => [
    neumorphicLightShadowSubtle,
    neumorphicDarkShadowSubtle,
  ];
  
  /// Inset/pressed shadow list
  static List<BoxShadow> get neumorphicShadowInset => [
    neumorphicInsetLight,
    neumorphicInsetDark,
  ];
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER DECORATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Standard neumorphic container decoration
  static BoxDecoration neumorphicDecoration({
    Color? color,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
  }) => BoxDecoration(
    color: color ?? neumorphicBase,
    borderRadius: borderRadius ?? BorderRadius.circular(16),
    boxShadow: shadows ?? neumorphicShadow,
  );
  
  /// Subtle neumorphic container decoration
  static BoxDecoration neumorphicDecorationSubtle({
    Color? color,
    BorderRadius? borderRadius,
  }) => BoxDecoration(
    color: color ?? neumorphicBase,
    borderRadius: borderRadius ?? BorderRadius.circular(12),
    boxShadow: neumorphicShadowSubtle,
  );
  
  /// Inset/pressed neumorphic decoration
  static BoxDecoration neumorphicDecorationInset({
    Color? color,
    BorderRadius? borderRadius,
  }) => BoxDecoration(
    color: color ?? neumorphicBase,
    borderRadius: borderRadius ?? BorderRadius.circular(12),
    boxShadow: neumorphicShadowInset,
  );
  
  /// Main theme data with neumorphic styling
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: success,
      surface: neumorphicBase,
      error: error,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: neumorphicBase,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.25,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textPrimary,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textSecondary,
        height: 1.5,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
    ),
    
    // Neumorphic AppBar - soft and elevated
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: neumorphicBase,
      foregroundColor: textPrimary,
      shadowColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    
    // Neumorphic elevated buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: neumorphicBase,
        foregroundColor: primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ).copyWith(
        // Add neumorphic shadow on default state
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return neumorphicBase;
          }
          return neumorphicBase;
        }),
      ),
    ),
    
    // Soft outlined buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: neumorphicBase,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    
    // Soft text buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    // Neumorphic input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neumorphicBase,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: error, width: 2),
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textHint,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: primary,
        fontWeight: FontWeight.w500,
      ),
    ),
    
    // Neumorphic cards
    cardTheme: CardThemeData(
      elevation: 0,
      color: neumorphicBase,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8),
    ),
    
    // Neumorphic data tables
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(neumorphicBase),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withOpacity(0.08);
        }
        return null;
      }),
      decoration: BoxDecoration(
        color: neumorphicBase,
        borderRadius: BorderRadius.circular(16),
      ),
      headingTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      dataTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textPrimary,
      ),
    ),
    
    // Neumorphic dialogs
    dialogTheme: DialogThemeData(
      backgroundColor: neumorphicBase,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
        height: 1.5,
      ),
    ),
    
    // Bottom sheets
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: neumorphicBase,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    
    // Floating action buttons
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: neumorphicBase,
      selectedColor: primary.withOpacity(0.2),
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
  
  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS & SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Soft gradient for headers (optional use with neumorphism)
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8EDF2), Color(0xFFD4DDE5)],
  );
  
  /// Primary gradient (for accent elements)
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );
  
  /// Success button style with neumorphic effect
  static ButtonStyle get successButton => ElevatedButton.styleFrom(
    backgroundColor: success,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    textStyle: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  /// Primary button style with neumorphic effect
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    textStyle: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  /// Neumorphic button style (soft UI button)
  static ButtonStyle get neumorphicButton => ElevatedButton.styleFrom(
    backgroundColor: neumorphicBase,
    foregroundColor: textPrimary,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    textStyle: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
  
  /// Box shadow for cards (backward compatibility)
  @Deprecated('Use neumorphicShadow instead')
  static List<BoxShadow> get cardShadow => neumorphicShadowSubtle;
}

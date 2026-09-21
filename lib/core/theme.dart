import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── SACCOPLUS Pro Brand Palette ───────────────────────────────────────────
  // Extracted from official brand flyer
  static const Color primary      = Color(0xFF0D2B6B); // deep navy blue (main brand)
  static const Color primaryLight = Color(0xFF1A3F8F); // mid navy
  static const Color primaryDark  = Color(0xFF071A45); // darkest navy (headers/gradients)

  // Orange accent — the signature SACCOPLUS orange
  static const Color accent       = Color(0xFFF47920); // vibrant brand orange
  static const Color accentDark   = Color(0xFFD4620F); // deeper orange (pressed state)
  static const Color accentLight  = Color(0xFFFF9A45); // lighter orange (highlights)

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color surface       = Color(0xFFF4F6FA); // clean light grey-white
  static const Color cardBg        = Colors.white;
  static const Color textPrimary   = Color(0xFF071A45); // darkest navy for text
  static const Color textSecondary = Color(0xFF6B7A99); // muted blue-grey
  static const Color success       = Color(0xFF22C55E);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color error         = Color(0xFFEF4444);
  static const Color info          = Color(0xFF0D2B6B);  // navy for info

  // ── Dark card colors (for cards on dark/navy backgrounds) ─────────────────
  static const Color darkCard      = Color(0xFF122F75); // card on navy bg
  static const Color darkCardLight = Color(0xFF1A3F8F); // lighter navy card

  // ── Divider / border ──────────────────────────────────────────────────────
  static const Color divider       = Color(0xFFE4E8F0);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(),
      scaffoldBackgroundColor: surface,

      // ── AppBar — deep navy, edge-to-edge ──────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ── Buttons — orange accent ────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.poppins(color: Color(0xFFAAAAAA), fontSize: 14),
        prefixIconColor: primary,
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: primary.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE4E8F0)),
        ),
      ),

      // ── Bottom nav ────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF9EACC0),
        selectedLabelStyle:
            GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      // ── Tab bar ───────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: accent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
      ),
    );
  }
}

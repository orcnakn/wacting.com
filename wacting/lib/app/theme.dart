import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// COLOR PALETTE — Wix Business Consulting inspired
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Navy (primary)
  static const Color navyPrimary  = Color(0xFF2C3E50);
  static const Color navyDark     = Color(0xFF1A252F);
  static const Color navyLight    = Color(0xFF34495E);

  // Backgrounds
  static const Color pageBackground = Color(0xFFFFFFFF);
  static const Color surfaceWhite   = Color(0xFFFFFFFF);
  static const Color surfaceLight   = Color(0xFFF8F9FA);

  // Borders / dividers
  static const Color borderLight  = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);

  // Text
  static const Color textPrimary   = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF5D6D7E);
  static const Color textTertiary  = Color(0xFF95A5A6);

  // Accents
  static const Color accentTeal  = Color(0xFF1ABC9C);
  static const Color accentBlue  = Color(0xFF2980B9);
  static const Color accentAmber = Color(0xFFF39C12);
  static const Color accentRed   = Color(0xFFE74C3C);
  static const Color accentGreen = Color(0xFF27AE60);

  // Nav bar
  static const Color navSelected   = Color(0xFFFFFFFF);
  static const Color navUnselected = Color(0xFF95A5A6);
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  // Headings — Playfair Display (serif)
  static TextStyle headingLarge = GoogleFonts.playfairDisplay(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1.5,
  );
  static TextStyle headingMedium = GoogleFonts.playfairDisplay(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 1.0,
  );
  static TextStyle headingSmall = GoogleFonts.playfairDisplay(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  // Body — DM Sans (sans-serif)
  static TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
  );

  // UI — DM Sans
  static TextStyle buttonText = GoogleFonts.dmSans(
    fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5,
  );
  static TextStyle caption = GoogleFonts.dmSans(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary,
  );
  static TextStyle label = GoogleFonts.dmSans(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.pageBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navyPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.accentBlue,
        onSecondary: Colors.white,
        surface: AppColors.surfaceWhite,
        onSurface: AppColors.textPrimary,
        error: AppColors.accentRed,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.dmSansTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navyPrimary,
        selectedItemColor: AppColors.navSelected,
        unselectedItemColor: AppColors.navUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navyPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      dividerColor: AppColors.borderLight,
      tabBarTheme: const TabBarTheme(
        indicatorColor: AppColors.accentBlue,
        labelColor: AppColors.accentBlue,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyPrimary,
          side: const BorderSide(color: AppColors.borderMedium),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navyPrimary,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

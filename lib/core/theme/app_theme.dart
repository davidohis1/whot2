import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Background layers
  static const bg0 = Color(0xFF0A0E1A);
  static const bg1 = Color(0xFF0F1526);
  static const bg2 = Color(0xFF151D35);
  static const bg3 = Color(0xFF1C2640);

  // Brand / Accent
  static const gold    = Color(0xFFFFD700);
  static const goldDim = Color(0xFFB8960C);
  static const teal    = Color(0xFF00E5CC);
  static const tealDim = Color(0xFF00A896);
  static const purple  = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFA855F7);

  // Game colours
  static const chessLight = Color(0xFFF0D9B5);
  static const chessDark  = Color(0xFFB58863);
  static const chessBorder = Color(0xFF8B6914);

  // Status
  static const success = Color(0xFF22C55E);
  static const danger  = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info    = Color(0xFF3B82F6);

  // Text
  static const textPrimary   = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted     = Color(0xFF475569);

  // Card / border
  static const cardBorder = Color(0xFF1E2D4D);
  static const divider    = Color(0xFF1E293B);

  // Whot shape colours
  static const circle   = Color(0xFF3B82F6);
  static const triangle = Color(0xFF22C55E);
  static const cross    = Color(0xFFEF4444);
  static const square   = Color(0xFFF59E0B);
  static const star     = Color(0xFFA855F7);
  static const whotCard = Color(0xFFFFD700);

  // Gradients
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFB8960C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientTeal = LinearGradient(
    colors: [Color(0xFF00E5CC), Color(0xFF0070F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientPurple = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientBg = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF0F1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg0,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.teal,
        secondary: AppColors.gold,
        surface: AppColors.bg2,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          displaySmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textSecondary),
          bodySmall: TextStyle(color: AppColors.textMuted),
          labelLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          labelMedium: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(color: AppColors.textMuted),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: AppColors.bg0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bg3,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
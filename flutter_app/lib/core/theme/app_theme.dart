import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class AppTheme {
  // Legacy border radius for backward compatibility
  static const double borderRadius = 8.0;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight.background,
      primaryColor: AppColorsLight.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColorsLight.primary,
        onPrimary: AppColorsLight.surface,
        secondary: AppColorsLight.secondary,
        surface: AppColorsLight.surface,
        onSurface: AppColorsLight.textPrimary,
        error: AppColorsLight.error,
        onError: AppColorsLight.surface,
      ),

      textTheme: _buildTextTheme(baseTextTheme, AppColorsLight.textPrimary),
      
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsLight.surface,
        foregroundColor: AppColorsLight.textPrimary,
        elevation: DesignTokens.elevationNone,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColorsLight.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColorsLight.textPrimary),
      ),

      cardTheme: CardTheme(
        color: AppColorsLight.surface,
        elevation: DesignTokens.elevationSubtle,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          side: const BorderSide(color: AppColorsLight.border, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColorsDark.background,
      primaryColor: AppColorsDark.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        onPrimary: AppColorsDark.surface,
        secondary: AppColorsDark.secondary,
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.textPrimary,
        surfaceContainerHighest: AppColorsDark.surfaceElevated,
        error: AppColorsDark.error,
        onError: AppColorsDark.surface,
      ),

      textTheme: _buildTextTheme(baseTextTheme, AppColorsDark.textPrimary),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsDark.surface,
        foregroundColor: AppColorsDark.textPrimary,
        elevation: DesignTokens.elevationNone,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColorsDark.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColorsDark.textPrimary),
      ),

      cardTheme: CardTheme(
        color: AppColorsDark.surfaceElevated,
        elevation: DesignTokens.elevationNone,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          side: const BorderSide(color: AppColorsDark.border, width: 1),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, Color textColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
    );
  }
}

// Legacy Colors for backward compatibility with old screens
class AppColors {
  static const Color industrialBlue = Color(0xFF0288D1);
  static const Color deepGraphite = Color(0xFF263238);
  static const Color validationGreen = Color(0xFF2E7D32);
  static const Color warningYellow = Color(0xFFFBC02D);
  static const Color alertRed = Color(0xFFC62828);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color neutralLightGray = Color(0xFFF5F7F8);
  static const Color borderGray = Color(0xFFCFD8DC);
}


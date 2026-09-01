import 'package:flutter/material.dart';

class DesignTokens {
  // Spacing (8-point grid)
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;
  static const double spacing64 = 64.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 24.0;

  // Elevation
  static const double elevationNone = 0.0;
  static const double elevationSubtle = 2.0;
  static const double elevationStandard = 4.0;
}

class AppColorsLight {
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textDisabled = Color(0xFF94A3B8);
  
  static const Color border = Color(0xFFE2E8F0);
  
  static const Color primary = Color(0xFF2563EB); // Primary Blue
  static const Color secondary = Color(0xFF0EA5E9); // Secondary Security Blue
  static const Color accent = Color(0xFF7C3AED); // Accent Violet
  
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color critical = Color(0xFF991B1B);
}

class AppColorsDark {
  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF1E293B);
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textDisabled = Color(0xFF94A3B8); // Reusing light mode disabled as it fits
  
  static const Color border = Color(0xFF334155);
  
  static const Color primary = Color(0xFF3B82F6); // Lighter blue for dark mode
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color accent = Color(0xFF7C3AED);
  
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color critical = Color(0xFF991B1B);
}

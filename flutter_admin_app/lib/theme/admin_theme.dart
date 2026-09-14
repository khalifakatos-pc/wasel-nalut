import 'package:flutter/material.dart';

class AdminColors {
  static const Color background = Color(0xFF041710);      // Deep Nocturnal Emerald
  static const Color surface = Color(0xFF062319);         // Elevated Emerald Surface
  static const Color surfaceElevated = Color(0xFF0A3324); // Raised Emerald Card
  static const Color primaryGold = Color(0xFFD4AF37);     // Imperial Gold
  static const Color goldRadiance = Color(0xFFF5D061);    // Gold Radiance
  static const Color emeraldGreen = Color(0xFF10B981);    // Emerald Green
  static const Color skyBlue = Color(0xFF38BDF8);         // Tech Blue
  static const Color alertRed = Color(0xFFEF4444);        // Alert Red
  static const Color textPrimary = Color(0xFFF8F5EE);     // Champagne Ivory
  static const Color textSecondary = Color(0xFFD0C5AF);   // Muted Champagne
  static const Color divider = Color(0x33D4AF37);         // Gold Divider
}

class AdminTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AdminColors.background,
      primaryColor: AdminColors.primaryGold,
      fontFamily: 'sans-serif',
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.primaryGold,
        surface: AdminColors.surface,
        secondary: AdminColors.emeraldGreen,
        error: AdminColors.alertRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AdminColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminColors.divider, width: 1),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// MOTION & ANIMATION TOKENS (60 / 120 FPS HIGH PERFORMANCE)
/// ---------------------------------------------------------------------------
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);      // Quick controls, toggle switches
  static const Duration normal = Duration(milliseconds: 300);    // Tab transitions, modal sheets
  static const Duration slow = Duration(milliseconds: 500);      // Financial counter rolling
  static const Duration relaxed = Duration(milliseconds: 800);   // Live fleet beacon pulse
  static const Duration extended = Duration(milliseconds: 1200); // Radar sweep cycle
  static const Duration shimmer = Duration(milliseconds: 1500);  // Operations table shimmer

  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve springSnappy = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve decelerate = Curves.decelerate;
  static const Curve pulseCurve = Curves.easeInOutSine;
  static const Curve linear = Curves.linear;

  static const double pressScaleButton = 0.96;
  static const double pressScaleCard = 0.98;
}


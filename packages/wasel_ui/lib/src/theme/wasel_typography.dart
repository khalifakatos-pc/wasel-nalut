import 'package:flutter/material.dart';
import 'wasel_colors.dart';

/// ============================================================================
/// WASEL NALUT (واصل نالوت) - TYPOGRAPHY SYSTEM
/// ============================================================================
/// Binds Cairo (400–800) for authentic Arabic typography & UI labels,
/// and Outfit (500–800) for numeric telemetry, prices, and tracking codes.
/// Bound cleanly to package: 'wasel_ui' for offline zero-network rendering.
/// ============================================================================
class WaselTypography {
  const WaselTypography._();

  static const String package = 'wasel_ui';
  static const String fontFamilyArabic = 'Cairo';
  static const String fontFamilyNumeric = 'Outfit';

  /// Generates a [TextStyle] using Cairo bundled inside `wasel_ui`.
  static TextStyle cairo({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: fontFamilyArabic,
      package: package,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  /// Generates a [TextStyle] using Outfit bundled inside `wasel_ui`.
  static TextStyle outfit({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: fontFamilyNumeric,
      package: package,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  // --- Numeric & Telemetry Scales (Outfit) ---
  static TextStyle numberHero({Color? color}) => outfit(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: color,
      );

  static TextStyle numberLarge({Color? color}) => outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
      );

  static TextStyle numberMedium({Color? color}) => outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color,
      );

  static TextStyle numberSmall({Color? color}) => outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color,
      );

  /// Generates the standard Material 3 [TextTheme] for either brightness mode.
  static TextTheme textTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final primaryColor =
        isDark ? WaselColors.textPrimaryDark : WaselColors.textPrimaryLight;
    final secondaryColor =
        isDark ? WaselColors.textSecondaryDark : WaselColors.textSecondaryLight;
    final mutedColor =
        isDark ? WaselColors.textMutedDark : WaselColors.textMutedLight;

    return TextTheme(
      displayLarge: cairo(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: primaryColor,
        height: 1.25,
      ),
      displayMedium: cairo(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        height: 1.28,
      ),
      displaySmall: cairo(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        height: 1.3,
      ),
      headlineLarge: cairo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        height: 1.32,
      ),
      headlineMedium: cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.35,
      ),
      headlineSmall: cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.38,
      ),
      titleLarge: cairo(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        height: 1.4,
      ),
      titleMedium: cairo(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.4,
      ),
      titleSmall: cairo(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
        height: 1.4,
      ),
      bodyLarge: cairo(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.5,
      ),
      bodyMedium: cairo(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.5,
      ),
      bodySmall: cairo(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        height: 1.45,
      ),
      labelLarge: cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.3,
      ),
      labelMedium: cairo(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        height: 1.3,
      ),
      labelSmall: cairo(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: mutedColor,
        height: 1.3,
      ),
    );
  }
}

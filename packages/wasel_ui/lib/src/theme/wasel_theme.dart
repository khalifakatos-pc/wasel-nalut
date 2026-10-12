import 'package:flutter/material.dart';
import 'wasel_colors.dart';
import 'wasel_typography.dart';
import 'wasel_spacing.dart';

/// ============================================================================
/// WASEL NALUT (واصل نالوت) - UNIFIED THEME (MATERIAL 3)
/// ============================================================================
/// Complete Material 3 Light & Dark themes with zero hardcoded overrides.
/// Provides semantic ColorScheme, Cairo/Outfit typography, and fluid transitions.
/// ============================================================================
class WaselTheme {
  const WaselTheme._();

  /// Standard Material 3 Light Theme for Wasel Nalut applications.
  static ThemeData get lightTheme {
    final colorScheme = const ColorScheme.light(
      primary: WaselColors.primary,
      onPrimary: Colors.white,
      primaryContainer: WaselColors.primaryTint,
      onPrimaryContainer: WaselColors.primaryAccent,
      secondary: WaselColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: WaselColors.secondarySoft,
      onSecondaryContainer: WaselColors.secondaryDark,
      tertiary: WaselColors.sadadBlue,
      onTertiary: Colors.white,
      surface: WaselColors.surfaceLight,
      onSurface: WaselColors.textPrimaryLight,
      error: WaselColors.error,
      onError: Colors.white,
      errorContainer: WaselColors.errorLight,
      onErrorContainer: WaselColors.error,
      outline: WaselColors.borderLight,
      outlineVariant: WaselColors.borderSubtleLight,
      surfaceContainerHighest: WaselColors.borderSubtleLight,
      surfaceContainer: WaselColors.cardLight,
      surfaceContainerLow: WaselColors.backgroundLight,
    );

    final typography = WaselTypography.textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WaselColors.backgroundLight,
      canvasColor: WaselColors.surfaceLight,
      textTheme: typography,
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: WaselColors.surfaceLight,
        foregroundColor: WaselColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: WaselTypography.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: WaselColors.textPrimaryLight,
        ),
        iconTheme: const IconThemeData(color: WaselColors.textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: WaselColors.cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: WaselRadius.radiusLg,
          side: const BorderSide(color: WaselColors.borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WaselColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: WaselTypography.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: WaselRadius.radiusMd,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WaselColors.primary,
          side: const BorderSide(color: WaselColors.primary, width: 1.5),
          textStyle: WaselTypography.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: WaselRadius.radiusMd,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WaselColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WaselColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WaselColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: WaselRadius.radiusXl,
        ),
      ),
    );
  }

  /// Standard Material 3 Dark Theme for Wasel Nalut applications (Clean Slate Charcoal).
  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark(
      primary: WaselColors.primary,
      onPrimary: WaselColors.backgroundDark,
      primaryContainer: Color(0xFF78350F),
      onPrimaryContainer: WaselColors.primaryLight,
      secondary: WaselColors.secondary,
      onSecondary: WaselColors.backgroundDark,
      secondaryContainer: Color(0xFF064E3B),
      onSecondaryContainer: WaselColors.secondaryLight,
      tertiary: WaselColors.sadadBlue,
      onTertiary: Colors.white,
      surface: WaselColors.surfaceDark,
      onSurface: WaselColors.textPrimaryDark,
      error: WaselColors.error,
      onError: Colors.white,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: WaselColors.errorLight,
      outline: WaselColors.borderDark,
      outlineVariant: WaselColors.borderSubtleDark,
      surfaceContainerHighest: WaselColors.cardElevatedDark,
      surfaceContainer: WaselColors.cardDark,
      surfaceContainerLow: WaselColors.backgroundDark,
    );

    final typography = WaselTypography.textTheme(Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WaselColors.backgroundDark,
      canvasColor: WaselColors.surfaceDark,
      textTheme: typography,
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: WaselColors.surfaceDark,
        foregroundColor: WaselColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: WaselTypography.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: WaselColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(color: WaselColors.textPrimaryDark),
      ),
      cardTheme: CardThemeData(
        color: WaselColors.cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: WaselRadius.radiusLg,
          side: const BorderSide(color: WaselColors.borderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WaselColors.primary,
          foregroundColor: WaselColors.backgroundDark,
          elevation: 0,
          textStyle: WaselTypography.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: WaselRadius.radiusMd,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WaselColors.primary,
          side: const BorderSide(color: WaselColors.primary, width: 1.5),
          textStyle: WaselTypography.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: WaselRadius.radiusMd,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: WaselColors.borderDark,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WaselColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WaselColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: WaselRadius.radiusXl,
        ),
      ),
    );
  }

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
      TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    },
  );
}

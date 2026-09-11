import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL CAPTAIN / DRIVER APP DESIGN SYSTEM & TOKENS
/// ============================================================================
/// High-contrast, automotive-optimized design tokens tailored for couriers
/// under intense daylight and dark night driving conditions across Libya (Tripoli/Benghazi).
/// ============================================================================

class DriverColors {
  // Brand Accents
  static const Color primary = Color(0xFFE23744);        // Wasel High-Energy Crimson
  static const Color primaryDark = Color(0xFFB91C1C);    // Deep Crimson
  static const Color primaryLight = Color(0xFFFEE2E2);   // Soft Crimson Tint
  static const Color secondary = Color(0xFFFF6600);      // High-Visibility Sunset Orange
  static const Color accentCyan = Color(0xFF06B6D4);     // Tech Radar Cyan
  static const Color accentPurple = Color(0xFF7C3AED);   // Marketplace Violet

  // Operational Logistics Status Colors
  static const Color onlineGreen = Color(0xFF10B981);    // Driver Online / Active GPS
  static const Color onlineGlow = Color(0xFF34D399);     // Glowing Radar Pulse
  static const Color offlineGrey = Color(0xFF64748B);    // Driver Offline / Inactive
  static const Color busyOrange = Color(0xFFF59E0B);     // On Active Delivery / Navigating
  static const Color urgentRed = Color(0xFFEF4444);      // High Urgency / Radar Expiry
  static const Color surgeAmber = Color(0xFFFFB800);     // Surge Multiplier Gold

  // Financial & COD Tokens
  static const Color codWarning = Color(0xFFEA580C);     // Cash on Delivery Liability
  static const Color earningsGreen = Color(0xFF059669);  // Payout / Net Earnings
  static const Color sadadBlue = Color(0xFF0284C7);      // Sadad Libyan Payment Blue
  static const Color tadawulTeal = Color(0xFF0D9488);    // Tadawul Libyan Banking Teal

  // Day Theme Neutrals
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Night Theme Neutrals (OLED Black & High-Contrast Slates for zero eye strain)
  static const Color darkBg = Color(0xFF080C14);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardElevated = Color(0xFF27354A);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // High-Energy Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE23744), Color(0xFFFF6600)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient acceptButtonGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient onlineGlowGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient walletHeaderGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF134E4A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class DriverSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
}

class DriverRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 22.0;
  static const double full = 999.0;

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(full));
  static const BorderRadius topSheet = BorderRadius.vertical(top: Radius.circular(24.0));
}

class DriverTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static const TextStyle monoMetric = TextStyle(
    fontFamily: 'Courier',
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );
}

class DriverTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: DriverColors.primary,
      scaffoldBackgroundColor: DriverColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: DriverColors.primary,
        secondary: DriverColors.secondary,
        tertiary: DriverColors.onlineGreen,
        surface: DriverColors.lightSurface,
        error: DriverColors.urgentRed,
        onPrimary: Colors.white,
        onSurface: DriverColors.lightTextPrimary,
      ),
      cardTheme: const CardTheme(
        color: DriverColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DriverRadius.radiusLg,
          side: BorderSide(color: DriverColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DriverColors.lightSurface,
        foregroundColor: DriverColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: DriverColors.primary,
      scaffoldBackgroundColor: DriverColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: DriverColors.primary,
        secondary: DriverColors.secondary,
        tertiary: DriverColors.onlineGreen,
        surface: DriverColors.darkSurface,
        error: DriverColors.urgentRed,
        onPrimary: Colors.white,
        onSurface: DriverColors.darkTextPrimary,
      ),
      cardTheme: const CardTheme(
        color: DriverColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DriverRadius.radiusLg,
          side: BorderSide(color: DriverColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DriverColors.darkSurface,
        foregroundColor: DriverColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  /// Helper to format Libyan Dinars (LYD)
  static String formatLyd(double amount) {
    return '${amount.toStringAsFixed(2)} LYD';
  }
}

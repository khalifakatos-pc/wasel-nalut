import 'package:flutter/material.dart';

/// ============================================================================
/// CAPTAIN WASEL (كابتن واصل) DRIVER APP DESIGN SYSTEM & TOKENS
/// ============================================================================
/// High-contrast, automotive-optimized design tokens tailored for couriers
/// in Nalut and across Libya.
/// ============================================================================

class DriverColors {
  // Brand Accents (Google Stitch Imperial Gold & Nocturnal Emerald)
  static const Color primary = Color(0xFFD4AF37);        // Imperial Gold
  static const Color primaryDark = Color(0xFFB89325);    // Deep Gold
  static const Color primaryLight = Color(0xFFF5D061);   // Gold Radiance
  static const Color secondary = Color(0xFF10B981);      // Emerald Green
  static const Color accentCyan = Color(0xFF38BDF8);     // Tech Radar Cyan
  static const Color accentTeal = Color(0xFF10B981);     // Nalut Mountain Emerald
  static const Color accentPurple = Color(0xFF7C3AED);   // Marketplace Violet

  // Operational Logistics Status Colors
  static const Color onlineGreen = Color(0xFF10B981);    // Driver Online / Active GPS
  static const Color onlineGlow = Color(0xFF34D399);     // Glowing Radar Pulse
  static const Color offlineGrey = Color(0xFF64748B);    // Driver Offline / Inactive
  static const Color busyOrange = Color(0xFFF59E0B);     // On Active Delivery / Navigating
  static const Color urgentRed = Color(0xFFEF4444);      // High Urgency / Radar Expiry
  static const Color surgeAmber = Color(0xFFD4AF37);     // Surge Multiplier Gold

  // Financial & COD Tokens
  static const Color codWarning = Color(0xFFEA580C);     // Cash on Delivery Liability
  static const Color earningsGreen = Color(0xFF10B981);  // Payout / Net Earnings
  static const Color sadadBlue = Color(0xFF0284C7);      // Sadad Libyan Payment Blue
  static const Color tadawulTeal = Color(0xFF0D9488);    // Tadawul Libyan Banking Teal

  // Day Theme Neutrals
  static const Color lightBg = Color(0xFFF1F5F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF041710);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Night Theme Neutrals (Nocturnal Emerald & Gold)
  static const Color darkBg = Color(0xFF041710);
  static const Color darkSurface = Color(0xFF062319);
  static const Color darkCard = Color(0xFF0A3324);
  static const Color darkCardElevated = Color(0xFF124532);
  static const Color darkBorder = Color(0x33D4AF37);
  static const Color darkTextPrimary = Color(0xFFF8F5EE);
  static const Color darkTextSecondary = Color(0xFFD0C5AF);
  static const Color darkTextMuted = Color(0xFF99907C);

  // High-Energy Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF5D061), Color(0xFFD4AF37), Color(0xFFB89325)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient acceptButtonGradient = LinearGradient(
    colors: [Color(0xFFF5D061), Color(0xFFD4AF37)],
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
}

class DriverTypography {
  static const TextStyle hudTimer = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.0,
    fontFamily: 'monospace',
  );

  static const TextStyle heroEarnings = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    fontFamily: 'monospace',
  );

  static const TextStyle hudAddress = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  static const TextStyle stepTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle chipLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}

class DriverTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DriverColors.darkBg,
      primaryColor: DriverColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: DriverColors.primary,
        secondary: DriverColors.secondary,
        tertiary: DriverColors.onlineGreen,
        surface: DriverColors.darkSurface,
        error: DriverColors.urgentRed,
        onPrimary: Colors.white,
        onSurface: DriverColors.darkTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: DriverColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DriverRadius.radiusLg,
          side: const BorderSide(color: DriverColors.darkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DriverColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: DriverColors.darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: DriverColors.lightBg,
      primaryColor: DriverColors.primary,
      colorScheme: const ColorScheme.light(
        primary: DriverColors.primary,
        secondary: DriverColors.secondary,
        tertiary: DriverColors.onlineGreen,
        surface: DriverColors.lightSurface,
        error: DriverColors.urgentRed,
        onPrimary: Colors.white,
        onSurface: DriverColors.lightTextPrimary,
      ),
      cardTheme: CardThemeData(
        color: DriverColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DriverRadius.radiusLg,
          side: const BorderSide(color: DriverColors.lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DriverColors.lightSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: DriverColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// MOTION & ANIMATION TOKENS (60 / 120 FPS HIGH PERFORMANCE)
/// ---------------------------------------------------------------------------
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);      // Tap feedback, micro bounce, toggles
  static const Duration normal = Duration(milliseconds: 300);    // Bottom sheets, card expansions
  static const Duration slow = Duration(milliseconds: 500);      // Radar sweeps, status morphing
  static const Duration relaxed = Duration(milliseconds: 800);   // Live telemetry beacons, breathing glow
  static const Duration extended = Duration(milliseconds: 1200); // Radar search pulse cycle
  static const Duration shimmer = Duration(milliseconds: 1500);  // Route loading shimmer

  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve springSnappy = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve decelerate = Curves.decelerate;
  static const Curve pulseCurve = Curves.easeInOutSine;
  static const Curve linear = Curves.linear;

  static const double pressScaleButton = 0.96;
  static const double pressScaleCard = 0.97;
  static const double pressScaleIcon = 0.90;
}


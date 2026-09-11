import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL MERCHANT & KITCHEN (تاجر ومطبخ واصل) DESIGN TOKENS & THEME
/// ============================================================================
/// Optimized for kitchen displays and restaurant cashiers with high contrast,
/// warm flame brand colors, and clear status indicators.
/// ============================================================================

class MerchantColors {
  // Brand Accents (Google Stitch Imperial Gold & Nocturnal Emerald)
  static const Color primary = Color(0xFFD4AF37);        // Imperial Gold
  static const Color primaryDark = Color(0xFFB89325);    // Burnished Gold
  static const Color primaryLight = Color(0xFFF5D061);   // Gold Radiance
  static const Color secondary = Color(0xFF10B981);      // Emerald Green
  static const Color accentAmber = Color(0xFFD4AF37);    // Golden Prep Accent
  static const Color accentTeal = Color(0xFF10B981);     // Nalut Mountain Emerald

  // Operational Kitchen Ticket Status Colors
  static const Color newOrderAmber = Color(0xFFF5D061);  // New Incoming Ticket (Urgent Gold)
  static const Color prepBlue = Color(0xFF38BDF8);       // Cooking in Progress
  static const Color readyGreen = Color(0xFF10B981);     // Ready for Pickup / Courier
  static const Color completedGrey = Color(0xFF99907C);  // Handed Over & Completed
  static const Color rejectedRed = Color(0xFFEF4444);    // Out of Stock / Cancelled

  // Financial & Payment Tokens
  static const Color revenueGreen = Color(0xFF10B981);   // Net Payout / Sales
  static const Color sadadBlue = Color(0xFF0284C7);      // Sadad Libyan Banking
  static const Color tadawulTeal = Color(0xFF0D9488);    // Tadawul Libyan Banking

  // Day Theme Neutrals
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF041710);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Nocturnal Emerald Theme
  static const Color darkBg = Color(0xFF041710);
  static const Color darkSurface = Color(0xFF062319);
  static const Color darkCard = Color(0xFF0A3324);
  static const Color darkCardElevated = Color(0xFF124532);
  static const Color darkBorder = Color(0x33D4AF37);
  static const Color darkTextPrimary = Color(0xFFF8F5EE);
  static const Color darkTextSecondary = Color(0xFFD0C5AF);
  static const Color darkTextMuted = Color(0xFF99907C);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF5D061), Color(0xFFD4AF37), Color(0xFFB89325)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient kdsHeaderGradient = LinearGradient(
    colors: [Color(0xFF041710), Color(0xFF062319), Color(0xFF0A3324)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class MerchantSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
}

class MerchantRadius {
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8.0));
  static const BorderRadius md = BorderRadius.all(Radius.circular(12.0));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(16.0));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(22.0));
  static const BorderRadius full = BorderRadius.all(Radius.circular(999.0));
}

class MerchantTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MerchantColors.darkBg,
      primaryColor: MerchantColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: MerchantColors.primary,
        secondary: MerchantColors.secondary,
        surface: MerchantColors.darkSurface,
        error: MerchantColors.rejectedRed,
        onPrimary: Colors.white,
        onSurface: MerchantColors.darkTextPrimary,
      ),
      cardTheme: const CardThemeData(
        color: MerchantColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: MerchantRadius.lg,
          side: BorderSide(color: MerchantColors.darkBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MerchantColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: MerchantColors.darkTextPrimary,
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
      scaffoldBackgroundColor: MerchantColors.lightBg,
      primaryColor: MerchantColors.primary,
      colorScheme: const ColorScheme.light(
        primary: MerchantColors.primary,
        secondary: MerchantColors.secondary,
        surface: MerchantColors.lightSurface,
        error: MerchantColors.rejectedRed,
        onPrimary: Colors.white,
        onSurface: MerchantColors.lightTextPrimary,
      ),
      cardTheme: const CardThemeData(
        color: MerchantColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: MerchantRadius.lg,
          side: BorderSide(color: MerchantColors.lightBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: MerchantColors.lightSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: MerchantColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL MERCHANT & KITCHEN (تاجر ومطبخ واصل) DESIGN TOKENS & THEME
/// ============================================================================
/// Optimized for kitchen displays and restaurant cashiers with high contrast,
/// warm flame brand colors, and clear status indicators.
/// ============================================================================

class MerchantColors {
  // Brand Accents (Modern Radiant Delivery Amber & Fresh Kitchen Palette)
  static const Color primary = Color(0xFFF59E0B);        // Radiant Delivery Amber
  static const Color primaryDark = Color(0xFFD97706);    // Deep Warm Amber
  static const Color primaryLight = Color(0xFFFBBF24);   // Amber Glow
  static const Color secondary = Color(0xFF10B981);      // Emerald Green
  static const Color accentAmber = Color(0xFFF59E0B);    // Golden Prep Accent
  static const Color accentTeal = Color(0xFF0D9488);     // Mountain Teal

  // Operational Kitchen Ticket Status Colors
  static const Color newOrderAmber = Color(0xFFFBBF24);  // New Incoming Ticket (Urgent Amber)
  static const Color prepBlue = Color(0xFF38BDF8);       // Cooking in Progress
  static const Color readyGreen = Color(0xFF10B981);     // Ready for Pickup / Courier
  static const Color completedGrey = Color(0xFF94A3B8);  // Handed Over & Completed
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
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Modern Dark KDS Theme (High-contrast Slate Charcoal)
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardElevated = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Stitch Modern Status Pill & Badge Tokens (Light Canvas)
  static const Color statusNewBg = Color(0xFFFEF3C7);       // Soft Amber Glow
  static const Color statusNewText = Color(0xFFB45309);     // Deep Amber Text
  static const Color statusNewBorder = Color(0xFFFCD34D);   // Amber Border

  static const Color statusPrepBg = Color(0xFFE0F2FE);      // Soft Sky Tint
  static const Color statusPrepText = Color(0xFF0369A1);    // Deep Azure Text
  static const Color statusPrepBorder = Color(0xFF7DD3FC);  // Azure Border

  static const Color statusReadyBg = Color(0xFFD1FAE5);     // Soft Emerald Tint
  static const Color statusReadyText = Color(0xFF047857);   // Deep Emerald Text
  static const Color statusReadyBorder = Color(0xFF6EE7B7); // Emerald Border

  static const Color statusCompletedBg = Color(0xFFF1F5F9); // Crisp Slate Neutral
  static const Color statusCompletedText = Color(0xFF475569);
  static const Color statusCompletedBorder = Color(0xFFE2E8F0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient kdsHeaderGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient stitchLightGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class MerchantShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> activeCard = [
    BoxShadow(
      color: Color(0x18F59E0B),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
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

/// ---------------------------------------------------------------------------
/// MOTION & ANIMATION TOKENS (60 / 120 FPS HIGH PERFORMANCE)
/// ---------------------------------------------------------------------------
class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);      // KDS buttons, ticket quick tap
  static const Duration normal = Duration(milliseconds: 300);    // Ticket state transitions, dialogs
  static const Duration slow = Duration(milliseconds: 500);      // Column slide animations
  static const Duration relaxed = Duration(milliseconds: 800);   // Urgent ticket pulse
  static const Duration extended = Duration(milliseconds: 1200); // Receipt print animation
  static const Duration shimmer = Duration(milliseconds: 1500);  // Orders loading shimmer

  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve springSnappy = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve decelerate = Curves.decelerate;
  static const Curve pulseCurve = Curves.easeInOutSine;

  static const double pressScaleButton = 0.96;
  static const double pressScaleCard = 0.97;
  static const double pressScaleIcon = 0.90;
}


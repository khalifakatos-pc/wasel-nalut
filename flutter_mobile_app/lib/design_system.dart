import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL (واصل) SUPER-APP DESIGN SYSTEM - NALUT & LIBYA
/// ============================================================================
/// A unified design token and theme system bridging:
/// - WASEL FOOD (واصل طعام): High-energy food delivery (Vibrant Crimson & Zesty Orange)
/// - WASEL FAST (واصل فوري): 15-minute quick commerce (Emerald Green & Fresh Mint)
/// - WASEL MARKET (سوق واصل): Premium e-commerce & local mountain goods (Royal Violet & Midnight Navy)
/// ============================================================================

/// ---------------------------------------------------------------------------
/// 1. COLOR TOKENS
/// ---------------------------------------------------------------------------
class AppColors {
  // Brand: Wasel Primary & Accents (Google Stitch High Mountain Luxury)
  static const Color waselPrimary = Color(0xFFD4AF37);       // Imperial Gold
  static const Color waselSecondary = Color(0xFFF5D061);     // Gold Radiance
  static const Color waselAccent = Color(0xFFB89325);        // Burnished Gold
  static const Color waselTeal = Color(0xFF10B981);          // Mountain Emerald
  static const Color waselPurple = Color(0xFF7C3AED);        // Royal Purple
  static const Color waselNavy = Color(0xFF041710);          // Nocturnal Emerald Canvas
  static const Color waselLight = Color(0xFFF8F5EE);         // Champagne Ivory
  static const Color waselSurface = Color(0xFF062319);       // Nocturnal Emerald Surface
  static const Color waselMarketPrimary = Color(0xFFD4AF37); // Imperial Gold Accent

  // Wasel Market & Express Brand Tokens
  static const Color waselMarketSecondary = Color(0xFFF5D061);
  static const Color waselMarketAccent = Color(0xFFB89325);
  static const Color waselMarketLight = Color(0xFFF8F5EE);
  static const Color waselMarketSurface = Color(0xFF0A3324);

  // Quick Commerce (Wasel Fast 15m)
  static const Color jetPrimary = Color(0xFF10B981);         // Express Emerald
  static const Color jetSecondary = Color(0xFF059669);       // Deep Forest
  static const Color jetAccent = Color(0xFFD4AF37);          // Gold Trim
  static const Color jetLight = Color(0xFFECFDF5);           // Crisp Mint Tint

  // Status & Feedback Colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Neutral Light Theme Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF041710);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Aliases for Common Backgrounds
  static const Color background = lightBackground;
  static const Color surface = lightSurface;
  static const Color cardBackground = lightCard;

  // Nocturnal Emerald & Gold Luxury Theme Palette
  static const Color darkBackground = Color(0xFF041710);      // Deep Nocturnal Emerald
  static const Color darkSurface = Color(0xFF062319);         // Elevated Emerald Surface
  static const Color darkCard = Color(0xFF0A3324);            // Glassmorphic Card Base
  static const Color darkBorder = Color(0x44D4AF37);          // Translucent Gold Border
  static const Color darkBorderSubtle = Color(0x22D4AF37);    // Subtle Gold Border
  static const Color darkTextPrimary = Color(0xFFF8F5EE);     // Champagne Ivory
  static const Color darkTextSecondary = Color(0xFFD0C5AF);   // Muted Champagne
  static const Color darkTextMuted = Color(0xFF99907C);       // Desert Olive Muted

  // Luxury & Promo Accents
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF5D061);
  static const Color starRating = Color(0xFFF5D061);

  // Gradients
  static const LinearGradient waselGradient = LinearGradient(
    colors: [Color(0xFFF5D061), Color(0xFFD4AF37), Color(0xFFB89325)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient waselMarketGradient = LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFF0A3324)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient jetGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF0A3324), Color(0xFF062319)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// ---------------------------------------------------------------------------
/// 2. SPACING & LAYOUT CONSTANTS
/// ---------------------------------------------------------------------------
class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets dialogPadding = EdgeInsets.all(24.0);
  static const EdgeInsets sheetPadding = EdgeInsets.all(20.0);
}

/// ---------------------------------------------------------------------------
/// 3. BORDER RADIUS CONSTANTS
/// ---------------------------------------------------------------------------
class AppRadius {
  static const Radius rXs = Radius.circular(4.0);
  static const Radius rSm = Radius.circular(8.0);
  static const Radius rMd = Radius.circular(12.0);
  static const Radius rLg = Radius.circular(16.0);
  static const Radius rXl = Radius.circular(20.0);
  static const Radius rXxl = Radius.circular(28.0);

  static final BorderRadius radiusXs = BorderRadius.circular(4.0);
  static final BorderRadius radiusSm = BorderRadius.circular(8.0);
  static final BorderRadius radiusMd = BorderRadius.circular(12.0);
  static final BorderRadius radiusLg = BorderRadius.circular(16.0);
  static final BorderRadius radiusXl = BorderRadius.circular(20.0);
  static final BorderRadius radiusXxl = BorderRadius.circular(28.0);
  static final BorderRadius radiusFull = BorderRadius.circular(999.0);

  static final BorderRadius topSheetRadius = const BorderRadius.only(
    topLeft: Radius.circular(24.0),
    topRight: Radius.circular(24.0),
  );

  static final BorderRadius topXxl = const BorderRadius.only(
    topLeft: Radius.circular(28.0),
    topRight: Radius.circular(28.0),
  );
}

/// ---------------------------------------------------------------------------
/// 4. ELEVATION & SHADOWS
/// ---------------------------------------------------------------------------
class AppShadows {
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get sm => subtle;

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          offset: const Offset(0, 4),
          blurRadius: 14,
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get md => card;

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get bottomBarShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          offset: const Offset(0, -4),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> colored(Color color, {double opacity = 0.3}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          offset: const Offset(0, 6),
          blurRadius: 16,
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get glowWasel => [
        BoxShadow(
          color: AppColors.waselPrimary.withValues(alpha: 0.35),
          offset: const Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get glowMarket => [
        BoxShadow(
          color: AppColors.waselPurple.withValues(alpha: 0.35),
          offset: const Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get glowJet => [
        BoxShadow(
          color: AppColors.jetPrimary.withValues(alpha: 0.35),
          offset: const Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -4,
        ),
      ];
}

/// ---------------------------------------------------------------------------
/// 5. TYPOGRAPHY SYSTEM
/// ---------------------------------------------------------------------------
class AppTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle currencyText = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w800,
    color: AppColors.waselPrimary,
  );
}

/// ---------------------------------------------------------------------------
/// 6. THEME DATA CONFIGURATION
/// ---------------------------------------------------------------------------
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.waselPrimary,
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightCard,
      dividerColor: AppColors.lightBorder,
      colorScheme: const ColorScheme.light(
        primary: AppColors.waselPrimary,
        secondary: AppColors.waselPurple,
        tertiary: AppColors.jetPrimary,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightTextPrimary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.waselPrimary.withValues(alpha: 0.12),
        elevation: 4,
        height: 68,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.waselPrimary,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      dividerColor: AppColors.darkBorder,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.waselPrimary,
        secondary: AppColors.waselPurple,
        tertiary: AppColors.jetPrimary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkTextPrimary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.waselPrimary.withValues(alpha: 0.2),
        elevation: 4,
        height: 68,
      ),
    );
  }
}

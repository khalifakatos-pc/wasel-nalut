import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL NALUT (واصل نالوت) - SEMANTIC COLOR TOKENS
/// ============================================================================
/// Official shared color palette uniting all four Wasel client applications.
/// Engineered for high contrast, Libyan regional clarity, and zero hardcoded overrides.
/// ============================================================================
class WaselColors {
  const WaselColors._();

  // --- Brand Radiance (Amber & Saffron) ---
  static const Color primary = Color(0xFFF59E0B);
  static const Color primaryDark = Color(0xFFD97706);
  static const Color primaryAccent = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFFBBF24);
  static const Color primaryTint = Color(0xFFFEF3C7);

  // --- Operational & Secondary (Emerald Green) ---
  static const Color secondary = Color(0xFF10B981);
  static const Color secondaryDark = Color(0xFF059669);
  static const Color secondaryLight = Color(0xFF34D399);
  static const Color secondaryTint = Color(0xFFECFDF5);
  static const Color secondarySoft = Color(0xFFD1FAE5);

  // --- Functional Status Colors ---
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // --- Regional & Operational Logistics ---
  static const Color codWarning = Color(0xFFEA580C);
  static const Color sadadBlue = Color(0xFF0284C7);
  static const Color tadawulTeal = Color(0xFF0D9488);
  static const Color radarCyan = Color(0xFF38BDF8);
  static const Color violet = Color(0xFF8B5CF6);

  // --- Neutral Canvas & Surfaces (Light Theme) ---
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderSubtleLight = Color(0xFFF1F5F9);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  // --- Neutral Canvas & Surfaces (Dark Theme - Slate Charcoal) ---
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color cardElevatedDark = Color(0xFF334155);
  static const Color borderDark = Color(0xFF334155);
  static const Color borderSubtleDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textMutedDark = Color(0xFF64748B);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

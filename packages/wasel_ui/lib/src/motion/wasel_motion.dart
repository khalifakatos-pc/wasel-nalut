import 'package:flutter/material.dart';

/// ============================================================================
/// WASEL NALUT (واصل نالوت) - SIGNATURE MOTION & PHYSICS ENGINE
/// ============================================================================
/// Defines core durations, physics bezier curves, and tactile scale constants.
/// Enforces mandatory accessibility bypass via [isAnimationDisabled].
/// ============================================================================
class WaselMotion {
  const WaselMotion._();

  // --- Core Durations (R1 & Specification) ---
  /// Instant micro-feedback, toggles, button taps (150ms).
  static const Duration quick = Duration(milliseconds: 150);

  /// Standard screen elements, card moves, transitions (280ms).
  static const Duration standard = Duration(milliseconds: 280);

  /// Heavy overlays, modal bottom sheets, smooth dialogs (450ms).
  static const Duration slow = Duration(milliseconds: 450);

  /// Gentle breathing ambient pulses, beacons (800ms).
  static const Duration relaxed = Duration(milliseconds: 800);

  /// Extended radar sweeps, background ambient loops (1200ms).
  static const Duration extended = Duration(milliseconds: 1200);

  /// Standard shimmer light wave cycle (1500ms).
  static const Duration shimmerCycle = Duration(milliseconds: 1500);

  // --- Backward-Compatible Aliases ---
  static const Duration fast = quick;
  static const Duration normal = standard;
  static const Duration shimmer = shimmerCycle;

  // --- Signature Physics Curves (R1 & Motion Design Skill) ---
  /// Wasel Signature: Emphasized decisive entrance curve (0.05, 0.7, 0.1, 1.0).
  static const Curve signature = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Wasel Joy: Tactile overshoot elasticity curve (0.175, 0.885, 0.32, 1.275).
  static const Curve joy = Cubic(0.175, 0.885, 0.32, 1.275);

  /// Smooth deceleration for entrances.
  static const Curve easeOutCubic = Curves.easeOutCubic;

  /// Smooth both ends for on-screen state transitions.
  static const Curve easeInOutCubic = Curves.easeInOutCubic;

  /// Sinusoidal breathing for ambient glows and beacons.
  static const Curve pulseCurve = Curves.easeInOutSine;

  /// Backward-compatible alias for snappy button release.
  static const Curve springSnappy = joy;

  // --- Tactile Scale Ratios ---
  static const double pressScaleButton = 0.96;
  static const double pressScaleCard = 0.97;
  static const double pressScaleIcon = 0.90;

  // --- Accessibility Bypass Helpers (Mandatory R1 & AC) ---

  /// Checks if system-level animations are disabled (e.g., "Remove animations").
  static bool isAnimationDisabled(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Returns [Duration.zero] if animations are disabled on the device,
  /// otherwise returns the requested [natural] duration.
  static Duration durationOf(BuildContext context, Duration natural) {
    return isAnimationDisabled(context) ? Duration.zero : natural;
  }

  /// Returns [Curves.linear] if animations are disabled on the device,
  /// otherwise returns the requested [natural] curve.
  static Curve curveOf(BuildContext context, Curve natural) {
    return isAnimationDisabled(context) ? Curves.linear : natural;
  }
}

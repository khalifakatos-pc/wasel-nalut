import 'package:flutter/material.dart';
import '../theme/wasel_typography.dart';
import 'wasel_motion.dart';

/// ============================================================================
/// ODOMETER COUNTER (العدّاد المتدحرج للأرقام والأسعار)
/// ============================================================================
/// Smoothly rolls numeric values (prices, COD, telemetry) using Outfit typography.
/// Checks [WaselMotion.isAnimationDisabled] to render final values immediately.
/// ============================================================================
class OdometerCounter extends StatelessWidget {
  final double value;
  final double? initialValue;
  final int decimalPlaces;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const OdometerCounter({
    super.key,
    required this.value,
    this.initialValue,
    this.decimalPlaces = 2,
    this.prefix = '',
    this.suffix = ' د.ل',
    this.style,
    this.duration = WaselMotion.slow,
    this.curve = WaselMotion.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = WaselTypography.outfit(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    );
    final effectiveStyle = style != null ? baseStyle.merge(style) : baseStyle;

    final isA11yDisabled = WaselMotion.isAnimationDisabled(context);
    final effectiveDuration = isA11yDisabled ? Duration.zero : duration;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: initialValue,
        end: value,
      ),
      duration: effectiveDuration,
      curve: curve,
      builder: (context, animatedValue, child) {
        final formattedNumber =
            animatedValue.toStringAsFixed(decimalPlaces);
        return Text(
          '$prefix$formattedNumber$suffix',
          style: effectiveStyle,
        );
      },
    );
  }
}

/// Backward compatibility alias for `WaselNumberOdometer`.
typedef WaselNumberOdometer = OdometerCounter;

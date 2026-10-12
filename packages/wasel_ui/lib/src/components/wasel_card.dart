import 'package:flutter/material.dart';
import '../motion/bouncy_pressable.dart';
import '../motion/wasel_motion.dart';
import '../theme/wasel_spacing.dart';

/// ============================================================================
/// WASEL CARD (بطاقة واصل الموحدة)
/// ============================================================================
/// Elevated or flat surface container adhering to the semantic Material 3
/// ColorScheme with optional bouncy tactile press feedback.
/// ============================================================================
class WaselCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Clip clipBehavior;
  final double? width;
  final double? height;

  const WaselCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.shadows,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveColor = color ??
        (isDark
            ? colorScheme.surfaceContainer
            : colorScheme.surface);

    final effectiveBorderColor = borderColor ??
        (isDark
            ? colorScheme.outline
            : colorScheme.outlineVariant);

    final effectiveRadius = borderRadius ?? WaselRadius.radiusLg;

    Widget cardBody = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        boxShadow: shadows ??
            (isDark ? WaselShadows.cardDark : WaselShadows.cardLight),
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      return WaselBouncyPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        pressedScale: WaselMotion.pressScaleCard,
        child: cardBody,
      );
    }

    return cardBody;
  }
}

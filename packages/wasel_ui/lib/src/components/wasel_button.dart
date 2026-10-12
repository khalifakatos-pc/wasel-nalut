import 'package:flutter/material.dart';
import '../motion/bouncy_pressable.dart';
import '../motion/wasel_motion.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_spacing.dart';
import '../theme/wasel_typography.dart';

enum WaselButtonType {
  primary,
  secondary,
  outline,
  ghost,
}

/// ============================================================================
/// WASEL BUTTON (زر واصل التفاعلي المرن)
/// ============================================================================
/// High-tactile bouncy action button supporting primary, secondary, outline,
/// and ghost variants with integrated loading states and Cairo typography.
/// ============================================================================
class WaselButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final Widget? icon;
  final VoidCallback? onPressed;
  final WaselButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double pressedScale;
  final bool enabled;

  const WaselButton({
    super.key,
    this.text,
    this.child,
    this.icon,
    this.onPressed,
    this.type = WaselButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.pressedScale = WaselMotion.pressScaleButton,
    this.enabled = true,
  });

  /// Convenient primary button constructor
  factory WaselButton.primary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    Widget? icon,
    bool isLoading = false,
    bool isFullWidth = false,
    bool enabled = true,
  }) =>
      WaselButton(
        key: key,
        text: text,
        icon: icon,
        onPressed: onPressed,
        type: WaselButtonType.primary,
        isLoading: isLoading,
        isFullWidth: isFullWidth,
        enabled: enabled,
      );

  /// Convenient secondary (Emerald) button constructor
  factory WaselButton.secondary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    Widget? icon,
    bool isLoading = false,
    bool isFullWidth = false,
    bool enabled = true,
  }) =>
      WaselButton(
        key: key,
        text: text,
        icon: icon,
        onPressed: onPressed,
        type: WaselButtonType.secondary,
        isLoading: isLoading,
        isFullWidth: isFullWidth,
        enabled: enabled,
      );

  /// Convenient outline button constructor
  factory WaselButton.outline({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    Widget? icon,
    bool isLoading = false,
    bool isFullWidth = false,
    bool enabled = true,
  }) =>
      WaselButton(
        key: key,
        text: text,
        icon: icon,
        onPressed: onPressed,
        type: WaselButtonType.outline,
        isLoading: isLoading,
        isFullWidth: isFullWidth,
        enabled: enabled,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isInteractive = enabled && !isLoading && onPressed != null;

    Color resolvedBg;
    Color resolvedText;
    Border? resolvedBorder;
    List<BoxShadow>? resolvedShadows;

    switch (type) {
      case WaselButtonType.primary:
        resolvedBg = backgroundColor ?? colorScheme.primary;
        resolvedText = textColor ??
            (isDark ? WaselColors.backgroundDark : Colors.white);
        resolvedShadows = isInteractive ? WaselShadows.glowAmber : null;
        break;
      case WaselButtonType.secondary:
        resolvedBg = backgroundColor ?? colorScheme.secondary;
        resolvedText = textColor ??
            (isDark ? WaselColors.backgroundDark : Colors.white);
        resolvedShadows = isInteractive ? WaselShadows.glowEmerald : null;
        break;
      case WaselButtonType.outline:
        resolvedBg = backgroundColor ?? Colors.transparent;
        resolvedText = textColor ?? colorScheme.primary;
        resolvedBorder = Border.all(
          color: borderColor ?? colorScheme.primary,
          width: 1.5,
        );
        break;
      case WaselButtonType.ghost:
        resolvedBg = backgroundColor ?? Colors.transparent;
        resolvedText = textColor ??
            (isDark ? WaselColors.textPrimaryDark : WaselColors.textPrimaryLight);
        break;
    }

    if (!isInteractive && !isLoading) {
      resolvedBg = isDark
          ? WaselColors.cardElevatedDark.withValues(alpha: 0.5)
          : WaselColors.borderLight;
      resolvedText = isDark
          ? WaselColors.textMutedDark
          : WaselColors.textMutedLight;
      resolvedBorder = null;
      resolvedShadows = null;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(resolvedText),
        ),
      );
    } else if (child != null) {
      content = child!;
    } else {
      content = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 8),
          ],
          if (text != null)
            Text(
              text!,
              style: WaselTypography.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: resolvedText,
              ),
            ),
        ],
      );
    }

    final buttonDecoration = DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: borderRadius ?? WaselRadius.radiusMd,
        border: resolvedBorder,
        boxShadow: resolvedShadows,
      ),
      child: Padding(
        padding: padding,
        child: Center(
          widthFactor: isFullWidth ? null : 1.0,
          child: content,
        ),
      ),
    );

    return WaselBouncyPressable(
      onTap: isInteractive ? onPressed : null,
      pressedScale: pressedScale,
      enabled: isInteractive,
      child: isFullWidth
          ? SizedBox(width: double.infinity, child: buttonDecoration)
          : buttonDecoration,
    );
  }
}

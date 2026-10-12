import 'package:flutter/material.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_spacing.dart';
import '../theme/wasel_typography.dart';
import '../motion/bouncy_pressable.dart';
import '../motion/wasel_motion.dart';

enum StatusPillType {
  success,
  warning,
  error,
  info,
  neutral,
}

/// ============================================================================
/// STATUS PILL (شريحة الحالة التفاعلية)
/// ============================================================================
/// Crisp, tinted status badge indicating delivery, ticket, or courier state.
/// Supports leading dots, icons, and optional bouncy press interaction.
/// ============================================================================
class StatusPill extends StatelessWidget {
  final String label;
  final StatusPillType type;
  final Widget? icon;
  final bool showDot;
  final Color? color;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final VoidCallback? onTap;

  const StatusPill({
    super.key,
    required this.label,
    this.type = StatusPillType.neutral,
    this.icon,
    this.showDot = false,
    this.color,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize = 12.0,
    this.onTap,
  });

  /// Factory constructor taking a custom statusText string and custom base color.
  factory StatusPill.custom({
    Key? key,
    required String statusText,
    required Color color,
    Widget? icon,
    bool showDot = false,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  }) {
    return StatusPill(
      key: key,
      label: statusText,
      color: color,
      icon: icon,
      showDot: showDot,
      onTap: onTap,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color resolvedAccent;
    Color resolvedBg;
    Color resolvedBorder;

    if (color != null) {
      resolvedAccent = color!;
      resolvedBg = isDark
          ? color!.withValues(alpha: 0.16)
          : color!.withValues(alpha: 0.10);
      resolvedBorder = color!.withValues(alpha: 0.35);
    } else {
      switch (type) {
        case StatusPillType.success:
          resolvedAccent = WaselColors.secondary;
          resolvedBg = isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.5)
              : WaselColors.secondaryTint;
          resolvedBorder = isDark
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : const Color(0xFFA7F3D0);
          break;
        case StatusPillType.warning:
          resolvedAccent = WaselColors.primary;
          resolvedBg = isDark
              ? const Color(0xFF78350F).withValues(alpha: 0.5)
              : WaselColors.primaryTint;
          resolvedBorder = isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.4)
              : const Color(0xFFFDE68A);
          break;
        case StatusPillType.error:
          resolvedAccent = WaselColors.error;
          resolvedBg = isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.5)
              : WaselColors.errorLight;
          resolvedBorder = isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
              : const Color(0xFFFECACA);
          break;
        case StatusPillType.info:
          resolvedAccent = WaselColors.info;
          resolvedBg = isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
              : WaselColors.infoLight;
          resolvedBorder = isDark
              ? const Color(0xFF2563EB).withValues(alpha: 0.4)
              : const Color(0xFFBFDBFE);
          break;
        case StatusPillType.neutral:
          resolvedAccent = isDark
              ? WaselColors.textSecondaryDark
              : WaselColors.textSecondaryLight;
          resolvedBg = isDark
              ? WaselColors.cardElevatedDark
              : WaselColors.borderLight;
          resolvedBorder = isDark
              ? WaselColors.borderDark
              : WaselColors.borderSubtleLight;
          break;
      }
    }

    final finalBg = backgroundColor ?? resolvedBg;
    final finalText = textColor ?? resolvedAccent;
    final finalBorder = borderColor ?? resolvedBorder;

    Widget pillContent = DecoratedBox(
      decoration: BoxDecoration(
        color: finalBg,
        borderRadius: WaselRadius.radiusFull,
        border: Border.all(color: finalBorder, width: 1.0),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: resolvedAccent,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: WaselTypography.cairo(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: finalText,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return WaselBouncyPressable(
        onTap: onTap,
        pressedScale: WaselMotion.pressScaleIcon,
        child: pillContent,
      );
    }

    return pillContent;
  }
}

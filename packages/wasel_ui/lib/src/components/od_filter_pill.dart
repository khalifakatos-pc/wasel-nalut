import 'package:flutter/material.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_spacing.dart';
import '../theme/wasel_typography.dart';
import '../motion/bouncy_pressable.dart';
import '../motion/wasel_motion.dart';

/// ============================================================================
/// OD FILTER PILL (كبسولة الفرز والتصنيف بأسلوب Open Design)
/// ============================================================================
/// Ergonomic capsule button for high-speed category filtering.
/// Styled after Open Design / Uber mobility navigation chips.
/// ============================================================================
class OdFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Widget? leading;
  final String? count;
  final VoidCallback onTap;
  final Color? activeColor;
  final EdgeInsetsGeometry padding;

  const OdFilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.leading,
    this.count,
    this.activeColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? WaselColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isSelected
        ? effectiveActiveColor
        : (isDark ? WaselColors.surfaceDark : WaselColors.surfaceLight);

    final fg = isSelected
        ? Colors.white
        : (isDark ? WaselColors.textPrimaryDark : WaselColors.textPrimaryLight);

    final border = isSelected
        ? Border.all(color: effectiveActiveColor, width: 1.5)
        : Border.all(
            color: isDark ? WaselColors.borderSubtleDark : WaselColors.borderLight,
            width: 1.0,
          );

    return WaselBouncyPressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: WaselMotion.quick,
        curve: WaselMotion.easeInOutCubic,
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: effectiveActiveColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: WaselSpacing.xs),
            ],
            Text(
              label,
              style: WaselTypography.cairo(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
            if (count != null && count!.isNotEmpty) ...[
              const SizedBox(width: WaselSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count!,
                  style: WaselTypography.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

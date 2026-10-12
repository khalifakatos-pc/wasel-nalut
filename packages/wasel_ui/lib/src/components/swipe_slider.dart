import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_typography.dart';
import '../motion/wasel_motion.dart';

/// ============================================================================
/// SWIPE TO CONFIRM SLIDER (مزلاج التمرير للتأكيد الميداني)
/// ============================================================================
/// High-friction slider designed for Captains and Drivers.
/// Prevents accidental touches with magnetic lock at 85%+ drag,
/// elastic snap-back upon release, and tactile haptic feedback.
/// ============================================================================
class SwipeToConfirmSlider extends StatefulWidget {
  final String label;
  final String completedLabel;
  final VoidCallback onConfirmed;
  final Color? activeColor;
  final Color? baseColor;
  final Color? textColor;
  final IconData icon;
  final double height;
  final bool isEnabled;

  const SwipeToConfirmSlider({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.completedLabel = 'تم التأكيد بنجاح ✓',
    this.activeColor,
    this.baseColor,
    this.textColor,
    this.icon = Icons.arrow_forward_rounded,
    this.height = 58.0,
    this.isEnabled = true,
  });

  @override
  State<SwipeToConfirmSlider> createState() => _SwipeToConfirmSliderState();
}

class _SwipeToConfirmSliderState extends State<SwipeToConfirmSlider>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isConfirmed = false;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: WaselMotion.standard,
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (!widget.isEnabled || _isConfirmed) return;

    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });

    if ((_dragPosition / maxDrag) > 0.5 && (_dragPosition / maxDrag) < 0.55) {
      HapticFeedback.selectionClick();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDrag) {
    if (!widget.isEnabled || _isConfirmed) return;

    final progress = _dragPosition / maxDrag;

    if (progress >= 0.85) {
      setState(() {
        _dragPosition = maxDrag;
        _isConfirmed = true;
      });
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
    } else {
      final isA11y = WaselMotion.isAnimationDisabled(context);
      if (isA11y) {
        setState(() {
          _dragPosition = 0.0;
        });
        return;
      }

      _resetAnimation = Tween<double>(
        begin: _dragPosition,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _resetController,
          curve: WaselMotion.joy,
        ),
      )..addListener(() {
          setState(() {
            _dragPosition = _resetAnimation.value;
          });
        });

      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveActiveColor = widget.activeColor ?? WaselColors.secondary;
    final effectiveBaseColor = widget.baseColor ??
        (isDark ? WaselColors.cardElevatedDark : WaselColors.borderLight);
    final effectiveTextColor = widget.textColor ??
        (isDark ? Colors.white : WaselColors.textPrimaryLight);

    final double buttonSize = widget.height - 8;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double maxDrag = (maxWidth - buttonSize - 8).clamp(0.0, maxWidth);
        final double progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return RepaintBoundary(
          child: Container(
            height: widget.height,
            width: maxWidth,
            decoration: BoxDecoration(
              color: effectiveBaseColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: _isConfirmed
                    ? effectiveActiveColor
                    : effectiveActiveColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Filled progress background
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragPosition + (buttonSize / 2) + 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: effectiveActiveColor.withValues(
                          alpha: _isConfirmed ? 0.95 : (0.15 + progress * 0.45)),
                      borderRadius:
                          BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),

                // Center Label
                Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                    child: Text(
                      _isConfirmed ? widget.completedLabel : widget.label,
                      style: WaselTypography.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isConfirmed ? Colors.white : effectiveTextColor,
                      ),
                    ),
                  ),
                ),

                // Draggable Thumb Knob
                Positioned(
                  left: 4 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) =>
                        _onHorizontalDragUpdate(details, maxDrag),
                    onHorizontalDragEnd: (details) =>
                        _onHorizontalDragEnd(details, maxDrag),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: _isConfirmed
                            ? Colors.white
                            : effectiveActiveColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: effectiveActiveColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isConfirmed ? Icons.check : widget.icon,
                        color: _isConfirmed
                            ? effectiveActiveColor
                            : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

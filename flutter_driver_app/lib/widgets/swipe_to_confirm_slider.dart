import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../driver_theme.dart';

/// ============================================================================
/// SWIPE TO CONFIRM SLIDER (مزلاج التمرير للتأكيد الميداني)
/// ============================================================================
/// A rugged, high-friction slider designed for Captains driving in Nalut.
/// Prevents accidental touches with magnetic snap-back under 85% drag,
/// dynamic color morphing, and tactile haptic feedback.
/// ============================================================================
class SwipeToConfirmSlider extends StatefulWidget {
  final String label;
  final String completedLabel;
  final VoidCallback onConfirmed;
  final Color activeColor;
  final Color baseColor;
  final Color textColor;
  final IconData icon;
  final double height;
  final bool isEnabled;

  const SwipeToConfirmSlider({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.completedLabel = 'تم التأكيد بنجاح ✓',
    this.activeColor = DriverColors.secondary,
    this.baseColor = DriverColors.darkCardElevated,
    this.textColor = Colors.white,
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
      duration: AppMotion.normal,
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

    // Light tick when passing halfway
    if ((_dragPosition / maxDrag) > 0.5 && (_dragPosition / maxDrag) < 0.55) {
      HapticFeedback.selectionClick();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details, double maxDrag) {
    if (!widget.isEnabled || _isConfirmed) return;

    final progress = _dragPosition / maxDrag;

    if (progress >= 0.85) {
      // Confirmed! Magnetic lock to 100%
      setState(() {
        _dragPosition = maxDrag;
        _isConfirmed = true;
      });
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
    } else {
      // Elastic snap-back
      _resetAnimation = Tween<double>(
        begin: _dragPosition,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: _resetController,
          curve: AppMotion.springSnappy,
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
    const double padding = 4.0;
    final double thumbSize = widget.height - (padding * 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = (constraints.maxWidth - thumbSize - (padding * 2)).clamp(1.0, double.infinity);
        final double progress = (maxDrag > 0) ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return RepaintBoundary(
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.baseColor,
              borderRadius: BorderRadius.circular(widget.height / 2),
              border: Border.all(
                color: widget.activeColor.withValues(alpha: 0.25 + (progress * 0.4)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.activeColor.withValues(alpha: 0.15 * progress),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 1. Sliding Fill Track
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragPosition + thumbSize + (padding * 2),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.activeColor.withValues(alpha: 0.22 + (0.35 * progress)),
                      borderRadius: BorderRadius.circular(widget.height / 2),
                    ),
                  ),
                ),

                // 2. Shimmering / Fading Hint Label
                Center(
                  child: Opacity(
                    opacity: (1.0 - (progress * 1.3)).clamp(0.0, 1.0),
                    child: Text(
                      _isConfirmed ? widget.completedLabel : widget.label,
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // 3. Draggable Tactile Thumb
                Positioned(
                  left: padding + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, maxDrag),
                    onHorizontalDragEnd: (d) => _onHorizontalDragEnd(d, maxDrag),
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.activeColor,
                            widget.activeColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.activeColor.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isConfirmed ? Icons.check_rounded : widget.icon,
                        color: Colors.white,
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

import 'package:flutter/material.dart';
import '../theme/wasel_spacing.dart';
import 'wasel_motion.dart';

/// ============================================================================
/// WASEL PULSE GLOW (الهالة الضوئية النابضة)
/// ============================================================================
/// Radiates a breathing rhythmic halo around beacons, live radar couriers,
/// or urgent action buttons. Checks [WaselMotion.isAnimationDisabled] to bypass
/// shadow oscillation for accessibility and performance.
/// ============================================================================
class WaselPulseGlow extends StatefulWidget {
  final Widget child;
  final Color? glowColor;
  final double minBlur;
  final double maxBlur;
  final double minSpread;
  final double maxSpread;
  final Duration duration;
  final BoxShape shape;
  final BorderRadius? borderRadius;
  final bool isPulsing;

  const WaselPulseGlow({
    super.key,
    required this.child,
    this.glowColor,
    this.minBlur = 8.0,
    this.maxBlur = 24.0,
    this.minSpread = 1.0,
    this.maxSpread = 6.0,
    this.duration = WaselMotion.relaxed,
    this.shape = BoxShape.circle,
    this.borderRadius,
    this.isPulsing = true,
  });

  @override
  State<WaselPulseGlow> createState() => _WaselPulseGlowState();
}

class _WaselPulseGlowState extends State<WaselPulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: WaselMotion.pulseCurve,
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WaselPulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isA11yDisabled = WaselMotion.isAnimationDisabled(context);
    final shouldAnimate = widget.isPulsing && !isA11yDisabled;

    if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    } else if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    if (!shouldAnimate) {
      return widget.child;
    }

    final effectiveColor =
        widget.glowColor ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final progress = _glowAnimation.value;
        final currentBlur =
            widget.minBlur + (widget.maxBlur - widget.minBlur) * progress;
        final currentSpread =
            widget.minSpread + (widget.maxSpread - widget.minSpread) * progress;
        final currentAlpha = 0.20 + (0.35 * progress);

        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle
                  ? null
                  : (widget.borderRadius ?? WaselRadius.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: currentAlpha),
                  blurRadius: currentBlur,
                  spreadRadius: currentSpread,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

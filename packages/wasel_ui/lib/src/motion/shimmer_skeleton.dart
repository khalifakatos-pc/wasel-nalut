import 'package:flutter/material.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_spacing.dart';
import 'wasel_motion.dart';

/// ============================================================================
/// WASEL SHIMMER & SKELETON (التموج الضوئي وهياكل التحميل)
/// ============================================================================
/// 60/120 FPS high-performance gradient shimmer with automatic accessibility
/// bypass via [WaselMotion.isAnimationDisabled].
/// ============================================================================
class WaselShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;
  final bool isShimmering;

  const WaselShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = WaselMotion.shimmerCycle,
    this.isShimmering = true,
  });

  @override
  State<WaselShimmer> createState() => _WaselShimmerState();
}

class _WaselShimmerState extends State<WaselShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.isShimmering) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(WaselShimmer oldWidget) {
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
    final shouldAnimate = widget.isShimmering && !isA11yDisabled;

    if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    } else if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    }

    if (!shouldAnimate) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBase =
        isDark ? WaselColors.cardDark : WaselColors.borderLight;
    final defaultHighlight = isDark
        ? WaselColors.primary.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.75);

    final effectiveBase = widget.baseColor ?? defaultBase;
    final effectiveHighlight = widget.highlightColor ?? defaultHighlight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                effectiveBase,
                effectiveHighlight,
                effectiveBase,
              ],
              stops: const [0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: RepaintBoundary(child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
        bounds.width * (slidePercent * 2 - 1), 0, 0);
  }
}

/// Standalone skeleton placeholder box with optional shimmer wave.
class ShimmerSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;
  final Color? color;

  const ShimmerSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark
        ? WaselColors.cardElevatedDark
        : const Color(0xFFE2E8F0);

    return WaselShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: color ?? defaultColor,
          shape: shape ??
              RoundedRectangleBorder(
                borderRadius: borderRadius ?? WaselRadius.radiusMd,
              ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias for `WaselShimmerBox`.
typedef WaselShimmerBox = ShimmerSkeleton;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system.dart';

/// ============================================================================
/// WASEL NALUT (واصل نالوت) - TACTILE MOTION & MICRO-INTERACTION WIDGETS
/// ============================================================================
/// High-performance, 60/120 FPS fluid micro-interaction widgets engineered
/// without deprecations (using Color.withValues) and optimized with RepaintBoundary
/// and AnimatedBuilder to prevent wasteful widget subtree rebuilds.
/// ============================================================================

/// ---------------------------------------------------------------------------
/// 1. WASEL BOUNCY PRESSABLE (تفاعل الضغط الفيزيائي المرتد)
/// ---------------------------------------------------------------------------
/// Provides tactile physical feedback on tap: scales down to [pressedScale] (default 0.96)
/// on pointer down, and springs back with overshoot elasticity upon release.
class WaselBouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const WaselBouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = AppMotion.pressScaleButton,
    this.pressDuration = AppMotion.fast,
    this.releaseDuration = const Duration(milliseconds: 250),
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<WaselBouncyPressable> createState() => _WaselBouncyPressableState();
}

class _WaselBouncyPressableState extends State<WaselBouncyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;
  DateTime? _pressStartTime;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: AppMotion.easeOutCubic,
        reverseCurve: AppMotion.springSnappy,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _isPressed = true;
    _pressStartTime = DateTime.now();
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    _isPressed = false;
    final elapsed = DateTime.now().difference(_pressStartTime ?? DateTime.now()).inMilliseconds;
    if (elapsed < 80) {
      Future.delayed(Duration(milliseconds: 80 - elapsed), () {
        if (mounted && !_isPressed) {
          _controller.reverse();
        }
      });
    } else {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// Convenience styled bouncy button wrapper
class WaselBouncyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? shadows;
  final double pressedScale;

  const WaselBouncyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.borderRadius,
    this.border,
    this.shadows,
    this.pressedScale = AppMotion.pressScaleButton,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppRadius.radiusMd;
    return WaselBouncyPressable(
      onTap: onPressed,
      pressedScale: pressedScale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.waselPrimary,
          borderRadius: effectiveRadius,
          border: border,
          boxShadow: shadows ?? AppShadows.glowWasel,
        ),
        child: Padding(
          padding: padding,
          child: Center(
            widthFactor: 1.0,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2. WASEL PULSE GLOW (الهالة الضوئية النابضة)
/// ---------------------------------------------------------------------------
/// Radiates a breathing rhythmic halo around beacons, live radar couriers,
/// or urgent action buttons. Zero memory leaks with automatic ticker management.
class WaselPulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
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
    this.glowColor = AppColors.waselPrimary,
    this.minBlur = 8.0,
    this.maxBlur = 24.0,
    this.minSpread = 1.0,
    this.maxSpread = 6.0,
    this.duration = AppMotion.relaxed,
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
      curve: AppMotion.pulseCurve,
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WaselPulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final progress = _glowAnimation.value;
        final currentBlur = widget.minBlur + (widget.maxBlur - widget.minBlur) * progress;
        final currentSpread = widget.minSpread + (widget.maxSpread - widget.minSpread) * progress;
        final currentAlpha = 0.20 + (0.35 * progress);

        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle ? null : (widget.borderRadius ?? AppRadius.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: currentAlpha),
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

/// ---------------------------------------------------------------------------
/// 3. WASEL SHIMMER (التموج الضوئي للتحميل - 60/120 FPS)
/// ---------------------------------------------------------------------------
/// Ultra-smooth gold/emerald gradient shimmer for loading lists, cards, and skeletons.
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
    this.duration = AppMotion.shimmer,
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
    if (widget.isShimmering != oldWidget.isShimmering) {
      if (widget.isShimmering) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isShimmering) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBase = isDark
        ? AppColors.darkCard
        : AppColors.lightBorderSubtle;
    final defaultHighlight = isDark
        ? AppColors.waselPrimary.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.7);

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
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
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
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0, 0);
  }
}

/// Convenience skeleton placeholder container
class WaselShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const WaselShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkCard : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: color,
        shape: shape ??
            RoundedRectangleBorder(
              borderRadius: borderRadius ?? AppRadius.radiusMd,
            ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 4. WASEL NUMBER ODOMETER (العدّاد المتدحرج للأسعار والنقاط)
/// ---------------------------------------------------------------------------
/// Smoothly rolls numbers from current value to target value (e.g., 25.50 د.ل)
/// with zero layout stutter or GC pressure.
class WaselNumberOdometer extends StatelessWidget {
  final double value;
  final int decimalPlaces;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const WaselNumberOdometer({
    super.key,
    required this.value,
    this.decimalPlaces = 2,
    this.prefix = '',
    this.suffix = ' د.ل',
    this.style,
    this.duration = AppMotion.slow,
    this.curve = AppMotion.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = AppTypography.titleLarge.copyWith(
      color: AppColors.waselPrimary,
      fontWeight: FontWeight.w800,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        final formattedNumber = animatedValue.toStringAsFixed(decimalPlaces);
        return Text(
          '$prefix$formattedNumber$suffix',
          style: style ?? defaultStyle,
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// 5. WASEL RADAR SWEEP (المسح الراداري الحي بزاوية 360 درجة)
/// ---------------------------------------------------------------------------
/// High-performance CustomPainter radar sweep for Nalut fleet operations.
class WaselRadarSweep extends StatefulWidget {
  final double size;
  final Color sweepColor;
  final Color ringColor;
  final Duration duration;
  final Widget? centerChild;

  const WaselRadarSweep({
    super.key,
    this.size = 220.0,
    this.sweepColor = AppColors.waselTeal,
    this.ringColor = const Color(0x3310B981),
    this.duration = const Duration(seconds: 3),
    this.centerChild,
  });

  @override
  State<WaselRadarSweep> createState() => _WaselRadarSweepState();
}

class _WaselRadarSweepState extends State<WaselRadarSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _RadarSweepPainter(
                    angle: _controller.value * 2 * math.pi,
                    sweepColor: widget.sweepColor,
                    ringColor: widget.ringColor,
                  ),
                );
              },
            ),
            if (widget.centerChild != null) widget.centerChild!,
          ],
        ),
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double angle;
  final Color sweepColor;
  final Color ringColor;

  _RadarSweepPainter({
    required this.angle,
    required this.sweepColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw Concentric Range Rings
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    // 2. Draw Crosshairs
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ringPaint,
    );

    // 3. Draw Radar Rotating Sweep Arc (SweepGradient)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2, // 90 degree sweep cone
        colors: [
          sweepColor.withValues(alpha: 0.0),
          sweepColor.withValues(alpha: 0.35),
        ],
        transform: GradientRotation(angle - (math.pi / 2)),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // 4. Draw Leading Scan Beam Line
    final beamPaint = Paint()
      ..color = sweepColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final endX = center.dx + radius * math.cos(angle);
    final endY = center.dy + radius * math.sin(angle);
    canvas.drawLine(center, Offset(endX, endY), beamPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.sweepColor != sweepColor ||
        oldDelegate.ringColor != ringColor;
  }
}

/// ---------------------------------------------------------------------------
/// 6. WASEL SLIDE FADE TRANSITION (انتقال الظهور التدريجي المتدرج)
/// ---------------------------------------------------------------------------
/// Staggered entry animation with customizable delay and vertical slide offset.
class WaselSlideFade extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const WaselSlideFade({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.offset = const Offset(0.0, 0.12),
    this.curve = AppMotion.easeOutCubic,
  });

  @override
  State<WaselSlideFade> createState() => _WaselSlideFadeState();
}

class _WaselSlideFadeState extends State<WaselSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child,
          ),
        );
      },
      child: RepaintBoundary(child: widget.child),
    );
  }
}

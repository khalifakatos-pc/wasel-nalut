import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

/// ============================================================================
/// WASEL SUPER ADMIN OPERATIONS - MOTION & TELEMETRY WIDGETS
/// ============================================================================
/// 60/120 FPS high-performance motion widgets for live dispatch and monitoring.
/// ============================================================================

/// 1. WaselBouncyPressable (Admin Operations Hub Edition)
class WaselBouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;

  const WaselBouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = AppMotion.pressScaleButton,
    this.pressDuration = AppMotion.fast,
    this.releaseDuration = const Duration(milliseconds: 250),
  });

  @override
  State<WaselBouncyPressable> createState() => _WaselBouncyPressableState();
}

class _WaselBouncyPressableState extends State<WaselBouncyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

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
    if (widget.onTap == null) return;
    _isPressed = true;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
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

/// 2. WaselPulseGlow (Admin Live Fleet Courier Beacon)
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
    this.glowColor = AdminColors.emeraldGreen,
    this.minBlur = 6.0,
    this.maxBlur = 22.0,
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
              borderRadius: widget.shape == BoxShape.circle ? null : (widget.borderRadius ?? BorderRadius.circular(12)),
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

/// 3. WaselNumberOdometer (Admin Live Revenue & Platform Metrics)
class WaselNumberOdometer extends StatelessWidget {
  final double value;
  final int decimalPlaces;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const WaselNumberOdometer({
    super.key,
    required this.value,
    this.decimalPlaces = 2,
    this.prefix = '',
    this.suffix = ' د.ل',
    this.style,
    this.duration = AppMotion.slow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: AppMotion.easeOutCubic,
      builder: (context, animatedValue, child) {
        final formattedNumber = animatedValue.toStringAsFixed(decimalPlaces);
        return Text(
          '$prefix$formattedNumber$suffix',
          style: style,
        );
      },
    );
  }
}

/// 4. WaselRadarSweep (Admin Ops Radar on Nalut Dispatch Hub)
class WaselRadarSweep extends StatefulWidget {
  final double size;
  final Color sweepColor;
  final Color ringColor;
  final Duration duration;
  final Widget? centerChild;

  const WaselRadarSweep({
    super.key,
    this.size = 260.0,
    this.sweepColor = AdminColors.emeraldGreen,
    this.ringColor = const Color(0x3310B981),
    this.duration = const Duration(seconds: 4),
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
                  painter: _AdminRadarPainter(
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

class _AdminRadarPainter extends CustomPainter {
  final double angle;
  final Color sweepColor;
  final Color ringColor;

  _AdminRadarPainter({
    required this.angle,
    required this.sweepColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.25, ringPaint);
    canvas.drawCircle(center, radius * 0.50, ringPaint);
    canvas.drawCircle(center, radius * 0.75, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

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

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          sweepColor.withValues(alpha: 0.0),
          sweepColor.withValues(alpha: 0.35),
        ],
        transform: GradientRotation(angle - (math.pi / 2)),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    final beamPaint = Paint()
      ..color = sweepColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final endX = center.dx + radius * math.cos(angle);
    final endY = center.dy + radius * math.sin(angle);
    canvas.drawLine(center, Offset(endX, endY), beamPaint);
  }

  @override
  bool shouldRepaint(covariant _AdminRadarPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.sweepColor != sweepColor ||
        oldDelegate.ringColor != ringColor;
  }
}

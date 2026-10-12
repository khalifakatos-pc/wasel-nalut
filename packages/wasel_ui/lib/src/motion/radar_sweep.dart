import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/wasel_colors.dart';
import 'wasel_motion.dart';

/// ============================================================================
/// WASEL RADAR SWEEP (المسح الراداري الحي بزاوية 360 درجة)
/// ============================================================================
/// High-performance 360-degree rotating radar with range rings, crosshairs,
/// and sweep cone. Checks [WaselMotion.isAnimationDisabled] to pause sweep.
/// ============================================================================
class WaselRadarSweep extends StatefulWidget {
  final double size;
  final Color sweepColor;
  final Color ringColor;
  final Duration duration;
  final Widget? centerChild;

  const WaselRadarSweep({
    super.key,
    this.size = 220.0,
    this.sweepColor = WaselColors.secondary,
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
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isA11yDisabled = WaselMotion.isAnimationDisabled(context);
    if (isA11yDisabled && _controller.isAnimating) {
      _controller.stop();
    } else if (!isA11yDisabled && !_controller.isAnimating) {
      _controller.repeat();
    }

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
                final angle = isA11yDisabled
                    ? 0.0
                    : _controller.value * 2 * math.pi;
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _RadarSweepPainter(
                    angle: angle,
                    sweepColor: widget.sweepColor,
                    ringColor: widget.ringColor,
                    drawBeam: !isA11yDisabled,
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
  final bool drawBeam;

  _RadarSweepPainter({
    required this.angle,
    required this.sweepColor,
    required this.ringColor,
    required this.drawBeam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Concentric Range Rings
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    // 2. Crosshairs
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

    // 3. Rotating Sweep Cone
    if (drawBeam) {
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

      // 4. Leading Beam Line
      final beamPaint = Paint()
        ..color = sweepColor.withValues(alpha: 0.8)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(endX, endY), beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.sweepColor != sweepColor ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.drawBeam != drawBeam;
  }
}

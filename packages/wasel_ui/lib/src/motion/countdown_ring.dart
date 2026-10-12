import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_typography.dart';

/// ============================================================================
/// COUNTDOWN RING (حلقة العد التنازلي التفاعلية)
/// ============================================================================
/// Circular timer with smooth urgency color interpolation:
/// Green (>50%) -> Amber (20%-50%) -> Urgent Red (<20%).
/// Optimized for order acceptance radar and kitchen cooking timers.
/// ============================================================================
class CountdownRing extends StatelessWidget {
  final double progress; // 1.0 (full) down to 0.0 (expired)
  final int? remainingSeconds;
  final int? totalSeconds;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? centerChild;
  final bool showText;

  const CountdownRing({
    super.key,
    required this.progress,
    this.remainingSeconds,
    this.totalSeconds,
    this.size = 64.0,
    this.strokeWidth = 4.5,
    this.color,
    this.trackColor,
    this.centerChild,
    this.showText = true,
  });

  /// Factory constructor taking duration and remaining duration.
  factory CountdownRing.fromDuration({
    Key? key,
    required Duration total,
    required Duration remaining,
    double size = 64.0,
    double strokeWidth = 4.5,
    Color? color,
    Color? trackColor,
    Widget? centerChild,
    bool showText = true,
  }) {
    final double safeTotal = total.inMilliseconds > 0
        ? total.inMilliseconds.toDouble()
        : 1.0;
    final double ratio =
        (remaining.inMilliseconds / safeTotal).clamp(0.0, 1.0);
    return CountdownRing(
      key: key,
      progress: ratio,
      remainingSeconds: remaining.inSeconds,
      totalSeconds: total.inSeconds,
      size: size,
      strokeWidth: strokeWidth,
      color: color,
      trackColor: trackColor,
      centerChild: centerChild,
      showText: showText,
    );
  }

  Color _resolveColor(double ratio) {
    if (color != null) return color!;
    if (ratio > 0.5) {
      return WaselColors.secondary; // Emerald
    } else if (ratio > 0.2) {
      return WaselColors.warning; // Amber
    } else {
      return WaselColors.error; // Urgent Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final clampedRatio = progress.clamp(0.0, 1.0);
    final activeColor = _resolveColor(clampedRatio);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultTrack = isDark
        ? WaselColors.cardElevatedDark
        : WaselColors.borderLight;
    final effectiveTrack = trackColor ?? defaultTrack;

    Widget? displayChild = centerChild;
    if (displayChild == null && showText && remainingSeconds != null) {
      displayChild = Text(
        '$remainingSeconds',
        style: WaselTypography.outfit(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: activeColor,
        ),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: clampedRatio,
                strokeWidth: strokeWidth,
                activeColor: activeColor,
                trackColor: effectiveTrack,
              ),
            ),
            ?displayChild,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // Active sweep arc
    if (progress > 0.0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Start from 12 o'clock (-pi / 2)
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

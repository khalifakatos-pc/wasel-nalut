import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';

/// ============================================================================
/// SIMULATED VECTOR NAVIGATION MAP WIDGET FOR CAPTAIN WASEL (NALUT)
/// ============================================================================

class SimulatedDriverMap extends StatefulWidget {
  final DeliveryStep? activeStep;
  final String? storeName;
  final String? destinationAddress;
  final bool isInteractive;
  final double height;
  final VoidCallback? onRecenter;

  const SimulatedDriverMap({
    super.key,
    this.activeStep,
    this.storeName,
    this.destinationAddress,
    this.isInteractive = true,
    this.height = 300,
    this.onRecenter,
  });

  @override
  State<SimulatedDriverMap> createState() => _SimulatedDriverMapState();
}

class _SimulatedDriverMapState extends State<SimulatedDriverMap> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _progressAnim = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: widget.height,
      width: double.infinity,
      color: isDark ? const Color(0xFF080C14) : const Color(0xFFE2E8F0),
      child: Stack(
        children: [
          // 1. Vector Map Canvas
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (context, child) {
              return CustomPaint(
                size: Size(double.infinity, widget.height),
                painter: _DriverMapPainter(
                  progress: _progressAnim.value,
                  step: widget.activeStep ?? DeliveryStep.navigatingToStore,
                  isDark: isDark,
                ),
              );
            },
          ),

          // 2. Turn-by-Turn Instruction Banner
          if (widget.activeStep != null && widget.activeStep != DeliveryStep.deliveryFinished)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildNavigationInstructionBanner(isDark),
            ),

          // 3. Live GPS Telemetry Badge (Nalut)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? DriverColors.darkSurface : Colors.white).withValues(alpha: 0.92),
                borderRadius: DriverRadius.radiusFull,
                border: Border.all(
                  color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 14, color: DriverColors.onlineGreen),
                  SizedBox(width: 6),
                  Text(
                    'GPS 38 كم/س • نالوت 31.868° N',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Map Control Buttons
          if (widget.isInteractive)
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  _buildMapCircleBtn(
                    icon: Icons.navigation_rounded,
                    onTap: widget.onRecenter ?? () {},
                    isDark: isDark,
                    color: DriverColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _buildMapCircleBtn(
                    icon: Icons.layers_outlined,
                    onTap: () {},
                    isDark: isDark,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationInstructionBanner(bool isDark) {
    String instruction;
    String distance;
    IconData turnIcon;

    switch (widget.activeStep!) {
      case DeliveryStep.navigatingToStore:
        instruction = 'توجه شمالاً عبر طريق وازن نحو مطعم قصر نالوت';
        distance = 'بعد 350 م • انعطف يميناً';
        turnIcon = Icons.turn_right_rounded;
        break;
      case DeliveryStep.orderPickupChecklist:
        instruction = 'توقف أمام مطعم قصر نالوت واستلم الوجبات';
        distance = 'لقد وصلت إلى المطعم';
        turnIcon = Icons.storefront_rounded;
        break;
      case DeliveryStep.navigatingToCustomer:
        instruction = 'انعطف يساراً نحو حي الشهداء شارع النور';
        distance = 'بعد 600 م • الوجهة على اليمين';
        turnIcon = Icons.turn_left_rounded;
        break;
      case DeliveryStep.completeDeliveryOtp:
        instruction = 'تحصيل الكاش وإدخال رمز OTP من الزبون';
        distance = 'وصلت لعنوان الزبون (حي الشهداء)';
        turnIcon = Icons.location_on_rounded;
        break;
      case DeliveryStep.deliveryFinished:
        instruction = 'تم اكتمال المشوار بنجاح!';
        distance = 'تمت إضافة الأرباح لمحفظتك';
        turnIcon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkCardElevated : Colors.white,
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(
          color: DriverColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: DriverColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(turnIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  distance,
                  style: const TextStyle(
                    color: DriverColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instruction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? DriverColors.darkCardElevated : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: color ?? (isDark ? Colors.white : DriverColors.lightTextPrimary),
        ),
      ),
    );
  }
}

/// Custom Vector Canvas for Nalut map roads, curves, and animated car
class _DriverMapPainter extends CustomPainter {
  final double progress;
  final DeliveryStep step;
  final bool isDark;

  _DriverMapPainter({
    required this.progress,
    required this.step,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)
      ..strokeWidth = 22
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadCenterPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Road 1: Horizontal Main Avenue (Nalut Wazen Highway)
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), roadCenterPaint);

    // Road 2: Vertical Connecting Avenue (Al-Shuhada road)
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), roadCenterPaint);

    // Active Route Path
    final routePath = Path();
    final startPt = Offset(size.width * 0.2, size.height * 0.75);
    final midPt1 = Offset(size.width * 0.35, size.height * 0.45);
    final midPt2 = Offset(size.width * 0.7, size.height * 0.45);
    final endPt = Offset(size.width * 0.82, size.height * 0.25);

    routePath.moveTo(startPt.dx, startPt.dy);
    routePath.quadraticBezierTo(size.width * 0.25, size.height * 0.55, midPt1.dx, midPt1.dy);
    routePath.lineTo(midPt2.dx, midPt2.dy);
    routePath.quadraticBezierTo(size.width * 0.78, size.height * 0.35, endPt.dx, endPt.dy);

    // Draw route line
    final routeBorderPaint = Paint()
      ..color = DriverColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, routeBorderPaint);

    final routeMainPaint = Paint()
      ..color = DriverColors.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, routeMainPaint);

    // Store Pin (Start)
    final storePaint = Paint()..color = DriverColors.secondary;
    canvas.drawCircle(startPt, 12, storePaint);
    canvas.drawCircle(startPt, 4, Paint()..color = Colors.white);

    // Customer Pin (End)
    final custPaint = Paint()..color = DriverColors.onlineGreen;
    canvas.drawCircle(endPt, 12, custPaint);
    canvas.drawCircle(endPt, 4, Paint()..color = Colors.white);

    // Animated Driver Vehicle Marker
    final pathMetrics = routePath.computeMetrics();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final tangent = metric.getTangentForOffset(metric.length * progress);

      if (tangent != null) {
        final driverPos = tangent.position;
        final heading = tangent.angle;

        // Vehicle halo pulse
        final pulsePaint = Paint()
          ..color = DriverColors.primary.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(driverPos, 22, pulsePaint);

        // Vehicle body circle
        final vehiclePaint = Paint()..color = DriverColors.primary;
        canvas.drawCircle(driverPos, 14, vehiclePaint);

        // Direction arrow
        final arrowPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

        final arrowPath = Path();
        arrowPath.moveTo(driverPos.dx + math.cos(heading) * 8, driverPos.dy + math.sin(heading) * 8);
        arrowPath.lineTo(driverPos.dx - math.cos(heading + 0.5) * 6, driverPos.dy - math.sin(heading + 0.5) * 6);
        arrowPath.moveTo(driverPos.dx + math.cos(heading) * 8, driverPos.dy + math.sin(heading) * 8);
        arrowPath.lineTo(driverPos.dx - math.cos(heading - 0.5) * 6, driverPos.dy - math.sin(heading - 0.5) * 6);

        canvas.drawPath(arrowPath, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DriverMapPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.step != step || oldDelegate.isDark != isDark;
  }
}

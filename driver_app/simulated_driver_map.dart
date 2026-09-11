import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';

/// ============================================================================
/// SIMULATED VECTOR NAVIGATION MAP WIDGET FOR DRIVERS
/// ============================================================================
/// Features:
/// 1. Dynamic road network with realistic urban styling (day & dark OLED night).
/// 2. Active route polyline with progress animation & direction arrows.
/// 3. Store, Customer, and Driver vehicle markers (Motorcycle/Car) with heading.
/// 4. Dynamic turn-by-turn instruction overlay banner.
/// 5. Live GPS telemetry HUD (speed, accuracy, heading).
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

          // 2. Turn-by-Turn Instruction Banner (if on active step)
          if (widget.activeStep != null && widget.activeStep != DeliveryStep.deliveryFinished)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildNavigationInstructionBanner(isDark),
            ),

          // 3. Live GPS Telemetry Badge
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
                    'GPS 42 km/h • 32.875° N',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Map Control Buttons (Recenter & Zoom)
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
        instruction = 'Head north on Gargarish Rd toward Tripoli Tower';
        distance = 'In 350m • Turn right';
        turnIcon = Icons.turn_right_rounded;
        break;
      case DeliveryStep.orderPickupChecklist:
        instruction = 'Park at Smash Burger & verify customer items';
        distance = 'You have arrived at store';
        turnIcon = Icons.storefront_rounded;
        break;
      case DeliveryStep.navigatingToCustomer:
        instruction = 'Turn left onto Hai Al-Andalus Ring Rd';
        distance = 'In 800m • Destination on left';
        turnIcon = Icons.turn_left_rounded;
        break;
      case DeliveryStep.completeDeliveryOtp:
        instruction = 'Collect customer OTP & cash payment at doorstep';
        distance = 'Arrived at Customer Villa 8B';
        turnIcon = Icons.location_on_rounded;
        break;
      case DeliveryStep.deliveryFinished:
        instruction = 'Trip Completed!';
        distance = 'Earnings credited';
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
                  style: DriverTypography.titleMedium.copyWith(
                    color: DriverColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instruction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DriverTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? DriverColors.darkSurface : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: color ?? (isDark ? Colors.white : DriverColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}

/// Custom Vector Map Painter rendering city grid, water bodies, routes, and pulsating markers
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
    final bgPaint = Paint()..color = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 1. Draw Coastline / Water Body (Mediterranean Sea Tripoli Coast at top)
    final seaPaint = Paint()..color = isDark ? const Color(0xFF0F2338) : const Color(0xFFD0E8FF);
    final seaPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.22, size.width * 0.3, size.height * 0.14)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.08, 0, size.height * 0.15)
      ..close();
    canvas.drawPath(seaPath, seaPaint);

    // 2. Draw Urban Road Grid Lines
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final secondaryRoadPaint = Paint()
      ..color = isDark ? const Color(0xFF151F30) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Grid lines
    for (double x = 40; x < size.width; x += 70) {
      canvas.drawLine(Offset(x, size.height * 0.15), Offset(x, size.height), secondaryRoadPaint);
    }
    for (double y = size.height * 0.25; y < size.height; y += 55) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secondaryRoadPaint);
    }

    // Main Coastal Highway (Gargarish Rd)
    final highwayPath = Path()
      ..moveTo(0, size.height * 0.32)
      ..cubicTo(
        size.width * 0.35, size.height * 0.30,
        size.width * 0.65, size.height * 0.40,
        size.width, size.height * 0.36,
      );
    canvas.drawPath(highwayPath, roadPaint);

    // 3. Active Delivery Navigation Polyline Route
    final routePath = Path();
    final p0 = Offset(size.width * 0.18, size.height * 0.72); // Store Location
    final p1 = Offset(size.width * 0.45, size.height * 0.45); // Turn point
    final p2 = Offset(size.width * 0.82, size.height * 0.38); // Customer Location

    routePath.moveTo(p0.dx, p0.dy);
    routePath.quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);

    // Route Outer Glow
    final routeGlowPaint = Paint()
      ..color = DriverColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, routeGlowPaint);

    // Route Main Line
    final activeRoutePaint = Paint()
      ..color = DriverColors.primary
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, activeRoutePaint);

    // 4. Store Waypoint Marker (Pickup)
    _drawStoreMarker(canvas, p0);

    // 5. Customer Waypoint Marker (Dropoff)
    _drawCustomerMarker(canvas, p2);

    // 6. Driver Vehicle Marker (Interpolated position along curve)
    final t = progress;
    // Quadratic bezier formula: B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
    final currentX = math.pow(1 - t, 2) * p0.dx + 2 * (1 - t) * t * p1.dx + math.pow(t, 2) * p2.dx;
    final currentY = math.pow(1 - t, 2) * p0.dy + 2 * (1 - t) * t * p1.dy + math.pow(t, 2) * p2.dy;
    final driverPos = Offset(currentX.toDouble(), currentY.toDouble());

    _drawDriverMarker(canvas, driverPos);
  }

  void _drawStoreMarker(Canvas canvas, Offset pos) {
    // Pulse ring
    final pulsePaint = Paint()
      ..color = DriverColors.secondary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 16, pulsePaint);

    // Pin base
    final pinPaint = Paint()..color = DriverColors.secondary;
    canvas.drawCircle(pos, 10, pinPaint);

    // Inner icon dot
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(pos, 4, innerPaint);
  }

  void _drawCustomerMarker(Canvas canvas, Offset pos) {
    // Pulse ring
    final pulsePaint = Paint()
      ..color = DriverColors.onlineGreen.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 16, pulsePaint);

    // Pin base
    final pinPaint = Paint()..color = DriverColors.onlineGreen;
    canvas.drawCircle(pos, 10, pinPaint);

    // Inner icon dot
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(pos, 4, innerPaint);
  }

  void _drawDriverMarker(Canvas canvas, Offset pos) {
    // Large glowing aura
    final glowPaint = Paint()
      ..color = DriverColors.accentCyan.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 22, glowPaint);

    // Vehicle circle background
    final vehicleBgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(pos, 14, vehicleBgPaint);

    // Cyan Border
    final borderPaint = Paint()
      ..color = DriverColors.accentCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, 14, borderPaint);

    // Vehicle direction chevron (North-East pointing)
    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowPath = Path()
      ..moveTo(pos.dx - 4, pos.dy + 4)
      ..lineTo(pos.dx + 4, pos.dy - 3)
      ..lineTo(pos.dx - 2, pos.dy - 5);
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _DriverMapPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.step != step || oldDelegate.isDark != isDark;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_system.dart';

/// ============================================================================
/// PRESTO x MATAA REAL-TIME ORDER TRACKING SCREEN
/// ============================================================================
/// Features:
/// 1. Interactive simulated Vector Map with smooth route, moving driver marker,
///    animated radar pulses, store & customer pins.
/// 2. Live Step Timeline: Placed -> Preparing -> On the Way -> Delivered.
/// 3. Captain / Driver Contact Card with vehicle details, star rating, call & chat.
/// 4. Secure Delivery OTP Code & Live ETA countdown badge.
/// 5. Expandable Order Itemization with financial summary & payment method.
/// 6. Live State Simulator: Tap buttons to advance order progress and test animations!
/// ============================================================================

enum OrderStatus {
  placed,
  preparing,
  onTheWay,
  delivered,
}

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with TickerProviderStateMixin {
  OrderStatus _currentStatus = OrderStatus.onTheWay;
  late AnimationController _pulseController;
  late AnimationController _driverMoveController;
  late Animation<double> _driverProgressAnimation;

  // Delivery simulation parameters
  int _etaMinutes = 14;
  final String _deliveryPin = '8492';
  bool _isDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _driverMoveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _driverProgressAnimation = Tween<double>(begin: 0.25, end: 0.78).animate(
      CurvedAnimation(parent: _driverMoveController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _driverMoveController.dispose();
    super.dispose();
  }

  void _advanceOrderState() {
    setState(() {
      switch (_currentStatus) {
        case OrderStatus.placed:
          _currentStatus = OrderStatus.preparing;
          _etaMinutes = 24;
          break;
        case OrderStatus.preparing:
          _currentStatus = OrderStatus.onTheWay;
          _etaMinutes = 14;
          break;
        case OrderStatus.onTheWay:
          _currentStatus = OrderStatus.delivered;
          _etaMinutes = 0;
          break;
        case OrderStatus.delivered:
          _currentStatus = OrderStatus.placed;
          _etaMinutes = 30;
          break;
      }
    });
  }

  String get _statusTitle {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return "Order Placed & Confirmed";
      case OrderStatus.preparing:
        return "Kitchen is Preparing Food";
      case OrderStatus.onTheWay:
        return "Captain is on the Way!";
      case OrderStatus.delivered:
        return "Order Delivered! Enjoy!";
    }
  }

  String get _statusSubtitle {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return "Restaurant has accepted your order #PR-89214";
      case OrderStatus.preparing:
        return "Fresh ingredients being grilled & packed";
      case OrderStatus.onTheWay:
        return "Captain Ali is 1.8 km away on Yamaha motorcycle";
      case OrderStatus.delivered:
        return "Delivered to Al-Mansour, District 604";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Tracking #PR-89214',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Text(
              'Smash Triple Burger Co.',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // Interactive Simulator Action Button in App Bar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _advanceOrderState,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.prestoPrimary.withValues(alpha: 0.12),
                foregroundColor: AppColors.prestoPrimary,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusFull),
              ),
              icon: const Icon(Icons.fast_forward_rounded, size: 16),
              label: const Text('Advance Step', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Simulated Interactive Map Layer (Top 45% of screen)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.42,
            child: _buildInteractiveMap(isDark),
          ),

          // 2. Draggable / Scrollable Order Details & Tracking Sheet
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.36,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: AppRadius.topXxl,
                boxShadow: AppShadows.lg,
              ),
              child: ClipRRect(
                borderRadius: AppRadius.topXxl,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  children: [
                    // Sheet Handle Drag Pill
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                          borderRadius: AppRadius.radiusFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ETA Header & Security OTP Pin Badge
                    _buildEtaAndOtpBanner(isDark),
                    const SizedBox(height: 16),

                    // Order Progress Timeline Steps
                    _buildProgressTimeline(isDark),
                    const SizedBox(height: 18),

                    // Driver / Captain Profile Card
                    if (_currentStatus != OrderStatus.delivered)
                      _buildDriverContactCard(isDark),

                    const SizedBox(height: 18),

                    // Expandable Order Details Card
                    _buildOrderBreakdownCard(isDark),

                    const SizedBox(height: 20),

                    // Help & Support Floating Buttons
                    _buildSupportRow(isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// SIMULATED VECTOR MAP WITH ROUTE & MOVING DRIVER
  /// ---------------------------------------------------------------------------
  Widget _buildInteractiveMap(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _driverProgressAnimation]),
      builder: (context, child) {
        return CustomPaint(
          painter: _MapRoutePainter(
            driverProgress: _driverProgressAnimation.value,
            pulseValue: _pulseController.value,
            status: _currentStatus,
            isDark: isDark,
          ),
          child: Stack(
            children: [
              // Map Overlay Buttons (Recenter & Map Layer)
              Positioned(
                right: 16,
                top: 16,
                child: Column(
                  children: [
                    _buildMapIconButton(
                      icon: Icons.my_location_rounded,
                      onTap: () {},
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildMapIconButton(
                      icon: Icons.layers_outlined,
                      onTap: () {},
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // Live Speed / Traffic Badge
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.9),
                    borderRadius: AppRadius.radiusFull,
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currentStatus == OrderStatus.onTheWay ? 'Live GPS • 38 km/h' : 'Tracking Active',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppShadows.md,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// ETA & OTP PIN BANNER
  /// ---------------------------------------------------------------------------
  Widget _buildEtaAndOtpBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _currentStatus == OrderStatus.delivered
            ? AppColors.jetGradient
            : AppColors.prestoGradient,
        borderRadius: AppRadius.radiusXl,
        boxShadow: AppShadows.colored(
          _currentStatus == OrderStatus.delivered ? AppColors.jetPrimary : AppColors.prestoPrimary,
          opacity: 0.3,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ETA Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStatus == OrderStatus.delivered ? 'STATUS' : 'ESTIMATED ARRIVAL',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _currentStatus == OrderStatus.delivered
                    ? 'Delivered'
                    : '$_etaMinutes mins',
                style: AppTypography.displayMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _statusSubtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),

          // Security OTP Delivery PIN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'DELIVERY PIN',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white70,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _deliveryPin,
                  style: AppTypography.monoNumber.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// PROGRESS TIMELINE (Placed -> Preparing -> On the Way -> Delivered)
  /// ---------------------------------------------------------------------------
  Widget _buildProgressTimeline(bool isDark) {
    final steps = [
      {'title': 'Placed', 'subtitle': '2:45 PM', 'status': OrderStatus.placed},
      {'title': 'Preparing', 'subtitle': '2:48 PM', 'status': OrderStatus.preparing},
      {'title': 'On The Way', 'subtitle': '2:58 PM', 'status': OrderStatus.onTheWay},
      {'title': 'Delivered', 'subtitle': 'Est 3:12 PM', 'status': OrderStatus.delivered},
    ];

    int currentIndex = _currentStatus.index;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isEven) {
                // Step Node
                final stepIdx = i ~/ 2;
                final isCompleted = stepIdx <= currentIndex;
                final isCurrent = stepIdx == currentIndex;

                return Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted ? AppColors.prestoPrimary : Colors.transparent,
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.prestoPrimary
                              : (isDark ? AppColors.darkBorder : AppColors.lightTextMuted),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: isCompleted
                            ? (isCurrent && _currentStatus != OrderStatus.delivered
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 16, color: Colors.white))
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightTextMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[stepIdx]['title'] as String,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w500,
                        color: isCompleted
                            ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      ),
                    ),
                    Text(
                      steps[stepIdx]['subtitle'] as String,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 9,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                );
              } else {
                // Connector Line
                final stepIdx = i ~/ 2;
                final isPassed = stepIdx < currentIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? AppColors.prestoPrimary
                          : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
                      borderRadius: AppRadius.radiusFull,
                    ),
                  ),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// DRIVER PROFILE & INTERACTIVE CONTACT CARD
  /// ---------------------------------------------------------------------------
  Widget _buildDriverContactCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          // Driver Avatar
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.prestoGradient,
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, size: 30, color: Colors.white),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.motorcycle_rounded, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Driver Name & Rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ali Al-Iraqi',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: AppRadius.radiusXs,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
                          SizedBox(width: 2),
                          Text(
                            '4.95',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Yamaha MT-07 • Plate: BAG 4819',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Quick Action Contact Buttons (Chat & Call)
          Row(
            children: [
              _buildCircularActionButton(
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.mataaPrimary,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening live chat with Captain Ali...'),
                      backgroundColor: AppColors.mataaNavy,
                    ),
                  );
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildCircularActionButton(
                icon: Icons.phone_rounded,
                color: AppColors.success,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calling Captain Ali (+964 770 000 0000)...'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// EXPANDABLE ORDER BREAKDOWN CARD
  /// ---------------------------------------------------------------------------
  Widget _buildOrderBreakdownCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Expand Header
          InkWell(
            borderRadius: AppRadius.radiusLg,
            onTap: () {
              setState(() {
                _isDetailsExpanded = !_isDetailsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: AppColors.prestoPrimary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Order Items (3 items)',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '\$28.50',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.prestoPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isDetailsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isDetailsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  _buildItemRow('2x Smash Triple Wagyu Burger', 'Extra Truffle Mayo, Pickles', '\$23.00', isDark),
                  const SizedBox(height: 10),
                  _buildItemRow('1x Crispy Truffle Fries', 'Cajun Seasoning', '\$3.50', isDark),
                  const SizedBox(height: 10),
                  _buildItemRow('1x Passion Fruit Sparkling Cooler', 'Less ice, Fresh Mint', '\$2.00', isDark),
                  const Divider(height: 20),
                  _buildCostLine('Subtotal', '\$28.50', isDark),
                  const SizedBox(height: 4),
                  _buildCostLine('Delivery Fee', 'FREE (VIP Deal)', isDark, isHighlight: true),
                  const SizedBox(height: 4),
                  _buildCostLine('Payment Method', 'ZainCash (Paid)', isDark),
                  const SizedBox(height: 4),
                  _buildCostLine('Delivery Instructions', 'Leave with building security', isDark, isItalic: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(String title, String modifier, String price, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                modifier,
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          price,
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCostLine(String label, String value, bool isDark, {bool isHighlight = false, bool isItalic = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        Text(
          value,
          style: AppTypography.labelSmall.copyWith(
            color: isHighlight ? AppColors.success : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// HELP & CANCEL / REPORT ROW
  /// ---------------------------------------------------------------------------
  Widget _buildSupportRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Order Help'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.share_location_rounded, size: 18),
            label: const Text('Share Link'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// CUSTOM VECTOR MAP PAINTER (Route, Road Grid, Pins & Moving Driver)
/// ============================================================================
class _MapRoutePainter extends CustomPainter {
  final double driverProgress;
  final double pulseValue;
  final OrderStatus status;
  final bool isDark;

  _MapRoutePainter({
    required this.driverProgress,
    required this.pulseValue,
    required this.status,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Map Background
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw Simulated Grid Roads
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final secondaryRoadPaint = Paint()
      ..color = isDark ? const Color(0xFF162033) : const Color(0xFFF1F5F9)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    // Cross roads
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7), roadPaint);
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), secondaryRoadPaint);
    canvas.drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.75, size.height), secondaryRoadPaint);

    // 3. Define Delivery Route Curve (from Restaurant to Customer)
    final startPoint = Offset(size.width * 0.15, size.height * 0.68);
    final controlPoint1 = Offset(size.width * 0.35, size.height * 0.22);
    final controlPoint2 = Offset(size.width * 0.65, size.height * 0.78);
    final endPoint = Offset(size.width * 0.85, size.height * 0.28);

    final routePath = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        endPoint.dx,
        endPoint.dy,
      );

    // Route Outer Shadow Glow
    final glowPaint = Paint()
      ..color = AppColors.prestoPrimary.withValues(alpha: 0.2)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, glowPaint);

    // Route Active Line
    final activeRoutePaint = Paint()
      ..color = AppColors.prestoPrimary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, activeRoutePaint);

    // 4. Restaurant Pin (Origin)
    _drawLocationPin(
      canvas: canvas,
      position: startPoint,
      icon: Icons.storefront_rounded,
      bgColor: AppColors.mataaNavy,
      iconColor: Colors.white,
      label: 'Smash Burger',
    );

    // 5. Customer Home Pin (Destination)
    _drawLocationPin(
      canvas: canvas,
      position: endPoint,
      icon: Icons.home_rounded,
      bgColor: AppColors.jetPrimary,
      iconColor: Colors.white,
      label: 'Home (You)',
    );

    // 6. Calculate Current Driver Position along Bezier Path
    final double t = status == OrderStatus.delivered
        ? 1.0
        : (status == OrderStatus.placed ? 0.05 : driverProgress);

    final driverPos = _calculateCubicBezier(startPoint, controlPoint1, controlPoint2, endPoint, t);

    // Radar Pulse around Driver
    final pulseRadius = 14 + (pulseValue * 22);
    final pulsePaint = Paint()
      ..color = AppColors.prestoPrimary.withValues(alpha: (1.0 - pulseValue) * 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(driverPos, pulseRadius, pulsePaint);

    // Driver Marker Capsule
    final driverShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(driverPos.translate(0, 3), 16, driverShadowPaint);

    final driverBgPaint = Paint()..color = Colors.white;
    canvas.drawCircle(driverPos, 16, driverBgPaint);

    final driverCorePaint = Paint()..color = AppColors.prestoPrimary;
    canvas.drawCircle(driverPos, 13, driverCorePaint);

    // Draw Motorbike Icon inside marker
    _drawIcon(canvas, Icons.delivery_dining_rounded, driverPos, 18, Colors.white);
  }

  Offset _calculateCubicBezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final double u = 1 - t;
    final double tt = t * t;
    final double uu = u * u;
    final double uuu = uu * u;
    final double ttt = tt * t;

    final double x = uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx;
    final double y = uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy;
    return Offset(x, y);
  }

  void _drawLocationPin({
    required Canvas canvas,
    required Offset position,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String label,
  }) {
    // Pin Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(position.translate(0, 2), 14, shadowPaint);

    // Pin Body
    final pinPaint = Paint()..color = bgColor;
    canvas.drawCircle(position, 14, pinPaint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(position, 14, borderPaint);

    // Icon
    _drawIcon(canvas, icon, position, 16, iconColor);
  }

  void _drawIcon(Canvas canvas, IconData icon, Offset offset, double size, Color color) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      offset.translate(-textPainter.width / 2, -textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MapRoutePainter oldDelegate) {
    return oldDelegate.driverProgress != driverProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.status != status ||
        oldDelegate.isDark != isDark;
  }
}

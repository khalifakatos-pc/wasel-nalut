import 'dart:async';
import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';

/// ============================================================================
/// HIGH-URGENCY ORDER RADAR DIALOG / BOTTOM SHEET
/// ============================================================================
/// Displays incoming dispatch orders with 15-second countdown timer,
/// real-time LYD earnings breakdown, distance metrics, and single-tap Accept/Decline.
/// ============================================================================

class OrderRadarDialog extends StatefulWidget {
  final RadarOrder order;
  final ValueChanged<RadarOrder> onAccept;
  final VoidCallback onDecline;

  const OrderRadarDialog({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onDecline,
  });

  /// Static helper to display radar dialog as a high-visibility modal sheet
  static Future<bool?> show(
    BuildContext context, {
    required RadarOrder order,
    required ValueChanged<RadarOrder> onAccept,
    required VoidCallback onDecline,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderRadarDialog(
        order: order,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  @override
  State<OrderRadarDialog> createState() => _OrderRadarDialogState();
}

class _OrderRadarDialogState extends State<OrderRadarDialog> with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.order.countdownSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handleDecline(autoExpired: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleAccept() {
    _timer?.cancel();
    Navigator.of(context).pop(true);
    widget.onAccept(widget.order);
  }

  void _handleDecline({bool autoExpired = false}) {
    _timer?.cancel();
    Navigator.of(context).pop(false);
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _remainingSeconds / widget.order.countdownSeconds;
    final isUrgent = _remainingSeconds <= 5;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = isUrgent ? (0.15 + (_pulseController.value * 0.20)) : 0.05;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? DriverColors.darkSurface : Colors.white,
            borderRadius: DriverRadius.topSheet,
            border: Border.all(
              color: isUrgent
                  ? DriverColors.urgentRed.withValues(alpha: 0.8)
                  : DriverColors.primary.withValues(alpha: 0.3),
              width: isUrgent ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isUrgent ? DriverColors.urgentRed : DriverColors.primary)
                    .withValues(alpha: glowAlpha),
                blurRadius: 30,
                spreadRadius: 6,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle & Urgency Header
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                        borderRadius: DriverRadius.radiusFull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header: Radar Title + Circular Countdown Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: DriverColors.primary.withValues(alpha: 0.15),
                              borderRadius: DriverRadius.radiusFull,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: DriverColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'INCOMING RADAR',
                                  style: DriverTypography.labelSmall.copyWith(
                                    color: DriverColors.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.order.orderNumber,
                            style: DriverTypography.titleSmall.copyWith(
                              color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Circular Countdown Timer Widget
                      _buildCircularTimer(progress, isUrgent),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payout Banner Card (Prominent LYD)
                  _buildPayoutHeroCard(isDark),
                  const SizedBox(height: 18),

                  // Route Metrics & Store -> Customer Itinerary
                  _buildRouteItinerary(isDark),
                  const SizedBox(height: 16),

                  // Order Items Quick Preview & Payment Method Pill
                  _buildOrderOverview(isDark),
                  const SizedBox(height: 22),

                  // Action Buttons: Huge Single-Tap Accept + Decline
                  _buildActionButtons(isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Circular 15s Countdown Ring
  Widget _buildCircularTimer(double progress, bool isUrgent) {
    final timerColor = isUrgent
        ? DriverColors.urgentRed
        : (_remainingSeconds <= 8 ? DriverColors.busyOrange : DriverColors.onlineGreen);

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.5,
            backgroundColor: timerColor.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
          ),
          Text(
            '${_remainingSeconds}s',
            style: DriverTypography.labelLarge.copyWith(
              color: timerColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  /// Hero Earnings Breakdown
  Widget _buildPayoutHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132A24), const Color(0xFF0F1E24)]
              : [const Color(0xFFECFDF5), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(
          color: DriverColors.onlineGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESTIMATED EARNINGS',
                style: DriverTypography.labelSmall.copyWith(
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.order.totalDriverPayoutLyd.toStringAsFixed(2),
                    style: DriverTypography.displayLarge.copyWith(
                      color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LYD',
                    style: DriverTypography.headlineMedium.copyWith(
                      color: DriverColors.onlineGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Surge & Bonus breakdown badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.order.surgeBonusLyd > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: DriverColors.surgeAmber.withValues(alpha: 0.2),
                    borderRadius: DriverRadius.radiusSm,
                    border: Border.all(color: DriverColors.surgeAmber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 13, color: DriverColors.surgeAmber),
                      const SizedBox(width: 3),
                      Text(
                        '+${widget.order.surgeBonusLyd.toStringAsFixed(2)} Surge',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.order.tipLyd > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '+${widget.order.tipLyd.toStringAsFixed(2)} LYD Tip Included',
                  style: DriverTypography.labelSmall.copyWith(
                    color: DriverColors.onlineGreen,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Store & Dropoff Itinerary
  Widget _buildRouteItinerary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkCard : const Color(0xFFF8FAFC),
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(
          color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Total distance banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.route_rounded, size: 16, color: DriverColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Trip Total: ${(widget.order.storeDistanceKm + widget.order.tripDistanceKm).toStringAsFixed(1)} km',
                    style: DriverTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '~${widget.order.storeEtaMinutes + widget.order.tripEtaMinutes} mins est.',
                style: DriverTypography.labelMedium.copyWith(
                  color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          // Pickup: Store
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: DriverColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PICKUP • ${widget.order.storeDistanceKm} km (${widget.order.storeEtaMinutes}m away)',
                          style: DriverTypography.labelSmall.copyWith(
                            color: DriverColors.secondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.order.storeName,
                      style: DriverTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      widget.order.storeAddress,
                      style: DriverTypography.bodySmall.copyWith(
                        color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropoff: Customer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: DriverColors.onlineGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DROPOFF • ${widget.order.tripDistanceKm} km (${widget.order.tripEtaMinutes}m trip)',
                      style: DriverTypography.labelSmall.copyWith(
                        color: DriverColors.onlineGreen,
                      ),
                    ),
                    Text(
                      widget.order.customerArea,
                      style: DriverTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      widget.order.customerAddress,
                      style: DriverTypography.bodySmall.copyWith(
                        color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Order Items & Payment Type Overview
  Widget _buildOrderOverview(bool isDark) {
    final isCod = widget.order.paymentType == PaymentType.cashOnDelivery;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Items Count
        Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 16, color: DriverColors.primary),
            const SizedBox(width: 6),
            Text(
              '${widget.order.items.length} items (${widget.order.items.map((i) => i.name).join(', ')})',
              style: DriverTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? DriverColors.darkTextSecondary : DriverColors.lightTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),

        // Payment Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isCod
                ? DriverColors.codWarning.withValues(alpha: 0.15)
                : DriverColors.sadadBlue.withValues(alpha: 0.15),
            borderRadius: DriverRadius.radiusSm,
            border: Border.all(
              color: isCod ? DriverColors.codWarning : DriverColors.sadadBlue,
              width: 1,
            ),
          ),
          child: Text(
            isCod ? 'COD: ${widget.order.codCollectAmountLyd.toStringAsFixed(1)} LYD' : 'Sadad Paid',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isCod ? DriverColors.codWarning : DriverColors.sadadBlue,
            ),
          ),
        ),
      ],
    );
  }

  /// Action Buttons (Accept / Decline)
  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        // Decline Button
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: () => _handleDecline(autoExpired: false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
            ),
            child: Text(
              'Decline',
              style: DriverTypography.labelLarge.copyWith(
                color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Accept Button (High Conversion)
        Expanded(
          flex: 4,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: DriverColors.acceptButtonGradient,
              borderRadius: DriverRadius.radiusLg,
              boxShadow: [
                BoxShadow(
                  color: DriverColors.onlineGreen.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: DriverRadius.radiusLg,
                onTap: _handleAccept,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'ACCEPT ORDER',
                        style: DriverTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

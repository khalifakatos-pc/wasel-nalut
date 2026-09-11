import 'dart:async';
import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';

/// ============================================================================
/// HIGH-URGENCY ORDER RADAR DIALOG (CAPTAIN WASEL - NALUT)
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
        _handleDecline();
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

  void _handleDecline() {
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
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
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.sensors_rounded, size: 16, color: DriverColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'طلب جديد وارد (نالوت)',
                                  style: TextStyle(
                                    color: DriverColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.order.orderNumber,
                            style: const TextStyle(
                              color: DriverColors.darkTextMuted,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      // Countdown Timer
                      _buildCircularTimer(progress, isUrgent),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payout Banner Card (Prominent LYD)
                  _buildPayoutHeroCard(isDark),
                  const SizedBox(height: 16),

                  // Route Itinerary
                  _buildRouteItinerary(isDark),
                  const SizedBox(height: 14),

                  // Action Buttons
                  _buildActionButtons(isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircularTimer(double progress, bool isUrgent) {
    final timerColor = isUrgent
        ? DriverColors.urgentRed
        : (_remainingSeconds <= 8 ? DriverColors.busyOrange : DriverColors.onlineGreen);

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4.0,
            backgroundColor: timerColor.withValues(alpha: 0.18),
            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
          ),
          Text(
            '$_remainingSecondsث',
            style: TextStyle(
              color: timerColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutHeroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A24) : const Color(0xFFECFDF5),
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
              const Text(
                'صافي أرباح الكابتن المقدرة',
                style: TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.order.totalDriverPayoutLyd.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'د.ل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: DriverColors.codWarning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DriverColors.codWarning.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Text('تحصيل كاش COD', style: TextStyle(fontSize: 10, color: Colors.white70)),
                Text(
                  '${widget.order.codCollectAmountLyd.toStringAsFixed(0)} د.ل',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DriverColors.codWarning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItinerary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkCardElevated : Colors.grey[100],
        borderRadius: DriverRadius.radiusMd,
      ),
      child: Column(
        children: [
          // Store Pickup
          Row(
            children: [
              const Icon(Icons.storefront_rounded, size: 20, color: DriverColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.storeName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${widget.order.storeAddress} • ${widget.order.storeDistanceKm} كم (${widget.order.storeEtaMinutes} د)',
                      style: const TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          // Customer Dropoff
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 20, color: DriverColors.onlineGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.order.customerAddress,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${widget.order.customerArea} • ${widget.order.tripDistanceKm} كم (${widget.order.tripEtaMinutes} د)',
                      style: const TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
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

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        // Decline button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _handleDecline,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white60,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
              ),
              child: const Text('تجاهل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Accept button
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _handleAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverColors.onlineGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                elevation: 4,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('قبول الطلب 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

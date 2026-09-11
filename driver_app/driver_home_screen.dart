import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'order_radar_dialog.dart';
import 'active_delivery_flow_screen.dart';
import 'driver_wallet_screen.dart';

/// ============================================================================
/// WASEL CAPTAIN / DRIVER HOME SCREEN
/// ============================================================================
/// Features:
/// 1. Online / Offline status switch with pulse glow animation and shift timer.
/// 2. Daily Earnings Overview Card (Net earnings LYD, Total trips, Cash in hand COD).
/// 3. Active Libyan Zone Heat Status (Tripoli / Benghazi demand & surge multipliers).
/// 4. Active Delivery Mini-Tracker Bar & Incoming Order Radar Simulation Trigger.
/// ============================================================================

class DriverHomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final Function(ActiveDeliveryOrder) onStartDelivery;

  const DriverHomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.onStartDelivery,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  DriverOnlineStatus _onlineStatus = DriverOnlineStatus.onlineIdle;
  late AnimationController _pulseController;
  late DriverStats _stats;
  ActiveDeliveryOrder? _currentActiveOrder;
  bool _autoAcceptOrders = false;

  @override
  void initState() {
    super.initState();
    _stats = DriverMockData.initialStats;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleOnlineStatus() {
    setState(() {
      _onlineStatus = _onlineStatus == DriverOnlineStatus.offline
          ? DriverOnlineStatus.onlineIdle
          : DriverOnlineStatus.offline;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _onlineStatus == DriverOnlineStatus.onlineIdle
              ? '🟢 You are now ONLINE — Receiving Tripoli/Benghazi radar dispatches!'
              : '⚪ You are now OFFLINE — Shift paused.',
        ),
        backgroundColor: _onlineStatus == DriverOnlineStatus.onlineIdle
            ? DriverColors.onlineGreen
            : DriverColors.offlineGrey,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _triggerSampleRadarOrder() {
    if (_onlineStatus == DriverOnlineStatus.offline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please switch to ONLINE mode before testing order radar!'),
          backgroundColor: DriverColors.urgentRed,
        ),
      );
      return;
    }

    final sampleRadar = DriverMockData.getSampleIncomingOrder();
    OrderRadarDialog.show(
      context,
      order: sampleRadar,
      onAccept: (order) {
        final active = DriverMockData.getSampleActiveDelivery();
        setState(() {
          _currentActiveOrder = active;
          _onlineStatus = DriverOnlineStatus.busyDelivery;
        });
        widget.onStartDelivery(active);
      },
      onDecline: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order declined. Radar continuing scan...'),
            backgroundColor: DriverColors.darkCard,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = _onlineStatus != DriverOnlineStatus.offline;

    return Scaffold(
      backgroundColor: isDark ? DriverColors.darkBg : DriverColors.lightBg,
      appBar: AppBar(
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DriverColors.primaryGradient,
                  ),
                  child: const Center(
                    child: Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? DriverColors.onlineGreen : DriverColors.offlineGrey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? DriverColors.darkSurface : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Captain Mahmoud',
                  style: DriverTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                  ),
                ),
                Text(
                  'Honda PCX 160 • 5-29418 🇱🇾',
                  style: DriverTypography.bodySmall.copyWith(
                    color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Theme Switcher Button
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Online / Offline Interactive Status Bar
            _buildOnlineToggleCard(isDark, isOnline),
            const SizedBox(height: 16),

            // 2. Active Delivery Sticky Mini-Banner (if active)
            if (_currentActiveOrder != null) ...[
              _buildActiveDeliveryBanner(isDark),
              const SizedBox(height: 16),
            ],

            // 3. Daily Earnings Overview Card
            _buildDailyEarningsCard(isDark),
            const SizedBox(height: 20),

            // 4. Radar Dispatch Simulator Trigger
            _buildRadarSimulationTrigger(isDark, isOnline),
            const SizedBox(height: 24),

            // 5. Active Zone Heat Status Section
            _buildZoneHeatSection(isDark),
          ],
        ),
      ),
    );
  }

  /// 1. Online/Offline Status Header Card
  Widget _buildOnlineToggleCard(bool isDark, bool isOnline) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = isOnline ? (0.12 + (_pulseController.value * 0.18)) : 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? DriverColors.darkCard : Colors.white,
            borderRadius: DriverRadius.radiusXl,
            border: Border.all(
              color: isOnline ? DriverColors.onlineGreen : (isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
              width: isOnline ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: DriverColors.onlineGreen.withValues(alpha: glowAlpha),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? DriverColors.onlineGreen : DriverColors.offlineGrey,
                          shape: BoxShape.circle,
                          boxShadow: isOnline
                              ? [
                                  BoxShadow(
                                    color: DriverColors.onlineGreen.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOnline ? 'ONLINE & READY' : 'OFFLINE',
                            style: DriverTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isOnline
                                  ? DriverColors.onlineGreen
                                  : (isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary),
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            isOnline ? 'Shift Time: 3h 56m • Tripoli Zone' : 'Tap switch to go online',
                            style: DriverTypography.bodySmall.copyWith(
                              color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Switch
                  Switch(
                    value: isOnline,
                    activeColor: DriverColors.onlineGreen,
                    activeTrackColor: DriverColors.onlineGreen.withValues(alpha: 0.3),
                    inactiveThumbColor: DriverColors.offlineGrey,
                    onChanged: (_) => _toggleOnlineStatus(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Auto-Accept & Quick Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: DriverColors.surgeAmber),
                      const SizedBox(width: 4),
                      Text(
                        '${_stats.rating} (${_stats.totalReviews})',
                        style: DriverTypography.labelSmall.copyWith(
                          color: isDark ? Colors.white70 : DriverColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.verified_outlined, size: 14, color: DriverColors.onlineGreen),
                      const SizedBox(width: 4),
                      Text(
                        '${(_stats.acceptanceRate * 100).toInt()}% Accept',
                        style: DriverTypography.labelSmall.copyWith(
                          color: isDark ? Colors.white70 : DriverColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Auto-Accept',
                        style: DriverTypography.bodySmall.copyWith(
                          color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: _autoAcceptOrders,
                          activeColor: DriverColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _autoAcceptOrders = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 2. Active Delivery Sticky Mini-Banner
  Widget _buildActiveDeliveryBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: DriverColors.primaryGradient,
        borderRadius: DriverRadius.radiusLg,
        boxShadow: [
          BoxShadow(
            color: DriverColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Delivery ${_currentActiveOrder!.orderNumber}',
                    style: DriverTypography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'To: ${_currentActiveOrder!.customerName}',
                    style: DriverTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () => widget.onStartDelivery(_currentActiveOrder!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: DriverColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusFull),
            ),
            child: const Text('Resume >', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  /// 3. Daily Earnings Overview Card
  Widget _buildDailyEarningsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkCard : Colors.white,
        borderRadius: DriverRadius.radiusXl,
        border: Border.all(
          color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Performance',
                style: DriverTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                  borderRadius: DriverRadius.radiusSm,
                ),
                child: Text(
                  '+18% vs Yesterday',
                  style: DriverTypography.labelSmall.copyWith(color: DriverColors.onlineGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Column Metrics Grid
          Row(
            children: [
              // Net Earnings
              Expanded(
                child: _buildMetricItem(
                  title: 'NET EARNINGS',
                  value: DriverTheme.formatLyd(_stats.netEarningsTodayLyd),
                  color: DriverColors.onlineGreen,
                  icon: Icons.savings_outlined,
                  isDark: isDark,
                ),
              ),
              Container(width: 1, height: 45, color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),

              // Total Trips
              Expanded(
                child: _buildMetricItem(
                  title: 'TOTAL TRIPS',
                  value: '${_stats.completedTripsToday} Trips',
                  color: DriverColors.primary,
                  icon: Icons.moped_rounded,
                  isDark: isDark,
                ),
              ),
              Container(width: 1, height: 45, color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),

              // Cash in Hand (COD)
              Expanded(
                child: _buildMetricItem(
                  title: 'COD HELD',
                  value: DriverTheme.formatLyd(_stats.cashInHandCodLyd),
                  color: DriverColors.codWarning,
                  icon: Icons.payments_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Quick Action to open Wallet
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DriverWalletScreen()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 18, color: DriverColors.sadadBlue),
                    const SizedBox(width: 8),
                    Text(
                      'View Wallet Ledger & Settle COD',
                      style: DriverTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DriverColors.sadadBlue,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: DriverColors.sadadBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: DriverTypography.labelSmall.copyWith(
                  color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: DriverTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : DriverColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Radar Dispatch Simulator Trigger
  Widget _buildRadarSimulationTrigger(bool isDark, bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkCardElevated : const Color(0xFFEFF6FF),
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(
          color: DriverColors.accentCyan.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DriverColors.accentCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar_rounded, color: DriverColors.accentCyan, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Radar Scanner',
                    style: DriverTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    isOnline ? 'Scanning for nearby orders in 5 km...' : 'Driver is currently offline',
                    style: DriverTypography.bodySmall.copyWith(
                      color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: isOnline ? _triggerSampleRadarOrder : null,
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: const Text('Simulate Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DriverColors.accentCyan,
              foregroundColor: Colors.black87,
              shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusFull),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Active Libyan Zone Heat Status Section
  Widget _buildZoneHeatSection(bool isDark) {
    final zones = DriverMockData.libyanZones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: DriverColors.secondary, size: 22),
                const SizedBox(width: 6),
                Text(
                  'Live Delivery Zones & Surge',
                  style: DriverTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            Text(
              'Tripoli / Benghazi',
              style: DriverTypography.bodySmall.copyWith(
                color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: zones.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final zone = zones[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? DriverColors.darkCard : Colors.white,
                borderRadius: DriverRadius.radiusLg,
                border: Border.all(
                  color: zone.isHotspot
                      ? DriverColors.surgeAmber.withValues(alpha: 0.4)
                      : (isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            zone.name,
                            style: DriverTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                            ),
                          ),
                          if (zone.isHotspot) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DriverColors.surgeAmber.withValues(alpha: 0.2),
                                borderRadius: DriverRadius.radiusXs,
                              ),
                              child: Text(
                                '${zone.surgeMultiplier}x SURGE',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${zone.city} • Wait: ${zone.estimatedWaitTime} • Demand: ${zone.demandLevel}',
                        style: DriverTypography.bodySmall.copyWith(
                          color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${DriverTheme.formatLyd(zone.bonusLyd)}',
                        style: DriverTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          color: DriverColors.onlineGreen,
                        ),
                      ),
                      Text(
                        'Bonus / Order',
                        style: DriverTypography.labelSmall.copyWith(
                          color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

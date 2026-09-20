import 'dart:async';
import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'order_radar_dialog.dart';
import 'driver_wallet_screen.dart';
import 'services/driver_supabase_service.dart';
import 'services/driver_notification_service.dart';

/// ============================================================================
/// CAPTAIN WASEL (كابتن واصل) DRIVER HOME SCREEN - NALUT
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
  Timer? _radarTimer;
  Timer? _telemetryTimer;
  double _currentLat = 31.8686;
  double _currentLng = 10.9818;
  int _telemetryPingCount = 0;
  bool _isRadarShowing = false;
  final Set<String> _dismissedOrderIds = {};
  final Set<String> _notifiedOrderIds = {};
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _systemConfig = {
    'captain_bonus_enabled': true,
    'captain_daily_target': 8,
    'captain_daily_bonus_lyd': 15.0,
  };

  @override
  void initState() {
    super.initState();
    _stats = DriverMockData.initialStats;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadLiveProfile();

    // Start periodic GPS telemetry stream for Nalut fleet dispatch
    _startTelemetryStream();

    // Periodic live order polling from Supabase Cloud (every 4 seconds)
    _radarTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkIncomingOrders();
    });
  }

  void _startTelemetryStream() {
    _telemetryTimer?.cancel();
    if (_onlineStatus == DriverOnlineStatus.offline) return;

    // Immediate initial presence heartbeat to backend
    DriverSupabaseService.sendHeartbeat(
      latitude: _currentLat,
      longitude: _currentLng,
      heading: 45.0,
      speedKmh: 38.0,
    );

    _telemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_onlineStatus == DriverOnlineStatus.offline || !mounted) return;
      _telemetryPingCount++;
      // Simulate minor vehicle GPS movement along Nalut main thoroughfare
      final latOffset = ((_telemetryPingCount % 10) - 5) * 0.00012;
      final lngOffset = ((_telemetryPingCount % 8) - 4) * 0.00015;
      _currentLat = 31.8686 + latOffset;
      _currentLng = 10.9818 + lngOffset;

      DriverSupabaseService.broadcastTelemetry(
        latitude: _currentLat,
        longitude: _currentLng,
        heading: 45.0,
        speedKmh: 38.0,
      );

      // Refresh presence heartbeat every 12 seconds
      if (_telemetryPingCount % 3 == 0) {
        DriverSupabaseService.sendHeartbeat(
          latitude: _currentLat,
          longitude: _currentLng,
          heading: 45.0,
          speedKmh: 38.0,
        );
      }

      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _radarTimer?.cancel();
    _telemetryTimer?.cancel();
    _pulseController.dispose();
    // Auto-set driver to offline when captain exits app
    DriverSupabaseService.updateStatus('offline');
    super.dispose();
  }

  Future<void> _loadLiveProfile() async {
    try {
      final p = await DriverSupabaseService.fetchDriverProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          if (_profile['full_name'] == null || _profile['full_name'] == 'كابتن واصل') {
            _profile['full_name'] = DriverSupabaseService.activeDriverName;
          }
          if (_profile['phone'] == null || (_profile['phone'] as String).isEmpty) {
            _profile['phone'] = DriverSupabaseService.activeDriverPhone;
          }
          if (_profile['vehicle_type'] == null || _profile['vehicle_type'] == 'سيارة') {
            _profile['vehicle_type'] = DriverSupabaseService.activeDriverVehicle;
          }
          if (_profile['plate_number'] == null || _profile['plate_number'] == 'نالوت') {
            _profile['plate_number'] = DriverSupabaseService.activeDriverPlate;
          }

          final double balance = (p['wallet_balance_lyd'] is num)
              ? (p['wallet_balance_lyd'] as num).toDouble()
              : 0.0;
          final int trips = (p['total_trips'] is int) ? (p['total_trips'] as int) : 0;
          final double rating = (p['rating'] is num) ? (p['rating'] as num).toDouble() : 5.0;
          _stats = DriverStats(
            netEarningsTodayLyd: trips * 6.5,
            netEarningsYesterdayLyd: 0.0,
            completedTripsToday: trips,
            cashInHandCodLyd: balance,
            rating: rating,
            totalReviews: trips,
            acceptanceRate: 1.0,
            onTimeRate: 1.0,
            onlineDurationSeconds: 0,
          );
        });
      }

      final cfg = await DriverSupabaseService.fetchSystemConfigurations();
      if (mounted) {
        setState(() {
          _systemConfig = cfg;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkIncomingOrders() async {
    if (!mounted || _onlineStatus != DriverOnlineStatus.onlineIdle || _isRadarShowing) return;

    try {
      final orders = await DriverSupabaseService.fetchAvailableOrders();
      if (!mounted || _onlineStatus != DriverOnlineStatus.onlineIdle || _isRadarShowing) return;

      for (final ord in orders) {
        final orderId = ord['id']?.toString() ?? '';
        final status = ord['status']?.toString() ?? '';
        final driverId = ord['driver_id']?.toString();

        if ((status == 'ready_for_pickup' || status == 'preparing') &&
            (driverId == null ||
             driverId.isEmpty ||
             driverId == 'null' ||
             driverId == DriverSupabaseService.activeDriverId) &&
            !_dismissedOrderIds.contains(orderId)) {
          if (!_notifiedOrderIds.contains(orderId)) {
            _notifiedOrderIds.add(orderId);
            final double ordAmount = (ord['total_amount_lyd'] is num)
                ? (ord['total_amount_lyd'] as num).toDouble()
                : ((ord['total_amount'] is num) ? (ord['total_amount'] as num).toDouble() : 0.0);
            final isPrep = status == 'preparing';
            final prepMinutes = ord['prep_time_minutes'] ?? 15;
            DriverNotificationService().showOrderAlert(
              title: isPrep ? '⏳ مشوار جديد قيد التحضير - كابتن واصل' : '🚨 مشوار جاهز للاستلام - كابتن واصل',
              body: isPrep
                  ? 'طلب ${ord['order_number'] ?? ''} من ${ord['store_name'] ?? 'المطعم'} قيد الطهي (يجهز بعد $prepMinutes دقيقة) - تحرّك للاستلام.'
                  : 'طلب ${ord['order_number'] ?? ''} بقيمة ${ordAmount.toStringAsFixed(2)} د.ل من ${ord['store_name'] ?? 'مطاعم نالوت'} جاهز للاستلام والتوصيل.',
              payload: orderId,
            );
          }
          _showRadarForOrder(ord);
          break;
        }
      }
    } catch (_) {}
  }

  void _showRadarForOrder(Map<String, dynamic> ord) {
    if (_isRadarShowing || !mounted) return;
    _isRadarShowing = true;

    final orderId = ord['id']?.toString() ?? '';
    final orderNumber = ord['order_number']?.toString() ?? '#W-100';
    final storeName = ord['store_name']?.toString() ?? 'قصر نالوت للمأكولات';
    final customerAddress = ord['delivery_address']?.toString() ?? 'نالوت - وسط المدينة';
    final double totalAmount = (ord['total_amount_lyd'] is num)
        ? (ord['total_amount_lyd'] as num).toDouble()
        : ((ord['total_amount'] is num) ? (ord['total_amount'] as num).toDouble() : 35.0);
    final String paymentMethod = ord['payment_method']?.toString() ?? 'cash';
    final String otp = (ord['otp_code'] != null && ord['otp_code'].toString().isNotEmpty)
        ? ord['otp_code'].toString()
        : ((ord['delivery_pin'] != null && ord['delivery_pin'].toString().isNotEmpty)
            ? ord['delivery_pin'].toString()
            : '1234');
    final bool isCod = paymentMethod == 'cash' || paymentMethod == 'cod';
    final String status = ord['status']?.toString() ?? 'ready_for_pickup';
    final prepMinutes = ord['prep_time_minutes'] ?? 15;
    final String prepStatusBadge = ord['prep_status_badge']?.toString() ??
        (status == 'preparing'
            ? '⏳ جاري التحضير بالمطعم (يجهز بعد $prepMinutes دقيقة) - تحرّك للاستلام'
            : '🟢 جاهز للاستلام والتسليم فوراً');

    final radarOrder = RadarOrder(
      orderId: orderId,
      orderNumber: orderNumber,
      storeName: storeName,
      storeCategory: 'مطاعم نالوت',
      storeAddress: 'نالوت - الشارع العام',
      storeDistanceKm: 1.2,
      storeEtaMinutes: 5,
      customerAddress: customerAddress,
      customerArea: 'نالوت',
      tripDistanceKm: 2.8,
      tripEtaMinutes: 12,
      basePayoutLyd: 6.0,
      surgeBonusLyd: 1.5,
      tipLyd: 0.0,
      paymentType: isCod ? PaymentType.cashOnDelivery : PaymentType.prepaidSadad,
      codCollectAmountLyd: totalAmount,
      countdownSeconds: 15,
      status: status,
      prepStatusBadge: prepStatusBadge,
      items: [
        DeliveryItem(
          name: 'طلب وجبة / مشتريات من نالوت',
          quantity: 1,
          options: 'طلب نشط عبر واصل',
          unitPriceLyd: totalAmount,
        ),
      ],
    );

    OrderRadarDialog.show(
      context,
      order: radarOrder,
      onAccept: (order) async {
        _isRadarShowing = false;
        if (mounted) {
          setState(() {
            _onlineStatus = DriverOnlineStatus.busyDelivery;
          });
        }

        try {
          await DriverSupabaseService.updateStatus('busy');
          await DriverSupabaseService.updateOrderStatus(
            orderId: orderId,
            status: status == 'placed' ? 'preparing' : status,
            driverId: DriverSupabaseService.activeDriverId,
          );
        } catch (_) {}

        final active = ActiveDeliveryOrder(
          orderId: orderId,
          orderNumber: orderNumber,
          storeName: storeName,
          storePhone: '091-2233445',
          storeAddress: 'نالوت - الشارع الرئيسي بجوار القلعة',
          storeLatitude: 31.8680,
          storeLongitude: 10.9850,
          customerName: ord['customer_name']?.toString() ?? 'زبون نالوت',
          customerPhone: '091-7788990',
          customerAddress: customerAddress,
          customerNotes: ord['notes']?.toString() ?? 'الدق على الباب الخارجي',
          customerLatitude: 31.8620,
          customerLongitude: 10.9780,
          paymentType: isCod ? PaymentType.cashOnDelivery : PaymentType.prepaidSadad,
          codAmountLyd: totalAmount,
          customerOtpPin: otp,
          driverPayoutLyd: 7.5,
          items: [
            DeliveryItem(
              name: 'طلب وجبة / مشتريات نالوت',
              quantity: 1,
              options: 'طلب مؤكد',
              unitPriceLyd: totalAmount,
            ),
          ],
        );

        widget.onStartDelivery(active);
      },
      onDecline: () {
        _isRadarShowing = false;
        _dismissedOrderIds.add(orderId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفويت الطلب والبحث عن أقرب كابتن آخر في نالوت.'),
            backgroundColor: DriverColors.darkCard,
          ),
        );
      },
    );
  }

  void _toggleOnlineStatus() {
    setState(() {
      _onlineStatus = _onlineStatus == DriverOnlineStatus.offline
          ? DriverOnlineStatus.onlineIdle
          : DriverOnlineStatus.offline;
    });

    DriverSupabaseService.updateStatus(
      _onlineStatus == DriverOnlineStatus.onlineIdle ? 'available' : 'offline',
    );

    if (_onlineStatus == DriverOnlineStatus.onlineIdle) {
      DriverSupabaseService.sendHeartbeat(
        latitude: _currentLat,
        longitude: _currentLng,
        heading: 45.0,
        speedKmh: 38.0,
      );
      _startTelemetryStream();
      _checkIncomingOrders();
    } else {
      _telemetryTimer?.cancel();
      DriverSupabaseService.updateStatus('offline');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _onlineStatus == DriverOnlineStatus.onlineIdle
              ? '🟢 أنت الآن متصل ومتاح لاستقبال طلبات نالوت والجبل!'
              : '⚪ تم إيقاف استقبال الطلبات (وضع الاستراحة).',
        ),
        backgroundColor: _onlineStatus == DriverOnlineStatus.onlineIdle
            ? DriverColors.onlineGreen
            : DriverColors.offlineGrey,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _onlineStatus != DriverOnlineStatus.offline;

    return Scaffold(
      backgroundColor: DriverColors.darkBg,
      appBar: AppBar(
        title: const Text('كابتن واصل 🛵 (نالوت)'),
        centerTitle: true,
        backgroundColor: DriverColors.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverWalletScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Driver Profile & Vehicle Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DriverColors.darkCard,
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(color: DriverColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: DriverColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: DriverColors.primary, width: 2),
                  ),
                  child: const Center(
                    child: Text('و', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: DriverColors.primary)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_profile['full_name'] ?? 'كابتن واصل'} ⭐ ${(_profile['rating'] ?? 5.0).toString()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_profile['vehicle_type'] ?? 'سيارة'} • ${_profile['plate_number'] ?? 'نالوت'}',
                        style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('VIP الذهبي', style: TextStyle(color: DriverColors.onlineGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Online / Offline Switch Big Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isOnline ? DriverColors.darkCardElevated : DriverColors.darkCard,
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(
                color: isOnline ? DriverColors.onlineGreen : DriverColors.darkBorder,
                width: isOnline ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isOnline ? DriverColors.onlineGreen : DriverColors.offlineGrey,
                        shape: BoxShape.circle,
                        boxShadow: isOnline
                            ? [
                                BoxShadow(
                                  color: DriverColors.onlineGreen.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? 'أنت متصل بالرادار 🟢' : 'غير متصل (استراحة) ⚪',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          isOnline ? 'مستعد لاستقبال طلبات نالوت وجبل نفوسة' : 'اضغط للاتصال وبدء العمل',
                          style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: isOnline,
                  activeThumbColor: DriverColors.onlineGreen,
                  onChanged: (val) => _toggleOnlineStatus(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2.1 Live GPS Telemetry Status Indicator
          if (isOnline) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: DriverColors.darkCard,
                borderRadius: DriverRadius.radiusMd,
                border: Border.all(color: DriverColors.onlineGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: DriverColors.onlineGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: DriverColors.onlineGreen.withValues(alpha: 0.8),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'بث التتبع المباشر (GPS Telemetry) نشط 📡',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DriverColors.onlineGreen),
                        ),
                        Text(
                          'نالوت ${_currentLat.toStringAsFixed(4)}° N, ${_currentLng.toStringAsFixed(4)}° E • سرعة 38 كم/س (تحديث كل 4 ثوانٍ)',
                          style: const TextStyle(fontSize: 10.5, color: DriverColors.darkTextMuted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#$_telemetryPingCount نبضة',
                      style: const TextStyle(fontSize: 10, color: DriverColors.onlineGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2.2 COD Debt Warning Threshold Banner (> 500 LYD)
          if (_stats.isCodLimitExceeded || _stats.isCodLimitApproaching) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _stats.isCodLimitExceeded
                    ? DriverColors.urgentRed.withValues(alpha: 0.15)
                    : DriverColors.codWarning.withValues(alpha: 0.15),
                borderRadius: DriverRadius.radiusLg,
                border: Border.all(
                  color: _stats.isCodLimitExceeded ? DriverColors.urgentRed : DriverColors.codWarning,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _stats.isCodLimitExceeded ? Icons.error_rounded : Icons.warning_amber_rounded,
                        color: _stats.isCodLimitExceeded ? DriverColors.urgentRed : DriverColors.codWarning,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _stats.isCodLimitExceeded
                              ? '⚠️ تحذير عاجل: تجاوز سقف العهدة النقدية (500 د.ل)!'
                              : '⚡ اقتراب حد العهدة النقدية المسموح به (500 د.ل)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _stats.isCodLimitExceeded ? DriverColors.urgentRed : DriverColors.codWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stats.isCodLimitExceeded
                        ? 'كاش العهدة بيدك بلغ ${_stats.cashInHandCodLyd.toStringAsFixed(2)} د.ل (الحد الأقصى: 500.00 د.ل). يرجى التوريد فوراً عبر سداد لتفادي تعليق استقبال الطلبات.'
                        : 'كاش العهدة بيدك ${_stats.cashInHandCodLyd.toStringAsFixed(2)} د.ل من أصل 500.00 د.ل. ننصح بالتوريد قريباً.',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                      label: const Text('تسوية وتوريد الكاش الآن 💵', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _stats.isCodLimitExceeded ? DriverColors.urgentRed : DriverColors.codWarning,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DriverWalletScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2.5 Daily Mission & Bonus Progress Card (تحدي وبونص الكابتن)
          if (_systemConfig['captain_bonus_enabled'] == true) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0D324D),
                    DriverColors.darkCard,
                  ],
                ),
                borderRadius: DriverRadius.radiusLg,
                border: Border.all(color: DriverColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.emoji_events_outlined, color: DriverColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'تحدي اليوم (بونص إضافي 🏆)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: DriverColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: DriverColors.primary),
                        ),
                        child: Text(
                          '+${_systemConfig['captain_daily_bonus_lyd'] ?? 15.0} د.ل',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: DriverColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final int target = (_systemConfig['captain_daily_target'] is int)
                          ? _systemConfig['captain_daily_target'] as int
                          : 8;
                      final int completed = _stats.completedTripsToday;
                      final double progress = (completed / (target > 0 ? target : 1)).clamp(0.0, 1.0);
                      final bool isDone = completed >= target;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDone ? '🎉 تم إنجاز المستهدف بالكامل!' : 'أنجزت $completed من أصل $target مشاوير اليوم',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDone ? DriverColors.onlineGreen : Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DriverColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDone ? DriverColors.onlineGreen : DriverColors.primary,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isDone
                                ? 'تم إضافة ${_systemConfig['captain_daily_bonus_lyd'] ?? 15.0} د.ل إلى محفظتك كمكافأة تشجيعية!'
                                : 'متبقي ${target - completed > 0 ? target - completed : 0} مشاوير للحصول على البونص النقدي.',
                            style: const TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(color: DriverColors.darkBorder, height: 16),
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: DriverColors.onlineGreen, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تذكير أمانة وسلامة: التأني في المنحدرات الجبلية بنالوت.. رزقك مكتوب وسلامتك أولاً.',
                          style: TextStyle(fontSize: 10.5, color: DriverColors.darkTextMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Today's Performance & Earnings Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DriverColors.darkCard,
                    borderRadius: DriverRadius.radiusMd,
                    border: Border.all(color: DriverColors.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أرباح اليوم الصافية', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        '${_stats.netEarningsTodayLyd.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DriverColors.onlineGreen, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DriverColors.darkCard,
                    borderRadius: DriverRadius.radiusMd,
                    border: Border.all(color: DriverColors.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الرحلات المكتملة', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        '${_stats.completedTripsToday} رحلة',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 4. Test Radar Trigger Button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.radar_rounded, size: 22),
              label: const Text('فحص وصول طلبات نالوت الجديدة ⚡', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                elevation: 4,
              ),
              onPressed: () {
                if (_onlineStatus == DriverOnlineStatus.offline) {
                  _toggleOnlineStatus();
                }
                _checkIncomingOrders();
              },
            ),
          ),

          const SizedBox(height: 24),

          // 5. Active Commercial Hotspots in Nalut
          const Text('مناطق ومتاجر الطلب النشط في نالوت والجبل 🔥', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),

          ...[
            const DeliveryZoneHeat(
              id: 'zone_alhanaa',
              name: 'جزيرة مصرف الجمهورية (صيدلية الهناء)',
              city: 'نالوت',
              surgeMultiplier: 1.5,
              demandLevel: 'مرتفع جداً 🔥',
              estimatedWaitTime: '< دقيقتين',
              bonusLyd: 3.50,
              isHotspot: true,
            ),
            const DeliveryZoneHeat(
              id: 'zone_ranchello',
              name: 'شارع أفريقيا (مطعم ومقهى رانشيلو)',
              city: 'نالوت',
              surgeMultiplier: 1.4,
              demandLevel: 'طلب عالي',
              estimatedWaitTime: '2-3 دقائق',
              bonusLyd: 3.00,
              isHotspot: true,
            ),
            const DeliveryZoneHeat(
              id: 'zone_qasr',
              name: 'حي الشهداء والقلعة (قصر نالوت للمشويات)',
              city: 'نالوت',
              surgeMultiplier: 1.3,
              demandLevel: 'متوسط',
              estimatedWaitTime: '3-5 دقائق',
              bonusLyd: 2.50,
              isHotspot: false,
            ),
            const DeliveryZoneHeat(
              id: 'zone_akakus',
              name: 'شارع تونس وطريق وازن (بيتزا أكاكوس)',
              city: 'نالوت',
              surgeMultiplier: 1.2,
              demandLevel: 'متوسط',
              estimatedWaitTime: '4 دقائق',
              bonusLyd: 2.00,
              isHotspot: false,
            ),
          ].map((zone) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DriverColors.darkCard,
                borderRadius: DriverRadius.radiusMd,
                border: Border.all(color: DriverColors.darkBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: DriverColors.secondary, size: 24),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          Text('معدل الانتظار: ${zone.estimatedWaitTime}', style: const TextStyle(fontSize: 11, color: DriverColors.darkTextMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DriverColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'مكافأة +${zone.bonusLyd.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(color: DriverColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

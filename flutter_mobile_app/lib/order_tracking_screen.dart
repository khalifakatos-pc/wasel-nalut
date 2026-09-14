import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'design_system.dart';
import 'services/api_service.dart';
import 'services/customer_notification_service.dart';
import 'fair_rating_dialog.dart';

/// ============================================================================
/// WASEL REAL-TIME ORDER TRACKING SCREEN (شاشة تتبع الطلب الحية - نالوت)
/// ============================================================================
enum OrderStatus {
  placed,
  preparing,
  onTheWay,
  delivered,
}

class OrderTrackingScreen extends StatefulWidget {
  final String? orderId;
  final String? orderNumber;

  const OrderTrackingScreen({
    super.key,
    this.orderId,
    this.orderNumber,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  OrderStatus _currentStatus = OrderStatus.placed;
  OrderStatus? _lastNotifiedTrackingStatus;
  Timer? _pollingTimer;
  final MapController _mapController = MapController();
  bool _isSatelliteMap = true;

  // Order Details from Supabase
  String _orderNum = 'WAS-9831';
  String _storeName = 'مطعم قصر نالوت للمشويات';
  String _deliveryOtp = '4821';
  String _deliveryAddress = 'نالوت - حي القلعة';
  double _totalAmount = 42.00;
  int _etaMinutes = 25;

  // GPS Coordinates (Default: Nalut center & Fortress)
  final double _storeLat = 31.8687;
  final double _storeLng = 10.9818;
  double _customerLat = 31.8695;
  double _customerLng = 10.9835;
  double _driverLat = 31.8680;
  double _driverLng = 10.9820;

  // Driver Details
  String _driverName = 'كابتن طارق النالوتي';
  String _driverPhone = '0915544332';
  String _driverVehicle = 'سيارة تويوتا يارس';
  String _driverPlate = '14-88492';
  double _driverRating = 4.9;

  @override
  void initState() {
    super.initState();
    if (widget.orderNumber != null) {
      _orderNum = widget.orderNumber!;
    }
    _fetchLiveTrackingData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLiveTrackingData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveTrackingData() async {
    try {
      final orderId = widget.orderId;
      Map<String, dynamic>? order;

      // 1. Try Live Unified Backend Server First (24/7 Cloud or Local)
      try {
        final uri = orderId != null
            ? Uri.parse('${ApiService.baseUrl}/orders/$orderId')
            : Uri.parse('${ApiService.baseUrl}/orders?status=placed,preparing,ready_for_pickup,out_for_delivery,delivered');

        final res = await http.get(uri).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['success'] == true) {
            if (data['data'] is Map) {
              order = Map<String, dynamic>.from(data['data']);
            } else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
              order = Map<String, dynamic>.from((data['data'] as List).first);
            }
          }
        }
      } catch (_) {
        // Fallback to Supabase
      }

      // 2. Fallback to Supabase Cloud if unified backend is unreachable
      if (order == null) {
        try {
          final uri = orderId != null
              ? Uri.parse('${ApiService.supabaseUrl}/orders?id=eq.$orderId&select=*')
              : Uri.parse('${ApiService.supabaseUrl}/orders?status=in.(placed,preparing,ready_for_pickup,out_for_delivery)&order=created_at.desc&limit=1');

          final res = await http.get(
            uri,
            headers: {
              'apikey': ApiService.supabaseApiKey,
              'Authorization': 'Bearer ${ApiService.supabaseApiKey}',
            },
          ).timeout(const Duration(seconds: 2));

          if (res.statusCode == 200) {
            final List<dynamic> list = jsonDecode(res.body);
            if (list.isNotEmpty) {
              order = Map<String, dynamic>.from(list.first);
            }
          }
        } catch (_) {}
      }

      if (order != null && mounted) {
        final liveOrder = order;
        final statusStr = liveOrder['status'] ?? 'placed';

        setState(() {
          _orderNum = liveOrder['order_number'] ?? _orderNum;
          _storeName = (liveOrder['store'] is Map ? liveOrder['store']['name'] : null) ?? liveOrder['store_name'] ?? _storeName;
          _deliveryOtp = liveOrder['otp_code'] ?? _deliveryOtp;
          _totalAmount = (liveOrder['total_amount_lyd'] as num?)?.toDouble() ??
              (liveOrder['total_amount'] as num?)?.toDouble() ??
              _totalAmount;
          _deliveryAddress = liveOrder['delivery_address'] ?? _deliveryAddress;

          if (liveOrder['delivery_latitude'] != null) {
            _customerLat = (liveOrder['delivery_latitude'] as num).toDouble();
          }
          if (liveOrder['delivery_longitude'] != null) {
            _customerLng = (liveOrder['delivery_longitude'] as num).toDouble();
          }

          // Embedded driver telemetry from live backend
          if (liveOrder['driver'] is Map) {
            final drv = Map<String, dynamic>.from(liveOrder['driver']);
            _driverName = drv['name'] ?? drv['full_name'] ?? _driverName;
            _driverPhone = drv['phone'] ?? _driverPhone;
            _driverVehicle = drv['vehicle_type'] ?? drv['vehicle_model'] ?? _driverVehicle;
            _driverPlate = drv['license_plate'] ?? drv['plate_number'] ?? _driverPlate;
            if (drv['rating'] != null) {
              _driverRating = (drv['rating'] as num).toDouble();
            }
            if (drv['latitude'] != null && drv['longitude'] != null) {
              _driverLat = (drv['latitude'] as num).toDouble();
              _driverLng = (drv['longitude'] as num).toDouble();
            }
          }

          if (liveOrder['tracking'] is Map && liveOrder['tracking']['eta_minutes'] != null) {
            _etaMinutes = (liveOrder['tracking']['eta_minutes'] as num).toInt();
          }

          if (statusStr == 'placed' || statusStr == 'pending' || statusStr == 'accepted') {
            _currentStatus = OrderStatus.placed;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 35;
          } else if (statusStr == 'preparing') {
            _currentStatus = OrderStatus.preparing;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 20;
          } else if (statusStr == 'ready_for_pickup' || statusStr == 'driver_assigned' || statusStr == 'out_for_delivery' || statusStr == 'picked_up') {
            _currentStatus = OrderStatus.onTheWay;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 10;
          } else if (statusStr == 'delivered') {
            _currentStatus = OrderStatus.delivered;
            _etaMinutes = 0;
          }

          if (_lastNotifiedTrackingStatus != null && _lastNotifiedTrackingStatus != _currentStatus) {
            if (_currentStatus == OrderStatus.preparing) {
              CustomerNotificationService().showOrderStatusNotification(
                title: '👨‍🍳 المطبخ يجهز طلبك الآن!',
                body: 'طلبك رقم $_orderNum قيد التحضير والتغليف الساخن في نالوت.',
                payload: liveOrder['id']?.toString(),
              );
            } else if (_currentStatus == OrderStatus.onTheWay) {
              CustomerNotificationService().showOrderStatusNotification(
                title: '🛵 الكابتن في الطريق إليك!',
                body: 'كابتن واصل استلم طلبك $_orderNum وهو متجه الآن لموقعك.',
                payload: liveOrder['id']?.toString(),
              );
            } else if (_currentStatus == OrderStatus.delivered) {
              CustomerNotificationService().showOrderStatusNotification(
                title: '🎉 تم تسليم طلبك بنجاح!',
                body: 'بالصحة والعافية! شاركنا تقييمك المنصف للمطبخ والكابتن.',
                payload: liveOrder['id']?.toString(),
              );
            }
          }
          _lastNotifiedTrackingStatus = _currentStatus;
        });

        // If driver details were not inlined, fetch separately
        final driverId = liveOrder['driver_id'];
        if (driverId != null && liveOrder['driver'] == null) {
          _fetchDriverProfile(driverId.toString());
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchDriverProfile(String driverId) async {
    try {
      // 1. Try Live Backend First
      try {
        final res = await http
            .get(Uri.parse('${ApiService.baseUrl}/drivers/$driverId'))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true && data['data'] != null && mounted) {
            final driver = Map<String, dynamic>.from(data['data']);
            setState(() {
              _driverName = driver['full_name'] ?? driver['name'] ?? _driverName;
              _driverPhone = driver['phone'] ?? _driverPhone;
              _driverVehicle = driver['vehicle_type'] ?? driver['vehicle_model'] ?? _driverVehicle;
              _driverPlate = driver['license_plate'] ?? driver['plate_number'] ?? _driverPlate;
              if (driver['rating'] != null) {
                _driverRating = (driver['rating'] as num).toDouble();
              }
              if (driver['latitude'] != null && driver['longitude'] != null) {
                _driverLat = (driver['latitude'] as num).toDouble();
                _driverLng = (driver['longitude'] as num).toDouble();
              }
            });
            return;
          }
        }
      } catch (_) {}

      // 2. Fallback to Supabase
      final res = await http.get(
        Uri.parse('${ApiService.supabaseUrl}/drivers?id=eq.$driverId&select=*'),
        headers: {
          'apikey': ApiService.supabaseApiKey,
          'Authorization': 'Bearer ${ApiService.supabaseApiKey}',
        },
      ).timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty && mounted) {
          final driver = Map<String, dynamic>.from(list.first);
          setState(() {
            _driverName = driver['full_name'] ?? _driverName;
            _driverPhone = driver['phone'] ?? _driverPhone;
            _driverVehicle = driver['vehicle_type'] ?? _driverVehicle;
            _driverPlate = driver['plate_number'] ?? _driverPlate;
            _driverRating = (driver['rating'] as num?)?.toDouble() ?? _driverRating;
            if (driver['latitude'] != null && driver['longitude'] != null) {
              _driverLat = (driver['latitude'] as num).toDouble();
              _driverLng = (driver['longitude'] as num).toDouble();
            }
          });
        }
      }
    } catch (_) {}
  }

  String get _statusTitle {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return "تم استلام الطلب وتأكيده";
      case OrderStatus.preparing:
        return "المطبخ يجهز طلبك الآن";
      case OrderStatus.onTheWay:
        return "الكابتن استلم الطلب وفي الطريق إليك!";
      case OrderStatus.delivered:
        return "تم تسليم الطلب بنجاح! بالهناء والعافية";
    }
  }

  String get _statusSubtitle {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return "تم إرسال الطلب للمطعم في نالوت للبدء في التجهيز";
      case OrderStatus.preparing:
        return "يتم تحضير المكونات الطازجة والتغليف الحراري";
      case OrderStatus.onTheWay:
        return "$_driverName في الطريق إليك عبر $_driverVehicle";
      case OrderStatus.delivered:
        return "تم التسليم في $_deliveryAddress";
    }
  }

  Future<void> _callDriver() async {
    final uri = Uri.parse('tel:$_driverPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تتبع مباشر #$_orderNum',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                _storeName,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            // 1. Real OpenStreetMap Layer (Top 44% of screen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.44,
              child: _buildRealOpenStreetMap(isDark),
            ),

            // 2. Scrollable Tracking Details Sheet
            Positioned.fill(
              top: MediaQuery.of(context).size.height * 0.38,
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
                      const SizedBox(height: 16),

                      // Driver / Captain Profile Card
                      if (_currentStatus != OrderStatus.delivered)
                        _buildDriverContactCard(isDark),

                      const SizedBox(height: 16),

                      // Order Summary Card
                      _buildOrderSummaryCard(isDark),

                      if (_currentStatus == OrderStatus.delivered) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                            ),
                            borderRadius: AppRadius.radiusLg,
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'تم تسليم وجبتك بنجاح! صحتين وعافية 🍽️',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'رأيك الصادق أمانة ويساعدنا في تحسين مطاعم وكباتن نالوت (واكسب 20 نقطة ولاء 🎁)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => FairRatingDialog(
                                        orderId: widget.orderId ?? 'ord_test',
                                        orderNumber: _orderNum,
                                        storeName: _storeName,
                                        storeId: 'store_nalut_01',
                                        driverId: 'drv_01',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.rate_review, color: Colors.white, size: 18),
                                  label: const Text(
                                    'تقييم المطعم والكابتن بأمانة ⭐',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.waselPrimary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// REAL OPENSTREETMAP (نالوت - خرائط تفاعلية حقيقية)
  /// ---------------------------------------------------------------------------
  Widget _buildRealOpenStreetMap(bool isDark) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_storeLat, _storeLng),
            initialZoom: 15.0,
            minZoom: 12.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: _isSatelliteMap
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wasel.customer.wasel_customer_app',
              maxZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    LatLng(_storeLat, _storeLng),
                    LatLng(_driverLat, _driverLng),
                    LatLng(_customerLat, _customerLng),
                  ],
                  color: AppColors.waselPrimary,
                  strokeWidth: 4.0,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Restaurant Pin
                Marker(
                  point: LatLng(_storeLat, _storeLng),
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.waselPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.waselPrimary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 22),
                  ),
                ),

                // Customer Delivery Pin
                Marker(
                  point: LatLng(_customerLat, _customerLng),
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
                  ),
                ),

                // Moving Captain Marker
                Marker(
                  point: LatLng(_driverLat, _driverLng),
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Live Satellite / Street Map Toggle Badge
        Positioned(
          left: 16,
          top: 16,
          child: GestureDetector(
            onTap: () => setState(() => _isSatelliteMap = !_isSatelliteMap),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: AppRadius.radiusFull,
                boxShadow: AppShadows.sm,
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSatelliteMap ? Icons.satellite_alt_rounded : Icons.map_rounded,
                    color: _isSatelliteMap ? Colors.greenAccent : Colors.cyanAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isSatelliteMap ? 'قمر صناعي مباشر • نالوت' : 'خريطة الشوارع • نالوت',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.swap_horiz_rounded, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ),

        // Controls (Satellite toggle & Recenter Button)
        Positioned(
          right: 16,
          bottom: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'tracking_satellite_toggle',
                backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                foregroundColor: _isSatelliteMap ? AppColors.waselPrimary : Colors.black87,
                onPressed: () => setState(() => _isSatelliteMap = !_isSatelliteMap),
                child: Icon(_isSatelliteMap ? Icons.satellite_alt_rounded : Icons.map_outlined),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'tracking_recenter',
                backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                foregroundColor: AppColors.waselPrimary,
                onPressed: () {
                  _mapController.move(LatLng(_driverLat, _driverLng), 15.5);
                },
                child: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// ETA & OTP BANNER
  /// ---------------------------------------------------------------------------
  Widget _buildEtaAndOtpBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _currentStatus == OrderStatus.delivered
            ? AppColors.jetGradient
            : AppColors.waselGradient,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.waselPrimary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ETA Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentStatus == OrderStatus.delivered ? 'تم التسليم' : '$_etaMinutes دقيقة',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusSubtitle,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Security OTP Delivery PIN
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text(
                  'رمز التسليم (OTP)',
                  style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _deliveryOtp,
                  style: const TextStyle(
                    fontSize: 22,
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
  /// PROGRESS TIMELINE
  /// ---------------------------------------------------------------------------
  Widget _buildProgressTimeline(bool isDark) {
    final steps = [
      {'title': 'تم الطلب', 'status': OrderStatus.placed},
      {'title': 'تجهيز المطبخ', 'status': OrderStatus.preparing},
      {'title': 'في الطريق', 'status': OrderStatus.onTheWay},
      {'title': 'تم التسليم', 'status': OrderStatus.delivered},
    ];

    int currentIndex = _currentStatus.index;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isEven) {
                final stepIdx = i ~/ 2;
                final isPassed = stepIdx <= currentIndex;
                final isCurrent = stepIdx == currentIndex;

                return Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isPassed ? AppColors.waselPrimary : Colors.grey[300],
                        shape: BoxShape.circle,
                        border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Center(
                        child: Icon(
                          isPassed ? Icons.check_rounded : Icons.circle,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[stepIdx]['title'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isPassed
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                  ],
                );
              } else {
                final stepIdx = i ~/ 2;
                final isPassed = stepIdx < currentIndex;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 18),
                    color: isPassed ? AppColors.waselPrimary : Colors.grey[300],
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
  /// DRIVER CONTACT CARD
  /// ---------------------------------------------------------------------------
  Widget _buildDriverContactCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.waselGradient,
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, size: 28, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _driverName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: AppColors.gold),
                          const SizedBox(width: 2),
                          Text(
                            '$_driverRating',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$_driverVehicle • لوحة: $_driverPlate',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _callDriver,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_rounded, color: AppColors.success, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// ORDER FINANCIAL SUMMARY
  /// ---------------------------------------------------------------------------
  Widget _buildOrderSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ملخص الحساب والدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.waselPrimary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Text('دفع نقدي عند الاستلام (COD)', style: TextStyle(fontSize: 10, color: AppColors.waselPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('عنوان التوصيل', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(_deliveryAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ الإجمالي المستحق', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text(
                '${_totalAmount.toStringAsFixed(2)} د.ل',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.waselPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

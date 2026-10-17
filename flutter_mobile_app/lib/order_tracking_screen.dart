import 'dart:async';
import 'dart:convert';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'design_system.dart';
import 'services/api_service.dart';
import 'services/customer_notification_service.dart';
import 'services/socket_service.dart';
import 'screens/order_rating_screen.dart';
import 'widgets/no_network_screen.dart';

/// ============================================================================
/// WASEL REAL-TIME ORDER TRACKING SCREEN (شاشة تتبع الطلب الحية - نالوت)
/// ============================================================================
enum OrderStatus {
  placed,
  preparing,
  onTheWay,
  delivered,
  cancelled,
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
  String _rawStatus = 'placed';
  OrderStatus? _lastNotifiedTrackingStatus;
  Timer? _pollingTimer;
  final MapController _mapController = MapController();
  gmap.GoogleMapController? _googleMapController;
  int _mapMode = 0; // 0 = Google Maps, 1 = ArcGIS Satellite, 2 = OpenStreetMap
  bool _isSatelliteMap = true;
  bool _hasNetworkError = false;

  // Order Details from Supabase
  String _orderNum = 'WAS-ORD';
  String _storeName = 'مطعم قصر نالوت للمشويات';
  String _deliveryOtp = '----';
  String _deliveryAddress = 'نالوت - حي القلعة';
  double _totalAmount = 42.00;
  int _etaMinutes = 25;

  // GPS Coordinates (Default: Nalut center & Fortress)
  final double _storeLat = 31.8687;
  final double _storeLng = 10.9818;
  double _customerLat = 31.8695;
  double _customerLng = 10.9835;

  // Driver GPS Smooth Interpolation (900ms signature curve)
  late final AnimationController _driverAnimController;
  late final Animation<double> _driverAnimation;
  LatLng _prevDriverLatLng = const LatLng(31.8680, 10.9820);
  LatLng _targetDriverLatLng = const LatLng(31.8680, 10.9820);

  // Driver Details
  String _driverName = 'كابتن طارق النالوتي';
  String _driverPhone = '0915544332';
  String _driverVehicle = 'سيارة تويوتا يارس';
  String _driverPlate = '14-88492';
  double _driverRating = 4.9;

  StreamSubscription<Map<String, dynamic>>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _driverAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _driverAnimation = CurvedAnimation(
      parent: _driverAnimController,
      curve: WaselMotion.signature,
    );
    _driverAnimController.value = 1.0;

    if (widget.orderNumber != null) {
      _orderNum = widget.orderNumber!;
    }
    _fetchLiveTrackingData();

    // 1. Connect WebSocket for sub-50ms instant sync
    SocketService.connect();
    _statusSubscription = SocketService.orderStatusStream.listen((event) {
      final evtOrderId = event['order_id'] ?? event['id'];
      if (evtOrderId == widget.orderId || evtOrderId == _orderNum) {
        final newStatus = event['status']?.toString();
        if (newStatus != null && mounted) {
          setState(() {
            _syncStatusFromBackend(newStatus);
          });
        }
      }
    });

    _locationSubscription = SocketService.driverLocationStream.listen((event) {
      final lat = (event['latitude'] as num?)?.toDouble();
      final lng = (event['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && mounted) {
        _updateDriverCoordinates(lat, lng);
      }
    });

    // Fallback polling (relaxed from 4s to 12s as secondary safety net)
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) => _fetchLiveTrackingData());
  }

  void _syncStatusFromBackend(String statusStr) {
    _rawStatus = statusStr;
    if (statusStr == 'cancelled') {
      _currentStatus = OrderStatus.cancelled;
      _etaMinutes = 0;
    } else if (statusStr == 'placed' || statusStr == 'pending' || statusStr == 'accepted') {
      _currentStatus = OrderStatus.placed;
    } else if (statusStr == 'preparing' || statusStr == 'ready_for_pickup') {
      _currentStatus = OrderStatus.preparing;
    } else if (statusStr == 'driver_assigned' || statusStr == 'out_for_delivery' || statusStr == 'picked_up') {
      _currentStatus = OrderStatus.onTheWay;
    } else if (statusStr == 'delivered') {
      _currentStatus = OrderStatus.delivered;
      _etaMinutes = 0;
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _locationSubscription?.cancel();
    _pollingTimer?.cancel();
    _driverAnimController.dispose();
    _mapController.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _updateDriverCoordinates(double lat, double lng) {
    if (lat != _targetDriverLatLng.latitude || lng != _targetDriverLatLng.longitude) {
      final currentProgress = _driverAnimation.value;
      _prevDriverLatLng = LatLng(
        lerpDouble(_prevDriverLatLng.latitude, _targetDriverLatLng.latitude, currentProgress) ?? _targetDriverLatLng.latitude,
        lerpDouble(_prevDriverLatLng.longitude, _targetDriverLatLng.longitude, currentProgress) ?? _targetDriverLatLng.longitude,
      );
      _targetDriverLatLng = LatLng(lat, lng);
      _driverAnimController.forward(from: 0.0);

      if (_googleMapController != null && _mapMode == 0) {
        try {
          _googleMapController!.animateCamera(
            gmap.CameraUpdate.newLatLng(gmap.LatLng(lat, lng)),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _fetchLiveTrackingData() async {
    final orderId = widget.orderId;
    if (orderId == null || orderId.isEmpty) {
      return;
    }

    try {
      Map<String, dynamic>? order;

      // 1. Try Live Unified Backend Server First (24/7 Cloud or Local)
      try {
        final uri = Uri.parse('${ApiService.baseUrl}/orders/$orderId');
        final res = await http.get(uri).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['success'] == true) {
            if (data['data'] is Map) {
              order = Map<String, dynamic>.from(data['data']);
            }
          }
        }
      } catch (_) {
        // Fallback to Supabase
      }

      // 2. Fallback to Supabase Cloud if unified backend is unreachable
      if (order == null) {
        try {
          final uri = Uri.parse('${ApiService.supabaseUrl}/orders?id=eq.$orderId&select=*');
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
          _hasNetworkError = false;
          _rawStatus = statusStr;
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
              _updateDriverCoordinates(
                (drv['latitude'] as num).toDouble(),
                (drv['longitude'] as num).toDouble(),
              );
            }
          }

          if (liveOrder['tracking'] is Map && liveOrder['tracking']['eta_minutes'] != null) {
            _etaMinutes = (liveOrder['tracking']['eta_minutes'] as num).toInt();
          }

          if (statusStr == 'cancelled') {
            _currentStatus = OrderStatus.cancelled;
            _etaMinutes = 0;
          } else if (statusStr == 'placed' || statusStr == 'pending' || statusStr == 'accepted') {
            _currentStatus = OrderStatus.placed;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 35;
          } else if (statusStr == 'preparing') {
            _currentStatus = OrderStatus.preparing;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 20;
          } else if (statusStr == 'ready_for_pickup') {
            _currentStatus = OrderStatus.preparing;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 15;
          } else if (statusStr == 'driver_assigned' || statusStr == 'out_for_delivery' || statusStr == 'picked_up') {
            _currentStatus = OrderStatus.onTheWay;
            _etaMinutes = _etaMinutes > 0 ? _etaMinutes : 10;
          } else if (statusStr == 'delivered') {
            _currentStatus = OrderStatus.delivered;
            _etaMinutes = 0;
          }

          if (_lastNotifiedTrackingStatus != null && _lastNotifiedTrackingStatus != _currentStatus) {
            String? bannerTitle;
            String? bannerBody;
            IconData bannerIcon = Icons.notifications_active_rounded;
            Color bannerColor = AppColors.waselPrimary;

            if (_currentStatus == OrderStatus.cancelled) {
              bannerTitle = '❌ تم إلغاء الطلب';
              bannerBody = 'تم إلغاء طلبك $_orderNum وفك حجز الرصيد بالمحفظة.';
              bannerIcon = Icons.cancel_outlined;
              bannerColor = Colors.red;
            } else if (_currentStatus == OrderStatus.preparing) {
              if (statusStr == 'ready_for_pickup') {
                bannerTitle = '📦 طلبك جاهز للاستلام!';
                bannerBody = 'المطبخ أتم تحضير وجبتك $_orderNum وبانتظار استلام الكابتن.';
                bannerIcon = Icons.takeout_dining_rounded;
              } else {
                bannerTitle = '👨‍🍳 المطبخ يجهز طلبك الآن!';
                bannerBody = 'طلبك رقم $_orderNum قيد التحضير والتغليف الساخن في نالوت.';
                bannerIcon = Icons.soup_kitchen_rounded;
              }
            } else if (_currentStatus == OrderStatus.onTheWay) {
              bannerTitle = '🛵 الكابتن في الطريق إليك!';
              bannerBody = 'كابتن واصل استلم طلبك $_orderNum وهو متجه الآن لموقعك.';
              bannerIcon = Icons.delivery_dining_rounded;
              bannerColor = AppColors.waselTeal;
            } else if (_currentStatus == OrderStatus.delivered) {
              bannerTitle = '🎉 تم تسليم طلبك بنجاح!';
              bannerBody = 'بالصحة والعافية! شاركنا تقييمك المنصف للمطبخ والكابتن.';
              bannerIcon = Icons.verified_rounded;
              bannerColor = AppColors.waselTeal;
            }

            if (bannerTitle != null && bannerBody != null) {
              CustomerNotificationService().showOrderStatusNotification(
                title: bannerTitle,
                body: bannerBody,
                payload: liveOrder['id']?.toString(),
              );
              try {
                WaselInAppNotificationBanner.show(
                  context,
                  title: bannerTitle,
                  body: bannerBody,
                  icon: bannerIcon,
                  accentColor: bannerColor,
                );
              } catch (_) {}
            }
          }
          _lastNotifiedTrackingStatus = _currentStatus;
        });

        // If driver details were not inlined, fetch separately
        final driverId = liveOrder['driver_id'];
        if (driverId != null && liveOrder['driver'] == null) {
          _fetchDriverProfile(driverId.toString());
        }
      } else if (mounted) {
        setState(() {
          _hasNetworkError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasNetworkError = true;
        });
      }
    }
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
                _updateDriverCoordinates(
                  (driver['latitude'] as num).toDouble(),
                  (driver['longitude'] as num).toDouble(),
                );
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
              _updateDriverCoordinates(
                (driver['latitude'] as num).toDouble(),
                (driver['longitude'] as num).toDouble(),
              );
            }
          });
        }
      }
    } catch (_) {}
  }

  String get _statusTitle {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return "تم إرسال الطلب للمطبخ ⏳";
      case OrderStatus.preparing:
        return _rawStatus == 'ready_for_pickup' ? "الوجبة جاهزة وبانتظار الكابتن 📦" : "المطبخ يجهز طلبك الآن 🍳";
      case OrderStatus.onTheWay:
        return "الكابتن استلم الوجبة وفي الطريق إليك! 🛵";
      case OrderStatus.delivered:
        return "تم تسليم الطلب بنجاح! بالهناء والعافية 🎉";
      case OrderStatus.cancelled:
        return "تم إلغاء الطلب ❌";
    }
  }

  String get _statusSubtitle {
    switch (_currentStatus) {
      case OrderStatus.placed:
        return "بانتظار تأكيد المطبخ وتحديد وقت الطهي";
      case OrderStatus.preparing:
        return _rawStatus == 'ready_for_pickup'
            ? "تم طهي وجبتك وتغليفها حرارياً، الكابتن يستلمها الآن بالمطعم"
            : "يتم طهي وجبتك طازجة، والكابتن يتحرك للمطعم أثناء الطهي لتصلك ساخنة!";
      case OrderStatus.onTheWay:
        return "$_driverName في الطريق إليك عبر $_driverVehicle";
      case OrderStatus.delivered:
        return "تم التسليم في $_deliveryAddress";
      case OrderStatus.cancelled:
        return "تم إلغاء الطلب وفك حجز الرصيد إن وجد";
    }
  }

  Future<void> _callDriver() async {
    final uri = Uri.parse('tel:$_driverPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareTrackingWithRecipient() async {
    final url = 'https://wasel-nalut.onrender.com/track/$_orderNum';
    final text = 'شحنتك من واصل نالوت في الطريق إليك ⚡\n'
        'المتجر: $_storeName\n'
        'رقم الطلب: #$_orderNum\n'
        'كود استلام الشحنة (OTP): $_deliveryOtp\n'
        'تتبع مسار الكابتن مباشرة عبر الرابط:\n$url';
    final whatsappUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final webUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
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
            // 1. Hybrid Google Maps & Satellite Layer (Top 44% of screen)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.44,
              child: _buildHybridTrackingMap(),
            ),

            // 2. Scrollable Tracking Details Sheet
            Positioned.fill(
              top: MediaQuery.of(context).size.height * 0.38,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
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
                            color: colorScheme.outlineVariant,
                            borderRadius: AppRadius.radiusFull,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mountain Network Signal Drop Warning
                      if (_hasNetworkError) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: AppRadius.radiusLg,
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: NoNetworkScreen(
                            isFullScreen: false,
                            onRetry: () async {
                              await _fetchLiveTrackingData();
                            },
                          ),
                        ),
                      ],

                      // ETA Header & Security OTP Pin Badge
                      _buildEtaAndOtpBanner(),
                      const SizedBox(height: 16),

                      // Order Progress Timeline Steps
                      _buildProgressTimeline(),
                      const SizedBox(height: 16),

                      // Driver / Captain Profile Card & Status-Aware Handover Banners
                      if (_currentStatus == OrderStatus.onTheWay) ...[
                        _buildDriverContactCard(),
                        _buildRecipientShareButton(),
                      ] else if (_rawStatus == 'ready_for_pickup') ...[
                        _buildReadyForPickupCard(),
                      ] else if (_currentStatus == OrderStatus.placed || _currentStatus == OrderStatus.preparing) ...[
                        _buildPreparingStatusCard(),
                      ],

                      const SizedBox(height: 16),

                      // Order Summary Card
                      _buildOrderSummaryCard(),

                      // Customer Order Cancellation Action (Allowed when placed/pending)
                      if (_currentStatus == OrderStatus.placed) ...[
                        const SizedBox(height: 14),
                        _buildCancellationAction(),
                      ],

                      // Cancelled Order Status Banner
                      if (_currentStatus == OrderStatus.cancelled) ...[
                        const SizedBox(height: 14),
                        _buildCancelledBanner(),
                      ],

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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OrderRatingScreen(
                                          orderId: widget.orderId ?? 'ord_test',
                                          orderNumber: _orderNum,
                                          storeName: _storeName,
                                          storeId: 'store_nalut_01',
                                          driverId: 'drv_01',
                                          driverName: _driverName.isNotEmpty ? _driverName : 'كابتن واصل نالوت',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                                  label: const Text(
                                    'تقييم المطعم والكابتن بأمانة (+20 نقطة 🎁)',
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
  /// HYBRID GOOGLE MAPS & SATELLITE ENGINE (نالوت - محرك الخرائط الهجين)
  /// ---------------------------------------------------------------------------
  Widget _buildHybridTrackingMap() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return AnimatedBuilder(
        animation: _driverAnimation,
        builder: (context, _) {
          final isA11yDisabled = WaselMotion.isAnimationDisabled(context);
          final t = isA11yDisabled ? 1.0 : _driverAnimation.value;
          final currentDriverPos = LatLng(
            lerpDouble(_prevDriverLatLng.latitude, _targetDriverLatLng.latitude, t) ?? _targetDriverLatLng.latitude,
            lerpDouble(_prevDriverLatLng.longitude, _targetDriverLatLng.longitude, t) ?? _targetDriverLatLng.longitude,
          );

          Widget mapLayer;
          if (_mapMode == 0) {
            // 1. Google Maps Platform Engine
            mapLayer = gmap.GoogleMap(
              initialCameraPosition: gmap.CameraPosition(
                target: gmap.LatLng(_storeLat, _storeLng),
                zoom: 15.2,
              ),
              mapType: _isSatelliteMap ? gmap.MapType.satellite : gmap.MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              trafficEnabled: false,
              onMapCreated: (ctrl) {
                _googleMapController = ctrl;
              },
              markers: {
                gmap.Marker(
                  markerId: const gmap.MarkerId('store_pin'),
                  position: gmap.LatLng(_storeLat, _storeLng),
                  infoWindow: gmap.InfoWindow(title: _storeName),
                  icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueOrange),
                ),
                gmap.Marker(
                  markerId: const gmap.MarkerId('customer_pin'),
                  position: gmap.LatLng(_customerLat, _customerLng),
                  infoWindow: gmap.InfoWindow(title: _deliveryAddress),
                  icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueGreen),
                ),
                gmap.Marker(
                  markerId: const gmap.MarkerId('driver_pin'),
                  position: gmap.LatLng(currentDriverPos.latitude, currentDriverPos.longitude),
                  infoWindow: gmap.InfoWindow(title: _driverName),
                  icon: gmap.BitmapDescriptor.defaultMarkerWithHue(gmap.BitmapDescriptor.hueAzure),
                ),
              },
              polylines: {
                gmap.Polyline(
                  polylineId: const gmap.PolylineId('nalut_delivery_route'),
                  points: [
                    gmap.LatLng(_storeLat, _storeLng),
                    gmap.LatLng(currentDriverPos.latitude, currentDriverPos.longitude),
                    gmap.LatLng(_customerLat, _customerLng),
                  ],
                  color: colorScheme.primary,
                  width: 5,
                ),
              },
            );
          } else {
            // 2. High-Performance Fallback: ArcGIS World Imagery & OpenStreetMap
            mapLayer = FlutterMap(
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
                        currentDriverPos,
                        LatLng(_customerLat, _customerLng),
                      ],
                      color: colorScheme.primary,
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
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.4),
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
                      point: currentDriverPos,
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
            );
          }

          return Stack(
            children: [
              mapLayer,

              // Live Map Engine Selector Badge
              Positioned(
                left: 16,
                top: 16,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_mapMode == 0) {
                        _mapMode = 1;
                        _isSatelliteMap = true;
                      } else if (_mapMode == 1) {
                        _mapMode = 2;
                        _isSatelliteMap = false;
                      } else {
                        _mapMode = 0;
                        _isSatelliteMap = false;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: AppRadius.radiusFull,
                      boxShadow: AppShadows.sm,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _mapMode == 0
                              ? Icons.map_rounded
                              : (_mapMode == 1 ? Icons.satellite_alt_rounded : Icons.explore_rounded),
                          color: _mapMode == 0
                              ? const Color(0xFFF59E0B)
                              : (_mapMode == 1 ? Colors.greenAccent : Colors.cyanAccent),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _mapMode == 0
                              ? 'Google Maps • نالوت'
                              : (_mapMode == 1 ? 'أقمار صناعية • نالوت' : 'خريطة الشوارع • نالوت'),
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
                      backgroundColor: colorScheme.surface,
                      foregroundColor: _isSatelliteMap ? colorScheme.primary : colorScheme.onSurface,
                      onPressed: () {
                        setState(() {
                          _isSatelliteMap = !_isSatelliteMap;
                        });
                      },
                      child: Icon(_isSatelliteMap ? Icons.satellite_alt_rounded : Icons.map_outlined),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'tracking_recenter',
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.primary,
                      onPressed: () {
                        if (_mapMode == 0 && _googleMapController != null) {
                          _googleMapController!.animateCamera(
                            gmap.CameraUpdate.newLatLng(
                              gmap.LatLng(currentDriverPos.latitude, currentDriverPos.longitude),
                            ),
                          );
                        } else {
                          _mapController.move(currentDriverPos, 15.5);
                        }
                      },
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    });
  }

  /// ---------------------------------------------------------------------------
  /// ETA & OTP BANNER
  /// ---------------------------------------------------------------------------
  Widget _buildEtaAndOtpBanner() {
    final Gradient bannerGradient;
    if (_currentStatus == OrderStatus.cancelled) {
      bannerGradient = const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF991B1B)]);
    } else if (_currentStatus == OrderStatus.delivered) {
      bannerGradient = AppColors.jetGradient;
    } else {
      bannerGradient = AppColors.waselGradient;
    }

    final String mainStatusText;
    if (_currentStatus == OrderStatus.cancelled) {
      mainStatusText = 'طلب ملغى';
    } else if (_currentStatus == OrderStatus.delivered) {
      mainStatusText = 'تم التسليم';
    } else {
      mainStatusText = '$_etaMinutes دقيقة';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: bannerGradient,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(
            color: (_currentStatus == OrderStatus.cancelled ? Colors.red : AppColors.waselPrimary).withValues(alpha: 0.3),
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
                  mainStatusText,
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
                Text(
                  _currentStatus == OrderStatus.cancelled ? 'الحالة' : 'رمز التسليم (OTP)',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                _currentStatus == OrderStatus.cancelled
                    ? const Icon(Icons.cancel_outlined, color: Colors.white, size: 24)
                    : Text(
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
  Widget _buildProgressTimeline() {
    if (_currentStatus == OrderStatus.cancelled) {
      return Builder(builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cancel_outlined, color: colorScheme.error, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تم إلغاء مسار الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.error)),
                    const SizedBox(height: 2),
                    Text('توقف التتبع نظراً لإلغاء الطلب بناءً على رغبتك أو من الإدارة.', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
      });
    }

    final steps = [
      {'title': 'تم الطلب', 'status': OrderStatus.placed},
      {'title': 'تجهيز المطبخ', 'status': OrderStatus.preparing},
      {'title': 'في الطريق', 'status': OrderStatus.onTheWay},
      {'title': 'تم التسليم', 'status': OrderStatus.delivered},
    ];

    final currentIndex = _currentStatus.index;

    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      final isA11yDisabled = WaselMotion.isAnimationDisabled(context);

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: colorScheme.outlineVariant),
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

                  final nodeWidget = Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isPassed ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: isCurrent ? Border.all(color: colorScheme.surface, width: 2) : null,
                    ),
                    child: Center(
                      child: Icon(
                        isPassed ? Icons.check_rounded : Icons.circle,
                        size: 14,
                        color: isPassed ? colorScheme.onPrimary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  );

                  return Column(
                    children: [
                      isCurrent && !isA11yDisabled
                          ? WaselPulseGlow(
                              glowColor: colorScheme.primary,
                              minSpread: 1.0,
                              maxSpread: 5.0,
                              child: nodeWidget,
                            )
                          : nodeWidget,
                      const SizedBox(height: 4),
                      Text(
                        steps[stepIdx]['title'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isPassed
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                } else {
                  final stepIdx = i ~/ 2;
                  final isPassed = stepIdx < currentIndex;
                  return Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: isPassed ? 1.0 : 0.0),
                      duration: isA11yDisabled ? Duration.zero : const Duration(milliseconds: 600),
                      curve: WaselMotion.signature,
                      builder: (context, fillProgress, _) {
                        return Container(
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight,
                            widthFactor: fillProgress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              }),
            ),
          ],
        ),
      );
    });
  }

  /// ---------------------------------------------------------------------------
  /// DRIVER CONTACT CARD
  /// ---------------------------------------------------------------------------
  Widget _buildDriverContactCard() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: colorScheme.outlineVariant),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface),
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
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
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
    });
  }

  /// ---------------------------------------------------------------------------
  /// RECIPIENT PUBLIC TRACKING SHARE CARD (GIFT / MEAL FOR OTHERS)
  /// ---------------------------------------------------------------------------
  Widget _buildRecipientShareButton() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF25D366).withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎁 هل طلبت الوجبة لشخص آخر أو عائلتك؟',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E8E42)),
                ),
                SizedBox(height: 2),
                Text(
                  'أرسل له رابط التتبع المباشر وكود الاستلام (OTP) بنقرة واحدة عبر واتساب',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _shareTrackingWithRecipient,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share_rounded, size: 14),
                SizedBox(width: 4),
                Text('إرسال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyForPickupCard() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الوجبة جاهزة في المطعم! 🍳',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'المطعم أتم تجهيز طلبك الساخن، وفي انتظار وصول واستلام كابتن التوصيل 🛵',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPreparingStatusCard() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.waselPrimary.withValues(alpha: 0.08),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.waselPrimary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.waselPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.soup_kitchen_rounded, color: AppColors.waselPrimary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المطعم يجهز طلبك الطازج الآن 👨‍🍳',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.waselPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'سيتم إشعارك فور اكتمال التجهيز وبدء انطلاق الكابتن لاستلام الوجبة 🛵',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// ---------------------------------------------------------------------------
  /// ORDER FINANCIAL SUMMARY
  /// ---------------------------------------------------------------------------
  Widget _buildOrderSummaryCard() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ملخص الحساب والدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.onSurface)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text('دفع نقدي عند الاستلام (COD)', style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('عنوان التوصيل', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                Text(_deliveryAddress, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبلغ الإجمالي المستحق', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                Text(
                  '${_totalAmount.toStringAsFixed(2)} د.ل',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCancellationAction() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.05),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'يمكنك إلغاء الطلب الآن قبل بدء تحضيره',
                style: TextStyle(fontSize: 11.5, color: colorScheme.error),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
              ),
              onPressed: _handleCancelOrder,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('إلغاء الطلب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCancelledBanner() {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.1),
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: colorScheme.error),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_rounded, color: colorScheme.error, size: 24),
                const SizedBox(width: 8),
                Text(
                  'تم إلغاء هذا الطلب ❌',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'تم فك حجز أي رصيد تم دفعه بالمحفظة فوراً وإعادته لرصيدك المتاح بنجاح.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _handleCancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('إلغاء الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟ سيتم فك حجز أي رصيد تم دفعه بالمحفظة فوراً وإخطار المتجر.',
            style: TextStyle(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم، إلغاء الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await ApiService.cancelOrder(widget.orderId ?? _orderNum);
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _currentStatus = OrderStatus.cancelled;
        _rawStatus = 'cancelled';
        _etaMinutes = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء الطلب وفك حجز الرصيد بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'فشل إلغاء الطلب'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

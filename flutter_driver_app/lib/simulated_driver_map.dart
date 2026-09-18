import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'driver_theme.dart';
import 'driver_models.dart';

/// ============================================================================
/// REAL SATELLITE NAVIGATION MAP WIDGET FOR CAPTAIN WASEL (NALUT)
/// Powered by ArcGIS World Imagery & OpenStreetMap
/// ============================================================================

class SimulatedDriverMap extends StatefulWidget {
  final DeliveryStep? activeStep;
  final String? storeName;
  final String? destinationAddress;
  final bool isInteractive;
  final double height;
  final VoidCallback? onRecenter;
  final double? driverLat;
  final double? driverLng;
  final double? storeLat;
  final double? storeLng;
  final double? customerLat;
  final double? customerLng;

  const SimulatedDriverMap({
    super.key,
    this.activeStep,
    this.storeName,
    this.destinationAddress,
    this.isInteractive = true,
    this.height = 300,
    this.onRecenter,
    this.driverLat,
    this.driverLng,
    this.storeLat,
    this.storeLng,
    this.customerLat,
    this.customerLng,
  });

  @override
  State<SimulatedDriverMap> createState() => _SimulatedDriverMapState();
}

class _SimulatedDriverMapState extends State<SimulatedDriverMap> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _isSatelliteMode = true;
  double _currentZoom = 16.0;

  // Nalut coordinate anchors
  late LatLng _storePos;
  late LatLng _customerPos;
  late LatLng _driverPos;

  // Waypoints connecting Store -> Customer in Nalut
  late final List<LatLng> _routePoints;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCoordinates();
  }

  void _initCoordinates() {
    _storePos = LatLng(
      widget.storeLat ?? 31.8686,
      widget.storeLng ?? 10.9818,
    );

    _customerPos = LatLng(
      widget.customerLat ?? 31.8740,
      widget.customerLng ?? 10.9790,
    );

    // Initial driver position based on step
    if (widget.activeStep == DeliveryStep.navigatingToStore) {
      _driverPos = LatLng(
        widget.driverLat ?? 31.8655,
        widget.driverLng ?? 10.9830,
      );
    } else if (widget.activeStep == DeliveryStep.orderPickupChecklist) {
      _driverPos = _storePos;
    } else if (widget.activeStep == DeliveryStep.completeDeliveryOtp ||
        widget.activeStep == DeliveryStep.deliveryFinished) {
      _driverPos = _customerPos;
    } else {
      _driverPos = LatLng(
        ((widget.driverLat ?? 31.8686) + _customerPos.latitude) / 2,
        ((widget.driverLng ?? 10.9818) + _customerPos.longitude) / 2,
      );
    }

    // Realistic navigation route through Nalut main roads
    _routePoints = [
      _storePos,
      LatLng(31.8698, 10.9825),
      LatLng(31.8712, 10.9810),
      LatLng(31.8728, 10.9800),
      _customerPos,
    ];
  }

  @override
  void didUpdateWidget(covariant SimulatedDriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeStep != widget.activeStep) {
      _initCoordinates();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _recenterOnDriver();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _recenterOnDriver() {
    _mapController.move(_driverPos, _currentZoom);
    widget.onRecenter?.call();
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(11.0, 19.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
    setState(() {});
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(11.0, 19.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
    setState(() {});
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
          // 1. Real Satellite / Streets Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos,
              initialZoom: _currentZoom,
              minZoom: 11.0,
              maxZoom: 19.0,
              interactionOptions: InteractionOptions(
                flags: widget.isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
            ),
            children: [
              // Tile Layer (ArcGIS Satellite or OpenStreetMap)
              if (_isSatelliteMode)
                TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.wasel.captain.wasel_captain_app',
                  maxZoom: 19,
                )
              else
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wasel.captain.wasel_captain_app',
                  maxZoom: 19,
                ),

              // Route Polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5.5,
                    color: DriverColors.primary.withValues(alpha: 0.9),
                    borderStrokeWidth: 2.0,
                    borderColor: Colors.black.withValues(alpha: 0.4),
                  ),
                ],
              ),

              // Markers: Store, Customer, Captain Vehicle
              MarkerLayer(
                markers: [
                  // Store Marker
                  Marker(
                    point: _storePos,
                    width: 70,
                    height: 60,
                    child: _buildStorePin(isDark),
                  ),

                  // Customer House Marker
                  Marker(
                    point: _customerPos,
                    width: 70,
                    height: 60,
                    child: _buildCustomerPin(isDark),
                  ),

                  // Captain Vehicle Marker (Animated)
                  Marker(
                    point: _driverPos,
                    width: 60,
                    height: 60,
                    child: _buildCaptainVehicleMarker(),
                  ),
                ],
              ),
            ],
          ),

          // 2. Turn-by-Turn Instruction Banner
          if (widget.activeStep != null && widget.activeStep != DeliveryStep.deliveryFinished)
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: _buildNavigationInstructionBanner(isDark),
            ),

          // 3. Satellite / Streets Toggle Badge (Top-Right)
          Positioned(
            top: widget.activeStep != null ? 82 : 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSatelliteMode ? Colors.greenAccent : Colors.amberAccent,
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSatelliteMode ? Icons.satellite_alt_rounded : Icons.map_rounded,
                        size: 14,
                        color: _isSatelliteMode ? Colors.greenAccent : Colors.amberAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSatelliteMode ? 'قمر صناعي 🛰️' : 'خريطة الشوارع 🗺️',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Live GPS Telemetry Badge (Bottom-Right)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed_rounded, color: Colors.greenAccent, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'نالوت 31.86° N • GPS دقيق',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // 5. Map Controls (Zoom In, Zoom Out, Recenter)
          Positioned(
            bottom: 12,
            left: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  tooltip: 'إعادة التوسيط على الكابتن',
                  color: DriverColors.primary,
                  onTap: _recenterOnDriver,
                ),
                const SizedBox(width: 6),
                _buildMapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'تكبير',
                  onTap: _zoomIn,
                ),
                const SizedBox(width: 6),
                _buildMapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'تصغير',
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildStorePin(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Text(
            widget.storeName != null && widget.storeName!.length > 10
                ? '${widget.storeName!.substring(0, 10)}..'
                : (widget.storeName ?? 'المتجر'),
            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
        const Icon(Icons.storefront_rounded, color: Colors.deepPurpleAccent, size: 28),
      ],
    );
  }

  Widget _buildCustomerPin(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red[800],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Text(
            'الزبون 🏠',
            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
        const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 28),
      ],
    );
  }

  Widget _buildCaptainVehicleMarker() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer radar pulse circle
            Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DriverColors.primary.withValues(alpha: 0.25),
                  border: Border.all(
                    color: DriverColors.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Inner vehicle icon badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: DriverColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationInstructionBanner(bool isDark) {
    IconData icon;
    String distance;
    String instruction;
    Color accentColor;

    switch (widget.activeStep) {
      case DeliveryStep.navigatingToStore:
        icon = Icons.turn_right_rounded;
        distance = '1.2 كم • 4 د';
        instruction = 'توجه نحو: ${widget.storeName ?? 'المطعم'}';
        accentColor = DriverColors.secondary;
        break;
      case DeliveryStep.orderPickupChecklist:
        icon = Icons.storefront_rounded;
        distance = 'أمام المطعم';
        instruction = 'وصلت للمتجر: طابق وفحص الأصناف مع المطعم';
        accentColor = DriverColors.onlineGreen;
        break;
      case DeliveryStep.navigatingToCustomer:
        icon = Icons.turn_left_rounded;
        distance = '2.8 كم • 8 د';
        instruction = 'توجه إلى: ${widget.destinationAddress ?? 'عنوان الزبون'}';
        accentColor = DriverColors.primary;
        break;
      case DeliveryStep.completeDeliveryOtp:
        icon = Icons.person_pin_circle_rounded;
        distance = 'وصلت للوجهة';
        instruction = 'أمام بيت الزبون: اطلب رمز OTP وتحصيل الحساب';
        accentColor = DriverColors.onlineGreen;
        break;
      default:
        icon = Icons.navigation_rounded;
        distance = 'مباشر';
        instruction = 'ملاحة واصل النشطة في نالوت';
        accentColor = DriverColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? DriverColors.darkSurface : Colors.black87).withValues(alpha: 0.94),
        borderRadius: DriverRadius.radiusMd,
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  instruction,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  distance,
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

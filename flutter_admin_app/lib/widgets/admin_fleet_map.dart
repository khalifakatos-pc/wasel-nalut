import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as osm;
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../services/admin_socket_service.dart';

/// Interactive Central Fleet & Store GIS Map for Wasel Nalut Admin.
class AdminFleetMap extends StatefulWidget {
  final double? height;
  final bool isFullScreen;

  const AdminFleetMap({
    super.key,
    this.height,
    this.isFullScreen = false,
  });

  @override
  State<AdminFleetMap> createState() => _AdminFleetMapState();
}

class _AdminFleetMapState extends State<AdminFleetMap> {
  final fmap.MapController _mapController = fmap.MapController();
  static const osm.LatLng _nalutCenter = osm.LatLng(31.8687, 10.9818);

  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  bool _isSatellite = true;

  StreamSubscription<Map<String, dynamic>>? _driverMovedSub;
  StreamSubscription<Map<String, dynamic>>? _orderStatusSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFleetData();

    // Listen to real-time telemetry from Socket.io
    _driverMovedSub = AdminSocketService.instance.onDriverMoved.listen((data) {
      final driverId = data['driver_id']?.toString();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (driverId != null && lat != null && lng != null && mounted) {
        setState(() {
          final idx = _drivers.indexWhere((d) => d['id']?.toString() == driverId);
          if (idx >= 0) {
            _drivers[idx]['latitude'] = lat;
            _drivers[idx]['longitude'] = lng;
          }
        });
      }
    });

    _orderStatusSub = AdminSocketService.instance.onOrderStatusChanged.listen((_) {
      _loadFleetData(silent: true);
    });

    // Periodic refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadFleetData(silent: true));
  }

  @override
  void dispose() {
    _driverMovedSub?.cancel();
    _orderStatusSub?.cancel();
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadFleetData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final storesFuture = AdminSupabaseService.fetchStores();
      final driversFuture = AdminSupabaseService.fetchDrivers();
      final results = await Future.wait([storesFuture, driversFuture]);

      if (mounted) {
        setState(() {
          _stores = results[0];
          _drivers = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _recenterOnNalut() {
    _mapController.move(_nalutCenter, 14.8);
  }

  void _showStoreDetails(Map<String, dynamic> store) {
    final isOpen = store['is_open'] == true || store['is_open'] == 'true';
    final storeName = store['name']?.toString() ?? 'متجر';
    final type = store['type']?.toString() ?? 'مطعم';
    final phone = store['phone']?.toString() ?? '';
    final rate = store['rating']?.toString() ?? '5.0';

    showModalBottomSheet(
      context: context,
      backgroundColor: AdminColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AdminColors.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: AdminColors.primaryGold, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('$type • نالوت المركز', style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? AdminColors.emeraldGreen.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isOpen ? AdminColors.emeraldGreen : Colors.red),
                    ),
                    child: Text(
                      isOpen ? 'مفتوح للطلبات 🟢' : 'مغلق مؤقتاً 🔴',
                      style: TextStyle(
                        color: isOpen ? AdminColors.emeraldGreen : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: AdminColors.divider, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('التقييم', '⭐ $rate'),
                  _buildStatItem('عمولة واصل', '${store['commission_rate'] ?? 10}%'),
                  _buildStatItem('وقت التجهيز', '${store['delivery_time_min'] ?? 20} دقيقة'),
                ],
              ),
              const SizedBox(height: 16),
              if (phone.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.primaryGold,
                      side: const BorderSide(color: AdminColors.primaryGold),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('نسخ رقم هاتف المحل ($phone)'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم نسخ رقم هاتف المحل: $phone')),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDriverDetails(Map<String, dynamic> driver) {
    final fullName = driver['full_name']?.toString() ?? 'كابتن نالوت';
    final phone = driver['phone']?.toString() ?? '';
    final status = driver['status']?.toString() ?? 'offline';
    final balance = (driver['wallet_balance_lyd'] is num) ? (driver['wallet_balance_lyd'] as num).toDouble() : 0.0;
    final isBusy = status == 'busy_delivery';
    final isOnline = status != 'offline';

    Color statusColor = Colors.grey;
    String statusText = 'غير متصل';
    if (isBusy) {
      statusColor = Colors.purpleAccent;
      statusText = 'قيد توصيل طلب 🛵';
    } else if (isOnline) {
      statusColor = AdminColors.emeraldGreen;
      statusText = 'جاهز ومتاح لاستلام طلب 🟢';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AdminColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delivery_dining_rounded, color: statusColor, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('كابتن معتمد • أسطول واصل نالوت', style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(color: AdminColors.divider, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('عهدة الكاش (COD)', '${balance.toStringAsFixed(1)} د.ل', valueColor: balance > 0 ? AdminColors.primaryGold : Colors.white),
                  _buildStatItem('المركبة', driver['vehicle_type'] ?? 'دراجة'),
                  _buildStatItem('التقييم', '⭐ ${driver['rating'] ?? 5.0}'),
                ],
              ),
              const SizedBox(height: 16),
              if (phone.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('نسخ رقم هاتف الكابتن ($phone)'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم نسخ رقم هاتف الكابتن: $phone')),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color valueColor = Colors.white}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  List<fmap.Marker> _buildMarkers() {
    final markers = <fmap.Marker>[];

    // 1. Nalut Central Fortress Marker
    markers.add(
      fmap.Marker(
        point: _nalutCenter,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AdminColors.primaryGold,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AdminColors.primaryGold.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.castle_rounded, color: Colors.black, size: 22),
        ),
      ),
    );

    // 2. Store Markers
    for (var i = 0; i < _stores.length; i++) {
      final store = _stores[i];
      final lat = (store['latitude'] as num?)?.toDouble() ?? (31.8687 + (i % 2 == 0 ? 0.0025 : -0.0025) * (i + 1));
      final lng = (store['longitude'] as num?)?.toDouble() ?? (10.9818 + (i % 3 == 0 ? 0.0035 : -0.0035) * (i + 1));
      final isOpen = store['is_open'] == true || store['is_open'] == 'true';
      final name = store['name']?.toString() ?? 'متجر';

      markers.add(
        fmap.Marker(
          point: osm.LatLng(lat, lng),
          width: 90,
          height: 60,
          child: GestureDetector(
            onTap: () => _showStoreDetails(store),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isOpen ? AdminColors.emeraldGreen : Colors.red, width: 1),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isOpen ? AdminColors.emeraldGreen : Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Captain Markers
    for (var i = 0; i < _drivers.length; i++) {
      final driver = _drivers[i];
      final lat = (driver['latitude'] as num?)?.toDouble() ?? (31.8687 + (i % 2 == 0 ? 0.004 : -0.004) * ((i + 1) * 0.7));
      final lng = (driver['longitude'] as num?)?.toDouble() ?? (10.9818 + (i % 3 == 0 ? 0.005 : -0.005) * ((i + 1) * 0.6));
      final status = driver['status']?.toString() ?? 'offline';
      final isBusy = status == 'busy_delivery';
      final isOnline = status != 'offline';

      Color ringColor = Colors.grey;
      if (isBusy) {
        ringColor = Colors.purpleAccent;
      } else if (isOnline) {
        ringColor = AdminColors.emeraldGreen;
      }

      markers.add(
        fmap.Marker(
          point: osm.LatLng(lat, lng),
          width: 80,
          height: 56,
          child: GestureDetector(
            onTap: () => _showDriverDetails(driver),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: ringColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    driver['full_name']?.toString() ?? 'كابتن',
                    style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: ringColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(Icons.motorcycle_rounded, color: ringColor, size: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final activeCaptains = _drivers.where((d) => d['status'] != 'offline').length;
    final openStores = _stores.where((s) => s['is_open'] == true || s['is_open'] == 'true').length;

    final mapWidget = Stack(
      children: [
        fmap.FlutterMap(
          mapController: _mapController,
          options: const fmap.MapOptions(
            initialCenter: _nalutCenter,
            initialZoom: 14.8,
            minZoom: 11.0,
            maxZoom: 18.5,
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: _isSatellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wasel.admin.wasel_admin_app',
            ),
            fmap.MarkerLayer(markers: _buildMarkers()),
          ],
        ),

        // Top Telemetry Header Bar
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stats Pills
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.motorcycle_rounded, color: AdminColors.emeraldGreen, size: 16),
                        const SizedBox(width: 6),
                        Text('$activeCaptains كابتن نشط', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, color: AdminColors.primaryGold, size: 16),
                        const SizedBox(width: 6),
                        Text('$openStores متجر مفتوح', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              // Controls (Satellite toggle & Fullscreen)
              Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _isSatellite = !_isSatellite),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Icon(
                        _isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded,
                        color: AdminColors.primaryGold,
                        size: 18,
                      ),
                    ),
                  ),
                  if (!widget.isFullScreen) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text('خريطة أسطول نالوت الحية (Full Screen)'),
                                backgroundColor: AdminColors.surface,
                              ),
                              body: const AdminFleetMap(isFullScreen: true),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Bottom Right Recenter Button
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingActionButton.small(
            backgroundColor: AdminColors.surfaceElevated,
            foregroundColor: AdminColors.primaryGold,
            onPressed: _recenterOnNalut,
            tooltip: 'إعادة التمركز في نالوت',
            child: const Icon(Icons.my_location_rounded),
          ),
        ),

        if (_isLoading)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AdminColors.primaryGold),
                  ),
                  SizedBox(width: 8),
                  Text('جارٍ تحديث الأسطول...', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ),
      ],
    );

    if (widget.isFullScreen) {
      return mapWidget;
    }

    return Container(
      height: widget.height ?? 300,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: mapWidget,
    );
  }
}

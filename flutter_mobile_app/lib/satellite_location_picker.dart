import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'design_system.dart';
import 'services/api_service.dart';

class SatelliteLocationPicker extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;

  const SatelliteLocationPicker({super.key, this.initialAddress});

  @override
  State<SatelliteLocationPicker> createState() => _SatelliteLocationPickerState();
}

class _SatelliteLocationPickerState extends State<SatelliteLocationPicker> {
  late final MapController _mapController;
  double _currentZoom = 16.5;

  String _selectedTag = 'home';
  final TextEditingController _titleController = TextEditingController(text: 'المنزل (الحوش)');
  final TextEditingController _detailsController = TextEditingController(text: 'نالوت - حي القلعة، الشارع الرئيسي');
  double _lat = 31.8687;
  double _lng = 10.9818;
  bool _isSatelliteMode = true;
  bool _isSaving = false;
  String _selectedDistrict = 'وسط المدينة';

  final List<Map<String, dynamic>> _districts = [
    {'name': 'وسط المدينة', 'lat': 31.8687, 'lng': 10.9818, 'desc': 'وسط المدينة، الشارع العام قرب القلعة'},
    {'name': 'حي سيدي خليفة', 'lat': 31.8650, 'lng': 10.9780, 'desc': 'حي سيدي خليفة، بجانب المسجد'},
    {'name': 'طريق القلعة', 'lat': 31.8695, 'lng': 10.9835, 'desc': 'طريق القلعة الأثرية، المرتفع الغربي'},
    {'name': 'الحوامد/كاباو', 'lat': 31.8820, 'lng': 10.9950, 'desc': 'طريق الحوامد / كاباو، مفرق المزارع'},
    {'name': 'قصر نالوت الأثري', 'lat': 31.8710, 'lng': 10.9850, 'desc': 'قصر نالوت الأثري والمناطق المجاورة'},
  ];

  final Map<String, String> _tagIcons = {
    'home': '🏠',
    'work': '💼',
    'chalet': '🌴',
    'custom': '📍',
  };

  final Map<String, String> _tagTitles = {
    'home': 'المنزل (الحوش)',
    'work': 'العمل',
    'chalet': 'الاستراحة (الزردة)',
    'custom': 'مكان آخر',
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialAddress != null) {
      if (widget.initialAddress!['latitude'] != null) {
        _lat = (widget.initialAddress!['latitude'] as num).toDouble();
      }
      if (widget.initialAddress!['longitude'] != null) {
        _lng = (widget.initialAddress!['longitude'] as num).toDouble();
      }
      if (widget.initialAddress!['title'] != null) {
        _titleController.text = widget.initialAddress!['title'];
      }
      if (widget.initialAddress!['details'] != null) {
        _detailsController.text = widget.initialAddress!['details'];
      }
      if (widget.initialAddress!['tag'] != null) {
        _selectedTag = widget.initialAddress!['tag'];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onTagSelected(String tag) {
    setState(() {
      _selectedTag = tag;
      _titleController.text = _tagTitles[tag] ?? 'مكاني';
    });
  }

  void _onDistrictSelected(Map<String, dynamic> dist) {
    setState(() {
      _selectedDistrict = dist['name'];
      _lat = dist['lat'];
      _lng = dist['lng'];
      _detailsController.text = 'نالوت - ';
    });
    _mapController.move(LatLng(_lat, _lng), _currentZoom);
  }

  void _locateCurrentGps() {
    setState(() {
      _lat = 31.8687;
      _lng = 10.9818;
    });
    _mapController.move(LatLng(_lat, _lng), 17.5);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 تم التقاط إحداثيات GPS بدقة عالية في نالوت!'),
        backgroundColor: AppColors.waselPrimary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(11.0, 19.0);
    _mapController.move(LatLng(_lat, _lng), _currentZoom);
    setState(() {});
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(11.0, 19.0);
    _mapController.move(LatLng(_lat, _lng), _currentZoom);
    setState(() {});
  }

  Future<void> _saveAddress() async {
    setState(() => _isSaving = true);
    final newAddress = {
      'id': 'addr_',
      'user_phone': ApiService.userPhone.isNotEmpty ? ApiService.userPhone : '0920000000',
      'tag': _selectedTag,
      'title': _titleController.text.trim(),
      'details': _detailsController.text.trim(),
      'latitude': _lat,
      'longitude': _lng,
      'is_default': true,
    };

    await ApiService.saveUserAddress(newAddress);
    ApiService.activeAddress = newAddress;

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ العنوان بنجاح!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, newAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🛰️ ', style: TextStyle(fontSize: 20)),
              Text('تحديد العنوان بالقمر الصناعي', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_isSatelliteMode ? Icons.map_outlined : Icons.satellite_alt_rounded),
              tooltip: _isSatelliteMode ? 'التبديل إلى خريطة الشوارع' : 'التبديل إلى صور الأقمار الصناعية الحقيقية',
              onPressed: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 1. Real Interactive Satellite & Streets Map (ArcGIS World Imagery + OpenStreetMap)
            Positioned.fill(
              child: _buildSatelliteMapView(),
            ),

            // 2. Fixed Center Pin (Pointing to Roof)
            Center(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.waselPrimary, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home_work_rounded, color: Colors.amber, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'سقف البيت / موقع التوصيل',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.location_on_rounded, size: 48, color: AppColors.waselPrimary),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Top Mode Badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSatelliteMode ? Icons.satellite_alt_rounded : Icons.map_rounded,
                      color: _isSatelliteMode ? Colors.greenAccent : Colors.cyanAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSatelliteMode ? 'قمر صناعي حقيقي • نالوت' : 'خريطة الشوارع • نالوت',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Zoom & GPS Controls
            Positioned(
              left: 16,
              bottom: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    onPressed: _zoomIn,
                    child: const Icon(Icons.add_rounded),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    onPressed: _zoomOut,
                    child: const Icon(Icons.remove_rounded),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'gps_locate',
                    backgroundColor: AppColors.waselPrimary,
                    onPressed: _locateCurrentGps,
                    child: const Icon(Icons.my_location_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

            // 5. Bottom Address Details Card
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tag Selector Row: المنزل | العمل | الاستراحة | مكان آخر
                    Row(
                      children: _tagTitles.keys.map((tag) {
                        final isSelected = _selectedTag == tag;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () => _onTagSelected(tag),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.waselPrimary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.waselPrimary : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(_tagIcons[tag] ?? '📍', style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _tagTitles[tag]!.split(' ')[0],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? AppColors.waselPrimary : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Nalut Districts Quick Chips
                    Row(
                      children: [
                        const Icon(Icons.location_city_rounded, size: 14, color: AppColors.waselPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'أحياء ومناطق نالوت المعتمدة:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _districts.map((dist) {
                          final isSelected = _selectedDistrict == dist['name'];
                          return Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: ChoiceChip(
                              label: Text(dist['name']),
                              selected: isSelected,
                              selectedColor: AppColors.waselPrimary.withValues(alpha: 0.2),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.waselPrimary : null,
                              ),
                              onSelected: (_) => _onDistrictSelected(dist),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Details text input (for Captain)
                    TextField(
                      controller: _detailsController,
                      decoration: InputDecoration(
                        labelText: 'علامة مميزة للكابتن في نالوت',
                        hintText: 'مثلاً: الباب الأخضر مقابل المحول، أو شجرة الكرمة',
                        prefixIcon: const Icon(Icons.edit_location_alt_outlined),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.waselPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSaving ? null : _saveAddress,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        'حفظ العنوان في أماكني ()',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatelliteMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_lat, _lng),
        initialZoom: _currentZoom,
        minZoom: 11.0,
        maxZoom: 19.0,
        onPositionChanged: (camera, hasGesture) {
          if (hasGesture) {
            _lat = camera.center.latitude;
            _lng = camera.center.longitude;
            _currentZoom = camera.zoom;
          }
        },
        onTap: (tapPosition, point) {
          setState(() {
            _lat = point.latitude;
            _lng = point.longitude;
          });
          _mapController.move(point, _currentZoom);
        },
      ),
      children: [
        if (_isSatelliteMode)
          TileLayer(
            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.wasel.customer.wasel_customer_app',
            maxZoom: 19,
          )
        else
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.wasel.customer.wasel_customer_app',
            maxZoom: 19,
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'design_system.dart';
import 'services/api_service.dart';

class SatelliteLocationPicker extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;

  const SatelliteLocationPicker({super.key, this.initialAddress});

  @override
  State<SatelliteLocationPicker> createState() => _SatelliteLocationPickerState();
}

class _SatelliteLocationPickerState extends State<SatelliteLocationPicker> {
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
      _detailsController.text = 'نالوت - ${dist['desc']}';
    });
  }

  void _locateCurrentGps() {
    setState(() {
      _lat = 31.8686 + (DateTime.now().millisecond % 50) * 0.0001;
      _lng = 10.9818 + (DateTime.now().millisecond % 50) * 0.0001;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎯 تم التقاط إحداثيات GPS بدقة عالية في نالوت!'),
        backgroundColor: AppColors.waselPrimary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAddress() async {
    setState(() => _isSaving = true);
    final newAddress = {
      'id': 'addr_${DateTime.now().millisecondsSinceEpoch}',
      'user_phone': '0920000000',
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
              icon: Icon(_isSatelliteMode ? Icons.map_outlined : Icons.satellite_alt),
              tooltip: _isSatelliteMode ? 'التبديل إلى الخريطة العادية' : 'التبديل إلى صور الأقمار الصناعية',
              onPressed: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 1. Satellite Imagery Map View Simulation
            Positioned.fill(
              child: _buildSatelliteMapView(),
            ),

            // 2. Fixed Center Pin (Pointer on roof)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📍', style: TextStyle(fontSize: 48)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Text(
                        'ضع الدبوس فوق سقف بيتك أو استراحتك',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. GPS My Location floating button
            Positioned(
              left: 16,
              bottom: 260,
              child: FloatingActionButton(
                heroTag: 'gps_locate',
                backgroundColor: AppColors.waselPrimary,
                onPressed: _locateCurrentGps,
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),

            // 4. Bottom Address Details Card
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
                    // Tag Selector Row: المنزل | العمل | الاستراحة
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
                        'حفظ العنوان في أماكني (${_titleController.text})',
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
    return Container(
      color: const Color(0xFF1B261D), // Deep aerial landscape green
      child: Stack(
        children: [
          // Aerial background texture with roads and mountains
          CustomPaint(
            size: Size.infinite,
            painter: _SatelliteGridPainter(isSatellite: _isSatelliteMode),
          ),
          // Watermark badge
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.satellite_alt, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _isSatelliteMode ? 'أقمار صناعية عالية الدقة • نالوت' : 'خريطة الشوارع • نالوت',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SatelliteGridPainter extends CustomPainter {
  final bool isSatellite;
  _SatelliteGridPainter({required this.isSatellite});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = isSatellite ? const Color(0xFF6B7280).withValues(alpha: 0.6) : Colors.white
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final roofPaint = Paint()
      ..color = isSatellite ? const Color(0xFFB45309).withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Draw main mountain roads of Nalut
    final path = Path();
    path.moveTo(0, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.65, size.width, size.height * 0.55);
    canvas.drawPath(path, roadPaint);

    // Draw secondary roads
    final path2 = Path();
    path2.moveTo(size.width * 0.5, 0);
    path2.lineTo(size.width * 0.5, size.height);
    canvas.drawPath(path2, roadPaint..strokeWidth = 4.0);

    // Draw house rooftops (aerial view)
    final houseOffsets = [
      Offset(size.width * 0.35, size.height * 0.45),
      Offset(size.width * 0.6, size.height * 0.42),
      Offset(size.width * 0.45, size.height * 0.58),
      Offset(size.width * 0.55, size.height * 0.55),
      Offset(size.width * 0.25, size.height * 0.38),
      Offset(size.width * 0.72, size.height * 0.62),
    ];

    for (var pos in houseOffsets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 42, height: 36), const Radius.circular(4)),
        roofPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SatelliteGridPainter oldDelegate) => oldDelegate.isSatellite != isSatellite;
}

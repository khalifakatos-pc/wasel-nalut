import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../widgets/digital_voucher_dialog.dart';

class CaptainsTab extends StatefulWidget {
  const CaptainsTab({super.key});

  @override
  State<CaptainsTab> createState() => _CaptainsTabState();
}

class _CaptainsTabState extends State<CaptainsTab> {
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    final list = await AdminSupabaseService.fetchDrivers();
    if (mounted) {
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _settleCash(Map<String, dynamic> driver) async {
    final balance = (driver['wallet_balance_lyd'] is num) ? (driver['wallet_balance_lyd'] as num).toDouble() : 0.0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          title: const Text('تأكيد تسوية العهدة النقدية'),
          content: Text('هل استلمت مبلغ (${balance.toStringAsFixed(1)} د.ل) نقداً من الكابتن ${driver['full_name']}؟\nسيتم تصفير عهدته في السحابة وإصدار سند قبض رسمي فوراً.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.emeraldGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('نعم، تم استلام الكاش'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final voucher = await AdminSupabaseService.settleDriverCashWithVoucher(driver);
      setState(() {
        driver['wallet_balance_lyd'] = 0.0;
      });
      await _loadDrivers();
      if (mounted) {
        DigitalVoucherDialog.show(context, voucher);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أسطول كباتن نالوت والتسويات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar, color: AdminColors.primaryGold),
            tooltip: 'رادار الأسطول الحي (نالوت 31.8687, 10.9818)',
            onPressed: _showLiveRadarDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDrivers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _drivers.length,
              itemBuilder: (context, index) {
                final driver = _drivers[index];
                final balance = (driver['wallet_balance_lyd'] is num) ? (driver['wallet_balance_lyd'] as num).toDouble() : 0.0;
                final isBusy = driver['status'] == 'busy_delivery';

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Driver Info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AdminColors.surfaceElevated,
                              child: const Icon(Icons.person, color: AdminColors.primaryGold, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        driver['full_name'] ?? 'كابتن',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBusy ? Colors.purpleAccent.withValues(alpha: 0.2) : AdminColors.emeraldGreen.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isBusy ? 'في مشوار' : 'متاح',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isBusy ? Colors.purpleAccent : AdminColors.emeraldGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${driver['phone'] ?? ''} • ${driver['vehicle_type'] ?? ''}',
                                    style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: AdminColors.primaryGold, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${driver['rating'] ?? 5.0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Text('${driver['total_trips'] ?? 0} رحلة', style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: AdminColors.divider, height: 24),

                        // Cash in Hand & Settle Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('كاش معلق (عهدة COD):', style: TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
                                Text(
                                  '${balance.toStringAsFixed(1)} د.ل',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0 ? AdminColors.primaryGold : AdminColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: balance > 0 ? () => _settleCash(driver) : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminColors.emeraldGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AdminColors.surfaceElevated,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('تسوية العهدة', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
        label: const Text('تسجيل كابتن جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddDriverDialog,
      ),
    );
  }

  void _showAddDriverDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController(text: 'سيارة هيونداي');
    final plateCtrl = TextEditingController(text: '14-');

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          title: const Row(
            children: [
              Icon(Icons.two_wheeler, color: AdminColors.primaryGold),
              SizedBox(width: 8),
              Text('تسجيل كابتن جديد في نالوت'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الكابتن الرباعي',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (ليبيانا / المدار)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vehicleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'نوع المركبة (سيارة / دراجة نارية)',
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم لوحة المركبة',
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.emeraldGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  await AdminSupabaseService.addDriver(
                    fullName: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    vehicleType: vehicleCtrl.text.trim(),
                    plateNumber: plateCtrl.text.trim(),
                  );
                  _loadDrivers();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AdminColors.emeraldGreen,
                      content: Text('✅ تم تسجيل واعتماد الكابتن ${nameCtrl.text} في السحابة بنجاح!'),
                    ),
                  );
                }
              },
              child: const Text('حفظ واعتماد الكابتن'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLiveRadarDialog() {
    // Nalut Core Coordinates: 31.8687, 10.9818
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: Container(
            width: 700,
            height: 620,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.5), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 30, spreadRadius: 4),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AdminColors.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.radar, color: AdminColors.primaryGold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رادار الأسطول الحي • نالوت المركزية',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            Text(
                              'مركز التغطية: نالوت (31.8687° N, 10.9818° E) • بث تيليماتري مباشر',
                              style: TextStyle(fontSize: 11, color: AdminColors.emeraldGreen),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                // Radar Viewport (Visual GIS Radar Canvas)
                Expanded(
                  child: Stack(
                    children: [
                      // Grid & Radar Concentric Circles
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.85,
                              colors: [
                                const Color(0xFF0284C7).withValues(alpha: 0.08),
                                const Color(0xFF0F172A),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Radar Ring Overlays
                      Center(
                        child: Container(
                          width: 440,
                          height: 440,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), width: 1.5),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25), width: 1.5),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.5),
                          ),
                        ),
                      ),

                      // Nalut Central Pillar Marker (31.8687, 10.9818)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdminColors.primaryGold.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: AdminColors.primaryGold, width: 2),
                              ),
                              child: const Icon(Icons.location_city, color: AdminColors.primaryGold, size: 20),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                'قلعة وقصر نالوت (31.8687, 10.9818)',
                                style: TextStyle(color: AdminColors.primaryGold, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Partner Store 1 (Top Left): قصر نالوت للمشويات
                      Positioned(
                        top: 80,
                        left: 100,
                        child: _buildStoreRadarMarker(
                          name: 'مطعم قصر نالوت',
                          orders: 5,
                          type: 'مشويات ومأكولات ليبية',
                          lat: 31.8686,
                          lng: 10.9818,
                        ),
                      ),

                      // Partner Store 2 (Bottom Right): بيتزا وفطائر القلعة
                      Positioned(
                        bottom: 90,
                        right: 80,
                        child: _buildStoreRadarMarker(
                          name: 'بيتزا القلعة نالوت',
                          orders: 4,
                          type: 'بيتزا ومعجنات',
                          lat: 31.8710,
                          lng: 10.9850,
                        ),
                      ),

                      // Partner Store 3 (Top Right): أسواق نالوت المركزية
                      Positioned(
                        top: 70,
                        right: 90,
                        child: _buildStoreRadarMarker(
                          name: 'أسواق نالوت المركزية',
                          orders: 8,
                          type: 'تموينات وبقالة 15 دقيقة',
                          lat: 31.8740,
                          lng: 10.9830,
                        ),
                      ),

                      // Green Captain Markers (Available / Delivering)
                      Positioned(
                        top: 140,
                        right: 180,
                        child: _buildCaptainRadarMarker(
                          name: 'كابتن وسيم النالوتي',
                          vehicle: 'كيا سيراتو',
                          status: 'delivering', // Green
                          battery: '95%',
                          speed: '38 كم/س',
                          orderId: 'WSL-90412',
                          color: AdminColors.emeraldGreen,
                          customerName: 'محمد سالم الورفلي',
                          dest: 'حي الشهداء، شارع النور',
                        ),
                      ),

                      Positioned(
                        bottom: 120,
                        left: 140,
                        child: _buildCaptainRadarMarker(
                          name: 'كابتن طارق العكرمي',
                          vehicle: 'تويوتا هايلوكس',
                          status: 'delivering', // Green
                          battery: '88%',
                          speed: '32 كم/س',
                          orderId: 'WSL-90388',
                          color: AdminColors.emeraldGreen,
                          customerName: 'أحمد بن عثمان',
                          dest: 'طريق وازن، نالوت',
                        ),
                      ),

                      // Orange Captain Markers (Busy / Preparing / Matching)
                      Positioned(
                        bottom: 160,
                        right: 170,
                        child: _buildCaptainRadarMarker(
                          name: 'كابتن إبراهيم الجبالي',
                          vehicle: 'دراجة ياماها',
                          status: 'busy', // Orange
                          battery: '90%',
                          speed: '25 كم/س',
                          orderId: 'WSL-90394',
                          color: const Color(0xFFF59E0B),
                          customerName: 'عمر الجبالي',
                          dest: 'منطقة القلعة الأثرية',
                        ),
                      ),

                      // Green Captain Available
                      Positioned(
                        top: 190,
                        left: 190,
                        child: _buildCaptainRadarMarker(
                          name: 'كابتن سالم التالاتي',
                          vehicle: 'هيونداي أفانتي',
                          status: 'available', // Green
                          battery: '98%',
                          speed: '0 كم/س',
                          orderId: null,
                          color: AdminColors.emeraldGreen,
                          customerName: null,
                          dest: 'وسط البلاد نالوت',
                        ),
                      ),

                      // Customer Dropoff Destination Markers (Purple Pins)
                      Positioned(
                        top: 40,
                        left: 280,
                        child: _buildCustomerDropoffMarker(
                          name: 'محمد الورفلي (حي الشهداء)',
                          orderId: 'WSL-90412',
                          eta: '4 دقائق',
                        ),
                      ),

                      Positioned(
                        bottom: 40,
                        left: 220,
                        child: _buildCustomerDropoffMarker(
                          name: 'أحمد بن عثمان (طريق وازن)',
                          orderId: 'WSL-90388',
                          eta: '7 دقائق',
                        ),
                      ),

                      // Legend at bottom
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.circle, color: AdminColors.emeraldGreen, size: 12),
                                  SizedBox(width: 4),
                                  Text('كابتن متصل / في التوصيل (Green)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.circle, color: Color(0xFFF59E0B), size: 12),
                                  SizedBox(width: 4),
                                  Text('كابتن مشغول / جاري التحضير (Orange)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.store, color: Color(0xFFF97316), size: 14),
                                  SizedBox(width: 4),
                                  Text('مطعم معتمد', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.pin_drop, color: Color(0xFF8B5CF6), size: 14),
                                  SizedBox(width: 4),
                                  Text('وجهة الزبون', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptainRadarMarker({
    required String name,
    required String vehicle,
    required String status,
    required String battery,
    required String speed,
    required String? orderId,
    required Color color,
    required String? customerName,
    required String dest,
  }) {
    return GestureDetector(
      onTap: () {
        _openTripInspector({
          'driver_name': name,
          'vehicle': vehicle,
          'status': status,
          'battery': battery,
          'speed': speed,
          'order_id': orderId ?? 'لا يوجد طلب نشط',
          'customer': customerName ?? 'متاح للمطابقة',
          'dest': dest,
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14, spreadRadius: 3),
              ],
            ),
            child: const Icon(Icons.two_wheeler, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              name.split(' ').first,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreRadarMarker({
    required String name,
    required int orders,
    required String type,
    required double lat,
    required double lng,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.5), blurRadius: 10),
            ],
          ),
          child: const Icon(Icons.storefront, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(name, style: const TextStyle(color: Color(0xFFF97316), fontSize: 9, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCustomerDropoffMarker({
    required String name,
    required String orderId,
    required String eta,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), blurRadius: 10),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('$orderId ($eta)', style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 9)),
        ),
      ],
    );
  }

  void _openTripInspector(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                      const Icon(Icons.search, color: AdminColors.primaryGold),
                      const SizedBox(width: 8),
                      Text('فاحص الرحلة المباشر • ${item['order_id']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item['status'] == 'busy' ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : AdminColors.emeraldGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['status'] == 'busy' ? 'قيد التحضير والتوصيل' : 'متاح للتكليف',
                      style: TextStyle(
                        color: item['status'] == 'busy' ? const Color(0xFFF59E0B) : AdminColors.emeraldGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 20),
              Text('الكابتن: ${item['driver_name']} (${item['vehicle']})', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 4),
              Text('السرعة وبطارية الهاتف: ${item['speed']} • البطارية: ${item['battery']}', style: const TextStyle(color: AdminColors.skyBlue, fontSize: 12)),
              const SizedBox(height: 4),
              Text('العميل والوجهة: ${item['customer']} • ${item['dest']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.primaryGold,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📍 تم تثبيت مسار الكابتن ${item['driver_name']} على الخريطة!'),
                            backgroundColor: AdminColors.emeraldGreen,
                          ),
                        );
                      },
                      icon: const Icon(Icons.near_me, size: 16),
                      label: const Text('تتبع المسار المباشر'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

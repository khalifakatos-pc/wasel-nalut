import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import 'store_menu_screen.dart';

class StoresTab extends StatefulWidget {
  const StoresTab({super.key});

  @override
  State<StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<StoresTab> {
  List<Map<String, dynamic>> _stores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    final list = await AdminSupabaseService.fetchStores();
    if (mounted) {
      setState(() {
        _stores = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStore(String storeId, bool currentStatus) async {
    final newStatus = !currentStatus;
    setState(() {
      final index = _stores.indexWhere((s) => s['id'] == storeId);
      if (index != -1) {
        _stores[index]['is_open'] = newStatus;
      }
    });

    final success = await AdminSupabaseService.toggleStoreOpen(storeId, newStatus);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تعديل الحالة على السحابة')),
      );
      _loadStores();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة مطاعم ومحلات نالوت'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStores),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stores.length,
              itemBuilder: (context, index) {
                final store = _stores[index];
                final isOpen = store['is_open'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AdminColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isOpen ? AdminColors.emeraldGreen : AdminColors.alertRed),
                              ),
                              child: Center(
                                child: Text(
                                  store['type'] == 'pharmacy'
                                      ? '💊'
                                      : (store['type'] == 'pizza'
                                          ? '🍕'
                                          : (store['type'] == 'grocery' ? '🛒' : '🍔')),
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store['name'] ?? 'متجر',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${store['district'] ?? 'نالوت'} • توصيل ${store['base_delivery_fee_lyd'] ?? 5.0} د.ل',
                                    style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isOpen,
                              activeTrackColor: AdminColors.emeraldGreen,
                              activeThumbColor: Colors.white,
                              inactiveThumbColor: AdminColors.alertRed,
                              onChanged: (_) => _toggleStore(store['id'], isOpen),
                            ),
                          ],
                        ),
                        const Divider(color: AdminColors.divider, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOpen ? AdminColors.emeraldGreen : AdminColors.alertRed,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isOpen ? 'مفتوح ويستقبل طلبات' : 'مغلق مؤقتاً في التطبيق',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isOpen ? AdminColors.emeraldGreen : AdminColors.alertRed,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.key_rounded, size: 18, color: AdminColors.primaryGold),
                                  tooltip: 'بيانات دخول التاجر',
                                  onPressed: () => _showMerchantCredentialsDialog(store),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StoreMenuScreen(
                                          storeId: (store['id'] ?? 'store_1').toString(),
                                          storeName: store['name']?.toString() ?? 'المتجر',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.menu_book, size: 16, color: AdminColors.primaryGold),
                                  label: const Text('عرض المنيو', style: TextStyle(color: AdminColors.primaryGold)),
                                ),
                              ],
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
        icon: const Icon(Icons.add_business),
        label: const Text('إضافة متجر جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddStoreDialog,
      ),
    );
  }

  void _showMerchantCredentialsDialog(Map<String, dynamic> store) {
    final phone = store['phone'] ?? '0910000000';
    final pin = store['pin'] ?? '1234';
    final appMode = (store['type'] == 'grocery' || store['type'] == 'pharmacy') ? 'شاشة تجزئة Pick & Pack' : 'شاشة مطبخ KDS';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AdminColors.primaryGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بيانات دخول: ${store['name']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('يستخدم التاجر هذه البيانات لفتح تطبيق التاجر (Wasel Merchant):', style: TextStyle(color: AdminColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              _buildCredentialRow('📞 رقم هاتف الدخول', phone),
              const SizedBox(height: 8),
              _buildCredentialRow('🔑 رمز PIN السري', pin),
              const SizedBox(height: 8),
              _buildCredentialRow('📱 نمط الواجهة', appMode),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ البيانات'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'بيانات دخول متجر ${store['name']}:\nالهاتف: $phone\nرمز PIN: $pin\nالنمط: $appMode'));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📋 تم نسخ بيانات الدخول إلى الحافظة')),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.primaryGold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminColors.primaryGold)),
        ],
      ),
    );
  }

  void _showAddStoreDialog() {
    final nameCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '091');
    final pinCtrl = TextEditingController(text: '1234');
    final districtCtrl = TextEditingController(text: 'نالوت - شارع أفريقيا');
    final feeCtrl = TextEditingController(text: '5.0');
    final commissionCtrl = TextEditingController(text: '10.0');
    final minOrderCtrl = TextEditingController(text: '10.0');
    String selectedType = 'restaurant';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (statefulCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_business_rounded, color: AdminColors.primaryGold),
                SizedBox(width: 8),
                Text('إضافة متجر وتوليد حساب تاجر'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المطعم أو المحل (بالعربية)*',
                        prefixIcon: Icon(Icons.store),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameEnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالإنجليزية (اختياري)',
                        prefixIcon: Icon(Icons.translate),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: AdminColors.surfaceElevated,
                      decoration: const InputDecoration(
                        labelText: 'تصنيف النشاط ونمط العمل',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'restaurant', child: Text('مطعم / كافيه (شاشة مطبخ KDS)')),
                        DropdownMenuItem(value: 'pizza', child: Text('بيتزا ومعجنات (شاشة مطبخ KDS)')),
                        DropdownMenuItem(value: 'grocery', child: Text('سوبرماركت وبقالة (تجميع Pick & Pack)')),
                        DropdownMenuItem(value: 'pharmacy', child: Text('صيدلية (تجميع Pick & Pack)')),
                        DropdownMenuItem(value: 'bakery', child: Text('مخبز وحلويات')),
                      ],
                      onChanged: (val) => setDialogState(() => selectedType = val ?? 'restaurant'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'هاتف التاجر (للدخول)*',
                              prefixIcon: Icon(Icons.phone_android),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              labelText: 'رمز PIN*',
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: districtCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الحي / الشارع في نالوت',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: feeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'توصيل (د.ل)',
                              prefixIcon: Icon(Icons.delivery_dining),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: commissionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عمولة واصل %',
                              prefixIcon: Icon(Icons.percent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emeraldGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى كتابة اسم المتجر')),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  final storeResult = await AdminSupabaseService.addStore(
                    name: nameCtrl.text.trim(),
                    nameEn: nameEnCtrl.text.trim(),
                    type: selectedType,
                    district: districtCtrl.text.trim(),
                    baseDeliveryFee: double.tryParse(feeCtrl.text.trim()) ?? 5.0,
                    phone: phoneCtrl.text.trim(),
                    pin: pinCtrl.text.trim(),
                    commissionRate: double.tryParse(commissionCtrl.text.trim()) ?? 10.0,
                    minOrderLyd: double.tryParse(minOrderCtrl.text.trim()) ?? 10.0,
                  );
                  _loadStores();
                  if (storeResult != null && mounted) {
                    _showMerchantCredentialsDialog(storeResult);
                  }
                },
                child: const Text('حفظ وتوليد الحساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

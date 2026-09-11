import 'package:flutter/material.dart';
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
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_business),
        label: const Text('إضافة مطعم جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddStoreDialog,
      ),
    );
  }

  void _showAddStoreDialog() {
    final nameCtrl = TextEditingController();
    final districtCtrl = TextEditingController(text: 'نالوت - الحي المركزي');
    final feeCtrl = TextEditingController(text: '5.0');
    String selectedType = 'restaurant';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (statefulCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.storefront, color: AdminColors.primaryGold),
                SizedBox(width: 8),
                Text('إضافة متجر جديد في نالوت'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المطعم أو المحل',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    dropdownColor: AdminColors.surfaceElevated,
                    decoration: const InputDecoration(
                      labelText: 'نوع النشاط',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'restaurant', child: Text('مطعم / كافيه')),
                      DropdownMenuItem(value: 'grocery', child: Text('سوبرماركت / بقالة')),
                      DropdownMenuItem(value: 'bakery', child: Text('مخبز ومعجنات')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedType = val ?? 'restaurant'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: districtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الحي / الشارع في نالوت',
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سعر التوصيل الأساسي (د.ل)',
                      prefixIcon: Icon(Icons.delivery_dining),
                    ),
                  ),
                ],
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
                  if (nameCtrl.text.isNotEmpty) {
                    Navigator.pop(dialogCtx);
                    await AdminSupabaseService.addStore(
                      name: nameCtrl.text.trim(),
                      type: selectedType,
                      district: districtCtrl.text.trim(),
                      baseDeliveryFee: double.tryParse(feeCtrl.text.trim()) ?? 5.0,
                    );
                    _loadStores();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AdminColors.emeraldGreen,
                        content: Text('✅ تم إضافة ${nameCtrl.text} إلى سحابة نالوت بنجاح!'),
                      ),
                    );
                  }
                },
                child: const Text('حفظ وإضافة إلى نالوت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

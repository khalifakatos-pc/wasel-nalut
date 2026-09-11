import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class StoreMenuScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreMenuScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final list = await AdminSupabaseService.fetchProductsForStore(widget.storeId);
    if (mounted) {
      setState(() {
        _products = list;
        _isLoading = false;
      });
    }
  }

  List<String> get _categories {
    final Set<String> cats = {'الكل'};
    for (var p in _products) {
      final cat = p['category']?.toString();
      if (cat != null && cat.isNotEmpty) {
        cats.add(cat);
      }
    }
    return cats.toList();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString();

      final matchesQuery = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase());

      final matchesCat = _selectedCategory == 'الكل' || cat == _selectedCategory;

      return matchesQuery && matchesCat;
    }).toList();
  }

  Future<void> _toggleAvailability(String productId, bool currentVal) async {
    final newVal = !currentVal;
    setState(() {
      final idx = _products.indexWhere((p) => p['id'] == productId);
      if (idx != -1) {
        _products[idx]['is_available'] = newVal;
      }
    });

    final ok = await AdminSupabaseService.updateProductStock(productId, newVal);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ تعذر تحديث حالة التوفر في السحابة'),
          backgroundColor: AdminColors.alertRed,
        ),
      );
      _loadProducts();
    }
  }

  void _showEditPriceDialog(Map<String, dynamic> product) {
    final priceController = TextEditingController(
      text: (product['price'] is num ? (product['price'] as num).toDouble() : 0.0).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تعديل سعر: ${product['name']}',
          style: const TextStyle(fontSize: 16, color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السعر الجديد (د.ل):', style: TextStyle(fontSize: 13, color: AdminColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: AdminColors.surface,
                prefixIcon: const Icon(Icons.monetization_on, color: AdminColors.primaryGold),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primaryGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newPrice = double.tryParse(priceController.text.trim());
              if (newPrice == null || newPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة رقم سعر صالح')),
                );
                return;
              }

              Navigator.pop(ctx);
              setState(() {
                final idx = _products.indexWhere((p) => p['id'] == product['id']);
                if (idx != -1) {
                  _products[idx]['price'] = newPrice;
                }
              });

              final ok = await AdminSupabaseService.updateProductPrice(product['id'], newPrice);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '✅ تم تحديث السعر إلى ${newPrice.toStringAsFixed(2)} د.ل' : '❌ تعذر التحديث'),
                    backgroundColor: ok ? AdminColors.emeraldGreen : AdminColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('حفظ السعر', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descController = TextEditingController();
    String category = _categories.firstWhere((c) => c != 'الكل', orElse: () => 'مشويات جبلية');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'إضافة وجبة / صنف جديد 🍽️',
            style: TextStyle(fontSize: 16, color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اسم الوجبة / الصنف:', style: TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'مثال: وجبة كباب لحم فاخر',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: AdminColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('السعر بالدينار الليبي (د.ل):', style: TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'مثال: 25.00',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: AdminColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('التصنيف:', style: TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: AdminColors.surfaceElevated,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AdminColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: ['مشويات جبلية', 'بيتزا وفطائر', 'سندوتشات سريعة', 'مشروبات ومقبلات', 'عام']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('الوصف والمكونات:', style: TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'مثال: لحم وطني مع خضار وخبز تنور طازج',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: AdminColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.emeraldGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim());
                if (name.isEmpty || price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى كتابة الاسم وتحديد سعر صالح')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final ok = await AdminSupabaseService.addProduct(
                  storeId: widget.storeId,
                  name: name,
                  price: price,
                  category: category,
                  description: descController.text.trim(),
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '✅ تمت إضافة $name بنجاح إلى المنيو' : '❌ تعذر إضافة الصنف'),
                      backgroundColor: ok ? AdminColors.emeraldGreen : AdminColors.alertRed,
                    ),
                  );
                  _loadProducts();
                }
              },
              child: const Text('إضافة للوجبات', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الصنف من القائمة', style: TextStyle(color: AdminColors.alertRed, fontWeight: FontWeight.bold)),
        content: Text(
          'هل أنت متأكد من حذف "${product['name']}" نهائياً من قائمة المطعم؟',
          style: const TextStyle(color: AdminColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.alertRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await AdminSupabaseService.deleteProduct(product['id']);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '🗑️ تم حذف الصنف بنجاح' : '❌ تعذر حذف الصنف'),
                    backgroundColor: ok ? Colors.grey[800] : AdminColors.alertRed,
                  ),
                );
                _loadProducts();
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForProduct(String name, String cat) {
    if (name.contains('بيتزا') || cat.contains('بيتزا')) {
      return Icons.local_pizza_rounded;
    } else if (name.contains('كباب') || name.contains('مشويات') || cat.contains('مشويات')) {
      return Icons.kebab_dining_rounded;
    } else if (name.contains('ساندوتش') || name.contains('برجر') || cat.contains('سندوتشات')) {
      return Icons.lunch_dining_rounded;
    } else if (name.contains('مشروب') || name.contains('عصير') || cat.contains('مشروبات')) {
      return Icons.local_cafe_rounded;
    }
    return Icons.restaurant_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final inStockCount = _products.where((p) => p['is_available'] == true || p['is_available'] == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'قائمة الوجبات والأصناف (${_products.length} صنف)',
              style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProducts),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.emeraldGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة وجبة للمنيو', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddProductDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
          : Column(
              children: [
                // Top Store Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.primaryGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded, color: AdminColors.primaryGold, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.storeName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'نالوت • $inStockCount متاح للطلب الآن من إجمالي ${_products.length} وجبة',
                              style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن وجبة، سندوتش، أو مشروب...',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AdminColors.primaryGold),
                      filled: true,
                      fillColor: AdminColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = cat == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(cat, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12)),
                          selected: isSelected,
                          selectedColor: AdminColors.primaryGold,
                          backgroundColor: AdminColors.surface,
                          side: BorderSide(color: isSelected ? AdminColors.primaryGold : AdminColors.divider),
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Items List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fastfood_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              const Text('لا توجد أصناف مطابقة للبحث', style: TextStyle(color: AdminColors.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            final p = filtered[idx];
                            final bool isAvailable = p['is_available'] == true || p['is_available'] == null;
                            final double price = (p['price'] is num) ? (p['price'] as num).toDouble() : 0.0;
                            final String name = p['name']?.toString() ?? 'وجبة';
                            final String desc = p['description']?.toString() ?? '';
                            final String cat = p['category']?.toString() ?? 'عام';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AdminColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isAvailable ? AdminColors.divider : Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? AdminColors.emeraldGreen.withValues(alpha: 0.15)
                                              : Colors.grey.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getIconForProduct(name, cat),
                                          color: isAvailable ? AdminColors.emeraldGreen : Colors.grey,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: isAvailable ? null : TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: AdminColors.primaryGold.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Text(
                                                    cat,
                                                    style: const TextStyle(color: AdminColors.primaryGold, fontSize: 10),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (desc.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                desc,
                                                style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20, color: AdminColors.divider),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Price with edit button
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _showEditPriceDialog(p),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: AdminColors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                '${price.toStringAsFixed(2)} د.ل',
                                                style: const TextStyle(
                                                  color: AdminColors.primaryGold,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.edit, size: 14, color: AdminColors.primaryGold),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Availability Switch & Delete
                                      Row(
                                        children: [
                                          Text(
                                            isAvailable ? 'متاح للطلب' : 'غير متوفر',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isAvailable ? AdminColors.emeraldGreen : AdminColors.alertRed,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: isAvailable,
                                              activeThumbColor: AdminColors.emeraldGreen,
                                              onChanged: (_) => _toggleAvailability(p['id'], isAvailable),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white38),
                                            tooltip: 'حذف من المنيو',
                                            onPressed: () => _confirmDelete(p),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

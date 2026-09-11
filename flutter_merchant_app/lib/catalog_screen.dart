import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';

/// ============================================================================
/// MENU & INVENTORY MANAGEMENT SCREEN
/// ============================================================================

class CatalogScreen extends StatefulWidget {
  final List<CatalogProduct> catalog;
  final Function(CatalogProduct) onProductUpdated;

  const CatalogScreen({
    super.key,
    required this.catalog,
    required this.onProductUpdated,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  List<String> get _categories => [
        'الكل',
        'مشويات جبلية',
        'بيتزا ومعجنات',
        'سندوتشات وسريع',
        'مقبلات ومشروبات',
      ];

  List<CatalogProduct> get _filteredProducts {
    return widget.catalog.where((p) {
      final matchesCategory = _selectedCategory == 'الكل' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || p.nameAr.contains(_searchQuery) || p.descAr.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _toggleProductStock(CatalogProduct product) {
    setState(() {
      product.inStock = !product.inStock;
    });
    widget.onProductUpdated(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(product.inStock
            ? '🟢 تم تفعيل الصنف: ${product.nameAr} (متوفر الآن للطلب)'
            : '🔴 تم إيقاف الصنف: ${product.nameAr} (نفدت الكمية)'),
        backgroundColor: product.inStock ? MerchantColors.readyGreen : MerchantColors.rejectedRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editProductPrice(CatalogProduct product) {
    final priceController = TextEditingController(text: product.priceLyd.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MerchantColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تعديل سعر: ${product.nameAr}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السعر الجديد بالدينار الليبي (د.ل):', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                suffixText: 'د.ل',
                suffixStyle: const TextStyle(color: MerchantColors.primary, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: MerchantColors.darkSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: MerchantColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                setState(() {
                  product.priceLyd = newPrice;
                });
                widget.onProductUpdated(product);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم تحديث سعر ${product.nameAr} إلى ${newPrice.toStringAsFixed(2)} د.ل'),
                    backgroundColor: MerchantColors.readyGreen,
                  ),
                );
              }
            },
            child: const Text('حفظ السعر'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MerchantColors.darkBg,
      appBar: AppBar(
        title: const Text('قائمة الأصناف والمخزون 📋'),
        centerTitle: true,
        backgroundColor: MerchantColors.darkSurface,
        actions: [
          IconButton(
            tooltip: 'الأصناف معتمدة ومُدارة بواسطة إدارة واصل 🛡️',
            icon: const Icon(Icons.verified_user_rounded, color: MerchantColors.readyGreen, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🛡️ جميع الأصناف معتمدة ومراقبة من إدارة المنصة لضمان الجودة والصور الموحدة.'),
                  backgroundColor: MerchantColors.readyGreen,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Platform Master Catalog Verification Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: MerchantColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MerchantColors.readyGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: MerchantColors.readyGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الأصناف معتمدة مركزياً من إدارة واصل. يمكنك تفعيل/تعطيل التوفر يومياً وتعديل الأسعار.',
                    style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف أو وجبة...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                filled: true,
                fillColor: MerchantColors.darkCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Category Filter Chips
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: MerchantColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    backgroundColor: MerchantColors.darkCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Products List
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text('لا توجد أصناف مطابقة للبحث', style: TextStyle(color: Colors.white38)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MerchantColors.darkCard,
                          borderRadius: MerchantRadius.lg,
                          border: Border.all(
                            color: product.inStock ? MerchantColors.darkBorder : MerchantColors.rejectedRed.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Product Icon Box
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: product.inStock
                                    ? MerchantColors.primary.withValues(alpha: 0.15)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                product.icon,
                                color: product.inStock ? MerchantColors.primary : Colors.white38,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.nameAr,
                                    style: TextStyle(
                                      color: product.inStock ? Colors.white : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      decoration: product.inStock ? null : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    product.descAr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _editProductPrice(product),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${product.priceLyd.toStringAsFixed(2)} د.ل',
                                          style: const TextStyle(
                                            color: MerchantColors.accentAmber,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_outlined, size: 13, color: MerchantColors.accentAmber),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // In Stock Switch
                            Column(
                              children: [
                                Switch(
                                  value: product.inStock,
                                  activeThumbColor: MerchantColors.readyGreen,
                                  onChanged: (_) => _toggleProductStock(product),
                                ),
                                Text(
                                  product.inStock ? 'متوفر' : 'نفد',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: product.inStock ? MerchantColors.readyGreen : MerchantColors.rejectedRed,
                                  ),
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

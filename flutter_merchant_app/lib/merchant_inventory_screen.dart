import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';

/// ============================================================================
/// WASEL MERCHANT INVENTORY & STOCK-TAKING SCREEN (الجرد وإدارة المخزون)
/// ============================================================================

class MerchantInventoryScreen extends StatefulWidget {
  final List<CatalogProduct> catalog;
  final PartnerStore store;
  final Function(CatalogProduct) onProductUpdated;

  const MerchantInventoryScreen({
    super.key,
    required this.catalog,
    required this.store,
    required this.onProductUpdated,
  });

  @override
  State<MerchantInventoryScreen> createState() => _MerchantInventoryScreenState();
}

class _MerchantInventoryScreenState extends State<MerchantInventoryScreen> {
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  bool _isAuditMode = false; // وضع الجرد السريع

  List<String> get _categories {
    final cats = {'الكل'};
    for (final p in widget.catalog) {
      cats.add(p.category);
    }
    return cats.toList();
  }

  List<CatalogProduct> get _filteredProducts {
    return widget.catalog.where((p) {
      final matchesCategory = _selectedCategory == 'الكل' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          p.nameAr.contains(_searchQuery) ||
          p.descAr.contains(_searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  int get _inStockCount => widget.catalog.where((p) => p.inStock && p.stockQuantity > p.minStockAlert).length;
  int get _lowStockCount => widget.catalog.where((p) => p.inStock && p.stockQuantity <= p.minStockAlert).length;
  int get _outOfStockCount => widget.catalog.where((p) => !p.inStock || p.stockQuantity == 0).length;

  void _toggleProductStock(CatalogProduct product) {
    setState(() {
      product.inStock = !product.inStock;
      if (product.inStock && product.stockQuantity == 0) {
        product.stockQuantity = 10;
      }
    });
    widget.onProductUpdated(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          product.inStock
              ? '🟢 تم تفعيل: ${product.nameAr} (متوفر للطلب في نالوت)'
              : '🔴 تم إيقاف: ${product.nameAr} (نفدت الكمية من المتجر)',
        ),
        backgroundColor: product.inStock ? MerchantColors.readyGreen : MerchantColors.rejectedRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _adjustQuantity(CatalogProduct product, int delta) {
    setState(() {
      product.stockQuantity = (product.stockQuantity + delta).clamp(0, 999);
      if (product.stockQuantity == 0) {
        product.inStock = false;
      } else if (!product.inStock && product.stockQuantity > 0) {
        product.inStock = true;
      }
    });
    widget.onProductUpdated(product);
  }

  void _showSetQuantityDialog(CatalogProduct product) {
    final controller = TextEditingController(text: product.stockQuantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MerchantColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تعديل كمية جرد: ${product.nameAr}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الكمية الفعلية المتوفرة بالمخزن أو المطبخ:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              decoration: InputDecoration(
                filled: true,
                fillColor: MerchantColors.darkSurface,
                suffixText: 'قطعة / وجبة',
                suffixStyle: const TextStyle(color: MerchantColors.primary, fontSize: 12),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: MerchantColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newQty = int.tryParse(controller.text);
              if (newQty != null && newQty >= 0) {
                setState(() {
                  product.stockQuantity = newQty;
                  product.inStock = newQty > 0;
                });
                widget.onProductUpdated(product);
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ الكمية'),
          ),
        ],
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
        title: Text(
          'تعديل سعر: ${product.nameAr}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السعر بالدينار الليبي (د.ل):', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: MerchantColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice > 0) {
                setState(() {
                  product.priceLyd = newPrice;
                });
                widget.onProductUpdated(product);
              }
              Navigator.pop(ctx);
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
      body: SafeArea(
        child: Column(
          children: [
            // Top Metrics Header
            _buildMetricsHeader(),

            // Search Bar & Audit Mode Switch
            _buildControlsBar(),

            // Category Filter Chips
            _buildCategoryChips(),

            // Products List
            Expanded(
              child: _buildProductsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: MerchantColors.darkCard,
      child: Row(
        children: [
          _buildCountBadge('إجمالي الأصناف', widget.catalog.length.toString(), Colors.white70),
          const SizedBox(width: 8),
          _buildCountBadge('متوفر', _inStockCount.toString(), MerchantColors.readyGreen),
          const SizedBox(width: 8),
          _buildCountBadge('قارب النفاد', _lowStockCount.toString(), MerchantColors.accentAmber),
          const SizedBox(width: 8),
          _buildCountBadge('نفد', _outOfStockCount.toString(), MerchantColors.rejectedRed),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'بحث في أصناف ${widget.store.name}...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
                filled: true,
                fillColor: MerchantColors.darkCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MerchantColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: MerchantColors.darkBorder),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const SizedBox(width: 10),
          // Audit Mode Toggle Button
          FilterChip(
            selected: _isAuditMode,
            avatar: Icon(
              Icons.checklist_rounded,
              size: 16,
              color: _isAuditMode ? Colors.white : Colors.white70,
            ),
            label: Text(
              _isAuditMode ? 'إنهاء الجرد' : 'جرد سريع',
              style: TextStyle(
                color: _isAuditMode ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            selectedColor: MerchantColors.primary,
            backgroundColor: MerchantColors.darkCard,
            side: BorderSide(
              color: _isAuditMode ? MerchantColors.primary : MerchantColors.darkBorder,
            ),
            onSelected: (val) {
              setState(() => _isAuditMode = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val
                        ? '📋 تم تفعيل وضع الجرد السريع: يمكنك الآن تعديل الكميات بسهولة'
                        : '✅ تم حفظ واعتماد بيانات الجرد',
                  ),
                  backgroundColor: val ? MerchantColors.primary : MerchantColors.readyGreen,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(cat, style: const TextStyle(fontSize: 11)),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selectedColor: MerchantColors.primary,
              backgroundColor: MerchantColors.darkCard,
              side: BorderSide(
                color: isSelected ? MerchantColors.primary : MerchantColors.darkBorder,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsList() {
    final list = _filteredProducts;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            const Text(
              'لا توجد أصناف مطابقة للبحث',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final product = list[i];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(CatalogProduct product) {
    final isLow = product.isLowStock;
    final isOut = !product.inStock || product.stockQuantity == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MerchantColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? MerchantColors.rejectedRed.withValues(alpha: 0.4)
              : (isLow
                  ? MerchantColors.accentAmber.withValues(alpha: 0.4)
                  : MerchantColors.darkBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOut
                      ? MerchantColors.rejectedRed.withValues(alpha: 0.12)
                      : MerchantColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  product.icon,
                  color: isOut ? MerchantColors.rejectedRed : MerchantColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nameAr,
                      style: TextStyle(
                        color: isOut ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: isOut ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Status Badge
              if (isOut)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MerchantColors.rejectedRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'نفدت الكمية 🚫',
                    style: TextStyle(color: MerchantColors.rejectedRed, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else if (isLow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MerchantColors.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'قارب النفاد ⚠️',
                    style: TextStyle(color: MerchantColors.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          const Divider(color: MerchantColors.darkBorder, height: 20),

          // Price and Quantity Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Price
              InkWell(
                onTap: () => _editProductPrice(product),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '${product.priceLyd.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(
                          color: MerchantColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 14, color: Colors.white38),
                    ],
                  ),
                ),
              ),

              // Stock Stepper / Audit Controls
              Row(
                children: [
                  const Text('المخزون:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: Colors.white60),
                    onPressed: () => _adjustQuantity(product, -1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showSetQuantityDialog(product),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MerchantColors.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MerchantColors.darkBorder),
                      ),
                      child: Text(
                        '${product.stockQuantity}',
                        style: TextStyle(
                          color: isOut
                              ? MerchantColors.rejectedRed
                              : (isLow ? MerchantColors.accentAmber : Colors.white),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Colors.white60),
                    onPressed: () => _adjustQuantity(product, 1),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),

                  // Stock Toggle Switch
                  Switch(
                    value: product.inStock,
                    activeTrackColor: MerchantColors.readyGreen.withValues(alpha: 0.5),
                    activeThumbColor: MerchantColors.readyGreen,
                    inactiveThumbColor: MerchantColors.rejectedRed,
                    inactiveTrackColor: MerchantColors.rejectedRed.withValues(alpha: 0.3),
                    onChanged: (_) => _toggleProductStock(product),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

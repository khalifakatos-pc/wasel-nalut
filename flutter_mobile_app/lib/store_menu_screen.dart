import 'dart:async';
import 'package:flutter/material.dart';
import 'design_system.dart';
import 'cart_checkout_screen.dart';
import 'product_detail_sheet.dart';
import 'services/api_service.dart';
import 'widgets/motion_widgets.dart';

/// ============================================================================
/// WASEL STORE & RESTAURANT MENU SCREEN (قائمة المتجر الحقيقية - نالوت)
/// ============================================================================
class StoreMenuScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreMenuScreen({super.key, required this.store});

  @override
  State<StoreMenuScreen> createState() => _StoreMenuScreenState();
}

class _StoreMenuScreenState extends State<StoreMenuScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  late bool _isOpen;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    final rawOpen = widget.store['is_open'];
    _isOpen = rawOpen != false && rawOpen != 'false' && rawOpen != 0;
    CartService.cartCountNotifier.addListener(_onCartUpdated);
    _loadMenu();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshStoreStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    CartService.cartCountNotifier.removeListener(_onCartUpdated);
    super.dispose();
  }

  void _onCartUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshStoreStatus() async {
    final storeId = widget.store['id']?.toString() ?? 'store_nalut_01';
    try {
      final res = await ApiService.getStores();
      if (mounted && res.isSuccess && res.data != null && res.data['data'] != null) {
        final List<dynamic> list = res.data['data'];
        final current = list.firstWhere(
          (s) => s['id']?.toString() == storeId,
          orElse: () => null,
        );
        if (current != null) {
          final rawOpen = current['is_open'];
          final isOpenNow = rawOpen != false && rawOpen != 'false' && rawOpen != 0;
          if (isOpenNow != _isOpen) {
            setState(() {
              _isOpen = isOpenNow;
            });
          }
        }
      }

      // Also silently re-fetch store menu to sync out-of-stock items in real-time
      final menuRes = await ApiService.getStoreMenu(storeId);
      if (mounted && menuRes.isSuccess && menuRes.data != null && menuRes.data['data'] != null) {
        final rawProducts = menuRes.data['data']['products'];
        if (rawProducts is List && rawProducts.isNotEmpty) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(rawProducts);
          });
        }
      }
    } catch (_) {}
  }

  bool _isProductInStock(Map<String, dynamic> product) {
    if (!_isOpen) return false;
    final inStock = product['in_stock'];
    final isAvailable = product['is_available'];
    final stockQty = product['stock_quantity'] ?? product['quantity'];
    if (inStock == false || inStock == 'false' || inStock == 0) return false;
    if (isAvailable == false || isAvailable == 'false' || isAvailable == 0) return false;
    if (stockQty != null && (stockQty is num) && stockQty <= 0) return false;
    return true;
  }

  int? _getProductQuantity(Map<String, dynamic> product) {
    final stockQty = product['stock_quantity'] ?? product['quantity'];
    if (stockQty != null && stockQty is num) {
      return stockQty.toInt();
    }
    return null;
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    _refreshStoreStatus();
    final storeId = widget.store['id']?.toString() ?? 'store_nalut_01';
    final res = await ApiService.getStoreMenu(storeId);

    if (mounted) {
      if (res.isSuccess && res.data != null && res.data['data'] != null) {
        final rawProducts = res.data['data']['products'];
        if (rawProducts is List && rawProducts.isNotEmpty) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(rawProducts);
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback authentic Libyan catalog if store items not seeded yet
      setState(() {
        _products = _getFallbackProducts(storeId);
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFallbackProducts(String storeId) {
    if (storeId == 'store_nalut_02') {
      return [
        {
          'id': 'prod_04',
          'name_ar': 'بيتزا تونة بالجبنة وزيتون نالوت عائلي',
          'price_lyd': 22.00,
          'desc_ar': 'بيتزا إيطالية محشوة بقطع التونة وجبنة الموزاريلا وزيتون الجبل',
          'in_stock': true,
          'is_popular': true,
          'unit': 'عائلي',
        },
        {
          'id': 'prod_05',
          'name_ar': 'سندوتش شاورما عربي دجاج مع ثومية',
          'price_lyd': 12.00,
          'desc_ar': 'سندوتش شاورما بخبز الصاج مع الثومية والبطاطا المقرمشة',
          'in_stock': true,
          'is_popular': true,
          'unit': 'وجبة',
        },
        {
          'id': 'prod_13',
          'name_ar': 'بيتزا شاورما لحم وطني بالجبنة',
          'price_lyd': 25.00,
          'desc_ar': 'صلصة طماطم خاصة، شرائح شاورما لحم بلدي، جبنة موزاريلا وصوص طحينة',
          'in_stock': true,
          'is_popular': true,
          'unit': 'كبير',
        },
        {
          'id': 'prod_16',
          'name_ar': 'فطيرة جبنة وزعتر جبلي ساخنة',
          'price_lyd': 6.00,
          'desc_ar': 'فطيرة مخبوزة في الفرن بجبنة الحلوم والزعتر الجبلي البري',
          'in_stock': true,
          'is_popular': false,
          'unit': 'قطعة',
        },
      ];
    } else if (storeId == 'store_nalut_03') {
      return [
        {
          'id': 'prod_20',
          'name_ar': 'صندوق مياه نالوت المعدنية (12 قارورة 1.5 لتر)',
          'price_lyd': 12.00,
          'desc_ar': 'صندوق مياه شرب نالوت النقية 12 عبوة عائلية',
          'in_stock': true,
          'is_popular': true,
          'unit': 'صندوق',
        },
        {
          'id': 'prod_21',
          'name_ar': 'كرتونة حليب معقم كامل الدسم (12 عبوة)',
          'price_lyd': 18.00,
          'desc_ar': 'حليب معقم كامل الدسم صحي ومغذي',
          'in_stock': true,
          'is_popular': true,
          'unit': 'كرتونة',
        },
        {
          'id': 'prod_22',
          'name_ar': 'سلة خضار مشكلة طازجة (طماطم، خيار، بطاطا)',
          'price_lyd': 15.00,
          'desc_ar': 'تشكيلة خضروات طازجة يومية من مزارع الجبل',
          'in_stock': true,
          'is_popular': true,
          'unit': 'سلة',
        },
        {
          'id': 'prod_27',
          'name_ar': 'زيت زيتون نالوت الحر النخب الأول (5 لتر)',
          'price_lyd': 135.00,
          'desc_ar': 'زيت زيتون بكر ممتاز معصور على البارد من أشجار نالوت',
          'in_stock': true,
          'is_popular': true,
          'unit': 'صفيحة',
        },
      ];
    }

    // Default: store_nalut_01 (مطعم قصر نالوت)
    return [
      {
        'id': 'prod_01',
        'name_ar': 'صحن مشكل كباب وشقف لحم وطني',
        'price_lyd': 34.00,
        'desc_ar': 'مشكل كباب وشقف لحم خروف بلدي مشوي على الفحم مع الخبز والبطاطا والسلاطة',
        'in_stock': true,
        'is_popular': true,
        'unit': 'صحن',
      },
      {
        'id': 'prod_02',
        'name_ar': 'أسياخ كباب لحم خروف (4 قطع)',
        'price_lyd': 28.00,
        'desc_ar': 'أربعة أسياخ كباب لحم وطني متبل على الطريقة الليبية التقليدية',
        'in_stock': true,
        'is_popular': true,
        'unit': 'وجبة',
      },
      {
        'id': 'prod_03',
        'name_ar': 'سلطة مشوية بزيت زيتون نالوت الحر',
        'price_lyd': 8.00,
        'desc_ar': 'سلطة مشوية على الفحم مع فلفل وثوم وزيت زيتون الجبل الأصلي',
        'in_stock': true,
        'is_popular': false,
        'unit': 'صحن',
      },
      {
        'id': 'prod_06',
        'name_ar': 'شقف لحم خروف مشوي على الفحم',
        'price_lyd': 36.00,
        'desc_ar': 'قطع لحم خروف بلدي طازجة مشوية على الجمر مع تتبيلة الجبل الخاصة',
        'in_stock': true,
        'is_popular': true,
        'unit': 'وجبة',
      },
      {
        'id': 'prod_08',
        'name_ar': 'نصف دجاجة شواية مع أرز أصفر وبطاطا',
        'price_lyd': 18.00,
        'desc_ar': 'دجاج وطني متبل ومحمر مع أرز مبوخ بالزعفران وبطاطا مقرمشة',
        'in_stock': true,
        'is_popular': true,
        'unit': 'وجبة',
      },
    ];
  }

  void _openProductCustomization(Map<String, dynamic> product) {
    if (!_isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          content: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عذراً، هذا المتجر مغلق مؤقتاً ولا يستقبل طلبات جديدة حالياً.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (!_isProductInStock(product)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          content: const Row(
            children: [
              Icon(Icons.remove_shopping_cart_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'عذراً، هذا الصنف نفدت كميته ولم يعد متوفراً حالياً.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final title = product['name_ar'] ?? product['name'] ?? 'صنف';
    final price = (product['price_lyd'] as num?)?.toDouble() ?? (product['price'] as num?)?.toDouble() ?? 10.0;
    final cat = product['category'] ?? 'سندوتشات ووجبات';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailSheet(
        title: title,
        basePrice: price,
        category: cat,
        isFood: true,
        onAddToCart: (itemDetails) {
          final item = CartItem(
            id: itemDetails['id']?.toString() ?? product['id']?.toString() ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
            title: itemDetails['title']?.toString() ?? title,
            storeName: widget.store['name'] ?? 'متجر واصل',
            price: (itemDetails['totalPrice'] as num?)?.toDouble() ?? (itemDetails['price'] as num?)?.toDouble() ?? price,
            quantity: (itemDetails['quantity'] as num?)?.toInt() ?? 1,
            selectedAddons: (itemDetails['selectedAddons'] as List?)?.map((e) => e.toString()).toList() ?? const [],
            spiceLevel: itemDetails['spiceLevel']?.toString(),
            exclusions: (itemDetails['exclusions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
            notes: itemDetails['notes']?.toString(),
          );
          CartService.addItem(item);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.waselPrimary,
              duration: const Duration(seconds: 2),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تمت إضافة $title بتخصيصاتك إلى السلة!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    _openProductCustomization(product);
  }

  double get _cartTotal => CartService.subtotal;
  int get _cartCount => CartService.count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeName = widget.store['name'] ?? 'متجر نالوت';
    final rating = widget.store['rating']?.toString() ?? '4.9';
    final timeMin = widget.store['delivery_time_min']?.toString() ?? '20';
    final timeMax = widget.store['delivery_time_max']?.toString() ?? '35';
    final deliveryFee = widget.store['base_delivery_fee_lyd']?.toString() ?? '5.00';
    final minOrder = widget.store['min_order_lyd']?.toString() ?? '15.00';
    final district = widget.store['district'] ?? 'نالوت';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar with store cover
            SliverAppBar(
              expandedHeight: 200.0,
              pinned: true,
              backgroundColor: AppColors.waselPrimary,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.waselGradient,
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant_rounded, size: 80, color: Colors.white30),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      left: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isOpen ? AppColors.success : Colors.red.shade700,
                              borderRadius: AppRadius.radiusSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isOpen ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isOpen ? 'مفتوح ويستقبل الطلبات في نالوت 🟢' : 'مغلق مؤقتاً ولا يستقبل طلبات 🔴',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            storeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            district,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Store Info Bar (Rating, Time, Fee, Min Order)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: AppRadius.radiusLg,
                  boxShadow: AppShadows.subtle,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(Icons.star_rounded, AppColors.gold, rating, 'التقييم'),
                    _buildDivider(isDark),
                    _buildInfoItem(Icons.timer_rounded, AppColors.waselPrimary, '$timeMin-$timeMax د', 'وقت التوصيل'),
                    _buildDivider(isDark),
                    _buildInfoItem(Icons.delivery_dining_rounded, AppColors.jetPrimary, '$deliveryFee د.ل', 'التوصيل'),
                    _buildDivider(isDark),
                    _buildInfoItem(Icons.shopping_bag_outlined, Colors.purple, '$minOrder د.ل', 'أقل طلب'),
                  ],
                ),
              ),
            ),

            // Prominent Store Closed Warning Banner
            if (!_isOpen)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المتجر مغلق حالياً 🔴',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'يمكنك تصفح قائمة الوجبات والأسعار، ولكن تم إيقاف استقبال الطلبات مؤقتاً بطلب من إدارة المتجر.',
                              style: TextStyle(color: Colors.redAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, color: AppColors.waselPrimary),
                    const SizedBox(width: 8),
                    const Text(
                      'قائمة الوجبات والأصناف المتاحة',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${_products.length} صنف',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            // Products List
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.waselPrimary),
                ),
              )
            else if (_products.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('لا توجد أصناف معروضة حالياً لهذا المتجر'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = _products[index];
                      return _buildProductCard(p, isDark);
                    },
                    childCount: _products.length,
                  ),
                ),
              ),
          ],
        ),

        // Bottom Floating Cart Bar
        bottomNavigationBar: _cartCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.waselPrimary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shopping_bag_rounded, color: AppColors.waselPrimary, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$_cartCount',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.waselPrimary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي الطلب', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            '${_cartTotal.toStringAsFixed(2)} د.ل',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.waselPrimary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _isOpen
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CartCheckoutScreen(
                                      initialCartItems: CartService.items,
                                      storeId: widget.store['id']?.toString() ?? 'store_nalut_01',
                                      storeName: storeName,
                                    ),
                                  ),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.red.shade700,
                                    content: const Text(
                                      'عذراً، هذا المتجر مغلق مؤقتاً ولا يمكن إتمام الطلب الآن.',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isOpen ? AppColors.waselPrimary : Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _isOpen ? 'متابعة الشراء' : 'المتجر مغلق',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Icon(_isOpen ? Icons.arrow_forward_ios_rounded : Icons.lock_outline_rounded, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isDark) {
    final title = product['name_ar'] ?? product['name'] ?? 'صنف';
    final desc = product['desc_ar'] ?? product['desc'] ?? '';
    final price = (product['price_lyd'] as num?)?.toDouble() ?? (product['price'] as num?)?.toDouble() ?? 0.0;
    final inStock = _isProductInStock(product);
    final remainingQty = _getProductQuantity(product);
    final isPopular = product['is_popular'] == true;

    return WaselBouncyPressable(
      behavior: HitTestBehavior.opaque,
      pressedScale: 0.98,
      onTap: (_isOpen && inStock) ? () => _addToCart(product) : null,
      child: Opacity(
        opacity: (!_isOpen || !inStock) ? 0.65 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: !_isOpen
                  ? Colors.red.withValues(alpha: 0.2)
                  : (!inStock
                      ? Colors.orange.withValues(alpha: 0.3)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPopular)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.waselPrimary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: const Text(
                        '🔥 الأكثر طلباً في نالوت',
                        style: TextStyle(color: AppColors.waselPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (remainingQty != null && remainingQty > 0 && remainingQty <= 3)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: Text(
                        '⚠️ متبقي $remainingQty قطع فقط',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: (!_isOpen || !inStock) ? Colors.grey.shade600 : null,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${price.toStringAsFixed(2)} د.ل',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: (_isOpen && inStock) ? AppColors.waselPrimary : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!_isOpen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.18),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      'مغلق',
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else if (inStock)
              ElevatedButton.icon(
                onPressed: () => _addToCart(product),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('إضافة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.waselPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                  elevation: 0,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🔴 نفد المخزون',
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}

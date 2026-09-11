import 'package:flutter/material.dart';
import 'design_system.dart';
import 'cart_checkout_screen.dart';
import 'services/api_service.dart';

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
  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
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

  void _addToCart(Map<String, dynamic> product) {
    final existingIndex = _cartItems.indexWhere((i) => i.id == product['id']);
    setState(() {
      if (existingIndex != -1) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(
          CartItem(
            id: product['id']?.toString() ?? 'item_${DateTime.now().millisecondsSinceEpoch}',
            title: product['name_ar'] ?? product['name'] ?? 'صنف',
            storeName: widget.store['name'] ?? 'متجر واصل',
            price: (product['price_lyd'] as num?)?.toDouble() ?? (product['price'] as num?)?.toDouble() ?? 10.0,
            quantity: 1,
            selectedAddons: [],
          ),
        );
      }
    });

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
                'تمت إضافة ${product['name_ar'] ?? 'الصنف'} إلى السلة!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _cartTotal => _cartItems.fold(0.0, (sum, i) => sum + i.total);
  int get _cartCount => _cartItems.fold(0, (sum, i) => sum + i.quantity);

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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: AppRadius.radiusSm,
                            ),
                            child: const Text(
                              '🟢 مفتوح ويستقبل الطلبات في نالوت',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
        bottomNavigationBar: _cartItems.isNotEmpty
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CartCheckoutScreen(
                                initialCartItems: _cartItems,
                                storeId: widget.store['id']?.toString() ?? 'store_nalut_01',
                                storeName: storeName,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.waselPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                        ),
                        child: const Row(
                          children: [
                            Text('متابعة الشراء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
    final inStock = product['in_stock'] != false;
    final isPopular = product['is_popular'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.waselPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (inStock)
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
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusMd,
              ),
              child: const Text(
                'نفد المخزون',
                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

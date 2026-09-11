import 'models/referral_model.dart';
import 'services/referral_service.dart';
import 'package:flutter/material.dart';
import 'design_system.dart';
import 'order_tracking_screen.dart';
import 'satellite_location_picker.dart';
import 'services/api_service.dart';

class CartItem {
  final String id;
  final String title;
  final String storeName;
  final double price;
  int quantity;
  final List<String> selectedAddons;
  final String? image;

  CartItem({
    required this.id,
    required this.title,
    required this.storeName,
    required this.price,
    this.quantity = 1,
    this.selectedAddons = const [],
    this.image,
  });

  double get total => price * quantity;
}

class CartCheckoutScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final List<CartItem>? initialCartItems;
  final String? storeId;
  final String? storeName;

  const CartCheckoutScreen({
    super.key,
    this.onBackToHome,
    this.initialCartItems,
    this.storeId,
    this.storeName,
  });

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  late List<CartItem> _cartItems;
  int _userLoyaltyPoints = 140;
  bool _usePointsDiscount = false;
  double get _pointsDiscountAmount => _usePointsDiscount ? 5.00 : 0.00;
  bool _useFreeDeliveryVoucher = false;
  List<FreeDeliveryVoucher> _availableFreeDeliveryVouchers = [];

  @override
  void initState() {
    super.initState();
    _cartItems = widget.initialCartItems != null
        ? List<CartItem>.from(widget.initialCartItems!)
        : [];
    ReferralService.getActiveVouchers().then((vouchers) {
      if (mounted && vouchers.isNotEmpty) {
        setState(() {
          _availableFreeDeliveryVouchers = vouchers;
        });
      }
    });
    ApiService.getLoyaltyPoints().then((pts) {
      if (mounted) setState(() => _userLoyaltyPoints = pts);
    });
  }

  String _selectedPaymentMethod = 'cod';
  String get _selectedAddress => '${ApiService.activeAddress['title'] ?? 'المنزل'} • ${ApiService.activeAddress['details'] ?? 'نالوت - حي القلعة'}';
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _alternatePhoneController = TextEditingController();
  double _discountAmount = 0.0;
  bool _isCouponApplied = false;
  String? _couponMessage;

  final double _deliveryFee = 3.00;
  final double _serviceFee = 1.00;

  double get _subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.total);
  double get _effectiveDeliveryFee => _useFreeDeliveryVoucher ? 0.00 : _deliveryFee;
  double get _grandTotal => (_subtotal + _effectiveDeliveryFee + _serviceFee - _discountAmount - _pointsDiscountAmount).clamp(0.0, double.infinity);

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code.startsWith('FREE-') || code == 'FREEDELIVERY') {
      setState(() {
        _useFreeDeliveryVoucher = true;
        _isCouponApplied = true;
        _couponMessage = 'تم تطبيق كوبون التوصيل المجاني! خصم 100% على التوصيل 🛵';
      });
      return;
    }
    if (code == 'WASEL2026' || code == 'NALUT50' || code == 'WASEL' || code.startsWith('WAS-')) {
      setState(() {
        _discountAmount = 5.00;
        _isCouponApplied = true;
        _couponMessage = code.startsWith('WAS-')
            ? 'تم تفعيل كود دعوة صديق! خصم 5.00 د.ل على طلبك الأول 🎉'
            : 'تم تطبيق خصم واصل بقيمة 5.00 د.ل بنجاح! 🎉';
      });
    } else {
      setState(() {
        _discountAmount = 0.0;
        _isCouponApplied = false;
        _couponMessage = 'كود الخصم غير صالح أو منتهي الصلاحية';
      });
    }
  }

  void _incrementItem(int index) {
    setState(() {
      _cartItems[index].quantity++;
    });
  }

  void _decrementItem(int index) {
    setState(() {
      if (_cartItems[index].quantity > 1) {
        _cartItems[index].quantity--;
      } else {
        _cartItems.removeAt(index);
      }
    });
  }

  Future<void> _placeOrder() async {
    if (_cartItems.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.waselPrimary),
      ),
    );

    final itemsPayload = _cartItems.map((item) => {
      'name': item.title,
      'price': item.price,
      'quantity': item.quantity,
      'addons': item.selectedAddons,
    }).toList();

    final result = await ApiService.checkout(
      items: itemsPayload,
      storeId: widget.storeId ?? 'store_nalut_01',
      deliveryLocation: {
        'latitude': (ApiService.activeAddress['latitude'] as num?)?.toDouble() ?? 31.8686,
        'longitude': (ApiService.activeAddress['longitude'] as num?)?.toDouble() ?? 10.9818,
      },
      paymentMethod: _selectedPaymentMethod,
      couponCode: null,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading indicator
    }

    if (_usePointsDiscount) {
      await ApiService.deductLoyaltyPoints(100);
    }
    await ApiService.addLoyaltyPoints(_subtotal.toInt());

    final String orderNum = result.data?['order_number'] ?? 'WAS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final String? createdOrderId = result.data?['order_id'];

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'تم تأكيد الطلب وحفظه في السحابة!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الطلب: #$orderNum\nتم حجز المشوار وإرسال الإشعار للمطعم والكابتن الأقرب في نالوت.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _cartItems.clear();
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(
                        orderId: createdOrderId,
                        orderNumber: orderNum,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.waselPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('تتبع الطلب مباشرة على الخريطة'),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('سلة الشراء'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.waselPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.waselPrimary),
              ),
              const SizedBox(height: 16),
              const Text(
                'سلة الشراء فارغة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'استكشف المطاعم والمتاجر وأضف وجباتك المفضلة',
                style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: widget.onBackToHome ?? () => Navigator.pop(context),
                icon: const Icon(Icons.restaurant_rounded),
                label: const Text('تصفح المطاعم الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.waselPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المشتريات والدفع'),
        centerTitle: true,
        leading: widget.onBackToHome != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBackToHome,
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. STORE HEADER
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.waselPrimary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: AppColors.waselPrimary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cartItems.first.storeName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'وقت التجهيز والتوصيل: 25-35 دقيقة',
                        style: TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. ITEMS LIST
          const Text(
            'الأصناف المطلوبة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),

          ...List.generate(_cartItems.length, (index) {
            final item = _cartItems[index];
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${item.total.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.waselPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (item.selectedAddons.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.selectedAddons.join(' • '),
                      style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.price.toStringAsFixed(2)} د.ل للقطعة',
                        style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: AppRadius.radiusMd,
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                item.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                size: 18,
                                color: item.quantity == 1 ? AppColors.error : null,
                              ),
                              onPressed: () => _decrementItem(index),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 18),
                              onPressed: () => _incrementItem(index),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.md),

          // 3. DELIVERY ADDRESS
          const Text(
            'عنوان التوصيل',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.waselPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAddress,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'موقع دقيق ومحدد على الخريطة',
                        style: TextStyle(fontSize: 10, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAddressPicker(context),
                  icon: const Icon(Icons.satellite_alt, size: 16),
                  label: const Text('تغيير / قمر صناعي'),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 3.1 ALTERNATE BACKUP PHONE (FOR NALUT COVERAGE)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_in_talk_rounded, color: AppColors.waselPrimary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'رقم هاتف بديل (احتياطي للطوارئ)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'لضمان وصول الكابتن في حال ضعف تغطية المدار أو ليبيانا في الجبل',
                  style: TextStyle(fontSize: 10, color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _alternatePhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'رقم الشبكة الأخرى (مثال: 0921234567 أو 091...)',
                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                    filled: true,
                    fillColor: isDark ? AppColors.darkBackground : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusMd,
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 4. PROMO CODE
          const Text(
            'كوبون الخصم',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'أدخل كود الخصم (مثال: WASEL2026)',
                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusMd,
                      borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                onPressed: _applyCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.waselPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                ),
                child: const Text('تطبيق'),
              ),
            ],
          ),
          if (_couponMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _couponMessage!,
              style: TextStyle(
                fontSize: 11,
                color: _isCouponApplied ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // 4.5 LOYALTY POINTS REDEMPTION
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
              ),
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'نقاط واصل للمكافآت',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_userLoyaltyPoints نقطة',
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userLoyaltyPoints >= 100
                            ? 'استبدل 100 نقطة بخصم 5.00 د.ل مباشر من الفاتورة'
                            : 'اجمع 100 نقطة لتحصل على خصم 5 د.ل على طلباتك',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
                if (_userLoyaltyPoints >= 100)
                  Switch(
                    value: _usePointsDiscount,
                    activeTrackColor: const Color(0xFFD97706),
                    onChanged: (val) {
                      setState(() {
                        _usePointsDiscount = val;
                      });
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 4.6 FREE DELIVERY VOUCHERS (EARNED FROM REFERRALS)
          if (_availableFreeDeliveryVouchers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                ),
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.electric_moped_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'كوبون توصيل مجاني 🛵',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'هدية الإحالة 🎁',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'لديك ${_availableFreeDeliveryVouchers.length} كوبون توصيل مجاني متاح للاستخدام!',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useFreeDeliveryVoucher,
                    activeTrackColor: const Color(0xFF059669),
                    onChanged: (val) {
                      setState(() {
                        _useFreeDeliveryVoucher = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 5. PAYMENT METHODS
          const Text(
            'طريقة الدفع',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),

          _buildPaymentOption(
            id: 'wallet',
            title: 'محفظة واصل الرقمية (Wasel Wallet)',
            subtitle: 'الرصيد المتاح: 120.00 د.ل (خصم فوري آمن)',
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.warning,
            isDark: isDark,
          ),
          _buildPaymentOption(
            id: 'cod',
            title: 'الدفع نقداً عند الاستلام (Cash on Delivery)',
            subtitle: 'ادفع للكابتن نقداً عند وصول الطلب لباب منزلك',
            icon: Icons.payments_rounded,
            color: AppColors.success,
            isDark: isDark,
          ),
          _buildPaymentOption(
            id: 'sadad',
            title: 'خدمة سداد الإلكترونية (Sadad)',
            subtitle: 'الدفع عبر رقم الهاتف ورسالة OTP',
            icon: Icons.phone_android_rounded,
            color: AppColors.waselPrimary,
            isDark: isDark,
          ),
          _buildPaymentOption(
            id: 'tadawul',
            title: 'بطاقة تداول المصرفية (Tadawul)',
            subtitle: 'الدفع المباشر عبر بطاقة الصراف المحلية',
            icon: Icons.credit_card_rounded,
            color: AppColors.info,
            isDark: isDark,
          ),

          const SizedBox(height: AppSpacing.md),

          // 6. ORDER BILL SUMMARY
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تفاصيل الفاتورة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),
                _buildBillRow('مجموع الأصناف', '${_subtotal.toStringAsFixed(2)} د.ل'),
                _buildBillRow('رسوم التوصيل', _useFreeDeliveryVoucher ? '0.00 د.ل (مجاني 🛵)' : '${_deliveryFee.toStringAsFixed(2)} د.ل', isDiscount: _useFreeDeliveryVoucher),
                _buildBillRow('رسوم الخدمة والمنصة', '${_serviceFee.toStringAsFixed(2)} د.ل'),
                if (_discountAmount > 0)
                  _buildBillRow('خصم الكوبون', '-${_discountAmount.toStringAsFixed(2)} د.ل', isDiscount: true),
                if (_pointsDiscountAmount > 0)
                  _buildBillRow('خصم نقاط واصل', '-${_pointsDiscountAmount.toStringAsFixed(2)} د.ل', isDiscount: true),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المبلغ الإجمالي',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_grandTotal.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.waselPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // CANCELLATION & COMMITMENT POLICY NOTICE
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ميثاق الالتزام بالطلب: يُسمح بإلغاء الطلب مجاناً فقط خلال دقيقتين قبل بدء الطهي. عدم الرد على الكابتن عند الوصول يعرّض الحساب للحظر والرصيد السالب حفاظاً على حقوق المطعم والكابتن.',
                    style: TextStyle(fontSize: 11, color: Colors.amber, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.waselPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'تأكيد الطلب والدفع (${_grandTotal.toStringAsFixed(2)} د.ل)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedPaymentMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: isSelected ? AppColors.waselPrimary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.waselPrimary : AppColors.darkTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.darkTextSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDiscount ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }

  void _openAddressPicker(BuildContext context) async {
    final addresses = await ApiService.getUserAddresses();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('اختر وجهة التوصيل للطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              ...addresses.map((addr) {
                final isSelected = ApiService.activeAddress['id'] == addr['id'];
                String icon = '📍';
                if (addr['tag'] == 'home') icon = '🏠';
                if (addr['tag'] == 'work') icon = '💼';
                if (addr['tag'] == 'chalet') icon = '🌴';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? AppColors.waselPrimary : Colors.transparent, width: 1.5),
                  ),
                  child: ListTile(
                    leading: Text(icon, style: const TextStyle(fontSize: 26)),
                    title: Text(addr['title'] ?? 'مكان', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(addr['details'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.waselPrimary) : null,
                    onTap: () {
                      setState(() {
                        ApiService.activeAddress = addr;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.waselPrimary),
                ),
                icon: const Icon(Icons.satellite_alt, color: AppColors.waselPrimary),
                label: const Text('تحديد موقع جديد بالقمر الصناعي 🛰️', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.waselPrimary)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SatelliteLocationPicker()),
                  );
                  if (result != null) {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

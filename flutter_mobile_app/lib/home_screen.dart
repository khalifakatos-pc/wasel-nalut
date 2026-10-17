import 'screens/referral_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_system.dart';
import 'order_tracking_screen.dart';
import 'satellite_location_picker.dart';
import 'store_menu_screen.dart';
import 'cart_checkout_screen.dart';
import 'widgets/no_network_screen.dart';
import 'services/api_service.dart';
import 'services/customer_notification_service.dart';

/// ============================================================================
/// WASEL SUPER-APP HOME SCREEN (واصل نالوت والجبل الغربي)
/// ============================================================================
enum WaselTab { food, fastGrocery, marketplace }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WaselTab _activeTab = WaselTab.food;
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  int _cartItemCount = 0;
  bool _hasActiveOrder = false;
  Map<String, dynamic>? _activeOrder;
  List<Map<String, dynamic>> _liveStores = [];
  bool _isLoadingStores = false;
  bool _hasNetworkError = false;
  int _userLoyaltyPoints = 0;
  Timer? _orderWatchTimer;
  Timer? _storeWatchTimer;
  bool _isCheckingOrder = false;
  String? _lastNotifiedStatus;

  @override
  void initState() {
    super.initState();
    _cartItemCount = CartService.count;
    CartService.cartCountNotifier.addListener(_onCartCountChanged);
    _fetchLiveStores();
    _checkActiveOrder();
    _loadLoyaltyAndReferral();
    _orderWatchTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _checkActiveOrder();
    });
    // Auto-refresh stores status (e.g. open/closed) in real-time every 10 seconds
    _storeWatchTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchLiveStores(silent: true);
    });
  }

  @override
  void dispose() {
    CartService.cartCountNotifier.removeListener(_onCartCountChanged);
    _searchController.dispose();
    _bannerController.dispose();
    _orderWatchTimer?.cancel();
    _storeWatchTimer?.cancel();
    super.dispose();
  }

  void _onCartCountChanged() {
    if (mounted) {
      setState(() {
        _cartItemCount = CartService.count;
      });
    }
  }

  Future<void> _loadLoyaltyAndReferral() async {
    final res = await ApiService.getLoyaltyPoints();
    if (mounted && res.isSuccess && res.data is int) {
      setState(() {
        _userLoyaltyPoints = res.data as int;
      });
    }
  }

  Future<void> _fetchLiveStores({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoadingStores = true);
    try {
      final res = await ApiService.getStores();
      if (mounted && res.isSuccess && res.data != null && res.data['data'] != null) {
        final List<dynamic> list = res.data['data'];
        setState(() {
          _liveStores = List<Map<String, dynamic>>.from(list);
          _hasNetworkError = false;
          if (!silent) _isLoadingStores = false;
        });
      } else {
        if (!silent && mounted) {
          setState(() {
            _isLoadingStores = false;
            if (_liveStores.isEmpty) _hasNetworkError = true;
          });
        }
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() {
          _isLoadingStores = false;
          if (_liveStores.isEmpty) _hasNetworkError = true;
        });
      }
    }
  }

  Future<void> _checkActiveOrder() async {
    if (_isCheckingOrder) return;
    _isCheckingOrder = true;
    try {
      final String? activeId = ApiService.activeOrderId;
      final String phone = ApiService.userPhone.trim();

      // If guest and has no active order placed in this session, do not poll other people's orders
      if (activeId == null && phone.isEmpty) {
        if (_hasActiveOrder && mounted) {
          setState(() {
            _hasActiveOrder = false;
            _activeOrder = null;
          });
        }
        return;
      }

    try {
      List<dynamic> list = [];

      // 1. Try Live Unified Backend First (24/7 Cloud or Local)
      try {
        final queryParam = activeId != null
            ? 'id=$activeId'
            : 'customer_phone=${Uri.encodeComponent(phone)}&status=placed,assigned,accepted,preparing,ready_for_pickup,arrived_at_store,picked_up,out_for_delivery,delivering';
        final res = await http
            .get(Uri.parse('${ApiService.baseUrl}/orders?$queryParam'))
            .timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['success'] == true && data['data'] is List) {
            list = data['data'];
          }
        }
      } catch (_) {
        // Fallback
      }

      // 2. Fallback to Supabase Cloud if unified backend is offline
      if (list.isEmpty && (activeId != null || phone.isNotEmpty)) {
        try {
          final filter = activeId != null
              ? 'id=eq.$activeId'
              : 'customer_phone=eq.${Uri.encodeComponent(phone)}&status=in.(placed,assigned,accepted,preparing,ready_for_pickup,arrived_at_store,picked_up,out_for_delivery,delivering)';
          final res = await http.get(
            Uri.parse('${ApiService.supabaseUrl}/orders?$filter&order=created_at.desc&limit=1'),
            headers: {
              'apikey': ApiService.supabaseApiKey,
              'Authorization': 'Bearer ${ApiService.supabaseApiKey}',
            },
          ).timeout(const Duration(seconds: 2));

          if (res.statusCode == 200) {
            list = jsonDecode(res.body);
          }
        } catch (_) {}
      }

      if (list.isNotEmpty && mounted) {
        final ord = Map<String, dynamic>.from(list.first);
        final String status = ord['status']?.toString() ?? 'placed';
        final String orderNum = ord['order_number']?.toString() ?? '#W-100';

          // Trigger Heads-Up Pop-up Notification on status change
          if (_lastNotifiedStatus != null && _lastNotifiedStatus != status) {
            if (status == 'preparing') {
              CustomerNotificationService().showOrderStatusNotification(
                title: '👨‍🍳 المطبخ يجهز طلبك الآن!',
                body: 'طلبك رقم $orderNum قيد التحضير والتغليف الساخن في نالوت.',
                payload: ord['id']?.toString(),
              );
            } else if (status == 'ready_for_pickup') {
              CustomerNotificationService().showOrderStatusNotification(
                title: '📦 طلبك جاهز للاستلام!',
                body: 'المطبخ أتم تحضير وجبتك $orderNum وبانتظار الكابتن.',
                payload: ord['id']?.toString(),
              );
            } else if (status == 'out_for_delivery') {
              CustomerNotificationService().showOrderStatusNotification(
                title: '🛵 الكابتن في الطريق إليك!',
                body: 'كابتن واصل استلم طلبك $orderNum وهو متجه الآن لموقعك في نالوت.',
                payload: ord['id']?.toString(),
              );
            } else if (status == 'delivered') {
              CustomerNotificationService().showOrderStatusNotification(
                title: '🎉 تم تسليم طلبك بنجاح!',
                body: 'بالصحة والعافية! شاركنا تقييمك المنصف للمطبخ والكابتن واكسب 20 نقطة ولاء.',
                payload: ord['id']?.toString(),
              );
            }
          }
          _lastNotifiedStatus = status;

          const nonTerminalStatuses = [
            'placed',
            'assigned',
            'accepted',
            'preparing',
            'ready_for_pickup',
            'arrived_at_store',
            'picked_up',
            'out_for_delivery',
            'delivering',
          ];
          final bool isOngoing = nonTerminalStatuses.contains(status);

          if (!isOngoing) {
            ApiService.clearActiveOrderId();
          }

          setState(() {
            _activeOrder = ord;
            _hasActiveOrder = isOngoing;
          });
          _isCheckingOrder = false;
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hasActiveOrder = false;
          _activeOrder = null;
        });
      }
    } finally {
      _isCheckingOrder = false;
    }
  }

  Color get _activeBrandColor {
    switch (_activeTab) {
      case WaselTab.food:
        return AppColors.waselPrimary;
      case WaselTab.fastGrocery:
        return AppColors.jetPrimary;
      case WaselTab.marketplace:
        return AppColors.waselPurple;
    }
  }

  Gradient get _activeBrandGradient {
    switch (_activeTab) {
      case WaselTab.food:
        return AppColors.waselGradient;
      case WaselTab.fastGrocery:
        return AppColors.jetGradient;
      case WaselTab.marketplace:
        return AppColors.waselGradient;
    }
  }

  String get _searchHintText {
    switch (_activeTab) {
      case WaselTab.food:
        return 'ابحث عن وجبات، مشويات، بيتزا في نالوت...';
      case WaselTab.fastGrocery:
        return 'ابحث عن خضار، مياه، حليب، تموينات في 15 دقيقة...';
      case WaselTab.marketplace:
        return 'ابحث عن زيت زيتون نالوت، هواتف، عسل الجبل...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Header (Nalut Location + Notifications + Cart)
            _buildTopAppBar(isDark),

            // 2. Wasel Multi-Vertical Switcher (طعام / فوري 15د / سوق واصل)
            _buildBrandSwitcher(isDark),

            // 3. Main Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: _activeBrandColor,
                onRefresh: () async {
                  await Future.wait([
                    _fetchLiveStores(),
                    _checkActiveOrder(),
                    _loadLoyaltyAndReferral(),
                  ]);
                },
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    // Search bar
                    _buildSearchBar(isDark),

                    // Flash Deals Promotional Banner Carousel
                    _buildBannerCarousel(isDark),

                    // Category Circular Grid
                    _buildCategorySection(isDark),

                    // Active Ongoing Order Mini Banner
                    if (_hasActiveOrder) _buildActiveOrderMiniBanner(isDark),

                    // Loyalty & Referral System Card
                    _buildReferralAndLoyaltyBanner(isDark),

                    // Dynamic Section based on Active Tab
                    _buildDynamicContent(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// TOP APP BAR (Nalut Location + Notification + Cart Counter)
  /// ---------------------------------------------------------------------------
  Widget _buildTopAppBar(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: colorScheme.surface,
      child: Row(
        children: [
          // Location Pin Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _activeBrandColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: _activeBrandColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),

          // Delivery Location Picker (أماكني: المنزل، العمل، الاستراحة)
          Expanded(
            child: InkWell(
              onTap: () => _showMyPlacesSheet(context),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'التوصيل إلى:',
                        style: WaselTypography.cairo(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ApiService.activeAddress['title'] ?? 'المنزل (الحوش)',
                        style: WaselTypography.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _activeBrandColor,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ApiService.activeAddress['details'] ?? 'نالوت - حي القلعة',
                          style: WaselTypography.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Notification Bell
          IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: colorScheme.onSurface,
                  size: 24,
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cart Button with live Badge & WaselBouncyPressable
          WaselBouncyPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CartCheckoutScreen(initialCartItems: CartService.items)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: _activeBrandGradient,
                borderRadius: AppRadius.radiusFull,
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '$_cartItemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMyPlacesSheet(BuildContext context) async {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.place, color: AppColors.waselPrimary),
                      SizedBox(width: 8),
                      Text('أماكني المحفوظة في نالوت', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
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
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? AppColors.waselPrimary : Colors.transparent,
                      width: 1.5,
                    ),
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
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.waselPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.satellite_alt),
                label: const Text('تحديد مكان جديد بالقمر الصناعي 🛰️', style: TextStyle(fontWeight: FontWeight.bold)),
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

  /// ---------------------------------------------------------------------------
  /// BRAND TAB SWITCHER (واصل طعام | واصل فوري | سوق واصل)
  /// ---------------------------------------------------------------------------
  Widget _buildBrandSwitcher(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: WaselRadius.radiusFull,
        ),
        child: Row(
          children: [
            _buildBrandTabItem(
              tab: WaselTab.food,
              label: 'واصل طعام',
              icon: Icons.restaurant_menu_rounded,
              color: WaselColors.primary,
              isDark: isDark,
            ),
            _buildBrandTabItem(
              tab: WaselTab.fastGrocery,
              label: 'واصل فوري',
              icon: Icons.bolt_rounded,
              color: WaselColors.success,
              isDark: isDark,
            ),
            _buildBrandTabItem(
              tab: WaselTab.marketplace,
              label: 'سوق واصل',
              icon: Icons.storefront_rounded,
              color: const Color(0xFF8B5CF6),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandTabItem({
    required WaselTab tab,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _activeTab == tab;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: WaselBouncyPressable(
        behavior: HitTestBehavior.opaque,
        pressedScale: 0.95,
        onTap: () {
          setState(() {
            _activeTab = tab;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? colorScheme.surfaceContainer : Colors.white)
                : Colors.transparent,
            borderRadius: WaselRadius.radiusFull,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: WaselTypography.cairo(
                  color: isSelected ? color : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// SEARCH BAR
  /// ---------------------------------------------------------------------------
  Widget _buildSearchBar(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: WaselRadius.radiusFull,
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: WaselTypography.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: _searchHintText,
                  hintStyle: WaselTypography.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Icon(Icons.tune_rounded, color: _activeBrandColor, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// PROMO BANNER CAROUSEL
  /// ---------------------------------------------------------------------------
  Widget _buildBannerCarousel(bool isDark) {
    final List<Map<String, dynamic>> banners = _activeTab == WaselTab.food
        ? [
            {
              'title': 'عروض مطاعم نالوت الكبرى 🔥',
              'subtitle': 'خصم حتى 40% على المشويات والوجبات',
              'code': 'WASEL40',
              'gradient': AppColors.waselGradient,
              'icon': Icons.local_fire_department_rounded,
            },
            {
              'title': 'توصيل مجاني في نالوت 🛵',
              'subtitle': 'على جميع الطلبات فوق 25 د.ل',
              'code': 'FREEDEL',
              'gradient': const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              'icon': Icons.delivery_dining_rounded,
            },
          ]
        : _activeTab == WaselTab.fastGrocery
            ? [
                {
                  'title': 'واصل فوري في 15 دقيقة ⚡',
                  'subtitle': 'خضار، مياه، وتموينات طازجة لباب بيتك',
                  'code': 'JET15',
                  'gradient': AppColors.jetGradient,
                  'icon': Icons.bolt_rounded,
                },
                {
                  'title': 'مخابز وحلويات نالوت 🥐',
                  'subtitle': 'خبز طازج وفطائر ساخنة صباح ومساء',
                  'code': 'FRESH',
                  'gradient': const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  'icon': Icons.eco_rounded,
                },
              ]
            : [
                {
                  'title': 'زيت زيتون نالوت الحر 🫒',
                  'subtitle': 'معصور على البارد - نخب أول من مزارع الجبل',
                  'code': 'NALUTOIL',
                  'gradient': const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF059669)],
                  ),
                  'icon': Icons.spa_rounded,
                },
                {
                  'title': 'عسل سدر وزعتر الجبل 🍯',
                  'subtitle': 'طبيعي 100% مضمون من جبل نفوسة',
                  'code': 'HONEY',
                  'gradient': AppColors.waselGradient,
                  'icon': Icons.auto_awesome_rounded,
                },
              ];

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (idx) => setState(() => _currentBannerIndex = idx),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: WaselBouncyPressable(
                  behavior: HitTestBehavior.opaque,
                  pressedScale: AppMotion.pressScaleCard,
                  onTap: () {
                    final code = banner['code'] as String;
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: _activeBrandColor,
                        duration: const Duration(seconds: 2),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تم نسخ كود الخصم ($code) بنجاح!',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: banner['gradient'] as LinearGradient,
                      borderRadius: AppRadius.radiusXl,
                      boxShadow: [
                        BoxShadow(
                          color: (banner['gradient'] as LinearGradient).colors.first.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                banner['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                banner['subtitle'] as String,
                                style: WaselTypography.cairo(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.radiusSm,
                                ),
                                child: Text(
                                  'كود: ${banner['code']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          banner['icon'] as IconData,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerIndex == i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerIndex == i
                    ? AppColors.waselPrimary
                    : Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// CATEGORY SECTION
  /// ---------------------------------------------------------------------------
  Widget _buildCategorySection(bool isDark) {
    final List<Map<String, dynamic>> categories = _activeTab == WaselTab.food
        ? [
            {'name': 'مشويات ليبية', 'icon': '🥩'},
            {'name': 'بيتزا وفطائر', 'icon': '🍕'},
            {'name': 'شاورما وبرجر', 'icon': '🍔'},
            {'name': 'مأكولات الجبل', 'icon': '🍲'},
            {'name': 'مقاهي وعصائر', 'icon': '☕'},
          ]
        : _activeTab == WaselTab.fastGrocery
            ? [
                {'name': 'خضار وفواكه', 'icon': '🥬'},
                {'name': 'ألبان وأجبان', 'icon': '🧀'},
                {'name': 'مياه ومشروبات', 'icon': '💧'},
                {'name': 'مخبوزات', 'icon': '🍞'},
                {'name': 'تموينات', 'icon': '🥫'},
              ]
            : [
                {'name': 'زيت زيتون نالوت', 'icon': '🫒'},
                {'name': 'عسل الجبل', 'icon': '🍯'},
                {'name': 'هواتف وإلكترونيات', 'icon': '📱'},
                {'name': 'ملابس وأزياء', 'icon': '👕'},
                {'name': 'منتجات تقليدية', 'icon': '🏺'},
              ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: SizedBox(
        height: 85,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final colorScheme = Theme.of(context).colorScheme;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: WaselBouncyPressable(
                behavior: HitTestBehavior.opaque,
                pressedScale: WaselMotion.pressScaleIcon,
                onTap: () {
                  final catName = cat['name'] as String;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: _activeBrandColor,
                      duration: const Duration(seconds: 1),
                      content: Text(
                        'تصنيف: $catName (متاح في نالوت)',
                        style: WaselTypography.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainer
                            : colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? colorScheme.outlineVariant
                              : colorScheme.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(cat['icon'] as String, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['name'] as String,
                      style: WaselTypography.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// ACTIVE ORDER MINI BANNER (Live tracker link & Delivery OTP)
  /// ---------------------------------------------------------------------------
  Widget _buildActiveOrderMiniBanner(bool isDark) {
    if (!_hasActiveOrder || _activeOrder == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final orderNum = _activeOrder!['order_number'] ??
        (_activeOrder!['id'] != null
            ? 'WAS-${_activeOrder!['id'].toString().substring(0, _activeOrder!['id'].toString().length >= 4 ? 4 : _activeOrder!['id'].toString().length).toUpperCase()}'
            : 'WAS-ORD');
    final statusStr = _activeOrder!['status'] ?? 'placed';
    final dynamic rawOtp = _activeOrder!['otp_code'] ?? _activeOrder!['delivery_pin'] ?? _activeOrder!['handover_code'] ?? _activeOrder!['pickup_code'];
    final String? otpCode = rawOtp?.toString();

    String statusTitle = 'تم تأكيد الطلب';
    StatusPillType pillType = StatusPillType.neutral;
    if (statusStr == 'preparing') {
      statusTitle = 'المطبخ يجهز طلبك 🍳';
      pillType = StatusPillType.warning;
    } else if (statusStr == 'out_for_delivery') {
      statusTitle = 'الكابتن في الطريق إليك 🛵';
      pillType = StatusPillType.info;
    } else if (statusStr == 'ready') {
      statusTitle = 'الطلب جاهز للاستلام 📦';
      pillType = StatusPillType.success;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: WaselBouncyPressable(
        pressedScale: AppMotion.pressScaleCard,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(
                orderId: _activeOrder!['id']?.toString(),
                orderNumber: orderNum,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: WaselRadius.radiusXl,
            border: Border.all(
              color: colorScheme.outlineVariant,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : const Color(0x12F59E0B),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: WaselRadius.radiusMd,
                    ),
                    child: Icon(Icons.two_wheeler_rounded, color: colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'طلب نشط #$orderNum',
                              style: WaselTypography.cairo(
                                color: colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(
                              label: statusTitle,
                              type: pillType,
                              showDot: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تتبع مباشر على خريطة نالوت لحظة بلحظة',
                          style: WaselTypography.cairo(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: colorScheme.primary, size: 14),
                ],
              ),
              if (otpCode != null && otpCode.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: WaselRadius.radiusMd,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'كود استلام الطلب الآمن (أعطه للكابتن):',
                            style: WaselTypography.cairo(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colorScheme.primary),
                        ),
                        child: Text(
                          '#$otpCode',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// REFERRAL & LOYALTY CARD BANNER (الولاء والإحالة الحلال)
  /// ---------------------------------------------------------------------------
  Widget _buildReferralAndLoyaltyBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: WaselBouncyPressable(
        pressedScale: AppMotion.pressScaleCard,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReferralScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1E2D), const Color(0xFF2D1F3D)]
                  : [const Color(0xFFFFF7ED), const Color(0xFFFEF2F2)],
            ),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.waselSecondary.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.waselSecondary.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Points Badge Circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.radiusMd,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              // Loyalty points info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        WaselNumberOdometer(
                          value: _userLoyaltyPoints.toDouble(),
                          decimalPlaces: 0,
                          suffix: ' نقطة ولاء',
                          style: WaselTypography.cairo(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'تخفيض فوري',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ادعُ أصدقاءك في نالوت واكسب توصيل مجاني 100% 🛵🎁',
                      style: WaselTypography.cairo(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.waselPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'دعوة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
  /// ---------------------------------------------------------------------------
  /// DYNAMIC CONTENT (Stores & Products in Nalut)
  /// ---------------------------------------------------------------------------
  Widget _buildDynamicContent(bool isDark) {
    if (_activeTab == WaselTab.food) {
      return _buildFoodContent(isDark);
    } else if (_activeTab == WaselTab.fastGrocery) {
      return _buildGroceryContent(isDark);
    } else {
      return _buildMarketplaceContent(isDark);
    }
  }

  Widget _buildFoodContent(bool isDark) {
    final foodStores = _liveStores.where((s) => s['type'] == 'restaurant' || s['type'] == null).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أشهر مطاعم نالوت 🍔',
                style: WaselTypography.cairo(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                '${foodStores.length} مطعم متاح',
                style: WaselTypography.cairo(color: _activeBrandColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingStores)
            _buildShimmerStoreLoading(isDark)
          else if (_hasNetworkError && _liveStores.isEmpty)
            NoNetworkScreen(
              isFullScreen: false,
              onRetry: () => _fetchLiveStores(silent: false),
            )
          else if (foodStores.isEmpty)
            _buildEmptyStoresCard(isDark, 'لا توجد مطاعم مسجلة حالياً في نالوت', Icons.restaurant_rounded)
          else
            ...foodStores.asMap().entries.map((entry) {
              final index = entry.key;
              final store = entry.value;
              return WaselSlideFade(
                key: ValueKey('store_food_${store['id'] ?? index}'),
                delay: Duration(milliseconds: index.clamp(0, 8) * 60),
                duration: WaselMotion.standard,
                offset: const Offset(0.0, 0.08),
                curve: WaselMotion.signature,
                child: _buildStoreCard(store, isDark),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildShimmerStoreLoading(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: WaselRadius.radiusLg,
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: const Row(
            children: [
              ShimmerSkeleton(width: 74, height: 74, borderRadius: WaselRadius.radiusLg),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerSkeleton(width: 160, height: 16, borderRadius: WaselRadius.radiusXs),
                    SizedBox(height: 8),
                    ShimmerSkeleton(width: 110, height: 12, borderRadius: WaselRadius.radiusXs),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        ShimmerSkeleton(width: 60, height: 12, borderRadius: WaselRadius.radiusXs),
                        SizedBox(width: 12),
                        ShimmerSkeleton(width: 50, height: 12, borderRadius: WaselRadius.radiusXs),
                      ],
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

  Widget _buildGroceryContent(bool isDark) {
    final groceryStores = _liveStores.where((s) => s['type'] == 'grocery').toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'واصل فوري ⚡ تموينات وسوبرماركت نالوت',
                style: WaselTypography.cairo(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '${groceryStores.length} متجر',
                style: WaselTypography.cairo(color: _activeBrandColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingStores)
            _buildShimmerStoreLoading(isDark)
          else if (groceryStores.isEmpty)
            _buildEmptyStoresCard(isDark, 'لا توجد تموينات أو أسواق مضافة حالياً في نالوت', Icons.shopping_basket_rounded)
          else
            ...groceryStores.asMap().entries.map((entry) {
              final index = entry.key;
              final store = entry.value;
              return WaselSlideFade(
                key: ValueKey('store_grocery_${store['id'] ?? index}'),
                delay: Duration(milliseconds: index.clamp(0, 8) * 60),
                duration: WaselMotion.standard,
                offset: const Offset(0.0, 0.08),
                curve: WaselMotion.signature,
                child: _buildStoreCard(store, isDark),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMarketplaceContent(bool isDark) {
    final marketStores = _liveStores.where((s) => s['type'] == 'marketplace').toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سوق واصل 🛍️ منتجات ومحلات نالوت',
                style: WaselTypography.cairo(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '${marketStores.length} متجر',
                style: WaselTypography.cairo(color: _activeBrandColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingStores)
            _buildShimmerStoreLoading(isDark)
          else if (marketStores.isEmpty)
            _buildEmptyStoresCard(isDark, 'سوق واصل شاغر حالياً - بانتظار إدراج المحلات الحرفية', Icons.storefront_rounded)
          else
            ...marketStores.asMap().entries.map((entry) {
              final index = entry.key;
              final store = entry.value;
              return WaselSlideFade(
                key: ValueKey('store_market_${store['id'] ?? index}'),
                delay: Duration(milliseconds: index.clamp(0, 8) * 60),
                duration: WaselMotion.standard,
                offset: const Offset(0.0, 0.08),
                curve: WaselMotion.signature,
                child: _buildStoreCard(store, isDark),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyStoresCard(bool isDark, String message, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: WaselRadius.radiusLg,
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: WaselTypography.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'يمكن للمدير إضافة المتاجر والمنتجات الحقيقية عبر تطبيق Wasel Admin',
            textAlign: TextAlign.center,
            style: WaselTypography.cairo(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = store['name']?.toString() ?? 'متجر نالوت';
    final rating = store['rating']?.toString() ?? '4.8';
    final cuisine = store['cuisine']?.toString() ?? store['district']?.toString() ?? 'نالوت';
    final timeMin = store['delivery_time_min']?.toString() ?? '20';
    final timeMax = store['delivery_time_max']?.toString() ?? '35';
    final timeStr = store['time']?.toString() ?? '$timeMin-$timeMax دقيقة';
    final feeStr = store['fee']?.toString() ?? '${store['base_delivery_fee_lyd'] ?? 5.00} د.ل';
    final isGrocery = store['type'] == 'grocery';

    final rawOpen = store['is_open'];
    final bool isOpen = rawOpen != false && rawOpen != 'false' && rawOpen != 0;

    return WaselBouncyPressable(
      pressedScale: AppMotion.pressScaleCard,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreMenuScreen(store: store),
          ),
        );
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isOpen ? 1.0 : 0.75,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: WaselRadius.radiusLg,
            border: Border.all(
              color: !isOpen
                  ? Colors.red.withValues(alpha: 0.4)
                  : colorScheme.outlineVariant,
              width: !isOpen ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Store thumbnail with Hero tag pairing & status overlay if closed
              Hero(
                tag: 'store_cover_${store['id']}',
                child: Stack(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        gradient: !isOpen
                            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600])
                            : (isGrocery
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )),
                        borderRadius: WaselRadius.radiusLg,
                      ),
                      child: Center(
                        child: Icon(
                          isGrocery ? Icons.shopping_basket_rounded : Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    if (!isOpen)
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: WaselRadius.radiusLg,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: WaselTypography.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: !isOpen
                                  ? (isDark ? Colors.white60 : Colors.black54)
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isOpen)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: AppRadius.radiusSm,
                              border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.do_not_disturb_on_rounded, size: 11, color: Colors.red),
                                SizedBox(width: 3),
                                Text(
                                  'مغلق مؤقتاً',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: AppRadius.radiusSm,
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 3),
                                Text(
                                  rating,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cuisine,
                      style: WaselTypography.cairo(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (!isOpen)
                      const Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'المتجر مغلق حالياً ولا يستقبل طلبات',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: WaselTypography.cairo(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.delivery_dining_rounded, size: 13, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  feeStr,
                                  style: WaselTypography.cairo(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
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

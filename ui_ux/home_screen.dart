import 'package:flutter/material.dart';
import 'design_system.dart';
import 'order_tracking_screen.dart';
import 'product_detail_sheet.dart';

/// ============================================================================
/// PRESTO x MATAA SUPER-APP HOME SCREEN
/// ============================================================================
/// An ultra-polished, unified super-app home screen switching seamlessly
/// between:
/// 1. PRESTO EAT (Restaurant Food Delivery)
/// 2. JET EXPRESS (15-min Ultra-fast Grocery)
/// 3. MATAA MARKETPLACE (Lifestyle & Tech E-Commerce)
/// ============================================================================

enum SuperAppTab { prestoEat, jetGrocery, mataaMarket }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  SuperAppTab _activeTab = SuperAppTab.prestoEat;
  int _bottomNavIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  // Active Simulated Cart Count
  int _cartItemCount = 3;

  // Active Ongoing Order status for sticky mini-tracker
  bool _hasActiveOrder = true;

  @override
  void dispose() {
    _searchController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Color get _activeBrandColor {
    switch (_activeTab) {
      case SuperAppTab.prestoEat:
        return AppColors.prestoPrimary;
      case SuperAppTab.jetGrocery:
        return AppColors.jetPrimary;
      case SuperAppTab.mataaMarket:
        return AppColors.mataaPrimary;
    }
  }

  Gradient get _activeBrandGradient {
    switch (_activeTab) {
      case SuperAppTab.prestoEat:
        return AppColors.prestoGradient;
      case SuperAppTab.jetGrocery:
        return AppColors.jetGradient;
      case SuperAppTab.mataaMarket:
        return AppColors.mataaGradient;
    }
  }

  String get _searchHintText {
    switch (_activeTab) {
      case SuperAppTab.prestoEat:
        return "Search restaurants, burgers, shawarma...";
      case SuperAppTab.jetGrocery:
        return "Search milk, fresh fruit, coffee, snacks in 15m...";
      case SuperAppTab.mataaMarket:
        return "Search iPhone 16, Oud perfumes, sneakers...";
    }
  }

  void _openProductDetail({
    required String title,
    required double price,
    required String category,
    required bool isFood,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailSheet(
        title: title,
        basePrice: price,
        category: category,
        isFood: isFood,
        onAddToCart: (itemDetails) {
          setState(() {
            _cartItemCount++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _activeBrandColor,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Added $title to your bag!',
                      style: AppTypography.labelMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _openOrderTracker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const OrderTrackingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Super Header (Location, ETA, Cart & Notifications)
            _buildTopAppBar(isDark),

            // 2. Super-App Brand Segmented Switcher (Presto / Jet / Mataa)
            _buildBrandSwitcher(isDark),

            // 3. Main Scrollable Content
            Expanded(
              child: RefreshIndicator(
                color: _activeBrandColor,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 600));
                },
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Dynamic Search Bar
                    SliverToBoxAdapter(
                      child: _buildSearchBar(isDark),
                    ),

                    // Flash Deals Promotional Banner Carousel
                    SliverToBoxAdapter(
                      child: _buildBannerCarousel(isDark),
                    ),

                    // Category Circular Grid
                    SliverToBoxAdapter(
                      child: _buildCategorySection(isDark),
                    ),

                    // Active Ongoing Order Mini Banner (Interactive preview)
                    if (_hasActiveOrder)
                      SliverToBoxAdapter(
                        child: _buildActiveOrderMiniBanner(isDark),
                      ),

                    // Dynamic Content based on Active Tab
                    ..._buildDynamicTabSlivers(isDark),

                    // Bottom spacing for sticky navigation
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(isDark),
    );
  }

  /// ---------------------------------------------------------------------------
  /// TOP APP BAR (Location + Notification + Cart Counter)
  /// ---------------------------------------------------------------------------
  Widget _buildTopAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
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

          // Delivery Location Address Picker
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Delivering to',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.jetPrimary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusFull,
                      ),
                      child: Text(
                        _activeTab == SuperAppTab.jetGrocery ? '15 MIN' : 'FAST',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.jetPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Al-Mansour, District 604, Baghdad',
                        style: AppTypography.titleSmall.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Notification Bell
          IconButton(
            onPressed: () {},
            icon: Stack(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  size: 24,
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.prestoPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cart Button with live Badge
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Viewing Cart: $_cartItemCount items ready to checkout'),
                  backgroundColor: AppColors.mataaNavy,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: _activeBrandGradient,
                borderRadius: AppRadius.radiusFull,
                boxShadow: AppShadows.colored(_activeBrandColor, opacity: 0.3),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '$_cartItemCount',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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

  /// ---------------------------------------------------------------------------
  /// BRAND TAB SWITCHER (Presto Eat | Jet 15m | Mataa Market)
  /// ---------------------------------------------------------------------------
  Widget _buildBrandSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : const Color(0xFFF1F5F9),
          borderRadius: AppRadius.radiusFull,
        ),
        child: Row(
          children: [
            _buildBrandTabItem(
              tab: SuperAppTab.prestoEat,
              label: 'Presto Eat',
              icon: Icons.fastfood_rounded,
              color: AppColors.prestoPrimary,
              badge: 'HOT',
            ),
            _buildBrandTabItem(
              tab: SuperAppTab.jetGrocery,
              label: 'Jet 15m',
              icon: Icons.flash_on_rounded,
              color: AppColors.jetPrimary,
              badge: '15m',
            ),
            _buildBrandTabItem(
              tab: SuperAppTab.mataaMarket,
              label: 'Mataa Market',
              icon: Icons.storefront_rounded,
              color: AppColors.mataaPrimary,
              badge: 'SALE',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandTabItem({
    required SuperAppTab tab,
    required String label,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    final isSelected = _activeTab == tab;

    return Expanded(
      child: GestureDetector(
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
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: AppRadius.radiusFull,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
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
                color: isSelected ? color : AppColors.lightTextMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: isSelected ? color : AppColors.lightTextSecondary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// DYNAMIC SEARCH BAR
  /// ---------------------------------------------------------------------------
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.2,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: _activeBrandColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: _searchHintText,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            Container(
              height: 24,
              width: 1,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            IconButton(
              onPressed: () {
                // Filter action
              },
              icon: Icon(
                Icons.tune_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// FLASH DEALS / PROMO CAROUSEL
  /// ---------------------------------------------------------------------------
  Widget _buildBannerCarousel(bool isDark) {
    final List<Map<String, dynamic>> banners = _activeTab == SuperAppTab.prestoEat
        ? [
            {
              'title': 'Presto Feast Day',
              'subtitle': 'Up to 50% OFF Top Iraqi & Global Eateries',
              'badge': 'FLASH DEAL',
              'code': 'PRESTO50',
              'gradient': AppColors.prestoGradient,
              'icon': Icons.local_fire_department_rounded,
            },
            {
              'title': 'Free Delivery Pass',
              'subtitle': 'Zero delivery fees on orders over \$15',
              'badge': 'VIP PERK',
              'code': 'FREEDEL',
              'gradient': const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              'icon': Icons.delivery_dining_rounded,
            },
          ]
        : _activeTab == SuperAppTab.jetGrocery
            ? [
                {
                  'title': 'Jet 15-Minute Rush',
                  'subtitle': 'Fresh milk, eggs & snacks delivered before your coffee brews!',
                  'badge': '15-MIN GUARANTEE',
                  'code': 'JETFAST',
                  'gradient': AppColors.jetGradient,
                  'icon': Icons.bolt_rounded,
                },
                {
                  'title': 'Fresh Organic Harvest',
                  'subtitle': 'Direct farm produce 30% OFF today',
                  'badge': 'FARM FRESH',
                  'code': 'ORGANIC',
                  'gradient': const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                  'icon': Icons.eco_rounded,
                },
              ]
            : [
                {
                  'title': 'Mataa Tech Expo 2026',
                  'subtitle': 'Flagship Smart Devices & Accessories with 2-Yr Warranty',
                  'badge': 'MEGA SALE',
                  'code': 'TECHMATAA',
                  'gradient': AppColors.heroPromoGradient,
                  'icon': Icons.devices_other_rounded,
                },
                {
                  'title': 'Luxury Oud & Perfumes',
                  'subtitle': 'Original Gulf & Parisian brands up to 40% OFF',
                  'badge': 'EXCLUSIVE',
                  'code': 'LUXURY',
                  'gradient': AppColors.mataaGradient,
                  'icon': Icons.auto_awesome_rounded,
                },
              ];

    return Column(
      children: [
        SizedBox(
          height: 155,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (idx) {
              setState(() {
                _currentBannerIndex = idx;
              });
            },
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    gradient: banner['gradient'] as LinearGradient,
                    borderRadius: AppRadius.radiusXl,
                    boxShadow: AppShadows.colored(
                      (banner['gradient'] as LinearGradient).colors.first,
                      opacity: 0.25,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative background icon watermark
                      Positioned(
                        right: -10,
                        bottom: -15,
                        child: Icon(
                          banner['icon'] as IconData,
                          size: 110,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: AppRadius.radiusFull,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.flash_on_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 3),
                                    Text(
                                      banner['badge'],
                                      style: AppTypography.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: AppRadius.radiusSm,
                                ),
                                child: Text(
                                  'Use: ${banner['code']}',
                                  style: AppTypography.monoNumber.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                banner['title'],
                                style: AppTypography.headlineLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                banner['subtitle'],
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
        ),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerIndex == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerIndex == i
                    ? _activeBrandColor
                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: AppRadius.radiusFull,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// ACTIVE ORDER LIVE MINI BANNER (Sticky preview -> opens OrderTracker)
  /// ---------------------------------------------------------------------------
  Widget _buildActiveOrderMiniBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: GestureDetector(
        onTap: _openOrderTracker,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.prestoPrimary.withValues(alpha: 0.6), width: 1.2),
            boxShadow: AppShadows.colored(Colors.black, opacity: 0.2),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.prestoPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: AppColors.prestoSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Driver on the way',
                          style: AppTypography.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smash Burger House • Arriving in 14 mins',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.prestoPrimary,
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Row(
                  children: [
                    Text(
                      'TRACK',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
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
  /// CATEGORY SECTION (Tailored per Tab)
  /// ---------------------------------------------------------------------------
  Widget _buildCategorySection(bool isDark) {
    final List<Map<String, dynamic>> categories = _activeTab == SuperAppTab.prestoEat
        ? [
            {'name': 'Burgers', 'icon': Icons.lunch_dining_rounded, 'color': const Color(0xFFEF4444)},
            {'name': 'Shawarma', 'icon': Icons.kebab_dining_rounded, 'color': const Color(0xFFF97316)},
            {'name': 'Pizza', 'icon': Icons.local_pizza_rounded, 'color': const Color(0xFFF59E0B)},
            {'name': 'Iraqi Grill', 'icon': Icons.outdoor_grill_rounded, 'color': const Color(0xFF84CC16)},
            {'name': 'Sweets & Cafe', 'icon': Icons.cake_rounded, 'color': const Color(0xFFEC4899)},
            {'name': 'Fried Chicken', 'icon': Icons.set_meal_rounded, 'color': const Color(0xFF6366F1)},
            {'name': 'Healthy', 'icon': Icons.eco_rounded, 'color': const Color(0xFF10B981)},
            {'name': 'Sushi & Asian', 'icon': Icons.rice_bowl_rounded, 'color': const Color(0xFF06B6D4)},
          ]
        : _activeTab == SuperAppTab.jetGrocery
            ? [
                {'name': 'Fresh Fruits', 'icon': Icons.apple_rounded, 'color': const Color(0xFF10B981)},
                {'name': 'Dairy & Eggs', 'icon': Icons.egg_rounded, 'color': const Color(0xFFF59E0B)},
                {'name': 'Snacks & Chips', 'icon': Icons.cookie_rounded, 'color': const Color(0xFFF97316)},
                {'name': 'Beverages', 'icon': Icons.local_drink_rounded, 'color': const Color(0xFF06B6D4)},
                {'name': 'Bakery', 'icon': Icons.bakery_dining_rounded, 'color': const Color(0xFFD97706)},
                {'name': 'Cleaning', 'icon': Icons.cleaning_services_rounded, 'color': const Color(0xFF6366F1)},
                {'name': 'Personal Care', 'icon': Icons.soap_rounded, 'color': const Color(0xFFEC4899)},
                {'name': 'Ice Cream', 'icon': Icons.icecream_rounded, 'color': const Color(0xFF8B5CF6)},
              ]
            : [
                {'name': 'Smartphones', 'icon': Icons.phone_iphone_rounded, 'color': const Color(0xFF6366F1)},
                {'name': 'Laptops', 'icon': Icons.laptop_mac_rounded, 'color': const Color(0xFF7C3AED)},
                {'name': 'Audio & Pods', 'icon': Icons.headphones_rounded, 'color': const Color(0xFFEC4899)},
                {'name': 'Gaming', 'icon': Icons.sports_esports_rounded, 'color': const Color(0xFFEF4444)},
                {'name': 'Watches', 'icon': Icons.watch_rounded, 'color': const Color(0xFFF59E0B)},
                {'name': 'Oud & Perfume', 'icon': Icons.local_florist_rounded, 'color': const Color(0xFFD97706)},
                {'name': 'Sneakers', 'icon': Icons.snowshoeing_rounded, 'color': const Color(0xFF10B981)},
                {'name': 'Home Tech', 'icon': Icons.home_mini_rounded, 'color': const Color(0xFF06B6D4)},
              ];

    return Column(
      children: [
        SectionHeader(
          title: _activeTab == SuperAppTab.prestoEat
              ? 'Explore Cuisines'
              : _activeTab == SuperAppTab.jetGrocery
                  ? 'Aisles in 15 Minutes'
                  : 'Shop Categories',
          actionText: 'See All',
          onActionTap: () {},
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final Color catColor = cat['color'] as Color;

              return Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: catColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Center(
                      child: Icon(
                        cat['icon'] as IconData,
                        color: catColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      cat['name'],
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// DYNAMIC TAB CONTENT SLIVERS
  /// ---------------------------------------------------------------------------
  List<Widget> _buildDynamicTabSlivers(bool isDark) {
    switch (_activeTab) {
      case SuperAppTab.prestoEat:
        return _buildPrestoEatSlivers(isDark);
      case SuperAppTab.jetGrocery:
        return _buildJetGrocerySlivers(isDark);
      case SuperAppTab.mataaMarket:
        return _buildMataaMarketSlivers(isDark);
    }
  }

  /// 1. PRESTO EAT: Featured & Active Restaurants
  List<Widget> _buildPrestoEatSlivers(bool isDark) {
    final List<Map<String, dynamic>> restaurants = [
      {
        'id': 'rest_1',
        'name': 'Smash Triple Burger Co.',
        'cuisine': 'American Gourmet Burgers • Crispy Fries',
        'rating': 4.9,
        'reviews': 1420,
        'deliveryTime': '18-25 min',
        'deliveryFee': 'Free Delivery',
        'tag': '20% OFF ALL COMBOS',
        'isFeatured': true,
        'featuredItem': 'Smash Triple Wagyu Truffle Burger',
        'price': 12.50,
      },
      {
        'id': 'rest_2',
        'name': 'Al-Basha Iraqi Kebab & Tikka',
        'cuisine': 'Authentic Iraqi Grill • Fresh Tannour Bread',
        'rating': 4.8,
        'reviews': 2890,
        'deliveryTime': '20-30 min',
        'deliveryFee': '\$1.00',
        'tag': 'TOP RATED BAGHDAD',
        'isFeatured': false,
        'featuredItem': 'Mixed Baghdad Kebab Platter 1kg',
        'price': 18.00,
      },
      {
        'id': 'rest_3',
        'name': 'FireCrust Artisan Pizza',
        'cuisine': 'Wood-fired Neapolitan Pizza • Pasta',
        'rating': 4.7,
        'reviews': 860,
        'deliveryTime': '25-35 min',
        'deliveryFee': 'Free Delivery',
        'tag': 'BUY 1 GET 1 50%',
        'isFeatured': false,
        'featuredItem': 'Truffle Burrata & Wild Mushroom Pizza',
        'price': 14.00,
      },
    ];

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Trending Restaurants',
          subtitle: 'Fastest delivery around Al-Mansour',
          actionText: 'Filters',
          onActionTap: () {},
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final rest = restaurants[index];
              return _buildRestaurantCard(rest, isDark);
            },
            childCount: restaurants.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildRestaurantCard(Map<String, dynamic> rest, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant Hero Visual Container
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.prestoNavy(isDark),
                      const Color(0xFF334155),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Discount / Promo Badge
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.prestoGradient,
                    borderRadius: AppRadius.radiusFull,
                    boxShadow: AppShadows.colored(AppColors.prestoPrimary, opacity: 0.3),
                  ),
                  child: Text(
                    rest['tag'],
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Delivery ETA Pill
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        rest['deliveryTime'],
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Restaurant Body Info
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        rest['name'],
                        style: AppTypography.titleLarge.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    RatingBadge(
                      rating: rest['rating'] as double,
                      reviewsCount: rest['reviews'] as int,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rest['cuisine'],
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Featured Dish Quick Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Featured Special:',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.prestoPrimary,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            rest['featuredItem'],
                            style: AppTypography.titleSmall.copyWith(
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.prestoLight,
                        foregroundColor: AppColors.prestoPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusFull),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _openProductDetail(
                          title: rest['featuredItem'],
                          price: rest['price'],
                          category: 'Food',
                          isFood: true,
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            '\$${(rest['price'] as double).toStringAsFixed(2)}',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.prestoPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.add_circle_outline_rounded, size: 16),
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
    );
  }

  /// 2. JET GROCERY: 15-Min Quick Essentials Grid
  List<Widget> _buildJetGrocerySlivers(bool isDark) {
    final List<Map<String, dynamic>> groceryItems = [
      {
        'title': 'Organic Whole Milk 1L',
        'subtitle': 'Farm fresh pasteurized',
        'price': 2.25,
        'oldPrice': 2.80,
        'discount': '20% OFF',
        'icon': Icons.local_drink_rounded,
      },
      {
        'title': 'Fresh Golden Bananas 1kg',
        'subtitle': 'Direct import sweet harvest',
        'price': 1.50,
        'oldPrice': 2.00,
        'discount': '25% OFF',
        'icon': Icons.apple_rounded,
      },
      {
        'title': 'Artisan Brioche Burger Buns',
        'subtitle': 'Pack of 6 fresh baked',
        'price': 3.10,
        'oldPrice': 3.75,
        'discount': '17% OFF',
        'icon': Icons.bakery_dining_rounded,
      },
      {
        'title': 'Columbian Roast Coffee Beans 500g',
        'subtitle': 'Medium dark roast aroma',
        'price': 7.80,
        'oldPrice': 9.50,
        'discount': '18% OFF',
        'icon': Icons.coffee_rounded,
      },
    ];

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Lightning Flash Deals (15m)',
          subtitle: 'Order now, at your door in 15 minutes',
          actionText: 'View 240+ Items',
          onActionTap: () {},
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = groceryItems[index];
              return _buildGroceryGridCard(item, isDark);
            },
            childCount: groceryItems.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildGroceryGridCard(Map<String, dynamic> item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container with Badge
          Stack(
            children: [
              Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.jetLight.withValues(alpha: isDark ? 0.08 : 0.8),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Center(
                  child: Icon(
                    item['icon'] as IconData,
                    size: 42,
                    color: AppColors.jetPrimary,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.jetPrimary,
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Text(
                    item['discount'],
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title & Subtitle
          Text(
            item['title'],
            style: AppTypography.titleSmall.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item['subtitle'],
            style: AppTypography.bodySmall.copyWith(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),

          // Price & Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${(item['price'] as double).toStringAsFixed(2)}',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.jetPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '\$${(item['oldPrice'] as double).toStringAsFixed(2)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  _openProductDetail(
                    title: item['title'],
                    price: item['price'],
                    category: 'Grocery',
                    isFood: true,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.jetPrimary,
                    borderRadius: AppRadius.radiusSm,
                    boxShadow: AppShadows.colored(AppColors.jetPrimary, opacity: 0.3),
                  ),
                  child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3. MATAA MARKETPLACE: Dual-Column E-Commerce Products
  List<Widget> _buildMataaMarketSlivers(bool isDark) {
    final List<Map<String, dynamic>> marketItems = [
      {
        'title': 'Apple AirPods Pro (2nd Gen)',
        'category': 'Audio & Electronics',
        'price': 219.00,
        'oldPrice': 249.00,
        'rating': 4.9,
        'sales': '3.2k sold',
        'badge': 'TOP SELLER',
        'icon': Icons.headphones_rounded,
      },
      {
        'title': 'Arabian Royal Oud Eau De Parfum 100ml',
        'category': 'Luxury Fragrance',
        'price': 85.00,
        'oldPrice': 120.00,
        'rating': 4.8,
        'sales': '1.1k sold',
        'badge': 'AUTHENTIC',
        'icon': Icons.local_florist_rounded,
      },
      {
        'title': 'Sony PlayStation 5 DualSense Wireless',
        'category': 'Gaming Accessories',
        'price': 69.99,
        'oldPrice': 79.99,
        'rating': 4.9,
        'sales': '4.8k sold',
        'badge': 'FAST SHIP',
        'icon': Icons.sports_esports_rounded,
      },
      {
        'title': 'Ultra Titanium Chronograph Watch',
        'category': 'Fashion & Luxury',
        'price': 149.00,
        'oldPrice': 199.00,
        'rating': 4.7,
        'sales': '640 sold',
        'badge': 'LIMITED',
        'icon': Icons.watch_rounded,
      },
    ];

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Mataa Curated Deals',
          subtitle: 'Original guaranteed with official warranty',
          actionText: 'All Brands',
          onActionTap: () {},
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = marketItems[index];
              return _buildMataaGridCard(item, isDark);
            },
            childCount: marketItems.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildMataaGridCard(Map<String, dynamic> item, bool isDark) {
    return GestureDetector(
      onTap: () {
        _openProductDetail(
          title: item['title'],
          price: item['price'],
          category: item['category'],
          isFood: false,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Icon Container
            Stack(
              children: [
                Container(
                  height: 105,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.mataaLight.withValues(alpha: isDark ? 0.08 : 0.7),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Center(
                    child: Icon(
                      item['icon'] as IconData,
                      size: 46,
                      color: AppColors.mataaPrimary,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mataaPrimary,
                      borderRadius: AppRadius.radiusFull,
                    ),
                    child: Text(
                      item['badge'],
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                // Wishlist heart button
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 15,
                      color: AppColors.mataaPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Rating & Sales
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 2),
                Text(
                  '${item['rating']}',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• ${item['sales']}',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Title
            Text(
              item['title'],
              style: AppTypography.titleSmall.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Price & Prime Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${(item['price'] as double).toStringAsFixed(2)}',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.mataaPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '\$${(item['oldPrice'] as double).toStringAsFixed(2)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.mataaNavy,
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    'PRIME',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// BOTTOM NAVIGATION BAR
  /// ---------------------------------------------------------------------------
  Widget _buildBottomNavigation(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1,
          ),
        ),
        boxShadow: AppShadows.bottomBarShadow,
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
          });
          if (index == 3) {
            _openOrderTracker();
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _activeBrandColor,
        unselectedItemColor: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        selectedLabelStyle: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTypography.labelSmall,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            activeIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_offer_outlined),
            activeIcon: Icon(Icons.local_offer_rounded),
            label: 'Offers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

// Color helper
extension on AppColors {
  static Color prestoNavy(bool isDark) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A);
}

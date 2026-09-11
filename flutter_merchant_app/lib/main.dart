import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'kds_screen.dart';
import 'retail_picking_screen.dart';
import 'catalog_screen.dart';
import 'sales_analytics_screen.dart';
import 'services/merchant_supabase_service.dart';
import 'services/merchant_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaselMerchantApp());
}

class WaselMerchantApp extends StatelessWidget {
  const WaselMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شريك واصل | Wasel Partner',
      debugShowCheckedModeBanner: false,
      theme: MerchantTheme.darkTheme,
      locale: const Locale('ar', 'LY'),
      supportedLocales: const [
        Locale('ar', 'LY'),
        Locale('ar', ''),
        Locale('en', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MerchantMainShell(),
    );
  }
}

class MerchantMainShell extends StatefulWidget {
  const MerchantMainShell({super.key});

  @override
  State<MerchantMainShell> createState() => _MerchantMainShellState();
}

class _MerchantMainShellState extends State<MerchantMainShell> {
  int _currentIndex = 0;
  StoreStatus _storeStatus = StoreStatus.open;
  Timer? _pollTimer;

  // Active Partner Store in Nalut
  PartnerStore _currentStore = PartnerStore.nalutStores[0];

  late List<KdsOrder> _orders;
  late List<CatalogProduct> _catalog;

  @override
  void initState() {
    super.initState();
    MerchantSupabaseService.currentStoreId = _currentStore.id;
    _orders = _currentStore.mode == PartnerAppMode.retail
        ? MerchantMockData.getSampleRetailOrders()
        : MerchantMockData.getSampleOrders();
    _catalog = MerchantMockData.getSampleCatalog();

    _initNotifications();
    _loadSavedStore();
    _loadLiveMerchantData();

    // Poll Supabase Cloud every 4 seconds for new incoming orders
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollOrdersSilently();
    });
  }

  Future<void> _loadSavedStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('wasel_active_store_id');
      if (savedId != null && savedId != _currentStore.id) {
        final store = PartnerStore.nalutStores.firstWhere(
          (s) => s.id == savedId,
          orElse: () => _currentStore,
        );
        if (store.id != _currentStore.id && mounted) {
          setState(() {
            _currentStore = store;
            MerchantSupabaseService.currentStoreId = store.id;
            _orders = store.mode == PartnerAppMode.retail
                ? MerchantMockData.getSampleRetailOrders()
                : MerchantMockData.getSampleOrders();
          });
          _loadLiveMerchantData();
        }
      }
    } catch (_) {}
  }

  Future<void> _initNotifications() async {
    try {
      await MerchantNotificationService().initialize().timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _switchStore(PartnerStore newStore) {
    if (_currentStore.id == newStore.id) return;
    setState(() {
      _currentStore = newStore;
      MerchantSupabaseService.currentStoreId = newStore.id;
      _orders = newStore.mode == PartnerAppMode.retail
          ? MerchantMockData.getSampleRetailOrders()
          : MerchantMockData.getSampleOrders();
    });

    // Multi-tenant persistent context: wasel_active_store_id
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('wasel_active_store_id', newStore.id);
    }).catchError((_) {});

    _loadLiveMerchantData();

    final isKitchen = newStore.mode == PartnerAppMode.kitchen;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isKitchen
              ? '📋 تم التحويل إلى: ${newStore.name} (وضع إدارة الطلبات والتحضير)'
              : '🛒 تم التحويل إلى: ${newStore.name} (وضع تجميع السلة والتعبئة)',
        ),
        backgroundColor: isKitchen ? MerchantColors.primary : MerchantColors.accentTeal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadLiveMerchantData() async {
    try {
      final liveOrders = await MerchantSupabaseService.fetchOrders(_currentStore.id);
      final liveCatalog = await MerchantSupabaseService.fetchCatalog(_currentStore.id);
      if (mounted) {
        setState(() {
          _orders = liveOrders;
          _catalog = liveCatalog;
        });
      }
    } catch (_) {}
  }

  Future<void> _pollOrdersSilently() async {
    try {
      final liveOrders = await MerchantSupabaseService.fetchOrders(_currentStore.id);
      if (!mounted) return;

      final oldNewIds = _orders
          .where((o) => o.status == KdsTicketStatus.newOrder)
          .map((o) => o.id)
          .toSet();
      final incomingNew = liveOrders
          .where((o) => o.status == KdsTicketStatus.newOrder && !oldNewIds.contains(o.id))
          .toList();

      if (incomingNew.isNotEmpty && mounted) {
        final newOrd = incomingNew.first;
        final isKitchen = _currentStore.mode == PartnerAppMode.kitchen;
        // 1. Kitchen / Retail Alert Notification
        MerchantNotificationService().showKitchenOrderAlert(
          title: isKitchen
              ? '🚨 تنبيه طلب جديد: ${newOrd.orderNumber}'
              : '🛒 طلب تجميع جديد: ${newOrd.orderNumber}',
          body: 'طلب بقيمة ${newOrd.totalAmountLyd.toStringAsFixed(2)} د.ل لـ ${_currentStore.name}.',
        );

        // 2. In-App Banner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKitchen
                  ? '🔔 ورد طلب تحضير جديد: ${newOrd.orderNumber}'
                  : '🛒 ورد طلب تجميع جديد: ${newOrd.orderNumber}',
            ),
            backgroundColor: isKitchen ? MerchantColors.primary : MerchantColors.accentTeal,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _orders = liveOrders;
      });
    } catch (_) {}
  }

  void _onOrderUpdated(KdsOrder updatedOrder) {
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == updatedOrder.id);
      if (idx != -1) {
        _orders[idx] = updatedOrder;
      }
    });

    String statusStr = 'placed';
    switch (updatedOrder.status) {
      case KdsTicketStatus.newOrder:
        statusStr = 'placed';
        break;
      case KdsTicketStatus.preparing:
        statusStr = 'preparing';
        break;
      case KdsTicketStatus.readyForPickup:
        statusStr = 'ready_for_pickup';
        break;
      case KdsTicketStatus.completed:
        statusStr = 'delivered';
        break;
      case KdsTicketStatus.cancelled:
        statusStr = 'cancelled';
        break;
    }

    MerchantSupabaseService.updateOrderStatus(updatedOrder.id, statusStr);
  }

  void _onProductUpdated(CatalogProduct updatedProduct) {
    setState(() {
      final idx = _catalog.indexWhere((p) => p.id == updatedProduct.id);
      if (idx != -1) {
        _catalog[idx] = updatedProduct;
      }
    });

    MerchantSupabaseService.updateProductStock(updatedProduct.id, updatedProduct.inStock);
    MerchantSupabaseService.updateProductPrice(updatedProduct.id, updatedProduct.priceLyd);
  }

  int get _newOrdersCount =>
      _orders.where((o) => o.status == KdsTicketStatus.newOrder).length;

  void _toggleStoreStatus(StoreStatus newStatus) {
    setState(() {
      _storeStatus = newStatus;
    });

    final msg = newStatus == StoreStatus.open
        ? '🟢 المتجر مفتوح ويستقبل الطلبات في نالوت'
        : (newStatus == StoreStatus.rushHour
            ? '🟡 تم تفعيل وضع الذروة (+15 دقيقة لوقت التجهيز)'
            : '🔴 تم إيقاف استقبال الطلبات (المتجر مغلق)');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: newStatus == StoreStatus.open
            ? MerchantColors.readyGreen
            : (newStatus == StoreStatus.rushHour
                ? MerchantColors.accentAmber
                : MerchantColors.rejectedRed),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _currentStore.mode == PartnerAppMode.kitchen
          ? KdsScreen(
              orders: _orders,
              onOrderUpdated: _onOrderUpdated,
            )
          : RetailPickingScreen(
              orders: _orders,
              onOrderUpdated: _onOrderUpdated,
              store: _currentStore,
            ),
      CatalogScreen(
        catalog: _catalog,
        onProductUpdated: _onProductUpdated,
      ),
      SalesAnalyticsScreen(
        orders: _orders,
        store: _currentStore,
      ),
    ];

    return Scaffold(
      backgroundColor: MerchantColors.darkBg,
      // Top Store Header Banner with Store Switcher
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: MerchantColors.darkSurface,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 14,
            right: 14,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Store Title & Interactive Switcher
              PopupMenuButton<PartnerStore>(
                initialValue: _currentStore,
                onSelected: _switchStore,
                color: MerchantColors.darkCard,
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: _currentStore.mode == PartnerAppMode.kitchen
                            ? MerchantColors.primaryGradient
                            : const LinearGradient(
                                colors: [MerchantColors.accentTeal, Color(0xFF0F766E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (_currentStore.mode == PartnerAppMode.kitchen
                                    ? MerchantColors.primary
                                    : MerchantColors.accentTeal)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(_currentStore.icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              _currentStore.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _currentStore.district,
                              style: const TextStyle(fontSize: 10, color: Colors.white54),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _currentStore.mode == PartnerAppMode.kitchen
                                    ? MerchantColors.primary.withValues(alpha: 0.2)
                                    : MerchantColors.accentTeal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _currentStore.mode == PartnerAppMode.kitchen ? 'مطبخ 👨‍🍳' : 'تجزئة 🛒',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: _currentStore.mode == PartnerAppMode.kitchen
                                      ? MerchantColors.primaryLight
                                      : MerchantColors.accentTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                itemBuilder: (ctx) => PartnerStore.nalutStores.map((s) {
                  final isSelected = s.id == _currentStore.id;
                  final isKitchen = s.mode == PartnerAppMode.kitchen;
                  return PopupMenuItem<PartnerStore>(
                    value: s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isKitchen ? MerchantColors.primary : MerchantColors.accentTeal)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              s.icon,
                              color: isKitchen ? MerchantColors.primary : MerchantColors.accentTeal,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                                    color: isSelected ? MerchantColors.primary : Colors.white,
                                  ),
                                ),
                                Text(
                                  '${s.district} • ${isKitchen ? "شاشة مطبخ KDS" : "تجميع سلة 🛒"}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: MerchantColors.readyGreen, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Store Status Quick Toggle Popup
              PopupMenuButton<StoreStatus>(
                initialValue: _storeStatus,
                onSelected: _toggleStoreStatus,
                color: MerchantColors.darkCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _storeStatus == StoreStatus.open
                        ? MerchantColors.readyGreen.withValues(alpha: 0.2)
                        : (_storeStatus == StoreStatus.rushHour
                            ? MerchantColors.accentAmber.withValues(alpha: 0.2)
                            : MerchantColors.rejectedRed.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _storeStatus == StoreStatus.open
                          ? MerchantColors.readyGreen
                          : (_storeStatus == StoreStatus.rushHour
                              ? MerchantColors.accentAmber
                              : MerchantColors.rejectedRed),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _storeStatus == StoreStatus.open
                              ? MerchantColors.readyGreen
                              : (_storeStatus == StoreStatus.rushHour
                                  ? MerchantColors.accentAmber
                                  : MerchantColors.rejectedRed),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _storeStatus == StoreStatus.open
                            ? 'مفتوح 🟢'
                            : (_storeStatus == StoreStatus.rushHour ? 'ذروة 🟡' : 'مغلق 🔴'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: StoreStatus.open,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: MerchantColors.readyGreen, size: 18),
                        SizedBox(width: 8),
                        Text('مفتوح ونستقبل الطلبات 🟢', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: StoreStatus.rushHour,
                    child: Row(
                      children: [
                        Icon(Icons.access_time_filled_rounded, color: MerchantColors.accentAmber, size: 18),
                        SizedBox(width: 8),
                        Text('ساعة ذروة ضغط (+15 دقيقة) 🟡', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: StoreStatus.closed,
                    child: Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: MerchantColors.rejectedRed, size: 18),
                        SizedBox(width: 8),
                        Text('مغلق حالياً 🔴', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: MerchantColors.darkSurface,
        indicatorColor: (_currentStore.mode == PartnerAppMode.kitchen
                ? MerchantColors.primary
                : MerchantColors.accentTeal)
            .withValues(alpha: 0.25),
        elevation: 10,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _newOrdersCount > 0,
              label: Text('$_newOrdersCount'),
              backgroundColor: MerchantColors.newOrderAmber,
              textColor: Colors.black,
              child: Icon(
                _currentStore.mode == PartnerAppMode.kitchen
                    ? Icons.receipt_long_outlined
                    : Icons.inventory_2_outlined,
                color: Colors.white70,
              ),
            ),
            selectedIcon: Badge(
              isLabelVisible: _newOrdersCount > 0,
              label: Text('$_newOrdersCount'),
              backgroundColor: MerchantColors.newOrderAmber,
              textColor: Colors.black,
              child: Icon(
                _currentStore.mode == PartnerAppMode.kitchen
                    ? Icons.receipt_long_rounded
                    : Icons.inventory_2_rounded,
                color: _currentStore.mode == PartnerAppMode.kitchen
                    ? MerchantColors.primary
                    : MerchantColors.accentTeal,
              ),
            ),
            label: _currentStore.mode == PartnerAppMode.kitchen ? 'الطلبات والتحضير' : 'تجهيز الطلبات 📦',
          ),
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.menu_book_rounded, color: MerchantColors.primary),
            label: 'قائمة الأصناف',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.analytics_rounded, color: MerchantColors.primary),
            label: 'المبيعات والأرباح',
          ),
        ],
      ),
    );
  }
}

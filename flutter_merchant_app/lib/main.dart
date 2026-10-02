import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'merchant_login_screen.dart';
import 'merchant_receipts_screen.dart';
import 'merchant_inventory_screen.dart';
import 'kds_screen.dart';
import 'retail_picking_screen.dart';
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
      theme: MerchantTheme.lightTheme,
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
      home: const MerchantAuthGate(),
    );
  }
}

/// ============================================================================
/// AUTH GATEWAY (عزل المتاجر والتحقق من تسجيل الدخول)
/// ============================================================================

class MerchantAuthGate extends StatefulWidget {
  const MerchantAuthGate({super.key});

  @override
  State<MerchantAuthGate> createState() => _MerchantAuthGateState();
}

class _MerchantAuthGateState extends State<MerchantAuthGate> {
  bool _isChecking = true;
  bool _isLoggedIn = false;
  PartnerStore _activeStore = PartnerStore.defaultStore;
  MerchantUser? _activeUser;

  @override
  void initState() {
    super.initState();
    _checkStoredSession();
  }

  Future<void> _checkStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool('wasel_merchant_logged_in') ?? false;
      final storeId = prefs.getString('wasel_active_store_id');
      final userPhone = prefs.getString('wasel_merchant_user_phone');
      final userName = prefs.getString('wasel_merchant_user_name');
      final userRole = prefs.getString('wasel_merchant_user_role');

      if (loggedIn && storeId != null) {
        final storeName = prefs.getString('wasel_active_store_name');
        final storeType = prefs.getString('wasel_active_store_type') ?? 'restaurant';
        final storeDistrict = prefs.getString('wasel_active_store_district') ?? 'نالوت';
        final storeMode = prefs.getString('wasel_active_store_mode') ?? 'kitchen';

        final store = PartnerStore.nalutStores.firstWhere(
          (s) => s.id == storeId,
          orElse: () => PartnerStore(
            id: storeId,
            name: storeName ?? (userName ?? 'متجر نالوت'),
            nameEn: '',
            type: storeType,
            district: storeDistrict,
            phone: userPhone ?? '',
            mode: storeMode == 'retail' ? PartnerAppMode.retail : PartnerAppMode.kitchen,
            icon: storeMode == 'retail' ? Icons.shopping_cart_rounded : Icons.storefront_rounded,
          ),
        );

        _activeStore = store;
        _isLoggedIn = true;
        _activeUser = MerchantUser(
          id: 'usr_$storeId',
          phone: userPhone ?? '0910000000',
          name: userName ?? store.name,
          storeId: store.id,
          role: userRole ?? 'مدير المتجر',
        );
        MerchantSupabaseService.currentStoreId = store.id;
        MerchantSupabaseService.currentUser = _activeUser;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  void _onLoginSuccess(MerchantUser user, PartnerStore store) {
    setState(() {
      _activeUser = user;
      _activeStore = store;
      _isLoggedIn = true;
      MerchantSupabaseService.currentStoreId = store.id;
      MerchantSupabaseService.currentUser = user;
    });
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wasel_merchant_logged_in');
    await prefs.remove('wasel_active_store_id');
    await prefs.remove('wasel_merchant_user_phone');
    await prefs.remove('wasel_merchant_user_name');
    await prefs.remove('wasel_merchant_user_role');

    try {
      await MerchantSupabaseService.toggleStoreStatus(_activeStore.id, false);
    } catch (_) {}

    MerchantSupabaseService.currentUser = null;

    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _activeUser = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👋 تم تسجيل الخروج من المتجر بنجاح'),
          backgroundColor: MerchantColors.readyGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: MerchantColors.lightBg,
        body: Center(
          child: CircularProgressIndicator(color: MerchantColors.primary),
        ),
      );
    }

    if (!_isLoggedIn) {
      return MerchantLoginScreen(
        onLoginSuccess: _onLoginSuccess,
      );
    }

    return MerchantMainShell(
      store: _activeStore,
      user: _activeUser,
      onLogout: _handleLogout,
    );
  }
}

/// ============================================================================
/// MAIN ISOLATED MERCHANT SHELL
/// ============================================================================

class MerchantMainShell extends StatefulWidget {
  final PartnerStore store;
  final MerchantUser? user;
  final VoidCallback onLogout;

  const MerchantMainShell({
    super.key,
    required this.store,
    this.user,
    required this.onLogout,
  });

  @override
  State<MerchantMainShell> createState() => _MerchantMainShellState();
}

class _MerchantMainShellState extends State<MerchantMainShell> {
  int _currentIndex = 0;
  StoreStatus _storeStatus = StoreStatus.open;
  Timer? _pollTimer;
  Timer? _heartbeatTimer;

  late PartnerStore _currentStore;
  late List<KdsOrder> _orders;
  late List<CatalogProduct> _catalog;

  @override
  void initState() {
    super.initState();
    _currentStore = widget.store;
    MerchantSupabaseService.currentStoreId = _currentStore.id;

    _orders = [];
    _catalog = [];

    _initNotifications();
    _loadLiveMerchantData();

    // Auto-open store via immediate heartbeat upon entering the app shell
    MerchantSupabaseService.sendHeartbeat(_currentStore.id);

    // Continuous presence heartbeat every 25 seconds while app is active
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_storeStatus != StoreStatus.closed) {
        MerchantSupabaseService.sendHeartbeat(_currentStore.id);
      }
    });

    // Poll Supabase / backend every 4 seconds for new incoming orders
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollOrdersSilently();
    });
  }

  Future<void> _initNotifications() async {
    try {
      final notif = MerchantNotificationService();
      await notif.initialize().timeout(const Duration(seconds: 4));
      await notif.subscribeToStore(_currentStore.id).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    // Unsubscribe from store push alerts
    MerchantNotificationService().unsubscribeFromStore(_currentStore.id);
    // Note: Store status is NOT automatically set to false here so incoming customer orders are not disrupted by app minimization
    super.dispose();
  }

  Future<void> _loadLiveMerchantData() async {
    // 1. Immediately hydrate cached orders from disk (zero-latency kitchen tickets)
    try {
      final cachedOrders = await MerchantSupabaseService.loadCachedOrders(_currentStore.id);
      if (cachedOrders.isNotEmpty && mounted) {
        setState(() {
          _orders = cachedOrders;
        });
      }
    } catch (_) {}

    // 2. Fetch live data from backend and Supabase
    try {
      final liveOrders = await MerchantSupabaseService.fetchOrders(_currentStore.id);
      final liveCatalog = await MerchantSupabaseService.fetchCatalog(_currentStore.id);
      final liveStatus = await MerchantSupabaseService.fetchStoreStatus(_currentStore.id);
      if (mounted) {
        setState(() {
          _orders = liveOrders;
          _catalog = liveCatalog;
          if (liveStatus != null) {
            _storeStatus = liveStatus ? StoreStatus.open : StoreStatus.closed;
            _currentStore = _currentStore.copyWith(isOpen: liveStatus);
          }
        });
      }
    } catch (_) {}
  }

  bool _isPolling = false;

  Future<void> _pollOrdersSilently() async {
    if (_isPolling) return;
    _isPolling = true;
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
        // Kitchen / Retail Alert Notification
        MerchantNotificationService().showKitchenOrderAlert(
          title: isKitchen
              ? '🚨 تنبيه طلب جديد: ${newOrd.orderNumber}'
              : '🛒 طلب تجميع جديد: ${newOrd.orderNumber}',
          body: 'طلب بقيمة ${newOrd.totalAmountLyd.toStringAsFixed(2)} د.ل لـ ${_currentStore.name}.',
        );

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
    } catch (_) {
    } finally {
      _isPolling = false;
    }
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
        statusStr = 'out_for_delivery';
        MerchantSupabaseService.confirmHandover(
          updatedOrder.id,
          updatedOrder.handoverCode ?? (updatedOrder.orderNumber.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')),
        );
        break;
      case KdsTicketStatus.cancelled:
        statusStr = 'cancelled';
        break;
    }

    MerchantSupabaseService.updateOrderStatus(
      updatedOrder.id,
      statusStr,
      prepTimeMinutes: updatedOrder.prepTimeMinutes,
    );
  }

  void _onProductUpdated(CatalogProduct updatedProduct) {
    setState(() {
      final idx = _catalog.indexWhere((p) => p.id == updatedProduct.id);
      if (idx != -1) {
        _catalog[idx] = updatedProduct;
      }
    });

    MerchantSupabaseService.updateProductStock(updatedProduct.id, updatedProduct.inStock, updatedProduct.stockQuantity);
    MerchantSupabaseService.updateProductPrice(updatedProduct.id, updatedProduct.priceLyd);
  }

  int get _newOrdersCount =>
      _orders.where((o) => o.status == KdsTicketStatus.newOrder).length;

  void _toggleStoreStatus(StoreStatus newStatus) {
    final bool isOpen = newStatus != StoreStatus.closed;

    setState(() {
      _storeStatus = newStatus;
      _currentStore = _currentStore.copyWith(isOpen: isOpen);
    });

    // Sync live with Unified Backend (emits store:status_changed) and Supabase
    if (isOpen) {
      MerchantSupabaseService.sendHeartbeat(_currentStore.id);
      MerchantSupabaseService.toggleStoreStatus(_currentStore.id, true);
    } else {
      MerchantSupabaseService.toggleStoreStatus(_currentStore.id, false);
    }

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

  Future<void> _switchStore(PartnerStore newStore) async {
    Navigator.pop(context);
    if (newStore.id == _currentStore.id) return;

    setState(() {
      _currentStore = newStore;
      _orders = [];
      _catalog = [];
    });

    MerchantSupabaseService.currentStoreId = newStore.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wasel_active_store_id', newStore.id);
    await prefs.setString('wasel_active_store_name', newStore.name);
    await prefs.setString('wasel_active_store_type', newStore.type);
    await prefs.setString('wasel_active_store_district', newStore.district);
    await prefs.setString('wasel_active_store_mode', newStore.mode == PartnerAppMode.retail ? 'retail' : 'kitchen');

    _initNotifications();
    _loadLiveMerchantData();
    MerchantSupabaseService.sendHeartbeat(newStore.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏪 تم التبديل إلى: ${newStore.name}'),
          backgroundColor: MerchantColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showStoreSwitcherModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MerchantColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
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
                      Icon(Icons.swap_horiz_rounded, color: MerchantColors.primary, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'تبديل متجر نالوت النشط',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: MerchantColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: MerchantColors.lightTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: MerchantColors.lightBorder),
              const SizedBox(height: 8),
              ...PartnerStore.nalutStores.map((st) {
                final isSelected = st.id == _currentStore.id;
                final isKitchen = st.mode == PartnerAppMode.kitchen;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? MerchantColors.primary : MerchantColors.lightBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    tileColor: isSelected ? MerchantColors.statusNewBg : const Color(0xFFF8FAFC),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isKitchen ? MerchantColors.primary : MerchantColors.accentTeal).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(st.icon, color: isKitchen ? MerchantColors.primary : MerchantColors.accentTeal, size: 20),
                    ),
                    title: Text(
                      st.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? MerchantColors.statusNewText : MerchantColors.lightTextPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${st.district} • ${isKitchen ? "مطبخ وتجهيز وجبات 🍳" : "تجهيز طلبات سوبرماركت 🛒"}',
                      style: const TextStyle(fontSize: 11, color: MerchantColors.lightTextSecondary),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: MerchantColors.primary)
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: MerchantColors.lightTextMuted),
                    onTap: () => _switchStore(st),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showStoreProfileModal() {
    final user = widget.user;
    showModalBottomSheet(
      context: context,
      backgroundColor: MerchantColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: MerchantColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_currentStore.icon, color: MerchantColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStore.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: MerchantColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentStore.district,
                          style: const TextStyle(fontSize: 12, color: MerchantColors.lightTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: MerchantColors.lightTextSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: MerchantColors.lightBorder, height: 24),
              if (user != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_rounded, color: MerchantColors.accentTeal),
                  title: Text(
                    user.name,
                    style: const TextStyle(color: MerchantColors.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${user.role} • هاتف: ${user.phone}',
                    style: const TextStyle(color: MerchantColors.lightTextSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.verified_user_rounded, color: MerchantColors.readyGreen),
                title: Text('نطاق المتجر معزول ومحمي', style: TextStyle(color: MerchantColors.lightTextPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('جميع الطلبات والواصلات والجرد تتبع هذا الفرع حصراً', style: TextStyle(color: MerchantColors.lightTextSecondary, fontSize: 11)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MerchantColors.rejectedRed.withValues(alpha: 0.1),
                  foregroundColor: MerchantColors.rejectedRed,
                  side: const BorderSide(color: MerchantColors.rejectedRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onLogout();
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'تسجيل الخروج من المتجر 🚪',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      // 1. سير الطلبات والمطبخ
      _currentStore.mode == PartnerAppMode.kitchen
          ? KdsScreen(
              orders: _orders,
              onOrderUpdated: _onOrderUpdated,
              onRefresh: _loadLiveMerchantData,
            )
          : RetailPickingScreen(
              orders: _orders,
              onOrderUpdated: _onOrderUpdated,
              store: _currentStore,
            ),

      // 2. الواصلات والحسابات
      MerchantReceiptsScreen(
        store: _currentStore,
      ),

      // 3. الجرد والمخزون
      MerchantInventoryScreen(
        catalog: _catalog,
        store: _currentStore,
        onProductUpdated: _onProductUpdated,
      ),

      // 4. تقارير المبيعات والأرباح
      SalesAnalyticsScreen(
        orders: _orders,
        store: _currentStore,
      ),
    ];

    return Scaffold(
      backgroundColor: MerchantColors.lightBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          decoration: const BoxDecoration(
            color: MerchantColors.lightSurface,
            border: Border(
              bottom: BorderSide(color: MerchantColors.lightBorder, width: 1),
            ),
            boxShadow: MerchantShadows.subtle,
          ),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 14,
            right: 14,
            bottom: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Store Identity & Quick Switch Chip
              Row(
                children: [
                  InkWell(
                    onTap: _showStoreProfileModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
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
                                    .withValues(alpha: 0.25),
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
                            Text(
                              _currentStore.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: MerchantColors.lightTextPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _currentStore.district,
                                  style: const TextStyle(fontSize: 11, color: MerchantColors.lightTextSecondary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _currentStore.mode == PartnerAppMode.kitchen
                                        ? MerchantColors.statusNewBg
                                        : MerchantColors.statusPrepBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _currentStore.mode == PartnerAppMode.kitchen ? 'مطبخ 🍳' : 'سوبرماركت 🛒',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _currentStore.mode == PartnerAppMode.kitchen
                                          ? MerchantColors.statusNewText
                                          : MerchantColors.statusPrepText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Switch Button
                  InkWell(
                    onTap: _showStoreSwitcherModal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MerchantColors.lightBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 14, color: MerchantColors.lightTextSecondary),
                          SizedBox(width: 4),
                          Text(
                            'تبديل',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MerchantColors.lightTextSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Store Status Quick Toggle & Profile Button
              Row(
                children: [
                  PopupMenuButton<StoreStatus>(
                    initialValue: _storeStatus,
                    onSelected: _toggleStoreStatus,
                    color: MerchantColors.lightSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: MerchantColors.lightBorder),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _storeStatus == StoreStatus.open
                            ? MerchantColors.statusReadyBg
                            : (_storeStatus == StoreStatus.rushHour
                                ? MerchantColors.statusNewBg
                                : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _storeStatus == StoreStatus.open
                              ? MerchantColors.statusReadyBorder
                              : (_storeStatus == StoreStatus.rushHour
                                  ? MerchantColors.statusNewBorder
                                  : const Color(0xFFFCA5A5)),
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _storeStatus == StoreStatus.open
                                  ? MerchantColors.statusReadyText
                                  : (_storeStatus == StoreStatus.rushHour
                                      ? MerchantColors.statusNewText
                                      : MerchantColors.rejectedRed),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: MerchantColors.lightTextSecondary),
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
                            Text('مفتوح ونستقبل الطلبات 🟢', style: TextStyle(color: MerchantColors.lightTextPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: StoreStatus.rushHour,
                        child: Row(
                          children: [
                            Icon(Icons.access_time_filled_rounded, color: MerchantColors.accentAmber, size: 18),
                            SizedBox(width: 8),
                            Text('ساعة ذروة ضغط (+15 دقيقة) 🟡', style: TextStyle(color: MerchantColors.lightTextPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: StoreStatus.closed,
                        child: Row(
                          children: [
                            Icon(Icons.cancel_rounded, color: MerchantColors.rejectedRed, size: 18),
                            SizedBox(width: 8),
                            Text('مغلق حالياً 🔴', style: TextStyle(color: MerchantColors.lightTextPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined, color: MerchantColors.lightTextSecondary, size: 26),
                    tooltip: 'بيانات المتجر وتسجيل الخروج',
                    onPressed: _showStoreProfileModal,
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
        backgroundColor: MerchantColors.lightSurface,
        indicatorColor: (_currentStore.mode == PartnerAppMode.kitchen
                ? MerchantColors.primary
                : MerchantColors.accentTeal)
            .withValues(alpha: 0.15),
        elevation: 0,
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
                color: MerchantColors.lightTextSecondary,
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
            label: _currentStore.mode == PartnerAppMode.kitchen ? 'الطلبات' : 'التجهيز 📦',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_outlined, color: MerchantColors.lightTextSecondary),
            selectedIcon: Icon(Icons.receipt_rounded, color: MerchantColors.primary),
            label: 'الواصلات',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined, color: MerchantColors.lightTextSecondary),
            selectedIcon: Icon(Icons.inventory_2_rounded, color: MerchantColors.primary),
            label: 'الجرد',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined, color: MerchantColors.lightTextSecondary),
            selectedIcon: Icon(Icons.analytics_rounded, color: MerchantColors.primary),
            label: 'الأرباح',
          ),
        ],
      ),
    );
  }
}

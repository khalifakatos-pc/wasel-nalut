import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'driver_home_screen.dart';
import 'driver_login_screen.dart';
import 'active_delivery_flow_screen.dart';
import 'driver_wallet_screen.dart';
import 'services/driver_notification_service.dart';
import 'services/driver_supabase_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaselCaptainApp());
}

/// ============================================================================
/// CAPTAIN WASEL (كابتن واصل) DRIVER APP — MAIN ENTRY POINT & AUTH GATE
/// ============================================================================

class WaselCaptainApp extends StatefulWidget {
  const WaselCaptainApp({super.key});

  @override
  State<WaselCaptainApp> createState() => _WaselCaptainAppState();
}

class _WaselCaptainAppState extends State<WaselCaptainApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _initNotificationsAsync();
  }

  Future<void> _checkInitialAuth() async {
    final loggedIn = await DriverSupabaseService.loadSavedCaptain();
    if (mounted) {
      setState(() {
        _isLoggedIn = loggedIn;
        _isCheckingAuth = false;
      });
    }
  }

  Future<void> _initNotificationsAsync() async {
    try {
      await DriverNotificationService().initialize().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كابتن واصل | Captain Wasel (نالوت)',
      debugShowCheckedModeBanner: false,
      theme: DriverTheme.lightTheme,
      darkTheme: DriverTheme.darkTheme,
      themeMode: _themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _isCheckingAuth
          ? const Scaffold(
              backgroundColor: DriverColors.darkBg,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delivery_dining_rounded, size: 64, color: DriverColors.primary),
                    SizedBox(height: 20),
                    CircularProgressIndicator(color: DriverColors.primary, strokeWidth: 3),
                    SizedBox(height: 16),
                    Text(
                      'جاري التحقق من هوية الكابتن...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : (!_isLoggedIn
              ? DriverLoginScreen(onLoginSuccess: _handleLoginSuccess)
              : DriverMainNavigationHarness(
                  onToggleTheme: toggleTheme,
                  onLogout: _handleLogout,
                )),
    );
  }
}

class DriverMainNavigationHarness extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const DriverMainNavigationHarness({
    super.key,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<DriverMainNavigationHarness> createState() => _DriverMainNavigationHarnessState();
}

class _DriverMainNavigationHarnessState extends State<DriverMainNavigationHarness> {
  int _currentIndex = 0;
  ActiveDeliveryOrder? _currentActiveDelivery;

  @override
  void initState() {
    super.initState();
    _currentActiveDelivery = null;
    _checkExistingActiveDelivery();
  }

  Future<void> _checkExistingActiveDelivery() async {
    try {
      final orders = await DriverSupabaseService.fetchAvailableOrders();
      final ongoing = orders.cast<Map<String, dynamic>>().firstWhere(
        (o) => o['driver_id'] == DriverSupabaseService.activeDriverId &&
               o['status'] == 'out_for_delivery',
        orElse: () => <String, dynamic>{},
      );
      if (ongoing.isNotEmpty && mounted) {
        final paymentMethod = ongoing['payment_method']?.toString() ?? 'cash';
        final isCod = paymentMethod == 'cash' || paymentMethod == 'cod';
        final dynamic rawAmt = ongoing['total_amount_lyd'] ?? ongoing['total_amount'];
        final double amount = (rawAmt is num) ? rawAmt.toDouble() : 35.0;
        final rawPin = (ongoing['otp_code'] ?? ongoing['delivery_pin'])?.toString();
        final otp = (rawPin != null && rawPin.isNotEmpty) ? rawPin : '1234';
        setState(() {
          _currentActiveDelivery = ActiveDeliveryOrder(
            orderId: ongoing['id']?.toString() ?? '',
            orderNumber: ongoing['order_number']?.toString() ?? '#W-100',
            storeName: ongoing['store_name']?.toString() ?? 'قصر نالوت للمأكولات',
            storePhone: '091-2233445',
            storeAddress: 'نالوت - الشارع الرئيسي بجوار القلعة',
            storeLatitude: 31.8680,
            storeLongitude: 10.9850,
            customerName: ongoing['customer_name']?.toString() ?? 'زبون نالوت',
            customerPhone: ongoing['customer_phone']?.toString() ?? '091-7788990',
            customerAddress: ongoing['delivery_address']?.toString() ?? 'نالوت - حي الزهور',
            customerNotes: ongoing['notes']?.toString() ?? 'الدق على الباب الخارجي',
            customerLatitude: 31.8620,
            customerLongitude: 10.9780,
            paymentType: isCod ? PaymentType.cashOnDelivery : PaymentType.prepaidSadad,
            codAmountLyd: amount,
            customerOtpPin: otp,
            driverPayoutLyd: 7.5,
            items: [
              DeliveryItem(
                name: 'طلب وجبة / مشتريات نالوت',
                quantity: 1,
                options: 'طلب نشط',
                unitPriceLyd: amount,
              ),
            ],
          );
        });
      }
    } catch (_) {}
  }

  void _onStartDelivery(ActiveDeliveryOrder order) {
    setState(() {
      _currentActiveDelivery = order;
      _currentIndex = 1;
    });
  }

  void _onFinishedDelivery() {
    setState(() {
      _currentActiveDelivery = null;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DriverHomeScreen(
        onToggleTheme: widget.onToggleTheme,
        onStartDelivery: _onStartDelivery,
      ),
      _currentActiveDelivery != null
          ? ActiveDeliveryFlowScreen(
              order: _currentActiveDelivery!,
              onFinishedDelivery: _onFinishedDelivery,
            )
          : Scaffold(
              backgroundColor: DriverColors.darkBg,
              appBar: AppBar(title: const Text('المشوار الجاري')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delivery_dining_rounded, size: 64, color: DriverColors.offlineGrey),
                      const SizedBox(height: 16),
                      const Text(
                        'لا يوجد مشوار توصيل نشط حالياً',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'في انتظار وصول طلبات جديدة من مطاعم ومتاجر نالوت عبر الرادار المباشر',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: DriverColors.darkTextMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _currentIndex = 0),
                        icon: const Icon(Icons.radar_rounded, color: DriverColors.primary),
                        label: const Text(
                          'الانتقال للرادار لاستقبال الطلبات',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: DriverColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      DriverWalletScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            selectedIcon: Icon(Icons.radar_rounded, color: DriverColors.primary),
            label: 'الرئيسية والرادار',
          ),
          NavigationDestination(
            icon: Icon(Icons.navigation_rounded),
            selectedIcon: Icon(Icons.navigation_rounded, color: DriverColors.onlineGreen),
            label: 'المشوار الجاري',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: DriverColors.tadawulTeal),
            label: 'المحفظة والأرباح',
          ),
        ],
      ),
    );
  }
}

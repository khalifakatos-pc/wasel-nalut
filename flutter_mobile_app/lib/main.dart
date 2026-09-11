import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'design_system.dart';
import 'home_screen.dart';
import 'cart_checkout_screen.dart';
import 'orders_history_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'driver_radar_sheet.dart';
import 'order_tracking_screen.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/customer_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaselCustomerApp());
}

/// Unified Single-MaterialApp Root
class WaselCustomerApp extends StatefulWidget {
  const WaselCustomerApp({super.key});

  @override
  State<WaselCustomerApp> createState() => _WaselCustomerAppState();
}

class _WaselCustomerAppState extends State<WaselCustomerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _initServicesAsync();
  }

  Future<void> _initServicesAsync() async {
    try {
      await ApiService.loadToken().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await CustomerNotificationService().initialize().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      SocketService.connect(authToken: null);
    } catch (_) {}
  }

  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }

  void toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'واصل نالوت | Wasel Super-App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
      home: SplashScreen(
        isLoggedIn: ApiService.isLoggedIn,
        nextScreen: OnboardingScreen(
          onComplete: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MainNavigationShell(
                  onToggleTheme: toggleTheme,
                  isDark: _themeMode == ThemeMode.dark,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const MainNavigationShell({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _triggerDriverRadar() {
    showDialog(
      context: context,
      builder: (ctx) => DriverRadarSheet(
        onAccept: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '✅ تم قبول الطلب! جاري توجيهك إلى مطعم قصر نالوت للمشويات.'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
          );
        },
        onDecline: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('تم تفويت الطلب والبحث عن أقرب كابتن آخر.')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      CartCheckoutScreen(
          onBackToHome: () => setState(() => _currentIndex = 0)),
      const OrdersHistoryScreen(),
      const WalletScreen(),
      ProfileScreen(
        onToggleTheme: widget.onToggleTheme,
        isDark: widget.isDark,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggerDriverRadar,
        backgroundColor: AppColors.waselPrimary,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.sensors_rounded, size: 20),
        label: const Text(
          'رادار الكابتن',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home_rounded, color: AppColors.waselPrimary),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded,
                color: AppColors.waselPrimary),
            label: 'السلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded,
                color: AppColors.waselPrimary),
            label: 'طلباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.warning),
            label: 'المحفظة',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: AppColors.waselPurple),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

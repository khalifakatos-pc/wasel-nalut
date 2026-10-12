import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_ui/wasel_ui.dart';
import 'design_system.dart';
import 'home_screen.dart';
import 'cart_checkout_screen.dart';
import 'orders_history_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/customer_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure global error handlers
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Wasel FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Wasel PlatformDispatcher Error: $error\n$stack');
    return true; // prevent unhandled crash
  };

  // Guard Firebase initialization
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 1));
  } catch (e) {
    debugPrint('Firebase init bypassed: $e');
  }

  // Await ApiService.loadToken() and CartService.loadFromStorage() so session state is known before building widget tree
  try {
    await ApiService.loadToken().timeout(const Duration(seconds: 2));
    await CartService.loadFromStorage();
  } catch (e) {
    debugPrint('Startup hydration error: $e');
  }

  runApp(const WaselCustomerApp());
}

/// Unified Single-MaterialApp Root
class WaselCustomerApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const WaselCustomerApp({super.key});

  @override
  State<WaselCustomerApp> createState() => _WaselCustomerAppState();
}

class _WaselCustomerAppState extends State<WaselCustomerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
    _initServicesAsync();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('wasel_theme_mode');
      if (saved == 'dark' && mounted) {
        setState(() => _themeMode = ThemeMode.dark);
      } else if (saved == 'light' && mounted) {
        setState(() => _themeMode = ThemeMode.light);
      }
    } catch (_) {}
  }

  Future<void> _initServicesAsync() async {
    try {
      await CustomerNotificationService().initialize().timeout(const Duration(seconds: 2));
    } catch (_) {}
    // Background service initialized cleanly without triggering a rebuild race condition.
  }

  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }

  void toggleTheme() async {
    final next =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() {
      _themeMode = next;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'wasel_theme_mode', next == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final navigatorKey = WaselCustomerApp.navigatorKey;
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'واصل نالوت | Wasel Super-App',
      debugShowCheckedModeBanner: false,
      theme: WaselTheme.lightTheme,
      darkTheme: WaselTheme.darkTheme,
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
        isLoggedIn: ApiService.hasActiveSession,
        homeScreen: MainNavigationShell(
          onToggleTheme: toggleTheme,
          isDark: _themeMode == ThemeMode.dark,
        ),
        nextScreen: OnboardingScreen(
          onComplete: () {
            navigatorKey.currentState?.pushReplacement(
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
  final Set<int> _loadedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      _loadedTabs.contains(1)
          ? CartCheckoutScreen(
              onBackToHome: () => setState(() => _currentIndex = 0))
          : const SizedBox.shrink(),
      _loadedTabs.contains(2)
          ? const OrdersHistoryScreen()
          : const SizedBox.shrink(),
      _loadedTabs.contains(3)
          ? const WalletScreen()
          : const SizedBox.shrink(),
      _loadedTabs.contains(4)
          ? ProfileScreen(
              onToggleTheme: widget.onToggleTheme,
              isDark: widget.isDark,
            )
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: widget.isDark ? 0.22 : 0.15),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() {
              _currentIndex = index;
              _loadedTabs.add(index);
            }),
            elevation: 0,
            height: 64,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon:
                    Icon(Icons.home_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: const Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'السلة',
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'طلباتي',
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                    color: Theme.of(context).colorScheme.primary),
                label: 'المحفظة',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon:
                    Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

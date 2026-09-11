import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'driver_home_screen.dart';
import 'order_radar_dialog.dart';
import 'active_delivery_flow_screen.dart';
import 'driver_wallet_screen.dart';

void main() {
  runApp(const WaselCaptainApp());
}

/// ============================================================================
/// WASEL CAPTAIN DRIVER APP — MAIN ENTRY POINT & HARNESS
/// ============================================================================

class WaselCaptainApp extends StatefulWidget {
  const WaselCaptainApp({super.key});

  @override
  State<WaselCaptainApp> createState() => _WaselCaptainAppState();
}

class _WaselCaptainAppState extends State<WaselCaptainApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode for couriers

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كابتن واصل | Captain Wasel 🇱🇾',
      debugShowCheckedModeBanner: false,
      theme: DriverTheme.lightTheme,
      darkTheme: DriverTheme.darkTheme,
      themeMode: _themeMode,
      home: DriverMainNavigationHarness(
        onToggleTheme: toggleTheme,
      ),
    );
  }
}

class DriverMainNavigationHarness extends StatefulWidget {
  final VoidCallback onToggleTheme;

  const DriverMainNavigationHarness({
    super.key,
    required this.onToggleTheme,
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
    // Pre-seed an active order for easy instant testing
    _currentActiveDelivery = DriverMockData.getSampleActiveDelivery();
  }

  void _onStartDelivery(ActiveDeliveryOrder order) {
    setState(() {
      _currentActiveDelivery = order;
      _currentIndex = 1; // Switch to Active Delivery Flow tab
    });
  }

  void _onFinishedDelivery() {
    setState(() {
      _currentActiveDelivery = null;
      _currentIndex = 0; // Return to Home / Radar
    });
  }

  void _triggerIncomingRadarModal() {
    final sampleOrder = DriverMockData.getSampleIncomingOrder();
    OrderRadarDialog.show(
      context,
      order: sampleOrder,
      onAccept: (order) {
        final active = DriverMockData.getSampleActiveDelivery();
        _onStartDelivery(active);
      },
      onDecline: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order radar declined.'),
            backgroundColor: DriverColors.darkCard,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          : _buildNoActiveOrderPlaceholder(isDark),
      const DriverWalletScreen(),
      _buildProfileSettingsScreen(isDark),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      floatingActionButton: _currentIndex != 1
          ? FloatingActionButton.extended(
              onPressed: _triggerIncomingRadarModal,
              backgroundColor: DriverColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.radar_rounded),
              label: const Text('Order Radar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: isDark ? DriverColors.darkSurface : Colors.white,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: DriverColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.navigation_outlined),
                if (_currentActiveDelivery != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DriverColors.onlineGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: const Icon(Icons.navigation_rounded, color: DriverColors.primary),
            label: 'Active Trip',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: DriverColors.primary),
            label: 'Wallet & COD',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: DriverColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveOrderPlaceholder(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? DriverColors.darkBg : DriverColors.lightBg,
      appBar: AppBar(
        title: const Text('Active Delivery Flow'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? DriverColors.darkCard : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.moped_rounded, size: 64, color: DriverColors.offlineGrey),
              ),
              const SizedBox(height: 20),
              Text(
                'No Active Delivery Right Now',
                style: DriverTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Switch to Online mode or tap the Order Radar button below to simulate an incoming dispatch.',
                textAlign: TextAlign.center,
                style: DriverTypography.bodySmall.copyWith(
                  color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _triggerIncomingRadarModal,
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Trigger Incoming Radar Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DriverColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSettingsScreen(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? DriverColors.darkBg : DriverColors.lightBg,
      appBar: AppBar(
        title: const Text('Captain Profile & Fleet'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? DriverColors.darkCard : Colors.white,
              borderRadius: DriverRadius.radiusXl,
              border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: DriverColors.primaryGradient,
                  ),
                  child: const Icon(Icons.person_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mahmoud Al-Zintani',
                        style: DriverTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+218 91 876 5432 • Tripoli, Libya',
                        style: DriverTypography.bodySmall.copyWith(
                          color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                              borderRadius: DriverRadius.radiusXs,
                            ),
                            child: const Text(
                              'VERIFIED CAPTAIN 🇱🇾',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: DriverColors.onlineGreen),
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
          const SizedBox(height: 18),

          // Vehicle Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? DriverColors.darkCard : Colors.white,
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registered Vehicle Details',
                  style: DriverTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildProfileDetailRow('Vehicle Type', 'Motorcycle (Scooter)', Icons.two_wheeler_rounded, isDark),
                _buildProfileDetailRow('Model', 'Honda PCX 160 (Black)', Icons.electric_moped_rounded, isDark),
                _buildProfileDetailRow('Plate Number', '5-29418 🇱🇾 (Tripoli)', Icons.badge_outlined, isDark),
                _buildProfileDetailRow('License Status', 'Valid (Exp: Dec 2027)', Icons.verified_user_outlined, isDark),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Platform Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? DriverColors.darkCard : Colors.white,
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logistics App Preferences',
                  style: DriverTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('High Audio Radar Beep Alert'),
                  subtitle: const Text('Louder sound during helmet intercom use'),
                  value: true,
                  activeColor: DriverColors.primary,
                  onChanged: (_) {},
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto Night Mode for Driving'),
                  subtitle: const Text('Switch to OLED black after sunset (19:00)'),
                  value: true,
                  activeColor: DriverColors.primary,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: DriverColors.primary),
              const SizedBox(width: 8),
              Text(label, style: DriverTypography.bodySmall.copyWith(color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary)),
            ],
          ),
          Text(value, style: DriverTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

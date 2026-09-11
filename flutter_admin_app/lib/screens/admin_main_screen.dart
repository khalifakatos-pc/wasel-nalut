import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import 'dashboard_tab.dart';
import 'orders_tab.dart';
import 'stores_tab.dart';
import 'captains_tab.dart';
import 'accounting_tab.dart';
import 'smart_settings_tab.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  int _pendingPayoutCount = 0;
  Timer? _payoutPollingTimer;

  @override
  void initState() {
    super.initState();
    _checkPendingPayouts();
    // Poll every 10 seconds for new incoming payout requests from merchants/drivers
    _payoutPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkPendingPayouts();
    });
  }

  @override
  void dispose() {
    _payoutPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPendingPayouts() async {
    final list = await AdminSupabaseService.fetchPendingPayoutRequests();
    if (mounted) {
      setState(() {
        _pendingPayoutCount = list.length;
      });
    }
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const DashboardTab();
      case 1:
        return const OrdersTab();
      case 2:
        return const StoresTab();
      case 3:
        return const CaptainsTab();
      case 4:
        return const AccountingTab();
      case 5:
        return const SmartSettingsTab();
      default:
        return const DashboardTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Column(
          children: [
            // Top alert banner for pending bank transfer payout requests
            if (_pendingPayoutCount > 0 && _currentIndex != 4)
              SafeArea(
                bottom: false,
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4C1D95), Color(0xFF5B21B6)],
                      ),
                      border: Border(bottom: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.5))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: AdminColors.primaryGold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '🔔 تنبيه: يوجد $_pendingPayoutCount طلب تحويل مصرفي/سداد معلق من المطبخ!',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminColors.primaryGold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'معاينة وصرف ←',
                            style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: _buildTab(_currentIndex)),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AdminColors.surface,
            border: Border(top: BorderSide(color: AdminColors.divider, width: 1)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: AdminColors.surface,
            selectedItemColor: AdminColors.primaryGold,
            unselectedItemColor: AdminColors.textSecondary,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 10,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'الأرباح',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.radar_outlined),
                activeIcon: Icon(Icons.radar),
                label: 'الطلبات',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.storefront_outlined),
                activeIcon: Icon(Icons.storefront),
                label: 'المطاعم',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.two_wheeler_outlined),
                activeIcon: Icon(Icons.two_wheeler),
                label: 'الكباتن',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: _pendingPayoutCount > 0,
                  label: Text('$_pendingPayoutCount'),
                  backgroundColor: AdminColors.alertRed,
                  child: const Icon(Icons.receipt_long_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: _pendingPayoutCount > 0,
                  label: Text('$_pendingPayoutCount'),
                  backgroundColor: AdminColors.alertRed,
                  child: const Icon(Icons.receipt_long),
                ),
                label: 'المحاسبة',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.tune_outlined),
                activeIcon: Icon(Icons.tune),
                label: 'الحوافز',
              ),
            ],
          ),
        ),
      ),
    );
  }
}


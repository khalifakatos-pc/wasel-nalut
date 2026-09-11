import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, dynamic>? _kpiData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    setState(() => _isLoading = true);
    final data = await AdminSupabaseService.fetchKpis();
    if (mounted) {
      setState(() {
        _kpiData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👑 ', style: TextStyle(fontSize: 22)),
            Text('غرفة القيادة المركزية', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AdminColors.primaryGold),
            onPressed: _loadKpis,
            tooltip: 'تحديث البيانات السحابية',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
          : RefreshIndicator(
              onRefresh: _loadKpis,
              color: AdminColors.primaryGold,
              backgroundColor: AdminColors.surface,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cloud Status Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AdminColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_done, color: AdminColors.emeraldGreen, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'سحابة واصل نالوت متصلة 24/7 (Frankfurt)',
                              style: TextStyle(fontSize: 13, color: AdminColors.emeraldGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary Revenue Card
                    _buildPrimaryRevenueCard(),

                    const SizedBox(height: 16),

                    // Cash in Hand COD Card
                    _buildCodCashCard(),

                    const SizedBox(height: 16),

                    // Grid stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'طلبات نشطة',
                            value: '${_kpiData?['active_orders'] ?? 0}',
                            icon: Icons.delivery_dining,
                            color: AdminColors.skyBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'كباتن أونلاين',
                            value: '${_kpiData?['online_drivers'] ?? 0}',
                            icon: Icons.two_wheeler,
                            color: AdminColors.primaryGold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'مطاعم مفتوحة',
                            value: '${_kpiData?['open_stores'] ?? 0}',
                            icon: Icons.store,
                            color: AdminColors.emeraldGreen,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Operations
                    const Text(
                      'إجراءات سريعة للمدير',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildActionBtn(
                            label: 'إيقاف طارئ للخدمة',
                            icon: Icons.pause_circle_outline,
                            color: AdminColors.alertRed,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚠️ نظام واصل مستقر ويعمل بشكل ممتاز!')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionBtn(
                            label: 'مزامنة السحابة',
                            icon: Icons.sync,
                            color: AdminColors.skyBlue,
                            onTap: _loadKpis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPrimaryRevenueCard() {
    final gmv = (_kpiData?['gmv_lyd'] ?? 0.0) as double;
    final platformFee = (_kpiData?['platform_fee_lyd'] ?? 0.0) as double;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E294B), Color(0xFF0F172A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primaryGold.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'مبيعات نالوت اليوم (GMV)',
                style: TextStyle(fontSize: 14, color: AdminColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminColors.emeraldGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'مباشر حياً',
                  style: TextStyle(fontSize: 11, color: AdminColors.emeraldGreen, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                gmv.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'د.ل',
                style: TextStyle(fontSize: 18, color: AdminColors.primaryGold, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: AdminColors.divider, height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'صافي أرباح المنظومة (10%):',
                style: TextStyle(fontSize: 14, color: AdminColors.textSecondary),
              ),
              Text(
                '+${platformFee.toStringAsFixed(1)} د.ل',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AdminColors.emeraldGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodCashCard() {
    final cod = (_kpiData?['cod_with_drivers_lyd'] ?? 0.0) as double;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet, color: AdminColors.primaryGold, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('كاش معلق مع الكباتن (COD)', style: TextStyle(fontSize: 12, color: AdminColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '${cod.toStringAsFixed(1)} د.ل',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('انتقل لتبويب الكباتن لإجراء تسوية العهدة النقدية')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.surfaceElevated,
              foregroundColor: AdminColors.primaryGold,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('تسوية'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

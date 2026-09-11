import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'services/merchant_supabase_service.dart';

/// ============================================================================
/// STORE SALES, REVENUE & FINANCIAL SETTLEMENT SCREEN
/// ============================================================================

class SalesAnalyticsScreen extends StatelessWidget {
  final List<KdsOrder> orders;
  final PartnerStore store;

  const SalesAnalyticsScreen({
    super.key,
    required this.orders,
    required this.store,
  });

  double get _grossSalesToday =>
      orders.fold(0.0, (sum, o) => sum + (o.status != KdsTicketStatus.cancelled ? o.totalAmountLyd : 0.0)) + 480.00;

  double get _platformCommission => _grossSalesToday * 0.10; // 10% platform commission

  double get _netPayout => _grossSalesToday * 0.90; // 90% store net share

  void _showWithdrawModal(BuildContext context) {
    String selectedMethod = 'سداد (Sadad Pay)';
    final accountController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MerchantColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('سحب أرباح المتجر 💳', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text('الرصيد المتاح للسحب: ${_netPayout.toStringAsFixed(2)} د.ل', style: const TextStyle(color: MerchantColors.readyGreen, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),

              const Text('طريقة التحويل:', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedMethod,
                dropdownColor: MerchantColors.darkCard,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: MerchantColors.darkCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ['سداد (Sadad Pay)', 'تداول (Tadawul)', 'مصرف الجمهورية (IBAN)', 'المصرف التجاري الوطني']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: isSubmitting ? null : (val) {
                  if (val != null) setModalState(() => selectedMethod = val);
                },
              ),
              const SizedBox(height: 12),

              const Text('رقم الحساب / رقم المحفظة:', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 4),
              TextField(
                controller: accountController,
                enabled: !isSubmitting,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '091XXXXXXX أو رقم الآيبان المصرفي',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: MerchantColors.darkCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    isSubmitting ? 'جاري إرسال طلب السحب...' : 'تأكيد التحويل الفوري',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MerchantColors.revenueGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final acc = accountController.text.trim();
                          if (acc.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⚠️ يرجى إدخال رقم الحساب أو المحفظة أولاً'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);

                          final ok = await MerchantSupabaseService.requestPayout(
                            amountLyd: _netPayout,
                            method: selectedMethod,
                            accountNumber: acc,
                            storeName: store.name,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }

                          if (context.mounted) {
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('💸 تم إرسال طلب سحب ${_netPayout.toStringAsFixed(2)} د.ل عبر $selectedMethod إلى لوحة إدارة واصل بنجاح!'),
                                  backgroundColor: MerchantColors.revenueGreen,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('❌ تعذر إرسال الطلب، تأكد من الاتصال بالإنترنت.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
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
    return Scaffold(
      backgroundColor: MerchantColors.darkBg,
      appBar: AppBar(
        title: const Text('المبيعات والتقارير المالية 📊'),
        centerTitle: true,
        backgroundColor: MerchantColors.darkSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue Main Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: MerchantRadius.xl,
                boxShadow: [
                  BoxShadow(
                    color: MerchantColors.revenueGreen.withValues(alpha: 0.25),
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
                        'صافي أرباح المطعم المستحقة',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('اليوم في نالوت', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_netPayout.toStringAsFixed(2)} د.ل',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي المبيعات: ${_grossSalesToday.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        'عمولة المنصة (10%): -${_platformCommission.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Withdraw Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                label: const Text('سحب الأرباح لمصرفي أو سداد 🏦', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MerchantColors.darkCardElevated,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showWithdrawModal(context),
              ),
            ),
            const SizedBox(height: 20),

            // KPI 3-Column Metrics
            const Text('مؤشرات كفاءة وسرعة التحضير اليوم ⚡', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildKpiCard('الطلبات المكتملة', '18 طلب', Icons.check_circle_outline_rounded, MerchantColors.readyGreen),
                const SizedBox(width: 8),
                _buildKpiCard('متوسط وقت التجهيز', '12 دقيقة', Icons.timer_outlined, MerchantColors.primary),
                const SizedBox(width: 8),
                _buildKpiCard('تقييم الزبائن', '4.9 ⭐', Icons.star_outline_rounded, MerchantColors.accentAmber),
              ],
            ),
            const SizedBox(height: 24),

            // Transaction History
            const Text('سجل حركات الطلبات الأخيرة 🧾', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            ...orders.map((order) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MerchantColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MerchantColors.darkBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MerchantColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_rounded, color: MerchantColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                          Text(order.customerName, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+${order.totalAmountLyd.toStringAsFixed(2)} د.ل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('صافي 90%: +${(order.totalAmountLyd * 0.90).toStringAsFixed(2)} د.ل', style: const TextStyle(color: MerchantColors.readyGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                      Text(order.paymentMethod.split(' ')[0], style: const TextStyle(color: Colors.white38, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MerchantColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MerchantColors.darkBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      ),
    );
  }
}

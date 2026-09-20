import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final list = await AdminSupabaseService.fetchOrders();
    if (mounted) {
      setState(() {
        _orders = list;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'all') return _orders;
    return _orders.where((o) => o['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رادار الطلبات الحية في نالوت'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('طلب جديد', 'placed'),
                const SizedBox(width: 8),
                _buildFilterChip('قيد الطهي', 'preparing'),
                const SizedBox(width: 8),
                _buildFilterChip('في الطريق', 'out_for_delivery'),
                const SizedBox(width: 8),
                _buildFilterChip('تم التسليم', 'delivered'),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
                : _filteredOrders.isEmpty
                    ? const Center(child: Text('لا توجد طلبات في هذا القسم حالياً', style: TextStyle(color: AdminColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          return _buildOrderCard(order);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String statusKey) {
    final isSelected = _selectedFilter == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = statusKey),
      selectedColor: AdminColors.primaryGold,
      backgroundColor: AdminColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AdminColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'placed';
    final amount = (order['total_amount_lyd'] is num) ? (order['total_amount_lyd'] as num).toDouble() : 0.0;

    Color badgeColor;
    String badgeText;
    switch (status) {
      case 'placed':
        badgeColor = AdminColors.skyBlue;
        badgeText = 'جديد';
        break;
      case 'preparing':
        badgeColor = AdminColors.primaryGold;
        badgeText = 'قيد الطهي';
        break;
      case 'out_for_delivery':
        badgeColor = Colors.purpleAccent;
        badgeText = 'في الطريق 🛵';
        break;
      case 'delivered':
        badgeColor = AdminColors.emeraldGreen;
        badgeText = 'تم التسليم ✅';
        break;
      default:
        badgeColor = AdminColors.textSecondary;
        badgeText = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Order Number + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AdminColors.primaryGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      order['order_number'] ?? 'WAS-000',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(color: AdminColors.divider, height: 20),

            // Store & Customer
            Row(
              children: [
                const Icon(Icons.storefront, color: AdminColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['store_name'] ?? 'مطعم قصر نالوت',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_pin, color: AdminColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${order['customer_name'] ?? 'زبون'} • ${order['customer_phone'] ?? ''}',
                    style: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: AdminColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['delivery_address'] ?? 'نالوت - الحي المركزي',
                    style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),

            // Accountability & Timeline (Kitchen vs Captain)
            Builder(
              builder: (context) {
                final prepMins = order['prep_time_minutes'];
                final kitchenDelay = (order['kitchen_delay_seconds'] as num?)?.toInt() ?? 0;
                final driverDelay = (order['driver_delay_seconds'] as num?)?.toInt() ?? 0;
                final handoverAt = order['handover_at'];
                final driverArrivedAt = order['driver_arrived_at'];
                final readyAt = order['ready_at'];

                if (prepMins == null && kitchenDelay == 0 && driverDelay == 0 && handoverAt == null) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '⏱️ خط المسؤولية (المطبخ ⟷ الكابتن):',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminColors.primaryGold),
                          ),
                          if (kitchenDelay > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AdminColors.alertRed.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AdminColors.alertRed),
                              ),
                              child: Text(
                                'تأخير مطبخ: ${(kitchenDelay / 60).ceil()} د',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminColors.alertRed),
                              ),
                            )
                          else if (driverDelay > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Text(
                                'تأخير كابتن: ${(driverDelay / 60).ceil()} د',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            )
                          else
                            const Text(
                              'الأداء منضبط ⚡',
                              style: TextStyle(fontSize: 10, color: AdminColors.emeraldGreen, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• وقت الطهي: ${prepMins ?? 15} د'
                        '${readyAt != null ? " • تجهز ✅" : ""}'
                        '${driverArrivedAt != null ? " • الكابتن بالمطعم 📍" : ""}'
                        '${handoverAt != null ? " • عهدة الكابتن 🛵" : ""}',
                        style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: AdminColors.divider, height: 20),

            // Bottom Financials and Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('القيمة الإجمالية:', style: TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
                    Text(
                      '${amount.toStringAsFixed(1)} د.ل',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminColors.emeraldGreen),
                    ),
                  ],
                ),
                if (order['otp_code'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('OTP: ${order['otp_code']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.primaryGold)),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AdminColors.textSecondary),
                  color: AdminColors.surfaceElevated,
                  onSelected: (action) async {
                    if (action == 'delivered') {
                      await AdminSupabaseService.updateOrderStatus(order['id'], 'delivered');
                      _loadOrders();
                    } else if (action == 'cancel') {
                      await AdminSupabaseService.updateOrderStatus(order['id'], 'cancelled');
                      _loadOrders();
                    } else if (action == 'resolve_dispute') {
                      _showDisputeResolutionDialog(order);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'delivered', child: Text('✅ تأكيد اكتمال الطلب')),
                    const PopupMenuItem(value: 'resolve_dispute', child: Text('⚠️ فض نزاع عدم الرد / إلغاء مع تعويض')),
                    const PopupMenuItem(value: 'cancel', child: Text('❌ إلغاء عادي للطلب')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDisputeResolutionDialog(Map<String, dynamic> order) {
    String customerAction = 'blacklisted';
    String mealDisposal = 'captain_bonus';
    final double amount = (order['total_amount_lyd'] is num) ? (order['total_amount_lyd'] as num).toDouble() : 35.0;
    final double deliveryFee = 5.0;
    final double restaurantShare = (amount - deliveryFee) * 0.90;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (statefulCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            title: const Row(
              children: [
                Icon(Icons.gavel_rounded, color: AdminColors.primaryGold),
                SizedBox(width: 8),
                Text('غرفة فض النزاع: تعذر الاستلام'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الطلب: ${order['order_number']} • ${order['customer_name'] ?? 'زبون'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminColors.textPrimary),
                  ),
                  Text(
                    'هاتف الزبون: ${order['customer_phone'] ?? 'غير محدد'}',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                  ),
                  const Divider(color: AdminColors.divider, height: 20),

                  // Compensation summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.emeraldGreen.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🛡️ التعويضات المعتمدة آلياً:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminColors.emeraldGreen)),
                        const SizedBox(height: 6),
                        Text('• تعويض المطعم (سند صرف 90%): ${restaurantShare.toStringAsFixed(1)} د.ل', style: const TextStyle(fontSize: 12)),
                        Text('• تعويض الكابتن (أجر التوصيل): $deliveryFee د.ل', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Customer Action
                  const Text('إجراء معاقبة الزبون المتهرب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: customerAction,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'blacklisted', child: Text('⛔ حظر الرقم نهائياً (Blacklist)')),
                      DropdownMenuItem(value: 'negative_balance', child: Text('💳 قيد رصيد سالب (-35 د.ل)')),
                      DropdownMenuItem(value: 'excused', child: Text('🤝 قبول العذر وإعفاء (ظرف طارئ)')),
                    ],
                    onChanged: (val) => setDialogState(() => customerAction = val!),
                  ),

                  const SizedBox(height: 14),

                  // Meal Disposal
                  const Text('مصير الوجبة المحضرة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: mealDisposal,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'captain_bonus', child: Text('🎁 مكافأة وإكرامية للكابتن')),
                      DropdownMenuItem(value: 'flash_deal', child: Text('⚡ طرح كعرض خاطف بخصم 50%')),
                      DropdownMenuItem(value: 'discarded', child: Text('🗑️ إتلاف الوجبة وتسجيلها كتالف')),
                    ],
                    onChanged: (val) => setDialogState(() => mealDisposal = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emeraldGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await AdminSupabaseService.resolveNoShowDispute(
                    orderId: order['id'],
                    storeId: order['store_id'] ?? 'store_nalut_01',
                    storeName: order['store_name'] ?? 'مطعم قصر نالوت',
                    driverId: order['driver_id'] ?? 'drv_01',
                    driverName: order['driver_name'] ?? 'كابتن نالوت',
                    totalAmountLyd: amount,
                    deliveryFeeLyd: deliveryFee,
                    customerPhone: order['customer_phone'] ?? '0910000000',
                    customerAction: customerAction,
                    mealDisposal: mealDisposal,
                  );
                  _loadOrders();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AdminColors.emeraldGreen,
                      content: Text('✅ تم فض النزاع، تعويض الشركاء، وتطبيق الإجراء في السحابة بنجاح!'),
                    ),
                  );
                },
                child: const Text('اعتماد فض النزاع وحفظ السندات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

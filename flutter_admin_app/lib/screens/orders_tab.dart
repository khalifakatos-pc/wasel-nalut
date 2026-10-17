import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../services/admin_socket_service.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  StreamSubscription<Map<String, dynamic>>? _orderStatusSubscription;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _initSocketSubscription();
  }

  void _initSocketSubscription() {
    _orderStatusSubscription =
        AdminSocketService.instance.onOrderStatusChanged.listen((event) {
      if (mounted) {
        _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _orderStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث القائمة',
            onPressed: () => _loadOrders(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: ElevatedButton.icon(
              icon: const Text('🧹', style: TextStyle(fontSize: 16)),
              label: const Text(
                'تصفير كافة الطلبات',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.alertRed.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showPurgeOrdersDialog,
            ),
          ),
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
                _buildFilterChip('قيد التجهيز', 'preparing'),
                const SizedBox(width: 8),
                _buildFilterChip('جاهز للاستلام 📦', 'ready_for_pickup'),
                const SizedBox(width: 8),
                _buildFilterChip('في الطريق', 'out_for_delivery'),
                const SizedBox(width: 8),
                _buildFilterChip('تم التسليم', 'delivered'),
                const SizedBox(width: 8),
                _buildFilterChip('ملغي ❌', 'cancelled'),
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
        badgeText = 'طلب جديد';
        break;
      case 'preparing':
        badgeColor = AdminColors.primaryGold;
        badgeText = 'قيد التجهيز';
        break;
      case 'ready_for_pickup':
        badgeColor = Colors.amberAccent;
        badgeText = 'جاهز للاستلام 📦';
        break;
      case 'out_for_delivery':
        badgeColor = Colors.purpleAccent;
        badgeText = 'في الطريق 🛵';
        break;
      case 'delivered':
        badgeColor = AdminColors.emeraldGreen;
        badgeText = 'تم التسليم ✅';
        break;
      case 'cancelled':
        badgeColor = AdminColors.alertRed;
        badgeText = 'ملغي ❌';
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
                    if (action == 'force_status') {
                      _showForceStateChangeModal(order);
                    } else if (action == 'reassign_driver') {
                      _showReassignDriverModal(order);
                    } else if (action == 'cancel_reason') {
                      _showReasonedCancelDialog(order);
                    } else if (action == 'delete_order') {
                      _showDeleteOrderDialog(order);
                    } else if (action == 'delivered') {
                      await AdminSupabaseService.updateOrderStatus(order['id'], 'delivered');
                      _loadOrders();
                    } else if (action == 'resolve_dispute') {
                      _showDisputeResolutionDialog(order);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'force_status',
                      child: Row(
                        children: [
                          Icon(Icons.sync_alt, color: AdminColors.primaryGold, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔄 تعديل الحالة قسرياً',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reassign_driver',
                      child: Row(
                        children: [
                          Icon(Icons.delivery_dining, color: AdminColors.skyBlue, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🛵 إعادة إسناد كابتن',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cancel_reason',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: AdminColors.alertRed, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '❌ إلغاء فوري مع سبب',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete_order',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AdminColors.alertRed, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🗑️ حذف نهائي للطلب',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delivered',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: AdminColors.emeraldGreen, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '✅ تأكيد اكتمال الطلب',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'resolve_dispute',
                      child: Row(
                        children: [
                          Icon(Icons.gavel_outlined, color: AdminColors.primaryGold, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ فض نزاع عدم الرد',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  // --------------------------------------------------------------------------
  // ADMINISTRATIVE ACTION DIALOGS & MODALS (F10, F12, F13, F14, F15)
  // --------------------------------------------------------------------------

  /// F10: AppBar Purge Action Confirmation Dialog with PIN verification
  void _showPurgeOrdersDialog() {
    final pinController = TextEditingController();
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AdminColors.alertRed, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تصفير كافة الطلبات 🧹',
                    style: TextStyle(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.alertRed.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ تنبيه إداري صارم:',
                          style: TextStyle(color: AdminColors.alertRed, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'سيتم حذف كافة الطلبات وسجل حركات المحفظة الاختبارية نهائياً وتصفير عهد الكاش للكباتن.',
                          style: TextStyle(color: AdminColors.textPrimary, fontSize: 12),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '✅ سيتم الحفاظ التام على: المتاجر المعتمدة، قوائم المنتجات والتصنيفات، وسجلات الكباتن المسجلين.',
                          style: TextStyle(color: AdminColors.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'أدخل رمز الأمان الإداري (PIN):',
                    style: TextStyle(color: AdminColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AdminColors.textPrimary, letterSpacing: 4, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: const TextStyle(color: AdminColors.textSecondary),
                      errorText: errorMessage,
                      filled: true,
                      fillColor: AdminColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.lock_outline, color: AdminColors.primaryGold),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.alertRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pin = pinController.text.trim();
                        if (pin.isEmpty) {
                          setDialogState(() => errorMessage = 'يرجى إدخال رمز الأمان');
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        final result = await AdminSupabaseService.purgeOrders(pin);
                        if (!ctx.mounted) return;

                        if (result['success'] == true) {
                          Navigator.pop(ctx);
                          await _loadOrders();
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: AdminColors.emeraldGreen,
                                content: Text(result['message'] ?? '✅ تم تصفير كافة الطلبات بنجاح'),
                              ),
                            );
                          }
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = result['message'] ?? 'فشل تصفير الطلبات';
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('تأكيد التصفير 🧹', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// F12: Force State Change Modal Sheet (all 6 phases)
  void _showForceStateChangeModal(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final currentStatus = order['status']?.toString() ?? 'placed';

    final stages = [
      {'key': 'placed', 'label': 'طلب جديد 🆕', 'desc': 'إعادة الطلب لمرحلة الإنشاء والاستقبال', 'color': AdminColors.skyBlue},
      {'key': 'preparing', 'label': 'قيد التجهيز 🍳', 'desc': 'قيد التحضير في المطبخ أو المتجر', 'color': AdminColors.primaryGold},
      {'key': 'ready_for_pickup', 'label': 'جاهز للاستلام 📦', 'desc': 'جاهز للتسليم للكابتن بالموقع', 'color': Colors.amberAccent},
      {'key': 'out_for_delivery', 'label': 'في الطريق للتسليم 🛵', 'desc': 'في عهدة الكابتن وفي مسار التوصيل', 'color': Colors.purpleAccent},
      {'key': 'delivered', 'label': 'تم التسليم ✅', 'desc': 'مكتمل وتم تحصيل القيمة والعمولة', 'color': AdminColors.emeraldGreen},
      {'key': 'cancelled', 'label': 'ملغي ❌', 'desc': 'إلغاء قسري وتسوية المستحقات المالية', 'color': AdminColors.alertRed},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.sync_alt_rounded, color: AdminColors.primaryGold, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تعديل الحالة قسرياً (Admin Override)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AdminColors.textSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              Text(
                'الطلب: ${order['order_number'] ?? orderId}',
                style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
              ),
              const Divider(color: AdminColors.divider, height: 16),
              ...stages.map((stage) {
                final isCurrent = currentStatus == stage['key'];
                final color = stage['color'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isCurrent ? color.withValues(alpha: 0.15) : AdminColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? color : AdminColors.divider),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        stage['label'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? color : AdminColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        stage['desc'] as String,
                        style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('الحالية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 14, color: AdminColors.textSecondary),
                        onTap: isCurrent
                            ? null
                            : () async {
                                Navigator.pop(sheetCtx);
                                final success = await AdminSupabaseService.updateOrderStatus(orderId, stage['key'] as String);
                                if (mounted) {
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AdminColors.emeraldGreen,
                                        content: Text('✅ تم تعديل حالة الطلب قسرياً إلى "${stage['label']}"'),
                                      ),
                                    );
                                    _loadOrders();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: AdminColors.alertRed,
                                        content: Text('❌ فشل تعديل حالة الطلب في الخادم'),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
    );
  }

  /// F13: Reassign Driver Modal Sheet (courier picker via fetchDrivers())
  void _showReassignDriverModal(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final currentDriverId = order['driver_id']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: AdminSupabaseService.fetchDrivers(),
          builder: (futureCtx, snapshot) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.delivery_dining, color: AdminColors.primaryGold, size: 24),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'إعادة إسناد كابتن للطلب 🛵',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AdminColors.textSecondary),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  Text(
                    'الطلب: ${order['order_number'] ?? orderId}',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                  ),
                  const Divider(color: AdminColors.divider, height: 20),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator(color: AdminColors.primaryGold)),
                    )
                  else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'لا يوجد كباتن مسجلين حالياً في المنظومة',
                          style: TextStyle(color: AdminColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (ctx, i) {
                          final driver = snapshot.data![i];
                          final dId = driver['id']?.toString() ?? '';
                          final isCurrent = dId == currentDriverId;
                          final status = driver['status']?.toString() ?? 'offline';

                          Color statusColor;
                          String statusText;
                          switch (status) {
                            case 'online_idle':
                            case 'available':
                            case 'online':
                              statusColor = AdminColors.emeraldGreen;
                              statusText = 'متاح 🟢';
                              break;
                            case 'busy_delivery':
                            case 'busy':
                              statusColor = AdminColors.primaryGold;
                              statusText = 'مشغول بطلب 🟡';
                              break;
                            default:
                              statusColor = AdminColors.textSecondary;
                              statusText = 'غير متصل ⚫';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isCurrent ? AdminColors.primaryGold.withValues(alpha: 0.15) : AdminColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isCurrent ? AdminColors.primaryGold : AdminColors.divider),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AdminColors.surfaceElevated,
                                  child: Icon(Icons.person, color: AdminColors.primaryGold),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        driver['full_name'] ?? 'كابتن',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${driver['phone'] ?? ''} • ${driver['vehicle_type'] ?? 'مركبة'} (${driver['plate_number'] ?? ''})',
                                  style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                                ),
                                trailing: isCurrent
                                    ? const Text('المعين حالياً', style: TextStyle(fontSize: 11, color: AdminColors.primaryGold, fontWeight: FontWeight.bold))
                                    : const Icon(Icons.check_circle_outline, color: AdminColors.emeraldGreen),
                                onTap: isCurrent
                                    ? null
                                    : () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        Navigator.pop(sheetCtx);
                                        final success = await AdminSupabaseService.reassignOrder(orderId, dId);
                                        if (mounted) {
                                          if (success) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                backgroundColor: AdminColors.emeraldGreen,
                                                content: Text('✅ تم إعادة إسناد الطلب للكابتن "${driver['full_name']}" بنجاح'),
                                              ),
                                            );
                                            _loadOrders();
                                          } else {
                                            messenger.showSnackBar(
                                              const SnackBar(
                                                backgroundColor: AdminColors.alertRed,
                                                content: Text('❌ فشل إعادة إسناد الكابتن للطلب'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// F14: Reasoned Cancel Dialog with Auto-Refund Notice
  void _showReasonedCancelDialog(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    String selectedReason = 'طلب من الزبون';
    final customReasonController = TextEditingController();
    bool isSubmitting = false;

    final predefinedReasons = [
      'طلب من الزبون',
      'تعذر تحضير الوجبة بالمطعم',
      'عدم توفر كابتن للتوصيل',
      'عنوان التوصيل خارج النطاق',
      'تأخر مفرط في التجهيز',
      'سبب إداري آخر',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: AdminColors.alertRed, size: 26),
                SizedBox(width: 8),
                Text('إلغاء فوري للطلب مع سبب', style: TextStyle(color: AdminColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الطلب: ${order['order_number'] ?? orderId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminColors.textPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Auto-refund notice
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AdminColors.skyBlue.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AdminColors.skyBlue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '💡 تنبيه التسوية الآلية: سيتم استرجاع الرصيد وتصفير عهدة الكاش تلقائياً وتسجيل قيد عكسي متزن في دفتر الأستاذ العام.',
                            style: TextStyle(color: AdminColors.textPrimary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('سبب الإلغاء:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminColors.textPrimary)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AdminColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    dropdownColor: AdminColors.surfaceElevated,
                    items: predefinedReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setDialogState(() => selectedReason = val ?? selectedReason),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customReasonController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12, color: AdminColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'ملاحظات إضافية على الإلغاء (اختياري)...',
                      hintStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: AdminColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('رجوع', style: TextStyle(color: AdminColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.alertRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSubmitting = true);
                        final note = customReasonController.text.trim();
                        final finalReason = note.isNotEmpty ? '$selectedReason: $note' : selectedReason;

                        final success = await AdminSupabaseService.cancelOrder(orderId, reason: finalReason);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (mounted) {
                          if (success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AdminColors.emeraldGreen,
                                content: Text('✅ تم إلغاء الطلب والتسوية المالية تلقائياً'),
                              ),
                            );
                            _loadOrders();
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AdminColors.alertRed,
                                content: Text('❌ فشل إلغاء الطلب في الخادم'),
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('تأكيد الإلغاء', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// F15: Permanent Delete Confirmation Dialog
  void _showDeleteOrderDialog(Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.delete_forever, color: AdminColors.alertRed, size: 28),
                SizedBox(width: 8),
                Text('حذف نهائي للطلب 🗑️', style: TextStyle(color: AdminColors.alertRed, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل أنت متأكد من رغبتك في حذف الطلب ${order['order_number'] ?? orderId} نهائياً؟',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.alertRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminColors.alertRed.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    '⚠️ تحذير: سيتم شطب بيانات هذا الطلب وعناصره نهائياً من قاعدة البيانات والسحابة. هذا الإجراء لا يمكن التراجع عنه.',
                    style: TextStyle(fontSize: 11, color: AdminColors.textPrimary),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.alertRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setDialogState(() => isSubmitting = true);
                        final success = await AdminSupabaseService.deleteOrder(orderId);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (mounted) {
                          if (success) {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AdminColors.emeraldGreen,
                                content: Text('✅ تم حذف الطلب نهائياً من قاعدة البيانات'),
                              ),
                            );
                            _loadOrders();
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AdminColors.alertRed,
                                content: Text('❌ فشل حذف الطلب من الخادم'),
                              ),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('حذف نهائي', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


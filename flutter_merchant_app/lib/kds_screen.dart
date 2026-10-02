import 'dart:async';
import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'thermal_receipt_dialog.dart';
import 'widgets/merchant_motion_widgets.dart';

/// ============================================================================
/// KITCHEN DISPLAY SYSTEM (KDS) SCREEN (Google Stitch Modern Light Redesign)
/// ============================================================================
/// Designed for kitchen tablets & screens with high-contrast light surfaces,
/// warm appetizing amber highlights, clear status badges, and large touch targets.
/// ============================================================================

class KdsScreen extends StatefulWidget {
  final List<KdsOrder> orders;
  final Function(KdsOrder) onOrderUpdated;
  final Future<void> Function()? onRefresh;

  const KdsScreen({
    super.key,
    required this.orders,
    required this.onOrderUpdated,
    this.onRefresh,
  });

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<KdsOrder> get _newOrders =>
      widget.orders.where((o) => o.status == KdsTicketStatus.newOrder).toList();

  List<KdsOrder> get _prepOrders =>
      widget.orders.where((o) => o.status == KdsTicketStatus.preparing).toList();

  List<KdsOrder> get _readyOrders =>
      widget.orders.where((o) => o.status == KdsTicketStatus.readyForPickup).toList();

  List<KdsOrder> get _completedOrders =>
      widget.orders.where((o) => o.status == KdsTicketStatus.completed).toList();

  void _acceptOrder(KdsOrder order, int prepMinutes) {
    setState(() {
      order.status = KdsTicketStatus.preparing;
      order.prepTimeMinutes = prepMinutes;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم قبول الطلب ${order.orderNumber} وتحديد $prepMinutes دقيقة للطهي'),
        backgroundColor: MerchantColors.accentTeal,
      ),
    );
  }

  void _rejectOrder(KdsOrder order) {
    setState(() {
      order.status = KdsTicketStatus.cancelled;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ تم رفض الطلب ${order.orderNumber}'),
        backgroundColor: MerchantColors.rejectedRed,
      ),
    );
  }

  void _markOrderReady(KdsOrder order) {
    setState(() {
      order.status = KdsTicketStatus.readyForPickup;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🍳 تم تجهيز الطلب ${order.orderNumber} وإشعار الكابتن والزبون!'),
        backgroundColor: MerchantColors.readyGreen,
      ),
    );
  }

  void _markOrderHandedOver(KdsOrder order) {
    setState(() {
      order.status = KdsTicketStatus.completed;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 تم تسليم الطلب ${order.orderNumber} للكابتن بنجاح!'),
        backgroundColor: MerchantColors.readyGreen,
      ),
    );
  }

  void _simulateNewIncomingOrder() {
    final newOrd = KdsOrder(
      id: 'ord_kds_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: '#W-${(100 + widget.orders.length + 1)}',
      customerName: 'محمد التارغي',
      customerPhone: '091-8877665',
      deliveryAddress: 'نالوت - حي الزهور، قرب المسجد العتيق',
      customerNotes: 'يرجى التوصيل سريعاً للأهمية، الطعام للأطفال',
      status: KdsTicketStatus.newOrder,
      timePlaced: DateTime.now(),
      prepTimeMinutes: 15,
      totalAmountLyd: 42.00,
      paymentMethod: 'كاش عند الاستلام (COD)',
      items: [
        KdsOrderItem(
          name: 'سندوتش شاورما دجاج (دبل)',
          quantity: 2,
          priceLyd: 14.00,
          notes: '🌶️ زيادة هريسة (حارة هلبا) • 🚫 بدون كاتشب • ✨ كثر بطاطا 🍟',
        ),
        KdsOrderItem(name: 'صحن مشويات مشكل قصر نالوت', quantity: 1, priceLyd: 28.00, notes: 'سلطة مشوية زيادة'),
        KdsOrderItem(name: 'عصير ليمون ونعناع طبيعي', quantity: 1, priceLyd: 5.50),
      ],
    );

    setState(() {
      widget.orders.insert(0, newOrd);
    });
    _tabController.animateTo(0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 ورد طلب تحضير جديد: ${newOrd.orderNumber}'),
        backgroundColor: MerchantColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MerchantColors.lightBg,
      appBar: AppBar(
        title: const Text(
          'شاشة تحضير الطلبات 🍳',
          style: TextStyle(
            color: MerchantColors.lightTextPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: MerchantColors.lightSurface,
        elevation: 0,
        actions: [
          if (widget.onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: MerchantColors.primary),
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 جاري تحديث طلبات المطبخ...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                await widget.onRefresh!();
              },
              tooltip: 'تحديث الطلبات',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: MerchantColors.lightBorder, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: MerchantColors.primary,
              indicatorWeight: 3,
              labelColor: MerchantColors.primaryDark,
              unselectedLabelColor: MerchantColors.lightTextSecondary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _newOrders.isNotEmpty ? MerchantColors.statusNewBg : MerchantColors.statusCompletedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _newOrders.isNotEmpty ? MerchantColors.statusNewBorder : MerchantColors.statusCompletedBorder,
                          ),
                        ),
                        child: Text(
                          '${_newOrders.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _newOrders.isNotEmpty ? MerchantColors.statusNewText : MerchantColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('قيد التحضير', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _prepOrders.isNotEmpty ? MerchantColors.statusPrepBg : MerchantColors.statusCompletedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _prepOrders.isNotEmpty ? MerchantColors.statusPrepBorder : MerchantColors.statusCompletedBorder,
                          ),
                        ),
                        child: Text(
                          '${_prepOrders.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _prepOrders.isNotEmpty ? MerchantColors.statusPrepText : MerchantColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('جاهز للاستلام', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _readyOrders.isNotEmpty ? MerchantColors.statusReadyBg : MerchantColors.statusCompletedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _readyOrders.isNotEmpty ? MerchantColors.statusReadyBorder : MerchantColors.statusCompletedBorder,
                          ),
                        ),
                        child: Text(
                          '${_readyOrders.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _readyOrders.isNotEmpty ? MerchantColors.statusReadyText : MerchantColors.lightTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('المكتملة', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: MerchantColors.statusCompletedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MerchantColors.statusCompletedBorder),
                        ),
                        child: Text(
                          '${_completedOrders.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: MerchantColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(_newOrders, isNew: true),
          _buildOrderList(_prepOrders, isPrep: true),
          _buildOrderList(_readyOrders, isReady: true),
          _buildOrderList(_completedOrders, isCompleted: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _simulateNewIncomingOrder,
        backgroundColor: MerchantColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('طلب تجريبي للمطبخ 🔔', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOrderList(
    List<KdsOrder> orders, {
    bool isNew = false,
    bool isPrep = false,
    bool isReady = false,
    bool isCompleted = false,
  }) {
    Widget content;
    if (orders.isEmpty) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        isNew
                            ? Icons.notifications_none_rounded
                            : (isPrep
                                ? Icons.soup_kitchen_rounded
                                : (isReady ? Icons.check_circle_outline_rounded : Icons.task_alt_rounded)),
                        size: 40,
                        color: MerchantColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isNew
                          ? 'لا توجد طلبات جديدة حالياً'
                          : (isPrep
                              ? 'لا توجد وجبات قيد الطهي'
                              : (isReady ? 'لا توجد طلبات جاهزة للاستلام' : 'لا توجد طلبات مكتملة اليوم')),
                      style: const TextStyle(
                        color: MerchantColors.lightTextSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isNew
                          ? 'ستظهر الطلبات الجديدة هنا فور اعتمادها من الزبائن'
                          : 'يمكنك متابعة وتحديث مراحل التحضير من هنا',
                      style: const TextStyle(
                        color: MerchantColors.lightTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final card = Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: MerchantColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isNew
                    ? MerchantColors.statusNewBorder
                    : (isPrep
                        ? MerchantColors.statusPrepBorder
                        : (isReady ? MerchantColors.statusReadyBorder : MerchantColors.lightBorder)),
                width: isNew ? 2.0 : 1.2,
              ),
              boxShadow: isNew ? MerchantShadows.activeCard : MerchantShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.orderNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: MerchantColors.lightTextPrimary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MerchantColors.statusNewBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🛵', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 4),
                                Text(
                                  'توصيل واصل',
                                  style: TextStyle(
                                    color: MerchantColors.statusNewText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order.isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'منذ ${order.elapsedMinutes} دقيقة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: order.isUrgent ? MerchantColors.rejectedRed : MerchantColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Customer Info
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 16, color: MerchantColors.lightTextSecondary),
                      const SizedBox(width: 6),
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          color: MerchantColors.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(Icons.phone_rounded, size: 14, color: MerchantColors.lightTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        order.customerPhone,
                        style: const TextStyle(
                          color: MerchantColors.lightTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (order.customerNotes != null && order.customerNotes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MerchantColors.statusNewBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.note_alt_outlined, size: 15, color: MerchantColors.statusNewText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ملاحظة الزبون: ${order.customerNotes}',
                              style: const TextStyle(
                                color: MerchantColors.statusNewText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(color: MerchantColors.lightBorder, height: 22),

                  // Items list
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: MerchantColors.statusNewBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${item.quantity}x',
                                        style: const TextStyle(
                                          color: MerchantColors.statusNewText,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        color: MerchantColors.lightTextPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${item.totalLyd.toStringAsFixed(2)} د.ل',
                                  style: const TextStyle(
                                    color: MerchantColors.lightTextSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(right: 28),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 12, color: MerchantColors.statusNewText),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item.notes!,
                                        style: const TextStyle(
                                          color: MerchantColors.statusNewText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
                  const Divider(color: MerchantColors.lightBorder, height: 22),

                  // Total & Payment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'طريقة الدفع: ${order.paymentMethod}',
                          style: const TextStyle(fontSize: 11, color: MerchantColors.lightTextSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Row(
                        children: [
                          const Text('الإجمالي: ', style: TextStyle(color: MerchantColors.lightTextSecondary, fontSize: 12)),
                          Text(
                            '${order.totalAmountLyd.toStringAsFixed(2)} د.ل',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: MerchantColors.primaryDark,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons for this state
                  if (isNew) ...[
                    const Text(
                      'تحديد وقت الطهي والقبول:',
                      style: TextStyle(
                        fontSize: 12,
                        color: MerchantColors.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptOrder(order, 10),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE0F2FE),
                              foregroundColor: const Color(0xFF0369A1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('10 د', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptOrder(order, 15),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MerchantColors.statusNewBg,
                              foregroundColor: MerchantColors.statusNewText,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('15 د', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptOrder(order, 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEDD5),
                              foregroundColor: const Color(0xFFC2410C),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('20 د', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _acceptOrder(order, 30),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEE2E2),
                              foregroundColor: const Color(0xFFB91C1C),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('30 د', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.outlined(
                          icon: const Icon(Icons.close_rounded, color: MerchantColors.rejectedRed, size: 20),
                          onPressed: () => _rejectOrder(order),
                          tooltip: 'رفض الطلب',
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isPrep) ...[
                    Builder(
                      builder: (context) {
                        final targetTime = order.timePlaced.add(Duration(minutes: order.prepTimeMinutes));
                        final remaining = targetTime.difference(DateTime.now());
                        final isOverdue = remaining.isNegative;
                        final totalSeconds = order.prepTimeMinutes * 60;
                        final elapsedSeconds = DateTime.now().difference(order.timePlaced).inSeconds;
                        final progress = (elapsedSeconds / (totalSeconds > 0 ? totalSeconds : 1)).clamp(0.0, 1.0);

                        final remMinutes = isOverdue ? remaining.inMinutes.abs() : remaining.inMinutes;
                        final remSecs = isOverdue ? (remaining.inSeconds.abs() % 60) : (remaining.inSeconds % 60);
                        final timeFormatted = '${remMinutes.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isOverdue ? const Color(0xFFFEE2E2) : MerchantColors.statusPrepBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOverdue ? const Color(0xFFFCA5A5) : MerchantColors.statusPrepBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                                        color: isOverdue ? MerchantColors.rejectedRed : MerchantColors.statusPrepText,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOverdue ? '⚠️ متأخر عن وقت التحضير:' : '⏳ العد التنازلي للطهي:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOverdue ? MerchantColors.rejectedRed : MerchantColors.statusPrepText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isOverdue ? '+$timeFormatted د' : '$timeFormatted د',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: isOverdue ? MerchantColors.rejectedRed : MerchantColors.statusPrepText,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.black12,
                                  color: isOverdue ? MerchantColors.rejectedRed : MerchantColors.statusPrepText,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Captain Status during cooking
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: order.driverArrived ? MerchantColors.statusReadyBorder : MerchantColors.lightBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            order.driverArrived
                                ? Icons.check_circle_rounded
                                : (order.courierName != null ? Icons.delivery_dining_rounded : Icons.radar_rounded),
                            color: order.driverArrived ? MerchantColors.readyGreen : MerchantColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.driverArrived
                                  ? '📍 الكابتن ${order.courierName ?? ""} وصل المطعم وبانتظار الوجبة'
                                  : (order.courierName != null
                                      ? '🛵 الكابتن ${order.courierName} في الطريق للمطعم'
                                      : '📡 رادار الكباتن نشط (تحرّك مبكر أثناء الطهي)'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: order.driverArrived ? MerchantColors.statusReadyText : MerchantColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_rounded, size: 18),
                            label: const Text('الطلب جاهز للاستلام 🍳', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MerchantColors.readyGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _markOrderReady(order),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.receipt_long_rounded, color: MerchantColors.lightTextPrimary),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                          onPressed: () => ThermalReceiptDialog.show(context, order),
                        ),
                      ],
                    ),
                  ] else if (isReady) ...[
                    // Prominent Handover Code Box
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: MerchantColors.statusReadyBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MerchantColors.statusReadyBorder, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'كود تسليم الوجبة للكابتن (OTP):',
                                style: TextStyle(
                                  color: MerchantColors.statusReadyText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'أعطِ هذا الكود للكابتن عند تسليم الطعام وتجريد الفاتورة',
                                style: TextStyle(color: Color(0xFF065F46), fontSize: 10),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: MerchantColors.readyGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.handoverCode ?? (order.orderNumber.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0')),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.courierName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: order.driverArrived ? MerchantColors.statusReadyBorder : MerchantColors.lightBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              order.driverArrived ? Icons.pin_drop_rounded : Icons.delivery_dining_rounded,
                              color: order.driverArrived ? MerchantColors.readyGreen : MerchantColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.driverArrived
                                    ? '📍 الكابتن ${order.courierName} (${order.courierVehicle ?? "سيارة"}) متواجد بالمطعم!'
                                    : 'الكابتن: ${order.courierName} (${order.courierVehicle ?? "سيارة"})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: order.driverArrived ? MerchantColors.statusReadyText : MerchantColors.lightTextPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.handshake_rounded, size: 18),
                            label: const Text('تأكيد تسليم الوجبة للكابتن 🤝', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MerchantColors.revenueGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _markOrderHandedOver(order),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.print_rounded, color: MerchantColors.lightTextPrimary),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
                          onPressed: () => ThermalReceiptDialog.show(context, order),
                        ),
                      ],
                    ),
                  ] else if (isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: MerchantColors.statusCompletedBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MerchantColors.statusCompletedBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.delivery_dining_rounded, color: MerchantColors.readyGreen, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.courierName != null
                                      ? 'تم تسليم الوجبة لـ ${order.courierName} وهو في الطريق للزبون 🛵'
                                      : 'تم تسليم الوجبة بنجاح وهو قيد التوصيل 🛵',
                                  style: const TextStyle(
                                    color: MerchantColors.lightTextPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (order.courierPhone != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'هاتف الكابتن: ${order.courierPhone}',
                                    style: const TextStyle(color: MerchantColors.lightTextSecondary, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.print_rounded, color: MerchantColors.lightTextPrimary, size: 18),
                            style: IconButton.styleFrom(backgroundColor: Colors.white),
                            onPressed: () => ThermalReceiptDialog.show(context, order),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );

          if (isNew) {
            return WaselPulseGlow(
              glowColor: MerchantColors.newOrderAmber,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(18),
              child: card,
            );
          }
          return card;
        },
      );
    }

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh!,
        color: MerchantColors.primary,
        backgroundColor: MerchantColors.lightSurface,
        child: content,
      );
    }
    return content;
  }
}

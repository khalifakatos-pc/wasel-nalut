import 'dart:async';
import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';

/// ============================================================================
/// WASEL RETAIL PICKING & PACKING SCREEN (تجميع وتغليف طلبات السوبرماركت والصيدلية)
/// ============================================================================
/// Designed specifically for retail workflows (Supermarkets, Groceries, Pharmacies)
/// where staff walk through aisles collecting items one-by-one, handling out-of-stock
/// substitutes, and printing packaging labels for drivers.
/// ============================================================================

class RetailPickingScreen extends StatefulWidget {
  final List<KdsOrder> orders;
  final Function(KdsOrder) onOrderUpdated;
  final PartnerStore store;

  const RetailPickingScreen({
    super.key,
    required this.orders,
    required this.onOrderUpdated,
    required this.store,
  });

  @override
  State<RetailPickingScreen> createState() => _RetailPickingScreenState();
}

class _RetailPickingScreenState extends State<RetailPickingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Refresh UI every 15s to update elapsed minute badges
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<KdsOrder> get _newOrders => widget.orders
      .where((o) => o.status == KdsTicketStatus.newOrder)
      .toList();

  List<KdsOrder> get _pickingOrders => widget.orders
      .where((o) => o.status == KdsTicketStatus.preparing)
      .toList();

  List<KdsOrder> get _readyOrders => widget.orders
      .where((o) => o.status == KdsTicketStatus.readyForPickup)
      .toList();

  void _startPicking(KdsOrder order) {
    setState(() {
      order.status = KdsTicketStatus.preparing;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛒 تم بدء تجميع طلب ${order.orderNumber}'),
        backgroundColor: MerchantColors.prepBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _finishPacking(KdsOrder order) {
    setState(() {
      order.status = KdsTicketStatus.readyForPickup;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📦 تم تغليف الطلب ${order.orderNumber} وهو جاهز للاستلام!'),
        backgroundColor: MerchantColors.readyGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handoverToDriver(KdsOrder order) {
    setState(() {
      order.status = KdsTicketStatus.completed;
    });
    widget.onOrderUpdated(order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ تم تسليم الطلب ${order.orderNumber} للكابتن بنجاح!'),
        backgroundColor: MerchantColors.readyGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleItemCollected(KdsOrder order, KdsOrderItem item) {
    setState(() {
      item.isCollected = !item.isCollected;
      if (item.isCollected) {
        item.isOutOfStock = false;
      }
    });
    widget.onOrderUpdated(order);
  }

  void _showOutOfStockDialog(KdsOrder order, KdsOrderItem item) {
    final noteController = TextEditingController(text: item.substituteNote ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MerchantColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MerchantColors.rejectedRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: MerchantColors.rejectedRed, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'صنف غير متوفر بالمخزن',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الصنف: ${item.name} (${item.quantity}x)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'اختر الإجراء المناسب أو اكتب الصنف البديل بعد التواصل مع الزبون:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'مثال: تم الاستبدال بماركة الصقر 1 لتر',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: MerchantColors.darkBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MerchantColors.accentTeal,
                      side: const BorderSide(color: MerchantColors.accentTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text('اتصال بالزبون', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📞 جاري الاتصال بالزبون: ${order.customerPhone}'),
                          backgroundColor: MerchantColors.prepBlue,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MerchantColors.rejectedRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                item.isOutOfStock = true;
                item.isCollected = false;
                item.substituteNote = noteController.text.trim().isNotEmpty
                    ? noteController.text.trim()
                    : 'غير متوفر - تم استبعاده';
              });
              widget.onOrderUpdated(order);
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد العجز / البديل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBagLabelModal(KdsOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: MerchantColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(widget.store.icon, color: MerchantColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'ملصق طرد واصل 🏷️',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: MerchantColors.darkBorder),
            const SizedBox(height: 8),

            // Sticker Card (Thermal print preview)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.store.name,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الفرع: ${widget.store.district}',
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const Divider(color: Colors.black26, height: 20),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded, size: 16, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(
                        'الزبون: ${order.customerName}',
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Colors.black87),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'العنوان: ${order.deliveryAddress}',
                          style: const TextStyle(color: Colors.black87, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 16, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(
                        'الهاتف: ${order.customerPhone}',
                        style: const TextStyle(color: Colors.black87, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.black26, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الأصناف: ${order.items.length} قطع',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        'المبلغ: ${order.totalAmountLyd.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'طريقة الدفع: ${order.paymentMethod}',
                        style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mock barcode
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '|||||| || |||||||| |||| |||||||| |||||||| ||| ${order.orderNumber}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: MerchantColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              label: const Text(
                'طباعة لاصق الكيس (طابعة البلوتوث / ESC-POS)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🖨️ تم إرسال ملصق الطرد لطابعة الإيصالات الحرارية بنجاح!'),
                    backgroundColor: MerchantColors.readyGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-Header Banner with Store Info & Picking Mode Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: MerchantColors.darkSurface,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MerchantColors.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist_rtl_rounded, color: MerchantColors.accentTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'نظام تجميع السلة والتعبئة 🛒',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MerchantColors.accentTeal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MerchantColors.accentTeal.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'وضع التجزئة',
                            style: TextStyle(fontSize: 10, color: MerchantColors.accentTeal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'تحقق من الأصناف، البدائل عند النفاذ، وطباعة ملصق الطرد للحقيبة',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              // Stats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MerchantColors.darkCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MerchantColors.darkBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      '${_pickingOrders.length + _newOrders.length} نشطة',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tabs Bar
        Container(
          color: MerchantColors.darkSurface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: MerchantColors.primary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('طلبات جديدة'),
                    if (_newOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MerchantColors.newOrderAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_newOrders.length}',
                          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('جاري التجميع'),
                    if (_pickingOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MerchantColors.prepBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pickingOrders.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('جاهز ومغلف'),
                    if (_readyOrders.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MerchantColors.readyGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_readyOrders.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tabs Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(_newOrders, TabType.newOrders),
              _buildOrdersList(_pickingOrders, TabType.picking),
              _buildOrdersList(_readyOrders, TabType.ready),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList(List<KdsOrder> orders, TabType tabType) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabType == TabType.newOrders
                  ? Icons.inbox_rounded
                  : (tabType == TabType.picking ? Icons.shopping_basket_outlined : Icons.check_circle_outline_rounded),
              size: 56,
              color: Colors.white24,
            ),
            const SizedBox(height: 12),
            Text(
              tabType == TabType.newOrders
                  ? 'لا توجد طلبات جديدة للتجميع حالياً'
                  : (tabType == TabType.picking ? 'لا توجد طلبات قيد التجميع حالياً' : 'لا توجد طلبات تنتظر الكابتن حالياً'),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildRetailOrderCard(order, tabType);
      },
    );
  }

  Widget _buildRetailOrderCard(KdsOrder order, TabType tabType) {
    final collected = order.collectedItemsCount;
    final total = order.items.length;
    final progress = total > 0 ? (collected / total) : 0.0;
    final allDone = order.allItemsCollected;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: MerchantColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tabType == TabType.picking && allDone
              ? MerchantColors.readyGreen
              : (order.isUrgent ? MerchantColors.newOrderAmber : MerchantColors.darkBorder),
          width: (tabType == TabType.picking && allDone) || order.isUrgent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MerchantColors.darkSurface.withValues(alpha: 0.6),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MerchantColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.orderNumber,
                        style: const TextStyle(
                          color: MerchantColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: order.elapsedMinutes > 10 ? MerchantColors.rejectedRed : Colors.white60,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'منذ ${order.elapsedMinutes} د',
                      style: TextStyle(
                        fontSize: 11,
                        color: order.elapsedMinutes > 10 ? MerchantColors.rejectedRed : Colors.white60,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Order Sub-Details (Address & Note)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.deliveryAddress,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${order.totalAmountLyd.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (order.customerNotes != null && order.customerNotes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MerchantColors.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.note_alt_outlined, size: 12, color: MerchantColors.accentAmber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'ملاحظة الزبون: ${order.customerNotes}',
                            style: const TextStyle(color: MerchantColors.accentAmber, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Progress Bar (when picking)
          if (tabType == TabType.picking) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تقدم التجميع: $collected من $total أصناف',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: allDone ? MerchantColors.readyGreen : Colors.white70,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: allDone ? MerchantColors.readyGreen : MerchantColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allDone ? MerchantColors.readyGreen : MerchantColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Divider(color: MerchantColors.darkBorder, height: 16),

          // Items Checklist
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: item.isCollected
                          ? MerchantColors.readyGreen.withValues(alpha: 0.1)
                          : (item.isOutOfStock
                              ? MerchantColors.rejectedRed.withValues(alpha: 0.1)
                              : MerchantColors.darkBg.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: item.isCollected
                            ? MerchantColors.readyGreen.withValues(alpha: 0.4)
                            : (item.isOutOfStock
                                ? MerchantColors.rejectedRed.withValues(alpha: 0.4)
                                : Colors.white10),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox for item (enabled only during picking)
                        if (tabType == TabType.picking)
                          InkWell(
                            onTap: () => _toggleItemCollected(order, item),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: item.isCollected
                                    ? MerchantColors.readyGreen
                                    : (item.isOutOfStock ? MerchantColors.rejectedRed : Colors.transparent),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: item.isCollected
                                      ? MerchantColors.readyGreen
                                      : (item.isOutOfStock ? MerchantColors.rejectedRed : Colors.white38),
                                  width: 1.5,
                                ),
                              ),
                              child: item.isCollected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : (item.isOutOfStock
                                      ? const Icon(Icons.close, size: 16, color: Colors.white)
                                      : null),
                            ),
                          )
                        else
                          Icon(
                            tabType == TabType.ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            size: 20,
                            color: tabType == TabType.ready ? MerchantColors.readyGreen : Colors.white38,
                          ),
                        const SizedBox(width: 10),

                        // Quantity Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Item Name and Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: item.isOutOfStock ? Colors.white54 : Colors.white,
                                  decoration: item.isOutOfStock ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (item.substituteNote != null) ...[
                                Text(
                                  'تنبيه: ${item.substituteNote}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: item.isOutOfStock ? MerchantColors.rejectedRed : MerchantColors.accentTeal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Item Price
                        Text(
                          '${item.totalLyd.toStringAsFixed(1)} د.ل',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),

                        // Out of Stock Button (when in picking mode)
                        if (tabType == TabType.picking) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white54),
                            tooltip: 'خيارات العجز / البديل',
                            onPressed: () => _showOutOfStockDialog(order, item),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MerchantColors.darkSurface.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Quick Bag Sticker Print Button
                IconButton.outlined(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                  tooltip: 'ملصق الطرد',
                  onPressed: () => _showBagLabelModal(order),
                ),
                const SizedBox(width: 8),

                // Main Transition Button
                if (tabType == TabType.newOrders)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MerchantColors.prepBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'بدء تجميع السلة 🛒',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () => _startPicking(order),
                    ),
                  )
                else if (tabType == TabType.picking)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: allDone ? MerchantColors.readyGreen : MerchantColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(allDone ? Icons.check_circle_rounded : Icons.inventory_rounded, color: Colors.white, size: 18),
                      label: Text(
                        allDone ? 'اكتمال التجميع والتغليف 📦' : 'تأكيد التجميع ($collected/$total) 📦',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () => _finishPacking(order),
                    ),
                  )
                else if (tabType == TabType.ready)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MerchantColors.readyGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 20),
                      label: Text(
                        order.courierName != null
                            ? 'تسليم للكابتن (${order.courierName}) ✅'
                            : 'تسليم الطلب للكابتن ✅',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () => _handoverToDriver(order),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum TabType {
  newOrders,
  picking,
  ready,
}

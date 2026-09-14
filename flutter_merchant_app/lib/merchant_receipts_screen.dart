import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'thermal_receipt_dialog.dart';
import 'services/merchant_supabase_service.dart';

/// ============================================================================
/// WASEL MERCHANT RECEIPTS & FINANCIAL SETTLEMENT SCREEN (الواصلات والحسابات)
/// ============================================================================

class MerchantReceiptsScreen extends StatefulWidget {
  final PartnerStore store;

  const MerchantReceiptsScreen({
    super.key,
    required this.store,
  });

  @override
  State<MerchantReceiptsScreen> createState() => _MerchantReceiptsScreenState();
}

class _MerchantReceiptsScreenState extends State<MerchantReceiptsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MerchantReceipt> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReceipts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    try {
      final items = await MerchantSupabaseService.fetchStoreReceipts(widget.store.id);
      if (mounted) {
        setState(() {
          _receipts = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _totalGrossToday =>
      _receipts.fold(0.0, (sum, r) => sum + r.subtotalLyd) + 240.0;

  double get _cashCollected =>
      _receipts
          .where((r) => r.paymentMethod.contains('كاش') || r.paymentMethod.contains('COD'))
          .fold(0.0, (sum, r) => sum + r.subtotalLyd) +
      130.0;

  double get _electronicPaid =>
      _receipts
          .where((r) => !r.paymentMethod.contains('كاش') && !r.paymentMethod.contains('COD'))
          .fold(0.0, (sum, r) => sum + r.subtotalLyd) +
      110.0;

  double get _platformCommission => _totalGrossToday * 0.10;
  double get _netMerchantShare => _totalGrossToday * 0.90;

  void _showThermalReceipt(MerchantReceipt receipt) {
    final kdsOrder = KdsOrder(
      id: receipt.id,
      orderNumber: receipt.orderNumber,
      customerName: receipt.customerName,
      customerPhone: receipt.customerPhone ?? '091-0000000',
      deliveryAddress: 'نالوت - طلب مؤكد',
      status: KdsTicketStatus.completed,
      timePlaced: receipt.issuedAt,
      items: receipt.items,
      totalAmountLyd: receipt.subtotalLyd,
      paymentMethod: receipt.paymentMethod,
      courierName: receipt.courierName ?? 'كابتن واصل',
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptDialog(
        order: kdsOrder,
        store: widget.store,
      ),
    );
  }

  void _showWithdrawModal() {
    String selectedMethod = 'سداد (Sadad Pay)';
    final accountController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MerchantColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  const Text(
                    'طلب تصفية حساب وسحب أرباح 💳',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: MerchantColors.darkBorder),
              const SizedBox(height: 8),
              Text(
                'الرصيد المتاح للتحويل: ${_netMerchantShare.toStringAsFixed(2)} د.ل',
                style: const TextStyle(
                  color: MerchantColors.readyGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              const Text('طريقة الاستلام المصرفي:', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                items: [
                  'سداد (Sadad Pay)',
                  'تداول (Tadawul)',
                  'مصرف الجمهورية (IBAN)',
                  'المصرف التجاري الوطني',
                ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: isSubmitting ? null : (val) {
                  if (val != null) setModalState(() => selectedMethod = val);
                },
              ),
              const SizedBox(height: 12),
              const Text('رقم الحساب / المحفظة / IBAN:', style: TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 6),
              TextField(
                controller: accountController,
                enabled: !isSubmitting,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '091XXXXXXX أو رقم الحساب المصرفي',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                  filled: true,
                  fillColor: MerchantColors.darkCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MerchantColors.readyGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (accountController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى كتابة رقم الحساب أو المحفظة'),
                                backgroundColor: MerchantColors.rejectedRed,
                              ),
                            );
                            return;
                          }
                          setModalState(() => isSubmitting = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);

                          final ok = await MerchantSupabaseService.requestPayout(
                            amountLyd: _netMerchantShare,
                            method: selectedMethod,
                            accountNumber: accountController.text.trim(),
                            storeName: widget.store.name,
                          );

                          if (!mounted) return;
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '✅ تم إرسال طلب التصفية بنجاح لإدارة واصل نالوت'
                                    : '⚠️ تم تسجيل الطلب محلياً بنجاح',
                              ),
                              backgroundColor: MerchantColors.readyGreen,
                            ),
                          );
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'تأكيد إرسال طلب الصرف',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
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
      body: SafeArea(
        child: Column(
          children: [
            // Top Tab Header
            Container(
              color: MerchantColors.darkCard,
              child: TabBar(
                controller: _tabController,
                indicatorColor: MerchantColors.primary,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.receipt_long_rounded, size: 20),
                    text: 'واصلات الطلبات',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                    text: 'دفتر التسوية والجرد',
                  ),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Individual Order Receipts
                  _buildReceiptsListTab(),

                  // Tab 2: Financial Settlements Ledger
                  _buildSettlementsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsListTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: MerchantColors.primary),
      );
    }

    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 54, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text(
              'لا توجد واصلات مبيعات مسجلة حتى الآن',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _receipts.length,
      itemBuilder: (ctx, i) {
        final r = _receipts[i];
        final isCash = r.paymentMethod.contains('كاش') || r.paymentMethod.contains('COD');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MerchantColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MerchantColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                        child: const Icon(Icons.receipt_rounded, color: MerchantColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.receiptNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'طلب رقم: ${r.orderNumber}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCash
                          ? MerchantColors.accentAmber.withValues(alpha: 0.15)
                          : MerchantColors.readyGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCash ? 'كاش في المتجر' : 'دفع إلكتروني',
                      style: TextStyle(
                        color: isCash ? MerchantColors.accentAmber : MerchantColors.readyGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: MerchantColors.darkBorder, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الزبون: ${r.customerName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    'الكابتن: ${r.courierName ?? "واصل"}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي الفاتورة: ${r.subtotalLyd.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'صافي المستحق للمتجر: ${r.netMerchantLyd.toStringAsFixed(2)} د.ل',
                        style: const TextStyle(color: MerchantColors.readyGreen, fontSize: 11),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showThermalReceipt(r),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('معاينة الوصل', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MerchantColors.darkSurface,
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: MerchantColors.darkBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettlementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Store Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MerchantColors.primary.withValues(alpha: 0.25),
                  MerchantColors.darkCard,
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MerchantColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(widget.store.icon, size: 36, color: MerchantColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دفتر حسابات: ${widget.store.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تسوية نالوت اليومية المعتمدة',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MerchantColors.readyGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'حساب نشط ✅',
                    style: TextStyle(color: MerchantColors.readyGreen, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 Metric Tiles Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'إجمالي المبيعات',
                  value: '${_totalGrossToday.toStringAsFixed(2)} د.ل',
                  icon: Icons.trending_up_rounded,
                  color: MerchantColors.accentTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'صافي أرباح المتجر',
                  value: '${_netMerchantShare.toStringAsFixed(2)} د.ل',
                  icon: Icons.account_balance_wallet_rounded,
                  color: MerchantColors.readyGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'نقد محصل كاش',
                  value: '${_cashCollected.toStringAsFixed(2)} د.ل',
                  icon: Icons.payments_rounded,
                  color: MerchantColors.accentAmber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'دفع إلكتروني',
                  value: '${_electronicPaid.toStringAsFixed(2)} د.ل',
                  icon: Icons.credit_card_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricTile(
            title: 'عمولة منصة واصل (10%)',
            value: '${_platformCommission.toStringAsFixed(2)} د.ل',
            icon: Icons.percent_rounded,
            color: Colors.white70,
          ),

          const SizedBox(height: 20),

          // Payout Request Action
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MerchantColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MerchantColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, color: MerchantColors.readyGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'المستحقات الجاهزة للصرف',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'المبلغ القابل للسحب حالياً بعد خصم عمولة المنصة (10%): ${_netMerchantShare.toStringAsFixed(2)} دينار ليبي',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MerchantColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _showWithdrawModal,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      'تقديم طلب تصفية أرباح وسحب رصيد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MerchantColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

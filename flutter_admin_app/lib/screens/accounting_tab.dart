import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';
import '../widgets/digital_voucher_dialog.dart';

class AccountingTab extends StatefulWidget {
  const AccountingTab({super.key});

  @override
  State<AccountingTab> createState() => _AccountingTabState();
}

class _AccountingTabState extends State<AccountingTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Payout requests state
  List<Map<String, dynamic>> _pendingPayouts = [];

  // Vouchers state
  List<Map<String, dynamic>> _vouchers = [];
  String _selectedVoucherFilter = 'all';

  // Audit state
  Map<String, dynamic>? _liveAudit;
  List<Map<String, dynamic>> _pastAudits = [];

  // Partner statements state
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _drivers = [];
  String _statementType = 'store'; // 'store' or 'driver'
  String? _selectedStoreId;
  String? _selectedDriverId;
  Map<String, dynamic>? _activeStatement;
  bool _isStatementLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadAllAccountingData();
      }
    });
    _loadAllAccountingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAccountingData() async {
    setState(() => _isLoading = true);
    final vouchers = await AdminSupabaseService.fetchVouchers();
    final liveAudit = await AdminSupabaseService.calculateLiveAudit();
    final pastAudits = await AdminSupabaseService.fetchDailyAudits();
    final stores = await AdminSupabaseService.fetchStores();
    final drivers = await AdminSupabaseService.fetchDrivers();
    final pendingPayouts = await AdminSupabaseService.fetchPendingPayoutRequests();

    if (mounted) {
      setState(() {
        _vouchers = vouchers;
        _liveAudit = liveAudit;
        _pastAudits = pastAudits;
        _stores = stores;
        _drivers = drivers;
        _pendingPayouts = pendingPayouts;
        if (stores.isNotEmpty && _selectedStoreId == null) {
          _selectedStoreId = stores.first['id'];
        }
        if (drivers.isNotEmpty && _selectedDriverId == null) {
          _selectedDriverId = drivers.first['id'];
        }
        _isLoading = false;
      });
      _loadActiveStatement();
    }
  }

  Future<void> _loadActiveStatement() async {
    if (_statementType == 'store' && _selectedStoreId != null) {
      setState(() => _isStatementLoading = true);
      final stmt = await AdminSupabaseService.getStoreStatement(_selectedStoreId!);
      if (mounted) {
        setState(() {
          _activeStatement = stmt;
          _isStatementLoading = false;
        });
      }
    } else if (_statementType == 'driver' && _selectedDriverId != null) {
      setState(() => _isStatementLoading = true);
      final stmt = await AdminSupabaseService.getCaptainStatement(_selectedDriverId!);
      if (mounted) {
        setState(() {
          _activeStatement = stmt;
          _isStatementLoading = false;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance, color: AdminColors.primaryGold, size: 22),
            SizedBox(width: 8),
            Text('المالية، السندات، والجرد'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AdminColors.primaryGold),
            onPressed: _loadAllAccountingData,
            tooltip: 'تحديث الحسابات',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AdminColors.primaryGold,
          indicatorWeight: 3,
          labelColor: AdminColors.primaryGold,
          unselectedLabelColor: AdminColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text('طلبات السحب'),
                  if (_pendingPayouts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: AdminColors.alertRed,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_pendingPayouts.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.receipt_long), text: 'سندات العمليات'),
            const Tab(icon: Icon(Icons.inventory), text: 'محضر الجرد Z'),
            const Tab(icon: Icon(Icons.assignment), text: 'كشوفات الحساب'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminColors.primaryGold))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPayoutRequestsView(),
                _buildVouchersView(),
                _buildDailyAuditView(),
                _buildStatementsView(),
              ],
            ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 0: PENDING PAYOUT REQUESTS (طلبات التحويل المصرفي والسحب)
  // --------------------------------------------------------------------------
  String _extractAccountNumber(String notes) {
    final parts = notes.split('|');
    for (var p in parts) {
      if (p.contains('رقم الحساب/المحفظة:')) {
        return p.replaceFirst('رقم الحساب/المحفظة:', '').trim();
      }
    }
    return 'غير محدد';
  }

  String _extractMethod(Map<String, dynamic> item) {
    if (item['payment_method'] != null && item['payment_method'].toString().isNotEmpty) {
      return item['payment_method'].toString();
    }
    final notes = (item['notes'] ?? '').toString();
    final parts = notes.split('|');
    for (var p in parts) {
      if (p.contains('طريقة السحب:')) {
        return p.replaceFirst('طريقة السحب:', '').trim();
      }
    }
    return 'تحويل مصرفي';
  }

  Widget _buildPayoutRequestsView() {
    double totalRequestedLyd = 0.0;
    for (var r in _pendingPayouts) {
      final amt = (r['amount_lyd'] is num) ? (r['amount_lyd'] as num).toDouble() : 0.0;
      totalRequestedLyd += amt;
    }

    return RefreshIndicator(
      onRefresh: _loadAllAccountingData,
      color: AdminColors.primaryGold,
      backgroundColor: AdminColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner summary card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1065), Color(0xFF1E1B4B), Color(0xFF0F172A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Colors.purpleAccent, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'طلبات التحويل الفوري الواردة',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _pendingPayouts.isNotEmpty
                            ? AdminColors.alertRed.withValues(alpha: 0.2)
                            : AdminColors.emeraldGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _pendingPayouts.isNotEmpty
                            ? '${_pendingPayouts.length} طلب بانتظار التحويل'
                            : 'لا توجد طلبات معلقة',
                        style: TextStyle(
                          color: _pendingPayouts.isNotEmpty ? AdminColors.alertRed : AdminColors.emeraldGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      totalRequestedLyd.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text('د.ل إجمالي المطلوب سحبه', style: TextStyle(fontSize: 13, color: AdminColors.primaryGold)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'عند قيام المطبخ أو الكابتن بطلب سحب أرباحه عبر سداد أو الحساب المصرفي، يظهر الطلب هنا فوراً لمطابقة الحساب وإصدار سند الصرف.',
                  style: TextStyle(color: AdminColors.textSecondary, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_pendingPayouts.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminColors.divider),
              ),
              child: Column(
                children: [
                  Icon(Icons.verified_outlined, size: 60, color: AdminColors.emeraldGreen.withValues(alpha: 0.6)),
                  const SizedBox(height: 14),
                  const Text(
                    'جميع طلبات السحب مسوّاة ومكتملة! 🎉',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'لا توجد طلبات تحويل مصرفي معلقة من المطابخ أو الكباتن في نالوت حالياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._pendingPayouts.map((req) => _buildPayoutCard(req)),
          ],
        ],
      ),
    );
  }

  Widget _buildPayoutCard(Map<String, dynamic> req) {
    final double amount = (req['amount_lyd'] is num) ? (req['amount_lyd'] as num).toDouble() : 0.0;
    final String storeName = req['beneficiary_name'] ?? 'مطبخ واصل';
    final String method = _extractMethod(req);
    final String accountNumber = _extractAccountNumber(req['notes'] ?? '');
    final String voucherNum = req['voucher_number'] ?? req['id'] ?? '';
    final String createdAt = req['created_at']?.toString().split('T').first ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.purpleAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '$voucherNum • $createdAt',
                            style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminColors.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${amount.toStringAsFixed(2)} د.ل',
                  style: const TextStyle(color: AdminColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AdminColors.divider),

          // Method & Account Number
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('طريقة التحويل:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
                    Text(
                      method,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('رقم الحساب / المحفظة:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
                    Row(
                      children: [
                        Text(
                          accountNumber,
                          style: const TextStyle(color: AdminColors.skyBlue, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: accountNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📋 تم نسخ رقم الحساب ($accountNumber) إلى الحافظة'),
                                backgroundColor: AdminColors.skyBlue,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.copy_rounded, size: 16, color: AdminColors.skyBlue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('اعتماد وصرف السند', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.emeraldGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmApprovePayout(req),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('رفض', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.alertRed,
                    side: const BorderSide(color: AdminColors.alertRed),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmRejectPayout(req),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmApprovePayout(Map<String, dynamic> req) {
    final refController = TextEditingController();
    final double amount = (req['amount_lyd'] is num) ? (req['amount_lyd'] as num).toDouble() : 0.0;
    final String storeName = req['beneficiary_name'] ?? 'المتجر';
    final String method = _extractMethod(req);
    final String accountNumber = _extractAccountNumber(req['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AdminColors.emeraldGreen),
            SizedBox(width: 8),
            Text('تأكيد اعتماد وصرف المستحقات', style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المستفيد: $storeName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text('المبلغ: ${amount.toStringAsFixed(2)} د.ل', style: const TextStyle(color: AdminColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('طريقة التحويل: $method ($accountNumber)', style: const TextStyle(color: AdminColors.skyBlue, fontSize: 12)),
            const SizedBox(height: 14),
            const Text('رقم إيصال أو مرجع التحويل (اختياري):', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: refController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثال: رقم إيصال سداد أو معاملة المصرف',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: AdminColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.emeraldGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await AdminSupabaseService.approvePayoutRequest(
                req['id'],
                notes: 'مرجع التحويل: ${refController.text.trim()}',
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '✅ تم اعتماد صرف ${amount.toStringAsFixed(2)} د.ل لصالح $storeName بنجاح!'
                        : '❌ تعذر اعتماد الطلب، تأكد من الاتصال'),
                    backgroundColor: ok ? AdminColors.emeraldGreen : AdminColors.alertRed,
                  ),
                );
                _loadAllAccountingData();
              }
            },
            child: const Text('تأكيد الصرف الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmRejectPayout(Map<String, dynamic> req) {
    final reasonController = TextEditingController();
    final String storeName = req['beneficiary_name'] ?? 'المتجر';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('رفض طلب السحب', style: TextStyle(color: AdminColors.alertRed, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تريد رفض طلب سحب أرباح $storeName؟', style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 12),
            const Text('سبب الرفض:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'مثال: رقم الحساب غير متطابق مع اسم المتجر',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                filled: true,
                fillColor: AdminColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.alertRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await AdminSupabaseService.rejectPayoutRequest(
                req['id'],
                reason: reasonController.text.trim(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم تسجيل رفض طلب السحب' : '❌ تعذر التحديث'),
                    backgroundColor: ok ? Colors.grey[800] : AdminColors.alertRed,
                  ),
                );
                _loadAllAccountingData();
              }
            },
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: VOUCHERS VIEW (سندات القبض والصرف)
  // --------------------------------------------------------------------------
  Widget _buildVouchersView() {
    double totalReceipts = 0.0;
    double totalDisbursed = 0.0;
    double totalExpenses = 0.0;

    for (var v in _vouchers) {
      final amt = (v['amount_lyd'] is num) ? (v['amount_lyd'] as num).toDouble() : 0.0;
      if (v['type'] == 'receipt') {
        totalReceipts += amt;
      } else if (v['type'] == 'disbursement') {
        totalDisbursed += amt;
      } else if (v['type'] == 'expense') {
        totalExpenses += amt;
      }
    }

    final double netVault = totalReceipts - totalDisbursed - totalExpenses;

    final filteredVouchers = _selectedVoucherFilter == 'all'
        ? _vouchers
        : _vouchers.where((v) => v['type'] == _selectedVoucherFilter).toList();

    return RefreshIndicator(
      onRefresh: _loadAllAccountingData,
      color: AdminColors.primaryGold,
      backgroundColor: AdminColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Card (الخزينة المركزية)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E294B), Color(0xFF0F172A)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('رصيد الخزينة الصافي الفعلي:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AdminColors.emeraldGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('مُطابق ومؤرشف', style: TextStyle(color: AdminColors.emeraldGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      netVault.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    const Text('د.ل', style: TextStyle(fontSize: 16, color: AdminColors.primaryGold, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: AdminColors.divider, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildVaultMiniStat('توريد مقبوضات', '+${totalReceipts.toStringAsFixed(1)}', AdminColors.emeraldGreen),
                    Container(width: 1, height: 28, color: AdminColors.divider),
                    _buildVaultMiniStat('صرف تجار', '-${totalDisbursed.toStringAsFixed(1)}', AdminColors.primaryGold),
                    Container(width: 1, height: 28, color: AdminColors.divider),
                    _buildVaultMiniStat('مصاريف تشغيل', '-${totalExpenses.toStringAsFixed(1)}', AdminColors.alertRed),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Filters & Issue Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filter Chips
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('الكل', 'all'),
                  _buildFilterChip('سند قبض', 'receipt'),
                  _buildFilterChip('سند صرف', 'disbursement'),
                  _buildFilterChip('مصاريف', 'expense'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _showIssueVoucherDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primaryGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_circle, size: 20),
            label: const Text('إصدار سند مالي رسمي جديد (صرف / قبض)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 16),

          // Vouchers List
          Text(
            'سجل الوثائق والسندات المؤرشفة (${filteredVouchers.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
          ),
          const SizedBox(height: 10),

          if (filteredVouchers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Text('لا توجد سندات في هذا التصنيف حالياً', style: TextStyle(color: AdminColors.textSecondary)),
            )
          else
            ...filteredVouchers.map((voucher) => _buildVoucherCard(voucher)),
        ],
      ),
    );
  }

  Widget _buildVaultMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedVoucherFilter == filterKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : AdminColors.textPrimary)),
      selected: isSelected,
      selectedColor: AdminColors.primaryGold,
      backgroundColor: AdminColors.surfaceElevated,
      onSelected: (val) {
        if (val) setState(() => _selectedVoucherFilter = filterKey);
      },
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> v) {
    final type = v['type'] ?? 'receipt';
    final isReceipt = type == 'receipt';
    final isDisbursement = type == 'disbursement';

    final Color badgeColor = isReceipt
        ? AdminColors.emeraldGreen
        : (isDisbursement ? AdminColors.primaryGold : AdminColors.alertRed);

    final String typeTitle = isReceipt
        ? 'سند قبض'
        : (isDisbursement ? 'سند صرف' : 'سند مصروف');

    final double amount = (v['amount_lyd'] is num) ? (v['amount_lyd'] as num).toDouble() : 0.0;
    final dateStr = v['created_at'] != null ? v['created_at'].toString().split('T').first : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
          ),
          child: Icon(
            isReceipt ? Icons.arrow_downward : Icons.arrow_upward,
            color: badgeColor,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              v['beneficiary_name'] ?? 'مستفيد',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminColors.textPrimary),
            ),
            Text(
              '${amount.toStringAsFixed(1)} د.ل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: badgeColor),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(typeTitle, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(v['voucher_number'] ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AdminColors.textSecondary)),
                const Spacer(),
                Text(dateStr, style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
              ],
            ),
            if (v['notes'] != null && v['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                v['notes'],
                style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AdminColors.textSecondary),
        onTap: () => DigitalVoucherDialog.show(context, v),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: DAILY AUDIT & Z-REPORT (محضر الجرد والإقفال اليومي)
  // --------------------------------------------------------------------------
  Widget _buildDailyAuditView() {
    final audit = _liveAudit ?? {};
    final double gmv = (audit['total_gmv_lyd'] is num) ? (audit['total_gmv_lyd'] as num).toDouble() : 0.0;
    final double platformRevenue = (audit['platform_revenue_lyd'] is num) ? (audit['platform_revenue_lyd'] as num).toDouble() : 0.0;
    final double merchantsPayout = (audit['merchants_payout_lyd'] is num) ? (audit['merchants_payout_lyd'] as num).toDouble() : 0.0;
    final double driversPayout = (audit['drivers_payout_lyd'] is num) ? (audit['drivers_payout_lyd'] as num).toDouble() : 0.0;
    final double cashCollected = (audit['cash_collected_lyd'] is num) ? (audit['cash_collected_lyd'] as num).toDouble() : 0.0;
    final double cashPending = (audit['cash_pending_lyd'] is num) ? (audit['cash_pending_lyd'] as num).toDouble() : 0.0;

    return RefreshIndicator(
      onRefresh: _loadAllAccountingData,
      color: AdminColors.primaryGold,
      backgroundColor: AdminColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Day Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'محضر جرد اليوم الحالي (Z-Report Live)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.textPrimary),
                        ),
                        Text(
                          'تاريخ اليومية: ${audit['audit_date'] ?? 'اليوم'}',
                          style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AdminColors.emeraldGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('اليومية مفتوحة', style: TextStyle(color: AdminColors.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                const Divider(color: AdminColors.divider, height: 24),

                _buildAuditMetricRow('إجمالي المبيعات وحجم التداول (GMV):', '${gmv.toStringAsFixed(1)} د.ل', isBold: true, color: AdminColors.textPrimary),
                const SizedBox(height: 10),
                _buildAuditMetricRow('صافي عمولة منصة واصل (10%):', '+${platformRevenue.toStringAsFixed(1)} د.ل', color: AdminColors.emeraldGreen, isBold: true),
                const SizedBox(height: 10),
                _buildAuditMetricRow('صافي مستحقات المتاجر والمطاعم (90%):', '${merchantsPayout.toStringAsFixed(1)} د.ل', color: AdminColors.primaryGold),
                const SizedBox(height: 10),
                _buildAuditMetricRow('إجمالي عمولات وتوصيلات الكباتن:', '${driversPayout.toStringAsFixed(1)} د.ل', color: AdminColors.skyBlue),
                const SizedBox(height: 10),
                _buildAuditMetricRow('الكاش المورّد للخزينة (سندات قبض):', '${cashCollected.toStringAsFixed(1)} د.ل', color: AdminColors.emeraldGreen),
                const SizedBox(height: 10),
                _buildAuditMetricRow('الكاش المعلق في ذمم الكباتن (COD):', '${cashPending.toStringAsFixed(1)} د.ل', color: AdminColors.alertRed),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () => _confirmCloseDay(audit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.emeraldGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('إقفال اليومية واعتماد محضر الجرد النهائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Archived Audits Section
          const Text(
            'أرشيف محاضر الجرد السابقة (Historical Z-Reports)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.textPrimary),
          ),
          const SizedBox(height: 12),

          if (_pastAudits.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد محاضر جرد مؤرشفة بعد', style: TextStyle(color: AdminColors.textSecondary))))
          else
            ..._pastAudits.map((a) => _buildPastAuditCard(a)),
        ],
      ),
    );
  }

  Widget _buildAuditMetricRow(String label, String value, {bool isBold = false, Color color = AdminColors.textPrimary}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPastAuditCard(Map<String, dynamic> a) {
    final double gmv = (a['total_gmv_lyd'] is num) ? (a['total_gmv_lyd'] as num).toDouble() : 0.0;
    final double profit = (a['platform_revenue_lyd'] is num) ? (a['platform_revenue_lyd'] as num).toDouble() : 0.0;
    final date = a['audit_date'] ?? '';
    final code = a['audit_code'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, color: AdminColors.emeraldGreen, size: 18),
                    const SizedBox(width: 8),
                    Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(date, style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
                ),
              ],
            ),
            const Divider(color: AdminColors.divider, height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المبيعات: ${gmv.toStringAsFixed(1)} د.ل', style: const TextStyle(fontSize: 13, color: AdminColors.textPrimary)),
                Text('أرباح واصل (10%): +${profit.toStringAsFixed(1)} د.ل', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminColors.emeraldGreen)),
              ],
            ),
            if (a['notes'] != null && a['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'ملاحظات الجرد: ${a['notes']}',
                style: const TextStyle(fontSize: 11, color: AdminColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: STATEMENTS VIEW (كشوفات الحساب للمطاعم والكباتن)
  // --------------------------------------------------------------------------
  Widget _buildStatementsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Type Selector Toggle
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _statementType = 'store');
                  _loadActiveStatement();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _statementType == 'store' ? AdminColors.primaryGold : AdminColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'كشف حساب مطعم / محل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statementType == 'store' ? Colors.black : AdminColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _statementType = 'driver');
                  _loadActiveStatement();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _statementType == 'driver' ? AdminColors.primaryGold : AdminColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'كشف حساب كابتن توصيل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statementType == 'driver' ? Colors.black : AdminColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Dropdown selection
        if (_statementType == 'store')
          DropdownButtonFormField<String>(
            initialValue: _selectedStoreId,
            decoration: const InputDecoration(
              labelText: 'اختر المتجر / المطعم في نالوت',
              prefixIcon: Icon(Icons.storefront, color: AdminColors.primaryGold),
            ),
            items: _stores.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'] as String,
                child: Text(s['name'] as String),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedStoreId = val);
              _loadActiveStatement();
            },
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedDriverId,
            decoration: const InputDecoration(
              labelText: 'اختر الكابتن في نالوت',
              prefixIcon: Icon(Icons.two_wheeler, color: AdminColors.primaryGold),
            ),
            items: _drivers.map((d) {
              return DropdownMenuItem<String>(
                value: d['id'] as String,
                child: Text(d['full_name'] as String),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedDriverId = val);
              _loadActiveStatement();
            },
          ),

        const SizedBox(height: 16),

        if (_isStatementLoading)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AdminColors.primaryGold)))
        else if (_statementType == 'store')
          _buildStoreStatementDetails()
        else
          _buildDriverStatementDetails(),
      ],
    );
  }

  Widget _buildStoreStatementDetails() {
    final stmt = _activeStatement ?? {};
    final store = stmt['store'] ?? {};
    final double sales = (stmt['gross_sales_lyd'] is num) ? (stmt['gross_sales_lyd'] as num).toDouble() : 0.0;
    final double commission = (stmt['platform_commission_lyd'] is num) ? (stmt['platform_commission_lyd'] as num).toDouble() : 0.0;
    final double earned = (stmt['net_earned_lyd'] is num) ? (stmt['net_earned_lyd'] as num).toDouble() : 0.0;
    final double disbursed = (stmt['total_disbursed_lyd'] is num) ? (stmt['total_disbursed_lyd'] as num).toDouble() : 0.0;
    final double remaining = (stmt['net_payable_remaining_lyd'] is num) ? (stmt['net_payable_remaining_lyd'] as num).toDouble() : 0.0;
    final List vouchers = stmt['vouchers'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'كشف حساب: ${store['name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.primaryGold),
              ),
              const SizedBox(height: 4),
              Text(
                'المنطقة: ${store['district'] ?? 'نالوت'}',
                style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
              ),
              const Divider(color: AdminColors.divider, height: 20),

              _buildAuditMetricRow('إجمالي المبيعات المحققة:', '${sales.toStringAsFixed(1)} د.ل'),
              const SizedBox(height: 8),
              _buildAuditMetricRow('استقطاع عمولة واصل (10%):', '-${commission.toStringAsFixed(1)} د.ل', color: AdminColors.alertRed),
              const SizedBox(height: 8),
              _buildAuditMetricRow('صافي استحقاق المطعم:', '${earned.toStringAsFixed(1)} د.ل', isBold: true),
              const SizedBox(height: 8),
              _buildAuditMetricRow('المبالغ المصروفة بسندات:', '-${disbursed.toStringAsFixed(1)} د.ل', color: AdminColors.skyBlue),
              const Divider(color: AdminColors.divider, height: 20),
              _buildAuditMetricRow('الرصيد المتبقي المستحق للصرف:', '${remaining.toStringAsFixed(1)} د.ل', isBold: true, color: AdminColors.emeraldGreen),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: remaining > 0 ? () => _quickDisburseToStore(store['name'], remaining) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AdminColors.surfaceElevated,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.payment, size: 18),
                label: const Text('صرف المستحقات الآن وإصدار سند صرف', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('سجل سندات الصرف للمطعم (${vouchers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),

        if (vouchers.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد سندات صرف سابقة لهذا المطعم', style: TextStyle(color: AdminColors.textSecondary))))
        else
          ...vouchers.map((v) => _buildVoucherCard(Map<String, dynamic>.from(v))),
      ],
    );
  }

  Widget _buildDriverStatementDetails() {
    final stmt = _activeStatement ?? {};
    final driver = stmt['driver'] ?? {};
    final double totalCollected = (stmt['total_collected_lyd'] is num) ? (stmt['total_collected_lyd'] as num).toDouble() : 0.0;
    final double totalSettled = (stmt['total_settled_lyd'] is num) ? (stmt['total_settled_lyd'] as num).toDouble() : 0.0;
    final double pendingCash = (stmt['pending_cash_lyd'] is num) ? (stmt['pending_cash_lyd'] as num).toDouble() : 0.0;
    final int trips = stmt['total_trips'] ?? 0;
    final List vouchers = stmt['vouchers'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'كشف حساب الكابتن: ${driver['full_name'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminColors.primaryGold),
              ),
              const SizedBox(height: 4),
              Text(
                'هاتف: ${driver['phone'] ?? ''} • مركبة: ${driver['vehicle_type'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
              ),
              const Divider(color: AdminColors.divider, height: 20),

              _buildAuditMetricRow('إجمالي الرحلات المنجزة:', '$trips مشوار'),
              const SizedBox(height: 8),
              _buildAuditMetricRow('إجمالي الكاش المحصل (COD):', '${totalCollected.toStringAsFixed(1)} د.ل'),
              const SizedBox(height: 8),
              _buildAuditMetricRow('الكاش المورد بسندات قبض:', '${totalSettled.toStringAsFixed(1)} د.ل', color: AdminColors.emeraldGreen),
              const Divider(color: AdminColors.divider, height: 20),
              _buildAuditMetricRow('العهدة النقدية المعلقة حالياً:', '${pendingCash.toStringAsFixed(1)} د.ل', isBold: true, color: AdminColors.alertRed),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: pendingCash > 0 ? () => _quickSettleCaptain(driver, pendingCash) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.emeraldGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AdminColors.surfaceElevated,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('استلام الكاش وتوريد عهدة وإصدار سند قبض', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('سجل سندات القبض للكابتن (${vouchers.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),

        if (vouchers.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد سندات قبض سابقة لهذا الكابتن', style: TextStyle(color: AdminColors.textSecondary))))
        else
          ...vouchers.map((v) => _buildVoucherCard(Map<String, dynamic>.from(v))),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // DIALOGS & ACTIONS
  // --------------------------------------------------------------------------
  void _showIssueVoucherDialog() {
    String type = 'disbursement';
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AdminColors.surfaceElevated,
            title: const Text('إصدار سند مالي رسمي جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'نوع السند'),
                    items: const [
                      DropdownMenuItem(value: 'disbursement', child: Text('سند صرف (مستحقات تاجر/مطعم)')),
                      DropdownMenuItem(value: 'receipt', child: Text('سند قبض (توريد كاش من كابتن/عميل)')),
                      DropdownMenuItem(value: 'expense', child: Text('سند مصروفات تشغيلية وطوارئ')),
                    ],
                    onChanged: (val) => setDialogState(() => type = val!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستلم / المستفيد',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ المالي (د.ل)',
                      prefixIcon: Icon(Icons.monetization_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'البيان / ملاحظات الاعتماد',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emeraldGreen, foregroundColor: Colors.white),
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (nameCtrl.text.isNotEmpty && amt > 0) {
                    Navigator.pop(dialogContext);
                    final v = await AdminSupabaseService.createVoucher(
                      type: type,
                      beneficiaryName: nameCtrl.text.trim(),
                      beneficiaryRole: type == 'disbursement' ? 'merchant' : (type == 'receipt' ? 'captain' : 'operational'),
                      amountLyd: amt,
                      notes: notesCtrl.text.trim(),
                    );
                    _loadAllAccountingData();
                    if (!mounted) return;
                    DigitalVoucherDialog.show(context, v);
                  }
                },
                child: const Text('اعتماد وحفظ السند'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCloseDay(Map<String, dynamic> audit) {
    final notesCtrl = TextEditingController(text: 'تم إقفال اليومية ومطابقة الخزينة المركزية بنجاح.');

    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          title: const Row(
            children: [
              Icon(Icons.lock, color: AdminColors.primaryGold),
              SizedBox(width: 8),
              Text('تأكيد إقفال اليومية وحفظ الجرد'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيتم ترحيل جميع أرقام اليوم وتوليد كود جرد رسمي وأرشفة السجل في سحابة واصل بشكل دائم.',
                style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات محضر الجرد',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء', style: TextStyle(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emeraldGreen, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await AdminSupabaseService.closeDailyAudit(
                  auditData: audit,
                  notes: notesCtrl.text.trim(),
                );
                _loadAllAccountingData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AdminColors.emeraldGreen,
                    content: Text('✅ تم إقفال اليومية واعتماد محضر الجرد Z بنجاح تام!'),
                  ),
                );
              },
              child: const Text('نعم، إقفال واعتماد الجرد'),
            ),
          ],
        ),
      ),
    );
  }

  void _quickDisburseToStore(String storeName, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          title: const Text('تأكيد صرف مستحقات المتجر'),
          content: Text('هل تود صرف مبلغ (${amount.toStringAsFixed(1)} د.ل) نقداً للسيد/ $storeName؟\nسيتم إصدار سند صرف رسمي فوراً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emeraldGreen, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الصرف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final v = await AdminSupabaseService.createVoucher(
        type: 'disbursement',
        beneficiaryName: storeName,
        beneficiaryRole: 'merchant',
        beneficiaryId: _selectedStoreId,
        amountLyd: amount,
        notes: 'صرف مستحقات المبيعات بعد خصم عمولة المنظومة 10%',
      );
      _loadAllAccountingData();
      if (mounted) {
        DigitalVoucherDialog.show(context, v);
      }
    }
  }

  void _quickSettleCaptain(Map<String, dynamic> driver, double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AdminColors.surfaceElevated,
          title: const Text('تأكيد استلام العهدة وتوريد الكاش'),
          content: Text('هل استلمت مبلغ (${amount.toStringAsFixed(1)} د.ل) نقداً من الكابتن ${driver['full_name']}؟\nسيتم تصفير عهدته وإصدار سند قبض رسمي.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AdminColors.emeraldGreen, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('نعم، استلمت الكاش'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final v = await AdminSupabaseService.settleDriverCashWithVoucher(driver);
      _loadAllAccountingData();
      if (mounted) {
        DigitalVoucherDialog.show(context, v);
      }
    }
  }
}

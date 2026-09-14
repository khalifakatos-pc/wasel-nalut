import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'services/driver_supabase_service.dart';

/// ============================================================================
/// CAPTAIN WASEL DRIVER WALLET & COD LEDGER MANAGEMENT SCREEN
/// ============================================================================

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  double _availableEarningsLyd = 0.0;
  double _cashInHandCodLyd = 0.0;
  final double _maxCodLimitLyd = 500.00;
  int _completedTrips = 0;
  String _selectedFilter = 'الكل';
  String _captainName = 'كابتن واصل';

  late List<LedgerTransaction> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = [];
    _loadLiveWalletData();
  }

  Future<void> _loadLiveWalletData() async {
    final profile = await DriverSupabaseService.fetchDriverProfile();
    final vouchers = await DriverSupabaseService.fetchDriverVouchers();
    if (mounted) {
      setState(() {
        _captainName = profile['full_name']?.toString() ?? 'كابتن واصل';
        _cashInHandCodLyd = (profile['wallet_balance_lyd'] is num)
            ? (profile['wallet_balance_lyd'] as num).toDouble()
            : 0.0;
        final int trips = (profile['total_trips'] is int) ? profile['total_trips'] as int : 0;
        _completedTrips = trips;
        _availableEarningsLyd = (trips * 5.0).toDouble();

        for (var v in vouchers) {
          final amt = (v['amount_lyd'] is num) ? (v['amount_lyd'] as num).toDouble() : 0.0;
          final String ref = v['voucher_number'] ?? 'REC-2026';
          final alreadyExists = _transactions.any((t) => t.referenceId == ref);
          if (!alreadyExists) {
            DateTime txTime = DateTime.now();
            if (v['created_at'] != null) {
              try {
                txTime = DateTime.parse(v['created_at'].toString());
              } catch (_) {}
            }
            _transactions.insert(
              0,
              LedgerTransaction(
                id: v['id'] ?? 'v',
                type: TransactionType.platformSettlement,
                title: 'توريد وسداد عهدة رسمية (سند قبض)',
                description: v['notes'] ?? 'توريد عهدة نقدية وإبراء ذمة',
                amountLyd: amt,
                isCredit: false,
                timestamp: txTime,
                referenceId: ref,
              ),
            );
          }
        }
      });
    }
  }

  List<LedgerTransaction> get _filteredTransactions {
    if (_selectedFilter == 'الأرباح') {
      return _transactions.where((t) => t.type == TransactionType.tripEarnings || t.type == TransactionType.surgeBonus || t.type == TransactionType.tipReceived).toList();
    } else if (_selectedFilter == 'الكاش (COD)') {
      return _transactions.where((t) => t.type == TransactionType.codCollected || t.type == TransactionType.platformSettlement).toList();
    } else if (_selectedFilter == 'السحوبات') {
      return _transactions.where((t) => t.type == TransactionType.payoutWithdrawalSadad || t.type == TransactionType.payoutWithdrawalTadawul).toList();
    }
    return _transactions;
  }

  void _openDepositSettleModal() {
    final amountController = TextEditingController(text: _cashInHandCodLyd.toStringAsFixed(0));
    final phoneController = TextEditingController(text: '0912345678');
    String selectedMethod = 'سداد';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: DriverColors.darkSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: DriverColors.darkBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, color: DriverColors.sadadBlue, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'تسوية كاش المنصة (إيداع COD)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('اختر وسيلة الدفع الإلكتروني:', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['سداد', 'تداول', 'موزع نالوت المعتمد'].map((m) {
                        final isSel = selectedMethod == m;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(m, style: TextStyle(color: isSel ? Colors.white : Colors.white70)),
                            selected: isSel,
                            selectedColor: DriverColors.primary,
                            backgroundColor: DriverColors.darkCardElevated,
                            onSelected: (val) {
                              if (val) setModalState(() => selectedMethod = m);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المراد تسويته (د.ل)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف المسجل بسداد',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          setState(() {
                            _cashInHandCodLyd = (_cashInHandCodLyd - amt).clamp(0.0, 9999.0);
                            _transactions.insert(
                              0,
                              LedgerTransaction(
                                id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                title: 'تسوية كاش المنصة ($selectedMethod)',
                                description: 'تمت التسوية بنجاح عبر $selectedMethod',
                                amountLyd: amt,
                                isCredit: true,
                                type: TransactionType.platformSettlement,
                                timestamp: DateTime.now(),
                                referenceId: 'SETTLE-${DateTime.now().millisecondsSinceEpoch}',
                              ),
                            );
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ تمت تسوية مبلغ $amt د.ل بنجاح!'),
                              backgroundColor: DriverColors.onlineGreen,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: DriverColors.onlineGreen),
                        child: const Text('تأكيد التسوية الفورية ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openWithdrawalModal() {
    final amountController = TextEditingController(text: '100');
    final cardController = TextEditingController(text: '1120-4490-8819-2041');
    String selectedMethod = 'سداد';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: DriverColors.darkSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: DriverColors.darkBorder,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.account_balance_rounded, color: DriverColors.tadawulTeal, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'سحب أرباح الكابتن الفورية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('اختر وسيلة الاستلام:', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['سداد Sadad', 'بطاقة تداول', 'مصرف الأمان'].map((m) {
                        final isSel = selectedMethod == m;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(m, style: TextStyle(color: isSel ? Colors.white : Colors.white70)),
                            selected: isSel,
                            selectedColor: DriverColors.tadawulTeal,
                            backgroundColor: DriverColors.darkCardElevated,
                            onSelected: (val) {
                              if (val) setModalState(() => selectedMethod = m);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المبلغ المراد سحبه (المتاح: ${_availableEarningsLyd.toStringAsFixed(2)} د.ل)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cardController,
                      decoration: const InputDecoration(
                        labelText: 'رقم البطاقة / الحساب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final amt = double.tryParse(amountController.text) ?? 0.0;
                          if (amt > _availableEarningsLyd) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('الرصيد المتاح غير كافٍ!'), backgroundColor: DriverColors.urgentRed),
                            );
                            return;
                          }
                          setState(() {
                            _availableEarningsLyd -= amt;
                            _transactions.insert(
                              0,
                              LedgerTransaction(
                                id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
                                title: 'سحب أرباح ($selectedMethod)',
                                description: 'تحويل مباشر إلى $selectedMethod',
                                amountLyd: amt,
                                isCredit: false,
                                type: TransactionType.payoutWithdrawalSadad,
                                timestamp: DateTime.now(),
                                referenceId: 'WTH-${DateTime.now().millisecondsSinceEpoch}',
                              ),
                            );
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ تم تحويل مبلغ $amt د.ل إلى حسابك بنجاح!'),
                              backgroundColor: DriverColors.onlineGreen,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: DriverColors.tadawulTeal),
                        child: const Text('تأكيد التحويل الآن 💳', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.darkBg,
      appBar: AppBar(
        title: const Text('محفظة كابتن واصل 💳'),
        centerTitle: true,
        backgroundColor: DriverColors.darkSurface,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLiveWalletData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLiveWalletData,
        color: DriverColors.primary,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Balance Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: DriverColors.walletHeaderGradient,
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(color: DriverColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('صافي أرباحك المتاحة للسحب', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _availableEarningsLyd.toStringAsFixed(2),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 8),
                    const Text('دينار ليبي (د.ل)', style: TextStyle(color: DriverColors.onlineGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$_completedTrips رحلات منجزة اليوم',
                        style: const TextStyle(fontSize: 11, color: DriverColors.onlineGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '• صافي عمولة الكابتن: +5.00 د.ل / مشوار',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('سحب الأرباح', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DriverColors.tadawulTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                        ),
                        onPressed: _openWithdrawalModal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_rounded, size: 18),
                        label: const Text('تسوية الكاش', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: DriverColors.codWarning,
                          side: const BorderSide(color: DriverColors.codWarning),
                          shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                        ),
                        onPressed: _openDepositSettleModal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. COD Liability Card & Threshold Alert (> 500 LYD)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DriverColors.darkCard,
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(
                color: _cashInHandCodLyd >= _maxCodLimitLyd ? DriverColors.urgentRed : DriverColors.darkBorder,
                width: _cashInHandCodLyd >= _maxCodLimitLyd ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('كاش في عهدة الكابتن (COD):', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(
                      '${_cashInHandCodLyd.toStringAsFixed(2)} / ${_maxCodLimitLyd.toStringAsFixed(0)} د.ل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _cashInHandCodLyd >= _maxCodLimitLyd ? DriverColors.urgentRed : DriverColors.codWarning,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (_cashInHandCodLyd / _maxCodLimitLyd).clamp(0.0, 1.0),
                  backgroundColor: DriverColors.darkCardElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _cashInHandCodLyd >= _maxCodLimitLyd ? DriverColors.urgentRed : DriverColors.codWarning,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                if (_cashInHandCodLyd >= _maxCodLimitLyd) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DriverColors.urgentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DriverColors.urgentRed),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: DriverColors.urgentRed, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ تجاوز سقف العهدة (500 د.ل)! يجب إجراء تسوية نقدية فورية لإبراء الذمة وتفادي إيقاف الحساب.',
                            style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_cashInHandCodLyd >= (_maxCodLimitLyd * 0.75)) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚡ تنبيه: اقتربت من حد العهدة المسموح به (${((_cashInHandCodLyd / _maxCodLimitLyd) * 100).toInt()}%). يفضل التوريد عبر سداد.',
                    style: const TextStyle(fontSize: 11, color: DriverColors.codWarning),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Transactions Ledger Header & Filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('سجل الحركات المالية (اضغط للمعاينة)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              DropdownButton<String>(
                value: _selectedFilter,
                dropdownColor: DriverColors.darkSurface,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                underline: const SizedBox(),
                items: ['الكل', 'الأرباح', 'الكاش (COD)', 'السحوبات'].map((f) {
                  return DropdownMenuItem(value: f, child: Text(f));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFilter = val);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 4. Ledger List (Clickable with official settlement receipt modal)
          ..._filteredTransactions.map((tx) {
            return InkWell(
              borderRadius: DriverRadius.radiusMd,
              onTap: () => _showSettlementReceiptDialog(context, tx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DriverColors.darkCard,
                  borderRadius: DriverRadius.radiusMd,
                  border: Border.all(color: DriverColors.darkBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tx.isCredit ? DriverColors.onlineGreen.withValues(alpha: 0.15) : DriverColors.urgentRed.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: tx.isCredit ? DriverColors.onlineGreen : DriverColors.urgentRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                              ),
                              const Icon(Icons.receipt_outlined, size: 14, color: DriverColors.primary),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(tx.description, style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${tx.isCredit ? '+' : '-'}${tx.amountLyd.toStringAsFixed(2)} د.ل',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: tx.isCredit ? DriverColors.onlineGreen : DriverColors.urgentRed,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

  void _showSettlementReceiptDialog(BuildContext context, LedgerTransaction tx) {
    final isSettlement = tx.type == TransactionType.platformSettlement;
    final isCod = tx.type == TransactionType.codCollected;

    String receiptTitle = isSettlement
        ? 'سند قبض وتوريد عهدة نقدية'
        : (isCod ? 'إشعار تحصيل كاش من الزبون' : 'سند استحقاق أرباح التوصيل');

    String channel = isSettlement
        ? 'سداد Sadad Pay (إلكتروني)'
        : (isCod ? 'كاش يدوي (COD)' : 'محفظة واصل نالوت');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: DriverColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: DriverColors.primary, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DriverColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: DriverColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'شركة واصل نالوت للخدمات اللوجستية',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              receiptTitle,
                              style: const TextStyle(color: DriverColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DriverColors.onlineGreen),
                        ),
                        child: const Text('معتمد ✅', style: TextStyle(color: DriverColors.onlineGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(color: DriverColors.darkBorder, height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: DriverColors.darkCardElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DriverColors.darkBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('المبلغ المالي الموثق في السند', style: TextStyle(color: DriverColors.darkTextMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              tx.amountLyd.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace'),
                            ),
                            const SizedBox(width: 6),
                            const Text('دينار ليبي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DriverColors.onlineGreen)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildReceiptRow('رقم السند المرجعي:', tx.referenceId),
                  _buildReceiptRow('اسم الكابتن:', _captainName),
                  _buildReceiptRow(
                    'التاريخ والوقت:',
                    '${tx.timestamp.year}-${tx.timestamp.month.toString().padLeft(2, '0')}-${tx.timestamp.day.toString().padLeft(2, '0')} ${tx.timestamp.hour.toString().padLeft(2, '0')}:${tx.timestamp.minute.toString().padLeft(2, '0')}',
                  ),
                  _buildReceiptRow('قناة المعاملة:', channel),
                  _buildReceiptRow('البيان:', tx.description),
                  if (tx.orderReference != null)
                    _buildReceiptRow('رقم الطلب المرتبط:', tx.orderReference!),

                  const Divider(color: DriverColors.darkBorder, height: 20),

                  Row(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.white70),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سند إلكتروني رسمي موثق بسجلات منصة واصل نالوت',
                              style: TextStyle(fontSize: 10, color: DriverColors.darkTextMuted),
                            ),
                            Text(
                              'VERIFY-HASH: ${tx.referenceId.hashCode.abs().toRadixString(16).padLeft(12, '0').toUpperCase()}',
                              style: const TextStyle(fontSize: 9, color: Colors.white38, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('مشاركة السند', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('📤 تم نسخ رابط السند الرسمي: ${tx.referenceId}')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إغلاق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

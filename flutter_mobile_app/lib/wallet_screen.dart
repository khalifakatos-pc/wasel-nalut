import 'package:flutter/material.dart';
import 'design_system.dart';

class WalletTransaction {
  final String id;
  final String title;
  final String date;
  final double amount;
  final bool isCredit;
  final String category;

  WalletTransaction({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isCredit,
    required this.category,
  });
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 120.00;
  String _selectedFilter = 'all';

  final List<WalletTransaction> _transactions = [
    WalletTransaction(
      id: 'tx-1',
      title: 'طلب من مطعم المهاري للأسماك',
      date: 'اليوم، 02:30 م',
      amount: 28.50,
      isCredit: false,
      category: 'food',
    ),
    WalletTransaction(
      id: 'tx-2',
      title: 'شحن رصيد عبر تطبيق سداد',
      date: 'أمس، 10:15 م',
      amount: 100.00,
      isCredit: true,
      category: 'topup',
    ),
    WalletTransaction(
      id: 'tx-3',
      title: 'مشتريات من سوبرماركت الجت',
      date: '20 أغسطس، 04:45 م',
      amount: 45.00,
      isCredit: false,
      category: 'grocery',
    ),
    WalletTransaction(
      id: 'tx-4',
      title: 'استرداد قيمة طلب ملغي #PRS-1092',
      date: '18 أغسطس، 01:20 م',
      amount: 32.00,
      isCredit: true,
      category: 'refund',
    ),
  ];

  void _showTopUpDialog() {
    final TextEditingController amountController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusMd,
              ),
              child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.warning, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('شحن محفظة واصل', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل المبلغ بالدينار الليبي:',
              style: TextStyle(fontSize: 13, color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: 'د.ل',
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اختر بوابة الدفع المحلية:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGatewayChip('سداد', Icons.phone_android_rounded, AppColors.waselPrimary),
                const SizedBox(width: 8),
                _buildGatewayChip('تداول', Icons.credit_card_rounded, AppColors.info),
                const SizedBox(width: 8),
                _buildGatewayChip('ليبيانا', Icons.sim_card_rounded, AppColors.success),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text) ?? 0.0;
              if (amt > 0) {
                setState(() {
                  _balance += amt;
                  _transactions.insert(
                    0,
                    WalletTransaction(
                      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                      title: 'شحن رصيد عبر سداد',
                      date: 'الآن',
                      amount: amt,
                      isCredit: true,
                      category: 'topup',
                    ),
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم شحن ${amt.toStringAsFixed(2)} د.ل بنجاح!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.waselPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
            ),
            child: const Text('تأكيد الشحن'),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayChip(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: AppRadius.radiusMd,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog() {
    final phoneController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: const Text('تحويل رصيد لمستخدم آخر', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'رقم هاتف المستلم (091xxxxxxx)',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'المبلغ المراد تحويله (د.ل)',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text) ?? 0.0;
              if (amt > 0 && amt <= _balance) {
                setState(() {
                  _balance -= amt;
                  _transactions.insert(
                    0,
                    WalletTransaction(
                      id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
                      title: 'تحويل إلى (${phoneController.text})',
                      date: 'الآن',
                      amount: amt,
                      isCredit: false,
                      category: 'transfer',
                    ),
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم تحويل ${amt.toStringAsFixed(2)} د.ل بنجاح!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.waselPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('إرسال الآن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredTransactions = _transactions.where((tx) {
      if (_selectedFilter == 'credit') return tx.isCredit;
      if (_selectedFilter == 'debit') return !tx.isCredit;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظة واصل الرقمية'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. MAIN BALANCE CARD
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF451A03)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.radiusXl,
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الرصيد المتاح للاستخدام',
                      style: TextStyle(fontSize: 12, color: AppColors.warningLight),
                    ),
                    Icon(Icons.verified_user_rounded, color: AppColors.warning, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _balance.toStringAsFixed(3),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'دينار ليبي (LYD)',
                      style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showTopUpDialog,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('شحن المحفظة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showTransferDialog,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('تحويل رصيد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 2. QUICK ACTIONS & REWARDS
          Row(
            children: [
              _buildFeatureTile(
                icon: Icons.qr_code_scanner_rounded,
                title: 'مسح QR للدفع',
                subtitle: 'دفع مباشر للمتجر',
                color: AppColors.waselPrimary,
                isDark: isDark,
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildFeatureTile(
                icon: Icons.card_giftcard_rounded,
                title: 'نقاط المكافآت',
                subtitle: '450 نقطة واصل',
                color: AppColors.waselPurple,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // 3. TRANSACTION HISTORY TITLE & FILTERS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'سجل المعاملات المالية',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _buildFilterTab('all', 'الكل'),
                  _buildFilterTab('credit', 'إيداع'),
                  _buildFilterTab('debit', 'مشتريات'),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 4. TRANSACTIONS LIST
          ...filteredTransactions.map((tx) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (tx.isCredit ? AppColors.success : AppColors.waselPrimary).withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: Icon(
                      tx.isCredit ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined,
                      color: tx.isCredit ? AppColors.success : AppColors.waselPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          tx.date,
                          style: const TextStyle(fontSize: 10, color: AppColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${tx.isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} د.ل',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: tx.isCredit ? AppColors.success : AppColors.error,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedFilter = id),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.waselPrimary : Colors.transparent,
          borderRadius: AppRadius.radiusSm,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.darkTextSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

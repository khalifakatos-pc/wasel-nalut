import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../services/admin_supabase_service.dart';

class SmartSettingsTab extends StatefulWidget {
  const SmartSettingsTab({super.key});

  @override
  State<SmartSettingsTab> createState() => _SmartSettingsTabState();
}

class _SmartSettingsTabState extends State<SmartSettingsTab> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Referral Settings
  bool _referralEnabled = true;
  final TextEditingController _referralTargetCountCtrl = TextEditingController(text: '3');
  String _referralRewardType = 'free_delivery'; // 'free_delivery' or 'wallet_lyd'
  final TextEditingController _referralRewardCtrl = TextEditingController(text: '5.0');
  final TextEditingController _referralValidityDaysCtrl = TextEditingController(text: '14');
  String _referralCondition = 'on_signup_otp'; // 'on_signup_otp' or 'on_first_order'
  final TextEditingController _referralMinOrderCtrl = TextEditingController(text: '20.0');

  // Loyalty Settings
  bool _loyaltyEnabled = true;
  final TextEditingController _loyaltyPointsPerLydCtrl = TextEditingController(text: '1.0');
  final TextEditingController _loyaltyRedemptionRateCtrl = TextEditingController(text: '20.0');

  // Captain Bonus Settings
  bool _captainBonusEnabled = true;
  final TextEditingController _captainTargetCtrl = TextEditingController(text: '8');
  final TextEditingController _captainBonusLydCtrl = TextEditingController(text: '15.0');

  // Ratings
  bool _ratingsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final cfg = await AdminSupabaseService.fetchSystemConfigurations();
    if (mounted) {
      setState(() {
        _referralEnabled = cfg['referral_enabled'] ?? true;
        _referralTargetCountCtrl.text = (cfg['referral_target_count'] ?? 3).toString();
        _referralRewardType = cfg['referral_reward_type'] ?? 'free_delivery';
        _referralRewardCtrl.text = (cfg['referral_reward_lyd'] ?? 5.0).toString();
        _referralValidityDaysCtrl.text = (cfg['referral_validity_days'] ?? 14).toString();
        _referralCondition = cfg['referral_condition'] ?? 'on_signup_otp';
        _referralMinOrderCtrl.text = (cfg['referral_min_order_lyd'] ?? 20.0).toString();

        _loyaltyEnabled = cfg['loyalty_enabled'] ?? true;
        _loyaltyPointsPerLydCtrl.text = (cfg['loyalty_points_per_lyd'] ?? 1.0).toString();
        _loyaltyRedemptionRateCtrl.text = (cfg['loyalty_redemption_rate'] ?? 20.0).toString();

        _captainBonusEnabled = cfg['captain_bonus_enabled'] ?? true;
        _captainTargetCtrl.text = (cfg['captain_daily_target'] ?? 8).toString();
        _captainBonusLydCtrl.text = (cfg['captain_daily_bonus_lyd'] ?? 15.0).toString();

        _ratingsEnabled = cfg['ratings_enabled'] ?? true;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final newConfig = {
      'referral_enabled': _referralEnabled,
      'referral_target_count': int.tryParse(_referralTargetCountCtrl.text) ?? 3,
      'referral_reward_type': _referralRewardType,
      'referral_reward_lyd': double.tryParse(_referralRewardCtrl.text) ?? 5.0,
      'referral_validity_days': int.tryParse(_referralValidityDaysCtrl.text) ?? 14,
      'referral_condition': _referralCondition,
      'referral_min_order_lyd': double.tryParse(_referralMinOrderCtrl.text) ?? 20.0,
      'loyalty_enabled': _loyaltyEnabled,
      'loyalty_points_per_lyd': double.tryParse(_loyaltyPointsPerLydCtrl.text) ?? 1.0,
      'loyalty_redemption_rate': double.tryParse(_loyaltyRedemptionRateCtrl.text) ?? 20.0,
      'captain_bonus_enabled': _captainBonusEnabled,
      'captain_daily_target': int.tryParse(_captainTargetCtrl.text) ?? 8,
      'captain_daily_bonus_lyd': double.tryParse(_captainBonusLydCtrl.text) ?? 15.0,
      'ratings_enabled': _ratingsEnabled,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final success = await AdminSupabaseService.updateSystemConfigurations(newConfig);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ تم حفظ ونشر القواعد والحوافز في السحابة بنجاح!' : '❌ تعذر الحفظ، يرجى التحقق من الاتصال',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: success ? Colors.green[700] : Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showReviewsModal() async {
    final reviews = await AdminSupabaseService.fetchRecentReviews();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⭐ أحدث تقييمات الزبائن للخدمة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AdminColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: AdminColors.divider),
                Expanded(
                  child: reviews.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد تقييمات سلبية أو نزاعات حالياً. كافة التقييمات ممتازة ⭐',
                            style: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: reviews.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, idx) {
                            final r = reviews[idx];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AdminColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AdminColors.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        r['order_number'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.primaryGold),
                                      ),
                                      Text(
                                        r['customer_name'] ?? '',
                                        style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    r['notes'] ?? '',
                                    style: const TextStyle(color: AdminColors.textPrimary, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AdminColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AdminColors.primaryGold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        elevation: 0,
        title: const Text(
          'محرك الحوافز والإعدادات الذكية ⚙️',
          style: TextStyle(
            color: AdminColors.primaryGold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AdminColors.textSecondary),
            onPressed: _loadConfig,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.primaryGold.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tune, color: AdminColors.primaryGold, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تحكم فوري وديناميكي: أي تعديل تقوم بحفظه هنا ينعكس لحظياً على كافة تطبيقات الزبون والكابتن دون الحاجة لإعادة التحديث.',
                      style: TextStyle(color: AdminColors.textPrimary, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Referral Section
            _buildSectionCard(
              title: '🔗 نظام الإحالة والمشاركة (ادعُ واكسب)',
              subtitle: 'تحكم في عدد الإحالات المطلوبة لمنح الزبون توصيلاً مجانياً أو رصيد محفظة',
              isEnabled: _referralEnabled,
              onToggle: (val) => setState(() => _referralEnabled = val),
              children: [
                _buildInputField(
                  label: 'عدد الأشخاص المطلوب إحالتهم للحصول على المكافأة:',
                  controller: _referralTargetCountCtrl,
                  suffix: 'أشخاص (مثال: 3)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                // Reward Type Selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('نوع المكافأة عند اكتمال الإحالات:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AdminColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _referralRewardType,
                          dropdownColor: AdminColors.surfaceElevated,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'free_delivery', child: Text('كوبون توصيل مجاني 100% 🛵 (Free Delivery)')),
                            DropdownMenuItem(value: 'wallet_lyd', child: Text('رصيد نقدي في محفظة واصل 💰 (LYD Cash)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _referralRewardType = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_referralRewardType == 'wallet_lyd') ...[
                  const SizedBox(height: 10),
                  _buildInputField(
                    label: 'قيمة الرصيد النقدي للمحفظة (د.ل):',
                    controller: _referralRewardCtrl,
                    suffix: 'دينار ليبي',
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                _buildInputField(
                  label: 'مدة صلاحية كوبون التوصيل المجاني (بالأيام):',
                  controller: _referralValidityDaysCtrl,
                  suffix: 'يوماً (مثال: 14)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                // Qualification Condition
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('شرط احتساب الإحالة الناجحة:', style: TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AdminColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.divider),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _referralCondition,
                          dropdownColor: AdminColors.surfaceElevated,
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: const [
                            DropdownMenuItem(value: 'on_signup_otp', child: Text('فور تسجيل حساب جديد وتأكيد رقم الهاتف بالـ OTP ✅')),
                            DropdownMenuItem(value: 'on_first_order', child: Text('بعد أن يكمل الصديق أول طلب ناجح عبر التطبيق 📦')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _referralCondition = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (_referralCondition == 'on_first_order') ...[
                  const SizedBox(height: 10),
                  _buildInputField(
                    label: 'الحد الأدنى لقيمة أول طلب لتفعيل المكافأة:',
                    controller: _referralMinOrderCtrl,
                    suffix: 'دينار ليبي',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 2. Loyalty Points Section
            _buildSectionCard(
              title: '🎁 نظام نقاط الولاء والكاش باك',
              subtitle: 'منح نقاط مجانية للزبائن قابلة للاستبدال بخصم مباشر من الفاتورة',
              isEnabled: _loyaltyEnabled,
              onToggle: (val) => setState(() => _loyaltyEnabled = val),
              children: [
                _buildInputField(
                  label: 'نقاط الولاء لكل 1 د.ل ينفقه الزبون:',
                  controller: _loyaltyPointsPerLydCtrl,
                  suffix: 'نقطة',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  label: 'معدل الاستبدال (كم نقطة = 1 د.ل خصم):',
                  controller: _loyaltyRedemptionRateCtrl,
                  suffix: 'نقطة لكل 1 د.ل',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Captain Bonus Section
            _buildSectionCard(
              title: '🏆 نظام مهمات وحوافز الكباتن (بونص)',
              subtitle: 'تحديات ومكافآت لتشجيع كباتن نالوت على البقاء متصلين وزيادة الرحلات',
              isEnabled: _captainBonusEnabled,
              onToggle: (val) => setState(() => _captainBonusEnabled = val),
              children: [
                _buildInputField(
                  label: 'المستهدف اليومي للمشاوير:',
                  controller: _captainTargetCtrl,
                  suffix: 'رحلات / يوم',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  label: 'قيمة مكافأة البونص الإضافية:',
                  controller: _captainBonusLydCtrl,
                  suffix: 'دينار ليبي',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Ratings Section
            _buildSectionCard(
              title: '⭐ نظام التقييم المنصف المزدوج',
              subtitle: 'تقييم منفصل لجودة وجبة المطعم ولأداء الكابتن للطلبات المسلّمة',
              isEnabled: _ratingsEnabled,
              onToggle: (val) => setState(() => _ratingsEnabled = val),
              children: [
                OutlinedButton.icon(
                  onPressed: _showReviewsModal,
                  icon: const Icon(Icons.reviews, color: AdminColors.primaryGold, size: 18),
                  label: const Text(
                    'استعراض سجل تقييمات الزبائن المنصفة',
                    style: TextStyle(color: AdminColors.primaryGold, fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AdminColors.primaryGold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload, color: Colors.black),
                label: Text(
                  _isSaving ? 'جاري الحفظ والنشر في السحابة...' : 'حفظ ونشر التعديلات فوراً (Live Save)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primaryGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? AdminColors.primaryGold.withValues(alpha: 0.3) : AdminColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: onToggle,
                activeThumbColor: AdminColors.primaryGold,
              ),
            ],
          ),
          if (isEnabled) ...[
            const Divider(color: AdminColors.divider, height: 20),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AdminColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AdminColors.surfaceElevated,
            suffixText: suffix,
            suffixStyle: const TextStyle(color: AdminColors.primaryGold, fontSize: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AdminColors.primaryGold),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/referral_model.dart';
import '../services/referral_service.dart';
import '../design_system.dart';

/// ============================================================================
/// WASEL REFERRAL & FREE DELIVERY SCREEN (شارك واكسب توصيل مجاني)
/// ============================================================================

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  bool _isLoading = true;
  String _referralCode = 'WAS-7947';
  int _targetCount = 3;
  int _verifiedCount = 1;
  List<ReferralFriend> _friends = [];
  List<FreeDeliveryVoucher> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);
    final code = await ReferralService.getReferralCode();
    final rules = await ReferralService.getCampaignRules();
    final friends = await ReferralService.getInvitedFriends();
    final vouchers = await ReferralService.getActiveVouchers();

    final target = rules['target_count'] ?? 3;
    final verified = friends.where((f) => f.status != ReferralFriendStatus.alreadyRegistered).length;

    if (mounted) {
      setState(() {
        _referralCode = code;
        _targetCount = target;
        _friends = friends;
        _vouchers = vouchers;
        _verifiedCount = verified;
        _isLoading = false;
      });
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 تم نسخ كود الإحالة: $_referralCode'),
        backgroundColor: AppColors.waselPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareViaWhatsApp() async {
    final message = await ReferralService.getShareMessage();
    Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📲 تم نسخ رسالة الدعوة لرابط الواتساب! يمكنك مشاركتها مع أصدقائك في نالوت الآن.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showTestReferralDialog() {
    final phoneCtrl = TextEditingController(text: '0915554433');
    final nameCtrl = TextEditingController(text: 'خالد النالوتي');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.science_outlined, color: AppColors.waselPrimary),
            SizedBox(width: 8),
            Text('فحص واختبار رقم الصديق 🧪', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل رقم هاتف لتجربة محرك كشف الحسابات المسجلة مسبقاً مقابل الحسابات الجديدة:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'اسم الصديق',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف الليبي',
                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                hintText: '0912345678',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    onPressed: () {
                      phoneCtrl.text = '0912345678';
                      nameCtrl.text = 'علي الورفلي (مسجل مسبقاً)';
                    },
                    child: const Text('رقم قديم ⚠️', style: TextStyle(fontSize: 11)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                      side: const BorderSide(color: Colors.greenAccent),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    onPressed: () {
                      phoneCtrl.text = '093${DateTime.now().millisecondsSinceEpoch % 10000000}';
                      nameCtrl.text = 'محمد الجديد (جديد ✅)';
                    },
                    child: const Text('رقم جديد ✅', style: TextStyle(fontSize: 11)),
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
              backgroundColor: AppColors.waselPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ReferralService.evaluateAndAddReferral(
                friendName: nameCtrl.text.trim().isEmpty ? 'صديق نالوت' : nameCtrl.text.trim(),
                friendPhone: phoneCtrl.text.trim(),
              );

              await _loadReferralData();

              if (!mounted) return;
              showDialog(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  backgroundColor: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Icon(
                        result['is_already_registered'] == true
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: result['is_already_registered'] == true ? Colors.amber : Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        result['is_already_registered'] == true ? 'مستخدم مسجل مسبقاً' : 'إحالة جديدة ناجحة!',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  content: Text(
                    result['message'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.waselPrimary),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('حسناً فهمت', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            child: const Text('فحص واحتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.waselPrimary)),
      );
    }

    final currentCycleVerified = _verifiedCount % _targetCount;
    final remaining = _targetCount - currentCycleVerified;
    final progressVal = (_targetCount > 0) ? (currentCycleVerified / _targetCount) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('شارك واكسب توصيل مجاني 🛵🎁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Banner Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE23744), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE23744).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.celebration_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'توصيل مجاني 100% لباب بيتك!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ادعُ أصدقاءك في نالوت لتجربة واصل. لكل $_targetCount أصدقاء جدد يسجلون، تحصل على كوبون توصيل مجاني فورياً!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.waselPrimary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, color: AppColors.waselPrimary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'تقدم الدعوات: $currentCycleVerified من $_targetCount أصدقاء',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.waselPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(progressVal * 100).toInt()}%',
                          style: const TextStyle(color: AppColors.waselPrimary, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressVal,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.waselPrimary),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    remaining == 0
                        ? '🎉 مبروك! فزت بكوبون التوصيل المجاني!'
                        : (remaining == 1
                            ? 'باقي صديق واحد فقط لكسب كوبون التوصيل المجاني! 🚀'
                            : 'باقي $remaining أصدقاء للحصول على كوبون التوصيل المجاني 🛵'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: remaining <= 1 ? Colors.amberAccent : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Personal Code Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text(
                    'كود الإحالة الخاص بك',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _referralCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            letterSpacing: 2,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.waselPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                          tooltip: 'نسخ الكود',
                          onPressed: _copyReferralCode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('مشاركة عبر الواتساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: _shareViaWhatsApp,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.purple.withValues(alpha: 0.2),
                          foregroundColor: Colors.purpleAccent,
                        ),
                        icon: const Icon(Icons.science_outlined),
                        tooltip: 'اختبار فحص رقم',
                        onPressed: _showTestReferralDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Anti-Fraud Policy Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'نظام التحقق الذكي: تُحتسب الإحالة للأرقام والحسابات الجديدة فقط. الأرقام المسجلة مسبقاً لا تُحتسب منعاً للتكرار والتحايل.',
                      style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Vouchers Section
            if (_vouchers.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.confirmation_number_rounded, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'كوبونات التوصيل المجاني الجاهزة للاستخدام (${_vouchers.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._vouchers.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.electric_moped_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  'كود: ${v.code} • صالح حتى ${v.expiresAt.day}/${v.expiresAt.month}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'خصم 100% توصيل',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],

            // Invited Friends List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'سجل الأصدقاء المدعوين (${_friends.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_friends.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لم تقم بدعوة أصدقاء بعد. شارك كودك الآن واكسب توصيل مجاني!', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              )
            else
              ..._friends.map((f) {
                final isAlready = f.status == ReferralFriendStatus.alreadyRegistered;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isAlready ? Colors.amber.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAlready ? Icons.person_off_rounded : Icons.person_add_alt_1_rounded,
                            color: isAlready ? Colors.amber : Colors.greenAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                f.phone,
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAlready ? Colors.amber.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isAlready ? Colors.amber.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          isAlready ? 'مسجل مسبقاً ⚠️ (لم يُحتسب)' : 'مستخدم جديد ✅ (محتسب)',
                          style: TextStyle(
                            color: isAlready ? Colors.amber : Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

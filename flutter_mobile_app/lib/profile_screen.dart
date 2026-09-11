import 'package:flutter/material.dart';
import 'design_system.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const ProfileScreen({
    super.key,
    this.onToggleTheme,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي والإعدادات'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. USER PROFILE CARD
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.radiusXl,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.waselPrimary, AppColors.waselPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadius.radiusLg,
                  ),
                  child: const Center(
                    child: Text(
                      'خ',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'خليفة محمد',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.verified_rounded, color: AppColors.info, size: 18),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '+218 91 234 5678',
                        style: TextStyle(fontSize: 12, color: AppColors.darkTextSecondary, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.waselPrimary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: const Text(
                          'عميل واصل VIP الذهبي ⭐',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.waselPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 2. SAVED ADDRESSES
          const Text(
            'العناوين المحفوظة في نالوت',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingsTile(
            icon: Icons.home_rounded,
            title: 'المنزل',
            subtitle: 'نالوت - حي الشهداء، بالقرب من قصر نالوت الأثري',
            isDark: isDark,
            trailing: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
          ),
          _buildSettingsTile(
            icon: Icons.work_rounded,
            title: 'العمل / المتجر',
            subtitle: 'نالوت - وسط المدينة، طريق وازن الرئيسي',
            isDark: isDark,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 3. APP PREFERENCES
          const Text(
            'تفضيلات التطبيق',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('الوضع الداكن (Dark Mode)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('راحة العين وتوفير طاقة البطارية', style: TextStyle(fontSize: 11)),
                  value: isDark,
                  onChanged: (_) => onToggleTheme?.call(),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('اللغة (Language)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('العربية (Arabic)', style: TextStyle(fontSize: 11)),
                  leading: const Icon(Icons.language_rounded, color: AppColors.info),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('إشعارات التتبع الفوري', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('تنبيه عند اقتراب الكابتن من باب منزلك', style: TextStyle(fontSize: 11)),
                  value: true,
                  onChanged: (val) {},
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // 4. SUPPORT & LEGAL
          const Text(
            'الدعم والمساعدة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSettingsTile(
            icon: Icons.headset_mic_rounded,
            title: 'خدمة العملاء المباشرة (24/7)',
            subtitle: 'محادثة فورية مع فريق دعم واصل',
            isDark: isDark,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري توصيلك بممثل خدمة العملاء...')),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: 'شروط الاستخدام والخصوصية',
            subtitle: 'سياسة حماية البيانات والضمان المالي',
            isDark: isDark,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 5. LOGOUT BUTTON
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: const Text('تسجيل الخروج من الحساب', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
            ),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text(
              'تطبيق واصل نالوت الموحد v1.0.0 (إصدار 2026)',
              style: TextStyle(fontSize: 10, color: AppColors.darkTextSecondary),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.waselPrimary),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
        trailing: trailing ?? const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    );
  }
}

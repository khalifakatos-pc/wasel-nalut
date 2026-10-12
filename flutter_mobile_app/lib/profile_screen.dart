import 'package:flutter/material.dart';
import 'design_system.dart';
import 'services/api_service.dart';
import 'login_screen.dart';
import 'satellite_location_picker.dart';
import 'address_management_sheet.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final bool isGuest = ApiService.isGuest;
    final String displayName = isGuest ? 'حساب زائر (Guest)' : (ApiService.userName.isNotEmpty ? ApiService.userName : 'خليفة محمد');
    final String displayPhone = isGuest ? 'تصفح بدون تسجيل دخول' : (ApiService.userPhone.isNotEmpty ? ApiService.userPhone : '+218 91 234 5678');

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
              color: colorScheme.surface,
              borderRadius: AppRadius.radiusXl,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isGuest
                              ? [Colors.blueGrey.shade700, Colors.blueGrey.shade900]
                              : [AppColors.waselPrimary, AppColors.waselPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppRadius.radiusLg,
                      ),
                      child: Center(
                        child: Icon(
                          isGuest ? Icons.person_outline_rounded : Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                isGuest ? Icons.explore_rounded : Icons.verified_rounded,
                                color: isGuest ? AppColors.waselPrimary : AppColors.info,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayPhone,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isGuest ? AppColors.jetPrimary : AppColors.waselPrimary).withValues(alpha: 0.15),
                              borderRadius: AppRadius.radiusSm,
                            ),
                            child: Text(
                              isGuest ? 'وضع الاستكشاف والتصفح 🧭' : 'عميل واصل VIP الذهبي ⭐',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isGuest ? AppColors.jetPrimary : AppColors.waselPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isGuest) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(
                              onToggleTheme: onToggleTheme,
                              isDark: isDark,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('تسجيل الدخول / ربط رقم الهاتف 📱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.waselPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                      ),
                    ),
                  ),
                ],
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
            icon: Icons.location_on_rounded,
            title: 'إدارة العناوين وأماكن التوصيل',
            subtitle: 'عرض واختيار وحذف العناوين المحفوظة في نالوت',
            trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.waselPrimary),
            onTap: () {
              AddressManagementSheet.show(context);
            },
          ),
          _buildSettingsTile(
            icon: Icons.satellite_alt_rounded,
            title: 'تحديد موقع جديد بالقمر الصناعي 🛰️',
            subtitle: 'تثبيت إحداثيات GPS دقيقة لحوشك أو استراحتك',
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.waselPrimary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SatelliteLocationPicker()),
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          // 3. APP PREFERENCES
          const Text(
            'تفضيلات التطبيق',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),

          Material(
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusLg,
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
          ),

          const SizedBox(height: AppSpacing.lg),

          // 5. LOGOUT BUTTON
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            label: Text(
              isGuest ? 'إنهاء وضع الزائر والعودة للتسجيل' : 'تسجيل الخروج من الحساب',
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: Text(
              'تطبيق واصل نالوت الموحد v1.0.0 (إصدار 2026)',
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: Text(
          ApiService.isGuest
              ? 'هل ترغب في إنهاء جلسة التصفح كزائر والعودة لشاشة تسجيل الدخول؟'
              : 'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('تأكيد الخروج'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await ApiService.clearToken();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onToggleTheme: onToggleTheme,
            isDark: isDark,
          ),
        ),
        (route) => false,
      );
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusLg,
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Icon(icon, color: AppColors.waselPrimary),
            title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
            trailing: trailing ?? const Icon(Icons.chevron_left_rounded),
            onTap: onTap,
          ),
        ),
      );
    });
  }
}

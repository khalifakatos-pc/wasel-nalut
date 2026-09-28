import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'design_system.dart';
import 'otp_verification_screen.dart';
import 'services/whatsapp_auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/api_service.dart';
import 'main.dart';

/// Login screen with Libyan phone number input (+218) for Wasel Nalut.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDark;

  const LoginScreen({
    super.key,
    this.onToggleTheme,
    this.isDark = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCarrier = 'ليبيانا (092/094)';

  final List<String> _carriers = ['ليبيانا (092/094)', 'المدار (091/093)'];

  bool get _isValidPhone {
    final phone = _phoneController.text.trim();
    if (phone.length != 9) return false;
    // Libyan mobile numbers: Madar: 91, 93 | Libyana: 92, 94
    final prefix = phone.substring(0, 2);
    return ['91', '92', '93', '94'].contains(prefix);
  }

  String get _fullPhoneNumber => '+218${_phoneController.text.trim()}';

  Future<void> _sendSmsOtp() async {
    if (!_isValidPhone) {
      setState(() => _errorMessage = 'أدخل رقم ليبي صالح (9 أرقام يبدأ بـ 092/094 ليبيانا أو 091/093 المدار)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final normalized = FirebaseAuthService.normalizeLibyanPhone(_phoneController.text.trim());

    await FirebaseAuthService.sendSmsOtp(
      phone: normalized,
      onCodeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phoneNumber: normalized,
              displayPhone: '0${_phoneController.text.trim()}',
              initialMethod: AuthMethod.sms,
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          ),
        );
      },
      onError: (errMsg, isQuotaOrNetwork) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = errMsg;
        });

        if (isQuotaOrNetwork) {
          _showQuotaFallbackDialog();
        }
      },
      onAutoVerify: (credential) async {
        if (!mounted) return;
        try {
          final userCred = await FirebaseAuthService.verifySmsCode(
            verificationId: '',
            smsCode: credential.smsCode ?? '',
          );
          final uid = userCred.user?.uid ?? 'firebase-user';
          await ApiService.saveToken(
            'wasel-firebase-token-$uid',
            phone: normalized,
            name: 'زبون واصل نالوت',
          );
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => MainNavigationShell(
                onToggleTheme: widget.onToggleTheme ?? () {},
                isDark: widget.isDark,
              ),
            ),
            (route) => false,
          );
        } catch (_) {}
      },
    );
  }

  void _showQuotaFallbackDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF25D366)),
              SizedBox(width: 8),
              Text('المتابعة عبر واتساب', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: const Text(
            'تعذر إرسال رسالة SMS حالياً (قد يكون بسبب اكتمال حد الرسائل المجاني أو تأخر الشبكة المحلية). يمكنك تسجيل الدخول فوراً وبأمان عبر واتساب.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _sendWhatsAppOtp();
              },
              icon: const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              label: const Text('دخول عبر واتساب الآن', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppOtp() async {
    if (!_isValidPhone) {
      setState(() => _errorMessage = 'أدخل رقم ليبي صالح (9 أرقام يبدأ بـ 092/094 ليبيانا أو 091/093 المدار)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final otp = await WhatsAppAuthService.requestWhatsAppOtp(_fullPhoneNumber);

    if (!mounted) return;

    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phoneNumber: _fullPhoneNumber,
          displayPhone: '0${_phoneController.text.trim()}',
          initialMethod: AuthMethod.whatsapp,
          generatedOtp: otp,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Mini logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.waselGradient,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Center(
                        child: Text(
                          'و',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'واصل | WASEL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'نالوت والجبل الغربي',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Header
                const Text(
                  'مرحباً بك 👋',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أدخل رقم هاتفك لتسجيل الدخول في واصل',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white54,
                  ),
                ),

                const SizedBox(height: 36),

                // Carrier selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: AppRadius.radiusLg,
                  ),
                  child: Row(
                    children: _carriers.map((carrier) {
                      final isSelected = _selectedCarrier == carrier;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _selectedCarrier = carrier),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.waselPrimary
                                  : Colors.transparent,
                              borderRadius: AppRadius.radiusMd,
                            ),
                            child: Center(
                              child: Text(
                                carrier,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),

                // Phone input
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(
                      color: _errorMessage != null
                          ? AppColors.error
                          : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Country code
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🇱🇾',
                              style: TextStyle(fontSize: 20),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '+218',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Phone number field
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 9,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            hintText: '91XXXXXXX',
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) =>
                              setState(() => _errorMessage = null),
                        ),
                      ),
                    ],
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.waselPrimary, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'تحقق فوري عبر رسائل SMS مع دعم تسجيل الدخول عبر واتساب',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Primary Button: Send SMS OTP via Firebase
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendSmsOtp,
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.sms_rounded, color: Colors.white, size: 22),
                    label: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'تسجيل الدخول عبر رسالة SMS ⚡',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.waselPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.waselPrimary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusLg,
                      ),
                      elevation: 4,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Secondary Button: WhatsApp OTP
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _sendWhatsAppOtp,
                    icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                    label: const Text(
                      'الدخول السريع عبر واتساب (WhatsApp) 💬',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                      side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusLg,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Guest Login Button
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () async {
                      await ApiService.setGuestMode(true);
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MainNavigationShell(
                            onToggleTheme: widget.onToggleTheme ?? () {},
                            isDark: widget.isDark,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusLg,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_rounded, size: 18, color: AppColors.jetPrimary),
                        SizedBox(width: 8),
                        Text(
                          'تخطي والدخول المباشر كزائر 🚀',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Terms
                const Text(
                  'بالمتابعة، أنت توافق على شروط وأحكام تطبيق واصل\nوسياسة الخصوصية المعمول بها في ليبيا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

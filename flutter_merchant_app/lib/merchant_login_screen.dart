import 'dart:async';
import 'package:wasel_ui/wasel_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'services/merchant_supabase_service.dart';

/// ============================================================================
/// WASEL MERCHANT & KITCHEN LOGIN SCREEN (Google Stitch Modern Light Redesign)
/// ============================================================================
/// Secure phone/PIN authentication for store managers & kitchen operators.
/// Issues verified JWT tokens with strict tenant isolation.
/// ============================================================================

class MerchantLoginScreen extends StatefulWidget {
  final Function(MerchantUser user, PartnerStore store) onLoginSuccess;

  const MerchantLoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }


  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم هاتف المتجر');
      return;
    }

    if (pin.isEmpty || pin.length < 4) {
      setState(() => _errorMessage = 'رمز PIN يجب أن يتكون من 4 أرقام على الأقل');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await MerchantSupabaseService.authenticateMerchant(phone, pin);

      if (user != null) {
        PartnerStore store;
        if (MerchantSupabaseService.activeDynamicStore != null &&
            MerchantSupabaseService.activeDynamicStore!.id == user.storeId) {
          store = MerchantSupabaseService.activeDynamicStore!;
        } else {
          store = PartnerStore.nalutStores.firstWhere(
            (s) => s.id == user.storeId,
            orElse: () => PartnerStore(
              id: user.storeId,
              name: user.name,
              nameEn: '',
              type: 'restaurant',
              district: 'نالوت',
              phone: user.phone,
              mode: PartnerAppMode.kitchen,
              icon: Icons.storefront_rounded,
            ),
          );
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('wasel_merchant_logged_in', true);
        await prefs.setString('wasel_active_store_id', store.id);
        await prefs.setString('wasel_active_store_name', store.name);
        await prefs.setString('wasel_active_store_type', store.type);
        await prefs.setString('wasel_active_store_district', store.district);
        await prefs.setString('wasel_active_store_mode', store.mode == PartnerAppMode.retail ? 'retail' : 'kitchen');
        await prefs.setString('wasel_merchant_user_phone', user.phone);
        await prefs.setString('wasel_merchant_user_name', user.name);
        await prefs.setString('wasel_merchant_user_role', user.role);

        MerchantSupabaseService.currentStoreId = store.id;
        MerchantSupabaseService.currentUser = user;

        if (mounted) {
          widget.onLoginSuccess(user, store);
        }
      } else {
        setState(() {
          _errorMessage = 'رقم الهاتف أو رمز PIN غير صحيح. يرجى التأكد وإعادة المحاولة.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'تعذر الاتصال بالخادم. تأكد من اتصال الإنترنت.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  static const Color _telegramBlue = Color(0xFF0088CC);

  Future<void> _handleTelegramLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم هاتف المتجر أولاً');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await TelegramAuthService.requestOtp(
        phone: phone,
        role: WaselUserRole.merchant,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!res.success) {
        setState(() {
          _errorMessage = res.errorMessage ?? 'فشل طلب رمز تيليجرام.';
        });
        return;
      }

      _showTelegramOtpDialog(phone, res);
      if (res.needsBotTap) {
        TelegramAuthService.openTelegramBot(
          customNativeUri: res.nativeUri,
          customWebUrl: res.deeplinkUrl,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل طلب رمز تيليجرام: $e';
      });
    }
  }

  void _showTelegramOtpDialog(String phone, TelegramOtpResult otpRes) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;
    Timer? pollTimer;
    bool pollStarted = false;
    bool completed = false;

    Future<void> completeVerifiedMerchant(
      BuildContext ctx,
      StateSetter setSheetState,
      TelegramVerifyResult verifyRes,
    ) async {
      if (completed) return;
      completed = true;
      pollTimer?.cancel();
      final user = await MerchantSupabaseService.authenticateMerchantWithVerifiedPhone(
        phone,
        token: verifyRes.token,
        storeData: verifyRes.storeData,
      );
      if (!mounted) return;
      if (user != null) {
        if (ctx.mounted) Navigator.pop(ctx);
        final store = MerchantSupabaseService.activeDynamicStore ?? PartnerStore.nalutStores.first;
        widget.onLoginSuccess(user, store);
      } else {
        completed = false;
        setSheetState(() {
          isVerifying = false;
          dialogError = 'تعذر تحميل بيانات المتجر المسجل.';
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (!pollStarted && otpRes.sessionId != null && otpRes.sessionId!.isNotEmpty) {
            pollStarted = true;
            pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
              if (completed || !ctx.mounted) {
                pollTimer?.cancel();
                return;
              }
              final pollRes = await TelegramAuthService.checkSessionStatus(
                sessionId: otpRes.sessionId!,
              );
              if (!ctx.mounted || completed) return;
              if (pollRes.expired) {
                pollTimer?.cancel();
                setSheetState(() => dialogError = 'انتهت صلاحية الجلسة. أعد المحاولة.');
                return;
              }
              if (pollRes.verified) {
                await completeVerifiedMerchant(ctx, setSheetState, pollRes);
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.send_rounded, color: _telegramBlue, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'تأكيد الدخول عبر تيليجرام ✈️',
                          style: TextStyle(color: MerchantColors.lightTextPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () {
                        pollTimer?.cancel();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  otpRes.needsBotTap
                      ? 'افتح بوت @WaselNalutbot وشارك رقمك ($phone) بنقرة واحدة للتسجيل التلقائي، أو أدخل الرمز (4 أرقام):'
                      : 'أدخل رمز التحقق (4 أرقام) المرسل في تيليجرام لرقم المتجر: $phone',
                  style: const TextStyle(color: MerchantColors.lightTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  maxLength: 4,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: const TextStyle(color: Colors.black26, letterSpacing: 8),
                    filled: true,
                    fillColor: MerchantColors.lightBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _telegramBlue),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      final entered = otpController.text.trim();
                      if (entered.length != 4) {
                        setSheetState(() => dialogError = 'أدخل رمز التحقق المكون من 4 أرقام');
                        return;
                      }

                      setSheetState(() {
                        isVerifying = true;
                        dialogError = null;
                      });

                      final verifiedRes = await TelegramAuthService.verifyOtp(
                        phone: phone,
                        enteredOtp: entered,
                        role: WaselUserRole.merchant,
                      );

                      if (!ctx.mounted) return;
                      if (verifiedRes.success && verifiedRes.verified) {
                        await completeVerifiedMerchant(ctx, setSheetState, verifiedRes);
                      } else {
                        setSheetState(() {
                          isVerifying = false;
                          dialogError = verifiedRes.errorMessage ?? 'رمز التحقق غير صحيح أو انتهت صلاحيته.';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _telegramBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isVerifying
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('تأكيد الدخول لإدارة المتجر 🏪', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    TelegramAuthService.openTelegramBot(
                      customNativeUri: otpRes.nativeUri,
                      customWebUrl: otpRes.deeplinkUrl,
                    );
                  },
                  icon: const Icon(Icons.send_rounded, color: _telegramBlue, size: 18),
                  label: const Text('فتح بوت واصل في تيليجرام للتأكيد الفوري ✈️', style: TextStyle(color: Colors.black87, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _telegramBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      pollTimer?.cancel();
      otpController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MerchantColors.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo & Title (Google Stitch Clean)
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: MerchantColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: MerchantColors.primary.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'شريك واصل | نالوت',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: MerchantColors.lightTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'منظومة إدارة الطلبات والمطبخ والجرد المستقل',
                      style: TextStyle(
                        fontSize: 13,
                        color: MerchantColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: MerchantColors.rejectedRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MerchantColors.rejectedRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: MerchantColors.rejectedRed,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: MerchantColors.rejectedRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],


                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: MerchantColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MerchantColors.lightBorder),
                      boxShadow: MerchantShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تسجيل الدخول للمتجر',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: MerchantColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'أدخل بيانات الدخول المعتمدة لمتجرك في نالوت',
                          style: TextStyle(
                            fontSize: 12,
                            color: MerchantColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),


                        // Phone Field
                        const Text(
                          'رقم هاتف المتجر / المسؤول',
                          style: TextStyle(fontSize: 12, color: MerchantColors.lightTextSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: MerchantColors.lightTextPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '091XXXXXXX',
                            hintStyle: const TextStyle(color: MerchantColors.lightTextMuted),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🇱🇾', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 6),
                                  Text(
                                    '+218',
                                    style: TextStyle(color: MerchantColors.lightTextSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: MerchantColors.lightBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: MerchantColors.lightBorder),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // PIN Field
                        const Text(
                          'رمز الدخول السري (PIN)',
                          style: TextStyle(fontSize: 12, color: MerchantColors.lightTextSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscurePin,
                          maxLength: 6,
                          style: const TextStyle(
                            color: MerchantColors.lightTextPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            hintStyle: const TextStyle(
                              color: MerchantColors.lightTextMuted,
                              letterSpacing: 4,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: MerchantColors.lightTextMuted,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: MerchantColors.lightTextMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: MerchantColors.lightBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: MerchantColors.lightBorder),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MerchantColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'دخول المتجر والمطبخ',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleTelegramLogin,
                            icon: const Icon(Icons.send_rounded, color: _telegramBlue, size: 18),
                            label: const Text(
                              'الدخول أو استعادة PIN عبر تيليجرام ✈️',
                              style: TextStyle(
                                color: _telegramBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _telegramBlue),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

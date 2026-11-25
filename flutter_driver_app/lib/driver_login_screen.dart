import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wasel_ui/wasel_ui.dart';
import 'driver_theme.dart';
import 'services/driver_supabase_service.dart';

/// ============================================================================
/// CAPTAIN WASEL (كابتن واصل نالوت) AUTHENTICATION & REGISTRATION SCREEN
/// ============================================================================
/// Secures the driver application behind phone number and PIN authentication,
/// with fast Telegram Bot (@WaselNalutbot) 1-tap / OTP verification and
/// direct operations room registration & support.
/// ============================================================================

class DriverLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const DriverLoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  int _activeTab = 0; // 0: Login, 1: Register New Captain / Contact Ops

  // Login controllers
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  // Registration controllers
  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regNotesController = TextEditingController();
  String _regVehicle = 'سيارة';

  bool _isLoading = false;
  bool _isRegistering = false;
  bool _obscurePin = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regNotesController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // LOGIN ACTIONS
  // --------------------------------------------------------------------------
  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم هاتف الكابتن');
      return;
    }

    if (pin.isEmpty || pin.length < 4) {
      setState(() => _errorMessage = 'رمز PIN يجب أن يتكون من 4 أرقام على الأقل');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final success = await DriverSupabaseService.authenticateCaptain(phone, pin);

      if (success) {
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'رقم الهاتف أو رمز PIN غير صحيح، أو أن الحساب غير مسجل في أسطول نالوت.\nإذا كنت كابتناً جديداً يمكنك طلب الانضمام أو مراسلة الإدارة عبر الخانة أعلاه.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال بالخادم. يرجى المحاولة مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  static const Color _telegramBlue = Color(0xFF0088CC);

  Future<void> _completeTelegramCaptainLogin(
    String phone,
    TelegramVerifyResult verifyRes,
  ) async {
    final user = verifyRes.userData ?? <String, dynamic>{};
    final driverInfo = verifyRes.driverData ?? <String, dynamic>{};
    final normalizedPhone = DriverSupabaseService.normalizePhone(phone);
    final driverId = driverInfo['id']?.toString() ??
        user['id']?.toString() ??
        'driver_$normalizedPhone';
    final driverName = user['full_name']?.toString() ??
        driverInfo['full_name']?.toString() ??
        'كابتن واصل نالوت';
    final vehicle = driverInfo['vehicle_type']?.toString() ?? 'سيارة';
    final plate = driverInfo['vehicle_plate']?.toString() ??
        driverInfo['plate_number']?.toString() ??
        'نالوت';
    final token = verifyRes.token ??
        'captain-tg-token-${DateTime.now().millisecondsSinceEpoch}';

    await DriverSupabaseService.persistExternalCaptainSession(
      id: driverId,
      name: driverName,
      phone: normalizedPhone,
      vehicle: vehicle,
      plate: plate,
      token: token,
    );
  }

  Future<void> _handleTelegramLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم هاتف الكابتن أولاً للتحقق عبر تيليجرام');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await TelegramAuthService.requestOtp(
        phone: phone,
        role: WaselUserRole.captain,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!res.success) {
        setState(() {
          _errorMessage = res.errorMessage ?? 'فشل طلب التحقق عبر تيليجرام.';
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
        _errorMessage = 'فشل طلب التحقق عبر تيليجرام: $e';
      });
    }
  }

  // --------------------------------------------------------------------------
  // REGISTRATION & OPS MESSAGING ACTIONS
  // --------------------------------------------------------------------------
  Future<void> _handleRegisterCaptain() async {
    final name = _regNameController.text.trim();
    final phone = _regPhoneController.text.trim();
    final notes = _regNotesController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال اسم الكابتن بالكامل (ثلاثي)');
      return;
    }

    if (phone.isEmpty || phone.length < 8) {
      setState(() => _errorMessage = 'يرجى إدخال رقم هاتف صحيح للتواصل');
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    final appRes = await TelegramAuthService.submitCaptainApplication(
      fullName: name,
      phone: phone,
      vehicleType: _regVehicle,
      notes: notes,
    );

    await TelegramAuthService.openTelegramBot(
      customWebUrl: appRes['bot_url']?.toString(),
      startPayload: 'captain_register',
    );

    if (mounted) {
      setState(() {
        _isRegistering = false;
        _successMessage = 'تم إرسال طلب الانضمام لإدارة العمليات عبر تيليجرام بنجاح!';
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DriverColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: DriverColors.onlineGreen),
              SizedBox(width: 8),
              Text('تم إرسال طلب الانضمام 🚀', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: const Text(
            'تم تسجيل طلبك وإشعار إدارة عمليات واصل نالوت، وفتح بوت تيليجرام الرسمي (@WaselNalutbot) لاستكمال اعتمادك وتزويدك برمز الدخول (PIN).',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _activeTab = 0);
              },
              child: const Text('العودة لتسجيل الدخول 🔑', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleDirectContactAdmin() async {
    await TelegramAuthService.openAdminSupportChat(startPayload: 'captain_register');
  }

  void _showTelegramOtpDialog(String phone, TelegramOtpResult otpRes) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;
    Timer? pollTimer;
    bool pollStarted = false;
    bool completed = false;

    Future<void> finishCaptainSignIn(
      BuildContext ctx,
      TelegramVerifyResult verifyRes,
    ) async {
      if (completed) return;
      completed = true;
      pollTimer?.cancel();
      await _completeTelegramCaptainLogin(phone, verifyRes);
      if (!mounted) return;
      if (ctx.mounted) {
        Navigator.pop(ctx);
      }
      widget.onLoginSuccess();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DriverColors.darkCard,
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
                await finishCaptainSignIn(ctx, pollRes);
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
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
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
                      ? 'افتح بوت @WaselNalutbot وشارك رقمك ($phone) بنقرة واحدة للدخول التلقائي، أو أدخل الرمز (4 أرقام):'
                      : 'أدخل رمز التحقق (4 أرقام) الذي تم إرساله في تيليجرام إلى رقمك: $phone',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  maxLength: 4,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                    filled: true,
                    fillColor: DriverColors.darkBg,
                    border: OutlineInputBorder(
                      borderRadius: DriverRadius.radiusMd,
                      borderSide: const BorderSide(color: _telegramBlue),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: DriverColors.urgentRed, fontSize: 12), textAlign: TextAlign.center),
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

                      final verifyRes = await TelegramAuthService.verifyOtp(
                        phone: phone,
                        enteredOtp: entered,
                        role: WaselUserRole.captain,
                      );

                      if (!ctx.mounted) return;
                      if (verifyRes.success && verifyRes.verified) {
                        await finishCaptainSignIn(ctx, verifyRes);
                      } else {
                        setSheetState(() {
                          isVerifying = false;
                          dialogError = verifyRes.errorMessage ?? 'رمز التحقق غير صحيح أو انتهت صلاحيته';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _telegramBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                    ),
                    child: isVerifying
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('تأكيد الدخول وبدء الوردية 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  label: const Text('فتح بوت واصل في تيليجرام للتأكيد الفوري ✈️', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _telegramBlue),
                    shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
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
      backgroundColor: DriverColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Logo & Branding
                Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: DriverColors.darkCard,
                      shape: BoxShape.circle,
                      border: Border.all(color: DriverColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: DriverColors.primary.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: DriverColors.primary,
                      size: 46,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'كابتن واصل | نالوت',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'بوابة كباتن التوصيل والأسطول الميداني المعتمد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: DriverColors.darkTextMuted,
                  ),
                ),
                const SizedBox(height: 22),

                // Top Mode Toggle Tabs (Login vs Register/Contact)
                Container(
                  decoration: BoxDecoration(
                    color: DriverColors.darkCardElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DriverColors.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _activeTab = 0;
                            _errorMessage = null;
                            _successMessage = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _activeTab == 0 ? DriverColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_open_rounded,
                                  size: 16,
                                  color: _activeTab == 0 ? Colors.black : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    color: _activeTab == 0 ? Colors.black : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _activeTab = 1;
                            _errorMessage = null;
                            _successMessage = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _activeTab == 1 ? DriverColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 16,
                                  color: _activeTab == 1 ? Colors.black : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'انضمام كابتن جديد',
                                  style: TextStyle(
                                    color: _activeTab == 1 ? Colors.black : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Error Message Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DriverColors.urgentRed.withValues(alpha: 0.15),
                      borderRadius: DriverRadius.radiusMd,
                      border: Border.all(color: DriverColors.urgentRed.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: DriverColors.urgentRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Success Message Banner
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                      borderRadius: DriverRadius.radiusMd,
                      border: Border.all(color: DriverColors.onlineGreen.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: DriverColors.onlineGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Active View Card
                _activeTab == 0 ? _buildLoginCard() : _buildRegistrationCard(),

                const SizedBox(height: 24),

                // Operational Support Note
                const Center(
                  child: Text(
                    '🔒 تطبيق أسطول كباتن واصل نالوت المعتمد\nللتسجيل المباشر والدعم الفني: إدارة العمليات +218 91-8207786',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white38, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 0: LOGIN CARD
  // --------------------------------------------------------------------------
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DriverColors.darkSurface,
        borderRadius: DriverRadius.radiusXl,
        border: Border.all(color: DriverColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone Number Input
          const Text(
            'رقم هاتف الكابتن',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0912345678',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.phone_android_rounded, color: DriverColors.primary),
              filled: true,
              fillColor: DriverColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: DriverRadius.radiusMd,
                borderSide: const BorderSide(color: DriverColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: DriverRadius.radiusMd,
                borderSide: const BorderSide(color: DriverColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: DriverRadius.radiusMd,
                borderSide: const BorderSide(color: DriverColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // PIN Input
          const Text(
            'رمز الدخول السري (PIN)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _pinController,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 3),
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 3),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: DriverColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
              filled: true,
              fillColor: DriverColors.darkCard,
              border: OutlineInputBorder(
                borderRadius: DriverRadius.radiusMd,
                borderSide: const BorderSide(color: DriverColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: DriverRadius.radiusMd,
                borderSide: const BorderSide(color: DriverColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: DriverRadius.radiusMd,
                borderSide: const BorderSide(color: DriverColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverColors.primary,
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : const Text(
                      'تسجيل الدخول وبدء الوردية 🛵',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Telegram Fast OTP Login Option
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleTelegramLogin,
              icon: const Icon(Icons.send_rounded, color: _telegramBlue, size: 18),
              label: const Text(
                'الدخول السريع عبر تيليجرام ✈️',
                style: TextStyle(
                  color: _telegramBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _telegramBlue),
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Divider(color: DriverColors.darkBorder),
          const SizedBox(height: 12),

          // Direct Telegram Messaging with Ops
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleDirectContactAdmin,
              icon: const Icon(Icons.support_agent_rounded, color: Colors.white70, size: 18),
              label: const Text(
                'مراسلة الإدارة عبر تيليجرام للتسجيل ✈️',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: DriverColors.darkBorder),
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Switch to Registration Tab Link
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _activeTab = 1;
                _errorMessage = null;
                _successMessage = null;
              }),
              child: const Text(
                'كابتن جديد لأول مرة؟ اضغط لتقديم طلب انضمام 📝',
                style: TextStyle(color: DriverColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: NEW CAPTAIN REGISTRATION CARD
  // --------------------------------------------------------------------------
  Widget _buildRegistrationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DriverColors.darkSurface,
        borderRadius: DriverRadius.radiusXl,
        border: Border.all(color: DriverColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DriverColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.badge_rounded, color: DriverColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب انضمام لأسطول كباتن نالوت 🛵',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'سجل بياناتك ومراسلة الإدارة لتفعيل حسابك فوراً',
                      style: TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Full Name Input
          const Text(
            'اسم الكابتن الثلاثي',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regNameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'مثال: محمد علي الباروني',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: DriverColors.primary),
              filled: true,
              fillColor: DriverColors.darkCard,
              border: OutlineInputBorder(borderRadius: DriverRadius.radiusMd),
            ),
          ),
          const SizedBox(height: 16),

          // Phone Number Input
          const Text(
            'رقم الهاتف (تيليجرام والتواصل)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0912345678',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.phone_android_rounded, color: DriverColors.primary),
              filled: true,
              fillColor: DriverColors.darkCard,
              border: OutlineInputBorder(borderRadius: DriverRadius.radiusMd),
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle Type Selection
          const Text(
            'نوع وسيلة النقل',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('سيارة 🚗'),
                    ],
                  ),
                  selected: _regVehicle == 'سيارة',
                  selectedColor: DriverColors.primary,
                  backgroundColor: DriverColors.darkCard,
                  labelStyle: TextStyle(
                    color: _regVehicle == 'سيارة' ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _regVehicle = 'سيارة');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.two_wheeler_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('دراجة نارية 🏍️'),
                    ],
                  ),
                  selected: _regVehicle == 'دراجة نارية',
                  selectedColor: DriverColors.primary,
                  backgroundColor: DriverColors.darkCard,
                  labelStyle: TextStyle(
                    color: _regVehicle == 'دراجة نارية' ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _regVehicle = 'دراجة نارية');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes / National ID / Region
          const Text(
            'المنطقة السكنية أو ملاحظات (اختياري)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _regNotesController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'مثال: نالوت - المركز، متفرغ للعمل المسائي',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: const Icon(Icons.location_on_outlined, color: DriverColors.primary),
              filled: true,
              fillColor: DriverColors.darkCard,
              border: OutlineInputBorder(borderRadius: DriverRadius.radiusMd),
            ),
          ),
          const SizedBox(height: 22),

          // Submit Application via Telegram Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isRegistering ? null : _handleRegisterCaptain,
              icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
              label: _isRegistering
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                    )
                  : const Text(
                      'إرسال طلب الانضمام عبر تيليجرام 🚀',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverColors.primary,
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Direct Telegram Chat with Admin Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _handleDirectContactAdmin,
              icon: const Icon(Icons.send_rounded, color: _telegramBlue, size: 18),
              label: const Text(
                'مراسلة الإدارة مباشرة عبر تيليجرام ✈️',
                style: TextStyle(
                  color: _telegramBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _telegramBlue),
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Return to Login Link
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _activeTab = 0;
                _errorMessage = null;
                _successMessage = null;
              }),
              child: const Text(
                'لديك حساب كابتن مسجل بالفعل؟ تسجيل الدخول 🔑',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

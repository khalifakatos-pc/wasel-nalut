import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'design_system.dart';
import 'services/firebase_auth_service.dart';
import 'services/api_service.dart';
import 'main.dart';

/// Authentication method: Firebase SMS or Telegram Bot Fallback
enum AuthMethod { sms, telegram }

/// Dual-channel OTP verification screen for Wasel Nalut.
/// Supports 6-digit Firebase Native SMS codes with auto-retrieval
/// and seamless 1-tap / 4-digit OTP fallback via Telegram (@WaselNalutbot).
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayPhone;
  final AuthMethod initialMethod;
  final String? verificationId;
  final int? resendToken;
  final String? telegramSessionId;
  final String? telegramDeeplinkUrl;
  final String? telegramNativeUri;
  final bool telegramBotNeedsTap;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.displayPhone,
    this.initialMethod = AuthMethod.sms,
    this.verificationId,
    this.resendToken,
    this.telegramSessionId,
    this.telegramDeeplinkUrl,
    this.telegramNativeUri,
    this.telegramBotNeedsTap = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const Color _telegramBlue = Color(0xFF0088CC);

  final TextEditingController _otpController = TextEditingController();
  late AuthMethod _currentMethod;
  String? _verificationId;
  int? _resendToken;
  String? _telegramSessionId;
  String? _telegramDeeplinkUrl;
  String? _telegramNativeUri;
  bool _telegramBotNeedsTap = false;

  bool _isLoading = false;
  bool _canResend = false;
  int _timerSeconds = 60;
  Timer? _timer;
  Timer? _telegramPollTimer;
  bool _isPollingCheck = false;
  bool _hasCompletedLogin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.initialMethod;
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _telegramSessionId = widget.telegramSessionId;
    _telegramDeeplinkUrl = widget.telegramDeeplinkUrl;
    _telegramNativeUri = widget.telegramNativeUri;
    _telegramBotNeedsTap = widget.telegramBotNeedsTap;
    _startCountdown();
    if (_currentMethod == AuthMethod.telegram) {
      _startTelegramPolling();
    }
  }

  void _startTelegramPolling() {
    _telegramPollTimer?.cancel();
    final sessionId = _telegramSessionId;
    if (_currentMethod != AuthMethod.telegram ||
        sessionId == null ||
        sessionId.isEmpty) {
      return;
    }

    _telegramPollTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) async {
        if (!mounted ||
            _hasCompletedLogin ||
            _isPollingCheck ||
            _currentMethod != AuthMethod.telegram) {
          return;
        }
        _isPollingCheck = true;
        try {
          final pollRes = await TelegramAuthService.checkSessionStatus(
            sessionId: sessionId,
          );
          if (!mounted || _hasCompletedLogin) return;
          if (pollRes.expired) {
            _telegramPollTimer?.cancel();
            setState(() {
              _errorMessage =
                  'انتهت صلاحية الجلسة. اضغط على إعادة الإرسال لبدء جلسة جديدة.';
            });
            return;
          }
          if (pollRes.verified) {
            await _completeTelegramSignIn(pollRes);
          }
        } finally {
          _isPollingCheck = false;
        }
      },
    );
  }

  Future<void> _completeTelegramSignIn(TelegramVerifyResult verifyRes) async {
    if (_hasCompletedLogin) return;
    _hasCompletedLogin = true;
    _timer?.cancel();
    _telegramPollTimer?.cancel();

    final userName =
        verifyRes.userData?['full_name']?.toString() ?? 'زبون واصل نالوت';
    final backendToken = verifyRes.token;
    if (backendToken != null && backendToken.isNotEmpty) {
      await ApiService.saveToken(
        backendToken,
        phone: widget.phoneNumber,
        name: userName,
      );
    } else {
      final apiRes = await ApiService.loginWithVerifiedPhone(
        widget.phoneNumber,
        fullName: userName,
        authMethod: 'telegram_bot',
      );
      if (apiRes.isSuccess && apiRes.data != null) {
        final token = apiRes.data['token']?.toString() ??
            'wasel-tg-token-${DateTime.now().millisecondsSinceEpoch}';
        final apiName =
            apiRes.data['user']?['full_name']?.toString() ?? userName;
        await ApiService.saveToken(
          token,
          phone: widget.phoneNumber,
          name: apiName,
        );
      } else {
        await ApiService.saveToken(
          'wasel-tg-token-${DateTime.now().millisecondsSinceEpoch}',
          phone: widget.phoneNumber,
          name: userName,
        );
      }
    }

    if (!mounted) return;
    _navigateToHome();
  }

  void _startCountdown() {
    _canResend = false;
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    final expectedLength = _currentMethod == AuthMethod.sms ? 6 : 4;
    if (otp.length != expectedLength) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentMethod == AuthMethod.sms) {
        if (_verificationId == null || _verificationId!.isEmpty) {
          throw Exception('معرف التحقق غير متوفر. أعد طلب الرمز.');
        }

        final userCred = await FirebaseAuthService.verifySmsCode(
          verificationId: _verificationId!,
          smsCode: otp,
        );

        final uid = userCred.user?.uid ?? 'firebase-user';
        final apiRes = await ApiService.loginWithVerifiedPhone(
          widget.phoneNumber,
          firebaseUid: uid,
          authMethod: 'firebase_sms',
        );

        if (apiRes.isSuccess && apiRes.data != null) {
          final token = apiRes.data['token']?.toString() ?? 'wasel-token-$uid';
          final userName = apiRes.data['user']?['full_name']?.toString() ?? 'زبون واصل نالوت';
          await ApiService.saveToken(
            token,
            phone: widget.phoneNumber,
            name: userName,
          );
        } else {
          await ApiService.saveToken(
            'wasel-firebase-token-$uid',
            phone: widget.phoneNumber,
            name: 'زبون واصل نالوت',
          );
        }

        if (!mounted) return;
        _navigateToHome();
      } else {
        // Telegram OTP fallback verification
        final verifyRes = await TelegramAuthService.verifyOtp(
          phone: widget.phoneNumber,
          enteredOtp: otp,
          role: WaselUserRole.customer,
        );

        if (!mounted) return;

        if (verifyRes.success && verifyRes.verified) {
          await _completeTelegramSignIn(verifyRes);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = verifyRes.errorMessage ?? 'رمز التحقق غير صحيح أو انتهت صلاحيته';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'فشل التحقق من الرمز: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationShell(
          onToggleTheme: () {},
          isDark: false,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _resendOtp() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    if (_currentMethod == AuthMethod.sms) {
      await FirebaseAuthService.sendSmsOtp(
        phone: widget.phoneNumber,
        forceResendingToken: _resendToken,
        onCodeSent: (newVerificationId, newResendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = newVerificationId;
            _resendToken = newResendToken;
            _isLoading = false;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📩 تم إرسال رمز SMS جديد بنجاح'),
              backgroundColor: AppColors.waselPrimary,
            ),
          );
        },
        onError: (errMsg, isQuota) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = errMsg;
          });
          if (isQuota) {
            _switchToTelegramFallback();
          }
        },
        onAutoVerify: (credential) async {
          if (!mounted) return;
          try {
            await FirebaseAuthService.verifySmsCode(
              verificationId: _verificationId ?? '',
              smsCode: credential.smsCode ?? '',
            );
            _navigateToHome();
          } catch (_) {}
        },
      );
    } else {
      final res = await TelegramAuthService.requestOtp(
        phone: widget.phoneNumber,
        role: WaselUserRole.customer,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (res.success) {
          _telegramSessionId = res.sessionId;
          _telegramDeeplinkUrl = res.deeplinkUrl;
          _telegramNativeUri = res.nativeUri;
          _telegramBotNeedsTap = res.needsBotTap;
        } else {
          _errorMessage = res.errorMessage;
        }
      });
      if (res.success) {
        _startCountdown();
        _startTelegramPolling();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✈️ تم إرسال/تحديث طلب التحقق عبر تيليجرام'),
            backgroundColor: _telegramBlue,
          ),
        );
      }
    }
  }

  Future<void> _switchToTelegramFallback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await TelegramAuthService.requestOtp(
      phone: widget.phoneNumber,
      role: WaselUserRole.customer,
    );
    if (!mounted) return;

    setState(() {
      _currentMethod = AuthMethod.telegram;
      _telegramSessionId = res.sessionId;
      _telegramDeeplinkUrl = res.deeplinkUrl;
      _telegramNativeUri = res.nativeUri;
      _telegramBotNeedsTap = res.needsBotTap;
      _otpController.clear();
      _isLoading = false;
      if (!res.success) {
        _errorMessage = res.errorMessage;
      }
    });
    _startCountdown();
    _startTelegramPolling();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✈️ تم التحويل إلى التحقق عبر بوت تيليجرام (@WaselNalutbot)'),
        backgroundColor: _telegramBlue,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _telegramPollTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSms = _currentMethod == AuthMethod.sms;
    final pinLength = isSms ? 6 : 4;

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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Back button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    iconSize: 28,
                  ),
                ),

                const SizedBox(height: 20),

                // Channel badge & Icon
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isSms
                          ? AppColors.waselPrimary.withValues(alpha: 0.15)
                          : _telegramBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSms ? Icons.sms_rounded : Icons.send_rounded,
                      size: 38,
                      color: isSms ? AppColors.waselPrimary : _telegramBlue,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  isSms ? 'رمز التحقق عبر رسالة SMS 📩' : 'التحقق عبر تيليجرام ✈️',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle with phone number
                Text(
                  isSms
                      ? 'تم إرسال رمز التحقق (6 أرقام) في رسالة نصية قصيرة إلى:\n${widget.displayPhone}'
                      : _telegramBotNeedsTap
                          ? 'اضغط على الزر بالأسفل لفتح بوت @WaselNalutbot ومشاركة رقمك بنقرة واحدة، وسيتم تسجيل دخولك تلقائياً أو أدخل الرمز:\n${widget.displayPhone}'
                          : 'تم إرسال رمز التحقق (4 أرقام) لحسابك في تيليجرام:\n${widget.displayPhone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 32),

                // OTP Pin Code Input
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: PinCodeTextField(
                    key: ValueKey('pin_field_$_currentMethod'),
                    appContext: context,
                    length: pinLength,
                    controller: _otpController,
                    autoFocus: true,
                    animationType: AnimationType.scale,
                    keyboardType: TextInputType.number,
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: AppRadius.radiusMd,
                      fieldHeight: 56,
                      fieldWidth: isSms ? 44 : 64,
                      activeColor: isSms ? AppColors.waselPrimary : _telegramBlue,
                      inactiveColor: Colors.white24,
                      selectedColor: isSms ? AppColors.waselPrimary : _telegramBlue,
                      activeFillColor: (isSms ? AppColors.waselPrimary : _telegramBlue)
                          .withValues(alpha: 0.1),
                      inactiveFillColor: Colors.white.withValues(alpha: 0.05),
                      selectedFillColor: (isSms ? AppColors.waselPrimary : _telegramBlue)
                          .withValues(alpha: 0.15),
                    ),
                    enableActiveFill: true,
                    cursorColor: isSms ? AppColors.waselPrimary : _telegramBlue,
                    animationDuration: const Duration(milliseconds: 200),
                    onCompleted: _verifyOtp,
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusMd,
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Loading indicator
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.waselPrimary,
                        ),
                      ),
                    ),
                  ),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _verifyOtp(_otpController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSms ? AppColors.waselPrimary : _telegramBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                    ),
                    child: const Text(
                      'تأكيد رمز التحقق والدخول 🚀',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Resend timer / button
                Center(
                  child: _canResend
                      ? TextButton.icon(
                          onPressed: _resendOtp,
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: isSms ? AppColors.waselPrimary : _telegramBlue,
                            size: 18,
                          ),
                          label: Text(
                            isSms ? 'إعادة إرسال رمز SMS' : 'إعادة إرسال طلب تيليجرام',
                            style: TextStyle(
                              color: isSms ? AppColors.waselPrimary : _telegramBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : Text(
                          'إعادة إرسال الرمز بعد $_timerSeconds ثانية',
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                ),

                const SizedBox(height: 12),

                // Fallback channel switch button (SMS -> Telegram or vice versa)
                if (isSms)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _switchToTelegramFallback,
                      icon: const Icon(Icons.send_rounded,
                          color: _telegramBlue, size: 18),
                      label: const Text(
                        'لم يصلك رمز SMS؟ التحويل إلى تيليجرام ✈️',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _telegramBlue.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            TelegramAuthService.openTelegramBot(
                              customNativeUri: _telegramNativeUri,
                              customWebUrl: _telegramDeeplinkUrl,
                            );
                          },
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: const Text(
                            'فتح بوت واصل في تيليجرام للتأكيد الفوري ✈️',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _telegramBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _telegramPollTimer?.cancel();
                            setState(() {
                              _currentMethod = AuthMethod.sms;
                              _otpController.clear();
                            });
                            _resendOtp();
                          },
                          icon: const Icon(Icons.sms_outlined,
                              color: AppColors.waselPrimary, size: 18),
                          label: const Text(
                            'الرجوع للإرسال عبر SMS 📩',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.waselPrimary.withValues(alpha: 0.6),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

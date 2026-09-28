import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'design_system.dart';
import 'services/whatsapp_auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/api_service.dart';
import 'main.dart';

/// Authentication method: Firebase SMS or WhatsApp Fallback
enum AuthMethod { sms, whatsapp }

/// Dual-channel OTP verification screen for Wasel Nalut.
/// Supports 6-digit Firebase Native SMS codes with auto-retrieval
/// and seamless 4-digit fallback to WhatsApp OTP.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayPhone;
  final AuthMethod initialMethod;
  final String? verificationId;
  final int? resendToken;
  final String? generatedOtp;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.displayPhone,
    this.initialMethod = AuthMethod.sms,
    this.verificationId,
    this.resendToken,
    this.generatedOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  late AuthMethod _currentMethod;
  String? _verificationId;
  int? _resendToken;
  String? _activeWhatsAppOtp;

  bool _isLoading = false;
  bool _canResend = false;
  int _timerSeconds = 60;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.initialMethod;
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _activeWhatsAppOtp = widget.generatedOtp;
    _startCountdown();
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
        await ApiService.saveToken(
          'wasel-firebase-token-$uid',
          phone: widget.phoneNumber,
          name: 'زبون واصل نالوت',
        );

        if (!mounted) return;
        _navigateToHome();
      } else {
        // WhatsApp fallback verification
        final verified = await WhatsAppAuthService.verifyOtp(
          phone: widget.phoneNumber,
          enteredOtp: otp,
        );

        if (!mounted) return;

        if (verified) {
          await ApiService.saveToken(
            'wasel-wa-token-${DateTime.now().millisecondsSinceEpoch}',
            phone: widget.phoneNumber,
            name: 'زبون واصل نالوت',
          );
          if (!mounted) return;
          _navigateToHome();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'رمز التحقق غير صحيح أو انتهت صلاحيته';
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
            _switchToWhatsAppFallback();
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
      final newOtp = await WhatsAppAuthService.requestWhatsAppOtp(widget.phoneNumber);
      if (!mounted) return;
      setState(() {
        _activeWhatsAppOtp = newOtp;
        _isLoading = false;
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال رمز جديد عبر واتساب'),
          backgroundColor: Color(0xFF25D366),
        ),
      );
    }
  }

  Future<void> _switchToWhatsAppFallback() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final otp = await WhatsAppAuthService.requestWhatsAppOtp(widget.phoneNumber);
    if (!mounted) return;

    setState(() {
      _currentMethod = AuthMethod.whatsapp;
      _activeWhatsAppOtp = otp;
      _otpController.clear();
      _isLoading = false;
    });
    _startCountdown();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💬 تم التحويل إلى التحقق عبر واتساب'),
        backgroundColor: Color(0xFF25D366),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
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
                          : const Color(0xFF25D366).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSms ? Icons.sms_rounded : Icons.chat_rounded,
                      size: 38,
                      color: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  isSms ? 'رمز التحقق عبر رسالة SMS 📩' : 'رمز التحقق عبر واتساب 💬',
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
                      : 'تم إنشاء رمز التحقق (4 أرقام) لحسابك على:\n${widget.displayPhone}',
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
                      activeColor: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
                      inactiveColor: Colors.white24,
                      selectedColor: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
                      activeFillColor: (isSms ? AppColors.waselPrimary : const Color(0xFF25D366))
                          .withValues(alpha: 0.1),
                      inactiveFillColor: Colors.white.withValues(alpha: 0.05),
                      selectedFillColor: (isSms ? AppColors.waselPrimary : const Color(0xFF25D366))
                          .withValues(alpha: 0.15),
                    ),
                    enableActiveFill: true,
                    cursorColor: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
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
                      backgroundColor: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
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

                // WhatsApp helper card if in WhatsApp mode
                if (!isSms) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                      borderRadius: AppRadius.radiusLg,
                      border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF25D366), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'رمز التحقق الخاص بك: ${_activeWhatsAppOtp ?? "1234"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final code = _activeWhatsAppOtp ?? '1234';
                              _otpController.text = code;
                              _verifyOtp(code);
                            },
                            icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              'تعبئة الرمز تلقائياً وتأكيد الدخول ⚡',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Resend timer / button
                Center(
                  child: _canResend
                      ? TextButton.icon(
                          onPressed: _resendOtp,
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
                            size: 18,
                          ),
                          label: Text(
                            isSms ? 'إعادة إرسال رمز SMS' : 'إعادة إرسال رمز واتساب',
                            style: TextStyle(
                              color: isSms ? AppColors.waselPrimary : const Color(0xFF25D366),
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

                // Fallback channel switch button (SMS -> WhatsApp or vice versa)
                if (isSms)
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _switchToWhatsAppFallback,
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF25D366), size: 18),
                      label: const Text(
                        'لم يصلك رمز SMS؟ التحويل إلى واتساب 💬',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFF25D366).withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
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

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

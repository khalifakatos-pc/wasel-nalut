import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'design_system.dart';
import 'services/whatsapp_auth_service.dart';
import 'services/api_service.dart';
import 'main.dart';

/// OTP verification screen for Wasel Nalut with WhatsApp OTP code.
class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String displayPhone;
  final String? generatedOtp;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.displayPhone,
    this.generatedOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _canResend = false;
  int _timerSeconds = 60;
  Timer? _timer;
  String? _errorMessage;
  String? _activeOtp;

  @override
  void initState() {
    super.initState();
    _activeOtp = widget.generatedOtp;
    _startCountdown();
  }

  void _startCountdown() {
    _canResend = false;
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 1) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 4) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'رمز التحقق غير صحيح أو انتهت صلاحيته';
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final newOtp = await WhatsAppAuthService.requestWhatsAppOtp(widget.phoneNumber);

    if (!mounted) return;

    setState(() {
      _activeOtp = newOtp;
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

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
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
                const SizedBox(height: 16),

                // Back button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white),
                    iconSize: 28,
                  ),
                ),

                const SizedBox(height: 32),

                // Lock icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.waselPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 36,
                      color: AppColors.waselPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                const Text(
                  'رمز التحقق عبر واتساب',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle with phone number
                Text(
                  'تم إرسال رمز التحقق المكون من 4 أرقام عبر واتساب إلى\n${widget.displayPhone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 40),

                // OTP Pin Code Input
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: PinCodeTextField(
                    appContext: context,
                    length: 4,
                    controller: _otpController,
                    autoFocus: true,
                    animationType: AnimationType.scale,
                    keyboardType: TextInputType.number,
                    textStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: AppRadius.radiusLg,
                      fieldHeight: 64,
                      fieldWidth: 64,
                      activeColor: AppColors.waselPrimary,
                      inactiveColor: Colors.white24,
                      selectedColor: AppColors.waselPrimary,
                      activeFillColor: AppColors.waselPrimary.withValues(alpha: 0.1),
                      inactiveFillColor: Colors.white.withValues(alpha: 0.05),
                      selectedFillColor: AppColors.waselPrimary.withValues(alpha: 0.15),
                    ),
                    enableActiveFill: true,
                    cursorColor: AppColors.waselPrimary,
                    animationDuration: const Duration(milliseconds: 200),
                    onCompleted: _verifyOtp,
                    onChanged: (_) => setState(() => _errorMessage = null),
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Loading indicator
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.waselPrimary,
                        ),
                      ),
                    ),
                  ),

                // Prominent Auto-Fill & Code Display Card
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF25D366), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'رمز التحقق الخاص بك: ${_activeOtp ?? "1234"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final code = _activeOtp ?? '1234';
                            _otpController.text = code;
                            _verifyOtp(code);
                          },
                          icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                          label: const Text(
                            'تعبئة الرمز تلقائياً وتأكيد الدخول ⚡',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Resend timer / button
                Center(
                  child: _canResend
                      ? TextButton.icon(
                          onPressed: _resendOtp,
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF25D366), size: 18),
                          label: const Text(
                            'إعادة إرسال رمز جديد',
                            style: TextStyle(
                              color: Color(0xFF25D366),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        )
                      : Text(
                          'إعادة إرسال الرمز بعد $_timerSeconds ثانية',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                // Open WhatsApp Support Button
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      WhatsAppAuthService.openWhatsAppVerificationChat(
                        phone: widget.phoneNumber,
                        otpCode: _activeOtp ?? '1234',
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                    label: const Text(
                      'مراسلة الدعم الفني عبر واتساب 💬',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusMd,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Clear Explanation Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.waselPrimary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(
                      color: AppColors.waselPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.waselPrimary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '💡 لا داعي لانتظار رسالة واتساب خارجية، الرمز تم إنشاؤه في التطبيق مباشرة. اضغط على «تعبئة الرمز تلقائياً» أو اكتب 1234 للدخول الفوري.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
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
    );
  }
}

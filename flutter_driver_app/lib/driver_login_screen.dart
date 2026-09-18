import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'services/driver_supabase_service.dart';

/// ============================================================================
/// CAPTAIN WASEL (كابتن واصل نالوت) AUTHENTICATION & LOGIN SCREEN
/// ============================================================================
/// Secures the driver application behind phone number and PIN authentication.
/// Links directly with backend and Supabase fleet records.
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

  void _fillQuickCredentials(String phone, String pin) {
    setState(() {
      _phoneController.text = phone;
      _pinController.text = pin;
      _errorMessage = null;
    });
  }

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
    });

    try {
      final success = await DriverSupabaseService.authenticateCaptain(phone, pin);

      if (success) {
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        setState(() {
          _errorMessage = 'رقم الهاتف أو رمز PIN غير صحيح، أو أن الحساب غير مسجل في أسطول نالوت.';
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
                    width: 90,
                    height: 90,
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
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

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
                const SizedBox(height: 28),

                // Error Message Banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DriverColors.offlineRed.withValues(alpha: 0.15),
                      borderRadius: DriverRadius.radiusMd,
                      border: Border.all(color: DriverColors.offlineRed.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: DriverColors.offlineRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Login Form Card
                Container(
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
                      const SizedBox(height: 24),

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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Select / Test Captains of Nalut
                const Text(
                  'كباتن نالوت المسجلون (اختيار سريع للتجربة):',
                  style: TextStyle(fontSize: 12, color: DriverColors.darkTextMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: DriverColors.darkSurface,
                      side: const BorderSide(color: DriverColors.darkBorder),
                      avatar: const Icon(Icons.directions_car_rounded, size: 16, color: DriverColors.primary),
                      label: const Text('خالد الكاتب (0912345678)', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _fillQuickCredentials('0912345678', '1234'),
                    ),
                    ActionChip(
                      backgroundColor: DriverColors.darkSurface,
                      side: const BorderSide(color: DriverColors.darkBorder),
                      avatar: const Icon(Icons.two_wheeler_rounded, size: 16, color: DriverColors.onlineGreen),
                      label: const Text('عمر القلعاوي (0923456789)', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _fillQuickCredentials('0923456789', '1234'),
                    ),
                    ActionChip(
                      backgroundColor: DriverColors.darkSurface,
                      side: const BorderSide(color: DriverColors.darkBorder),
                      avatar: const Icon(Icons.directions_car_rounded, size: 16, color: DriverColors.tadawulTeal),
                      label: const Text('طارق النالوتي (0915544332)', style: TextStyle(color: Colors.white, fontSize: 11)),
                      onPressed: () => _fillQuickCredentials('0915544332', '1234'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Operational Support Note
                const Center(
                  child: Text(
                    '🔒 تطبيق خاص بكباتن التوصيل المسجلين رسمياً في منصة واصل نالوت\nلطلب التسجيل أو استعادة الرمز يرجى مراجعة إدارة العمليات',
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
}

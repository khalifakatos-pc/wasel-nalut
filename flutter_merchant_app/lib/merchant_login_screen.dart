import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';
import 'services/merchant_supabase_service.dart';

/// ============================================================================
/// WASEL MERCHANT & KITCHEN LOGIN SCREEN (عزل المتاجر وتسجيل الدخول المخصص)
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

        // Save session locally for persistent isolation
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MerchantColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Logo & Title
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MerchantColors.primary,
                            MerchantColors.primary.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MerchantColors.primary.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'شريك واصل | نالوت',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'منظومة إدارة الطلبات والمطبخ والجرد المستقل',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: MerchantColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: MerchantColors.darkBorder,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تسجيل الدخول للمتجر',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'أدخل بيانات الدخول المعتمدة لمتجرك في نالوت',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: MerchantColors.rejectedRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: MerchantColors.rejectedRed.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: MerchantColors.rejectedRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: MerchantColors.rejectedRed,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Phone Field
                        const Text(
                          'رقم هاتف المتجر / المسؤول',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '091XXXXXXX',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🇱🇾', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 6),
                                  Text(
                                    '+218',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            filled: true,
                            fillColor: MerchantColors.darkSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PIN Field
                        const Text(
                          'رمز الدخول السري (PIN)',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          obscureText: _obscurePin,
                          maxLength: 6,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '••••',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              letterSpacing: 4,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                            filled: true,
                            fillColor: MerchantColors.darkSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MerchantColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
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
                                      Icon(Icons.arrow_back_rounded, size: 20),
                                    ],
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

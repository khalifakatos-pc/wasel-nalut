import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service handling Firebase Phone (SMS) Authentication for Wasel Nalut.
/// Includes Libyan phone normalization, automated OTP retrieval, and
/// smart quota detection for fallback routing to WhatsApp.
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _kCachedVerificationId = 'wasel_sms_verification_id';
  static const String _kCachedPhone = 'wasel_sms_phone';

  /// Normalizes any Libyan phone number representation into standard E.164 (+2189XXXXXXXX).
  /// Converts Arabic numerals (٠-٩) and strips non-digits.
  static String normalizeLibyanPhone(String raw) {
    if (raw.isEmpty) return '';

    // Convert Arabic-Indic digits to Latin
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String converted = raw;
    for (int i = 0; i < arabicDigits.length; i++) {
      converted = converted.replaceAll(arabicDigits[i], i.toString());
    }

    // Strip whitespace, dashes, parens
    String cleaned = converted.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Strip leading '+'
    cleaned = cleaned.replaceAll('+', '');

    // If starts with 00218, strip 00
    if (cleaned.startsWith('00218')) {
      cleaned = cleaned.substring(2); // '218...'
    }

    // If starts with 218
    if (cleaned.startsWith('218')) {
      return '+$cleaned';
    }

    // If starts with local 0 (e.g. 0912345678)
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Now if it starts with 91, 92, 94, 95, 93 (standard Libyan mobile prefixes)
    return '+218$cleaned';
  }

  /// Validates whether a phone number is a well-formed Libyan mobile number.
  /// Standard: +218 followed by 9 and 8 digits (total 13 chars)
  static bool isValidLibyanPhone(String phone) {
    final normalized = normalizeLibyanPhone(phone);
    final regExp = RegExp(r'^\+2189[1-689]\d{7}$');
    return regExp.hasMatch(normalized);
  }

  /// Nicely formats normalized phone for local display (e.g. 091 234 5678).
  static String formatDisplayPhone(String raw) {
    final normalized = normalizeLibyanPhone(raw);
    if (normalized.startsWith('+218') && normalized.length == 13) {
      final local = '0${normalized.substring(4)}'; // 0912345678
      return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
    return raw;
  }

  /// Sends Firebase SMS OTP to the provided phone number.
  /// Handles auto-verification, quota errors, and caching of verification ID.
  static Future<void> sendSmsOtp({
    required String phone,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage, bool isQuotaOrNetworkError) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
    int? forceResendingToken,
  }) async {
    final normalizedPhone = normalizeLibyanPhone(phone);

    if (!isValidLibyanPhone(normalizedPhone)) {
      onError('رقم الهاتف غير صالح. يرجى إدخال رقم ليبي يبدأ بـ 091 أو 092 أو 094', false);
      return;
    }

    // Cache requested phone for continuity
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedPhone, normalizedPhone);
    } catch (_) {}

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ [FirebaseAuth] Instant verification completed on Android');
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('⚠️ [FirebaseAuth] Verification failed: [${e.code}] ${e.message}');
          final isQuota = e.code == 'quota-exceeded' ||
              e.code == 'too-many-requests' ||
              e.code == 'app-not-authorized' ||
              e.code == 'billing-not-enabled' ||
              e.code == 'captcha-check-failed';

          String message = 'تعذر إرسال رمز التحقق عبر الرسائل القصيرة SMS.';
          if (e.code == 'quota-exceeded' || e.code == 'too-many-requests') {
            message = 'تم الوصول للحد الأقصى لرسائل SMS المجانية لهذا الشهر. يمكنك الدخول فوراً عبر واتساب.';
          } else if (e.code == 'invalid-phone-number') {
            message = 'رقم الهاتف غير صالح أو غير معتمد من شركة الاتصالات.';
          } else if (e.code == 'network-request-failed') {
            message = 'تعذر الاتصال بخوادم التحقق. تحقق من اتصال الإنترنت أو استخدم واتساب.';
          }

          onError(message, isQuota);
        },
        codeSent: (String verificationId, int? resendToken) async {
          debugPrint('📩 [FirebaseAuth] SMS Code Sent! Verification ID: $verificationId');
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kCachedVerificationId, verificationId);
          } catch (_) {}
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) async {
          debugPrint('⏳ [FirebaseAuth] Code auto-retrieval timeout');
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kCachedVerificationId, verificationId);
          } catch (_) {}
        },
      );
    } catch (e) {
      debugPrint('🚨 [FirebaseAuth] Unexpected error in verifyPhoneNumber: $e');
      onError('حدث خطأ غير متوقع أثناء إرسال SMS. يرجى المتابعة عبر واتساب.', true);
    }
  }

  /// Verifies manual 6-digit SMS code entered by the user.
  static Future<UserCredential> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final cleanCode = smsCode.trim().replaceAll(' ', '');
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: cleanCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Retrieves cached verification ID if user navigated back or app was restarted.
  static Future<String?> getCachedVerificationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kCachedVerificationId);
    } catch (_) {
      return null;
    }
  }

  /// Clears stored verification artifacts after successful login or reset.
  static Future<void> clearVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedVerificationId);
    } catch (_) {}
  }

  /// Returns current authenticated Firebase user if any.
  static User? get currentUser => _auth.currentUser;

  /// Signs out from Firebase Authentication.
  static Future<void> signOut() async {
    await clearVerification();
    await _auth.signOut();
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Phone Auth service for Captains (كابتن واصل نالوت).
class DriverFirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _kCachedVerificationId = 'wasel_captain_sms_verification_id';

  /// Normalizes Libyan mobile numbers to E.164 (+2189XXXXXXXX).
  static String normalizeLibyanPhone(String raw) {
    if (raw.isEmpty) return '';

    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String converted = raw;
    for (int i = 0; i < arabicDigits.length; i++) {
      converted = converted.replaceAll(arabicDigits[i], i.toString());
    }

    String cleaned = converted.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    cleaned = cleaned.replaceAll('+', '');

    if (cleaned.startsWith('00218')) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.startsWith('218')) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    return '+218$cleaned';
  }

  static bool isValidLibyanPhone(String phone) {
    final normalized = normalizeLibyanPhone(phone);
    return RegExp(r'^\+2189[1-689]\d{7}$').hasMatch(normalized);
  }

  static Future<void> sendCaptainSmsOtp({
    required String phone,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage, bool isQuota) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
    int? forceResendingToken,
  }) async {
    final normalizedPhone = normalizeLibyanPhone(phone);

    if (!isValidLibyanPhone(normalizedPhone)) {
      onError('يرجى إدخال رقم هاتف ليبي صحيح للكابتن', false);
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          debugPrint('✅ [DriverFirebaseAuth] Instant verification completed');
          onAutoVerify(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('⚠️ [DriverFirebaseAuth] Verification failed: ${e.code}');
          final isQuota = e.code == 'quota-exceeded' ||
              e.code == 'too-many-requests' ||
              e.code == 'app-not-authorized' ||
              e.code == 'billing-not-enabled';

          String message = 'تعذر إرسال رمز التحقق SMS للكابتن.';
          if (isQuota) {
            message = 'تم الوصول للحد الشهري لرسائل SMS. يمكنك المتابعة برمز PIN الخاص بك أو عبر واتساب.';
          }
          onError(message, isQuota);
        },
        codeSent: (String verificationId, int? resendToken) async {
          debugPrint('📩 [DriverFirebaseAuth] SMS sent to captain: $verificationId');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kCachedVerificationId, verificationId);
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kCachedVerificationId, verificationId);
        },
      );
    } catch (e) {
      onError('حدث خطأ أثناء إرسال الرمز SMS: $e', true);
    }
  }

  static Future<UserCredential> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    return await _auth.signInWithCredential(credential);
  }
}

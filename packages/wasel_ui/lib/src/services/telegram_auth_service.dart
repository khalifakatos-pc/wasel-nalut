import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'kapso_whatsapp_service.dart' show WaselUserRole;

export 'kapso_whatsapp_service.dart' show WaselUserRole;

/// Delivery mode returned by the Telegram Bot API backend
enum TelegramDeliveryMode {
  directDelivery,
  botVerificationRequired,
  error,
}

/// Result returned when initiating a Telegram OTP / Deep-Link login
class TelegramOtpResult {
  final bool success;
  final TelegramDeliveryMode mode;
  final String normalizedPhone;
  final String? sessionId;
  final String botUsername;
  final String deeplinkUrl;
  final String nativeUri;
  final String? message;
  final String? errorMessage;
  final int expiresInSeconds;

  const TelegramOtpResult({
    required this.success,
    required this.mode,
    required this.normalizedPhone,
    this.sessionId,
    this.botUsername = TelegramAuthService.botUsername,
    required this.deeplinkUrl,
    required this.nativeUri,
    this.message,
    this.errorMessage,
    this.expiresInSeconds = 300,
  });

  bool get isDirectDelivery => mode == TelegramDeliveryMode.directDelivery;
  bool get needsBotTap => mode == TelegramDeliveryMode.botVerificationRequired;
}

/// Verification / Login session result
class TelegramVerifyResult {
  final bool success;
  final bool verified;
  final bool expired;
  final bool isNewUser;
  final String? token;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? driverData;
  final Map<String, dynamic>? storeData;
  final String? errorMessage;

  const TelegramVerifyResult({
    required this.success,
    this.verified = false,
    this.expired = false,
    this.isNewUser = false,
    this.token,
    this.userData,
    this.driverData,
    this.storeData,
    this.errorMessage,
  });
}

/// ============================================================================
/// CENTRAL TELEGRAM BOT API AUTHENTICATION & DISPATCH SERVICE
/// Powered by @WaselNalutbot across Customer, Captain, Merchant & Admin apps.
/// ============================================================================
class TelegramAuthService {
  static const String botUsername = 'WaselNalutbot';
  static const String officialAdminPhone = '+218918207786';

  static String backendBaseUrl = const String.fromEnvironment(
    'WASEL_BACKEND_URL',
    defaultValue: 'https://wasel-nalut.onrender.com',
  );

  static String normalizePhone(String phone) {
    String clean = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('00218')) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0')) {
      clean = '218${clean.substring(1)}';
    } else if (!clean.startsWith('218') && clean.length >= 9) {
      clean = '218$clean';
    }
    return clean;
  }

  static String formatDisplayPhone(String phone) {
    final clean = normalizePhone(phone);
    if (clean.startsWith('218') && clean.length == 12) {
      final local = '0${clean.substring(3)}';
      return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
    return phone;
  }

  /// Requests Telegram verification (either pushes 4-digit OTP directly if linked,
  /// or returns a unique Deep-Link sessionId for 1-tap contact verification).
  static Future<TelegramOtpResult> requestOtp({
    required String phone,
    WaselUserRole role = WaselUserRole.customer,
  }) async {
    final normalized = normalizePhone(phone);
    final fallbackDeeplink = 'https://t.me/$botUsername';
    final fallbackNative = 'tg://resolve?domain=$botUsername';

    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/api/v1/auth/telegram/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': normalized,
              'role': role.toApiString(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      final dynamic parsed = jsonDecode(res.body);
      if (parsed is Map<String, dynamic> &&
          res.statusCode >= 200 &&
          res.statusCode < 300 &&
          parsed['success'] == true) {
        final modeStr = parsed['mode']?.toString() ?? 'bot_verification_required';
        return TelegramOtpResult(
          success: true,
          mode: modeStr == 'direct_delivery'
              ? TelegramDeliveryMode.directDelivery
              : TelegramDeliveryMode.botVerificationRequired,
          normalizedPhone: parsed['normalizedPhone']?.toString() ?? normalized,
          sessionId: parsed['sessionId']?.toString(),
          botUsername: parsed['botUsername']?.toString() ?? botUsername,
          deeplinkUrl: parsed['deeplinkUrl']?.toString() ?? fallbackDeeplink,
          nativeUri: parsed['nativeUri']?.toString() ?? fallbackNative,
          message: parsed['message']?.toString(),
          expiresInSeconds: (parsed['expiresInSeconds'] as num?)?.toInt() ?? 300,
        );
      }

      return TelegramOtpResult(
        success: false,
        mode: TelegramDeliveryMode.error,
        normalizedPhone: normalized,
        deeplinkUrl: fallbackDeeplink,
        nativeUri: fallbackNative,
        errorMessage: (parsed is Map ? parsed['error']?.toString() : null) ??
            'تعذر طلب التحقق عبر تيليجرام. يرجى المحاولة مرة أخرى.',
      );
    } catch (e) {
      debugPrint('Telegram requestOtp error: $e');
      return TelegramOtpResult(
        success: false,
        mode: TelegramDeliveryMode.error,
        normalizedPhone: normalized,
        deeplinkUrl: fallbackDeeplink,
        nativeUri: fallbackNative,
        errorMessage: 'تعذر الاتصال بخادم تيليجرام. تحقق من اتصال الإنترنت.',
      );
    }
  }

  /// Polls whether the user completed 1-tap phone verification inside Telegram
  static Future<TelegramVerifyResult> checkSessionStatus({
    required String sessionId,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('$backendBaseUrl/api/v1/auth/telegram/session-status?session_id=${Uri.encodeComponent(sessionId)}'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final verified = body['verified'] == true;
        final expired = body['expired'] == true;
        if (verified && body['data'] is Map<String, dynamic>) {
          final data = body['data'] as Map<String, dynamic>;
          return TelegramVerifyResult(
            success: true,
            verified: true,
            isNewUser: data['isNewUser'] == true,
            token: data['token']?.toString(),
            userData: data['user'] as Map<String, dynamic>?,
            driverData: data['driver'] as Map<String, dynamic>?,
            storeData: data['store'] as Map<String, dynamic>?,
          );
        }
        return TelegramVerifyResult(success: false, verified: false, expired: expired);
      }
    } catch (e) {
      debugPrint('Telegram checkSessionStatus warning: $e');
    }
    return const TelegramVerifyResult(success: false, verified: false);
  }

  /// Verifies 4-digit OTP code received in Telegram
  static Future<TelegramVerifyResult> verifyOtp({
    required String phone,
    required String enteredOtp,
    WaselUserRole role = WaselUserRole.customer,
    String? fullName,
  }) async {
    final normalized = normalizePhone(phone);
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/api/v1/auth/telegram/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': normalized,
              'otp': enteredOtp.trim(),
              'role': role.toApiString(),
              'full_name': ?fullName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>?;
        return TelegramVerifyResult(
          success: true,
          verified: true,
          isNewUser: data?['isNewUser'] == true,
          token: data?['token']?.toString(),
          userData: data?['user'] as Map<String, dynamic>?,
          driverData: data?['driver'] as Map<String, dynamic>?,
          storeData: data?['store'] as Map<String, dynamic>?,
        );
      }

      return TelegramVerifyResult(
        success: false,
        errorMessage: body['error']?.toString() ?? 'رمز التحقق غير صحيح.',
      );
    } catch (e) {
      debugPrint('Telegram verifyOtp error: $e');
      return const TelegramVerifyResult(
        success: false,
        errorMessage: 'حدث خطأ أثناء التحقق عبر تيليجرام. تأكد من الاتصال.',
      );
    }
  }

  /// Submits new captain registration inquiry to backend & admin Telegram alert
  static Future<Map<String, dynamic>> submitCaptainApplication({
    required String fullName,
    required String phone,
    String vehicleType = 'سيارة',
    String notes = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/api/v1/integrations/telegram/captain-application'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName.trim(),
              'phone': phone.trim(),
              'vehicle_type': vehicleType,
              'notes': notes.trim(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body;
    } catch (e) {
      debugPrint('Captain application API error: $e');
      return {
        'success': false,
        'bot_url': 'https://t.me/$botUsername?start=captain_register',
      };
    }
  }

  /// Opens @WaselNalutbot in Telegram app or web fallback
  static Future<bool> openTelegramBot({
    String? startPayload,
    String? customNativeUri,
    String? customWebUrl,
  }) async {
    final param = (startPayload != null && startPayload.isNotEmpty) ? '?start=$startPayload' : '';
    final nativeParam = (startPayload != null && startPayload.isNotEmpty) ? '&start=$startPayload' : '';
    final tgUri = Uri.parse(customNativeUri ?? 'tg://resolve?domain=$botUsername$nativeParam');
    final webUri = Uri.parse(customWebUrl ?? 'https://t.me/$botUsername$param');

    try {
      if (await canLaunchUrl(tgUri)) {
        return await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      }
      if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('Error launching Telegram bot: $e');
      return false;
    }
  }

  /// Opens direct Telegram chat with Operations Admin (+218918207786) with bot fallback
  static Future<bool> openAdminSupportChat({String startPayload = 'captain_register'}) async {
    final cleanAdmin = officialAdminPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneUri = Uri.parse('https://t.me/+$cleanAdmin');
    try {
      if (await canLaunchUrl(phoneUri)) {
        return await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return openTelegramBot(startPayload: startPayload);
  }
}

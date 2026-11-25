import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Role category for WhatsApp verification
enum WaselUserRole {
  customer,
  captain,
  merchant,
  admin;

  String toApiString() {
    switch (this) {
      case WaselUserRole.captain:
        return 'captain';
      case WaselUserRole.merchant:
        return 'merchant';
      case WaselUserRole.admin:
        return 'admin';
      case WaselUserRole.customer:
        return 'customer';
    }
  }
}

/// Delivery mode returned by Kapso Cloud API
enum KapsoDeliveryMode {
  directDelivery,
  deeplinkRequired,
  offlineFallback,
}

/// Response payload from an OTP request
class KapsoOtpResult {
  final bool success;
  final KapsoDeliveryMode mode;
  final String normalizedPhone;
  final String? otp;
  final String? message;
  final String? deeplinkUrl;
  final String? nativeUri;
  final int expiresInSeconds;
  final String? errorMessage;

  const KapsoOtpResult({
    required this.success,
    required this.mode,
    required this.normalizedPhone,
    this.otp,
    this.message,
    this.deeplinkUrl,
    this.nativeUri,
    this.expiresInSeconds = 300,
    this.errorMessage,
  });

  bool get isDirectDelivery => mode == KapsoDeliveryMode.directDelivery;
  bool get needsDeeplink => mode == KapsoDeliveryMode.deeplinkRequired || mode == KapsoDeliveryMode.offlineFallback;
}

/// Verification result
class KapsoVerifyResult {
  final bool success;
  final bool isNewUser;
  final String? token;
  final Map<String, dynamic>? userData;
  final String? errorMessage;

  const KapsoVerifyResult({
    required this.success,
    this.isNewUser = false,
    this.token,
    this.userData,
    this.errorMessage,
  });
}

/// Central Kapso WhatsApp Authentication Service
/// Shared across Customer, Captain, Merchant, and Admin apps.
class KapsoWhatsAppService {
  /// Official Nalut Customer & Fleet Support WhatsApp Number
  static const String officialSupportPhone = '+218918207786';

  /// Default Backend Base URL
  static String backendBaseUrl = 'http://127.0.0.1:3000';

  // Client-side cache for offline/direct fallback
  static String? _cachedOtp;
  static String? _cachedPhone;
  static DateTime? _cachedExpiresAt;

  /// Normalizes any Libyan phone number to standard international format (e.g. 218918207786)
  static String normalizePhone(String phone) {
    String clean = phone.trim().replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
    if (clean.startsWith('0')) {
      clean = '218${clean.substring(1)}';
    } else if (!clean.startsWith('218')) {
      clean = '218$clean';
    }
    return clean;
  }

  /// Formats phone for local display (e.g. 091 820 7786)
  static String formatDisplayPhone(String phone) {
    final clean = normalizePhone(phone);
    if (clean.startsWith('218') && clean.length == 12) {
      final local = '0${clean.substring(3)}';
      return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
    return phone;
  }

  /// Requests a 4-digit OTP code via Kapso WhatsApp
  static Future<KapsoOtpResult> requestOtp({
    required String phone,
    WaselUserRole role = WaselUserRole.customer,
  }) async {
    final normalized = normalizePhone(phone);
    final roleStr = role.toApiString();

    // 1. Try Backend endpoint first (Secure server-side Kapso dispatch)
    try {
      final url = Uri.parse('$backendBaseUrl/api/v1/auth/whatsapp/send-otp');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': normalized,
          'role': roleStr,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        final modeStr = body['mode']?.toString() ?? 'direct_delivery';
        final mode = modeStr == 'direct_delivery'
            ? KapsoDeliveryMode.directDelivery
            : KapsoDeliveryMode.deeplinkRequired;

        final receivedOtp = body['otp']?.toString();
        if (receivedOtp != null) {
          _cachedOtp = receivedOtp;
          _cachedPhone = normalized;
          _cachedExpiresAt = DateTime.now().add(const Duration(minutes: 5));
        }

        return KapsoOtpResult(
          success: true,
          mode: mode,
          normalizedPhone: normalized,
          otp: receivedOtp,
          message: body['message']?.toString(),
          deeplinkUrl: body['deeplinkUrl']?.toString(),
          nativeUri: body['nativeUri']?.toString(),
          expiresInSeconds: (body['expiresInSeconds'] as num?)?.toInt() ?? 300,
        );
      }
    } catch (e) {
      debugPrint('Kapso backend send-otp error: $e. Falling back to client-assisted OTP.');
    }

    // 2. Client-Assisted Fallback (offline or local server down)
    final random = Random();
    final fallbackOtp = (1000 + random.nextInt(9000)).toString();
    _cachedOtp = fallbackOtp;
    _cachedPhone = normalized;
    _cachedExpiresAt = DateTime.now().add(const Duration(minutes: 5));

    final cleanOfficial = officialSupportPhone.replaceAll('+', '').replaceAll(' ', '');
    final prefilled = Uri.encodeComponent(
      'طلب تأكيد رقمي في واصل نالوت ($roleStr):\n'
      'الرقم: $normalized\n'
      'رمز التحقق الخاص بي: $fallbackOtp\n'
      'يرجى فتح وتأكيد الجلسة ⚡',
    );

    return KapsoOtpResult(
      success: true,
      mode: KapsoDeliveryMode.deeplinkRequired,
      normalizedPhone: normalized,
      otp: fallbackOtp,
      message: 'يرجى فتح محادثة واتساب الرسمية لتأكيد الرقم وتلقي الرمز.',
      deeplinkUrl: 'https://wa.me/$cleanOfficial?text=$prefilled',
      nativeUri: 'whatsapp://send?phone=$cleanOfficial&text=$prefilled',
      expiresInSeconds: 300,
    );
  }

  /// Verifies the entered OTP code
  static Future<KapsoVerifyResult> verifyOtp({
    required String phone,
    required String enteredOtp,
    WaselUserRole role = WaselUserRole.customer,
    String? fullName,
  }) async {
    final normalized = normalizePhone(phone);
    final cleanOtp = enteredOtp.trim();

    // 1. Try Backend verification first
    try {
      final url = Uri.parse('$backendBaseUrl/api/v1/auth/whatsapp/verify-otp');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': normalized,
          'otp': cleanOtp,
          'role': role.toApiString(),
          'full_name': fullName,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          return KapsoVerifyResult(
            success: true,
            isNewUser: body['message']?.toString().contains('تسجيل') ?? false,
            token: data?['token']?.toString(),
            userData: data?['user'] as Map<String, dynamic>?,
          );
        }
      } else {
        final Map<String, dynamic> errBody = jsonDecode(res.body);
        return KapsoVerifyResult(
          success: false,
          errorMessage: errBody['error']?.toString() ?? 'رمز التحقق غير صحيح.',
        );
      }
    } catch (e) {
      debugPrint('Kapso backend verify error: $e. Checking client cache.');
    }

    // 2. Client-Assisted Cache Verification (Fallback)
    if (_cachedPhone == normalized && _cachedOtp == cleanOtp) {
      if (_cachedExpiresAt != null && DateTime.now().isBefore(_cachedExpiresAt!)) {
        return KapsoVerifyResult(
          success: true,
          token: 'wasel-wa-token-${DateTime.now().millisecondsSinceEpoch}',
          userData: {
            'phone': '+$normalized',
            'role': role.toApiString(),
            'full_name': fullName ?? 'مستخدم واصل نالوت',
          },
        );
      }
      return const KapsoVerifyResult(
        success: false,
        errorMessage: 'انتهت صلاحية رمز التحقق (5 دقائق). أعد المحاولة.',
      );
    }

    return const KapsoVerifyResult(
      success: false,
      errorMessage: 'رمز التحقق غير صحيح أو لم يتم طلبه.',
    );
  }

  /// Opens WhatsApp with the official verification conversation
  static Future<bool> openWhatsAppChat({
    required String phone,
    required String otpCode,
    String? customOfficialPhone,
  }) async {
    final normalized = normalizePhone(phone);
    final targetOfficial = customOfficialPhone ?? officialSupportPhone;
    final cleanOfficial = targetOfficial.replaceAll('+', '').replaceAll(' ', '');

    final message = 'طلب تأكيد رقمي في تطبيق واصل نالوت ⚡\n'
        'الرقم: +$normalized\n'
        'رمز التحقق الخاص بي: $otpCode\n'
        'يرجى تأكيد الحساب وفتح المحادثة.';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUri = Uri.parse('whatsapp://send?phone=$cleanOfficial&text=$encodedMessage');
    final webUri = Uri.parse('https://wa.me/$cleanOfficial?text=$encodedMessage');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Error launching WhatsApp chat: $e');
      return false;
    }
  }

  /// Opens a direct chat with the Wasel Nalut Smart AI Agent (+218 91-8207786)
  static Future<bool> openSupportChat({String? initialMessage}) async {
    final cleanOfficial = officialSupportPhone.replaceAll('+', '').replaceAll(' ', '');
    final msg = initialMessage ?? 'السلام عليكم واصل نالوت ⚡، أحتاج مساعدة أو استفسار بخصوص الخدمة.';
    final encoded = Uri.encodeComponent(msg);
    final whatsappUri = Uri.parse('whatsapp://send?phone=$cleanOfficial&text=$encoded');
    final webUri = Uri.parse('https://wa.me/$cleanOfficial?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Error launching support WhatsApp chat: $e');
      return false;
    }
  }
}

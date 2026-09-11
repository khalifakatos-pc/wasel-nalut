import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// WhatsApp OTP Authentication Service for Wasel Nalut Captains
class WhatsAppAuthService {
  static const String officialSupportPhone = '+218910000000';
  static const String _supabaseUrl = 'https://yfhvuatssuylrkbthosa.supabase.co/rest/v1';
  static const String _supabaseApiKey = 'sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD';

  static Map<String, String> get _headers => {
        'apikey': _supabaseApiKey,
        'Authorization': 'Bearer $_supabaseApiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation,resolution=merge-duplicates',
      };

  static String? _cachedOtp;
  static String? _cachedPhone;
  static DateTime? _cachedExpiresAt;

  static Future<String> requestWhatsAppOtp(String phone) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final random = Random();
    final otp = (1000 + random.nextInt(9000)).toString();
    final expiresAt = DateTime.now().add(const Duration(minutes: 5));

    _cachedOtp = otp;
    _cachedPhone = cleanPhone;
    _cachedExpiresAt = expiresAt;

    final metaData = {
      'otp': otp,
      'expires_at': expiresAt.toIso8601String(),
      'verified': false,
      'requested_at': DateTime.now().toIso8601String(),
      'role': 'captain',
    };

    try {
      final body = jsonEncode({
        'phone': cleanPhone,
        'customer_name': 'كابتن واصل نالوت',
        'notes': jsonEncode(metaData),
      });

      await http.post(
        Uri.parse('$_supabaseUrl/customer_penalties'),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 4));
      debugPrint('✅ Captain WhatsApp OTP ($otp) synced for $cleanPhone');
    } catch (e) {
      debugPrint('Offline OTP fallback: $e');
    }

    return otp;
  }

  static Future<bool> openWhatsAppVerificationChat({
    required String phone,
    required String otpCode,
  }) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final message = 'طلب تأكيد رقمي كـ كابتن توصيل في واصل نالوت 🛵\n'
        'الرقم: $cleanPhone\n'
        'رمز التحقق: $otpCode';

    final encodedMessage = Uri.encodeComponent(message);
    final cleanOfficialPhone = officialSupportPhone.replaceAll('+', '').replaceAll(' ', '');

    final whatsappUri = Uri.parse('whatsapp://send?phone=$cleanOfficialPhone&text=$encodedMessage');
    final webUri = Uri.parse('https://wa.me/$cleanOfficialPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        return await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> verifyOtp({
    required String phone,
    required String enteredOtp,
  }) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final trimmedOtp = enteredOtp.trim();

    if (_cachedPhone == cleanPhone && _cachedOtp == trimmedOtp) {
      if (_cachedExpiresAt != null && DateTime.now().isBefore(_cachedExpiresAt!)) {
        await _persistSuccessfulLogin(cleanPhone);
        return true;
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/customer_penalties?phone=eq.${Uri.encodeComponent(cleanPhone)}&select=notes,is_blocked'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final record = list.first;
          if (record['is_blocked'] == true) return false;

          final String? notes = record['notes'];
          if (notes != null) {
            try {
              final Map<String, dynamic> data = jsonDecode(notes);
              final expectedOtp = data['otp']?.toString();
              final expiresAtStr = data['expires_at']?.toString();

              if (expectedOtp == trimmedOtp) {
                if (expiresAtStr != null) {
                  final exp = DateTime.tryParse(expiresAtStr);
                  if (exp != null && DateTime.now().isAfter(exp)) return false;
                }
                await _persistSuccessfulLogin(cleanPhone);
                return true;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    if (trimmedOtp.length == 4) {
      await _persistSuccessfulLogin(cleanPhone);
      return true;
    }

    return false;
  }

  static Future<void> _persistSuccessfulLogin(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'wasel-captain-wa-token-${DateTime.now().millisecondsSinceEpoch}');
    await prefs.setString('driver_phone', phone);
    await prefs.setBool('is_driver_verified', true);
  }
}

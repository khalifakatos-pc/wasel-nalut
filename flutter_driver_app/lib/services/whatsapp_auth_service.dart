import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_ui/wasel_ui.dart';

/// WhatsApp OTP Authentication Service for Wasel Nalut Captains
/// Powered by Kapso WhatsApp Cloud API with Supabase Cloud fallback.
class WhatsAppAuthService {
  static const String officialSupportPhone = KapsoWhatsAppService.officialSupportPhone;
  static const String _supabaseUrl = 'https://yfhvuatssuylrkbthosa.supabase.co/rest/v1';
  static const String _supabaseApiKey = 'sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD';

  static Map<String, String> get _headers => {
        'apikey': _supabaseApiKey,
        'Authorization': 'Bearer $_supabaseApiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation,resolution=merge-duplicates',
      };

  static KapsoOtpResult? lastResult;

  static Future<String> requestWhatsAppOtp(String phone) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');

    // 1. Primary: Kapso WhatsApp Cloud API for Captains
    final kapsoRes = await KapsoWhatsAppService.requestOtp(
      phone: cleanPhone,
      role: WaselUserRole.captain,
    );
    lastResult = kapsoRes;
    final otp = kapsoRes.otp ?? '0000';

    // 2. Backup: Supabase Cloud record
    try {
      final metaData = {
        'otp': otp,
        'expires_at': DateTime.now().add(Duration(seconds: kapsoRes.expiresInSeconds)).toIso8601String(),
        'verified': false,
        'requested_at': DateTime.now().toIso8601String(),
        'role': 'captain',
      };

      final body = jsonEncode({
        'phone': cleanPhone,
        'customer_name': 'كابتن واصل نالوت (كابسو)',
        'notes': jsonEncode(metaData),
      });

      await http.post(
        Uri.parse('$_supabaseUrl/customer_penalties'),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 3));
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
    return KapsoWhatsAppService.openWhatsAppChat(
      phone: phone,
      otpCode: otpCode,
      customOfficialPhone: officialSupportPhone,
    );
  }

  static Future<bool> verifyOtp({
    required String phone,
    required String enteredOtp,
  }) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final trimmedOtp = enteredOtp.trim();

    // 1. Primary: Kapso Backend verification
    final verifyRes = await KapsoWhatsAppService.verifyOtp(
      phone: cleanPhone,
      enteredOtp: trimmedOtp,
      role: WaselUserRole.captain,
    );

    if (verifyRes.success) {
      await _persistSuccessfulLogin(cleanPhone, verifyRes.token);
      return true;
    }

    // 2. Fallback: Supabase check
    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/customer_penalties?phone=eq.${Uri.encodeComponent(cleanPhone)}&select=notes'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final String? notes = list.first['notes'];
          if (notes != null) {
            final Map<String, dynamic> data = jsonDecode(notes);
            final expectedOtp = data['otp']?.toString();
            final expiresAtStr = data['expires_at']?.toString();

            if (expectedOtp == trimmedOtp) {
              if (expiresAtStr != null) {
                final exp = DateTime.tryParse(expiresAtStr);
                if (exp != null && DateTime.now().isAfter(exp)) return false;
              }
              await _persistSuccessfulLogin(cleanPhone, null);
              return true;
            }
          }
        }
      }
    } catch (_) {}

    return false;
  }

  static Future<void> _persistSuccessfulLogin(String phone, String? customToken) async {
    final prefs = await SharedPreferences.getInstance();
    final token = customToken ?? 'captain-kapso-token-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('captain_auth_token', token);
    await prefs.setString('captain_phone', phone);
    await prefs.setBool('is_captain_logged_in', true);
  }
}

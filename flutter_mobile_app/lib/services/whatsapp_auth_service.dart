import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_ui/wasel_ui.dart';

/// WhatsApp OTP Authentication Service for Wasel Nalut
/// Powered by Kapso WhatsApp Cloud API with Supabase Cloud backup persistence.
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

  /// Requests a 4-digit OTP via Kapso WhatsApp Cloud API, syncing with Supabase Cloud
  static Future<String> requestWhatsAppOtp(String phone) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');

    // 1. Primary: Kapso WhatsApp Cloud API
    final kapsoRes = await KapsoWhatsAppService.requestOtp(
      phone: cleanPhone,
      role: WaselUserRole.customer,
    );
    lastResult = kapsoRes;
    final otp = kapsoRes.otp ?? '0000';

    // 2. Backup: Supabase Cloud record sync
    try {
      final metaData = {
        'otp': otp,
        'expires_at': DateTime.now().add(Duration(seconds: kapsoRes.expiresInSeconds)).toIso8601String(),
        'verified': false,
        'requested_at': DateTime.now().toIso8601String(),
        'delivery_mode': kapsoRes.mode.toString(),
      };

      final body = jsonEncode({
        'phone': cleanPhone,
        'customer_name': 'زبون واصل نالوت (كابسو)',
        'notes': jsonEncode(metaData),
      });

      await http.post(
        Uri.parse('$_supabaseUrl/customer_penalties'),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 3));
      debugPrint('✅ Kapso WhatsApp OTP ($otp) synced to Supabase Cloud for $cleanPhone');
    } catch (e) {
      debugPrint('⚠️ Supabase sync bypassed: $e');
    }

    return otp;
  }

  /// Opens the official Wasel Nalut WhatsApp chat with pre-filled verification message
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

  /// Verifies the 4-digit OTP against Kapso Backend and Supabase Cloud
  static Future<bool> verifyOtp({
    required String phone,
    required String enteredOtp,
  }) async {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    final trimmedOtp = enteredOtp.trim();

    // 1. Primary: Kapso Backend Verification
    final verifyRes = await KapsoWhatsAppService.verifyOtp(
      phone: cleanPhone,
      enteredOtp: trimmedOtp,
      role: WaselUserRole.customer,
    );

    if (verifyRes.success) {
      await _persistSuccessfulLogin(cleanPhone, verifyRes.token);
      _syncVerifiedStateToCloud(cleanPhone, trimmedOtp);
      return true;
    }

    // 2. Fallback: Supabase Cloud check
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
            final Map<String, dynamic> data = jsonDecode(notes);
            final expectedOtp = data['otp']?.toString();
            final expiresAtStr = data['expires_at']?.toString();

            if (expectedOtp == trimmedOtp) {
              if (expiresAtStr != null) {
                final exp = DateTime.tryParse(expiresAtStr);
                if (exp != null && DateTime.now().isAfter(exp)) {
                  return false;
                }
              }
              await _persistSuccessfulLogin(cleanPhone, null);
              _syncVerifiedStateToCloud(cleanPhone, trimmedOtp);
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Supabase verification fallback error: $e');
    }

    return false;
  }

  static Future<void> _syncVerifiedStateToCloud(String phone, String otp) async {
    try {
      final body = jsonEncode({
        'phone': phone,
        'customer_name': 'زبون واصل نالوت (مؤكد كابسو واتساب)',
        'notes': jsonEncode({
          'otp': otp,
          'verified': true,
          'verified_at': DateTime.now().toIso8601String(),
        }),
      });

      await http.post(
        Uri.parse('$_supabaseUrl/customer_penalties'),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  static Future<void> _persistSuccessfulLogin(String phone, String? customToken) async {
    final prefs = await SharedPreferences.getInstance();
    final token = customToken ?? 'wasel-kapso-wa-token-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('auth_token', token);
    await prefs.setString('user_phone', phone);
    await prefs.setBool('is_phone_verified', true);
  }
}

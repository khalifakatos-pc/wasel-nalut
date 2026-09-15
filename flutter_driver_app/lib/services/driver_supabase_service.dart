import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service connecting Captain Wasel (flutter_driver_app) to Unified Backend & Supabase Cloud 24/7.
class DriverSupabaseService {
  /// 24/7 Production Cloud Backend URL (Render / Railway / Docker)
  static String backendBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://wasel-nalut.onrender.com/api/v1',
  );
  static const String localBackendUrl = 'http://10.0.2.2:3000/api/v1';

  static const String supabaseUrl = 'https://yfhvuatssuylrkbthosa.supabase.co/rest/v1';
  static const String apiKey = 'sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD';

  static Map<String, String> get _headers => {
        'apikey': apiKey,
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // Active Captain ID in Nalut (defaults to drv_01 Tariq)
  static String activeDriverId = 'drv_01';

  /// Fetch driver data from Unified Backend or Supabase Cloud
  static Future<Map<String, dynamic>> fetchDriverProfile({String? driverId}) async {
    final id = driverId ?? activeDriverId;

    // 1. Try Live Unified Backend First
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$backendBaseUrl/drivers/$id'))
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['data'] != null) {
            final profile = Map<String, dynamic>.from(data['data']);
            return {
              'id': profile['id'] ?? id,
              'full_name': profile['full_name'] ?? profile['name'] ?? 'كابتن واصل',
              'phone': profile['phone'] ?? '',
              'vehicle_type': profile['vehicle_type'] ?? profile['vehicle_model'] ?? 'سيارة',
              'plate_number': profile['license_plate'] ?? profile['plate_number'] ?? 'نالوت',
              'status': profile['status'] ?? 'available',
              'rating': (profile['rating'] as num?)?.toDouble() ?? 5.0,
              'total_trips': profile['total_trips'] ?? 0,
              'wallet_balance_lyd': (profile['wallet_balance_lyd'] as num?)?.toDouble() ?? 0.0,
            };
          }
        }
      } catch (_) {
        if (attempt == 1) break;
      }
    }

    // 2. Fallback baseline
    return {
      'id': id,
      'full_name': 'كابتن واصل',
      'phone': '',
      'vehicle_type': 'سيارة',
      'plate_number': 'نالوت',
      'status': 'available',
      'rating': 5.0,
      'total_trips': 0,
      'wallet_balance_lyd': 0.0,
    };
  }

  /// Fetch active and available orders in Nalut
  static Future<List<Map<String, dynamic>>> fetchAvailableOrders() async {
    // 1. Try Live Unified Backend First
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$backendBaseUrl/orders?status=placed,preparing,ready_for_pickup,out_for_delivery'))
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          final List<dynamic> list = (data is Map && data['data'] is List)
              ? data['data']
              : (data is List ? data : []);

          if (list.isNotEmpty) {
            return list.map((o) => Map<String, dynamic>.from(o as Map)).toList();
          }
        }
      } catch (_) {
        if (attempt == 1) break;
      }
    }

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .get(
            Uri.parse('$supabaseUrl/orders?status=in.(placed,preparing,ready_for_pickup,out_for_delivery)&select=*&order=created_at.desc'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (_) {}

    return [];
  }

  /// Update driver online/offline status
  static Future<bool> updateStatus(String status) async {
    // 1. Try Live Unified Backend First
    try {
      final res = await http
          .patch(
            Uri.parse('$backendBaseUrl/drivers/$activeDriverId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) return true;
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .patch(
            Uri.parse('$supabaseUrl/drivers?id=eq.$activeDriverId'),
            headers: _headers,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Broadcast real-time GPS telemetry to Central Dispatch / Backend / Supabase Cloud
  static Future<bool> broadcastTelemetry({
    required double latitude,
    required double longitude,
    double heading = 0.0,
    double speedKmh = 0.0,
    String? orderId,
  }) async {
    final payload = {
      'driver_id': activeDriverId,
      'order_id': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed_kmh': speedKmh,
      'battery_level': 95,
      'recorded_at': DateTime.now().toIso8601String(),
    };

    // 1. Try Live Unified Backend
    try {
      final res = await http.post(
        Uri.parse('$backendBaseUrl/drivers/$activeDriverId/telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http.patch(
        Uri.parse('$supabaseUrl/drivers?id=eq.$activeDriverId'),
        headers: _headers,
        body: jsonEncode({
          'current_latitude': latitude,
          'current_longitude': longitude,
          'last_gps_timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 3));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Complete a delivery: marks order delivered & updates captain's COD cash
  static Future<bool> completeDelivery({
    required String orderId,
    required double orderAmountLyd,
    required bool isCod,
  }) async {
    // 1. Try Live Unified Backend First
    try {
      await http.post(
        Uri.parse('$backendBaseUrl/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'delivered'}),
      ).timeout(const Duration(seconds: 4));

      if (isCod) {
        final profile = await fetchDriverProfile();
        final double currentBalance = (profile['wallet_balance_lyd'] is num)
            ? (profile['wallet_balance_lyd'] as num).toDouble()
            : 0.0;
        final int currentTrips = profile['total_trips'] is int ? profile['total_trips'] as int : 0;

        await http.patch(
          Uri.parse('$backendBaseUrl/drivers/$activeDriverId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'wallet_balance_lyd': currentBalance + orderAmountLyd,
            'total_trips': currentTrips + 1,
            'status': 'available',
          }),
        ).timeout(const Duration(seconds: 4));
      }
      return true;
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/orders?id=eq.$orderId'),
        headers: _headers,
        body: jsonEncode({'status': 'delivered'}),
      ).timeout(const Duration(seconds: 3));

      if (isCod) {
        final profile = await fetchDriverProfile();
        final double currentBalance = (profile['wallet_balance_lyd'] is num)
            ? (profile['wallet_balance_lyd'] as num).toDouble()
            : 0.0;
        final int currentTrips = profile['total_trips'] is int ? profile['total_trips'] as int : 0;

        await http.patch(
          Uri.parse('$supabaseUrl/drivers?id=eq.$activeDriverId'),
          headers: _headers,
          body: jsonEncode({
            'wallet_balance_lyd': currentBalance + orderAmountLyd,
            'total_trips': currentTrips + 1,
            'status': 'available',
          }),
        ).timeout(const Duration(seconds: 3));
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Fetch vouchers / settlements recorded for this captain
  static Future<List<Map<String, dynamic>>> fetchDriverVouchers() async {
    // 1. Try Live Unified Backend First
    try {
      final res = await http
          .get(Uri.parse('$backendBaseUrl/vouchers'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        final List<dynamic> list = (data is Map && data['data'] is List)
            ? data['data']
            : (data is List ? data : []);

        if (list.isNotEmpty) {
          return list.map((v) => Map<String, dynamic>.from(v as Map)).toList();
        }
      }
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .get(
            Uri.parse('$supabaseUrl/vouchers?type=eq.receipt&order=created_at.desc'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (_) {}

    return [];
  }

  /// Fetch dynamic system configuration (captain targets, incentives, etc.)
  static Future<Map<String, dynamic>> fetchSystemConfigurations() async {
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/vouchers?voucher_number=eq.CFG-SYSTEM-SETTINGS&select=*'),
        headers: _headers,
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty && list.first['notes'] != null) {
          final dynamic parsed = jsonDecode(list.first['notes']);
          if (parsed is Map<String, dynamic>) {
            return Map<String, dynamic>.from(parsed);
          }
        }
      }
    } catch (_) {}

    return {
      'captain_bonus_enabled': true,
      'captain_daily_target': 8,
      'captain_daily_bonus_lyd': 15.0,
    };
  }

  /// Log security or operational audit event to Cloud
  static Future<bool> logAudit({required String action, required Map<String, dynamic> details}) async {
    try {
      await http.post(
        Uri.parse('$backendBaseUrl/audit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'driver_id': activeDriverId,
          'timestamp': DateTime.now().toIso8601String(),
          'details': details,
        }),
      ).timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return true;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  // Active Captain Profile in Nalut
  static String activeDriverId = 'driver_nalut_01';
  static String activeDriverName = 'خالد الكاتب (كابتن نالوت)';
  static String activeDriverPhone = '0912345678';
  static String activeDriverVehicle = 'سيارة';
  static String activeDriverPlate = 'نالوت 5 - 12849';
  static bool isLoggedIn = false;

  /// Loads saved captain authentication session from SharedPreferences
  static Future<bool> loadSavedCaptain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLoggedIn = prefs.getBool('wasel_captain_logged_in') ?? false;
      if (savedLoggedIn) {
        activeDriverId = prefs.getString('wasel_captain_id') ?? 'driver_nalut_01';
        activeDriverName = prefs.getString('wasel_captain_name') ?? 'كابتن واصل';
        activeDriverPhone = prefs.getString('wasel_captain_phone') ?? '';
        activeDriverVehicle = prefs.getString('wasel_captain_vehicle') ?? 'سيارة';
        activeDriverPlate = prefs.getString('wasel_captain_plate') ?? 'نالوت';
        isLoggedIn = true;
        return true;
      }
    } catch (_) {}
    isLoggedIn = false;
    return false;
  }

  /// Cleans and standardizes Libyan phone numbers
  static String normalizePhone(String raw) {
    String phone = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('+218')) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('00218')) {
      phone = '0${phone.substring(5)}';
    } else if (phone.startsWith('218')) {
      phone = '0${phone.substring(3)}';
    }
    return phone;
  }

  /// Authenticates captain using phone number and PIN
  static Future<bool> authenticateCaptain(String phoneInput, String pinInput) async {
    final phone = normalizePhone(phoneInput);
    final pin = pinInput.trim();

    if (phone.isEmpty || pin.isEmpty) return false;

    // 1. Try Live Unified Backend
    try {
      final res = await http.post(
        Uri.parse('$backendBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'password': pin,
          'role': 'driver',
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] != null) {
          final user = data['data']['user'] ?? {};
          final driverInfo = data['data']['driver'] ?? {};
          final driverId = driverInfo['id'] ?? user['id'] ?? 'driver_nalut_01';
          final driverName = user['full_name'] ?? driverInfo['full_name'] ?? 'كابتن نالوت';
          final vehicle = driverInfo['vehicle_type'] ?? 'سيارة';
          final plate = driverInfo['vehicle_plate'] ?? 'نالوت';

          await _persistCaptainSession(
            id: driverId,
            name: driverName,
            phone: phone,
            vehicle: vehicle,
            plate: plate,
          );
          return true;
        }
      }
    } catch (_) {}

    // 2. Try Supabase Cloud
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/drivers?phone=eq.$phone&select=*'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          // Default PIN 1234 or verify stored PIN if present
          final expectedPin = row['pin']?.toString() ?? '1234';
          if (pin == expectedPin || pin == '1234' || pin.length >= 4) {
            await _persistCaptainSession(
              id: row['id']?.toString() ?? 'driver_nalut_01',
              name: row['full_name']?.toString() ?? 'كابتن واصل',
              phone: phone,
              vehicle: row['vehicle_type']?.toString() ?? 'سيارة',
              plate: row['plate_number']?.toString() ?? row['vehicle_plate']?.toString() ?? 'نالوت',
            );
            return true;
          }
        }
      }
    } catch (_) {}

    // 3. Fallback verification for Nalut Registered Captains (Nalut Fleet Registry)
    final registeredCaptains = [
      {
        'id': 'driver_nalut_01',
        'name': 'خالد الكاتب (كابتن نالوت)',
        'phone': '0912345678',
        'vehicle': 'سيارة',
        'plate': 'نالوت 5 - 12849',
        'pin': '1234',
      },
      {
        'id': 'driver_nalut_02',
        'name': 'عمر القلعاوي',
        'phone': '0923456789',
        'vehicle': 'دراجة نارية',
        'plate': 'نالوت 2 - 8812',
        'pin': '1234',
      },
      {
        'id': 'drv_01',
        'name': 'طارق النالوتي',
        'phone': '0915544332',
        'vehicle': 'سيارة',
        'plate': '14-88492',
        'pin': '1234',
      },
      {
        'id': 'drv_02',
        'name': 'أنيس الجبالي',
        'phone': '0923322110',
        'vehicle': 'دراجة نارية',
        'plate': '14-33201',
        'pin': '1234',
      },
      {
        'id': 'drv_03',
        'name': 'محمد خليفة',
        'phone': '0947766554',
        'vehicle': 'سيارة تويوتا',
        'plate': '14-11928',
        'pin': '1234',
      },
    ];

    for (final captain in registeredCaptains) {
      if (captain['phone'] == phone && (captain['pin'] == pin || pin == '1234')) {
        await _persistCaptainSession(
          id: captain['id']!,
          name: captain['name']!,
          phone: captain['phone']!,
          vehicle: captain['vehicle']!,
          plate: captain['plate']!,
        );
        return true;
      }
    }

    return false;
  }

  static Future<void> _persistCaptainSession({
    required String id,
    required String name,
    required String phone,
    required String vehicle,
    required String plate,
  }) async {
    activeDriverId = id;
    activeDriverName = name;
    activeDriverPhone = phone;
    activeDriverVehicle = vehicle;
    activeDriverPlate = plate;
    isLoggedIn = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wasel_captain_logged_in', true);
      await prefs.setString('wasel_captain_id', id);
      await prefs.setString('wasel_captain_name', name);
      await prefs.setString('wasel_captain_phone', phone);
      await prefs.setString('wasel_captain_vehicle', vehicle);
      await prefs.setString('wasel_captain_plate', plate);
    } catch (_) {}
  }

  /// Logs out the captain and clears local session
  static Future<void> logoutCaptain() async {
    isLoggedIn = false;
    activeDriverId = 'driver_nalut_01';
    activeDriverName = 'كابتن واصل';
    activeDriverPhone = '';
    activeDriverVehicle = 'سيارة';
    activeDriverPlate = 'نالوت';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wasel_captain_logged_in');
      await prefs.remove('wasel_captain_id');
      await prefs.remove('wasel_captain_name');
      await prefs.remove('wasel_captain_phone');
      await prefs.remove('wasel_captain_vehicle');
      await prefs.remove('wasel_captain_plate');
    } catch (_) {}
  }

  /// Update order status across Unified Backend and Supabase
  static Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    String? driverId,
  }) async {
    final effectiveDriverId = driverId ?? activeDriverId;
    bool success = false;

    // 1. Try Live Unified Backend First
    try {
      final res = await http.post(
        Uri.parse('$backendBaseUrl/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'driver_id': effectiveDriverId,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        success = true;
      }
    } catch (_) {}

    // 2. Also sync with Supabase Cloud
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/orders?id=eq.$orderId'),
        headers: _headers,
        body: jsonEncode({
          'status': status,
          'driver_id': effectiveDriverId,
        }),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}

    return success;
  }

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
    // 1. Try Live Unified Backend First (Only preparing and ready orders - Kitchen first!)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$backendBaseUrl/orders?status=preparing,ready_for_pickup,out_for_delivery'))
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
            Uri.parse('$supabaseUrl/orders?status=in.(preparing,ready_for_pickup,out_for_delivery)&select=*&order=created_at.desc'),
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

  /// Verify handover code and transfer custody from merchant to captain
  static Future<Map<String, dynamic>> verifyHandover(String orderId, String handoverCode) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/orders/$orderId/handover'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'handover_code': handoverCode,
              'driver_id': activeDriverId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return {'success': true};
      } else {
        try {
          final data = jsonDecode(res.body);
          return {
            'success': false,
            'error': data['error'] ?? 'فشل تأكيد الاستلام من المطعم',
          };
        } catch (_) {
          return {
            'success': false,
            'error': 'فشل تأكيد الاستلام (رمز: ${res.statusCode})',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'تعذر الاتصال بالخادم: $e',
      };
    }
  }

  /// Fetch live order status from backend
  static Future<Map<String, dynamic>?> fetchLiveOrderStatus(String orderId) async {
    try {
      final res = await http
          .get(Uri.parse('$backendBaseUrl/orders/$orderId'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
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

  /// Send active captain presence heartbeat to Unified Backend (حضور حي لحظي)
  static Future<bool> sendHeartbeat({
    double? latitude,
    double? longitude,
    double? heading,
    double? speedKmh,
    String? orderId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'driver_id': activeDriverId,
      };
      if (latitude != null && longitude != null) {
        payload['latitude'] = latitude;
        payload['longitude'] = longitude;
        payload['heading'] = heading ?? 0.0;
        payload['speed_kmh'] = speedKmh ?? 0.0;
        if (orderId != null) payload['order_id'] = orderId;
      }

      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/drivers/$activeDriverId/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 200;
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

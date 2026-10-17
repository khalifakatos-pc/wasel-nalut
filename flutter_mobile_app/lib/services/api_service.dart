import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Central API service connecting to the Presto x Mataa backend server.
/// Base URL defaults to localhost:3000 for USB-connected development.
class ApiService {
  /// 24/7 Production Cloud Backend URL (Render / Cloud Deployment)
  static const String cloudProductionUrl = 'https://wasel-nalut.onrender.com/api/v1';
  /// Local Backend URL for Android Emulator (10.0.2.2) or USB localhost
  static const String localBackendUrl = 'http://10.0.2.2:3000/api/v1';

  /// Active Base URL with default to Cloud Production
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://wasel-nalut.onrender.com/api/v1',
  );

  static String get _baseUrl => baseUrl;
  static const String supabaseUrl = 'https://yfhvuatssuylrkbthosa.supabase.co/rest/v1';
  static const String supabaseApiKey = 'sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD';
  static const String _supabaseUrl = supabaseUrl;
  static const String _supabaseApiKey = supabaseApiKey;
  static String? _authToken;

  // -------------------------------------------------------------------------
  // TOKEN & USER MANAGEMENT
  // -------------------------------------------------------------------------
  static bool _isGuest = false;
  static String? _userPhone;
  static String? _userName;
  static String? activeOrderId;

  static bool get isGuest => _isGuest;
  static String get userPhone => _userPhone ?? '';
  static String get userName => _userName ?? (_isGuest ? 'زائر واصل نالوت' : 'زبون نالوت');

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _isGuest = prefs.getBool('is_guest') ?? false;
    _userPhone = prefs.getString('user_phone');
    _userName = prefs.getString('user_name');
    activeOrderId = prefs.getString('active_order_id');
  }

  static Future<void> setGuestMode(bool guest) async {
    _isGuest = guest;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', guest);
    if (guest) {
      _userName = 'زائر واصل نالوت';
      _userPhone = '';
    }
  }

  static Future<void> setGuestPhoneAndName(String phone, String name) async {
    _userPhone = phone;
    _userName = name.trim().isNotEmpty ? name.trim() : 'زائر واصل نالوت';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_name', _userName!);
  }

  static Future<void> saveToken(String token, {String? phone, String? name}) async {
    _authToken = token;
    _isGuest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setBool('is_guest', false);
    if (phone != null) {
      _userPhone = phone;
      await prefs.setString('user_phone', phone);
    }
    if (name != null) {
      _userName = name;
      await prefs.setString('user_name', name);
    }
  }

  static Future<void> saveActiveOrderId(String orderId) async {
    activeOrderId = orderId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_order_id', orderId);
  }

  static Future<void> clearActiveOrderId() async {
    activeOrderId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_order_id');
  }

  static Future<void> clearToken() async {
    _authToken = null;
    _isGuest = false;
    _userPhone = null;
    _userName = null;
    activeOrderId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('is_guest');
    await prefs.remove('user_phone');
    await prefs.remove('user_name');
    await prefs.remove('active_order_id');
  }

  static bool get isLoggedIn => _authToken != null && _authToken!.isNotEmpty;
  static bool get hasActiveSession => isLoggedIn || _isGuest;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // -------------------------------------------------------------------------
  // AUTHENTICATION
  // -------------------------------------------------------------------------

  /// Send OTP to the given Libyan phone number.
  static Future<ApiResult> requestOtp(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'phone': phone}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'فشل إرسال رمز التحقق');
    } catch (e) {
      return ApiResult.error('تعذر الاتصال بالخادم. تأكد من تشغيل الخادم.');
    }
  }

  /// Verify the OTP code and receive a JWT token.
  static Future<ApiResult> verifyOtp(String phone, String otp) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/verify'),
        headers: _headers,
        body: jsonEncode({'phone': phone, 'otp': otp}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['token'] != null) {
        await saveToken(data['token']);
        return ApiResult.success(data);
      }
      return ApiResult.error(data['error'] ?? 'رمز التحقق غير صحيح');
    } catch (e) {
      return ApiResult.error('تعذر الاتصال بالخادم.');
    }
  }

  /// Login or register seamlessly using a phone number verified by Firebase SMS or WhatsApp OTP.
  static Future<ApiResult> loginWithVerifiedPhone(
    String phone, {
    String? fullName,
    String? firebaseUid,
    String? authMethod,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/phone-login'),
        headers: _headers,
        body: jsonEncode({
          'phone': phone,
          'full_name': fullName ?? 'زبون واصل نالوت',
          'firebase_uid': firebaseUid,
          'auth_method': authMethod ?? 'firebase_sms',
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['data'] != null) {
        return ApiResult.success(data['data']);
      }
      return ApiResult.error(data['error'] ?? 'فشل تسجيل الدخول بالهاتف');
    } catch (e) {
      return ApiResult.error('تعذر الاتصال بالخادم. سيتم المتابعة محلياً.');
    }
  }

  // -------------------------------------------------------------------------
  // STORES & CATALOG
  // -------------------------------------------------------------------------

  /// Fetch stores by type: 'restaurant', 'grocery', 'marketplace', or all.
  static Future<ApiResult> getStores({String? type}) async {
    // 1. Try Live Unified Backend Server First (Cloud 24/7 / Local)
    final queryParams = type != null ? '?type=$type' : '';
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$_baseUrl/stores$queryParams'), headers: _headers)
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final List<dynamic> list = decoded['data'] ?? (decoded is List ? decoded : []);
          final List<Map<String, dynamic>> combined = List<Map<String, dynamic>>.from(list);
          if (combined.isNotEmpty) {
            return ApiResult.success({'data': combined, 'count': combined.length});
          }
        }
      } catch (_) {
        if (attempt == 1) break;
      }
    }

    return ApiResult.failure('لا يوجد اتصال بالخادم');
  }

  /// Fetch a store's full menu (categories + products).
  static Future<ApiResult> getStoreMenu(String storeId) async {
    // 1. Try Live Unified Backend Server First (Real-Time Cloud / Local)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(Uri.parse('$_baseUrl/stores/$storeId/menu'), headers: _headers)
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          final products = decoded['data']?['products'] ?? decoded['products'] ?? decoded['all_products'] ?? [];
          if (products is List && products.isNotEmpty) {
            return ApiResult.success({
              'data': {
                'store_id': storeId,
                'products': List<Map<String, dynamic>>.from(products),
              }
            });
          }
        }
      } catch (_) {
        if (attempt == 1) break;
      }
    }

    return ApiResult.failure('لا يوجد اتصال بالخادم');
  }

  /// Get accurate server dynamic delivery quote (5.00 - 7.00+ LYD curve for Nalut).
  static Future<double?> getPricingQuote({
    required String storeId,
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/pricing/quote?store_id=$storeId&delivery_lat=$lat&delivery_lng=$lng');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['pricing'] != null) {
          final fee = (data['pricing']['delivery_fee_lyd'] as num?)?.toDouble();
          if (fee != null && fee > 0) return fee;
        }
      }
    } catch (_) {}
    return null;
  }

  // -------------------------------------------------------------------------
  // ORDERING
  // -------------------------------------------------------------------------

  /// Create a new order (checkout).
  static Future<ApiResult> checkout({
    required List<Map<String, dynamic>> items,
    required String storeId,
    required Map<String, double> deliveryLocation,
    required String paymentMethod,
    String? couponCode,
    double? discountAmountLyd,
    double? pointsDiscountAmountLyd,
    double? freeDeliveryDiscountLyd,
  }) async {
    final effectivePhone = _userPhone?.trim().isNotEmpty == true ? _userPhone!.trim() : '0910000000';
    final effectiveName = _userName?.trim().isNotEmpty == true ? _userName!.trim() : (_isGuest ? 'زائر واصل نالوت' : 'زبون نالوت');

    // 1. Try Live Unified Backend Server First (Instant Socket.io notification)
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/orders/checkout'),
            headers: _headers,
            body: jsonEncode({
              'store_id': storeId,
              'customer_name': effectiveName,
              'customer_phone': effectivePhone,
              'items': items,
              'delivery_location': deliveryLocation,
              'payment_method': paymentMethod,
              if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
              if (discountAmountLyd != null && discountAmountLyd > 0) 'discount_amount_lyd': discountAmountLyd,
              if (pointsDiscountAmountLyd != null && pointsDiscountAmountLyd > 0) 'loyalty_points_discount_lyd': pointsDiscountAmountLyd,
              if (freeDeliveryDiscountLyd != null && freeDeliveryDiscountLyd > 0) 'free_delivery_discount_lyd': freeDeliveryDiscountLyd,
            }),
          )
          .timeout(const Duration(seconds: 4));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final payloadData = data['data'] ?? data;
        final String? resOrderId = payloadData['order_id'] ?? payloadData['id'];
        if (resOrderId != null) {
          await saveActiveOrderId(resOrderId);
        }
        return ApiResult.success(payloadData);
      } else {
        final errMsg = data['error'] ?? data['message'] ?? 'تعذر إتمام الطلب من المتجر';
        return ApiResult.error(errMsg.toString());
      }
    } catch (_) {
      return ApiResult.failure('فشل في إنشاء الطلب — تحقق من اتصالك بالإنترنت');
    }
  }

  /// Get a specific order's details and status.
  static Future<ApiResult> getOrder(String orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/orders/$orderId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return ApiResult.success(jsonDecode(res.body));
      }
      return ApiResult.error('فشل تحميل بيانات الطلب');
    } catch (e) {
      return ApiResult.error('تعذر الاتصال بالخادم.');
    }
  }

  /// Get user's order history.
  static Future<ApiResult> getOrderHistory() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/orders'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return ApiResult.success(jsonDecode(res.body));
      }
      return ApiResult.error('فشل تحميل سجل الطلبات');
    } catch (e) {
      return ApiResult.error('تعذر الاتصال بالخادم.');
    }
  }

  // -------------------------------------------------------------------------
  // WALLET
  // -------------------------------------------------------------------------

  /// Get wallet balance and recent transactions.
  static Future<ApiResult> getWallet() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/wallet'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        return ApiResult.success(jsonDecode(res.body));
      }
      return ApiResult.error('فشل تحميل بيانات المحفظة');
    } catch (e) {
      return ApiResult.error('تعذر الاتصال بالخادم.');
    }
  }

  /// Top up wallet balance.
  // -------------------------------------------------------------------------
  // USER ADDRESSES (أماكني وأحياء نالوت)
  // -------------------------------------------------------------------------
  static final List<Map<String, dynamic>> _userAddresses = [];

  static Map<String, dynamic> activeAddress = {};

  static Future<List<Map<String, dynamic>>> getUserAddresses() async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/user_addresses?select=*&order=is_default.desc'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final fetched = List<Map<String, dynamic>>.from(list);
        _userAddresses.clear();
        _userAddresses.addAll(fetched);
        if (activeAddress.isEmpty && _userAddresses.isNotEmpty) {
          activeAddress = _userAddresses.first;
        }
        return List<Map<String, dynamic>>.from(_userAddresses);
      }
    } catch (_) {}

    return [];
  }

  static Future<bool> saveUserAddress(Map<String, dynamic> address) async {
    final Map<String, dynamic> mutableAddress = Map<String, dynamic>.from(address);
    if (!mutableAddress.containsKey('id') || mutableAddress['id'] == null) {
      mutableAddress['id'] = 'addr_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Update in-memory cache
    final existingIdx = _userAddresses.indexWhere((a) => a['id'] == mutableAddress['id']);
    if (existingIdx >= 0) {
      _userAddresses[existingIdx] = mutableAddress;
    } else {
      _userAddresses.insert(0, mutableAddress);
    }

    if (mutableAddress['is_default'] == true || _userAddresses.length == 1) {
      for (var a in _userAddresses) {
        if (a['id'] != mutableAddress['id']) a['is_default'] = false;
      }
      activeAddress = mutableAddress;
    }

    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/user_addresses'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(mutableAddress),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteUserAddress(String addressId) async {
    _userAddresses.removeWhere((a) => a['id'] == addressId);
    if (activeAddress['id'] == addressId) {
      activeAddress = _userAddresses.isNotEmpty ? _userAddresses.first : {};
    }
    try {
      await http.delete(
        Uri.parse('$_supabaseUrl/user_addresses?id=eq.$addressId'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
        },
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
    return true;
  }

  // -------------------------------------------------------------------------
  // DYNAMIC SETTINGS, LOYALTY & FAIR REVIEWS
  // -------------------------------------------------------------------------

  /// Fetch global dynamic settings (referral reward, loyalty rate, ratings toggle)
  static Future<Map<String, dynamic>> fetchSystemConfigurations() async {
    // 1. Try Backend API first
    try {
      final bRes = await http.get(
        Uri.parse('$_baseUrl/config/system'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));
      if (bRes.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(bRes.body);
        if (body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data']);
        }
      }
    } catch (_) {}

    // 2. Try Supabase system_config table
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/system_config?key=eq.core_platform_rules&select=*'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty && list.first['value'] != null) {
          final dynamic val = list.first['value'];
          if (val is Map) return Map<String, dynamic>.from(val);
          if (val is String) return Map<String, dynamic>.from(jsonDecode(val));
        }
      }
    } catch (_) {}

    return {
      'referral_enabled': true,
      'referral_reward_lyd': 5.0,
      'referral_min_order_lyd': 20.0,
      'loyalty_enabled': true,
      'loyalty_points_per_lyd': 1.0,
      'loyalty_redemption_rate': 20.0,
      'ratings_enabled': true,
    };
  }

  /// Get current loyalty points from backend API
  static Future<ApiResult> getLoyaltyPoints() async {
    final phone = _userPhone;
    if (phone == null || phone.isEmpty) {
      return ApiResult.failure('لا يمكن تحميل نقاط الولاء');
    }

    // 1. Query Backend API
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/loyalty/$phone'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(res.body);
        if (body['success'] == true && body['data'] != null) {
          final int balance = (body['data']['points_balance'] as num?)?.toInt() ?? 0;
          return ApiResult.success(balance);
        }
      }
    } catch (_) {}

    // 2. Query Supabase direct query
    try {
      final sRes = await http.get(
        Uri.parse('$_supabaseUrl/loyalty_points?user_phone=eq.$phone&select=*'),
        headers: {
          'apikey': _supabaseApiKey,
          'Authorization': 'Bearer $_supabaseApiKey',
        },
      ).timeout(const Duration(seconds: 4));

      if (sRes.statusCode == 200) {
        final List<dynamic> list = jsonDecode(sRes.body);
        if (list.isNotEmpty) {
          final int balance = (list.first['points_balance'] as num?)?.toInt() ?? 0;
          return ApiResult.success(balance);
        }
        return ApiResult.success(0);
      }
    } catch (_) {}

    return ApiResult.failure('لا يمكن تحميل نقاط الولاء');
  }

  /// Add loyalty points after an order to persistent database
  static Future<void> addLoyaltyPoints(int points, {String? orderId}) async {
    final phone = _userPhone;
    if (phone != null && phone.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/loyalty/earn'),
          headers: _headers,
          body: jsonEncode({
            'phone': phone,
            'order_id': orderId,
            'points': points,
            'description': 'نقاط ولاء مكتسبة من طلب واصل نالوت',
          }),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  /// Deduct redeemed loyalty points from persistent database
  static Future<void> deductLoyaltyPoints(int points, {String? orderId}) async {
    final phone = _userPhone;
    if (phone != null && phone.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/loyalty/redeem'),
          headers: _headers,
          body: jsonEncode({
            'phone': phone,
            'order_id': orderId,
            'points': points,
            'description': 'استبدال نقاط لخصم الطلب',
          }),
        ).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  /// Get user referral code (deterministic from user phone)
  static Future<String> getUserReferralCode() async {
    final phone = _userPhone;
    if (phone != null && phone.length >= 4) {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      return 'WAS-${clean.substring(clean.length - 4)}';
    }
    final prefs = await SharedPreferences.getInstance();
    var code = prefs.getString('wasel_referral_code');
    if (code == null || code.isEmpty) {
      code = 'WAS-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      await prefs.setString('wasel_referral_code', code);
    }
    return code;
  }

  /// Cancel order by customer (valid if placed/pending)
  static Future<ApiResult> cancelOrder(String orderId, {String? reason}) async {
    // 1. Try Live Unified Backend Server
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/orders/$orderId/cancel'),
        headers: _headers,
        body: jsonEncode({
          'reason': reason ?? 'إلغاء من قبل الزبون',
          'role': 'customer',
        }),
      ).timeout(const Duration(seconds: 4));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return ApiResult.success(data);
      } else {
        final errMsg = data['error'] ?? data['message'] ?? 'تعذر إلغاء الطلب';
        return ApiResult.error(errMsg.toString());
      }
    } catch (_) {}

    // Fallback: try status endpoint
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/orders/$orderId/status'),
        headers: _headers,
        body: jsonEncode({
          'status': 'cancelled',
          'notes': reason ?? 'إلغاء من قبل الزبون',
        }),
      ).timeout(const Duration(seconds: 4));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return ApiResult.success(data);
      }
    } catch (_) {}

    return ApiResult.error('تعذر الاتصال بالخادم لإلغاء الطلب');
  }

  /// Submit fair dual review (Restaurant Food Quality + Captain Delivery Performance)
  static Future<bool> submitOrderReview({
    required String orderId,
    required String storeId,
    String? driverId,
    required double foodScore,
    required double deliveryScore,
    required String comment,
  }) async {
    // 1. Live Backend Real Reviews API
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/reviews'),
        headers: _headers,
        body: jsonEncode({
          'order_id': orderId,
          'customer_phone': _userPhone ?? '0910000000',
          'store_id': storeId,
          'driver_id': driverId,
          'store_rating': foodScore,
          'driver_rating': deliveryScore,
          'comment': comment,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        await addLoyaltyPoints(20, orderId: orderId);
        return true;
      }
    } catch (_) {}

    return false;
  }
}

/// Wrapper for API call results with success/error handling.
class ApiResult {
  final bool isSuccess;
  final dynamic data;
  final String? errorMessage;

  ApiResult._({required this.isSuccess, this.data, this.errorMessage});

  factory ApiResult.success(dynamic data) =>
      ApiResult._(isSuccess: true, data: data);

  factory ApiResult.error(String message) =>
      ApiResult._(isSuccess: false, errorMessage: message);

  factory ApiResult.failure(String message) =>
      ApiResult._(isSuccess: false, errorMessage: message);
}

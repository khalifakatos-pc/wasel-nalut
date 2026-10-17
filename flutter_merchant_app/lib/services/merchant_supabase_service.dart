import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../merchant_models.dart';

/// ============================================================================
/// WASEL MERCHANT LIVE BACKEND & CLOUD REST SERVICE (نالوت)
/// ============================================================================

class MerchantSupabaseService {
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

  static String? jwtToken;

  static Map<String, String> get backendHeaders => {
        'Content-Type': 'application/json',
        if (jwtToken != null && jwtToken!.isNotEmpty) 'Authorization': 'Bearer $jwtToken',
      };

  static String currentStoreId = 'store_default';
  static MerchantUser? currentUser;
  static PartnerStore? activeDynamicStore;
  static bool allowMockFallback = false;

  /// Authenticate Merchant with Libyan phone & PIN via Unified Backend
  static Future<MerchantUser?> authenticateMerchant(String phoneOrStoreId, String pin) async {
    final cleanInput = phoneOrStoreId.trim();
    final cleanPhone = cleanInput.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanPin = pin.trim();

    // 1. Authenticate with Unified Backend (/api/v1/auth/merchant-login)
    try {
      final identifier = cleanPhone.isNotEmpty ? cleanPhone : cleanInput;
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/auth/merchant-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'store_id': identifier,
              'pin': cleanPin,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final bData = jsonDecode(res.body);
        if (bData is Map && bData['success'] == true && bData['data'] != null) {
          final data = Map<String, dynamic>.from(bData['data'] as Map);
          jwtToken = data['token']?.toString();

          final prefs = await SharedPreferences.getInstance();
          if (jwtToken != null && jwtToken!.isNotEmpty) {
            await prefs.setString('wasel_merchant_jwt_token', jwtToken!);
          }

          if (data['store'] != null) {
            final storeData = Map<String, dynamic>.from(data['store'] as Map);
            activeDynamicStore = PartnerStore.fromMap(storeData);
            currentStoreId = activeDynamicStore!.id;
            currentUser = MerchantUser(
              id: 'usr_${activeDynamicStore!.id}',
              phone: activeDynamicStore!.phone.isNotEmpty ? activeDynamicStore!.phone : cleanPhone,
              name: activeDynamicStore!.name,
              storeId: activeDynamicStore!.id,
              role: 'مدير المتجر',
            );
            return currentUser;
          }
        }
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        // Explicit invalid credentials from backend - reject immediately
        return null;
      }
    } catch (_) {}

    // 2. Check live cloud stores in Supabase
    try {
      final queryParam = cleanPhone.isNotEmpty ? 'phone=eq.$cleanPhone' : 'id=eq.$cleanInput';
      final res = await http
          .get(
            Uri.parse('$supabaseUrl/stores?$queryParam&select=*'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final storeData = Map<String, dynamic>.from(list.first as Map);
          final dbPin = storeData['pin']?.toString().trim();
          if (dbPin != null && dbPin.isNotEmpty && dbPin == cleanPin) {
            activeDynamicStore = PartnerStore.fromMap(storeData);
            currentStoreId = activeDynamicStore!.id;
            currentUser = MerchantUser(
              id: 'usr_${activeDynamicStore!.id}',
              phone: cleanPhone.isNotEmpty ? cleanPhone : (activeDynamicStore!.phone),
              name: activeDynamicStore!.name,
              storeId: activeDynamicStore!.id,
              role: 'مدير المتجر',
            );
            return currentUser;
          }
        }
      }
    } catch (_) {}

    // No hardcoded fallback or substring phone PINs!
    return null;
  }

  /// Fetch store delivery receipts & invoices (الواصلات)
  static Future<List<MerchantReceipt>> fetchStoreReceipts([String? storeId]) async {
    final targetStoreId = storeId ?? currentStoreId;
    if (!allowMockFallback) {
      try {
        final res = await http
            .get(
              Uri.parse('$supabaseUrl/orders?store_id=eq.$targetStoreId&status=eq.delivered&select=*&order=created_at.desc'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(res.body);
          if (list.isNotEmpty) {
            return list.map((raw) {
              final o = Map<String, dynamic>.from(raw as Map);
              DateTime orderDate = DateTime.now();
              if (o['created_at'] != null) {
                try {
                  orderDate = DateTime.parse(o['created_at'].toString());
                } catch (_) {}
              }
              final double total = (o['total_amount_lyd'] is num)
                  ? (o['total_amount_lyd'] as num).toDouble()
                  : 0.0;
              final subtotal = (o['subtotal_lyd'] is num)
                  ? (o['subtotal_lyd'] as num).toDouble()
                  : total * 0.85;
              final deliveryFee = (o['delivery_fee_lyd'] is num)
                  ? (o['delivery_fee_lyd'] as num).toDouble()
                  : total * 0.15;
              final commission = total * 0.10;
              final double net = total - commission;

              List<KdsOrderItem> receiptItems = [];
              if (o['items'] is List && (o['items'] as List).isNotEmpty) {
                receiptItems = (o['items'] as List).map((it) {
                  final itMap = Map<String, dynamic>.from(it as Map);
                  return KdsOrderItem(
                    name: itMap['name_ar']?.toString() ?? itMap['name']?.toString() ?? 'صنف نالوت',
                    quantity: (itMap['quantity'] as num?)?.toInt() ?? 1,
                    priceLyd: (itMap['price'] as num?)?.toDouble() ?? 20.0,
                  );
                }).toList();
              } else {
                receiptItems = [
                  KdsOrderItem(
                    name: 'طلب واصل نالوت',
                    quantity: 1,
                    priceLyd: total,
                  ),
                ];
              }

              return MerchantReceipt(
                id: o['id']?.toString() ?? '',
                receiptNumber: 'REC-${o['order_number']?.toString().replaceAll('#', '') ?? '000'}',
                orderNumber: o['order_number']?.toString() ?? '#W-000',
                storeId: targetStoreId,
                issuedAt: orderDate,
                subtotalLyd: subtotal,
                deliveryFeeLyd: deliveryFee,
                platformCommissionLyd: commission,
                netMerchantLyd: net,
                paymentMethod: o['payment_method']?.toString() ?? 'كاش عند الاستلام',
                paymentStatus: 'paid',
                customerName: o['customer_name']?.toString() ?? 'زبون واصل نالوت',
                customerPhone: o['customer_phone']?.toString(),
                courierName: o['driver_name']?.toString() ?? 'كابتن واصل',
                items: receiptItems,
              );
            }).toList();
          }
        }
      } catch (_) {}
    }
    return [];
  }

  /// Update inventory stock count (الجرد)
  static Future<bool> updateInventoryStock(String productId, int newQuantity) async {
    final inStock = newQuantity > 0;
    return updateProductStock(productId, inStock, newQuantity);
  }

  /// Fetch live orders from Unified Backend Server or Supabase Cloud
  static Future<List<KdsOrder>> fetchOrders([String? storeId]) async {
    final targetStoreId = storeId ?? currentStoreId;
    List<dynamic> list = [];

    // 1. Try Live Unified Backend First (Instant sync with Customer App)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(
              Uri.parse('$backendBaseUrl/orders?store_id=$targetStoreId'),
              headers: backendHeaders,
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['data'] is List) {
            list = data['data'];
          } else if (data is List) {
            list = data;
          }
          if (list.isNotEmpty) break;
        }
      } catch (_) {
        if (attempt == 1) break;
      }
    }

    // 2. Fallback to Supabase Cloud if unified backend is offline
    if (list.isEmpty) {
      try {
        final res = await http
            .get(
              Uri.parse('$supabaseUrl/orders?store_id=eq.$targetStoreId&order=created_at.desc'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          list = jsonDecode(res.body);
        }
      } catch (_) {}
    }

    if (list.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('wasel_merchant_cached_orders_$targetStoreId', jsonEncode(list));
      } catch (_) {}
      return parseOrdersList(list);
    }

    return [];
  }

  /// Load cached KDS orders from disk for instant recovery upon launch or offline state
  static Future<List<KdsOrder>> loadCachedOrders([String? storeId]) async {
    final targetStoreId = storeId ?? currentStoreId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('wasel_merchant_cached_orders_$targetStoreId');
      if (str != null && str.isNotEmpty) {
        final dynamic decoded = jsonDecode(str);
        if (decoded is List) {
          return parseOrdersList(decoded);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Parses list of raw order maps into typed KdsOrder models
  static List<KdsOrder> parseOrdersList(List<dynamic> list) {
    final List<KdsOrder> result = [];

      for (final raw in list) {
        final o = Map<String, dynamic>.from(raw);
        result.add(parseOrder(o));
      }

      return result;
  }

  /// Parse an order JSON map into a KdsOrder model
  static KdsOrder parseOrder(Map<String, dynamic> o) {
    final String statusStr = o['status']?.toString() ?? 'placed';

    KdsTicketStatus ticketStatus;
    switch (statusStr) {
      case 'placed':
      case 'pending':
      case 'accepted':
        ticketStatus = KdsTicketStatus.newOrder;
        break;
      case 'preparing':
        ticketStatus = KdsTicketStatus.preparing;
        break;
      case 'ready_for_pickup':
        ticketStatus = KdsTicketStatus.readyForPickup;
        break;
      case 'out_for_delivery':
      case 'delivered':
      case 'picked_up':
        ticketStatus = KdsTicketStatus.completed;
        break;
      case 'cancelled':
        ticketStatus = KdsTicketStatus.cancelled;
        break;
      default:
        ticketStatus = KdsTicketStatus.newOrder;
    }

    DateTime placedTime = DateTime.now();
    if (o['created_at'] != null) {
      try {
        placedTime = DateTime.parse(o['created_at'].toString());
      } catch (_) {}
    }

    final double totalAmt = (o['total_amount_lyd'] is num)
        ? (o['total_amount_lyd'] as num).toDouble()
        : ((o['total_amount'] is num) ? (o['total_amount'] as num).toDouble() : 35.0);

    final String payMethod = o['payment_method']?.toString() == 'cod' ||
            o['payment_method']?.toString() == 'cash' ||
            o['payment_method']?.toString() == 'cash_on_delivery'
        ? 'كاش عند الاستلام (COD)'
        : 'دفع إلكتروني (سداد / تداول)';

    final courierName = o['driver_id'] == 'drv_01'
        ? 'كابتن طارق النالوتي'
        : (o['driver_id'] != null ? 'كابتن واصل نالوت' : null);

    List<KdsOrderItem> orderItems = [];
    if (o['items'] is List && (o['items'] as List).isNotEmpty) {
      orderItems = (o['items'] as List).map((it) {
        final itMap = Map<String, dynamic>.from(it);
        String itemNotes = 'طلب طازج';
        final rawMod = itMap['modifiers'];
        if (rawMod is List && rawMod.isNotEmpty) {
          itemNotes = rawMod.map((m) => m is Map ? (m['name_ar'] ?? m['name'] ?? '') : m.toString()).where((s) => s.isNotEmpty).join(', ');
          if (itemNotes.isEmpty) itemNotes = 'طلب طازج';
        } else if (rawMod is String && rawMod.trim().isNotEmpty) {
          itemNotes = rawMod.trim();
        }

        return KdsOrderItem(
          name: itMap['name_ar']?.toString() ?? itMap['name']?.toString() ?? 'صنف نالوت',
          quantity: (itMap['quantity'] as num?)?.toInt() ?? 1,
          priceLyd: (itMap['unit_price_lyd'] as num?)?.toDouble() ??
              (itMap['price'] as num?)?.toDouble() ??
              (itMap['item_total_lyd'] as num?)?.toDouble() ??
              20.0,
          notes: itemNotes,
        );
      }).toList();
    } else {
      orderItems = [
        KdsOrderItem(
          name: 'وجبة / مشتريات نالوت الطازجة',
          quantity: 1,
          priceLyd: totalAmt,
          notes: 'طلب مؤكد من السوبر آب',
        ),
      ];
    }

    final String? handoverCode = o['handover_code']?.toString() ?? o['pickup_code']?.toString();
    final int prepMins = (o['prep_time_minutes'] as num?)?.toInt() ?? 15;
    final bool isDriverArrived = o['driver_arrived_at'] != null || o['driver_status'] == 'arrived';

    return KdsOrder(
      id: o['id']?.toString() ?? '',
      orderNumber: o['order_number']?.toString() ?? '#W-100',
      customerName: o['customer_name']?.toString() ?? 'زبون نالوت',
      customerPhone: o['customer_phone']?.toString() ?? '091-5550000',
      deliveryAddress: o['delivery_address']?.toString() ?? 'نالوت - وسط المدينة',
      customerNotes: o['notes']?.toString() ?? 'طلب مباشر عبر تطبيق واصل',
      status: ticketStatus,
      timePlaced: placedTime,
      prepTimeMinutes: prepMins,
      items: orderItems,
      totalAmountLyd: totalAmt,
      paymentMethod: payMethod,
      courierName: courierName,
      courierVehicle: courierName != null ? 'سيارة نالوت' : null,
      courierPhone: courierName != null ? '091-5544332' : null,
      handoverCode: handoverCode,
      driverArrived: isDriverArrived,
      driverStatus: isDriverArrived ? 'وصل المطعم' : (courierName != null ? 'في الطريق للمتجر' : null),
    );
  }

  /// Update order status (KDS Kitchen Display System)
  /// Dispatches immediate status transitions without 10-second timeout loops.
  static Future<bool> updateOrderStatus(String orderId, String newStatus, {int? prepTimeMinutes}) async {
    final Map<String, dynamic> body = {'status': newStatus};
    if (prepTimeMinutes != null) {
      body['prep_time_minutes'] = prepTimeMinutes;
    }

    // If transitioning to preparing, ensure acceptance is recorded first if order was in placed
    if (newStatus == 'preparing') {
      try {
        await http.post(
          Uri.parse('$backendBaseUrl/orders/$orderId/status'),
          headers: backendHeaders,
          body: jsonEncode({
            'status': 'accepted',
            // ignore: use_null_aware_elements
            if (prepTimeMinutes != null) 'prep_time_minutes': prepTimeMinutes,
          }),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    // 1. Try Live Unified Backend (fast single dispatch)
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/orders/$orderId/status'),
            headers: backendHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      }
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .patch(
            Uri.parse('$supabaseUrl/orders?id=eq.$orderId'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Confirm Handover to Captain (Transfers custody to out_for_delivery)
  static Future<bool> confirmHandover(String orderId, [String? handoverCode]) async {
    try {
      final Map<String, dynamic> body = {};
      if (handoverCode != null) body['handover_code'] = handoverCode;
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/orders/$orderId/handover'),
            headers: backendHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      // Fallback: update status to out_for_delivery
      return updateOrderStatus(orderId, 'out_for_delivery');
    }
  }

  /// Fetch live products catalog for this merchant
  static Future<List<CatalogProduct>> fetchCatalog([String? storeId]) async {
    final targetStoreId = storeId ?? currentStoreId;

    // 1. Try Live Unified Backend First
    try {
      final res = await http
          .get(
            Uri.parse('$backendBaseUrl/stores/$targetStoreId/menu'),
            headers: backendHeaders,
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        final dynamic menuData = data['data'];
        final List<dynamic> list = (menuData is Map && menuData['products'] is List)
            ? menuData['products']
            : ((menuData is Map && menuData['all_products'] is List) ? menuData['all_products'] : []);

        if (list.isNotEmpty) {
          return list.map((raw) {
            final p = Map<String, dynamic>.from(raw);
            final double price = (p['price_lyd'] is num)
                ? (p['price_lyd'] as num).toDouble()
                : ((p['price'] is num) ? (p['price'] as num).toDouble() : 20.0);
            final bool inStock = p['is_available'] == true || p['in_stock'] == true || p['is_available'] == null;
            final String name = p['name_ar']?.toString() ?? p['name']?.toString() ?? 'صنف';
            final String desc = p['description']?.toString() ?? '';
            final String cat = p['category']?.toString() ?? 'وجبات نالوت';

            IconData icon = Icons.restaurant_rounded;
            if (name.contains('بيتزا') || cat.contains('بيتزا')) {
              icon = Icons.local_pizza_rounded;
            } else if (name.contains('مشويات') || name.contains('كباب')) {
              icon = Icons.outdoor_grill_rounded;
            } else if (name.contains('عصير') || name.contains('مشروب')) {
              icon = Icons.local_drink_rounded;
            } else if (name.contains('سندوتش') || name.contains('شاورما') || name.contains('برجر')) {
              icon = Icons.lunch_dining_rounded;
            }

            return CatalogProduct(
              id: p['id']?.toString() ?? '',
              nameAr: name,
              category: cat,
              priceLyd: price,
              inStock: inStock,
              descAr: desc,
              icon: icon,
            );
          }).toList();
        }
        return [];
      }
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .get(
            Uri.parse('$supabaseUrl/products?store_id=eq.$targetStoreId&order=name.asc'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          return list.map((raw) {
            final p = Map<String, dynamic>.from(raw);
            final double price = (p['price'] is num) ? (p['price'] as num).toDouble() : 20.0;
            final bool inStock = p['is_available'] == true || p['is_available'] == null;
            final String name = p['name']?.toString() ?? 'صنف';
            final String desc = p['description']?.toString() ?? '';
            final String cat = p['category']?.toString() ?? 'مشويات جبلية';

            IconData icon = Icons.restaurant_rounded;
            if (name.contains('بيتزا') || cat.contains('بيتزا')) {
              icon = Icons.local_pizza_rounded;
            } else if (name.contains('مشويات') || name.contains('كباب')) {
              icon = Icons.outdoor_grill_rounded;
            } else if (name.contains('عصير') || name.contains('مشروب')) {
              icon = Icons.local_drink_rounded;
            } else if (name.contains('سندوتش') || name.contains('شاورما')) {
              icon = Icons.lunch_dining_rounded;
            }

            return CatalogProduct(
              id: p['id']?.toString() ?? '',
              nameAr: name,
              category: cat,
              priceLyd: price,
              inStock: inStock,
              descAr: desc,
              icon: icon,
            );
          }).toList();
        }
        return [];
      }
    } catch (_) {}

    return [];
  }

  /// Toggle product availability (In Stock / Out of Stock) and quantity
  static Future<bool> updateProductStock(String productId, bool inStock, [int? quantity]) async {
    final payload = <String, dynamic>{
      'is_available': inStock,
      'in_stock': inStock,
    };
    if (quantity != null) {
      payload['stock_quantity'] = quantity;
    }

    // 1. Try Live Unified Backend
    try {
      final res = await http
          .patch(
            Uri.parse('$backendBaseUrl/products/$productId'),
            headers: backendHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return true;
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .patch(
            Uri.parse('$supabaseUrl/products?id=eq.$productId'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 || res.statusCode == 204) return true;
    } catch (_) {}

    // 3. Purged unconditional true fallback - report real failure
    return false;
  }

  /// Update product inventory quantity directly
  static Future<bool> updateProductQuantity(String productId, int quantity) async {
    final inStock = quantity > 0;
    return updateProductStock(productId, inStock, quantity);
  }

  /// Update product price
  static Future<bool> updateProductPrice(String productId, double price) async {
    // 1. Try Live Unified Backend
    try {
      final res = await http
          .patch(
            Uri.parse('$backendBaseUrl/products/$productId'),
            headers: backendHeaders,
            body: jsonEncode({'price': price, 'price_lyd': price}),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) return true;
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .patch(
            Uri.parse('$supabaseUrl/products?id=eq.$productId'),
            headers: _headers,
            body: jsonEncode({'price': price}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Submit a payout / bank transfer request
  static Future<bool> requestPayout({
    required double amountLyd,
    required String method,
    required String accountNumber,
    String? storeName,
  }) async {
    final voucherNumber = 'REQ-DISB-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final payload = {
      'id': 'payout_${DateTime.now().millisecondsSinceEpoch}',
      'voucher_number': voucherNumber,
      'type': 'disbursement',
      'beneficiary_name': storeName ?? 'مطعم قصر نالوت للمشويات',
      'beneficiary_role': 'store',
      'beneficiary_id': currentStoreId,
      'amount_lyd': amountLyd,
      'payment_method': method,
      'notes': 'PENDING_PAYOUT|طريقة السحب: $method|رقم الحساب/المحفظة: $accountNumber',
      'created_by': 'تطبيق مطبخ واصل',
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. Try Live Unified Backend
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/vouchers'),
            headers: backendHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
    } catch (_) {}

    // 2. Fallback to Supabase Cloud
    try {
      final res = await http
          .post(
            Uri.parse('$supabaseUrl/vouchers'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 4));

      return res.statusCode == 201 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Toggle store open / closed status (مفتوح / مغلق) across Unified Backend and Supabase
  static Future<bool> toggleStoreStatus(String storeId, bool isOpen) async {
    bool backendSuccess = false;

    // 1. Try Live Unified Backend First (emits store:status_changed via WebSocket)
    try {
      final res = await http
          .patch(
            Uri.parse('$backendBaseUrl/stores/$storeId'),
            headers: backendHeaders,
            body: jsonEncode({'is_open': isOpen}),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        backendSuccess = true;
      }
    } catch (_) {}

    // 2. Fallback / Sync with Supabase Cloud
    try {
      await http
          .patch(
            Uri.parse('$supabaseUrl/stores?id=eq.$storeId'),
            headers: _headers,
            body: jsonEncode({'is_open': isOpen}),
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (activeDynamicStore != null && activeDynamicStore!.id == storeId) {
      activeDynamicStore = activeDynamicStore!.copyWith(isOpen: isOpen);
    }

    return backendSuccess;
  }

  /// Fetch live store status (is_open) from backend
  static Future<bool?> fetchStoreStatus(String storeId) async {
    try {
      final res = await http
          .get(
            Uri.parse('$backendBaseUrl/stores/$storeId'),
            headers: backendHeaders,
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] != null) {
          final rawOpen = data['data']['is_open'];
          return rawOpen != false && rawOpen != 'false' && rawOpen != 0;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Send active merchant heartbeat to backend to keep store open (حضور حي لحظي)
  static Future<bool> sendHeartbeat(String storeId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/stores/$storeId/heartbeat'),
            headers: backendHeaders,
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

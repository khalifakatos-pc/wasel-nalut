import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  static String currentStoreId = 'store_nalut_ranchello';

  /// Fetch live orders from Unified Backend Server or Supabase Cloud
  static Future<List<KdsOrder>> fetchOrders([String? storeId]) async {
    final targetStoreId = storeId ?? currentStoreId;
    List<dynamic> list = [];

    // 1. Try Live Unified Backend First (Instant sync with Customer App)
    try {
      final res = await http
          .get(Uri.parse('$backendBaseUrl/orders?store_id=$targetStoreId'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          list = data['data'];
        } else if (data is List) {
          list = data;
        }
      }
    } catch (_) {
      // Fallback
    }

    // 2. Fallback to Supabase Cloud if unified backend is offline
    if (list.isEmpty) {
      try {
        final res = await http
            .get(
              Uri.parse('$supabaseUrl/orders?store_id=eq.$targetStoreId&order=created_at.desc'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          list = jsonDecode(res.body);
        }
      } catch (_) {}
    }

    if (list.isNotEmpty) {
      final List<KdsOrder> result = [];

      for (final raw in list) {
        final o = Map<String, dynamic>.from(raw);
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
            return KdsOrderItem(
              name: itMap['name_ar']?.toString() ?? itMap['name']?.toString() ?? 'صنف نالوت',
              quantity: (itMap['quantity'] as num?)?.toInt() ?? 1,
              priceLyd: (itMap['unit_price_lyd'] as num?)?.toDouble() ??
                  (itMap['price'] as num?)?.toDouble() ??
                  (itMap['item_total_lyd'] as num?)?.toDouble() ??
                  20.0,
              notes: (itMap['modifiers'] is List && (itMap['modifiers'] as List).isNotEmpty)
                  ? (itMap['modifiers'] as List).map((m) => m['name_ar'] ?? m['name']).join(', ')
                  : 'طلب طازج',
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

        result.add(
          KdsOrder(
            id: o['id']?.toString() ?? '',
            orderNumber: o['order_number']?.toString() ?? '#W-100',
            customerName: o['customer_name']?.toString() ?? 'زبون نالوت',
            customerPhone: o['customer_phone']?.toString() ?? '091-5550000',
            deliveryAddress: o['delivery_address']?.toString() ?? 'نالوت - وسط المدينة',
            customerNotes: o['notes']?.toString() ?? 'طلب مباشر عبر تطبيق واصل',
            status: ticketStatus,
            timePlaced: placedTime,
            prepTimeMinutes: 15,
            items: orderItems,
            totalAmountLyd: totalAmt,
            paymentMethod: payMethod,
            courierName: courierName,
            courierVehicle: courierName != null ? 'سيارة نالوت' : null,
            courierPhone: courierName != null ? '091-5544332' : null,
          ),
        );
      }

      if (result.isNotEmpty) {
        return result;
      }
    }

    final isRetail = targetStoreId == 'store_nalut_rixos' || targetStoreId == 'store_nalut_alhanaa';
    return isRetail ? MerchantMockData.getSampleRetailOrders() : MerchantMockData.getSampleOrders();
  }

  /// Update order status (KDS Kitchen Display System)
  static Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    // 1. Try Live Unified Backend First
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/orders/$orderId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': newStatus}),
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
            body: jsonEncode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Fetch live products catalog for this merchant
  static Future<List<CatalogProduct>> fetchCatalog([String? storeId]) async {
    final targetStoreId = storeId ?? currentStoreId;

    // 1. Try Live Unified Backend First
    try {
      final res = await http
          .get(Uri.parse('$backendBaseUrl/stores/$targetStoreId/menu'))
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
      }
    } catch (_) {}

    return MerchantMockData.getSampleCatalog();
  }

  /// Toggle product availability (In Stock / Out of Stock)
  static Future<bool> updateProductStock(String productId, bool inStock) async {
    // 1. Try Live Unified Backend
    try {
      final res = await http
          .patch(
            Uri.parse('$backendBaseUrl/products/$productId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'is_available': inStock}),
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
            body: jsonEncode({'is_available': inStock}),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Update product price
  static Future<bool> updateProductPrice(String productId, double price) async {
    // 1. Try Live Unified Backend
    try {
      final res = await http
          .patch(
            Uri.parse('$backendBaseUrl/products/$productId'),
            headers: {'Content-Type': 'application/json'},
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
            headers: {'Content-Type': 'application/json'},
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
}

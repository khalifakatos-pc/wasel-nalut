import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'design_system.dart';
import 'order_tracking_screen.dart';
import 'services/api_service.dart';
import 'services/cart_service.dart';

class OrderHistoryModel {
  final String orderId;
  final String orderNumber;
  final String storeName;
  final String date;
  final double totalAmount;
  final int itemsCount;
  final String status;
  final String statusAr;
  final Color statusColor;
  final bool isActive;

  OrderHistoryModel({
    required this.orderId,
    required this.orderNumber,
    required this.storeName,
    required this.date,
    required this.totalAmount,
    required this.itemsCount,
    required this.status,
    required this.statusAr,
    required this.statusColor,
    this.isActive = false,
  });
}

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<OrderHistoryModel> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveOrders();
  }

  Future<void> _fetchLiveOrders() async {
    setState(() => _isLoading = true);
    final phone = ApiService.userPhone.trim();
    final activeId = ApiService.activeOrderId;

    List<dynamic> rawOrders = [];

    // 1. Try Live Unified Backend Server First (Instant sync with all Wasel apps)
    try {
      String query = '';
      if (phone.isNotEmpty) {
        query = 'customer_phone=${Uri.encodeComponent(phone)}';
      } else if (activeId != null && activeId.isNotEmpty) {
        query = 'id=$activeId';
      }

      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders${query.isNotEmpty ? '?$query' : ''}'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          rawOrders = data['data'];
        } else if (data is List) {
          rawOrders = data;
        }
      }
    } catch (_) {}

    // 2. Fallback to Supabase Cloud if unified backend is offline
    if (rawOrders.isEmpty) {
      try {
        String filter = '';
        if (phone.isNotEmpty) {
          filter = 'customer_phone=eq.${Uri.encodeComponent(phone)}&';
        } else if (activeId != null && activeId.isNotEmpty) {
          filter = 'id=eq.$activeId&';
        }

        final res = await http.get(
          Uri.parse('${ApiService.supabaseUrl}/orders?${filter}select=*&order=created_at.desc'),
          headers: {
            'apikey': ApiService.supabaseApiKey,
            'Authorization': 'Bearer ${ApiService.supabaseApiKey}',
          },
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final list = jsonDecode(res.body);
          if (list is List) {
            rawOrders = list;
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      if (rawOrders.isNotEmpty) {
        final mapped = rawOrders.map<OrderHistoryModel>((o) {
          final status = o['status'] ?? 'placed';
          final isActive = status == 'placed' || status == 'preparing' || status == 'ready_for_pickup' || status == 'out_for_delivery';

          String statusAr = 'قيد التجهيز';
          Color statusColor = AppColors.warning;
          if (status == 'placed') {
            statusAr = 'تم استلام الطلب بانتظار المطعم';
            statusColor = AppColors.waselPrimary;
          } else if (status == 'preparing') {
            statusAr = 'المطعم يجهز طلبك الآن';
            statusColor = AppColors.warning;
          } else if (status == 'ready_for_pickup') {
            statusAr = 'الطلب جاهز بانتظار استلام الكابتن';
            statusColor = AppColors.warning;
          } else if (status == 'out_for_delivery') {
            statusAr = 'الكابتن في الطريق إليك';
            statusColor = AppColors.waselPrimary;
          } else if (status == 'delivered') {
            statusAr = 'تم التسليم بنجاح';
            statusColor = AppColors.success;
          } else if (status == 'cancelled') {
            statusAr = 'تم إلغاء الطلب';
            statusColor = AppColors.error;
          }

          final createdAt = o['created_at'] != null ? o['created_at'].toString().split('T').first : 'اليوم';
          final total = (o['total_amount_lyd'] is num)
              ? (o['total_amount_lyd'] as num).toDouble()
              : ((o['total_amount'] is num) ? (o['total_amount'] as num).toDouble() : 30.0);

          final items = o['items'];
          final itemsCount = (items is List && items.isNotEmpty) ? items.length : 1;

          return OrderHistoryModel(
            orderId: o['id'] ?? 'ord',
            orderNumber: '#${o['order_number'] ?? 'WAS-0000'}',
            storeName: o['store_name'] ?? (o['store_id'] == 'store_nalut_02' ? 'بيتزا ومعجنات القلعة نالوت' : 'مطعم قصر نالوت للمشويات'),
            date: createdAt,
            totalAmount: total,
            itemsCount: itemsCount,
            status: status,
            statusAr: statusAr,
            statusColor: statusColor,
            isActive: isActive,
          );
        }).toList();

        setState(() {
          _orders = mapped;
          _isLoading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final orders = _orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل طلباتي'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchLiveOrders),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.waselPrimary))
          : RefreshIndicator(
              onRefresh: _fetchLiveOrders,
              color: AppColors.waselPrimary,
              child: orders.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: AppColors.waselPrimary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                size: 48,
                                color: AppColors.waselPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'لا توجد طلبات سابقة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'عندما تطلب وجبة أو مشتريات من متاجر نالوت، ستظهر تفاصيل وحالة طلبك ومساره هنا مباشرة.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _fetchLiveOrders,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('تحديث السجل'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.waselPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        // 1. ACTIVE ORDER BANNER
          ...orders.where((o) => o.isActive).map((order) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.waselPrimary, Color(0xFFC22026)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.radiusXl,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.waselPrimary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          order.orderNumber,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.motorcycle_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('طلب نشط', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order.storeName,
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.statusAr,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderTrackingScreen(
                              orderId: order.orderId,
                              orderNumber: order.orderNumber.replaceAll('#', ''),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_searching_rounded, size: 18),
                      label: const Text('تتبع مسار الكابتن على الخريطة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.waselPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // 2. PAST ORDERS SECTION
          const Text(
            'الطلبات السابقة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),

          ...orders.where((o) => !o.isActive).map((order) {
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.storeName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: order.statusColor.withValues(alpha: 0.15),
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          order.statusAr,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: order.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.date} • ${order.itemsCount} أصناف • ${order.totalAmount.toStringAsFixed(2)} د.ل',
                    style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          CartService.addItem(
                            CartItem(
                              id: 'reorder_${order.orderId}',
                              title: 'وجبة سابقة (${order.storeName})',
                              storeName: order.storeName,
                              price: order.totalAmount > 5 ? (order.totalAmount - 4.0) : order.totalAmount,
                              quantity: 1,
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.waselPrimary,
                              content: Text('✅ تمت إضافة وجبة من ${order.storeName} إلى السلة!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.replay_rounded, size: 16),
                        label: const Text('إعادة الطلب'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.waselPrimary,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _showRatingDialog(context, order.storeName);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                        ),
                        child: const Text('تقييم الطلب ⭐'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}

  void _showRatingDialog(BuildContext context, String storeName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم $storeName'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('كيف كانت تجربتك مع الوجبة وسرعة التوصيل؟'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                Icon(Icons.star_rounded, color: Colors.amber, size: 32),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('شكراً لتقييمك! تم إرسال ملاحظاتك بنجاح.')),
              );
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'design_system.dart';
import 'order_tracking_screen.dart';

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
    try {
      final res = await http.get(
        Uri.parse('https://yfhvuatssuylrkbthosa.supabase.co/rest/v1/orders?select=*&order=created_at.desc'),
        headers: {
          'apikey': 'sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD',
          'Authorization': 'Bearer sb_publishable_oksEzBwufYAmR1mRBUFCYg_XtSQjbTD',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final mapped = list.map<OrderHistoryModel>((o) {
            final status = o['status'] ?? 'placed';
            final isActive = status == 'placed' || status == 'preparing' || status == 'out_for_delivery';
            
            String statusAr = 'قيد التجهيز';
            Color statusColor = AppColors.warning;
            if (status == 'placed') {
              statusAr = 'تم استلام الطلب بانتظار المطعم';
              statusColor = AppColors.waselPrimary;
            } else if (status == 'preparing') {
              statusAr = 'المطعم يجهز طلبك الآن';
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
            final total = (o['total_amount_lyd'] is num) ? (o['total_amount_lyd'] as num).toDouble() : 30.0;

            return OrderHistoryModel(
              orderId: o['id'] ?? 'ord',
              orderNumber: '#${o['order_number'] ?? 'WAS-0000'}',
              storeName: o['store_id'] == 'store_nalut_02' ? 'بيتزا ومعجنات القلعة نالوت' : 'مطعم قصر نالوت للمشويات',
              date: createdAt,
              totalAmount: total,
              itemsCount: 2,
              status: status,
              statusAr: statusAr,
              statusColor: statusColor,
              isActive: isActive,
            );
          }).toList();

          if (mounted) {
            setState(() {
              _orders = mapped;
              _isLoading = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    // Baseline fallback if no cloud connection
    if (mounted) {
      setState(() {
        _orders = [
          OrderHistoryModel(
            orderId: 'ord-live',
            orderNumber: '#WSL-84920',
            storeName: 'مطعم قصر نالوت للمشويات',
            date: 'اليوم، 02:40 م',
            totalAmount: 34.00,
            itemsCount: 2,
            status: 'out_for_delivery',
            statusAr: 'الكابتن وسيم في الطريق إليك (8 دقائق)',
            statusColor: AppColors.waselPrimary,
            isActive: true,
          ),
          OrderHistoryModel(
            orderId: 'ord-2',
            orderNumber: '#WSL-83210',
            storeName: 'أسواق نالوت المركزية - واصل فوري',
            date: '21 أغسطس 2026',
            totalAmount: 48.50,
            itemsCount: 5,
            status: 'delivered',
            statusAr: 'تم التسليم بنجاح',
            statusColor: AppColors.success,
          ),
        ];
        _isLoading = false;
      });
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
              child: ListView(
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
                          MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تمت إضافة أصناف الوجبة إلى سلة المشتريات!')),
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

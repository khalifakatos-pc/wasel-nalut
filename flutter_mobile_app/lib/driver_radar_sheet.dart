import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'design_system.dart';
import 'services/api_service.dart';
import 'order_tracking_screen.dart';

/// Customer's Captain Radar Sheet (رادار كباتن واصل وتتبع طلبات الزبون في نالوت)
class DriverRadarSheet extends StatefulWidget {
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const DriverRadarSheet({super.key, this.onAccept, this.onDecline});

  @override
  State<DriverRadarSheet> createState() => _DriverRadarSheetState();
}

class _DriverRadarSheetState extends State<DriverRadarSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _hasActiveOrder = false;
  String _orderNum = 'WAS-9831';
  final String _storeName = 'مطعم قصر نالوت للمشويات';
  final String _captainName = 'كابتن طارق النالوتي';
  final String _captainPhone = '0915544332';
  final String _captainVehicle = 'سيارة تويوتا يارس (أبيض) - لوحة 14-88492';
  final String _etaText = '10 - 15 دقيقة';
  final String _otpCode = '4821';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _checkCustomerActiveOrder();
  }

  void _checkCustomerActiveOrder() {
    final activeId = ApiService.activeOrderId;
    if (activeId != null && activeId.isNotEmpty) {
      setState(() {
        _hasActiveOrder = true;
        _orderNum = activeId.length > 8 ? activeId.substring(activeId.length - 8).toUpperCase() : activeId;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+|-'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+|-'), '');
    final localDigits = cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone;
    final fullPhone = cleanPhone.startsWith('+') ? cleanPhone.replaceFirst('+', '') : '218$localDigits';
    final uri = Uri.parse('https://wa.me/$fullPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: AppRadius.radiusXl,
            border: Border.all(color: AppColors.waselPrimary.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.waselPrimary.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. RADAR ICON WITH ANIMATED PULSE
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 76 + (_pulseController.value * 24),
                        height: 76 + (_pulseController.value * 24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_hasActiveOrder ? AppColors.success : AppColors.waselPrimary)
                              .withValues(alpha: 0.22 - (_pulseController.value * 0.16)),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _hasActiveOrder
                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                            : [AppColors.waselPrimary, const Color(0xFFC22026)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      _hasActiveOrder ? Icons.moped_rounded : Icons.radar_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. HEADER BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (_hasActiveOrder ? AppColors.success : AppColors.waselPrimary).withValues(alpha: 0.18),
                  borderRadius: AppRadius.radiusFull,
                ),
                child: Text(
                  _hasActiveOrder ? '🛵 الكابتن في الطريق إليك!' : '📡 رادار كباتن واصل في نالوت',
                  style: TextStyle(
                    color: _hasActiveOrder ? AppColors.success : AppColors.waselPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_hasActiveOrder) ...[
                // CASE A: CUSTOMER HAS ACTIVE ORDER ASSIGNED TO A CAPTAIN
                Text(
                  _storeName,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'طلب رقم: #$_orderNum • وقت الوصول المتوقع: $_etaText',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // CAPTAIN INFO CARD
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.waselPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.person_pin_circle_rounded, color: AppColors.waselPrimary, size: 26),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _captainName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                          SizedBox(width: 2),
                                          Text('4.9', style: TextStyle(color: Colors.amber, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _captainVehicle,
                                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF334155), height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'رمز تسليم الطلب (OTP):',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.waselPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.waselPrimary.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _otpCode,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ACTION BUTTONS: TRACK MAP / CALL / WHATSAPP
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(
                            orderId: ApiService.activeOrderId,
                            orderNumber: _orderNum,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.satellite_alt_rounded, size: 18),
                    label: const Text('تتبع الكابتن مباشرة على الخريطة 🛰️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.waselPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _makeCall(_captainPhone),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Colors.white),
                        label: const Text('اتصال بالكابتن', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(_captainPhone),
                        icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                        label: const Text('واتساب الكابتن', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // CASE B: CUSTOMER HAS NO ACTIVE ORDERS YET
                const Text(
                  'كباتن واصل المتاحون في نالوت',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'يوجد حالياً 3 كباتن توصيل نشطين وقريبين في نالوت جاهزون لاستلام وتوصيل طلبك فوراً.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // NEARBY CAPTAINS LIST
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    children: [
                      _buildCaptainRow(
                        name: 'كابتن طارق النالوتي',
                        location: 'وسط المدينة • قرب القصر الأثري',
                        vehicle: 'سيارة يارس',
                        rating: '4.9',
                      ),
                      const Divider(color: Color(0xFF334155), height: 12),
                      _buildCaptainRow(
                        name: 'كابتن وسيم الورفلي',
                        location: 'حي سيدي خليفة والشهداء',
                        vehicle: 'دراجة نارية سريعة',
                        rating: '4.8',
                      ),
                      const Divider(color: Color(0xFF334155), height: 12),
                      _buildCaptainRow(
                        name: 'كابتن سالم العكرمي',
                        location: 'طريق القلعة ومفرق المستشفى',
                        vehicle: 'سيارة كيا ريو',
                        rating: '5.0',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ACTION BUTTON: GO TO MENU / ORDER NOW
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        ),
                        child: const Text('إغلاق'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onAccept?.call();
                        },
                        icon: const Icon(Icons.restaurant_rounded, size: 18),
                        label: const Text('تصفح واطلب الآن 🍔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.waselPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptainRow({
    required String name,
    required String location,
    required String vehicle,
    required String rating,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                Text(
                  ' • ',
                  style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
              const SizedBox(width: 2),
              Text(rating, style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

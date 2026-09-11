import 'package:flutter/material.dart';
import 'merchant_theme.dart';
import 'merchant_models.dart';

/// ============================================================================
/// POS THERMAL RECEIPT SLIP PREVIEW & SIMULATED PRINTER DIALOG
/// ============================================================================

class ThermalReceiptDialog extends StatelessWidget {
  final KdsOrder order;

  const ThermalReceiptDialog({super.key, required this.order});

  static void show(BuildContext context, KdsOrder order) {
    showDialog(
      context: context,
      builder: (_) => ThermalReceiptDialog(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Store Header
              const Icon(Icons.receipt_long_rounded, size: 36, color: Colors.black87),
              const SizedBox(height: 6),
              const Text(
                'مطعم قصر نالوت للمشويات',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const Text(
                'نالوت - بالقرب من القصر الأثري\nهاتف: 091-2345678',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.black26, thickness: 1),

              // Order & Customer Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('رقم الطلب: ${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                  Text(
                    '${order.timePlaced.hour.toString().padLeft(2, '0')}:${order.timePlaced.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('الزبون: ${order.customerName}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('العنوان: ${order.deliveryAddress}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.black26, thickness: 1),

              // Items Table
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.quantity}x ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text('↳ ${item.notes}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Text('${item.totalLyd.toStringAsFixed(2)} د.ل', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                  ],
                ),
              )),

              const Divider(color: Colors.black26, thickness: 1),
              const SizedBox(height: 4),

              // Total Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('طريقة الدفع:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  Text(order.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي المطلوب:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
                  Text(
                    '${order.totalAmountLyd.toStringAsFixed(2)} د.ل',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Simulated QR Code Box for Courier Scan
              Container(
                width: 110,
                height: 110,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 68, color: Colors.black87),
                    Text('امسح للاستلام', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                'شكراً لطلبكم عبر سوبر آب واصل نالوت 🏔️\nWasel Super-App Nalut',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق', style: TextStyle(color: Colors.black54)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('طباعة الفاتورة 🖨️'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MerchantColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🖨️ جاري إرسال الفاتورة إلى طابعة البلوتوث / POS...'),
                backgroundColor: MerchantColors.primaryDark,
              ),
            );
          },
        ),
      ],
    );
  }
}

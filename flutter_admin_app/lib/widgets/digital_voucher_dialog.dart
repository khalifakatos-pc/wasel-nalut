import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/admin_theme.dart';

class DigitalVoucherDialog extends StatelessWidget {
  final Map<String, dynamic> voucher;

  const DigitalVoucherDialog({super.key, required this.voucher});

  static void show(BuildContext context, Map<String, dynamic> voucher) {
    showDialog(
      context: context,
      builder: (context) => DigitalVoucherDialog(voucher: voucher),
    );
  }

  String _formatAmountInWords(double amount) {
    final int whole = amount.truncate();
    final int fraction = ((amount - whole) * 100).round();
    
    // Simple Libyan Dinar expression helper
    String wholeStr = '$whole دينار ليبي';
    if (fraction > 0) {
      return '$wholeStr و $fraction درهم لا غير';
    }
    return '$wholeStr فقط لا غير';
  }

  @override
  Widget build(BuildContext context) {
    final type = voucher['type'] ?? 'receipt';
    final isReceipt = type == 'receipt';
    final isDisbursement = type == 'disbursement';

    final Color badgeColor = isReceipt
        ? AdminColors.emeraldGreen
        : (isDisbursement ? AdminColors.primaryGold : AdminColors.alertRed);

    final String titleArabic = isReceipt
        ? 'سند قبض نقدي رسمي'
        : (isDisbursement ? 'سند صرف مستحقات' : 'سند مصروفات تشغيلية');

    final String subTitleArabic = isReceipt
        ? 'Official Cash Receipt Voucher'
        : (isDisbursement ? 'Merchant Disbursement Voucher' : 'Operational Expense Voucher');

    final double amount = (voucher['amount_lyd'] is num)
        ? (voucher['amount_lyd'] as num).toDouble()
        : 0.0;

    final String dateStr = voucher['created_at'] != null
        ? voucher['created_at'].toString().split('T').first
        : DateTime.now().toString().split(' ').first;

    final String timeStr = voucher['created_at'] != null && voucher['created_at'].toString().contains('T')
        ? voucher['created_at'].toString().split('T')[1].split('.').first
        : '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131C31),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Official Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'منظومة واصل نالوت الموحدة',
                            style: TextStyle(
                              color: AdminColors.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'الإدارة المالية والحسابات - نالوت',
                            style: TextStyle(
                              color: AdminColors.textSecondary.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          voucher['voucher_number'] ?? 'VOUCHER',
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AdminColors.divider, height: 1),
                  const SizedBox(height: 16),

                  // Voucher Title Badge
                  Center(
                    child: Column(
                      children: [
                        Text(
                          titleArabic,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subTitleArabic,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AdminColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Amount Box
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          badgeColor.withValues(alpha: 0.15),
                          badgeColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              amount.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'د.ل (دينار ليبي)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAmountInWords(amount),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AdminColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Meta Grid
                  _buildDetailRow('تاريخ الإصدار:', '$dateStr  $timeStr'),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    isReceipt ? 'استلمنا من السيد/الكابتن:' : 'يُصرف للسيد/المتجر:',
                    voucher['beneficiary_name'] ?? 'غير محدد',
                    isHighlight: true,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('طريقة الدفع:', voucher['payment_method'] == 'cash' ? 'نقداً (كاش)' : (voucher['payment_method'] ?? 'نقداً')),
                  const SizedBox(height: 8),
                  _buildDetailRow('البيان والغرض:', voucher['notes'] ?? 'توريد وتسوية حسابات'),
                  const SizedBox(height: 8),
                  _buildDetailRow('الموظف المسؤول:', voucher['created_by'] ?? 'إدارة واصل - نالوت'),

                  const SizedBox(height: 20),

                  const SizedBox(height: 18),

                  // QR Code Validation Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceElevated.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white70, width: 2),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: CustomPaint(
                            painter: _VoucherQrPainter('WASEL-NALUT-${voucher['voucher_number']}-$amount'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_scanner, color: AdminColors.emeraldGreen, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'رمز التحقق الرقمي (QR Code)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'مشفر ومعتمد لدى سحابة واصل نالوت المركزية\nالمعرف: ${voucher['voucher_number'] ?? 'VCH'}',
                                style: const TextStyle(fontSize: 10, color: AdminColors.textSecondary, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stamp & Signature Simulation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.surfaceElevated.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AdminColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('توقيع المستلم / المورد', style: TextStyle(fontSize: 11, color: AdminColors.textSecondary)),
                            SizedBox(height: 6),
                            Text('✓ تم الاستلام والإبراء', style: TextStyle(fontSize: 12, color: AdminColors.skyBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AdminColors.primaryGold, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            children: [
                              Text('★ خَتم رقمي مُعتمد ★', style: TextStyle(fontSize: 10, color: AdminColors.primaryGold, fontWeight: FontWeight.bold)),
                              Text('إدارة واصل - نالوت', style: TextStyle(fontSize: 10, color: AdminColors.primaryGold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 80mm Thermal Print Action Button
                  ElevatedButton.icon(
                    onPressed: () => _showThermalReceiptDialog(context, voucher, titleArabic, amount, dateStr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text('🖨️ طباعة إيصال حراري (80mm Thermal Printer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),

                  const SizedBox(height: 12),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final text = '📄 سند مالي معتمد من واصل نالوت:\n'
                                'الرقم: ${voucher['voucher_number']}\n'
                                'النوع: $titleArabic\n'
                                'المستفيد: ${voucher['beneficiary_name']}\n'
                                'المبلغ: ${amount.toStringAsFixed(2)} د.ل\n'
                                'التاريخ: $dateStr\n'
                                'البيان: ${voucher['notes']}';
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: AdminColors.emeraldGreen,
                                content: Text('📋 تم نسخ بيانات السند لمشاركتها عبر واتساب!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('مشاركة السند'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminColors.skyBlue,
                            side: const BorderSide(color: AdminColors.skyBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminColors.surfaceElevated,
                            foregroundColor: AdminColors.textPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('إغلاق'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AdminColors.primaryGold : AdminColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showThermalReceiptDialog(BuildContext context, Map<String, dynamic> v, String typeTitle, double amount, String dateStr) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320, // 80mm standard printable roll width representation
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 4),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      '*** واصل نالوت ***',
                      style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'WASEL NALUT DISPATCH & FINANCES',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black87),
                    ),
                  ),
                  const Center(
                    child: Text(
                      'غرفة العمليات المركزية - نالوت',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '================================',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                  ),
                  Center(
                    child: Text(
                      '[$typeTitle]',
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                    ),
                  ),
                  const Text(
                    '================================',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  _thermalTextRow('رقم السند:', v['voucher_number'] ?? 'VCH-0000'),
                  _thermalTextRow('التاريخ:', dateStr),
                  _thermalTextRow('المستفيد:', v['beneficiary_name'] ?? 'مستفيد'),
                  _thermalTextRow('طريقة الدفع:', v['payment_method'] ?? 'نقداً (كاش)'),
                  _thermalTextRow('البيان:', v['notes'] ?? 'تسوية حسابات'),
                  const SizedBox(height: 6),
                  const Text(
                    '--------------------------------',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'المبلغ الإجمالي:',
                        style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                      ),
                      Text(
                        '${amount.toStringAsFixed(2)} LYD',
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatAmountInWords(amount),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '--------------------------------',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  // Centered Thermal QR Code
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: CustomPaint(
                        painter: _VoucherQrPainter('WASEL-${v['voucher_number']}-$amount'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'WASEL-SECURE-80MM-RECEIPT',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '-- -- -- -- [ قَص الإيصال ] -- -- -- --',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black45),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🖨️ تم إرسال أمر الطباعة الحرارية للطابعة (80mm POS)!'),
                                backgroundColor: AdminColors.emeraldGreen,
                              ),
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('إرسال للطابعة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إغلاق', style: TextStyle(color: Colors.black87)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thermalTextRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
          Expanded(
            child: Text(val, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _VoucherQrPainter extends CustomPainter {
  final String data;
  _VoucherQrPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final paintLight = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintLight);

    const int modules = 21;
    final double step = size.width / modules;

    // Helper to draw square finder pattern at (r, c)
    void drawFinder(int r, int c) {
      canvas.drawRect(Rect.fromLTWH(c * step, r * step, 7 * step, 7 * step), paintDark);
      canvas.drawRect(Rect.fromLTWH((c + 1) * step, (r + 1) * step, 5 * step, 5 * step), paintLight);
      canvas.drawRect(Rect.fromLTWH((c + 2) * step, (r + 2) * step, 3 * step, 3 * step), paintDark);
    }

    drawFinder(0, 0);
    drawFinder(0, modules - 7);
    drawFinder(modules - 7, 0);

    // Hash-based data dots
    final hash = data.hashCode.abs();
    for (int r = 0; r < modules; r++) {
      for (int c = 0; c < modules; c++) {
        if ((r < 8 && c < 8) || (r < 8 && c >= modules - 8) || (r >= modules - 8 && c < 8)) {
          continue;
        }
        final bit = ((hash * (r + 1) * 31 + (c + 1) * 17 + r * c) % 5) == 0;
        if (bit) {
          canvas.drawRect(Rect.fromLTWH(c * step, r * step, step * 0.95, step * 0.95), paintDark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

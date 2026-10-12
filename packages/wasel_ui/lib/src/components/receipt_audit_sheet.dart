import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/wasel_colors.dart';
import '../theme/wasel_spacing.dart';
import '../theme/wasel_typography.dart';
import '../motion/bouncy_pressable.dart';
import '../motion/odometer_counter.dart';
import 'wasel_button.dart';

/// Item representation for itemized receipt audit checklist.
class ReceiptAuditItem {
  final String id;
  final String name;
  final int quantity;
  final double? price;
  final String? note;

  const ReceiptAuditItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.price,
    this.note,
  });
}

/// ============================================================================
/// RECEIPT AUDIT SHEET (شيت تجريد الفاتورة والمطابقة الميدانية)
/// ============================================================================
/// Mandatory checklist enforcing Captain arrival at store -> auditing items
/// one-by-one -> unlocking the pickup/approval button only when 100% checked.
/// Eliminates bypass loopholes and guarantees order completeness.
/// ============================================================================
class ReceiptAuditSheet extends StatefulWidget {
  final String orderId;
  final String merchantName;
  final List<ReceiptAuditItem> items;
  final double? totalPrice;
  final String? customerNote;
  final VoidCallback onApproved;
  final VoidCallback? onContactMerchant;

  const ReceiptAuditSheet({
    super.key,
    required this.orderId,
    required this.merchantName,
    required this.items,
    required this.onApproved,
    this.totalPrice,
    this.customerNote,
    this.onContactMerchant,
  });

  /// Displays the receipt audit bottom sheet modally.
  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String merchantName,
    required List<ReceiptAuditItem> items,
    required VoidCallback onApproved,
    double? totalPrice,
    String? customerNote,
    VoidCallback? onContactMerchant,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptAuditSheet(
        orderId: orderId,
        merchantName: merchantName,
        items: items,
        onApproved: onApproved,
        totalPrice: totalPrice,
        customerNote: customerNote,
        onContactMerchant: onContactMerchant,
      ),
    );
  }

  @override
  State<ReceiptAuditSheet> createState() => _ReceiptAuditSheetState();
}

class _ReceiptAuditSheetState extends State<ReceiptAuditSheet> {
  final Set<int> _checkedIndices = {};

  bool get _isAllChecked =>
      widget.items.isNotEmpty &&
      _checkedIndices.length == widget.items.length;

  @override
  void didUpdateWidget(covariant ReceiptAuditSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _checkedIndices.removeWhere((index) => index >= widget.items.length);
    }
  }

  void _toggleItem(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_checkedIndices.contains(index)) {
        _checkedIndices.remove(index);
      } else {
        _checkedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_isAllChecked) {
        _checkedIndices.clear();
      } else {
        for (int i = 0; i < widget.items.length; i++) {
          _checkedIndices.add(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? WaselColors.surfaceDark : WaselColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? WaselColors.borderDark
                      : WaselColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: WaselColors.primary.withValues(alpha: 0.15),
                      borderRadius: WaselRadius.radiusMd,
                    ),
                    child: const Icon(
                      Icons.fact_check_rounded,
                      color: WaselColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تجريد ومطابقة الفاتورة',
                          style: WaselTypography.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? WaselColors.textPrimaryDark
                                : WaselColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'طلب ${widget.orderId} • ${widget.merchantName}',
                          style: WaselTypography.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? WaselColors.textSecondaryDark
                                : WaselColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  WaselBouncyPressable(
                    onTap: _selectAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAllChecked
                            ? WaselColors.secondary.withValues(alpha: 0.15)
                            : (isDark
                                ? WaselColors.cardElevatedDark
                                : WaselColors.borderLight),
                        borderRadius: WaselRadius.radiusSm,
                      ),
                      child: Text(
                        _isAllChecked ? 'إلغاء الكل' : 'تحديد الكل',
                        style: WaselTypography.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isAllChecked
                              ? WaselColors.secondary
                              : (isDark
                                  ? WaselColors.textSecondaryDark
                                  : WaselColors.textSecondaryLight),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isAllChecked
                    ? WaselColors.secondaryTint.withValues(alpha: isDark ? 0.15 : 1.0)
                    : WaselColors.primaryTint.withValues(alpha: isDark ? 0.15 : 1.0),
                borderRadius: WaselRadius.radiusMd,
                border: Border.all(
                  color: _isAllChecked
                      ? WaselColors.secondary.withValues(alpha: 0.3)
                      : WaselColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAllChecked
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: _isAllChecked
                        ? WaselColors.secondary
                        : WaselColors.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAllChecked
                          ? 'اكتملت المطابقة بنجاح! يمكنك الآن استلام الطلب والانطلاق.'
                          : 'يرجى التأكد من مطابقة جميع الأصناف مع المطبخ (${_checkedIndices.length}/${widget.items.length}).',
                      style: WaselTypography.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isAllChecked
                            ? WaselColors.secondary
                            : WaselColors.primaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // Items List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: widget.items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isChecked = _checkedIndices.contains(index);

                  return WaselBouncyPressable(
                    key: ValueKey('audit_item_$index'),
                    onTap: () => _toggleItem(index),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? (isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                                : WaselColors.secondaryTint)
                            : (isDark
                                ? WaselColors.cardElevatedDark
                                : WaselColors.surfaceLight),
                        borderRadius: WaselRadius.radiusMd,
                        border: Border.all(
                          color: isChecked
                              ? WaselColors.secondary
                              : (isDark
                                  ? WaselColors.borderDark
                                  : WaselColors.borderLight),
                          width: isChecked ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? WaselColors.secondary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isChecked
                                    ? WaselColors.secondary
                                    : (isDark
                                        ? WaselColors.borderDark
                                        : WaselColors.borderLight),
                                width: 2,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black26
                                            : Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${item.quantity}x',
                                        style: WaselTypography.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? WaselColors.textPrimaryDark
                                              : WaselColors.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: WaselTypography.cairo(
                                          fontSize: 14,
                                          fontWeight: isChecked
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: isDark
                                              ? WaselColors.textPrimaryDark
                                              : WaselColors.textPrimaryLight,
                                          decoration: isChecked
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.note != null &&
                                    item.note!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'ملاحظة: ${item.note}',
                                    style: WaselTypography.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: WaselColors.primaryAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (item.price != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${item.price!.toStringAsFixed(2)} د.ل',
                              style: WaselTypography.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? WaselColors.textSecondaryDark
                                    : WaselColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            if (widget.customerNote != null &&
                widget.customerNote!.isNotEmpty) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? WaselColors.cardElevatedDark
                        : WaselColors.borderSubtleLight,
                    borderRadius: WaselRadius.radiusMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 16, color: WaselColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ملاحظات الزبون: ${widget.customerNote}',
                          style: WaselTypography.cairo(
                            fontSize: 11,
                            color: isDark
                                ? WaselColors.textSecondaryDark
                                : WaselColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Total and Approval Action Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (widget.totalPrice != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'إجمالي الفاتورة:',
                          style: WaselTypography.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? WaselColors.textSecondaryDark
                                : WaselColors.textSecondaryLight,
                          ),
                        ),
                        OdometerCounter(
                          value: widget.totalPrice!,
                          suffix: ' د.ل',
                          style: WaselTypography.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  WaselButton.secondary(
                    text: _isAllChecked
                        ? 'تأكيد ومطابقة الفاتورة واستلام الطلب ✓'
                        : 'يرجى مراجعة كافة الأصناف للمتابعة',
                    enabled: _isAllChecked,
                    isFullWidth: true,
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      widget.onApproved();
                      Navigator.of(context).maybePop();
                    },
                  ),
                  if (widget.onContactMerchant != null) ...[
                    const SizedBox(height: 8),
                    WaselButton.outline(
                      text: 'إبلاغ عن نقص أو خطأ في الطلب',
                      isFullWidth: true,
                      onPressed: widget.onContactMerchant,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

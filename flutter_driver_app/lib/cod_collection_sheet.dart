import 'package:flutter/material.dart';
import 'driver_theme.dart';

/// ============================================================================
/// CASH ON DELIVERY (COD) COLLECTION & CHANGE CALCULATOR SHEET (LYD)
/// ============================================================================

class CodCollectionSheet extends StatefulWidget {
  final double requiredAmountLyd;
  final String orderNumber;
  final ValueChanged<double> onConfirmed;

  const CodCollectionSheet({
    super.key,
    required this.requiredAmountLyd,
    required this.orderNumber,
    required this.onConfirmed,
  });

  static Future<bool?> show(
    BuildContext context, {
    required double requiredAmountLyd,
    required String orderNumber,
    required ValueChanged<double> onConfirmed,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CodCollectionSheet(
          requiredAmountLyd: requiredAmountLyd,
          orderNumber: orderNumber,
          onConfirmed: onConfirmed,
        ),
      ),
    );
  }

  @override
  State<CodCollectionSheet> createState() => _CodCollectionSheetState();
}

class _CodCollectionSheetState extends State<CodCollectionSheet> {
  late double _tenderedAmount;
  final TextEditingController _customController = TextEditingController();
  bool _isConfirmedByDriver = false;

  @override
  void initState() {
    super.initState();
    _tenderedAmount = widget.requiredAmountLyd;
    _customController.text = _tenderedAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  double get _changeToReturn => (_tenderedAmount - widget.requiredAmountLyd).clamp(0.0, 9999.0);
  bool get _isUnderpaid => _tenderedAmount < widget.requiredAmountLyd;

  void _selectQuickAmount(double amount) {
    setState(() {
      _tenderedAmount = amount;
      _customController.text = amount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickOptions = {
      widget.requiredAmountLyd,
      (widget.requiredAmountLyd <= 50.0) ? 50.0 : widget.requiredAmountLyd,
      (widget.requiredAmountLyd <= 100.0) ? 100.0 : widget.requiredAmountLyd + 50.0,
      (widget.requiredAmountLyd <= 200.0) ? 200.0 : widget.requiredAmountLyd + 100.0,
    }.toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: DriverColors.codWarning.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DriverColors.codWarning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded, color: DriverColors.codWarning, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'تحصيل كاش عند الاستلام (COD)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            'طلب رقم: ${widget.orderNumber}',
                            style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Total Required Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DriverColors.codWarning.withValues(alpha: 0.1),
                  borderRadius: DriverRadius.radiusLg,
                  border: Border.all(color: DriverColors.codWarning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المبلغ المطلوب تحصيله:', style: TextStyle(fontSize: 13, color: Colors.white70)),
                        Text('شامل تكلفة الطلب والتوصيل', style: TextStyle(fontSize: 11, color: DriverColors.darkTextMuted)),
                      ],
                    ),
                    Text(
                      '${widget.requiredAmountLyd.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: DriverColors.codWarning,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Libyan Banknotes
              const Text('اختر المبلغ المستلم من الزبون:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: quickOptions.map((amount) {
                  final isSelected = (_tenderedAmount == amount);
                  return ChoiceChip(
                    label: Text(
                      amount == widget.requiredAmountLyd ? 'المبلغ بالضبط (${amount.toStringAsFixed(0)} د.ل)' : '${amount.toStringAsFixed(0)} د.ل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: DriverColors.primary,
                    backgroundColor: isDark ? DriverColors.darkCardElevated : Colors.grey[200],
                    onSelected: (selected) {
                      if (selected) _selectQuickAmount(amount);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Change to return display
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? DriverColors.darkCardElevated : Colors.grey[100],
                  borderRadius: DriverRadius.radiusMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ المتبقي للزبون (الفكة):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      '${_changeToReturn.toStringAsFixed(2)} د.ل',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _changeToReturn > 0 ? DriverColors.onlineGreen : Colors.white60,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Confirmation Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: DriverColors.onlineGreen,
                value: _isConfirmedByDriver,
                onChanged: (val) => setState(() => _isConfirmedByDriver = val ?? false),
                title: const Text(
                  'أؤكد استلام المبلغ نقداً من الزبون بالكامل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 12),

              // Confirm button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_isConfirmedByDriver && !_isUnderpaid)
                      ? () {
                          widget.onConfirmed(_tenderedAmount);
                          Navigator.pop(context, true);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DriverColors.onlineGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                  ),
                  child: const Text(
                    'تأكيد تحصيل الكاش وإتمام التسليم ✅',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

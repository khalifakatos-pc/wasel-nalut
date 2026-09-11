import 'package:flutter/material.dart';
import 'driver_theme.dart';

/// ============================================================================
/// CASH ON DELIVERY (COD) COLLECTION & CHANGE CALCULATOR SHEET
/// ============================================================================
/// Assures accurate Libyan Dinar (LYD) cash handover with quick currency
/// note buttons, change calculation, and driver verification check.
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

    // Standard Libyan Banknotes & denominations (10 LYD, 20 LYD, 50 LYD, 100 LYD)
    final quickOptions = [
      widget.requiredAmountLyd, // Exact
      (widget.requiredAmountLyd <= 50.0) ? 50.0 : widget.requiredAmountLyd,
      (widget.requiredAmountLyd <= 100.0) ? 100.0 : widget.requiredAmountLyd + 50.0,
      (widget.requiredAmountLyd <= 200.0) ? 200.0 : widget.requiredAmountLyd + 100.0,
    ].toSet().toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkSurface : Colors.white,
        borderRadius: DriverRadius.topSheet,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                    borderRadius: DriverRadius.radiusFull,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Order Ref
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DriverColors.codWarning.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payments_rounded, color: DriverColors.codWarning, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Collection (COD)',
                            style: DriverTypography.headlineMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            'Order ${widget.orderNumber}',
                            style: DriverTypography.bodySmall.copyWith(
                              color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DriverColors.codWarning.withValues(alpha: 0.18),
                      borderRadius: DriverRadius.radiusSm,
                    ),
                    child: Text(
                      'Cash Payment',
                      style: DriverTypography.labelSmall.copyWith(color: DriverColors.codWarning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Due Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? DriverColors.darkCard : const Color(0xFFFFF7ED),
                  borderRadius: DriverRadius.radiusLg,
                  border: Border.all(
                    color: DriverColors.codWarning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL CASH DUE FROM CUSTOMER',
                          style: DriverTypography.labelSmall.copyWith(
                            color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DriverTheme.formatLyd(widget.requiredAmountLyd),
                          style: DriverTypography.displayMedium.copyWith(
                            color: DriverColors.codWarning,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.receipt_long_rounded, color: DriverColors.codWarning, size: 36),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tendered Cash Input / Quick Presets
              Text(
                'Customer Tendered Cash (LYD)',
                style: DriverTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Quick Note Buttons
              Wrap(
                spacing: 8,
                children: quickOptions.map((amount) {
                  final isSelected = (_tenderedAmount - amount).abs() < 0.01;
                  return ChoiceChip(
                    label: Text(
                      amount == widget.requiredAmountLyd ? 'Exact (${amount.toStringAsFixed(0)} LYD)' : '${amount.toStringAsFixed(0)} LYD',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : DriverColors.lightTextPrimary),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: DriverColors.primary,
                    backgroundColor: isDark ? DriverColors.darkCard : const Color(0xFFE2E8F0),
                    onSelected: (_) => _selectQuickAmount(amount),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Change Return Display
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isUnderpaid
                      ? DriverColors.urgentRed.withValues(alpha: 0.1)
                      : DriverColors.onlineGreen.withValues(alpha: 0.1),
                  borderRadius: DriverRadius.radiusLg,
                  border: Border.all(
                    color: _isUnderpaid ? DriverColors.urgentRed : DriverColors.onlineGreen,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isUnderpaid ? 'Underpaid Amount (Short):' : 'Change to Return to Customer:',
                      style: DriverTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _isUnderpaid ? DriverColors.urgentRed : DriverColors.onlineGreen,
                      ),
                    ),
                    Text(
                      _isUnderpaid
                          ? DriverTheme.formatLyd(widget.requiredAmountLyd - _tenderedAmount)
                          : DriverTheme.formatLyd(_changeToReturn),
                      style: DriverTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _isUnderpaid ? DriverColors.urgentRed : DriverColors.onlineGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Confirmation Checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isConfirmedByDriver,
                onChanged: (val) {
                  setState(() {
                    _isConfirmedByDriver = val ?? false;
                  });
                },
                activeColor: DriverColors.onlineGreen,
                title: Text(
                  'I confirm receiving ${DriverTheme.formatLyd(widget.requiredAmountLyd)} cash in full from the customer.',
                  style: DriverTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : DriverColors.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isConfirmedByDriver && !_isUnderpaid
                      ? () {
                          Navigator.of(context).pop(true);
                          widget.onConfirmed(widget.requiredAmountLyd);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DriverColors.onlineGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                  ),
                  child: Text(
                    'Confirm Cash Collected',
                    style: DriverTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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

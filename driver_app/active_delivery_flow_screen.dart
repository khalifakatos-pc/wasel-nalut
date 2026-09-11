import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'simulated_driver_map.dart';
import 'otp_input_field.dart';
import 'cod_collection_sheet.dart';

/// ============================================================================
/// ACTIVE DELIVERY WORKFLOW SCREEN (4-STEP STATE MACHINE)
/// ============================================================================
/// Step 1: Navigating to Store (Pickup location, Call store, Arrived button)
/// Step 2: Order Pickup Confirmation (Item checklist & QR Scan verification)
/// Step 3: Navigating to Customer (Dropoff pin, Call customer, SMS button)
/// Step 4: Complete Delivery (4-digit OTP verification & Cash Collection modal)
/// ============================================================================

class ActiveDeliveryFlowScreen extends StatefulWidget {
  final ActiveDeliveryOrder order;
  final VoidCallback onFinishedDelivery;

  const ActiveDeliveryFlowScreen({
    super.key,
    required this.order,
    required this.onFinishedDelivery,
  });

  @override
  State<ActiveDeliveryFlowScreen> createState() => _ActiveDeliveryFlowScreenState();
}

class _ActiveDeliveryFlowScreenState extends State<ActiveDeliveryFlowScreen> {
  late ActiveDeliveryOrder _activeOrder;
  bool _isQrScanned = false;
  bool _isOtpVerified = false;
  bool _isCashCollected = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _activeOrder = widget.order;
    // If prepaid, COD is already resolved
    if (_activeOrder.paymentType != PaymentType.cashOnDelivery) {
      _isCashCollected = true;
    }
  }

  void _advanceToStep(DeliveryStep step) {
    setState(() {
      _activeOrder.currentStep = step;
    });
  }

  void _onAllItemsToggled(bool value) {
    setState(() {
      for (var item in _activeOrder.items) {
        item.isChecked = value;
      }
    });
  }

  void _openQrScannerSimulator() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DriverColors.darkSurface,
          shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusXl),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: DriverColors.primary),
              SizedBox(width: 8),
              Text('Scan Merchant QR', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: DriverColors.primary, width: 2),
                  borderRadius: DriverRadius.radiusLg,
                  color: Colors.black,
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 90, color: Colors.white),
                      SizedBox(height: 6),
                      Text(
                        'Align merchant receipt QR',
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Merchant: ${_activeOrder.storeName}\nOrder: ${_activeOrder.orderNumber}',
                textAlign: TextAlign.center,
                style: DriverTypography.bodySmall.copyWith(color: DriverColors.darkTextMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isQrScanned = true;
                  for (var item in _activeOrder.items) {
                    item.isChecked = true;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Merchant QR code verified successfully!'),
                    backgroundColor: DriverColors.onlineGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: DriverColors.onlineGreen),
              child: const Text('Simulate Scan Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionCelebrationModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? DriverColors.darkSurface : Colors.white,
            borderRadius: DriverRadius.topSheet,
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DriverColors.acceptButtonGradient,
                ),
                child: const Icon(Icons.check_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Delivery Successfully Completed!',
                style: DriverTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Order ${_activeOrder.orderNumber} delivered to ${_activeOrder.customerName}',
                style: DriverTypography.bodySmall.copyWith(
                  color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Payout Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? DriverColors.darkCard : const Color(0xFFECFDF5),
                  borderRadius: DriverRadius.radiusLg,
                  border: Border.all(color: DriverColors.onlineGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EARNINGS CREDITED TO WALLET',
                          style: DriverTypography.labelSmall.copyWith(
                            color: DriverColors.onlineGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DriverTheme.formatLyd(_activeOrder.driverPayoutLyd),
                          style: DriverTypography.displayMedium.copyWith(
                            color: DriverColors.onlineGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.account_balance_wallet_rounded, size: 36, color: DriverColors.onlineGreen),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Back to Radar Action
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onFinishedDelivery();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DriverColors.primary,
                    shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
                  ),
                  child: Text(
                    'Return to Radar (Find Next Order)',
                    style: DriverTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DriverColors.darkBg : DriverColors.lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DriverColors.onlineGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Active Order ${_activeOrder.orderNumber}',
                  style: DriverTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            Text(
              _getStepSubtitle(),
              style: DriverTypography.bodySmall.copyWith(
                color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calling Wasel Dispatcher Support (+218 21 000 0000)...'),
                  backgroundColor: DriverColors.darkCard,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Navigation Map Header
          SimulatedDriverMap(
            height: MediaQuery.of(context).size.height * 0.30,
            activeStep: _activeOrder.currentStep,
            storeName: _activeOrder.storeName,
            destinationAddress: _activeOrder.customerAddress,
          ),

          // 2. 4-Step Progress Indicator Bar
          _buildStepProgressBar(isDark),

          // 3. Dynamic Step Body View
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: _buildCurrentStepContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepSubtitle() {
    switch (_activeOrder.currentStep) {
      case DeliveryStep.navigatingToStore:
        return 'Step 1: En route to Pickup';
      case DeliveryStep.orderPickupChecklist:
        return 'Step 2: Merchant Pickup Checklist';
      case DeliveryStep.navigatingToCustomer:
        return 'Step 3: En route to Customer';
      case DeliveryStep.completeDeliveryOtp:
        return 'Step 4: OTP Verification & Handover';
      case DeliveryStep.deliveryFinished:
        return 'Trip Completed';
    }
  }

  /// 4-Step Progress Horizontal Stepper
  Widget _buildStepProgressBar(bool isDark) {
    final steps = [
      {'title': 'Store', 'step': DeliveryStep.navigatingToStore},
      {'title': 'Pickup', 'step': DeliveryStep.orderPickupChecklist},
      {'title': 'Customer', 'step': DeliveryStep.navigatingToCustomer},
      {'title': 'Verify & Pay', 'step': DeliveryStep.completeDeliveryOtp},
    ];

    final currentIndex = _activeOrder.currentStep.index;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? DriverColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isEven) {
            final stepIdx = i ~/ 2;
            final isCompleted = stepIdx < currentIndex;
            final isCurrent = stepIdx == currentIndex;

            return Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? DriverColors.onlineGreen
                        : (isCurrent ? DriverColors.primary : Colors.transparent),
                    border: Border.all(
                      color: isCompleted
                          ? DriverColors.onlineGreen
                          : (isCurrent
                              ? DriverColors.primary
                              : (isDark ? DriverColors.darkBorder : DriverColors.lightTextMuted)),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                        : Text(
                            '${stepIdx + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? Colors.white
                                  : (isDark ? Colors.white60 : DriverColors.lightTextMuted),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[stepIdx]['title'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent
                        ? (isDark ? Colors.white : DriverColors.lightTextPrimary)
                        : (isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary),
                  ),
                ),
              ],
            );
          } else {
            final stepIdx = i ~/ 2;
            final isPassed = stepIdx < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isPassed
                    ? DriverColors.onlineGreen
                    : (isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1)),
              ),
            );
          }
        }),
      ),
    );
  }

  /// Current Step Content Switcher
  Widget _buildCurrentStepContent(bool isDark) {
    switch (_activeOrder.currentStep) {
      case DeliveryStep.navigatingToStore:
        return _buildStep1NavigatingToStore(isDark);
      case DeliveryStep.orderPickupChecklist:
        return _buildStep2PickupChecklist(isDark);
      case DeliveryStep.navigatingToCustomer:
        return _buildStep3NavigatingToCustomer(isDark);
      case DeliveryStep.completeDeliveryOtp:
      case DeliveryStep.deliveryFinished:
        return _buildStep4CompleteDelivery(isDark);
    }
  }

  /// ---------------------------------------------------------------------------
  /// STEP 1: NAVIGATING TO STORE
  /// ---------------------------------------------------------------------------
  Widget _buildStep1NavigatingToStore(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? DriverColors.darkCard : Colors.white,
            borderRadius: DriverRadius.radiusLg,
            border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DriverColors.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: DriverColors.secondary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activeOrder.storeName,
                                style: DriverTypography.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                _activeOrder.storeAddress,
                                style: DriverTypography.bodySmall.copyWith(
                                  color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Kitchen prep status pill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: DriverRadius.radiusMd,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: Color(0xFFD97706)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kitchen Status: Order being packed (Ready in ~3 mins)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Store Contact Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calling Store at ${_activeOrder.storePhone}...'),
                            backgroundColor: DriverColors.darkCard,
                          ),
                        );
                      },
                      icon: const Icon(Icons.phone_rounded, size: 18, color: DriverColors.onlineGreen),
                      label: const Text('Call Store'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening Google Maps navigation to Store...'),
                            backgroundColor: DriverColors.darkCard,
                          ),
                        );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18, color: DriverColors.primary),
                      label: const Text('Google Maps'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Arrived at Store CTA Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _advanceToStep(DeliveryStep.orderPickupChecklist),
            icon: const Icon(Icons.place_rounded, size: 22),
            label: Text(
              'I HAVE ARRIVED AT STORE',
              style: DriverTypography.labelLarge.copyWith(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DriverColors.secondary,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// STEP 2: ORDER PICKUP CONFIRMATION & CHECKLIST
  /// ---------------------------------------------------------------------------
  Widget _buildStep2PickupChecklist(bool isDark) {
    final allChecked = _activeOrder.items.every((item) => item.isChecked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // QR Code Scan Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isQrScanned
                  ? [const Color(0xFF059669), const Color(0xFF10B981)]
                  : [const Color(0xFF7C3AED), const Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: DriverRadius.radiusLg,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isQrScanned ? Icons.verified_rounded : Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isQrScanned ? 'Merchant QR Verified' : 'Scan Merchant QR Receipt',
                        style: DriverTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _isQrScanned ? 'Match confirmed by camera' : 'Verify order package barcode',
                        style: DriverTypography.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!_isQrScanned)
                ElevatedButton(
                  onPressed: _openQrScannerSimulator,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: DriverColors.accentPurple,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text('Scan QR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Items Checklist Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order Checklist (${_activeOrder.items.length} items)',
              style: DriverTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : DriverColors.lightTextPrimary,
              ),
            ),
            TextButton(
              onPressed: () => _onAllItemsToggled(!allChecked),
              child: Text(
                allChecked ? 'Uncheck All' : 'Select All',
                style: const TextStyle(color: DriverColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Items List
        ...List.generate(_activeOrder.items.length, (index) {
          final item = _activeOrder.items[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? DriverColors.darkCard : Colors.white,
              borderRadius: DriverRadius.radiusMd,
              border: Border.all(
                color: item.isChecked
                    ? DriverColors.onlineGreen.withValues(alpha: 0.5)
                    : (isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
              ),
            ),
            child: CheckboxListTile(
              activeColor: DriverColors.onlineGreen,
              value: item.isChecked,
              onChanged: (val) {
                setState(() {
                  item.isChecked = val ?? false;
                });
              },
              title: Text(
                '${item.quantity}x ${item.name}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                ),
              ),
              subtitle: item.options != null
                  ? Text(
                      item.options!,
                      style: DriverTypography.bodySmall.copyWith(
                        color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                      ),
                    )
                  : null,
            ),
          );
        }),
        const SizedBox(height: 20),

        // Confirm Pickup CTA
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: allChecked || _isQrScanned
                ? () => _advanceToStep(DeliveryStep.navigatingToCustomer)
                : null,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
            label: Text(
              'CONFIRM PICKUP & START DELIVERY',
              style: DriverTypography.labelLarge.copyWith(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DriverColors.onlineGreen,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// STEP 3: NAVIGATING TO CUSTOMER
  /// ---------------------------------------------------------------------------
  Widget _buildStep3NavigatingToCustomer(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Information Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? DriverColors.darkCard : Colors.white,
            borderRadius: DriverRadius.radiusLg,
            border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DriverColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_pin_circle_rounded, color: DriverColors.primary, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _activeOrder.customerName,
                          style: DriverTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          _activeOrder.customerAddress,
                          style: DriverTypography.bodySmall.copyWith(
                            color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Customer Special Delivery Notes
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D2E) : const Color(0xFFEFF6FF),
                  borderRadius: DriverRadius.radiusMd,
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Note:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            _activeOrder.customerNotes,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : DriverColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Customer Contact Buttons (Call & SMS)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calling Customer ${_activeOrder.customerPhone}...'),
                            backgroundColor: DriverColors.darkCard,
                          ),
                        );
                      },
                      icon: const Icon(Icons.phone_rounded, size: 18, color: DriverColors.onlineGreen),
                      label: const Text('Call Customer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SMS Template sent: "Captain arriving in 2 minutes!"'),
                            backgroundColor: DriverColors.sadadBlue,
                          ),
                        );
                      },
                      icon: const Icon(Icons.sms_rounded, size: 18, color: DriverColors.sadadBlue),
                      label: const Text('Send SMS'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Arrived at Customer CTA
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _advanceToStep(DeliveryStep.completeDeliveryOtp),
            icon: const Icon(Icons.doorbell_rounded, size: 22),
            label: Text(
              'I HAVE ARRIVED AT CUSTOMER',
              style: DriverTypography.labelLarge.copyWith(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: DriverColors.primary,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// STEP 4: COMPLETE DELIVERY WITH OTP & CASH COLLECTION
  /// ---------------------------------------------------------------------------
  Widget _buildStep4CompleteDelivery(bool isDark) {
    final isCod = _activeOrder.paymentType == PaymentType.cashOnDelivery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OTP Instruction Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? DriverColors.darkCard : Colors.white,
            borderRadius: DriverRadius.radiusLg,
            border: Border.all(color: isDark ? DriverColors.darkBorder : DriverColors.lightBorder),
          ),
          child: Column(
            children: [
              Text(
                'Enter 4-Digit Customer OTP',
                style: DriverTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : DriverColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask customer for their delivery verification code shown in their Wasel App',
                textAlign: TextAlign.center,
                style: DriverTypography.bodySmall.copyWith(
                  color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // OTP Segmented Input Field Component
              OtpInputField(
                correctOtp: _activeOrder.customerOtpPin,
                onCompleted: (otp) {
                  setState(() {
                    _isOtpVerified = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Customer OTP verified successfully!'),
                      backgroundColor: DriverColors.onlineGreen,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Cash Collection Card (if COD)
        if (isCod)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? DriverColors.darkCard : const Color(0xFFFFF7ED),
              borderRadius: DriverRadius.radiusLg,
              border: Border.all(
                color: _isCashCollected ? DriverColors.onlineGreen : DriverColors.codWarning,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isCashCollected ? Icons.check_circle_rounded : Icons.payments_rounded,
                          color: _isCashCollected ? DriverColors.onlineGreen : DriverColors.codWarning,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCashCollected ? 'Cash Collected & Verified' : 'Cash on Delivery (COD) Required',
                          style: DriverTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _isCashCollected ? DriverColors.onlineGreen : DriverColors.codWarning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Collect ${DriverTheme.formatLyd(_activeOrder.codAmountLyd)} from customer before handing package.',
                  style: DriverTypography.bodySmall.copyWith(
                    color: isDark ? DriverColors.darkTextMuted : DriverColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      CodCollectionSheet.show(
                        context,
                        requiredAmountLyd: _activeOrder.codAmountLyd,
                        orderNumber: _activeOrder.orderNumber,
                        onConfirmed: (amt) {
                          setState(() {
                            _isCashCollected = true;
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(_isCashCollected ? 'Update / Recalculate Cash' : 'Open Cash Calculator & Collect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCashCollected ? DriverColors.onlineGreen : DriverColors.codWarning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),

        // Final Complete Delivery Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_isOtpVerified && _isCashCollected && !_isCompleting)
                ? () {
                    setState(() {
                      _isCompleting = true;
                    });
                    _showCompletionCelebrationModal();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: DriverColors.onlineGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? DriverColors.darkBorder : const Color(0xFFCBD5E1),
              shape: const RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
              elevation: 4,
            ),
            child: Text(
              _isOtpVerified
                  ? (_isCashCollected ? 'COMPLETE DELIVERY (CREDIT PAYOUT)' : 'COLLECT CASH TO COMPLETE')
                  : 'ENTER 4-DIGIT OTP TO COMPLETE',
              style: DriverTypography.labelLarge.copyWith(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

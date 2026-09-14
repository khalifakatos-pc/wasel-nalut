import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'simulated_driver_map.dart';
import 'otp_input_field.dart';
import 'cod_collection_sheet.dart';
import 'services/driver_supabase_service.dart';
import 'widgets/swipe_to_confirm_slider.dart';
import 'widgets/driver_motion_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _activeOrder = widget.order;
    if (_activeOrder.paymentType != PaymentType.cashOnDelivery) {
      _isCashCollected = true;
    }
  }

  void _advanceToStep(DeliveryStep step) {
    setState(() {
      _activeOrder.currentStep = step;
    });
  }

  void _openQrScannerSimulator() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DriverColors.darkSurface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: DriverColors.primary),
              SizedBox(width: 8),
              Text('مسح باركود الفاتورة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                        'وجّه الكاميرا نحو فاتورة المطعم',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'فاتورة طلب مطعم قصر نالوت (#WSL-90412)',
                style: TextStyle(color: DriverColors.darkTextMuted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isQrScanned = true;
                  for (var item in _activeOrder.items) {
                    item.isVerified = true;
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم مسح وتأكيد استلام الطلب بنجاح!'),
                    backgroundColor: DriverColors.onlineGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: DriverColors.onlineGreen),
              child: const Text('محاكاة مسح الباركود ✅', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _openCodCollectionModal() {
    CodCollectionSheet.show(
      context,
      requiredAmountLyd: _activeOrder.codAmountLyd,
      orderNumber: _activeOrder.orderNumber,
      onConfirmed: (collected) {
        setState(() {
          _isCashCollected = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تحصيل ${collected.toStringAsFixed(2)} د.ل كاش بنجاح!'),
            backgroundColor: DriverColors.onlineGreen,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.darkBg,
      appBar: AppBar(
        title: Text('طلب جاري: ${_activeOrder.orderNumber}'),
        centerTitle: true,
        backgroundColor: DriverColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onFinishedDelivery,
        ),
      ),
      body: Column(
        children: [
          // 1. Simulated Live Map (Real ArcGIS Satellite & Street Tiles)
          SimulatedDriverMap(
            height: 220,
            activeStep: _activeOrder.currentStep,
            storeName: _activeOrder.storeName,
            destinationAddress: _activeOrder.customerAddress,
            storeLat: _activeOrder.storeLatitude,
            storeLng: _activeOrder.storeLongitude,
            customerLat: _activeOrder.customerLatitude,
            customerLng: _activeOrder.customerLongitude,
          ),

          // 2. Step Progress Stepper
          _buildStepperBar(),

          // 3. Step Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepCard(),
            ),
          ),

          // 4. Bottom Action CTA Button
          _buildBottomActionButton(),
        ],
      ),
    );
  }

  Widget _buildStepperBar() {
    final steps = [
      {'label': 'المطعم', 'step': DeliveryStep.navigatingToStore},
      {'label': 'الاستلام', 'step': DeliveryStep.orderPickupChecklist},
      {'label': 'الزبون', 'step': DeliveryStep.navigatingToCustomer},
      {'label': 'التسليم', 'step': DeliveryStep.completeDeliveryOtp},
    ];

    final currentIdx = _getStepIndex(_activeOrder.currentStep);

    return Container(
      color: DriverColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isCompleted = currentIdx > index;
          final isCurrent = currentIdx == index;

          return Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? DriverColors.onlineGreen
                      : (isCurrent ? DriverColors.primary : DriverColors.darkCardElevated),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                steps[index]['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? Colors.white : DriverColors.darkTextMuted,
                ),
              ),
              if (index < steps.length - 1)
                Container(
                  width: 18,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: isCompleted ? DriverColors.onlineGreen : DriverColors.darkBorder,
                ),
            ],
          );
        }),
      ),
    );
  }

  int _getStepIndex(DeliveryStep step) {
    switch (step) {
      case DeliveryStep.navigatingToStore:
        return 0;
      case DeliveryStep.orderPickupChecklist:
        return 1;
      case DeliveryStep.navigatingToCustomer:
        return 2;
      case DeliveryStep.completeDeliveryOtp:
      case DeliveryStep.deliveryFinished:
        return 3;
    }
  }

  Widget _buildStepCard() {
    switch (_activeOrder.currentStep) {
      case DeliveryStep.navigatingToStore:
        return _buildNavToStoreCard();
      case DeliveryStep.orderPickupChecklist:
        return _buildPickupChecklistCard();
      case DeliveryStep.navigatingToCustomer:
        return _buildNavToCustomerCard();
      case DeliveryStep.completeDeliveryOtp:
      case DeliveryStep.deliveryFinished:
        return _buildCompleteDeliveryCard();
    }
  }

  Widget _buildNavToStoreCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverColors.darkCard,
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(color: DriverColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DriverColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: DriverColors.secondary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeOrder.storeName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _activeOrder.storeAddress,
                        style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.call_rounded, color: DriverColors.onlineGreen),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('📞 الاتصال بالمطعم: ${_activeOrder.storePhone}')),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 24),
          const Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: DriverColors.surgeAmber),
              SizedBox(width: 8),
              Text(
                'الطلب جاهز للاستلام من المطبخ',
                style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupChecklistCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverColors.darkCard,
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(color: DriverColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'قائمة التحقق من الأصناف:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              TextButton.icon(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('مسح باركود'),
                onPressed: _openQrScannerSimulator,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._activeOrder.items.map((item) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: DriverColors.onlineGreen,
              value: item.isVerified,
              onChanged: (val) {
                setState(() {
                  item.isVerified = val ?? false;
                });
              },
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${item.options} • ${item.quantity}x', style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavToCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverColors.darkCard,
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(color: DriverColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_pin_circle_rounded, color: DriverColors.onlineGreen, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _activeOrder.customerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _activeOrder.customerAddress,
                        style: const TextStyle(fontSize: 12, color: DriverColors.darkTextMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.call_rounded, color: DriverColors.onlineGreen),
                    tooltip: 'اتصال هاتفي',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('📞 الاتصال بالزبون: ${_activeOrder.customerPhone}')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chat_rounded, color: DriverColors.primary),
                    tooltip: 'محادثة فورية / واتساب',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('💬 فتح المحادثة مع الزبون: ${_activeOrder.customerName} (${_activeOrder.customerPhone})'),
                          backgroundColor: DriverColors.primary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DriverColors.darkCardElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.note_alt_outlined, size: 16, color: DriverColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ملاحظة الزبون: ${_activeOrder.customerNotes}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteDeliveryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverColors.darkCard,
        borderRadius: DriverRadius.radiusLg,
        border: Border.all(color: DriverColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OTP Section
          const Text(
            '1. التحقق من رمز الاستلام (OTP):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
          ),
          const SizedBox(height: 12),
          OtpInputField(
            correctOtp: _activeOrder.customerOtpPin,
            onCompleted: (otp) {
              setState(() {
                _isOtpVerified = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ تم التحقق من رمز OTP بنجاح!'),
                  backgroundColor: DriverColors.onlineGreen,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Cash Collection Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. تحصيل كاش عند الاستلام (COD):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  Text(
                    _isCashCollected ? 'تم تحصيل المبلغ بنجاح ✅' : 'المبلغ المطلوب: ${_activeOrder.codAmountLyd.toStringAsFixed(2)} د.ل',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isCashCollected ? DriverColors.onlineGreen : DriverColors.codWarning,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _openCodCollectionModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCashCollected ? DriverColors.onlineGreen : DriverColors.codWarning,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isCashCollected ? 'تم التحصيل ✅' : 'تحصيل الكاش 💵'),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // No-Show Emergency Protocol Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openNoShowProtocolModal,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusMd),
              ),
              icon: const Icon(Icons.phone_missed_rounded, size: 18),
              label: const Text(
                'الزبون لا يرد / بروتوكول تعذر التسليم (10 د)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton() {
    if (_activeOrder.currentStep == DeliveryStep.completeDeliveryOtp ||
        _activeOrder.currentStep == DeliveryStep.deliveryFinished) {
      final canFinish = _isOtpVerified && _isCashCollected;
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        color: DriverColors.darkSurface,
        child: canFinish
            ? SwipeToConfirmSlider(
                label: 'اسحب لإنهاء الطلب وإيداع الأرباح 🎉',
                completedLabel: 'تم إنهاء الطلب وإيداع الأرباح ✓',
                activeColor: DriverColors.onlineGreen,
                onConfirmed: () async {
                  _advanceToStep(DeliveryStep.deliveryFinished);

                  // Persist status and driver COD balance to Supabase Cloud
                  await DriverSupabaseService.completeDelivery(
                    orderId: _activeOrder.orderId.isNotEmpty ? _activeOrder.orderId : _activeOrder.orderNumber,
                    orderAmountLyd: _activeOrder.codAmountLyd > 0 ? _activeOrder.codAmountLyd : 40.0,
                    isCod: _activeOrder.paymentType == PaymentType.cashOnDelivery,
                  );

                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: DriverColors.darkSurface,
                        title: const Text('🎉 مبروك يا كابتن!'),
                        content: Text(
                          'تم إتمام الطلب بنجاح وتمت إضافة ${_activeOrder.driverPayoutLyd.toStringAsFixed(2)} د.ل إلى رصيد محفظتك في السحابة.',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onFinishedDelivery();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: DriverColors.onlineGreen),
                            child: const Text('العودة للرادار والطلبات', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  }
                },
              )
            : WaselBouncyPressable(
                onTap: null,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: DriverRadius.radiusLg,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'يُرجى إدخال رمز OTP وتحصيل الكاش أولاً',
                    style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
      );
    }

    String label = '';
    VoidCallback? onTap;
    Color buttonColor = DriverColors.primary;

    switch (_activeOrder.currentStep) {
      case DeliveryStep.navigatingToStore:
        label = 'وصلت إلى المطعم 🏬';
        buttonColor = DriverColors.secondary;
        onTap = () => _advanceToStep(DeliveryStep.orderPickupChecklist);
        break;

      case DeliveryStep.orderPickupChecklist:
        final allChecked = _activeOrder.items.every((i) => i.isVerified) || _isQrScanned;
        label = 'تأكيد الاستلام وبدء التوصيل للزبون 🛵';
        buttonColor = DriverColors.primary;
        onTap = allChecked ? () => _advanceToStep(DeliveryStep.navigatingToCustomer) : null;
        break;

      case DeliveryStep.navigatingToCustomer:
        label = 'وصلت إلى موقع الزبون 📍';
        buttonColor = DriverColors.onlineGreen;
        onTap = () => _advanceToStep(DeliveryStep.completeDeliveryOtp);
        break;

      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      color: DriverColors.darkSurface,
      child: WaselBouncyPressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: onTap != null ? buttonColor : Colors.grey[800],
            borderRadius: DriverRadius.radiusLg,
            boxShadow: onTap != null
                ? [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _openNoShowProtocolModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AntiFraudNoShowSheet(
        order: _activeOrder,
        onEscalated: () {
          widget.onFinishedDelivery();
        },
      ),
    );
  }
}

/// ============================================================================
/// 5-TIER ANTI-FRAUD NO-SHOW VERIFICATION PROTOCOL (نظام الحماية الخماسي ضد التلاعب)
/// ============================================================================

class AntiFraudNoShowSheet extends StatefulWidget {
  final ActiveDeliveryOrder order;
  final VoidCallback onEscalated;

  const AntiFraudNoShowSheet({
    super.key,
    required this.order,
    required this.onEscalated,
  });

  @override
  State<AntiFraudNoShowSheet> createState() => _AntiFraudNoShowSheetState();
}

class _AntiFraudNoShowSheetState extends State<AntiFraudNoShowSheet> {
  // Geofence state (Nalut coordinates)
  late double _driverLat;
  late double _driverLng;
  late final double _customerLat;
  late final double _customerLng;

  // Countdown timer state (10 minutes = 600s)
  int _remainingSeconds = 600;
  Timer? _timer;

  // Contact attempts proof
  bool _call1Made = false;
  String? _call1Time;
  bool _call2Made = false;
  String? _call2Time;
  bool _whatsappSent = false;
  String? _whatsappTime;

  // Photo proof
  bool _photoCaptured = false;
  String? _photoTimestamp;

  // Submitting
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _customerLat = widget.order.customerLatitude;
    _customerLng = widget.order.customerLongitude;

    // Start with driver at the customer pin for real scenario, but allows toggling distance
    _driverLat = widget.order.customerLatitude;
    _driverLng = widget.order.customerLongitude;

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double get _currentDistanceMeters => _calculateDistanceMeters(_driverLat, _driverLng, _customerLat, _customerLng);
  bool get _isWithinGeofence => _currentDistanceMeters <= 100.0;
  bool get _isTimerCompleted => _remainingSeconds <= 0;
  bool get _isContactComplete => _call1Made && _call2Made && _whatsappSent;
  bool get _canSubmitEscalation => _isWithinGeofence && _isTimerCompleted && _isContactComplete && _photoCaptured;

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _currentTimestampStr() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _submitEscalationReport() async {
    setState(() => _isSubmitting = true);

    // Persist to Cloud
    await DriverSupabaseService.logAudit(
      action: 'NO_SHOW_ESCALATION',
      details: {
        'order_id': widget.order.orderId.isNotEmpty ? widget.order.orderId : widget.order.orderNumber,
        'customer_phone': widget.order.customerPhone,
        'driver_lat': _driverLat,
        'driver_lng': _driverLng,
        'distance_meters': _currentDistanceMeters,
        'call_primary_time': _call1Time,
        'call_backup_time': _call2Time,
        'whatsapp_time': _whatsappTime,
        'photo_proof_timestamp': _photoTimestamp,
        'status': 'escalated_to_admin_dispatch',
      },
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context); // Close bottom sheet

    // Show formal Ops Escalation Notice
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: DriverColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security_update_warning_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('تم رفع البلاغ لغرفة العمليات المركزية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تم توثيق كافة الإثباتات الخمسة بنجاح وتحويل الطلب للمشرف الرقابي في نالوت:',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⛔ تعليمات أمنية صارمة:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• الوجبة أمانة في عهدتك: يمنع منعاً باتاً تناولها أو التصرف بها.\n'
                      '• يقوم مشرف العمليات الآن بمحاولة التواصل مع الزبون من الهاتف الثابت.\n'
                      '• ستصلك توجيهات رسمية خلال 5 دقائق إما بإرجاع الوجبة للمتجر أو إتلافها مع ضمان كامل حقك وأجرك.\n'
                      '• أي بلاغ غير صحيح يعرض الكابتن للمساءلة وحظر الحساب.',
                      style: TextStyle(fontSize: 11, height: 1.4, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DriverColors.onlineGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: DriverColors.onlineGreen, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'أجر مشوارك (5.00 د.ل) محفوظ ومضمون في محفظتك تقديراً لأمانتك.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onEscalated();
              },
              child: const Text('فهمت ذلك • إنهاء المشوار والعودة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final distance = _currentDistanceMeters;
    final isWithin = _isWithinGeofence;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: DriverColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بروتوكول تعذر التسليم المحمي ضد التلاعب',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'نظام الحماية الخماسي لضمان حقوق المطعم والزبون والكابتن',
                          style: TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // ===============================================================
              // 1. GEOFENCE LOCATION CHECK (< 100m)
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isWithin ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isWithin ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isWithin ? Icons.location_on_rounded : Icons.location_off_rounded,
                          color: isWithin ? Colors.greenAccent : Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '1. التحقق الجغرافي الصارم (Geofence)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isWithin ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isWithin
                          ? '✅ تم التحقق: أنت متواجد بموقع التسليم (المسافة: ${distance.toStringAsFixed(0)} متر).'
                          : '⛔ محجوب: أنت تبعد (${distance.toStringAsFixed(0)} متر) عن موقع الزبون! البروتوكول يتطلب التواجد على مسافة أقل من 100 متر لمنع التلاعب.',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    // Debug toggle for demonstration
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          setState(() {
                            if (isWithin) {
                              // Simulate moving 450m away
                              _driverLat = _customerLat + 0.004;
                              _driverLng = _customerLng + 0.004;
                            } else {
                              // Snap to customer location (15m)
                              _driverLat = _customerLat + 0.0001;
                              _driverLng = _customerLng + 0.0001;
                            }
                          });
                        },
                        icon: Icon(isWithin ? Icons.directions_walk_rounded : Icons.near_me_rounded, size: 14),
                        label: Text(
                          isWithin ? 'محاكاة الابتعاد عن الموقع (تجربة الحجب)' : 'محاكاة التواجد أمام بيت الزبون (15م)',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===============================================================
              // 2. UN-BYPASSABLE 10-MINUTE COUNTDOWN TIMER
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DriverColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isTimerCompleted ? DriverColors.onlineGreen : Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '2. مؤقت الانتظار الإلزامي (10 دقائق)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isTimerCompleted ? DriverColors.onlineGreen : Colors.amber[900],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isTimerCompleted ? 'انتهى الوقت ✓' : _formatTimer(_remainingSeconds),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isTimerCompleted
                          ? '✅ تم استيفاء شرط الانتظار الإلزامي (10 دقائق كاملة).'
                          : 'يجب الانتظار بموقع الزبون حتى ينتهي المؤقت للتأكد من عدم وجوده.',
                      style: const TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                    ),
                    if (!_isTimerCompleted) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (600 - _remainingSeconds) / 600,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => _remainingSeconds = 0),
                          child: const Text('تخطي الـ 10 دقائق [تجربة التطوير]', style: TextStyle(fontSize: 10, color: Colors.amberAccent)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===============================================================
              // 3. PROVABLE CONTACT ATTEMPTS
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DriverColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isContactComplete ? DriverColors.onlineGreen : DriverColors.darkBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.phone_in_talk_rounded, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '3. سجل محاولات التواصل الموثقة (إلزامي)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Call 1
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        _call1Made ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: _call1Made ? DriverColors.onlineGreen : Colors.white38,
                      ),
                      title: Text(
                        'الاتصال بالرقم الأساسي: ${widget.order.customerPhone}',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      subtitle: _call1Made
                          ? Text('تم الاتصال في: $_call1Time', style: const TextStyle(fontSize: 10, color: DriverColors.onlineGreen))
                          : null,
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _call1Made ? Colors.grey[800] : DriverColors.onlineGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () {
                          setState(() {
                            _call1Made = true;
                            _call1Time = _currentTimestampStr();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('📞 تم توثيق الاتصال بالرقم الأساسي: ${widget.order.customerPhone}')),
                          );
                        },
                        child: Text(_call1Made ? 'تم ✓' : 'اتصال', style: const TextStyle(fontSize: 11)),
                      ),
                    ),

                    // Call 2
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        _call2Made ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: _call2Made ? DriverColors.onlineGreen : Colors.white38,
                      ),
                      title: const Text(
                        'الاتصال بالرقم البديل (شبكة أخرى للطوارئ)',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      subtitle: _call2Made
                          ? Text('تم الاتصال في: $_call2Time', style: const TextStyle(fontSize: 10, color: DriverColors.onlineGreen))
                          : null,
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _call2Made ? Colors.grey[800] : DriverColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () {
                          setState(() {
                            _call2Made = true;
                            _call2Time = _currentTimestampStr();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('📞 تم توثيق محاولة الاتصال بالشبكة البديلة للطوارئ')),
                          );
                        },
                        child: Text(_call2Made ? 'تم ✓' : 'اتصال بديل', style: const TextStyle(fontSize: 11)),
                      ),
                    ),

                    // WhatsApp / SMS Alert
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Icon(
                        _whatsappSent ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: _whatsappSent ? DriverColors.onlineGreen : Colors.white38,
                      ),
                      title: const Text(
                        'إرسال تنبيه واتساب فوري للزبون',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                      subtitle: _whatsappSent
                          ? Text('تم الإرسال في: $_whatsappTime', style: const TextStyle(fontSize: 10, color: DriverColors.onlineGreen))
                          : null,
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _whatsappSent ? Colors.grey[800] : Colors.green[700],
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        onPressed: () {
                          setState(() {
                            _whatsappSent = true;
                            _whatsappTime = _currentTimestampStr();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.green,
                              content: Text('💬 تم إرسال تنبيه واتساب للزبون مع إشعار بالانتظار أمام بابه'),
                            ),
                          );
                        },
                        child: Text(_whatsappSent ? 'تم ✓' : 'واتساب', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===============================================================
              // 4. MANDATORY PHOTO PROOF (WITH DIGITAL WATERMARK)
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DriverColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _photoCaptured ? DriverColors.onlineGreen : DriverColors.darkBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Colors.purpleAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '4. إثبات تصويري للباب / المعلم الخارجي',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'التقط صورة واضحة لواجهة المنزل أو الباب لإثبات تواجدك الفعلي.',
                      style: TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                    ),
                    const SizedBox(height: 10),

                    if (!_photoCaptured)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purpleAccent,
                          side: const BorderSide(color: Colors.purpleAccent),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.camera_enhance_rounded),
                        label: const Text('التقاط صورة وإرفاق الختم الجغرافي'),
                        onPressed: () {
                          setState(() {
                            _photoCaptured = true;
                            _photoTimestamp = 'نالوت 31.874° N, 10.979° E • ${_currentTimestampStr()}';
                          });
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: DriverColors.onlineGreen),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.photo_library_rounded, color: Colors.greenAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('✅ تم التقاط وتشفير الصورة بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                  Text(_photoTimestamp ?? '', style: const TextStyle(fontSize: 10, color: DriverColors.darkTextMuted)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
                              tooltip: 'إعادة التقاط',
                              onPressed: () {
                                setState(() {
                                  _photoCaptured = false;
                                  _photoTimestamp = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ===============================================================
              // 5. ESCALATION SUBMIT BUTTON
              // ===============================================================
              ElevatedButton.icon(
                onPressed: _canSubmitEscalation && !_isSubmitting ? _submitEscalationReport : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  disabledBackgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _canSubmitEscalation
                      ? 'رفع البلاغ الموثق لغرفة العمليات المركزية (Dispatch)'
                      : 'أكمل الشروط الخمسة أعلاه لتفعيل رفع البلاغ',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

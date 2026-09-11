import 'package:flutter/material.dart';
import 'driver_theme.dart';
import 'driver_models.dart';
import 'simulated_driver_map.dart';
import 'otp_input_field.dart';
import 'cod_collection_sheet.dart';
import 'services/driver_supabase_service.dart';

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
          // 1. Simulated Live Map
          SimulatedDriverMap(
            height: 220,
            activeStep: _activeOrder.currentStep,
            storeName: _activeOrder.storeName,
            destinationAddress: _activeOrder.customerAddress,
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
    String label;
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

      case DeliveryStep.completeDeliveryOtp:
      case DeliveryStep.deliveryFinished:
        final canFinish = _isOtpVerified && _isCashCollected;
        label = 'إنهاء الطلب وإيداع الأرباح في المحفظة 🎉';
        buttonColor = DriverColors.onlineGreen;
        onTap = canFinish
            ? () async {
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
              }
            : null;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      color: DriverColors.darkSurface,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[800],
            shape: RoundedRectangleBorder(borderRadius: DriverRadius.radiusLg),
            elevation: 4,
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _openNoShowProtocolModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DriverColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.phone_missed_rounded, color: Colors.amber, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بروتوكول تعذر التسليم (الزبون لا يرد)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                          Text(
                            'اتبع الخطوات الإلزامية لحفظ حقك في أجر التوصيل وحق المطعم',
                            style: TextStyle(fontSize: 11, color: DriverColors.darkTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Step 1: Primary Call
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: DriverColors.darkCardElevated,
                    child: Text('1', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('الاتصال بالرقم الأساسي: ${_activeOrder.customerPhone}', style: const TextStyle(fontSize: 13, color: Colors.white)),
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('📞 جاري الاتصال بالرقم الأساسي: ${_activeOrder.customerPhone}')),
                      );
                    },
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.onlineGreen),
                  ),
                ),

                // Step 2: Alternate / Backup Call
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: DriverColors.darkCardElevated,
                    child: Text('2', style: TextStyle(color: Colors.white)),
                  ),
                  title: const Text('الاتصال بالرقم البديل (شبكة الطوارئ)', style: TextStyle(fontSize: 13, color: Colors.white)),
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('📞 جاري الاتصال بالرقم البديل للزبون...')),
                      );
                    },
                    icon: const Icon(Icons.phone_in_talk, size: 16),
                    label: const Text('رقم بديل'),
                    style: ElevatedButton.styleFrom(backgroundColor: DriverColors.primary),
                  ),
                ),

                // Step 3: WhatsApp Quick Alert
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: DriverColors.darkCardElevated,
                    child: Text('3', style: TextStyle(color: Colors.white)),
                  ),
                  title: const Text('إرسال تنبيه واتساب فوري للزبون', style: TextStyle(fontSize: 13, color: Colors.white)),
                  trailing: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('💬 تم إرسال رسالة: "كابتن واصل أمام منزلك ومعه طلبيتك" عبر واتساب'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('واتساب'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),

                const SizedBox(height: 12),

                // 10-Minute Waiting Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'قاعدة الـ 10 دقائق: إذا لم يرد الزبون بعد 3 محاولات وانتظار 10 دقائق، اضغط الزر بالأسفل.',
                          style: TextStyle(fontSize: 11, color: Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Confirm No-Show CTA
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmNoShowAndFinish();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cancel_presentation_rounded),
                  label: const Text(
                    'تأكيد تعذر التسليم (إلغاء مع ضمان أجر الكابتن)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmNoShowAndFinish() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: DriverColors.darkSurface,
          title: const Text('إثبات حالة عدم رد الزبون'),
          content: const Text(
            'سيتم تسجيل الطلب كـ (تعذر التسليم - زبون لا يرد).\n'
            '• أجر التوصيل (5.00 د.ل) مضمون وسيُضاف لمحفظتك فوراً.\n'
            '• تصريح تلقائي: يمكنك الاحتفاظ بالوجبة كإكرامية ومكافأة لك على تعبك.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DriverColors.onlineGreen, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onFinishedDelivery();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: DriverColors.onlineGreen,
                    content: Text('✅ تم إثبات الحالة بنجاح وإضافة أجر التوصيل لمحفظتك! شكراً لأمانتك.'),
                  ),
                );
              },
              child: const Text('تأكيد وإنهاء المشوار'),
            ),
          ],
        ),
      ),
    );
  }
}

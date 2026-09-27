import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel_captain_app/driver_models.dart';
import 'package:wasel_captain_app/services/driver_supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Captain Active Delivery Persistence & Protection Tests', () {
    test('ActiveDeliveryOrder serializes to JSON and restores correctly', () {
      final order = ActiveDeliveryOrder(
        orderId: 'ord_nalut_99',
        orderNumber: '#W-999',
        storeName: 'مطعم القلعة نالوت',
        storePhone: '091-2233445',
        storeAddress: 'نالوت - الشارع الرئيسي',
        storeLatitude: 31.8680,
        storeLongitude: 10.9850,
        customerName: 'سالم النالوتي',
        customerPhone: '091-9988776',
        customerAddress: 'نالوت - حي السلام',
        customerNotes: 'الاتصال عند الوصول',
        customerLatitude: 31.8620,
        customerLongitude: 10.9780,
        paymentType: PaymentType.cashOnDelivery,
        codAmountLyd: 45.0,
        customerOtpPin: '7890',
        driverPayoutLyd: 8.5,
        currentStep: DeliveryStep.orderPickupChecklist,
        orderStatus: 'ready_for_pickup',
        items: [
          DeliveryItem(
            name: 'كسكسي بالبصلة نالوتي',
            quantity: 2,
            options: 'حار',
            unitPriceLyd: 22.5,
            isVerified: true,
          ),
        ],
      );

      final json = order.toJson();
      expect(json['orderId'], 'ord_nalut_99');
      expect(json['orderNumber'], '#W-999');
      expect(json['codAmountLyd'], 45.0);
      expect(json['currentStep'], 'orderPickupChecklist');
      expect(json['orderStatus'], 'ready_for_pickup');

      final restored = ActiveDeliveryOrder.fromJson(json);
      expect(restored.orderId, 'ord_nalut_99');
      expect(restored.orderNumber, '#W-999');
      expect(restored.storeName, 'مطعم القلعة نالوت');
      expect(restored.customerName, 'سالم النالوتي');
      expect(restored.codAmountLyd, 45.0);
      expect(restored.customerOtpPin, '7890');
      expect(restored.currentStep, DeliveryStep.orderPickupChecklist);
      expect(restored.orderStatus, 'ready_for_pickup');
      expect(restored.items.length, 1);
      expect(restored.items.first.name, 'كسكسي بالبصلة نالوتي');
      expect(restored.items.first.isVerified, true);
    });

    test('Local persistence (save, load, clear) retains order across simulated app restarts', () async {
      final order = ActiveDeliveryOrder(
        orderId: 'ord_persist_01',
        orderNumber: '#W-777',
        storeName: 'صيدلية الهناء',
        storePhone: '091-1122334',
        storeAddress: 'نالوت - جزيرة مصرف الجمهورية',
        storeLatitude: 31.8686,
        storeLongitude: 10.9818,
        customerName: 'أحمد الباروني',
        customerPhone: '092-3344556',
        customerAddress: 'نالوت - السوق القديم',
        customerNotes: 'مستعجل جداً',
        customerLatitude: 31.8650,
        customerLongitude: 10.9800,
        paymentType: PaymentType.prepaidSadad,
        codAmountLyd: 0.0,
        customerOtpPin: '4321',
        driverPayoutLyd: 6.0,
        currentStep: DeliveryStep.navigatingToCustomer,
        orderStatus: 'out_for_delivery',
        items: [
          DeliveryItem(
            name: 'أدوية ومستلزمات طبية',
            quantity: 1,
            options: 'عاجل',
            unitPriceLyd: 30.0,
          ),
        ],
      );

      // Save order locally
      await DriverSupabaseService.saveActiveOrderLocally(order);

      // Verify loaded order
      final loaded = await DriverSupabaseService.loadActiveOrderLocally();
      expect(loaded, isNotNull);
      expect(loaded!.orderId, 'ord_persist_01');
      expect(loaded.orderNumber, '#W-777');
      expect(loaded.currentStep, DeliveryStep.navigatingToCustomer);
      expect(loaded.orderStatus, 'out_for_delivery');

      // Clear order locally
      await DriverSupabaseService.clearActiveOrderLocally();
      final afterClear = await DriverSupabaseService.loadActiveOrderLocally();
      expect(afterClear, isNull);
    });
  });
}

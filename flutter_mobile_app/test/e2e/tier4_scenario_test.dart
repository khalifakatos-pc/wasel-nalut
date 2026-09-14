import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_customer_app/services/api_service.dart';
import 'package:wasel_customer_app/cart_checkout_screen.dart';
import 'package:wasel_customer_app/order_tracking_screen.dart';
import 'test_harness.dart';

void main() {
  setUpAll(() {
    TestHarness.installMockHttpOverrides();
  });

  group('Tier 4: Authentic Nalut Scenario Suite', () {
    // ------------------------------------------------------------------------
    // T4.1: Authentic Nalut Grilled Meat Order Flow
    // ------------------------------------------------------------------------
    testWidgets('T4.1: Authentic Nalut grilled meat order flow from cart checkout to order confirmation and tracking', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Establish session with Nalut authenticated user
      await TestHarness.setupMockEnvironment(
        isGuest: false,
        phone: '0919876543',
        name: 'مفتاح النالوتي',
        loyaltyPoints: 140,
      );

      expect(ApiService.isGuest, isFalse);
      expect(ApiService.userPhone, equals('0919876543'));
      expect(ApiService.userName, equals('مفتاح النالوتي'));

      // 2. Prepare order with authentic Nalut store and signature dish
      final signatureKebabs = CartItem(
        id: 'kebab_plate_01',
        title: 'صحن مشكل كباب وشقف لحم وطني',
        storeName: 'مطعم قصر نالوت للمشويات',
        price: 34.00,
        quantity: 2, // 34.00 * 2 = 68.00 LYD
        selectedAddons: const [
          'صلصة ثومية ليبية حارة (+1.50 د.ل)',
          'خبز تنور ليبي طازج (+1.50 د.ل)',
        ],
      );

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: CartCheckoutScreen(
            storeId: 'store_nalut_01',
            storeName: 'مطعم قصر نالوت للمشويات',
            initialCartItems: [signatureKebabs],
          ),
        ),
      );
      await tester.pump();

      // Verify item title and subtotal (68.00 LYD)
      expect(find.text('صحن مشكل كباب وشقف لحم وطني'), findsOneWidget);
      expect(find.text('68.00 د.ل'), findsWidgets);

      // 3. Apply promotional discount coupon WASEL2026 (5.00 LYD off)
      final couponFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText?.contains('WASEL2026') == true,
      );
      expect(couponFieldFinder, findsOneWidget);
      await tester.enterText(couponFieldFinder, 'WASEL2026');

      final applyBtnFinder = find.text('تطبيق');
      expect(applyBtnFinder, findsOneWidget);
      await tester.tap(applyBtnFinder);
      await tester.pump();

      // Verify discount is applied: Subtotal 68.00 + Delivery 3.00 + Service 1.00 - Discount 5.00 = 67.00 LYD
      expect(find.textContaining('تم تطبيق خصم واصل بقيمة 5.00 د.ل بنجاح!'), findsOneWidget);
      expect(find.text('-5.00 د.ل'), findsWidgets);
      expect(find.text('67.00 د.ل'), findsWidgets);

      // 4. Submit order (Cash On Delivery)
      final placeOrderBtn = find.textContaining('تأكيد الطلب والدفع');
      expect(placeOrderBtn, findsOneWidget);
      await tester.tap(placeOrderBtn);
      await tester.pumpAndSettle();

      // 5. Verify order confirmation dialog appears with order number and Nalut captain dispatch note
      expect(find.text('تم تأكيد الطلب وحفظه في السحابة!'), findsOneWidget);
      expect(find.textContaining('تم حجز المشوار وإرسال الإشعار للمطعم والكابتن الأقرب في نالوت'), findsOneWidget);

      // 6. Transition to live order tracking screen
      final trackOrderBtn = find.text('تتبع الطلب مباشرة على الخريطة');
      expect(trackOrderBtn, findsOneWidget);
      await tester.tap(trackOrderBtn);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Verify live tracking screen elements
      expect(find.textContaining('WAS-'), findsWidgets);
      expect(find.textContaining('نالوت'), findsWidgets);

      // Safely unmount widget to cancel periodic polling timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T4.2: Nalut Delivery Order Real-Time Telemetry & Captain Tracking
    // ------------------------------------------------------------------------
    testWidgets('T4.2: Live tracking screen displays Nalut captain, vehicle, status, and OTP security code', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: const OrderTrackingScreen(
            orderNumber: 'WAS-9988',
          ),
        ),
      );
      await tester.pump();

      // Verify order number header
      expect(find.textContaining('WAS-9988'), findsWidgets);

      // Verify authentic Nalut store name
      expect(find.textContaining('مطعم قصر نالوت للمشويات'), findsWidgets);

      // Verify Nalut captain profile and vehicle telemetry
      expect(find.textContaining('كابتن طارق النالوتي'), findsWidgets);
      expect(find.textContaining('تويوتا يارس'), findsWidgets);

      // Verify secure delivery OTP code
      expect(find.text('رمز التسليم (OTP)'), findsOneWidget);
      expect(find.text('4821'), findsOneWidget);

      // Verify progress timeline status
      expect(find.text('تم الطلب'), findsOneWidget);
      expect(find.text('تجهيز المطبخ'), findsOneWidget);

      // Safely unmount widget to cancel polling timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

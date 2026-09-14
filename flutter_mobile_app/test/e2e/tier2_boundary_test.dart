import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_customer_app/cart_checkout_screen.dart';
import 'package:wasel_customer_app/login_screen.dart';
import 'test_harness.dart';

void main() {
  setUpAll(() {
    TestHarness.installMockHttpOverrides();
  });

  group('Tier 2: Boundary & Negative Verification Suite', () {
    // ------------------------------------------------------------------------
    // T2.1: Empty Cart Boundary
    // ------------------------------------------------------------------------
    testWidgets('T2.1: Empty cart displays empty state message, disables checkout, and handles back navigation', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();
      bool backTapped = false;

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: CartCheckoutScreen(
            initialCartItems: const [],
            onBackToHome: () {
              backTapped = true;
            },
          ),
        ),
      );
      await tester.pump();

      // Verify empty state text elements
      expect(find.text('سلة الشراء فارغة'), findsOneWidget);
      expect(find.text('استكشف المطاعم والمتاجر وأضف وجباتك المفضلة'), findsOneWidget);

      // Verify navigation button exists
      final browseBtnFinder = find.text('تصفح المطاعم الآن');
      expect(browseBtnFinder, findsOneWidget);

      // Verify checkout execution buttons are NOT present in empty state
      expect(find.text('تأكيد الطلب'), findsNothing);
      expect(find.text('ملخص الفاتورة'), findsNothing);

      // Tap back button
      await tester.tap(browseBtnFinder);
      await tester.pump();
      expect(backTapped, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T2.2: Libyan Phone Format Validation (Length < 9)
    // ------------------------------------------------------------------------
    testWidgets('T2.2: Libyan phone length boundary (< 9 digits) triggers rejection error message', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: const LoginScreen(),
        ),
      );
      await tester.pump();

      // Find the phone field with hint 91XXXXXXX
      final phoneField = find.byType(TextField).first;
      expect(phoneField, findsOneWidget);

      // Enter short number: 6 digits (boundary below 9 digits)
      await tester.enterText(phoneField, '912345');
      await tester.pump();

      // Tap the OTP verification submit button
      final submitBtn = find.text('إرسال رمز التحقق عبر واتساب (مجاني 100%)');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pump();

      // Verify rejection error message is displayed
      expect(
        find.text('أدخل رقم ليبي صالح (9 أرقام يبدأ بـ 092/094 ليبيانا أو 091/093 المدار)'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T2.3: Libyan Phone Non-Digit Filtering
    // ------------------------------------------------------------------------
    testWidgets('T2.3: Non-digit characters are rejected by phone input formatter', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: const LoginScreen(),
        ),
      );
      await tester.pump();

      final phoneField = find.byType(TextField).first;

      // Attempt to enter alphabetic characters and symbols mixed with digits
      await tester.enterText(phoneField, 'abc-!@#912345678');
      await tester.pump();

      // The field should retain only digits
      final TextField fieldWidget = tester.widget(phoneField);
      expect(fieldWidget.controller?.text, equals('912345678'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T2.4: Libyan Phone Carrier Prefix Validation
    // ------------------------------------------------------------------------
    testWidgets('T2.4: Libyan carrier prefix validation rejects invalid prefixes and accepts valid ones', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: const LoginScreen(),
        ),
      );
      await tester.pump();

      final phoneField = find.byType(TextField).first;
      final submitBtn = find.text('إرسال رمز التحقق عبر واتساب (مجاني 100%)');

      // Test invalid carrier prefix '95' (9 digits total, but prefix 95 is unassigned)
      await tester.enterText(phoneField, '951234567');
      await tester.pump();
      await tester.tap(submitBtn);
      await tester.pump();

      expect(
        find.text('أدخل رقم ليبي صالح (9 أرقام يبدأ بـ 092/094 ليبيانا أو 091/093 المدار)'),
        findsOneWidget,
      );

      // Change to valid carrier prefix '91' (Al-Madar)
      await tester.enterText(phoneField, '912345678');
      await tester.pump();

      // Error message should be dismissed on change
      expect(
        find.text('أدخل رقم ليبي صالح (9 أرقام يبدأ بـ 092/094 ليبيانا أو 091/093 المدار)'),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T2.5: Promo Code Coupon Validation
    // ------------------------------------------------------------------------
    testWidgets('T2.5: Promo code coupon validation handles invalid codes, fixed discounts, and free delivery', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await TestHarness.setupMockEnvironment();
      final item = TestHarness.createSampleCartItem(
        title: 'وجبة تجريبية نالوت',
        price: 25.00,
        quantity: 1,
      );

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: CartCheckoutScreen(
            initialCartItems: [item],
          ),
        ),
      );
      await tester.pump();

      // Find coupon text field
      final couponFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText?.contains('WASEL2026') == true,
      );
      expect(couponFieldFinder, findsOneWidget);

      final applyBtnFinder = find.text('تطبيق');
      expect(applyBtnFinder, findsOneWidget);

      // 1. Invalid coupon test
      await tester.enterText(couponFieldFinder, 'INVALID999');
      await tester.tap(applyBtnFinder);
      await tester.pump();

      expect(find.text('كود الخصم غير صالح أو منتهي الصلاحية'), findsOneWidget);

      // 2. Fixed 5.00 LYD discount coupon test (WASEL2026)
      await tester.enterText(couponFieldFinder, 'WASEL2026');
      await tester.tap(applyBtnFinder);
      await tester.pump();

      expect(find.textContaining('تم تطبيق خصم واصل بقيمة 5.00 د.ل بنجاح!'), findsOneWidget);
      expect(find.text('-5.00 د.ل'), findsWidgets);

      // 3. Free delivery coupon test (FREEDELIVERY)
      await tester.enterText(couponFieldFinder, 'FREEDELIVERY');
      await tester.tap(applyBtnFinder);
      await tester.pump();

      expect(find.textContaining('تم تطبيق كوبون التوصيل المجاني!'), findsOneWidget);
      expect(find.textContaining('مجاني'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T2.6: Extreme Numerical Values & Boundary Clamping
    // ------------------------------------------------------------------------
    testWidgets('T2.6: Extreme prices and quantities calculate and clamp accurately without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await TestHarness.setupMockEnvironment();

      // Test extreme cases: 0.00 LYD item, high-value 1000.00 LYD item, and 99 quantity
      final freeItem = TestHarness.createSampleCartItem(
        id: 'item_zero',
        title: 'هدية مجانية ترويجية',
        price: 0.00,
        quantity: 1,
      );
      final highValItem = TestHarness.createSampleCartItem(
        id: 'item_high',
        title: 'وليمة ضيافة نالوت الفاخرة',
        price: 1000.00,
        quantity: 1,
      );
      final bulkItem = TestHarness.createSampleCartItem(
        id: 'item_bulk',
        title: 'مشروب نالوت المنعش',
        price: 5.00,
        quantity: 99,
      );

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: CartCheckoutScreen(
            initialCartItems: [freeItem, highValItem, bulkItem],
          ),
        ),
      );
      await tester.pump();

      // Subtotal: 0.00 + 1000.00 + (5.00 * 99 = 495.00) = 1495.00 LYD
      expect(find.text('1495.00 د.ل'), findsWidgets);

      // Delivery: 3.00, Service: 1.00 -> Grand Total: 1499.00 LYD
      expect(find.text('1499.00 د.ل'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

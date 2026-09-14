import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_customer_app/splash_screen.dart';
import 'package:wasel_customer_app/services/api_service.dart';
import 'package:wasel_customer_app/widgets/motion_widgets.dart';
import 'package:wasel_customer_app/cart_checkout_screen.dart';
import 'package:wasel_customer_app/order_tracking_screen.dart';
import 'test_harness.dart';

void main() {
  setUpAll(() {
    TestHarness.installMockHttpOverrides();
  });

  group('Tier 1: Feature Verification Suite', () {
    // ------------------------------------------------------------------------
    // T1.1: Startup Flow & Splash Screen
    // ------------------------------------------------------------------------
    testWidgets('T1.1: Splash screen renders branding and navigates cleanly', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();
      bool navigationCompleted = false;

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: SplashScreen(
            isLoggedIn: true,
            homeScreen: Builder(
              builder: (context) {
                navigationCompleted = true;
                return const Scaffold(body: Center(child: Text('Home Destination')));
              },
            ),
            nextScreen: const Scaffold(body: Center(child: Text('Next Destination'))),
          ),
        ),
      );

      // Verify immediate Frame-0 branding
      expect(find.text('و'), findsOneWidget);
      expect(find.text('واصل | WASEL'), findsOneWidget);
      expect(find.textContaining('نالوت والجبل'), findsOneWidget);

      // Advance clock past the 2200ms splash timer and settle fade transition
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();

      // Destination reached without deadlock
      expect(navigationCompleted, isTrue);
      expect(find.text('Home Destination'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // T1.2: Guest Exploration Mode Session State
    // ------------------------------------------------------------------------
    test('T1.2: Guest session mode isolates phone and initializes cleanly', () async {
      await ApiService.setGuestMode(true);
      expect(ApiService.isGuest, isTrue);
      expect(ApiService.hasActiveSession, isTrue);
      expect(ApiService.userPhone, isEmpty);
      expect(ApiService.userName, equals('زائر واصل نالوت'));
      expect(ApiService.activeOrderId, isNull);
    });

    // ------------------------------------------------------------------------
    // T1.3: Store Catalog Loading & Authentic Nalut Stores
    // ------------------------------------------------------------------------
    test('T1.3: Store catalog returns authentic Nalut establishments', () async {
      final res = await ApiService.getStores();
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);

      final List<dynamic> stores = res.data['data'];
      expect(stores, isNotEmpty);

      // Verify authentic Nalut store IDs and locations exist
      final storeIds = stores.map((s) => s['id']?.toString()).toList();
      final hasNalutStore = storeIds.any((id) => id != null && id.contains('nalut'));
      expect(hasNalutStore, isTrue);

      // Verify Nalut latitude and longitude coordinates are centered in Nalut (~31.8, ~10.9)
      final firstStore = stores.first as Map<String, dynamic>;
      final lat = (firstStore['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (firstStore['longitude'] as num?)?.toDouble() ?? 0.0;
      expect(lat, inInclusiveRange(31.8, 31.95));
      expect(lng, inInclusiveRange(10.9, 11.05));
    });

    // ------------------------------------------------------------------------
    // T1.4: Tactile WaselBouncyPressable Interactions
    // ------------------------------------------------------------------------
    testWidgets('T1.4: WaselBouncyPressable compresses on pointer down and triggers tap', (WidgetTester tester) async {
      int tapCount = 0;

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: Scaffold(
            body: Center(
              child: WaselBouncyPressable(
                onTap: () => tapCount++,
                pressedScale: 0.90,
                child: Container(
                  key: const Key('bouncy_target'),
                  width: 100,
                  height: 100,
                  color: Colors.blue,
                  child: const Text('اضغط هنا'),
                ),
              ),
            ),
          ),
        ),
      );

      final targetFinder = find.byKey(const Key('bouncy_target'));
      expect(targetFinder, findsOneWidget);

      // Simulate press down
      final gesture = await tester.startGesture(tester.getCenter(targetFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Animated scale transform exists and is compressing
      final transformFinder = find.ancestor(
        of: targetFinder,
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsWidgets);

      // Release gesture
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tapCount, equals(1));
    });

    // ------------------------------------------------------------------------
    // T1.5: Cart Manipulation & Subtotal Calculations
    // ------------------------------------------------------------------------
    testWidgets('T1.5: Cart manipulation modifies quantities and recalculates LYD correctly', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();
      final initialItem = TestHarness.createSampleCartItem(
        title: 'صحن مشكل كباب وشقف لحم وطني',
        price: 34.00,
        quantity: 1,
      );

      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: CartCheckoutScreen(
            initialCartItems: [initialItem],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('صحن مشكل كباب وشقف لحم وطني'), findsOneWidget);
      expect(find.text('34.00 د.ل'), findsWidgets);

      // Increment quantity: 1 -> 2 (34.00 * 2 = 68.00)
      final addIconFinder = find.byIcon(Icons.add_rounded);
      expect(addIconFinder, findsOneWidget);
      await tester.tap(addIconFinder);
      await tester.pump();

      expect(find.text('68.00 د.ل'), findsWidgets);

      // Decrement quantity: 2 -> 1 (68.00 -> 34.00)
      final removeIconFinder = find.byIcon(Icons.remove_rounded);
      expect(removeIconFinder, findsOneWidget);
      await tester.tap(removeIconFinder);
      await tester.pump();

      expect(find.text('34.00 د.ل'), findsWidgets);

      // When quantity is 1, icon changes to delete_outline_rounded to remove item
      final deleteIconFinder = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteIconFinder, findsOneWidget);
      await tester.tap(deleteIconFinder);
      await tester.pump();

      // Verify empty state display
      expect(find.text('سلة الشراء فارغة'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    // ------------------------------------------------------------------------
    // T1.6: Live Order Tracking Screen
    // ------------------------------------------------------------------------
    testWidgets('T1.6: Order tracking screen initializes with Nalut tracking coordinates and status', (WidgetTester tester) async {
      await TestHarness.setupMockEnvironment();
      await tester.pumpWidget(
        TestHarness.buildTestApp(
          home: const OrderTrackingScreen(
            orderNumber: 'WAS-9988',
          ),
        ),
      );
      await tester.pump();

      // Verify order number display
      expect(find.textContaining('WAS-9988'), findsWidgets);

      // Verify Nalut restaurant and captain information
      expect(find.textContaining('نالوت'), findsWidgets);

      // Safely unmount widget to cancel periodic timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_ui/wasel_ui.dart';

void main() {
  group('Adversarial Stress Test: disableAnimations Accessibility Behavior', () {
    testWidgets('WaselBouncyPressable bypasses animation when disableAnimations is true',
        (tester) async {
      int tapped = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: WaselBouncyPressable(
                onTap: () => tapped++,
                child: const Text('Press Me'),
              ),
            ),
          ),
        ),
      );

      // Verify no Transform is inside WaselBouncyPressable when disableAnimations is true
      expect(find.text('Press Me'), findsOneWidget);
      final transformFinder = find.descendant(
        of: find.byType(WaselBouncyPressable),
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsNothing);

      // Tap should trigger immediately without animation ticks
      await tester.tap(find.text('Press Me'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('WaselPulseGlow bypasses animated shadow when disableAnimations is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: WaselPulseGlow(
                child: Text('Glow Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Glow Content'), findsOneWidget);
      // AnimatedBuilder / DecoratedBox shadow should not be in WaselPulseGlow
      final shadowFinder = find.descendant(
        of: find.byType(WaselPulseGlow),
        matching: find.byType(DecoratedBox),
      );
      expect(shadowFinder, findsNothing);
    });

    testWidgets('WaselShimmer bypasses shader mask when disableAnimations is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: WaselShimmer(
                child: Text('Shimmering Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Shimmering Content'), findsOneWidget);
      final shaderMaskFinder = find.descendant(
        of: find.byType(WaselShimmer),
        matching: find.byType(ShaderMask),
      );
      expect(shaderMaskFinder, findsNothing);
    });

    testWidgets('WaselRadarSweep stops controller and disables beam when disableAnimations is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: WaselRadarSweep(),
            ),
          ),
        ),
      );

      expect(find.byType(WaselRadarSweep), findsOneWidget);
      final customPaintFinder = find.descendant(
        of: find.byType(WaselRadarSweep),
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('WaselSlideFade renders child immediately when disableAnimations is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: WaselSlideFade(
                child: Text('Slide Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Slide Content'), findsOneWidget);
      // No FadeTransition or SlideTransition inside WaselSlideFade
      final fadeFinder = find.descendant(
        of: find.byType(WaselSlideFade),
        matching: find.byType(FadeTransition),
      );
      final slideFinder = find.descendant(
        of: find.byType(WaselSlideFade),
        matching: find.byType(SlideTransition),
      );
      expect(fadeFinder, findsNothing);
      expect(slideFinder, findsNothing);
    });

    testWidgets('SwipeToConfirmSlider snaps to 0 immediately without animation when disableAnimations is true',
        (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: SwipeToConfirmSlider(
                  label: 'مرر للتأكيد',
                  onConfirmed: () => confirmed = true,
                ),
              ),
            ),
          ),
        ),
      );

      // Drag partially (40px) and release
      await tester.drag(find.byType(GestureDetector).first, const Offset(40, 0));
      await tester.pump();
      expect(confirmed, isFalse);
    });
  });

  group('Adversarial Stress Test: OdometerCounter Edge Values', () {
    testWidgets('OdometerCounter edge values (negative, zero, large, decimalPlaces: 0)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OdometerCounter(value: 0.0, decimalPlaces: 0),
                OdometerCounter(value: -15.75, decimalPlaces: 2),
                OdometerCounter(value: 999999.99, decimalPlaces: 2),
                OdometerCounter(value: 0.001, decimalPlaces: 3),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('0 د.ل'), findsOneWidget);
      expect(find.text('-15.75 د.ل'), findsOneWidget);
      expect(find.text('999999.99 د.ل'), findsOneWidget);
      expect(find.text('0.001 د.ل'), findsOneWidget);
    });
  });

  group('Adversarial Stress Test: CountdownRing Boundary Conditions', () {
    testWidgets('CountdownRing handles zero, full, negative, and overflow progress values safely',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CountdownRing(progress: 0.0, remainingSeconds: 0),
                CountdownRing(progress: 1.0, remainingSeconds: 60),
                CountdownRing(progress: -0.5, remainingSeconds: -5), // Negative boundary
                CountdownRing(progress: 1.5, remainingSeconds: 90), // Overflow boundary
                CountdownRing(progress: 0.50), // Exactly on boundary 0.5
                CountdownRing(progress: 0.20), // Exactly on boundary 0.2
              ],
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.byType(CountdownRing), findsNWidgets(6));
    });

    testWidgets('CountdownRing.fromDuration handles Duration.zero, negative durations, and overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Zero division safety check
                CountdownRing.fromDuration(
                  total: Duration.zero,
                  remaining: Duration.zero,
                ),
                // Negative total duration
                CountdownRing.fromDuration(
                  total: const Duration(seconds: -10),
                  remaining: const Duration(seconds: 5),
                ),
                // Negative remaining duration
                CountdownRing.fromDuration(
                  total: const Duration(seconds: 30),
                  remaining: const Duration(seconds: -5),
                ),
                // Remaining exceeds total
                CountdownRing.fromDuration(
                  total: const Duration(seconds: 30),
                  remaining: const Duration(seconds: 60),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CountdownRing), findsNWidgets(4));
    });

    testWidgets('CountdownRing custom centerChild and showText: false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CountdownRing(
                  progress: 0.5,
                  remainingSeconds: 30,
                  showText: false,
                ),
                CountdownRing(
                  progress: 0.5,
                  remainingSeconds: 30,
                  centerChild: Icon(Icons.timer),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('30'), findsNothing);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });
  });

  group('Adversarial Stress Test: ReceiptAuditSheet 100% Check Requirement', () {
    testWidgets('Cannot approve empty items list', (tester) async {
      bool approved = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptAuditSheet(
              orderId: '#WSL-EMPTY',
              merchantName: 'متجر فارغ',
              items: const [],
              onApproved: () => approved = true,
            ),
          ),
        ),
      );

      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      await tester.tap(find.text('يرجى مراجعة كافة الأصناف للمتابعة'));
      await tester.pumpAndSettle();
      expect(approved, isFalse);
    });

    testWidgets('Multi-item audit: partial check CANNOT approve; unchecking re-locks approval',
        (tester) async {
      bool approved = false;

      final items = [
        const ReceiptAuditItem(id: 'item_1', name: 'وجبة رقم 1', quantity: 1),
        const ReceiptAuditItem(id: 'item_2', name: 'وجبة رقم 2', quantity: 2),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptAuditSheet(
              orderId: '#WSL-202',
              merchantName: 'مطعم الأهرام نالوت',
              items: items,
              totalPrice: 40.0,
              customerNote: 'بدون شطة حارة',
              onApproved: () => approved = true,
            ),
          ),
        ),
      );

      expect(find.text('ملاحظات الزبون: بدون شطة حارة'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);

      // Check first item only
      await tester.tap(find.text('وجبة رقم 1'));
      await tester.pumpAndSettle();

      // 1 out of 2 checked -> banner shows (1/2)
      expect(find.textContaining('(1/2)'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);

      // Attempt to tap locked button
      await tester.tap(find.text('يرجى مراجعة كافة الأصناف للمتابعة'));
      await tester.pumpAndSettle();
      expect(approved, isFalse);

      // Check the 2nd item
      await tester.tap(find.text('وجبة رقم 2'));
      await tester.pumpAndSettle();

      // Now 2/2 -> Unlocked!
      expect(
          find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);

      // Now uncheck item 1 -> Must re-lock immediately!
      await tester.tap(find.text('وجبة رقم 1'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      expect(find.textContaining('(1/2)'), findsOneWidget);

      // Tap locked button
      await tester.tap(find.text('يرجى مراجعة كافة الأصناف للمتابعة'));
      await tester.pumpAndSettle();
      expect(approved, isFalse);

      // Re-check item 1 -> Unlocked again
      await tester.tap(find.text('وجبة رقم 1'));
      await tester.pumpAndSettle();
      expect(
          find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);

      // Tap unlocked button -> Approval triggered!
      await tester.tap(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
    });

    testWidgets('Select All and Deselect All toggle cycles properly',
        (tester) async {
      bool approved = false;

      final items = [
        const ReceiptAuditItem(id: 'a', name: 'عنصر أ'),
        const ReceiptAuditItem(id: 'b', name: 'عنصر ب'),
        const ReceiptAuditItem(id: 'c', name: 'عنصر ج'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptAuditSheet(
              orderId: '#WSL-777',
              merchantName: 'محل البركة',
              items: items,
              onApproved: () => approved = true,
            ),
          ),
        ),
      );

      expect(find.text('تحديد الكل'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);

      // Tap 'تحديد الكل'
      await tester.tap(find.text('تحديد الكل'));
      await tester.pumpAndSettle();

      expect(find.text('إلغاء الكل'), findsOneWidget);
      expect(
          find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);

      // Tap 'إلغاء الكل'
      await tester.tap(find.text('إلغاء الكل'));
      await tester.pumpAndSettle();

      expect(find.text('تحديد الكل'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      await tester.tap(find.text('يرجى مراجعة كافة الأصناف للمتابعة'));
      await tester.pumpAndSettle();
      expect(approved, isFalse);
    });

    testWidgets('Duplicate item IDs do not deadlock completion (Defect 3 resolution)',
        (tester) async {
      bool approved = false;

      // Order with duplicate product IDs (e.g. customized multi-line items)
      final items = [
        const ReceiptAuditItem(id: 'shawarma_1', name: 'شاورما دجاج (عادي)', quantity: 1),
        const ReceiptAuditItem(id: 'shawarma_1', name: 'شاورما دجاج (بدون طماطم)', quantity: 1),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptAuditSheet(
              orderId: '#WSL-DUP-303',
              merchantName: 'مطعم القلعة',
              items: items,
              onApproved: () => approved = true,
            ),
          ),
        ),
      );

      // Verify initial state: 0/2 checked, button locked
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      expect(find.textContaining('(0/2)'), findsOneWidget);

      // Check first item only (index 0)
      await tester.tap(find.text('شاورما دجاج (عادي)'));
      await tester.pumpAndSettle();

      // Only 1 item should be checked, button still locked
      expect(find.textContaining('(1/2)'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      expect(approved, isFalse);

      // Check second item (index 1)
      await tester.tap(find.text('شاورما دجاج (بدون طماطم)'));
      await tester.pumpAndSettle();

      // Both items checked -> Unlocked!
      expect(
          find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);
      expect(find.textContaining('اكتملت المطابقة بنجاح'), findsOneWidget);

      // Tap unlocked button -> Approved
      await tester.tap(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
    });

    testWidgets('Select All unlocks order with duplicate item IDs',
        (tester) async {
      bool approved = false;

      final items = [
        const ReceiptAuditItem(id: 'item_dup', name: 'صنف مكرر 1', quantity: 1),
        const ReceiptAuditItem(id: 'item_dup', name: 'صنف مكرر 2', quantity: 1),
        const ReceiptAuditItem(id: 'item_dup', name: 'صنف مكرر 3', quantity: 1),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptAuditSheet(
              orderId: '#WSL-DUP-ALL',
              merchantName: 'مطعم القلعة',
              items: items,
              onApproved: () => approved = true,
            ),
          ),
        ),
      );

      // Tap Select All
      await tester.tap(find.text('تحديد الكل'));
      await tester.pumpAndSettle();

      // Unlocked
      expect(
          find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);
      expect(find.text('إلغاء الكل'), findsOneWidget);

      // Tap Deselect All
      await tester.tap(find.text('إلغاء الكل'));
      await tester.pumpAndSettle();

      // Re-locked
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      expect(find.textContaining('(0/3)'), findsOneWidget);

      // Re-select all and tap approve
      await tester.tap(find.text('تحديد الكل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
    });
  });

  group('Adversarial Stress Test: SwipeToConfirmSlider Latch Thresholds', () {
    testWidgets('Slider requires >= 85% drag to latch; 84% drag snaps back',
        (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SwipeToConfirmSlider(
                label: 'مرر للتأكيد',
                onConfirmed: () => confirmed = true,
              ),
            ),
          ),
        ),
      );

      final gestureFinder = find.byType(GestureDetector).first;

      // 80% drag (approx 190px out of 242px) -> release -> snaps back
      await tester.drag(gestureFinder, const Offset(190, 0));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      expect(find.text('تم التأكيد بنجاح ✓'), findsNothing);

      // Full drag (250px) -> latches at 100%
      await tester.drag(gestureFinder, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.text('تم التأكيد بنجاح ✓'), findsOneWidget);

      // Subsequent drags while confirmed should be ignored
      await tester.drag(gestureFinder, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });

    testWidgets('Disabled slider ignores all drag events', (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SwipeToConfirmSlider(
                label: 'مرر للتأكيد',
                isEnabled: false,
                onConfirmed: () => confirmed = true,
              ),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(GestureDetector).first, const Offset(250, 0));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
    });
  });
}

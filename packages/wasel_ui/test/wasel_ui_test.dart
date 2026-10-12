import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_ui/wasel_ui.dart';

void main() {
  group('WaselMotion Physics & A11y Engine', () {
    test('Durations match specification R1', () {
      expect(WaselMotion.quick, const Duration(milliseconds: 150));
      expect(WaselMotion.standard, const Duration(milliseconds: 280));
      expect(WaselMotion.slow, const Duration(milliseconds: 450));
      expect(WaselMotion.relaxed, const Duration(milliseconds: 800));
      expect(WaselMotion.extended, const Duration(milliseconds: 1200));
      expect(WaselMotion.shimmerCycle, const Duration(milliseconds: 1500));

      // Aliases
      expect(WaselMotion.fast, WaselMotion.quick);
      expect(WaselMotion.normal, WaselMotion.standard);
    });

    test('Curves match signature and joy specifications', () {
      expect(WaselMotion.signature, const Cubic(0.05, 0.7, 0.1, 1.0));
      expect(WaselMotion.joy, const Cubic(0.175, 0.885, 0.32, 1.275));
      expect(WaselMotion.springSnappy, WaselMotion.joy);
    });

    testWidgets('isAnimationDisabled and durationOf respect MediaQuery',
        (tester) async {
      late bool disabledNormal;
      late Duration durationNormal;
      late bool disabledA11y;
      late Duration durationA11y;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              disabledNormal = WaselMotion.isAnimationDisabled(context);
              durationNormal =
                  WaselMotion.durationOf(context, WaselMotion.standard);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(disabledNormal, isFalse);
      expect(durationNormal, WaselMotion.standard);

      // Wrap with MediaQuery disableAnimations: true
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                disabledA11y = WaselMotion.isAnimationDisabled(context);
                durationA11y =
                    WaselMotion.durationOf(context, WaselMotion.standard);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(disabledA11y, isTrue);
      expect(durationA11y, Duration.zero);
    });
  });

  group('WaselTheme & Design Tokens', () {
    test('Light theme tokens match semantic specification', () {
      final theme = WaselTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, WaselColors.primary);
      expect(theme.colorScheme.secondary, WaselColors.secondary);
      expect(theme.colorScheme.surface, WaselColors.surfaceLight);
      expect(theme.scaffoldBackgroundColor, WaselColors.backgroundLight);
    });

    test('Dark theme tokens match slate charcoal specification', () {
      final theme = WaselTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, WaselColors.primary);
      expect(theme.colorScheme.secondary, WaselColors.secondary);
      expect(theme.colorScheme.surface, WaselColors.surfaceDark);
      expect(theme.scaffoldBackgroundColor, WaselColors.backgroundDark);
    });

    test('Typography uses Cairo and Outfit bound to wasel_ui package', () {
      final cairoStyle = WaselTypography.cairo(fontSize: 16);
      expect(cairoStyle.fontFamily, 'packages/wasel_ui/Cairo');

      final outfitStyle = WaselTypography.outfit(fontSize: 18);
      expect(outfitStyle.fontFamily, 'packages/wasel_ui/Outfit');

      final themeText = WaselTypography.textTheme(Brightness.light);
      expect(themeText.titleLarge?.fontFamily, 'packages/wasel_ui/Cairo');
    });
  });

  group('Core Reusable Components', () {
    testWidgets('WaselCard renders and handles tap interaction',
        (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaselCard(
              onTap: () => tapped = true,
              child: const Text('بطاقة اختبار'),
            ),
          ),
        ),
      );

      expect(find.text('بطاقة اختبار'), findsOneWidget);
      await tester.tap(find.text('بطاقة اختبار'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('WaselButton primary and secondary behave correctly',
        (tester) async {
      int count = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WaselButton.primary(
                  text: 'تأكيد',
                  onPressed: () => count++,
                ),
                WaselButton.secondary(
                  text: 'موافق',
                  onPressed: () => count += 10,
                ),
                WaselButton(
                  text: 'معطل',
                  enabled: false,
                  onPressed: () => count += 100,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(count, 1);

      await tester.tap(find.text('موافق'));
      await tester.pumpAndSettle();
      expect(count, 11);

      await tester.tap(find.text('معطل'));
      await tester.pumpAndSettle();
      expect(count, 11); // Did not increase
    });

    testWidgets('StatusPill renders status types correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusPill(
                  label: 'قيد التوصيل',
                  type: StatusPillType.warning,
                  showDot: true,
                ),
                StatusPill(
                  label: 'مكتمل',
                  type: StatusPillType.success,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('قيد التوصيل'), findsOneWidget);
      expect(find.text('مكتمل'), findsOneWidget);
    });

    testWidgets('CountdownRing color shifts dynamically based on urgency',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CountdownRing(
                  progress: 0.8,
                  remainingSeconds: 40,
                  totalSeconds: 50,
                ),
                CountdownRing(
                  progress: 0.35,
                  remainingSeconds: 15,
                  totalSeconds: 50,
                ),
                CountdownRing(
                  progress: 0.1,
                  remainingSeconds: 5,
                  totalSeconds: 50,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('40'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('OdometerCounter formats numbers with suffix',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OdometerCounter(
              value: 24.50,
              prefix: '',
              suffix: ' د.ل',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('24.50 د.ل'), findsOneWidget);
    });

    testWidgets('ReceiptAuditSheet enforces 100% item checking before approval',
        (tester) async {
      bool approved = false;

      final items = [
        const ReceiptAuditItem(id: '1', name: 'شاورما دجاج', quantity: 2),
        const ReceiptAuditItem(id: '2', name: 'عصير برتقال', quantity: 1),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptAuditSheet(
              orderId: '#WSL-101',
              merchantName: 'مطعم القلعة نالوت',
              items: items,
              totalPrice: 35.0,
              onApproved: () => approved = true,
            ),
          ),
        ),
      );

      // Verify initial state: items rendered, approval button locked
      expect(find.text('شاورما دجاج'), findsOneWidget);
      expect(find.text('عصير برتقال'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);

      // Tap approval button while incomplete -> should not approve
      await tester.tap(find.text('يرجى مراجعة كافة الأصناف للمتابعة'));
      await tester.pumpAndSettle();
      expect(approved, isFalse);

      // Check item 1
      await tester.tap(find.text('شاورما دجاج'));
      await tester.pumpAndSettle();
      expect(approved, isFalse);

      // Check item 2
      await tester.tap(find.text('عصير برتقال'));
      await tester.pumpAndSettle();

      // Now approval button should be unlocked
      expect(
          find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);

      await tester.tap(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
    });

    testWidgets('SwipeToConfirmSlider confirms on full drag',
        (tester) async {
      bool confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: SwipeToConfirmSlider(
                label: 'مرر للتأكيد',
                completedLabel: 'تم التأكيد ✓',
                onConfirmed: () => confirmed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('مرر للتأكيد'), findsOneWidget);
      expect(confirmed, isFalse);

      // Drag partially (50px) and release -> should not confirm
      await tester.drag(find.byType(GestureDetector).first, const Offset(50, 0));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);

      // Drag completely (250px) -> should confirm
      await tester.drag(find.byType(GestureDetector).first, const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.text('تم التأكيد ✓'), findsOneWidget);
    });

    testWidgets(
        'OdometerCounter smoothly interpolates between old and new values',
        (tester) async {
      double value = 10.0;
      late StateSetter setState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setS) {
                setState = setS;
                return OdometerCounter(
                  value: value,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.linear,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('10.00 د.ل'), findsOneWidget);

      setState(() {
        value = 100.0;
      });
      await tester.pump(); // Start animation

      // Pump halfway (250ms of 500ms linear tween)
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('55.00 د.ل'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('100.00 د.ل'), findsOneWidget);
    });

    testWidgets(
        'OdometerCounter renders target value immediately under disableAnimations',
        (tester) async {
      double value = 10.0;
      late StateSetter setState;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setS) {
                  setState = setS;
                  return OdometerCounter(
                    value: value,
                    duration: const Duration(milliseconds: 500),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('10.00 د.ل'), findsOneWidget);

      setState(() {
        value = 100.0;
      });
      await tester.pump();

      // Completes on first frame under disableAnimations
      expect(find.text('100.00 د.ل'), findsOneWidget);
    });

    testWidgets(
        'OdometerCounter preserves Outfit typography when custom style is supplied',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OdometerCounter(
              value: 42.0,
              style: TextStyle(
                color: Colors.red,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final textWidget = tester.widget<Text>(find.text('42.00 د.ل'));
      expect(textWidget.style?.fontFamily, 'packages/wasel_ui/Outfit');
      expect(textWidget.style?.color, Colors.red);
      expect(textWidget.style?.fontSize, 22);
    });

    testWidgets(
        'WaselPulseGlow stops ticker when disableAnimations is true and settles immediately',
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

      // Must settle immediately without timing out
      await tester.pumpAndSettle();
      expect(find.text('Glow Content'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WaselPulseGlow),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'WaselPulseGlow resumes ticker when disableAnimations is toggled back to false',
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
      await tester.pumpAndSettle();
      expect(find.byType(DecoratedBox), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: const Scaffold(
              body: WaselPulseGlow(
                child: Text('Glow Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(WaselPulseGlow),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'WaselShimmer stops ticker when disableAnimations is true and settles immediately',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: WaselShimmer(
                child: Text('Shimmer Content'),
              ),
            ),
          ),
        ),
      );

      // Must settle immediately without timing out
      await tester.pumpAndSettle();
      expect(find.text('Shimmer Content'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WaselShimmer),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'WaselShimmer resumes ticker when disableAnimations is toggled back to false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: WaselShimmer(
                child: Text('Shimmer Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShaderMask), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: const Scaffold(
              body: WaselShimmer(
                child: Text('Shimmer Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(WaselShimmer),
          matching: find.byType(ShaderMask),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'ReceiptAuditSheet handles duplicate item IDs without deadlock',
        (tester) async {
      bool approved = false;

      final items = [
        const ReceiptAuditItem(
            id: 'shawarma_1', name: 'شاورما دجاج (عادي)', quantity: 1),
        const ReceiptAuditItem(
            id: 'shawarma_1', name: 'شاورما دجاج (بدون طماطم)', quantity: 1),
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

      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      expect(find.textContaining('(0/2)'), findsOneWidget);

      // Check first item only (index 0)
      await tester.tap(find.text('شاورما دجاج (عادي)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('(1/2)'), findsOneWidget);
      expect(find.text('يرجى مراجعة كافة الأصناف للمتابعة'), findsOneWidget);
      expect(approved, isFalse);

      // Check second item (index 1)
      await tester.tap(find.text('شاورما دجاج (بدون طماطم)'));
      await tester.pumpAndSettle();

      // Both checked -> Unlocked!
      expect(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);
      expect(find.textContaining('اكتملت المطابقة بنجاح'), findsOneWidget);

      await tester.tap(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
    });

    testWidgets(
        'ReceiptAuditSheet Select All unlocks order with duplicate item IDs',
        (tester) async {
      bool approved = false;

      final items = [
        const ReceiptAuditItem(
            id: 'item_dup', name: 'صنف مكرر 1', quantity: 1),
        const ReceiptAuditItem(
            id: 'item_dup', name: 'صنف مكرر 2', quantity: 1),
        const ReceiptAuditItem(
            id: 'item_dup', name: 'صنف مكرر 3', quantity: 1),
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

      await tester.tap(find.text('تحديد الكل'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد ومطابقة الفاتورة واستلام الطلب ✓'), findsOneWidget);
      expect(find.text('إلغاء الكل'), findsOneWidget);

      await tester.tap(find.text('إلغاء الكل'));
      await tester.pumpAndSettle();

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
}

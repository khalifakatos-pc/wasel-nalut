import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: unnecessary_import
import 'package:wasel_customer_app/widgets/motion_widgets.dart';
import 'package:wasel_customer_app/design_system.dart';

void main() {
  group('Empirical Stress: Mobile motion_widgets.dart Backward Compatibility', () {
    testWidgets('Exports all 8 legacy motion classes and renders without conflicts with design_system.dart', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.waselPrimary,
            body: Column(
              children: [
                WaselBouncyPressable(
                  onTap: () => tapped = true,
                  pressDuration: AppMotion.fast,
                  child: const Text('BouncyPressable'),
                ),
                WaselBouncyButton(
                  onPressed: () {},
                  child: const Text('BouncyButton'),
                ),
                const WaselPulseGlow(
                  child: SizedBox(width: 40, height: 40),
                ),
                const WaselShimmer(
                  child: SizedBox(width: 100, height: 20),
                ),
                const WaselShimmerBox(
                  width: 80,
                  height: 16,
                ),
                const WaselNumberOdometer(
                  value: 45.5,
                  prefix: 'Total: ',
                  suffix: ' د.ل',
                ),
                const WaselRadarSweep(
                  size: 100,
                ),
                const WaselSlideFade(
                  child: Text('SlideFade'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BouncyPressable'), findsOneWidget);
      expect(find.text('BouncyButton'), findsOneWidget);
      expect(find.text('SlideFade'), findsOneWidget);
      expect(find.byType(WaselShimmerBox), findsOneWidget);
      expect(find.byType(WaselNumberOdometer), findsOneWidget);
      expect(find.byType(WaselRadarSweep), findsOneWidget);

      await tester.tap(find.text('BouncyPressable'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tapped, isTrue);
    });

    testWidgets('Renders all legacy motion widgets under disableAnimations a11y mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Column(
                children: [
                  WaselBouncyPressable(
                    child: Text('A11yPressable'),
                  ),
                  WaselPulseGlow(
                    child: SizedBox(width: 30, height: 30),
                  ),
                  WaselShimmer(
                    child: SizedBox(width: 50, height: 20),
                  ),
                  WaselNumberOdometer(
                    value: 99.9,
                    suffix: ' د.ل',
                  ),
                  WaselRadarSweep(
                    size: 80,
                  ),
                  WaselSlideFade(
                    child: Text('A11ySlide'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('A11yPressable'), findsOneWidget);
      expect(find.text('A11ySlide'), findsOneWidget);
      expect(find.text('99.90 د.ل'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_captain_app/driver_theme.dart';
import 'package:wasel_captain_app/widgets/driver_motion_widgets.dart';
// ignore: unnecessary_import
import 'package:wasel_captain_app/widgets/swipe_to_confirm_slider.dart';

void main() {
  group('Empirical Stress: Driver driver_motion_widgets.dart Backward Compatibility', () {
    testWidgets('Exports legacy driver motion symbols without colliding with local SwipeToConfirmSlider or AppMotion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DriverTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                WaselBouncyPressable(
                  child: const Text('DriverPressable'),
                ),
                const WaselPulseGlow(
                  child: SizedBox(width: 30, height: 30),
                ),
                const WaselNumberOdometer(
                  value: 120.0,
                  suffix: ' د.ل',
                ),
                const WaselRadarSweep(
                  size: 60,
                ),
                SwipeToConfirmSlider(
                  label: 'تأكيد الاستلام',
                  onConfirmed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('DriverPressable'), findsOneWidget);
      expect(find.byType(WaselNumberOdometer), findsOneWidget);
      expect(find.byType(WaselRadarSweep), findsOneWidget);
      expect(find.text('تأكيد الاستلام'), findsOneWidget);
    });
  });
}

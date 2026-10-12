import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_merchant_app/merchant_theme.dart';
import 'package:wasel_merchant_app/widgets/merchant_motion_widgets.dart';

void main() {
  group('Empirical Stress: Merchant merchant_motion_widgets.dart Backward Compatibility', () {
    testWidgets('Exports legacy merchant motion symbols without colliding with merchant_theme.dart', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: MerchantTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                WaselBouncyPressable(
                  child: Text('MerchantPressable'),
                ),
                WaselPulseGlow(
                  child: SizedBox(width: 30, height: 30),
                ),
                WaselNumberOdometer(
                  value: 85.0,
                  suffix: ' د.ل',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('MerchantPressable'), findsOneWidget);
      expect(find.byType(WaselPulseGlow), findsOneWidget);
      expect(find.byType(WaselNumberOdometer), findsOneWidget);
    });
  });
}

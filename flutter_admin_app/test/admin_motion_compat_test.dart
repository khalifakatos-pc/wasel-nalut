import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_admin_app/theme/admin_theme.dart';
import 'package:wasel_admin_app/widgets/admin_motion_widgets.dart';

void main() {
  group('Empirical Stress: Admin admin_motion_widgets.dart Backward Compatibility', () {
    testWidgets('Exports legacy admin motion symbols without colliding with admin_theme.dart', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              children: [
                WaselBouncyPressable(
                  child: Text('AdminPressable'),
                ),
                WaselPulseGlow(
                  child: SizedBox(width: 30, height: 30),
                ),
                WaselNumberOdometer(
                  value: 5400.0,
                  suffix: ' د.ل',
                ),
                WaselRadarSweep(
                  size: 70,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('AdminPressable'), findsOneWidget);
      expect(find.byType(WaselPulseGlow), findsOneWidget);
      expect(find.byType(WaselNumberOdometer), findsOneWidget);
      expect(find.byType(WaselRadarSweep), findsOneWidget);
    });
  });
}

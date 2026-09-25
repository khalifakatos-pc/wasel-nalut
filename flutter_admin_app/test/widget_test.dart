import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_admin_app/main.dart';
import 'package:wasel_admin_app/screens/pin_lock_screen.dart';

void main() {
  testWidgets('Wasel Admin App smoke test & PinLockScreen render', (WidgetTester tester) async {
    await tester.pumpWidget(const WaselAdminApp());

    // Verify that the PinLockScreen is mounted
    expect(find.byType(PinLockScreen), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_merchant_app/main.dart';

void main() {
  testWidgets('Wasel Merchant App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WaselMerchantApp());
    expect(find.byType(WaselMerchantApp), findsOneWidget);
  });
}

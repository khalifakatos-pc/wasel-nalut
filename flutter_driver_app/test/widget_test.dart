import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_captain_app/main.dart';

void main() {
  testWidgets('Wasel Captain smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WaselCaptainApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

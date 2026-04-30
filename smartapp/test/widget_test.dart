import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Smoke test renders a widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('smoke-test'),
        ),
      ),
    );

    expect(find.text('smoke-test'), findsOneWidget);
  });
}

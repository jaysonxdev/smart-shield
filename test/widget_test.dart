// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';

// make sure this matches the name in pubspec.yaml
import 'package:smartshield/main.dart';

void main() {
  testWidgets('app boots and shows SmartShield title', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmartShieldApp());

    // Let animations settle
    await tester.pumpAndSettle();

    // Verify that the app contains the title text we expect.
    expect(find.text('SmartShield'), findsOneWidget);
  });
}

// SafeArms Frontend - Widget Test

import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/main.dart';

void main() {
  testWidgets('SafeArmsApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeArmsApp());
    // Verify the app builds without errors
    expect(find.byType(SafeArmsApp), findsOneWidget);
  });
}

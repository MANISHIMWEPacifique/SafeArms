import 'package:flutter_test/flutter_test.dart';

import 'package:officer_verification_mobile/main.dart';

void main() {
  testWidgets('renders UI kit title', (WidgetTester tester) async {
    await tester.pumpWidget(const OfficerVerificationApp());

    expect(find.text('SafeArms Officer Verification UI Kit'), findsOneWidget);
  });
}

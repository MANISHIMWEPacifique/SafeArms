import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/screens/workflows/hq_reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHqReportsAtSize(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF1A1F2E),
          body: HqReportsScreen(autoLoadUnits: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in <Size>[
    const Size(390, 844),
    const Size(360, 640),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'HQ reports form does not overflow at ${size.width}x${size.height}',
      (tester) async {
        await pumpHqReportsAtSize(tester, size);

        expect(find.text('Report Parameters'), findsOneWidget);
        expect(find.text('Generate Report'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

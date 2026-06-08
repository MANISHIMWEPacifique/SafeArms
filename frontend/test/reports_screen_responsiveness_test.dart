import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/screens/workflows/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHqApprovalsAtSize(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(
          roleType: 'hq',
          autoLoad: false,
          initialLossReports: [],
          initialDestructionRequests: [],
          initialProcurementRequests: [],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpStationReportsAtSize(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(
          roleType: 'station',
          autoLoad: false,
          initialLossReports: [],
          initialDestructionRequests: [],
          initialProcurementRequests: [],
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
      'HQ approvals empty state does not overflow at ${size.width}x${size.height}',
      (tester) async {
        await pumpHqApprovalsAtSize(tester, size);

        expect(find.text('No loss reports found'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in <Size>[
    const Size(390, 844),
    const Size(360, 640),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'Station reports actions do not overflow at ${size.width}x${size.height}',
      (tester) async {
        await pumpStationReportsAtSize(tester, size);

        expect(find.text('Unit Reports'), findsOneWidget);
        expect(find.text('Report Loss'), findsOneWidget);
        expect(find.text('Request Destruction'), findsOneWidget);
        expect(find.text('Request Firearms'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('HQ pending approvals do not expose delete actions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(
          roleType: 'hq',
          autoLoad: false,
          initialLossReports: [
            {
              'loss_id': 10,
              'status': 'pending',
              'serial_number': 'SN-001',
              'loss_type': 'lost',
              'circumstances': 'Missing from unit armoury',
              'created_at': '2026-06-08T10:00:00Z',
            },
          ],
          initialDestructionRequests: [],
          initialProcurementRequests: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Station pending reports do not expose delete actions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(
          roleType: 'station',
          autoLoad: false,
          initialLossReports: [
            {
              'loss_id': 11,
              'status': 'pending',
              'serial_number': 'SN-002',
              'loss_type': 'stolen',
              'circumstances': 'Reported by assigned officer',
              'created_at': '2026-06-08T10:00:00Z',
            },
          ],
          initialDestructionRequests: [],
          initialProcurementRequests: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HQ reviewed approvals can still expose delete actions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(
          roleType: 'hq',
          autoLoad: false,
          initialLossReports: [
            {
              'loss_id': 12,
              'status': 'approved',
              'serial_number': 'SN-003',
              'loss_type': 'lost',
              'circumstances': 'Reviewed record',
              'created_at': '2026-06-08T10:00:00Z',
            },
          ],
          initialDestructionRequests: [],
          initialProcurementRequests: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

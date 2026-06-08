import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safearms_frontend/providers/anomaly_provider.dart';
import 'package:safearms_frontend/providers/dashboard_provider.dart';
import 'package:safearms_frontend/screens/dashboards/station_commander_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpStationDashboardAtSize(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => AnomalyProvider()),
        ],
        child: const MaterialApp(
          home: StationCommanderDashboard(autoLoad: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in <Size>[
    const Size(390, 844),
    const Size(360, 640),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'Station dashboard does not overflow at ${size.width}x${size.height}',
      (tester) async {
        await pumpStationDashboardAtSize(tester, size);

        expect(find.text('Dashboard'), findsAtLeastNWidgets(1));
        expect(find.text('Total Firearms'), findsOneWidget);
        expect(find.text('Unit Firearm Status'), findsOneWidget);
        expect(find.text('Recent Station Activity'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

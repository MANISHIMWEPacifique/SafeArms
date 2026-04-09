import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:officer_verification_mobile/config/api_config.dart';
import 'package:officer_verification_mobile/main.dart';
import 'package:officer_verification_mobile/screens/connection_setup_screen.dart';

void main() {
  testWidgets('renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OfficerVerificationApp());

    expect(find.text('SafeArms'), findsOneWidget);
  });

  testWidgets('edit api url keeps existing enrollment credentials', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'safearms_manual_api_base_url': 'http://10.0.2.2:5000/api',
      'safearms_manual_api_base_url_updated_at': '2026-04-09T00:00:00.000Z',
      'safearms_officer_id': 'OFF-001',
      'safearms_device_key': 'DVK-001',
      'safearms_device_token': 'TOKEN-001',
    });
    await ApiConfig.initialize();

    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ConnectionSetupScreen(),
                      ),
                    );
                  },
                  child: const Text('Open Setup'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open Setup'));
    await tester.pumpAndSettle();

    final editApiUrlButton = find.widgetWithText(
      ElevatedButton,
      'EDIT API URL',
    );
    expect(editApiUrlButton, findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'http://192.168.0.45:5000',
    );

    final editButtonWidget = tester.widget<ElevatedButton>(editApiUrlButton);
    expect(editButtonWidget.onPressed, isNotNull);
    editButtonWidget.onPressed!.call();
    await tester.pumpAndSettle();

    expect(ApiConfig.effectiveBaseUrl, 'http://192.168.0.45:5000/api');
    expect(ApiConfig.effectiveOfficerId, 'OFF-001');
    expect(ApiConfig.effectiveDeviceKey, 'DVK-001');
    expect(ApiConfig.effectiveDeviceToken, 'TOKEN-001');
    expect(observer.popCount, greaterThan(0));
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}

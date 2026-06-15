import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/models/firearm_model.dart';
import 'package:safearms_frontend/widgets/firearm_detail_modal.dart';

void main() {
  testWidgets('admin sees send to maintenance for available firearm',
      (tester) async {
    await _pumpModal(
      tester,
      firearm: _buildFirearm(status: 'available'),
      userRole: 'admin',
    );

    expect(find.text('Send to Maintenance'), findsOneWidget);
    expect(find.text('Return to Available'), findsNothing);
  });

  testWidgets('admin sees return to available for maintenance firearm',
      (tester) async {
    await _pumpModal(
      tester,
      firearm: _buildFirearm(status: 'maintenance'),
      userRole: 'admin',
    );

    expect(find.text('Return to Available'), findsOneWidget);
    expect(find.text('Send to Maintenance'), findsNothing);
  });

  testWidgets('non-admin does not see maintenance actions', (tester) async {
    await _pumpModal(
      tester,
      firearm: _buildFirearm(status: 'available'),
      userRole: 'hq_firearm_commander',
    );

    expect(find.text('Send to Maintenance'), findsNothing);
    expect(find.text('Return to Available'), findsNothing);
  });

  testWidgets('send to maintenance calls start without reason dialog',
      (tester) async {
    String? capturedAction;

    await _pumpModal(
      tester,
      firearm: _buildFirearm(status: 'available'),
      userRole: 'admin',
      onMaintenanceAction: (action) async {
        capturedAction = action;
        return null;
      },
    );

    await tester.ensureVisible(find.text('Send to Maintenance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to Maintenance'));
    await tester.pumpAndSettle();

    expect(capturedAction, 'start');
    expect(find.text('Reason'), findsNothing);
  });

  testWidgets('return to available calls complete without reason dialog',
      (tester) async {
    String? capturedAction;

    await _pumpModal(
      tester,
      firearm: _buildFirearm(status: 'maintenance'),
      userRole: 'admin',
      onMaintenanceAction: (action) async {
        capturedAction = action;
        return null;
      },
    );

    await tester.ensureVisible(find.text('Return to Available'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return to Available'));
    await tester.pumpAndSettle();

    expect(capturedAction, 'complete');
    expect(find.text('Reason'), findsNothing);
  });
}

Future<void> _pumpModal(
  WidgetTester tester, {
  required FirearmModel firearm,
  required String userRole,
  Future<String?> Function(String action)? onMaintenanceAction,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FirearmDetailModal(
          firearm: firearm,
          userRole: userRole,
          onClose: () {},
          onMaintenanceAction: userRole == 'admin'
              ? onMaintenanceAction ?? ((_) async => null)
              : null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FirearmModel _buildFirearm({required String status}) {
  return FirearmModel(
    firearmId: 'FA-001',
    serialNumber: 'SA-TEST-001',
    manufacturer: 'Glock',
    model: '17',
    firearmType: 'pistol',
    caliber: '9mm',
    acquisitionDate: DateTime(2024, 1, 1),
    registrationLevel: 'hq',
    registeredBy: 'USR-001',
    assignedUnitId: 'UNIT-HQ',
    assignedUnitName: 'Headquarters',
    currentStatus: status,
    isActive: true,
  );
}

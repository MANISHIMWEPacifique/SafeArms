import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/screens/workflows/hq_reports_screen.dart';
import 'package:safearms_frontend/services/report_service.dart';

class _FakeReportService extends ReportService {
  _FakeReportService(this.responses);

  final Map<String, Map<String, dynamic>> responses;

  @override
  Future<Map<String, dynamic>> generateAnalyticalReport({
    required String type,
    DateTime? startDate,
    DateTime? endDate,
    String? unitId,
    String? serialNumber,
    String? userId,
    String? username,
    String? role,
    int page = 1,
    int limit = 100,
  }) async {
    return responses[type] ?? {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHqReports(
    WidgetTester tester,
    _FakeReportService reportService,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1F2E),
          body: HqReportsScreen(
            autoLoadUnits: false,
            reportService: reportService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final fakeService = _FakeReportService({
    'firearm_history': {
      'firearms': [
        {
          'serial_number': 'SA-001',
          'firearm_type': 'pistol',
          'caliber': '9mm',
          'acquisition_date': '2026-01-02',
          'unit_name': 'HQ Armoury',
        }
      ],
      'unit_history': [
        {
          'unit_name': 'HQ Armoury',
          'assigned_date': '2026-01-02',
        }
      ],
      'custody_records': [
        {
          'officer_name': 'Officer Maseko',
          'issued_at': '2026-01-03',
          'duration': 'Active',
          'unit_name': 'HQ Armoury',
        }
      ],
      'anomalies': [
        {
          'anomaly_id': 'AN-001',
          'severity': 'high',
          'status': 'open',
        }
      ],
    },
    'ballistic_summary': {
      'profiles': [
        {
          'serial_number': 'SA-001',
          'ballistic_id': 'BP-001',
          'caliber': '9mm',
          'rifling_characteristics': '6 grooves',
          'firing_pin_impression': 'round',
          'ejector_marks': 'right',
          'extractor_marks': 'left',
          'chamber_marks': 'fine',
        }
      ],
      'recent_custody_logs': [
        {
          'custody_id': 'CUS-001',
          'custody_type': 'temporary',
          'officer_name': 'Officer Maseko',
          'unit_name': 'HQ Armoury',
          'issued_at': '2026-01-03',
        }
      ],
      'investigator_activities': [
        {
          'activity_date': '2026-01-04',
          'serial_number': 'SA-001',
          'investigator_name': 'Investigator Dlamini',
          'activity_type': 'Access Log',
          'action': 'traceability_report',
          'notes': 'Case review',
        }
      ],
    },
    'anomaly_summary': {
      'summary': {
        'total': 1,
        'high': 1,
        'medium': 0,
        'low': 0,
      },
      'anomalies': [
        {
          'anomaly_id': 'AN-001',
          'serial_number': 'SA-001',
          'unit_name': 'HQ Armoury',
          'severity': 'high',
          'status': 'open',
          'detected_at': '2026-01-05',
        }
      ],
    },
  });

  testWidgets('renders HQ firearm history generated data', (tester) async {
    await pumpHqReports(tester, fakeService);

    await tester.tap(find.text('Generate Report'));
    await tester.pumpAndSettle();

    expect(find.text('Firearm Details'), findsOneWidget);
    expect(find.text('Unit Assignment History'), findsOneWidget);
    expect(find.text('Custody Timeline'), findsOneWidget);
    expect(find.text('Related Anomalies'), findsOneWidget);
  });

  testWidgets('renders HQ ballistic traceability generated data',
      (tester) async {
    await pumpHqReports(tester, fakeService);

    await tester.tap(find.text('Ballistic Traceability Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Report'));
    await tester.pumpAndSettle();

    expect(find.text('Ballistic Profiles'), findsOneWidget);
    expect(find.text('Recent Custody Logs'), findsOneWidget);
    expect(find.text('Investigator Activities & Traceability Logs'),
        findsOneWidget);
  });

  testWidgets('renders HQ anomaly oversight generated data', (tester) async {
    await pumpHqReports(tester, fakeService);

    await tester.tap(find.text('Anomaly Oversight Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate Report'));
    await tester.pumpAndSettle();

    expect(find.text('Total Anomalies'), findsOneWidget);
    expect(find.text('Anomaly Details'), findsOneWidget);
  });
}

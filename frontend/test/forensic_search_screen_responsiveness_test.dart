import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/screens/forensic/forensic_search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const List<Map<String, dynamic>> sampleResults = [
    {
      'firearm_id': 'FA-001',
      'manufacturer': 'Beretta',
      'model': 'PX4 Storm',
      'serial_number': 'SAFE-9MM-001',
      'caliber': '9x19mm Parabellum',
      'evidence_strength': 'Strong candidate',
      'match_score': 85,
      'matched_fields': ['Firing pin', 'Rifling', 'Chamber/feed'],
      'incident_custody': {
        'held_at_incident': true,
        'officer_name': 'Capt. Ndlovu',
        'unit_name': 'Forensics Unit',
      },
      'firing_pin_impression': 'Circular striker mark with light drag',
      'rifling_characteristics': '6 grooves, right-hand twist',
      'chamber_marks': 'Parallel feed ramp marks',
      'ejector_marks': 'Square ejector mark',
      'extractor_marks': 'Fine extractor scrape',
      'is_locked': true,
      'registration_hash': 'abcdef1234567890',
    },
  ];

  Future<void> pumpScreenAtSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF1A1F2E),
          body: ForensicSearchScreen(
            initialSearchResults: sampleResults,
            initialIncidentDate: '2026-06-08',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in <Size>[
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1366, 768),
  ]) {
    testWidgets(
      'investigation search results fit at ${size.width}x${size.height}',
      (tester) async {
        await pumpScreenAtSize(tester, size);

        expect(find.text('SAFE-9MM-001'), findsOneWidget);
        expect(find.text('KEY BALLISTICS'), findsWidgets);
        expect(
          find.textContaining('Pin: Circular striker mark with light drag'),
          findsOneWidget,
        );
        expect(find.textContaining('+4 more'), findsOneWidget);
        expect(find.textContaining('Rifling:'), findsNothing);
        expect(find.byType(DataTable), findsNothing);
        expect(
          tester
              .widgetList<SingleChildScrollView>(
                find.byType(SingleChildScrollView),
              )
              .where((widget) => widget.scrollDirection == Axis.horizontal),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safearms_frontend/providers/ballistic_profile_provider.dart';
import 'package:safearms_frontend/screens/forensic/forensic_search_screen.dart';
import 'package:safearms_frontend/widgets/responsive_dashboard_scaffold.dart';

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

  testWidgets('search results survive compact to desktop resize',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<BallisticProfileProvider>.value(
        value: _FakeBallisticProfileProvider(),
        child: const MaterialApp(
          home: ResponsiveDashboardScaffold(
            sideNavigation: SizedBox(width: 220, child: Text('Side Nav')),
            topNavigation: SizedBox(height: 64, child: Text('Top Nav')),
            mainContent: ForensicSearchScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'AK-47');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Search'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
    await tester.pumpAndSettle();

    expect(find.text('SAFE-RESP-001'), findsOneWidget);
    expect(find.text('AK-47'), findsOneWidget);

    tester.view.physicalSize = const Size(1366, 768);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.text('Side Nav'), findsOneWidget);
    expect(find.text('SAFE-RESP-001'), findsOneWidget);
    expect(find.text('AK-47'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero-result search recovers after extra criterion is removed',
      (tester) async {
    await _pumpSearchScreenWithProvider(
      tester,
      _FakeBallisticProfileProvider(),
    );

    await _enterGeneralSearch(tester, 'AK-47');
    await _submitFocusedSearchField(tester);

    expect(find.text('SAFE-RESP-001'), findsOneWidget);

    await _enterFiringPin(tester, 'does-not-match');
    await _submitFocusedSearchField(tester);

    expect(find.text('No matching ballistic profiles found'), findsOneWidget);
    expect(find.text('SAFE-RESP-001'), findsNothing);

    await _enterFiringPin(tester, '');
    await _submitFocusedSearchField(tester);

    expect(find.text('SAFE-RESP-001'), findsOneWidget);
    expect(find.text('No matching ballistic profiles found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late zero-result response cannot overwrite newer results',
      (tester) async {
    await _pumpSearchScreenWithProvider(
      tester,
      _FakeBallisticProfileProvider(
        zeroResultDelay: const Duration(milliseconds: 100),
      ),
    );

    await _enterGeneralSearch(tester, 'AK-47');
    await _enterFiringPin(tester, 'does-not-match');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 10));

    await _enterFiringPin(tester, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('SAFE-RESP-001'), findsOneWidget);
    expect(find.text('No matching ballistic profiles found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'dropdown selection waits for explicit search and sends visible criteria',
      (tester) async {
    final provider = _FakeBallisticProfileProvider();
    await _pumpSearchScreenWithProvider(tester, provider);

    await _enterGeneralSearch(tester, 'AK-47');
    await _selectCaliberOption(tester, '7.62x39mm');

    expect(provider.calls, isEmpty);

    await _enterRifling(tester, '4 grooves');
    await _enterBreechFace(tester, 'Semi-circular');
    await _tapSearch(tester);

    expect(find.text('SAFE-RESP-001'), findsOneWidget);
    expect(provider.calls, hasLength(1));
    expect(provider.calls.single.generalSearch, 'AK-47');
    expect(provider.calls.single.caliber, '7.62x39mm');
    expect(provider.calls.single.rifling, '4 grooves');
    expect(provider.calls.single.breechFace, 'Semi-circular');
    expect(provider.calls.single.firingPin, isNull);
    expect(provider.calls.single.incidentDate, isNull);
    expect(
      find.textContaining(
        'Submitted: General: AK-47 | Caliber: 7.62x39mm',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'recorded options populate all ballistic criteria and allow typing',
      (tester) async {
    final provider = _FakeBallisticProfileProvider();
    await _pumpSearchScreenWithProvider(tester, provider);

    await _selectAutocompleteOption(
      tester,
      3,
      'Circular, centered, 0.82.mm with smooth primer rim',
    );
    await _enterChamberFeed(tester, 'typed custom chamber scrape');
    await _selectAutocompleteOption(
      tester,
      6,
      'Fine linear extractor mark at 10 o clock',
    );
    await _tapSearch(tester);

    expect(provider.calls, hasLength(1));
    expect(
      provider.calls.single.firingPin,
      'Circular, centered, 0.82.mm with smooth primer rim',
    );
    expect(provider.calls.single.chamberFeed, 'typed custom chamber scrape');
    expect(
      provider.calls.single.breechFace,
      'Fine linear extractor mark at 10 o clock',
    );
    expect(tester.takeException(), isNull);
  });
}

class _ForensicSearchCall {
  final String? firingPin;
  final String? caliber;
  final String? rifling;
  final String? chamberFeed;
  final String? breechFace;
  final String? firearmSerial;
  final String? testLocation;
  final String? forensicLab;
  final String? generalSearch;
  final String? incidentDate;
  final String incidentDateMode;
  final int page;
  final int limit;

  const _ForensicSearchCall({
    required this.firingPin,
    required this.caliber,
    required this.rifling,
    required this.chamberFeed,
    required this.breechFace,
    required this.firearmSerial,
    required this.testLocation,
    required this.forensicLab,
    required this.generalSearch,
    required this.incidentDate,
    required this.incidentDateMode,
    required this.page,
    required this.limit,
  });
}

class _FakeBallisticProfileProvider extends BallisticProfileProvider {
  final Duration zeroResultDelay;
  final List<_ForensicSearchCall> calls = [];
  static const Map<String, List<String>> _searchOptions = {
    'calibers': ['7.62x39mm', '9x19mm Parabellum'],
    'riflings': [
      '4 grooves, right-hand twist',
      '6 grooves, right-hand twist, 1:10 pitch',
    ],
    'firingPins': [
      'Circular, centered, 0.82.mm with smooth primer rim',
      'Rectangular, centered, 1.20mm x 0.80mm with shallow drag tail',
    ],
    'chamberFeeds': [
      'Polygonal chamber with shallow feed-ramp polish',
      'Stamped receiver marks with diagonal feed-ramp striation',
    ],
    'breechFaces': [
      'Semi-circular',
      'Fine linear extractor mark at 10 o clock',
    ],
  };

  _FakeBallisticProfileProvider({
    this.zeroResultDelay = Duration.zero,
  });

  @override
  Future<Map<String, List<String>>> loadForensicSearchOptions({
    bool forceRefresh = false,
  }) async {
    return _searchOptions;
  }

  @override
  Future<Map<String, dynamic>> forensicSearch({
    String? firingPin,
    String? caliber,
    String? rifling,
    String? chamberFeed,
    String? breechFace,
    String? firearmSerial,
    String? testLocation,
    String? forensicLab,
    String? generalSearch,
    String? incidentDate,
    String incidentDateMode = 'filter',
    int page = 1,
    int limit = 20,
  }) async {
    calls.add(
      _ForensicSearchCall(
        firingPin: firingPin,
        caliber: caliber,
        rifling: rifling,
        chamberFeed: chamberFeed,
        breechFace: breechFace,
        firearmSerial: firearmSerial,
        testLocation: testLocation,
        forensicLab: forensicLab,
        generalSearch: generalSearch,
        incidentDate: incidentDate,
        incidentDateMode: incidentDateMode,
        page: page,
        limit: limit,
      ),
    );

    if (firingPin?.trim().isNotEmpty ?? false) {
      if (zeroResultDelay > Duration.zero) {
        await Future<void>.delayed(zeroResultDelay);
      }

      return {
        'data': <Map<String, dynamic>>[],
        'total': 0,
        'page': page,
        'pageSize': limit,
        'totalPages': 0,
      };
    }

    return {
      'data': [
        {
          'firearm_id': 'FA-RESP-001',
          'manufacturer': 'Kalashnikov',
          'model': 'AK-47',
          'serial_number': 'SAFE-RESP-001',
          'caliber': '7.62x39mm',
          'evidence_strength': 'Strong candidate',
          'match_score': 90,
          'matched_fields': ['General evidence'],
          'incident_custody': {'held_at_incident': false},
          'firing_pin_impression': 'Circular, centered',
          'rifling_characteristics': '4 grooves, right-hand twist',
          'chamber_marks': 'Parallel chamber marks',
          'ejector_marks': 'Semi-circular',
          'extractor_marks': 'Fine extractor scrape',
          'is_locked': true,
          'registration_hash': 'resize-state-hash',
        },
      ],
      'total': 1,
      'page': page,
      'pageSize': limit,
      'totalPages': 1,
    };
  }
}

Future<void> _pumpSearchScreenWithProvider(
  WidgetTester tester,
  BallisticProfileProvider provider,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<BallisticProfileProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF1A1F2E),
          body: ForensicSearchScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterGeneralSearch(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).at(0), value);
  await tester.pump();
}

Future<void> _enterFiringPin(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).at(3), value);
  await tester.pump();
}

Future<void> _enterRifling(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).at(4), value);
  await tester.pump();
}

Future<void> _enterChamberFeed(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).at(5), value);
  await tester.pump();
}

Future<void> _enterBreechFace(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(TextField).at(6), value);
  await tester.pump();
}

Future<void> _selectCaliberOption(
  WidgetTester tester,
  String value,
) async {
  await _selectAutocompleteOption(tester, 2, value);
}

Future<void> _selectAutocompleteOption(
  WidgetTester tester,
  int textFieldIndex,
  String value,
) async {
  final field = find.byType(TextField).at(textFieldIndex);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> _tapSearch(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Search'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Search'));
  await tester.pumpAndSettle();
}

Future<void> _submitFocusedSearchField(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

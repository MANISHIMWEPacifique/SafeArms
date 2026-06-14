import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/screens/workflows/procurement_request_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpProcurementDialog(
    WidgetTester tester,
    Future<void> Function(
      List<Map<String, dynamic>> requests,
      String priority,
      DateTime requiredBy,
      String justification,
    ) onSubmit,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) =>
                          ProcurementRequestDialog(onSubmit: onSubmit),
                    );
                  },
                  child: const Text('Open procurement dialog'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open procurement dialog'));
    await tester.pumpAndSettle();
  }

  String totalQuantity(WidgetTester tester) {
    final totalText = tester.widget<Text>(
      find.byKey(const Key('procurement-total-quantity')),
    );
    return totalText.data ?? '';
  }

  testWidgets('typed quantity updates total and submitted row', (tester) async {
    List<Map<String, dynamic>>? submittedRows;

    await pumpProcurementDialog(tester,
        (requests, priority, requiredBy, justification) async {
      submittedRows = requests
          .map((request) => Map<String, dynamic>.from(request))
          .toList();
    });

    await tester.enterText(
      find.byKey(const ValueKey('procurement-quantity-input-0')),
      '7',
    );
    await tester.pump();

    expect(totalQuantity(tester), '7');

    await tester.enterText(
      find.byKey(const Key('procurement-justification-input')),
      'Operational shortage',
    );
    await tester.tap(find.byKey(const Key('procurement-submit-button')));
    await tester.pumpAndSettle();

    expect(
      submittedRows,
      equals([
        {'type': 'Pistol', 'quantity': 7},
      ]),
    );
  });

  testWidgets('plus and minus buttons still adjust quantity', (tester) async {
    await pumpProcurementDialog(
        tester, (requests, priority, requiredBy, justification) async {});

    await tester.tap(
      find.byKey(const ValueKey('procurement-quantity-increment-0')),
    );
    await tester.pump();
    expect(totalQuantity(tester), '2');

    await tester.tap(
      find.byKey(const ValueKey('procurement-quantity-decrement-0')),
    );
    await tester.pump();
    expect(totalQuantity(tester), '1');

    await tester.tap(
      find.byKey(const ValueKey('procurement-quantity-decrement-0')),
    );
    await tester.pump();
    expect(totalQuantity(tester), '1');
  });

  testWidgets('blank and zero quantities block submit', (tester) async {
    var submitCount = 0;

    await pumpProcurementDialog(tester,
        (requests, priority, requiredBy, justification) async {
      submitCount++;
    });

    await tester.enterText(
      find.byKey(const Key('procurement-justification-input')),
      'Operational shortage',
    );

    await tester.enterText(
      find.byKey(const ValueKey('procurement-quantity-input-0')),
      '',
    );
    await tester.tap(find.byKey(const Key('procurement-submit-button')));
    await tester.pump();

    expect(submitCount, 0);
    expect(
      find.text('Please enter quantity of at least 1 for each firearm type'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('procurement-quantity-input-0')),
      '0',
    );
    await tester.tap(find.byKey(const Key('procurement-submit-button')));
    await tester.pump();

    expect(submitCount, 0);
  });
}

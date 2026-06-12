import 'package:flutter_test/flutter_test.dart';
import 'package:safearms_frontend/utils/duration_formatter.dart';

void main() {
  group('formatOperationalDuration', () {
    test('includes hours and minutes', () {
      expect(
        formatOperationalDuration(const Duration(hours: 5, minutes: 34)),
        '5 hours 34 minutes',
      );
    });

    test('does not floor away remaining minutes', () {
      expect(
        formatOperationalDuration(const Duration(hours: 5, minutes: 59)),
        '5 hours 59 minutes',
      );
    });

    test('formats overdue durations with the same precision', () {
      expect(
        formatOperationalDuration(const Duration(hours: 1, minutes: 7)),
        '1 hour 7 minutes',
      );
    });
  });
}

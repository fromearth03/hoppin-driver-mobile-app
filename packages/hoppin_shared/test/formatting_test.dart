import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

void main() {
  group('money', () {
    test('formatPounds renders two decimals', () {
      expect(formatPounds(12.5), '£12.50');
      expect(formatPounds(9), '£9.00');
      expect(formatPounds(0), '£0.00');
    });
    test('formatPence converts to pounds', () {
      expect(formatPence(900), '£9.00');
      expect(formatPence(1), '£0.01');
      expect(formatPence(180), '£1.80');
    });
  });

  group('dates', () {
    test('formatShortDateTime renders day, month, time', () {
      // Construct a local time directly so the expectation is TZ-stable.
      final dt = DateTime(2026, 7, 5, 17, 42);
      expect(formatShortDateTime(dt), '5 Jul, 17:42');
    });
    test('formatTime pads minutes and hours', () {
      expect(formatTime(DateTime(2026, 1, 2, 9, 5)), '09:05');
    });
  });
}

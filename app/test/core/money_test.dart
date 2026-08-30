import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';

void main() {
  group('Pence', () {
    test('formats whole and part pounds', () {
      expect(const Pence(830).format(), '£8.30');
      expect(const Pence(2000).format(), '£20.00');
      expect(const Pence(5).format(), '£0.05');
      expect(const Pence(0).format(), '£0.00');
    });

    test('formats negatives with a real minus sign, not a hyphen', () {
      expect(const Pence(-5000).format(), '−£50.00');
    });

    test('formatSigned marks positives explicitly', () {
      expect(const Pence(830).formatSigned(), '+£8.30');
      expect(const Pence(-300).formatSigned(), '−£3.00');
      expect(const Pence(0).formatSigned(), '£0.00');
    });

    test('fromPounds converts the wallet float without drift', () {
      expect(Pence.fromPounds(8.30).pence, 830);
      expect(Pence.fromPounds(0.1 + 0.2).pence, 30);
      expect(Pence.fromPounds(-50.0).pence, -5000);
    });

    test('arithmetic stays integer', () {
      expect((const Pence(830) + const Pence(170)).pence, 1000);
      expect((const Pence(830) - const Pence(1000)).pence, -170);
    });

    test('exposes sign predicates', () {
      expect(const Pence(-1).isNegative, isTrue);
      expect(const Pence(0).isNegative, isFalse);
      expect(const Pence(0).isZero, isTrue);
    });

    test('equality is by value', () {
      expect(const Pence(830), const Pence(830));
    });
  });
}

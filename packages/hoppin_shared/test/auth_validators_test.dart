import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

void main() {
  group('validateEmail', () {
    test('accepts a normal address', () {
      expect(validateEmail('rider@example.com'), isNull);
    });
    test('trims surrounding whitespace', () {
      expect(validateEmail('  rider@example.com  '), isNull);
    });
    test('rejects empty and null', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
    });
    test('rejects missing domain / tld / spaces', () {
      expect(validateEmail('rider@'), isNotNull);
      expect(validateEmail('rider@host'), isNotNull);
      expect(validateEmail('ri der@example.com'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('sign-in: any non-empty passes', () {
      expect(validatePassword('x'), isNull);
    });
    test('sign-in: empty fails', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
    });
    test('sign-up: shorter than 8 fails', () {
      expect(validatePassword('1234567', forSignUp: true), isNotNull);
    });
    test('sign-up: 8 characters passes', () {
      expect(validatePassword('12345678', forSignUp: true), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';

void main() {
  test('returns whatever token the source currently holds', () async {
    var current = 'jwt-1';
    final store = CallbackTokenStore(() => current);

    expect(await store.read(), 'jwt-1');

    // The SDK refreshed underneath us; the next call must see the new one
    // rather than a cached copy.
    current = 'jwt-2';
    expect(await store.read(), 'jwt-2');
  });

  test('returns null when signed out', () async {
    expect(await CallbackTokenStore(() => null).read(), isNull);
  });

  test('InMemoryTokenStore still serves tests', () async {
    expect(await InMemoryTokenStore('jwt').read(), 'jwt');
  });
}

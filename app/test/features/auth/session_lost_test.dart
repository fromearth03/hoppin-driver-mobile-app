import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/session_lost.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockTokens extends Mock implements TokenStore {}

/// Answers every request with the given status and envelope.
Dio dioAnswering(int status, Map<String, dynamic> body) {
  final dio = Dio();
  dio.options.validateStatus = (_) => true;
  dio.httpClientAdapter = _StubAdapter(status, body);
  return dio;
}

class _StubAdapter implements HttpClientAdapter {
  final int status;
  final Map<String, dynamic> body;

  _StubAdapter(this.status, this.body);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
        '{"error":"${body['error']}","code":"${body['code']}"}',
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
}

void main() {
  setUpAll(() => registerFallbackValue(''));

  test('a replaced session is raised once, however many calls fail', () async {
    final tokens = _MockTokens();
    when(() => tokens.read()).thenAnswer((_) async => 'token');

    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      dioProvider.overrideWithValue(dioAnswering(
        401,
        {'error': 'signed in elsewhere', 'code': 'SESSION_REPLACED'},
      )),
    ]);
    addTearDown(container.dispose);

    expect(container.read(sessionLostProvider), isFalse);

    final api = container.read(apiClientProvider);
    await api.get<dynamic>('/me/profile');

    expect(container.read(sessionLostProvider), isTrue);

    // Twenty in-flight calls all answer the same way; the screen must be
    // raised once, not twenty times.
    await api.get<dynamic>('/drivers/me/status');
    expect(container.read(sessionLostProvider), isTrue);
  });

  test('an ordinary failure leaves the session alone', () async {
    final tokens = _MockTokens();
    when(() => tokens.read()).thenAnswer((_) async => 'token');

    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(tokens),
      dioProvider.overrideWithValue(dioAnswering(
        404,
        {'error': 'no such ride', 'code': 'NOT_FOUND'},
      )),
    ]);
    addTearDown(container.dispose);

    await container.read(apiClientProvider).get<dynamic>('/rides/nope');

    // A missing ride is not a lost session. Signing the driver out for one
    // would end their shift over a bad id.
    expect(container.read(sessionLostProvider), isFalse);
  });
}

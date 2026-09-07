import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

/// A driver reported being stuck: "We can't reach the server… Your session has
/// ended. Please log in again." — but it never logged them out, logging out and
/// back in did not clear it, and Retry only failed again.
///
/// Two defects, both here:
///
///  1. Only `SESSION_REPLACED` raised session-lost, so a plain 401
///     (`AUTH_REQUIRED`) parked the driver on a dead session with no exit.
///  2. The token store returned `currentSession?.accessToken` without checking
///     expiry, so once a session went stale every call shipped the dead token.
void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;

  setUp(() => adapter = _MockAdapter());

  ApiClient client({void Function()? onLost}) {
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(dio, InMemoryTokenStore('t'), onSessionLost: onLost);
  }

  test('a plain 401 raises session-lost, so the driver is not stranded',
      () async {
    var raised = false;
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"code":"AUTH_REQUIRED","error":"unauthorized"}', 401));

    final r = await client(onLost: () => raised = true)
        .get<Map<String, dynamic>>('/drivers/me/today');

    expect(r.errorOrNull!.code, 'AUTH_REQUIRED');
    expect(raised, isTrue,
        reason: 'a 401 that does not sign the driver out leaves them on a '
            'screen whose every call is rejected');
  });

  test('a 401 with no body still raises it', () async {
    var raised = false;
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('', 401));

    await client(onLost: () => raised = true)
        .get<Map<String, dynamic>>('/drivers/me/today');

    expect(raised, isTrue);
  });

  test('SESSION_REPLACED still raises it', () async {
    var raised = false;
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"code":"SESSION_REPLACED","error":"taken"}', 401));

    await client(onLost: () => raised = true)
        .get<Map<String, dynamic>>('/drivers/me/today');

    expect(raised, isTrue);
  });

  test('an ordinary failure does NOT raise it', () async {
    var raised = false;
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"code":"INTERNAL","error":"boom"}', 500));

    await client(onLost: () => raised = true)
        .get<Map<String, dynamic>>('/drivers/me/today');

    expect(raised, isFalse,
        reason: 'a 500 is not an auth problem; signing the driver out on one '
            'would throw away a working session over a server hiccup');
  });
}

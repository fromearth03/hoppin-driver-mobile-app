import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/auth/session_lost.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

/// A session can end for three reasons and the driver must be told which.
///
/// `ACCOUNT_BANNED` and `ACCOUNT_SUSPENDED` had copy in `error_codes.dart` and
/// nothing else — a blocked driver stayed signed in with every call refused,
/// which is the same trap that `AUTH_REQUIRED` used to create. `ACCOUNT_DELETED`
/// is new from the backend: a GDPR erasure now stops working immediately rather
/// than lasting until the token expires.
///
/// The reason matters as much as the raising. Telling a deleted driver their
/// account "signed in on another device" sends them looking for a phone that
/// does not exist, and offers a banned driver a password reset that cannot help.
void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late List<SessionEndReason> raised;

  setUp(() {
    adapter = _MockAdapter();
    raised = [];
  });

  ApiClient client() {
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(dio, InMemoryTokenStore('t'),
        onSessionLost: raised.add);
  }

  Future<void> callWith(String code, int status) async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"code":"$code","error":"x"}', status));
    await client().get<Map<String, dynamic>>('/drivers/me/today');
  }

  test('a deleted account ends the session, and says it was deleted', () async {
    await callWith('ACCOUNT_DELETED', 403);
    expect(raised, [SessionEndReason.deleted]);
  });

  test('a banned account ends the session as blocked', () async {
    await callWith('ACCOUNT_BANNED', 403);
    expect(raised, [SessionEndReason.blocked],
        reason: 'a banned driver used to stay signed in with every call '
            'refused and no way out');
  });

  test('a suspended account ends the session as blocked', () async {
    await callWith('ACCOUNT_SUSPENDED', 403);
    expect(raised, [SessionEndReason.blocked]);
  });

  test('a blacklisted device ends the session as blocked', () async {
    await callWith('DEVICE_BLACKLISTED', 403);
    expect(raised, [SessionEndReason.blocked]);
  });

  test('a replaced session still reads as replaced', () async {
    await callWith('SESSION_REPLACED', 401);
    expect(raised, [SessionEndReason.replaced]);
  });

  test('a plain 401 still reads as replaced', () async {
    await callWith('AUTH_REQUIRED', 401);
    expect(raised, [SessionEndReason.replaced]);
  });

  test('an ordinary failure ends nothing', () async {
    await callWith('INTERNAL', 500);
    expect(raised, isEmpty,
        reason: 'signing a driver out over a server hiccup would throw away a '
            'working session');
  });

  test('NO_DRIVER_PROFILE does not end the session', () async {
    // 422 on a location beat is terminal for the beat, not for the session:
    // the driver is signed in fine, they simply have no profile row. Signing
    // them out would hide a provisioning gap behind a login screen.
    await callWith('NO_DRIVER_PROFILE', 422);
    expect(raised, isEmpty);
  });

  test('NO_DRIVER_PROFILE is not retryable', () {
    // The account has no profile and that needs support. Retrying the beat
    // every 15 seconds only re-hides it.
    expect(
      ApiException('NO_DRIVER_PROFILE', 'x', 422).isRetryable,
      isFalse,
    );
  });

  test('ACCOUNT_DELETED is not retryable', () {
    expect(ApiException('ACCOUNT_DELETED', 'x', 403).isRetryable, isFalse);
  });
}

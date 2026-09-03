import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
  });

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late Dio dio;
  late _MockAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = _MockAdapter();
    dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
      ..httpClientAdapter = adapter;
    client = ApiClient(dio, InMemoryTokenStore('jwt-abc'));
  });

  test('returns Ok with the decoded body on 200', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"presence":"online"}', 200));

    final r = await client.get<Map<String, dynamic>>('/drivers/me/status');

    expect(r.isOk, isTrue);
    expect(r.valueOrNull!['presence'], 'online');
  });

  test('attaches the bearer token', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{}', 200));

    await client.get<Map<String, dynamic>>('/drivers/me/status');

    final captured = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(captured.headers['Authorization'], 'Bearer jwt-abc');
  });

  test('maps an error envelope to ApiException on the code', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"code":"OFFER_EXPIRED","error":"offer lapsed"}', 409));

    final r = await client.post<Map<String, dynamic>>('/offers/x/accept');

    expect(r.isOk, isFalse);
    expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    expect(r.errorOrNull!.statusCode, 409);
  });

  test('keeps extra error fields such as NOT_ELIGIBLE reason', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"code":"NOT_ELIGIBLE","error":"blocked","reason":"DOCS_EXPIRED",'
        '"blocking_document_types":["vehicle_insurance"]}',
        403));

    final r = await client.post<Map<String, dynamic>>('/drivers/me/online');

    expect(r.errorOrNull!.fields['reason'], 'DOCS_EXPIRED');
    expect(r.errorOrNull!.fields['blocking_document_types'],
        ['vehicle_insurance']);
  });

  test('maps a body-less failure to its status', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('not json', 500));

    final r = await client.get<Map<String, dynamic>>('/drivers/me/status');

    expect(r.errorOrNull!.code, 'INTERNAL');
  });

  test('maps a connection failure to INTERNAL rather than throwing', () async {
    when(() => adapter.fetch(any(), any(), any())).thenThrow(
        DioException.connectionError(
            requestOptions: RequestOptions(path: '/x'), reason: 'offline'));

    final r = await client.get<Map<String, dynamic>>('/drivers/me/status');

    expect(r.isOk, isFalse);
    expect(r.errorOrNull!.isRetryable, isTrue);
  });

  group('parseError falls back on the STATUS, not on NOT_FOUND', () {
    Response<dynamic> bodyless(int status) => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: status,
          // A gateway page, a truncated body, a cold start: anything that is
          // not the service's own JSON envelope.
          data: '<html>502 Bad Gateway</html>',
        );

    test('🔴 a bodiless 401 is AUTH_REQUIRED, never NOT_FOUND', () {
      // This was the defect: every non-500 without a parseable body became
      // NOT_FOUND — so a stale session was reported as "That record no longer
      // exists", which is wrong AND points the driver away from the fix.
      expect(ApiClient.parseError(bodyless(401)).code, 'AUTH_REQUIRED');
    });

    test('a bodiless 403 is FORBIDDEN', () {
      expect(ApiClient.parseError(bodyless(403)).code, 'FORBIDDEN');
    });

    test('a bodiless 5xx stays INTERNAL, and stays retryable', () {
      final e = ApiClient.parseError(bodyless(503));
      expect(e.code, 'INTERNAL');
      expect(e.isRetryable, isTrue);
    });

    test('a genuine 404 is still NOT_FOUND', () {
      expect(ApiClient.parseError(bodyless(404)).code, 'NOT_FOUND');
    });

    test("the server's own code always wins over the status guess", () {
      final r = Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 401,
        data: {'code': 'SESSION_REPLACED', 'error': 'signed in elsewhere'},
      );

      expect(ApiClient.parseError(r).code, 'SESSION_REPLACED',
          reason: 'the status fallback must never override a stated code — '
              'SESSION_REPLACED arrives as a 401 and means something the '
              'app handles differently');
    });
  });
}

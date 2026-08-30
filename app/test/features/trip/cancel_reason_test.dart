import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late CancelReasonRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = CancelReasonRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses the penny amount, not the deprecated float', () {
    final r = CancelReason.fromJson({
      'id': 'rider_no_show',
      'reason_text': "Rider didn't show up",
      'pickable': true,
      'penalty_fee_amount': 59.0,
      'penalty_fee_pence': 5900,
      'free_cancel_seconds': 300,
    });

    expect(r.penaltyFee!.pence, 5900);
    expect(r.hasPenalty, isTrue);
    expect(r.freeCancelSeconds, 300);
  });

  test('a reason with no penalty reports none', () {
    final r = CancelReason.fromJson({
      'id': 'vehicle_issue',
      'reason_text': 'Vehicle issue',
      'pickable': true,
    });

    expect(r.penaltyFee, isNull);
    expect(r.hasPenalty, isFalse);
  });

  test('the picker never offers a system outcome', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '[{"id":"driver_declined","reason_text":"driver_declined",'
        '"pickable":false},'
        '{"id":"offer_timeout","reason_text":"offer_timeout","pickable":false},'
        '{"id":"vehicle_issue","reason_text":"Vehicle issue","pickable":true}]',
        200));

    final r = await repo.forDriver();

    // The two slugs are system-generated outcomes, not choices. Filtering on
    // the server's flag is what keeps a raw slug off the screen without us
    // prettifying one.
    expect(r.valueOrNull!.map((e) => e.id), ['vehicle_issue']);
  });

  test('reads an envelope as well as a bare array', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"reasons":[{"id":"a","reason_text":"A","pickable":true}]}', 200));

    final r = await repo.forDriver();

    expect(r.valueOrNull!.single.id, 'a');
  });

  test('asks for the driver actor', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('[]', 200));

    await repo.forDriver();

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters['actor'], 'driver');
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  const rideJson = '{"id":"r1","status":"accepted","ref":"R-1042",'
      '"geo":{"pickup":{"lat":1.0,"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},'
      '"route":[]}}';

  late _MockAdapter adapter;
  late TripRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = TripRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('reads a ride', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body(rideJson, 200));

    final r = await repo.ride('r1');

    expect(r.valueOrNull!.phase, TripPhase.headingToPickup);
    expect(r.valueOrNull!.ref, 'R-1042');
  });

  test('arrive returns the updated ride', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"id":"r1","status":"arrived","geo":{"pickup":{"lat":1.0,'
            '"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},"route":[]}}', 200));

    final r = await repo.arrive('r1');

    expect(r.valueOrNull!.phase, TripPhase.waiting);
  });

  test('a transition out of order surfaces ILLEGAL_TRANSITION', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
        body('{"code":"ILLEGAL_TRANSITION","error":"start before arrive"}',
            409));

    final r = await repo.start('r1');

    expect(r.errorOrNull!.code, 'ILLEGAL_TRANSITION');
  });

  test('an early no-show reports how long is left', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"code":"NO_SHOW_TOO_EARLY","error":"wait","seconds_remaining":120}',
        400));

    final r = await repo.cancel('r1', reasonId: 'rider_no_show', driverUserId: 'u1');

    expect(r.errorOrNull!.code, 'NO_SHOW_TOO_EARLY');
    expect(r.errorOrNull!.fields['seconds_remaining'], 120);
  });

  test('reads the waiting policy', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"free_wait_seconds":180,"per_minute_pence":30,'
        '"no_show_fee_pence":5900,"currency":"GBP"}',
        200));

    final r = await repo.waitingPolicy('r1');

    expect(r.valueOrNull!.freeWaitSeconds, 180);
    expect(r.valueOrNull!.perMinutePence.pence, 30);
  });

  test('cancel sends the reason id the picker chose', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"id":"r1","status":"cancelled","geo":{"pickup":'
            '{"lat":1.0,"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},'
            '"route":[]}}', 200));

    await repo.cancel('r1', reasonId: 'vehicle_issue', driverUserId: 'u1');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.data['reason_id'], 'vehicle_issue');
  });
}

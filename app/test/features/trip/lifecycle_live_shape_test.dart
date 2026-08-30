import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

/// Every payload here is the one the Go service actually returns, taken from
/// the handlers rather than from a plan. The lifecycle transitions in
/// particular reply with a bare message, not a ride.
void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late TripRepository trips;
  late CancelReasonRepository reasons;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(dio, InMemoryTokenStore());
    trips = TripRepository(api);
    reasons = CancelReasonRepository(api);
  });

  const rideJson = '{"id":"r1","status":"arrived","geo":{"pickup":'
      '{"lat":1.0,"lng":2.0},"dropoff":{"lat":3.0,"lng":4.0},"route":[]}}';

  group('lifecycle transitions', () {
    for (final (name, call) in [
      ('arrive', (TripRepository r) => r.arrive('r1')),
      ('start', (TripRepository r) => r.start('r1')),
      ('complete', (TripRepository r) => r.complete('r1')),
    ]) {
      test('$name succeeds against the bare message the service returns',
          () async {
        var call$ = 0;
        when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
          call$++;
          // PATCH returns {"message": ...} with no ride; the repository must
          // re-read the ride rather than parse the acknowledgement.
          return call$ == 1
              ? body('{"message":"Ride updated"}', 200)
              : body(rideJson, 200);
        });

        final r = await call(trips);

        expect(r.isOk, isTrue, reason: '$name must not throw on success');
        expect(r.valueOrNull!.phase, TripPhase.waiting);
      });
    }

    test('a refused transition still surfaces its code', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body('{"code":"ILLEGAL_TRANSITION","error":"too early"}', 409));

      final r = await trips.start('r1');

      expect(r.errorOrNull!.code, 'ILLEGAL_TRANSITION');
    });
  });

  group('cancel', () {
    test('sends the actor fields the handler requires', () async {
      var call$ = 0;
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async {
        call$++;
        return call$ == 1
            ? body('{"message":"Ride cancelled"}', 200)
            : body(rideJson, 200);
      });

      await trips.cancel('r1',
          reasonId: 'reason-1', driverUserId: 'user-9');

      final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
          .captured
          .first as RequestOptions;
      // canceled_by_user_id and actor_type are binding:"required" — without
      // them the handler rejects every cancellation with 400 before it looks
      // at the ride at all.
      expect(sent.data['canceled_by_user_id'], 'user-9');
      expect(sent.data['actor_type'], 'driver');
      expect(sent.data['reason_id'], 'reason-1');
    });
  });

  group('cancellation reasons', () {
    test('reads the cancellation_reasons envelope the service sends',
        () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async =>
          body(
              '{"cancellation_reasons":[{"id":"a","reason_text":"Vehicle issue",'
              '"pickable":true}]}',
              200));

      final r = await reasons.forDriver();

      expect(r.valueOrNull, hasLength(1));
      expect(r.valueOrNull!.single.text, 'Vehicle issue');
    });
  });
}

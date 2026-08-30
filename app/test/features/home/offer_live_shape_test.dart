import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

/// Payloads here mirror `repository.PendingOffer` in the Go service, which
/// keys the offer as `offer_id` and expresses expiry as an absolute
/// `expires_at` — not `id` and `expires_in_sec` as the plan assumed.
void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late OfferRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = OfferRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('reads offer_id, the key the service actually sends', () {
    final offer = PendingOffer.fromJson({
      'offer_id': 'offer-1',
      'ride_id': 'ride-1',
      'fare_pence': 2015,
      'pickup_label': 'City Centre',
      'dropoff_label': 'Railway Station',
    });

    expect(offer.id, 'offer-1');
    expect(offer.rideId, 'ride-1');
  });

  test('derives the countdown from the absolute expires_at', () {
    final offer = PendingOffer.fromJson({
      'offer_id': 'o',
      'ride_id': 'r',
      'fare_pence': 1000,
      'pickup_label': 'A',
      'dropoff_label': 'B',
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 45))
          .toIso8601String(),
    });

    // A hardcoded 60s default would tell the driver they had longer than
    // they do, and the ring would still be turning when the offer lapsed.
    expect(offer.secondsRemaining, closeTo(45, 2));
    expect(offer.hasExpired, isFalse);
  });

  test('an already-lapsed expires_at reports no time left', () {
    final offer = PendingOffer.fromJson({
      'offer_id': 'o',
      'ride_id': 'r',
      'fare_pence': 1000,
      'pickup_label': 'A',
      'dropoff_label': 'B',
      'expires_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 5))
          .toIso8601String(),
    });

    expect(offer.hasExpired, isTrue);
    expect(offer.secondsRemaining, 0);
  });

  test('parses a live offer list without throwing', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"offers":[{"offer_id":"o1","ride_id":"r1","fare_pence":2015,'
        '"pickup_label":"City Centre","dropoff_label":"Station",'
        '"expires_at":"2099-01-01T00:00:00Z"}]}',
        200));

    final r = await repo.offers();

    expect(r.isOk, isTrue);
    expect(r.valueOrNull!.single.id, 'o1');
  });

  test('accept succeeds against the bare acknowledgement the service sends',
      () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"message":"offer accepted"}', 200));

    // The handler returns no ride id. Accepting must still succeed and hand
    // back the ride the offer already named, or a driver who has been
    // assigned a job sees nothing happen.
    final r = await repo.accept('offer-1', rideId: 'ride-9');

    expect(r.isOk, isTrue);
    expect(r.valueOrNull, 'ride-9');
  });

  test('a lapsed offer still surfaces its code on accept', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer(
        (_) async => body('{"code":"OFFER_EXPIRED","error":"gone"}', 409));

    final r = await repo.accept('offer-1', rideId: 'ride-9');

    expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
  });
}

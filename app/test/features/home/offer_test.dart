import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

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

  group('PendingOffer', () {
    test('parses the widened payload', () {
      final o = PendingOffer.fromJson({
        'id': 'offer-1',
        'ride_id': 'ride-1',
        'fare_pence': 2015,
        'pickup_label': 'City Centre',
        'dropoff_label': 'Railway Station',
        'ride_category': 'standard',
        'estimated_duration_seconds': 900,
        'pickup_eta_seconds': 240,
        'expires_in_sec': 60,
      });

      expect(o.fare, const Pence(2015));
      expect(o.pickupLabel, 'City Centre');
      expect(o.pickupEtaSeconds, 240);
      expect(o.expiresInSec, 60);
    });

    test('prefers fare_pence over the deprecated float fare', () {
      final o = PendingOffer.fromJson({
        'id': 'o',
        'ride_id': 'r',
        'fare': 20.15,
        'fare_pence': 2015,
        'pickup_label': 'A',
        'dropoff_label': 'B',
        'expires_in_sec': 60,
      });
      expect(o.fare.pence, 2015);
    });

    test('tolerates a null pickup ETA', () {
      final o = PendingOffer.fromJson({
        'id': 'o',
        'ride_id': 'r',
        'fare_pence': 1000,
        'pickup_label': 'A',
        'dropoff_label': 'B',
        'pickup_eta_seconds': null,
        'expires_in_sec': 60,
      });
      expect(o.pickupEtaSeconds, isNull);
    });

    test('counts down from when it was received', () {
      final o = PendingOffer.fromJson({
        'id': 'o',
        'ride_id': 'r',
        'fare_pence': 1000,
        'pickup_label': 'A',
        'dropoff_label': 'B',
        'expires_in_sec': 60,
      }, receivedAt: DateTime.now().subtract(const Duration(seconds: 20)));

      expect(o.secondsRemaining, closeTo(40, 1));
      expect(o.hasExpired, isFalse);
    });

    test('reports expiry once the window has passed', () {
      final o = PendingOffer.fromJson({
        'id': 'o',
        'ride_id': 'r',
        'fare_pence': 1000,
        'pickup_label': 'A',
        'dropoff_label': 'B',
        'expires_in_sec': 60,
      }, receivedAt: DateTime.now().subtract(const Duration(seconds: 61)));

      expect(o.hasExpired, isTrue);
      expect(o.secondsRemaining, 0);
    });

    test('carries no rider identity fields at all', () {
      // Guards the Equality Act position: even if the server started
      // sending a name, the model has nowhere to put it.
      final o = PendingOffer.fromJson({
        'id': 'o',
        'ride_id': 'r',
        'fare_pence': 1000,
        'pickup_label': 'A',
        'dropoff_label': 'B',
        'expires_in_sec': 60,
        'rider_name': 'Should Not Appear',
        'rider_rating': 4.3,
      });
      expect(o.toString().contains('Should Not Appear'), isFalse);
    });
  });

  group('OfferRepository', () {
    test('returns an empty list when there is no offer', () async {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => body('{"offers":[]}', 200));

      final r = await repo.offers();

      expect(r.valueOrNull, isEmpty);
    });

    test('parses a bare array as well as an envelope', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
          '[{"id":"o","ride_id":"r","fare_pence":1000,"pickup_label":"A",'
          '"dropoff_label":"B","expires_in_sec":60}]',
          200));

      final r = await repo.offers();

      expect(r.valueOrNull!.single.id, 'o');
    });

    test('accept returns the ride id', () async {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((_) async => body('{"ride_id":"ride-9"}', 200));

      final r = await repo.accept('offer-1', rideId: 'ride-9');

      expect(r.valueOrNull, 'ride-9');
    });

    test('accept surfaces OFFER_EXPIRED', () async {
      when(() => adapter.fetch(any(), any(), any())).thenAnswer(
          (_) async => body('{"code":"OFFER_EXPIRED","error":"lapsed"}', 409));

      final r = await repo.accept('offer-1', rideId: 'ride-9');

      expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    });
  });
}

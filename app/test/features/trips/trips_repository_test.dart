import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late TripsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = TripsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  test('parses a completed trip', () {
    final t = DriverTrip.fromJson({
      'id': 'r1',
      'ref': 'R-1042',
      'completed_at': '2026-08-30T09:30:00Z',
      'status': 'completed',
      'pickup_label': 'City Centre',
      'dropoff_label': 'Railway Station',
      'distance_miles': 3.2,
      'driver_earnings_pence': 830,
      'penalty_pence': 0,
    });

    expect(t.ref, 'R-1042');
    expect(t.earnings.pence, 830);
    expect(t.isCancelled, isFalse);
    expect(t.penalty.isZero, isTrue);
  });

  test('states who cancelled, in words the driver can act on', () {
    DriverTrip cancelledBy(String who) => DriverTrip.fromJson({
          'id': 'r2',
          'status': 'cancelled',
          'pickup_label': 'A',
          'dropoff_label': 'B',
          'cancelled_by': who,
        });

    expect(cancelledBy('driver').cancelledByLabel, 'You cancelled');
    expect(cancelledBy('rider').cancelledByLabel, 'Cancelled by rider');
    expect(cancelledBy('admin').cancelledByLabel, 'Cancelled by Hoppin');
    // A watchdog timeout is explicitly not the driver's fault, and the
    // wording has to say so — it feeds their cancellation rate otherwise.
    expect(cancelledBy('system').cancelledByLabel, 'Cancelled automatically');
  });

  test('carries the human-readable cancel reason when there is one', () {
    final t = DriverTrip.fromJson({
      'id': 'r2',
      'status': 'cancelled',
      'pickup_label': 'A',
      'dropoff_label': 'B',
      'cancelled_by': 'rider',
      'cancel_reason': "Rider didn't show up",
      'penalty_pence': 5900,
    });

    expect(t.cancelReason, "Rider didn't show up");
    expect(t.penalty.pence, 5900);
  });

  test('a completed trip has no cancellation fields', () {
    final t = DriverTrip.fromJson({
      'id': 'r1',
      'status': 'completed',
      'pickup_label': 'A',
      'dropoff_label': 'B',
    });

    expect(t.cancelledBy, isNull);
    expect(t.cancelledByLabel, isNull);
  });

  test('filters server-side rather than in the client', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"trips":[],"has_more":false}', 200));

    await repo.page(filter: TripFilter.cancelled);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    // Filtering client-side would page fifty rows and display twelve.
    expect(sent.queryParameters['status'], 'cancelled');
  });

  test('omits the status parameter for the All filter', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"trips":[],"has_more":false}', 200));

    await repo.page(filter: TripFilter.all);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters.containsKey('status'), isFalse);
  });

  test('can separate cancels the driver made from cancels made on them',
      () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"trips":[],"has_more":false}', 200));

    await repo.page(filter: TripFilter.cancelled, cancelledBy: 'others');

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    expect(sent.queryParameters['cancelled_by'], 'others');
  });

  test('reads the cursor for the next page', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"trips":[],"next_cursor":"2026-08-29T00:00:00Z","has_more":true}',
        200));

    final r = await repo.page();

    expect(r.valueOrNull!.nextCursor, '2026-08-29T00:00:00Z');
    expect(r.valueOrNull!.hasMore, isTrue);
  });
}

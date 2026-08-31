import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/features/stats/data/models/driver_stats.dart';
import 'package:hoppin_driver/features/stats/data/stats_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements HttpClientAdapter {}

void main() {
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));

  ResponseBody body(String json, int status) =>
      ResponseBody.fromString(json, status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  late _MockAdapter adapter;
  late StatsRepository repo;

  setUp(() {
    adapter = _MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = StatsRepository(ApiClient(dio, InMemoryTokenStore()));
  });

  group('DriverStats', () {
    test('parses the shape /drivers/me/stats really sends', () {
      final s = DriverStats.fromJson({
        'period': 'month',
        'from': '2026-08-01T00:00:00Z',
        'to': '2026-08-31T23:59:59Z',
        'rating': 4.8,
        'rating_count': 5,
        'acceptance_rate': 0.94,
        'completion_rate': 0.83,
        'cancellation_rate': 0.04,
        'offers_received': 20,
        'offers_accepted': 18,
        'offers_declined': 2,
        'accepted_trips': 18,
        'trips_completed': 15,
        'trips_cancelled': 3,
        'penalties_active': 6,
      });

      expect(s.period, StatsPeriod.month);
      expect(s.from, DateTime.utc(2026, 8, 1));
      expect(s.averageRating, 4.8);
      expect(s.cancellationRate, 0.04);
      expect(s.penaltiesActive, 6);
      expect(s.offersDeclined, 2);
    });

    test('reads the rating key /drivers/me/today uses too', () {
      // The two endpoints name the same figure differently. Either payload
      // must produce a rating rather than silently falling to an em dash.
      final s = DriverStats.fromJson({'average_rating': 4.2});
      expect(s.averageRating, 4.2);
    });

    test('an omitted rate renders an em dash, never a zero', () {
      // The service omits a rate whose denominator is zero rather than
      // sending 0. A driver who has had no offers has an unknown acceptance
      // rate, not a 0% one — the difference matters to someone being
      // assessed on it.
      final s = DriverStats.fromJson({'period': 'week'});

      expect(s.acceptanceRate, isNull);
      expect(s.cancellationRate, isNull);
      expect(s.ratePercent(s.acceptanceRate), '—');
      expect(s.ratePercent(s.cancellationRate), '—');
    });

    test('formats a real rate as a percentage', () {
      // Rates arrive as 0..1, not as percentages.
      final s = DriverStats.fromJson({'acceptance_rate': 0.94});
      expect(s.ratePercent(s.acceptanceRate), '94%');
    });

    test('a driver with no reviews yet has no rating', () {
      final s = DriverStats.fromJson({'rating_count': 0});
      expect(s.averageRating, isNull);
    });

    test('an unknown period falls back to the service default', () {
      expect(DriverStats.fromJson({'period': 'decade'}).period,
          StatsPeriod.week);
    });
  });

  test('asks for the window the driver selected', () async {
    when(() => adapter.fetch(any(), any(), any()))
        .thenAnswer((_) async => body('{"period":"month"}', 200));

    await repo.stats(period: StatsPeriod.month);

    final sent = verify(() => adapter.fetch(captureAny(), any(), any()))
        .captured
        .first as RequestOptions;
    // The service rejects any window outside week/month/all, so the code
    // it is sent has to be the service's own.
    expect(sent.queryParameters['period'], 'month');
  });

  test('penalties come from the ledger and carry the appeal flag', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"penalties":[{"id":"p1","created_at":"2026-08-26T09:12:00Z",'
        '"amount_pence":1000,"display_title":"Complaint penalty",'
        '"display_reason":"A penalty following a rider complaint.",'
        '"ride_id":"r1","appealable":true}],"count":6}',
        200));

    final r = await repo.penalties();

    expect(r.valueOrNull!.count, 6);
    final p = r.valueOrNull!.penalties.single;
    expect(p.displayTitle, 'Complaint penalty');
    expect(p.amount.pence, 1000);
    expect(p.appealable, isTrue);
  });

  test('an unappealable penalty says so', () async {
    when(() => adapter.fetch(any(), any(), any())).thenAnswer((_) async => body(
        '{"penalties":[{"id":"p2","created_at":"2026-08-26T09:12:00Z",'
        '"amount_pence":300,"display_title":"Late arrival",'
        '"appealable":false}],"count":1}',
        200));

    final r = await repo.penalties();

    expect(r.valueOrNull!.penalties.single.appealable, isFalse);
  });
}

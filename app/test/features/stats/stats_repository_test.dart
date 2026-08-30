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
    test('parses the round-4 shape', () {
      final s = DriverStats.fromJson({
        'average_rating': 4.8,
        'rating_count': 5,
        'trips_completed': 15,
        'trips_cancelled': 3,
        'online_minutes': 742,
        'penalties_count': 6,
        'balance_pence': -5000,
        'earnings': {
          'total_pence': 11307,
          'this_week_pence': 2400,
          'this_month_pence': 8600,
        },
        'acceptance_rate': 0.94,
        'completion_rate': 0.83,
      });

      expect(s.averageRating, 4.8);
      expect(s.penaltiesCount, 6);
      expect(s.balance.pence, -5000);
      expect(s.weekEarnings.pence, 2400);
    });

    test('a null rate renders an em dash, never a zero', () {
      final s = DriverStats.fromJson({
        'average_rating': null,
        'acceptance_rate': null,
        'completion_rate': null,
      });

      // A driver who has had no offers has an unknown acceptance rate, not
      // a 0% one — the difference matters to someone being assessed on it.
      expect(s.ratePercent(s.acceptanceRate), '—');
      expect(s.acceptanceRate, isNull);
    });

    test('formats a real rate as a percentage', () {
      final s = DriverStats.fromJson({'acceptance_rate': 0.94});
      expect(s.ratePercent(s.acceptanceRate), '94%');
    });

    test('a driver with no reviews yet has no rating', () {
      final s = DriverStats.fromJson({'rating_count': 0});
      expect(s.averageRating, isNull);
    });
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

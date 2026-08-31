import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_client.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:hoppin_driver/features/trips/logic/trips_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockApi extends Mock implements ApiClient {}

class MockTripsRepo extends Mock implements TripsRepository {}

TripsPage page({String? nextCursor}) =>
    TripsPage(trips: const [], nextCursor: nextCursor);

void main() {
  setUpAll(() => registerFallbackValue(TripFilter.all));

  group('repository', () {
    late MockApi api;

    setUp(() {
      api = MockApi();
      when(() => api.get<Map<String, dynamic>>(any(),
              query: any(named: 'query')))
          .thenAnswer((_) async => const Ok({'trips': [], 'has_more': false}));
    });

    Map<String, dynamic> sentQuery() =>
        verify(() => api.get<Map<String, dynamic>>('/drivers/me/trips',
                query: captureAny(named: 'query')))
            .captured
            .single as Map<String, dynamic>;

    test('sends a plain ISO date for each bound', () async {
      await TripsRepository(api).page(
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 31),
      );

      final q = sentQuery();
      expect(q['from'], '2026-08-01');
      expect(q['to'], '2026-08-31');
    });

    test('omits the bounds entirely when there is no range', () async {
      await TripsRepository(api).page();

      final q = sentQuery();
      expect(q.containsKey('from'), isFalse);
      expect(q.containsKey('to'), isFalse);
    });

    test('an open-ended range sends only the bound it has', () async {
      await TripsRepository(api).page(from: DateTime.utc(2026, 8, 1));

      final q = sentQuery();
      expect(q['from'], '2026-08-01');
      expect(q.containsKey('to'), isFalse);
    });
  });

  group('controller', () {
    late MockTripsRepo repo;

    setUp(() {
      repo = MockTripsRepo();
      when(() => repo.page(
            filter: any(named: 'filter'),
            cursor: any(named: 'cursor'),
            cancelledBy: any(named: 'cancelledBy'),
            from: any(named: 'from'),
            to: any(named: 'to'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Ok(page()));
    });

    ProviderContainer container() {
      final c = ProviderContainer(
          overrides: [tripsRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      return c;
    }

    test('narrowing to a range refetches from the server', () async {
      final c = container();
      await c.read(tripsControllerProvider.future);

      await c
          .read(tripsControllerProvider.notifier)
          .setDateRange(DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 31));

      verify(() => repo.page(
            filter: TripFilter.all,
            from: DateTime.utc(2026, 8, 1),
            to: DateTime.utc(2026, 8, 31),
          )).called(1);
    });

    test('the range survives a change of status filter', () async {
      final c = container();
      await c.read(tripsControllerProvider.future);
      final controller = c.read(tripsControllerProvider.notifier);

      await controller.setDateRange(
          DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 31));
      await controller.setFilter(TripFilter.cancelled);

      // The driver narrowed to a month and is now asking which of those
      // were cancelled - not which of all time were.
      verify(() => repo.page(
            filter: TripFilter.cancelled,
            from: DateTime.utc(2026, 8, 1),
            to: DateTime.utc(2026, 8, 31),
          )).called(1);
    });

    test('the next page keeps the range', () async {
      when(() => repo.page(
            filter: any(named: 'filter'),
            cursor: any(named: 'cursor'),
            cancelledBy: any(named: 'cancelledBy'),
            from: any(named: 'from'),
            to: any(named: 'to'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Ok(page(nextCursor: 'c2')));

      final c = container();
      await c.read(tripsControllerProvider.future);
      final controller = c.read(tripsControllerProvider.notifier);
      await controller.setDateRange(DateTime.utc(2026, 8, 1), null);
      await controller.loadMore();

      // Dropping the range on page two silently widens the list to every
      // trip the driver ever made.
      verify(() => repo.page(
            filter: TripFilter.all,
            cursor: 'c2',
            from: DateTime.utc(2026, 8, 1),
            to: null,
          )).called(1);
    });

    test('clearing the range asks for everything again', () async {
      final c = container();
      await c.read(tripsControllerProvider.future);
      final controller = c.read(tripsControllerProvider.notifier);

      await controller.setDateRange(DateTime.utc(2026, 8, 1), null);
      await controller.setDateRange(null, null);

      expect(c.read(tripsControllerProvider).value!.hasDateRange, isFalse);
      verify(() => repo.page(filter: TripFilter.all, from: null, to: null))
          .called(greaterThan(0));
    });
  });
}

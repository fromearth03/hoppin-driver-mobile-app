import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';
import 'package:hoppin_driver/features/earnings/logic/earnings_controller.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:hoppin_driver/features/trips/logic/trips_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTripsRepo extends Mock implements TripsRepository {}

class MockEarningsRepo extends Mock implements EarningsRepository {}

DriverTrip trip(String id) => DriverTrip(
      id: id,
      status: 'completed',
      pickupLabel: 'A',
      dropoffLabel: 'B',
      earnings: const Pence(100),
      penalty: const Pence(0),
    );

void main() {
  setUpAll(() => registerFallbackValue(TripFilter.all));

  test('the last filter the driver chose wins, not the last response',
      () async {
    final repo = MockTripsRepo();
    // Completed is slow, Cancelled is fast. The driver taps Completed then
    // Cancelled; without a guard the late Completed response overwrites the
    // Cancelled list the driver is already looking at.
    when(() => repo.page(
            filter: TripFilter.completed, cursor: any(named: 'cursor')))
        .thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      return Ok(TripsPage(trips: [trip('slow-completed')]));
    });
    when(() => repo.page(
            filter: TripFilter.cancelled, cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Ok(TripsPage(trips: [trip('fast-cancelled')])));
    when(() => repo.page(filter: TripFilter.all, cursor: any(named: 'cursor')))
        .thenAnswer((_) async => const Ok(TripsPage(trips: [])));

    final c = ProviderContainer(
        overrides: [tripsRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    await c.read(tripsControllerProvider.future);
    final controller = c.read(tripsControllerProvider.notifier);

    final slow = controller.setFilter(TripFilter.completed);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.setFilter(TripFilter.cancelled);
    await slow;

    final state = c.read(tripsControllerProvider).value!;
    expect(state.filter, TripFilter.cancelled);
    expect(state.trips.single.id, 'fast-cancelled');
  });

  test('the last period the driver chose wins, not the last response',
      () async {
    final repo = MockEarningsRepo();
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(
        Wallet(availableBalance: Pence(0), pendingBalance: Pence(0))));
    when(() => repo.promotions()).thenAnswer((_) async => const Ok([]));
    when(() => repo.summary('today'))
        .thenAnswer((_) async => const Ok(EarningsSummary(net: Pence(100))));
    when(() => repo.summary('week')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      return const Ok(EarningsSummary(net: Pence(700)));
    });
    when(() => repo.summary('month'))
        .thenAnswer((_) async => const Ok(EarningsSummary(net: Pence(3000))));

    final c = ProviderContainer(
        overrides: [earningsRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    await c.read(earningsControllerProvider.future);
    final controller = c.read(earningsControllerProvider.notifier);

    final slow = controller.setPeriod('week');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.setPeriod('month');
    await slow;

    // Money against a mismatched period label is the worst version of this
    // bug: the driver reads a total for a period they did not ask for.
    final state = c.read(earningsControllerProvider).value!;
    expect(state.period, 'month');
    expect(state.summary!.net.pence, 3000);
  });
}

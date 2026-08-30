import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/logic/trip_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

Ride buildRide(String status) => Ride(
      id: 'r1',
      status: status,
      geo: const RideGeo(
        pickup: GeoPoint(lat: 1, lng: 2),
        dropoff: GeoPoint(lat: 3, lng: 4),
      ),
    );

WaitingPolicy buildPolicy() => const WaitingPolicy(
      freeWaitSeconds: 180,
      perMinutePence: Pence(30),
      noShowFeePence: Pence(5900),
    );

void main() {
  late MockTripRepo repo;

  setUp(() {
    repo = MockTripRepo();
    when(() => repo.waitingPolicy(any()))
        .thenAnswer((_) async => Ok(buildPolicy()));
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      // Cancelling needs the acting driver's id; overriding the narrow
      // provider avoids standing up the whole Supabase SDK in a unit test.
      currentUserIdProvider.overrideWithValue('driver-1'),
      tripPollIntervalProvider
          .overrideWithValue(const Duration(milliseconds: 20)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('loads the ride on build', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    final c = container();
    final state = await c.read(tripControllerProvider('r1').future);

    expect(state.ride!.phase, TripPhase.headingToPickup);
  });

  test('arriving advances the phase to waiting', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));
    when(() => repo.arrive('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    await c.read(tripControllerProvider('r1').notifier).arrive();

    expect(c.read(tripControllerProvider('r1')).value!.ride!.phase,
        TripPhase.waiting);
  });

  test('ILLEGAL_TRANSITION re-reads the ride rather than guessing', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));
    when(() => repo.start('r1')).thenAnswer(
        (_) async => Err(ApiException('ILLEGAL_TRANSITION', '', 409)));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    clearInteractions(repo);
    await c.read(tripControllerProvider('r1').notifier).start();

    // The server and the app disagree about the phase; the server wins.
    verify(() => repo.ride('r1')).called(1);
  });

  test('loads the waiting policy once the driver has arrived', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    final c = container();
    final state = await c.read(tripControllerProvider('r1').future);

    expect(state.policy, isNotNull);
    expect(state.policy!.perMinutePence.pence, 30);
  });

  test('does not fetch a waiting policy before arrival', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);

    verifyNever(() => repo.waitingPolicy(any()));
  });

  test('a failed transition surfaces its error and leaves the phase alone',
      () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));
    when(() => repo.cancel(any(), reasonId: any(named: 'reasonId'), driverUserId: any(named: 'driverUserId'))).thenAnswer(
        (_) async => Err(ApiException('NO_SHOW_TOO_EARLY', '', 400,
            fields: {'seconds_remaining': 120})));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    final result = await c
        .read(tripControllerProvider('r1').notifier)
        .cancel('rider_no_show');

    expect(result.errorOrNull!.code, 'NO_SHOW_TOO_EARLY');
    expect(c.read(tripControllerProvider('r1')).value!.ride!.phase,
        TripPhase.waiting);
  });

  test('stops polling once the ride is finished', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('completed')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // One read on build and nothing after: a finished ride cannot change.
    verify(() => repo.ride('r1')).called(1);
  });

  test('a read resolving after disposal does not throw', () async {
    when(() => repo.ride('r1')).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      return Ok(buildRide('accepted'));
    });

    final c = ProviderContainer(
        overrides: [tripRepositoryProvider.overrideWithValue(repo)]);
    await c.read(tripControllerProvider('r1').future);
    final pending = c.read(tripControllerProvider('r1').notifier).refresh();
    c.dispose();

    await expectLater(pending, completes);
  });
}

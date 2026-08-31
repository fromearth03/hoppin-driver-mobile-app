import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_stop.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/logic/trip_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

class MockReasonRepo extends Mock implements CancelReasonRepository {}

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
  late MockReasonRepo reasons;

  setUp(() {
    repo = MockTripRepo();
    reasons = MockReasonRepo();
    when(() => repo.waitingPolicy(any()))
        .thenAnswer((_) async => Ok(buildPolicy()));
    // Every load reads the per-leg breakdown. These tests are single-leg
    // rides, which is exactly what an empty breakdown means.
    when(() => repo.stops(any()))
        .thenAnswer((_) async => const Ok(RideStops.empty));
    // The controller now enriches a live ride with rider-context. These
    // tests are not about the rider, so answer with the empty-handed case.
    when(() => repo.riderContext(any())).thenAnswer(
        (_) async => Err(ApiException('NOT_FOUND', 'no rider context', 404)));
    // The free-cancellation window is read off the driver's own reasons.
    when(() => reasons.forDriver()).thenAnswer((_) async => const Ok([
          CancelReason(
              id: 'vehicle_issue',
              text: 'Vehicle issue',
              pickable: true,
              freeCancelSeconds: 120),
          CancelReason(
              id: 'other',
              text: 'Other',
              pickable: true,
              freeCancelSeconds: 300),
        ]));
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      cancelReasonRepositoryProvider.overrideWithValue(reasons),
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

    final c = ProviderContainer(overrides: [
      tripRepositoryProvider.overrideWithValue(repo),
      cancelReasonRepositoryProvider.overrideWithValue(reasons),
    ]);
    await c.read(tripControllerProvider('r1').future);
    final pending = c.read(tripControllerProvider('r1').notifier).refresh();
    c.dispose();

    await expectLater(pending, completes);
  });

  group('free-cancellation window', () {
    test('takes the narrowest window any driver reason offers', () async {
      when(() => repo.ride('r1')).thenAnswer((_) async => Ok(Ride(
            id: 'r1',
            status: 'accepted',
            acceptedAt: DateTime.now().toUtc(),
            geo: const RideGeo(
              pickup: GeoPoint(lat: 1, lng: 2),
              dropoff: GeoPoint(lat: 3, lng: 4),
            ),
          )));

      final c = container();
      final state = await c.read(tripControllerProvider('r1').future);

      // 120 wins over 300: the driver has not picked a reason yet, so the
      // clock may only promise "free" for as long as that is true of every
      // reason on the table. Showing 300 would keep counting while a driver
      // choosing the 120s reason was already being charged.
      expect(state.freeCancelSeconds, 120);
      expect(state.freeCancelSecondsRemaining, greaterThan(110));
    });

    test('says nothing once the window has closed', () async {
      when(() => repo.ride('r1')).thenAnswer((_) async => Ok(Ride(
            id: 'r1',
            status: 'accepted',
            acceptedAt:
                DateTime.now().toUtc().subtract(const Duration(minutes: 30)),
            geo: const RideGeo(
              pickup: GeoPoint(lat: 1, lng: 2),
              dropoff: GeoPoint(lat: 3, lng: 4),
            ),
          )));

      final c = container();
      final state = await c.read(tripControllerProvider('r1').future);

      // Null, not zero — a countdown sitting at 00:00 would still read as
      // "free", and the service would charge them.
      expect(state.freeCancelSecondsRemaining, isNull);
    });

    test('says nothing when the ride carries no accept time', () async {
      when(() => repo.ride('r1'))
          .thenAnswer((_) async => Ok(buildRide('accepted')));

      final c = container();
      final state = await c.read(tripControllerProvider('r1').future);

      // The service anchors the grace window to accepted_at. Without it the
      // app cannot compute the window and must not invent one.
      expect(state.freeCancelSecondsRemaining, isNull);
    });

    test('a failed reason lookup costs the countdown, not the trip screen',
        () async {
      when(() => repo.ride('r1'))
          .thenAnswer((_) async => Ok(buildRide('accepted')));
      when(() => reasons.forDriver()).thenAnswer(
          (_) async => Err(ApiException('INTERNAL', 'boom', 500)));

      final c = container();
      final state = await c.read(tripControllerProvider('r1').future);

      expect(state.ride, isNotNull);
      expect(state.freeCancelSeconds, isNull);
    });
  });

  test('the rider survives the completing transition', () async {
    when(() => repo.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('in_progress')));
    when(() => repo.riderContext('r1')).thenAnswer(
        (_) async => const Ok({'id': 'u1', 'full_name': 'Alex Morgan'}));
    when(() => repo.complete('r1'))
        .thenAnswer((_) async => Ok(buildRide('completed')));

    final c = container();
    await c.read(tripControllerProvider('r1').future);
    await c.read(tripControllerProvider('r1').notifier).complete();

    // rider-context 409s RIDE_NOT_ACTIVE the moment a ride completes, so the
    // name the summary screen asks the driver to rate has to be carried
    // across the transition rather than re-read.
    expect(c.read(tripControllerProvider('r1')).value!.ride!.rider!.fullName,
        'Alex Morgan');
  });
}

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Interactor unit layer (riblet testing contract, DOCS/05): the trip
/// runner's phase mapping, guarded intents, payout-delta detection, and
/// staleness protection proven against hand-fed telemetry streams and a
/// recording repository fake. No polling, no world, no widgets.
void main() {
  test('ride status maps to phases', () {
    FakeAsync().run((async) {
      final h = _Harness();
      // The route is only reachable post-accept, so the initial state is
      // headingToPickup; the first ride emission confirms within ≤2s.
      expect(h.state.phase, TripPhase.headingToPickup);

      h.rideCtrl.add(_ride(RideStatus.accepted));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.headingToPickup);

      h.rideCtrl.add(_ride(RideStatus.arriving));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.arrivedAtPickup);

      h.rideCtrl.add(_ride(RideStatus.started));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.inTrip);

      // Unknown statuses hold the current phase — never a blank regression.
      h.rideCtrl.add(_ride(RideStatus.unknown));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.inTrip);

      h.dispose();
    });
  });

  test('ETA flows from stats and stays numeric at zero', () {
    FakeAsync().run((async) {
      final h = _Harness();
      expect(h.state.etaSeconds, isNull);

      h.statsCtrl.add(_stats(pickupEtaSeconds: 90));
      async.flushMicrotasks();
      expect(h.state.etaSeconds, 90);

      // 0 == "Arriving now" is the VIEW's rendering; the state stays 0.
      h.statsCtrl.add(_stats(pickupEtaSeconds: 0));
      async.flushMicrotasks();
      expect(h.state.etaSeconds, 0);

      h.dispose();
    });
  });

  test('arrived() guards and delegates', () {
    FakeAsync().run((async) {
      final h = _Harness();
      final gate = Completer<void>();
      h.repo.arrivedGate = gate;

      unawaited(h.interactor.arrived());
      async.flushMicrotasks();
      expect(h.repo.markArrivedCalls, 1);
      expect(h.state.busy, isTrue);

      // A second tap while the first is in flight is a no-op (busy guard).
      unawaited(h.interactor.arrived());
      async.flushMicrotasks();
      expect(h.repo.markArrivedCalls, 1);

      gate.complete();
      async.flushMicrotasks();
      expect(h.state.busy, isFalse);
      expect(h.state.phase, TripPhase.arrivedAtPickup);

      // Wrong phase now — arrived() must never fire again.
      unawaited(h.interactor.arrived());
      async.flushMicrotasks();
      expect(h.repo.markArrivedCalls, 1);

      h.dispose();
    });
  });

  test('startTrip() and complete() delegate from their phases only', () {
    FakeAsync().run((async) {
      final h = _Harness();

      // headingToPickup: neither slide intent may reach the repository.
      unawaited(h.interactor.startTrip());
      unawaited(h.interactor.complete());
      async.flushMicrotasks();
      expect(h.repo.startRideCalls, 0);
      expect(h.repo.completeRideCalls, 0);

      h.rideCtrl.add(_ride(RideStatus.arriving));
      async.flushMicrotasks();
      unawaited(h.interactor.startTrip());
      async.flushMicrotasks();
      expect(h.repo.startRideCalls, 1);
      expect(h.state.phase, TripPhase.inTrip);

      unawaited(h.interactor.complete());
      async.flushMicrotasks();
      expect(h.repo.completeRideCalls, 1);
      expect(h.state.phase, TripPhase.completed);

      // Terminal — a second complete is a no-op.
      unawaited(h.interactor.complete());
      async.flushMicrotasks();
      expect(h.repo.completeRideCalls, 1);

      h.dispose();
    });
  });

  test('intent failure surfaces a friendly error and reverts', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.repo.throwOnMarkArrived = true;

      unawaited(h.interactor.arrived());
      async.flushMicrotasks();
      expect(h.repo.markArrivedCalls, 1);
      expect(h.state.phase, TripPhase.headingToPickup);
      expect(h.state.busy, isFalse);
      expect(h.state.error, 'Something went wrong. Please try again.');

      // The retry clears the error.
      h.repo.throwOnMarkArrived = false;
      unawaited(h.interactor.arrived());
      async.flushMicrotasks();
      expect(h.state.error, isNull);
      expect(h.state.phase, TripPhase.arrivedAtPickup);

      h.dispose();
    });
  });

  test('payout detected by earnings delta', () {
    FakeAsync().run((async) {
      final h = _Harness();
      h.rideCtrl.add(_ride(RideStatus.started));
      h.statsCtrl.add(_stats(earningsPence: 4375));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.inTrip);

      unawaited(h.interactor.complete());
      async.flushMicrotasks();
      expect(h.repo.completeRideCalls, 1);

      // The completed ride WITHOUT the stats bump yet: the phase settles
      // but the sheet's number is still unknown — payout stays null.
      h.rideCtrl.add(_ride(RideStatus.completed));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.completed);
      expect(h.state.payoutPence, isNull);

      // The stats bump closes the loop: delta == the trip's payout.
      h.statsCtrl.add(_stats(earningsPence: 5014, tripCount: 6));
      async.flushMicrotasks();
      expect(h.state.phase, TripPhase.completed);
      expect(h.state.payoutPence, 639);

      h.dispose();
    });
  });

  test('stale async discarded after dispose', () {
    FakeAsync().run((async) {
      final h = _Harness();
      final gate = Completer<void>();
      h.repo.arrivedGate = gate;

      unawaited(h.interactor.arrived());
      async.flushMicrotasks();
      expect(h.repo.markArrivedCalls, 1);

      // The notifier dies while the repository call is in flight; the late
      // completion must be discarded — no state mutation, no thrown error
      // (an unhandled async error would fail this test on its own).
      h.dispose();
      gate.complete();
      async.flushMicrotasks();
    });
  });

  test('rider context lands in state', () {
    FakeAsync().run((async) {
      final h = _Harness();
      async.flushMicrotasks();
      expect(h.state.riderContext, isNotNull);
      expect(h.state.riderContext!.name, 'Sophie Bell');
      expect(h.state.riderContext!.rating, 4.8);
      expect(h.state.riderContext!.pickupLabel, 'Wolverhampton Rail Station');
      h.dispose();

      // Live mode: the capability seam answers null — view-safe null.
      final live = _Harness(riderContext: null);
      async.flushMicrotasks();
      expect(live.state.riderContext, isNull);
      live.dispose();
    });
  });
}

const String _rideId = 'ride-1';

const TripRiderContext _sophie = (
  name: 'Sophie Bell',
  photoUrl: null,
  rating: 4.8,
  ratingCount: 12,
  recentComments: ['Always on time'],
  pickupLabel: 'Wolverhampton Rail Station',
  pickupEtaSeconds: 120,
);

Ride _ride(RideStatus status) => Ride(
      id: _rideId,
      riderId: 'rider-1',
      driverId: 'driver-1',
      status: status,
    );

DriverDayStats _stats({
  bool online = true,
  int earningsPence = 4375,
  int tripCount = 5,
  Duration onlineTime = const Duration(hours: 3, minutes: 10),
  int? pickupEtaSeconds,
  String? activeRideId = _rideId,
}) =>
    (
      online: online,
      earningsPence: earningsPence,
      tripCount: tripCount,
      onlineTime: onlineTime,
      pickupEtaSeconds: pickupEtaSeconds,
      activeRideId: activeRideId,
    );

/// Injected-telemetry harness: the interactor sees ONLY overridden
/// providers and a recording repository fake.
class _Harness {
  _Harness({this.riderContext = _sophie}) {
    container = ProviderContainer(
      overrides: [
        driverRideStreamProvider.overrideWith((ref, rideId) => rideCtrl.stream),
        driverStatsProvider.overrideWith((ref) => statsCtrl.stream),
        tripRiderContextProvider.overrideWith((ref, _) async => riderContext),
        driverRepositoryProvider.overrideWithValue(repo),
      ],
    );
    // Keep the interactor actively listened (the view's ref.watch in
    // production) — Riverpod 3 pauses an unlistened provider's own
    // subscriptions, which would freeze the telemetry merge.
    _sub = container.listen(tripRunnerInteractorProvider(_rideId), (_, _) {});
  }

  final TripRiderContext? riderContext;

  late final ProviderSubscription<TripRunnerState> _sub;

  final rideCtrl = StreamController<Ride>();
  final statsCtrl = StreamController<DriverDayStats>();
  final repo = _RecordingDriverRepo();
  late final ProviderContainer container;

  TripRunnerState get state =>
      container.read(tripRunnerInteractorProvider(_rideId));

  TripRunnerInteractor get interactor =>
      container.read(tripRunnerInteractorProvider(_rideId).notifier);

  void dispose() {
    _sub.close();
    container.dispose();
    unawaited(rideCtrl.close());
    unawaited(statsCtrl.close());
  }
}

/// Records the three lifecycle intents; each can be gated (in-flight) or
/// armed to throw. Only the members the interactor touches are implemented.
class _RecordingDriverRepo implements DriverRepository {
  int markArrivedCalls = 0;
  int startRideCalls = 0;
  int completeRideCalls = 0;
  Completer<void>? arrivedGate;
  bool throwOnMarkArrived = false;

  @override
  Future<void> markArrived(String rideId) {
    markArrivedCalls++;
    if (throwOnMarkArrived) return Future.error(Exception('NOT_ASSIGNED'));
    return arrivedGate?.future ?? Future.value();
  }

  @override
  Future<void> startRide(String rideId) {
    startRideCalls++;
    return Future.value();
  }

  @override
  Future<void> completeRide(String rideId, {int? actualDistanceMeters}) {
    completeRideCalls++;
    return Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

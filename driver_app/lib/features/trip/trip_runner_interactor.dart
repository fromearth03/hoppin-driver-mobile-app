import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import '../../providers.dart';
import 'trip_runner_state.dart';

/// THE BRAIN of the trip runner riblet (DOCS/05): a per-ride state machine
/// keyed by rideId (family arg via constructor, Riverpod 3).
///
/// Telemetry flows IN via `ref.listen` on the 03-01 polling providers; taps
/// flow OUT through the repository intents. Each intent advances the phase
/// optimistically on repository success (the world is synchronous in demo)
/// and the ride stream confirms within one 2s poll tick — the status
/// mapping is monotonic so a stale snapshot can never regress the card.
///
/// No Flutter widget imports, no BuildContext, no navigation — the router
/// listens to this state and attaches the earned moment; the view renders.
class TripRunnerInteractor extends Notifier<TripRunnerState> {
  TripRunnerInteractor(this.rideId);

  /// The family argument: the ride this runner is bound to.
  final String rideId;

  /// Bumped on every user intent AND on dispose; in-flight async work from
  /// an older generation discards its result instead of clobbering fresh
  /// (or dead) state (BookingController pattern).
  int _generation = 0;

  /// The last earnings figure telemetry reported — the baseline the payout
  /// delta is measured from.
  int? _lastEarningsPence;

  /// Earnings at the moment complete() fired; non-null only while the
  /// payout confirmation is pending.
  int? _earningsBeforeComplete;

  /// True between an intentional complete() and the stats emission that
  /// carries the payout — only then is a delta credited to this trip.
  bool _completePending = false;

  @override
  TripRunnerState build() {
    _completePending = false;
    _earningsBeforeComplete = null;
    _lastEarningsPence = null;
    ref.onDispose(() => _generation++);

    // Ride status in: confirmation of the optimistic advances + the F5
    // resume truth (a fresh boot lands here mid-trip within one poll).
    ref.listen(driverRideStreamProvider(rideId), (previous, next) {
      final ride = next.value;
      if (ride == null) return;
      _onRide(ride);
    });

    // Telemetry in: pickup ETA at 1Hz + the earnings delta that closes the
    // payout loop after complete().
    ref.listen(driverStatsProvider, (previous, next) {
      final stats = next.value;
      if (stats == null) return;
      _onStats(stats);
    });

    // Rider identity in: the seeded persona in demo, null in live — the
    // view degrades to its copy fallbacks.
    ref.listen(tripRiderContextProvider(rideId), (previous, next) {
      if (!next.hasValue) return;
      state = state.copyWith(riderContext: next.value);
    });

    // The route is only reachable post-accept, so headingToPickup is the
    // honest initial phase; the first ride emission corrects within ≤2s.
    // The rider context seeds from any ALREADY-resolved value: the offer
    // takeover that navigated here watched the same one-shot provider, and
    // a resolved FutureProvider never re-emits — the listen above only
    // covers the cold-start path.
    return TripRunnerState(
      rideId: rideId,
      riderContext: ref.read(tripRiderContextProvider(rideId)).value,
    );
  }

  void _onRide(Ride ride) {
    final mapped = switch (ride.status) {
      RideStatus.accepted => TripPhase.headingToPickup,
      RideStatus.arriving => TripPhase.arrivedAtPickup,
      RideStatus.started => TripPhase.inTrip,
      RideStatus.completed => TripPhase.completed,
      // unknown / cancelled / pre-accept rows: hold the current phase —
      // the card never blanks or regresses mid-demo.
      _ => null,
    };
    if (mapped == null) return;
    // Monotonic forward only: a stale poll snapshot delivered after an
    // optimistic advance must not walk the card backwards.
    if (mapped.index <= state.phase.index) return;
    if (mapped == TripPhase.completed) _closeOut();
    state = state.copyWith(phase: mapped);
  }

  void _onStats(DriverDayStats stats) {
    var phase = state.phase;
    var payout = state.payoutPence;
    final before = _earningsBeforeComplete;
    if (_completePending && before != null && stats.earningsPence > before) {
      // The intentional complete's credit landed: the delta IS the payout.
      // (The payout is DECORATION — the phase below is already `completed` by
      // the time this runs; this branch only supplies a figure.)
      payout = stats.earningsPence - before;
      phase = TripPhase.completed;
      _completePending = false;
      _earningsBeforeComplete = null;
      _closeOut();
    }
    _lastEarningsPence = stats.earningsPence;
    state = state.copyWith(
      phase: phase,
      etaSeconds: stats.pickupEtaSeconds,
      payoutPence: payout,
    );
  }

  /// The low-stakes tap: at the pickup. Guarded to headingToPickup.
  ///
  /// On SUCCESS it stamps `arrivedAt` from `clock.now()` — the LOCAL anchor the
  /// count-up waiting clock reads. It is stamped on success (not before the
  /// call) so a rejected arrival never starts a clock; and it is `clock.now()`,
  /// never `DateTime.now()`, so `fake_async` tests drive it (PL-03).
  Future<void> arrived() => _dispatch(
        from: TripPhase.headingToPickup,
        to: TripPhase.arrivedAtPickup,
        call: (repo) => repo.markArrived(rideId),
        onSuccess: () => state = state.copyWith(arrivedAt: clock.now()),
      );

  /// The first swipe-to-confirm: rider on board, trip running.
  Future<void> startTrip() => _dispatch(
        from: TripPhase.arrivedAtPickup,
        to: TripPhase.inTrip,
        call: (repo) => repo.startRide(rideId),
      );

  /// The second swipe-to-confirm: trip done — triggers the charge. Records
  /// the pre-complete earnings so the stats listener can credit the delta
  /// as this trip's payout.
  Future<void> complete() => _dispatch(
        from: TripPhase.inTrip,
        to: TripPhase.completed,
        call: (repo) => repo.completeRide(rideId),
        beforeCall: () {
          _earningsBeforeComplete = _lastEarningsPence;
          _completePending = true;
        },
        onFailure: () {
          _earningsBeforeComplete = null;
          _completePending = false;
        },
      );

  /// THE EXIT. The driver taps Done on the completed card and the router lands
  /// them back on the dashboard.
  ///
  /// It calls NOTHING, awaits NOTHING and checks NOTHING. That is the point:
  /// the exit from a finished trip cannot depend on a repository, a seam, or a
  /// money figure, because every one of those can be absent on live — and the
  /// version of this app that gated the exit on a seam-fed figure stranded the
  /// driver on a dead screen after every trip.
  void dismiss() {
    if (state.phase != TripPhase.completed || state.dismissed) return;
    state = state.copyWith(dismissed: true);
  }

  /// Shut the door behind a finished trip.
  ///
  /// `GET /rides` is polled every 2 seconds and the server's row does not flip
  /// to `completed` the instant the driver's finger leaves the screen. Without
  /// this, the dashboard's resume redirect would see the trip still "running"
  /// and pull the driver straight back into the one they just finished — on a
  /// loop they could not escape. Called on EVERY exit from a completed trip
  /// (the Done button, and the earned sheet's own collapse), because the
  /// invariant is about the TRIP being over, not about which door was used.
  void _closeOut() =>
      ref.read(dismissedRidesProvider.notifier).add(rideId);

  /// Shared guarded intent: phase + busy guards in, generation-checked
  /// optimistic advance out; failures surface a friendly message and leave
  /// the phase untouched (nothing advanced yet, so nothing to unwind).
  Future<void> _dispatch({
    required TripPhase from,
    required TripPhase to,
    required Future<void> Function(DriverRepository repo) call,
    void Function()? beforeCall,
    void Function()? onSuccess,
    void Function()? onFailure,
  }) async {
    if (state.phase != from || state.busy) return;
    final gen = ++_generation;
    beforeCall?.call();
    state = state.copyWith(busy: true, error: null);
    try {
      await call(ref.read(driverRepositoryProvider));
      if (gen != _generation) return; // superseded, rebuilt, or disposed
      if (to == TripPhase.completed) _closeOut();
      state = state.copyWith(busy: false, phase: to);
      // AFTER the phase advance, on the confirmed intent only — a rejected
      // arrival never stamps a clock (the catch below is where a failure lands).
      onSuccess?.call();
    } on Exception catch (e) {
      onFailure?.call();
      if (gen != _generation) return;
      state = state.copyWith(busy: false, error: friendlyErrorMessage(e));
    }
  }
}

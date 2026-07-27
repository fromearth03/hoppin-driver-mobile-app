import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// App-level data providers shared by several driver screens.
/// (Feature-local providers live next to their feature.)
///
/// Everything here is mode-blind: each provider polls ONLY the repository
/// interfaces, so the demo substitution stays at the root override list and
/// no consumer ever learns which world it is talking to. Polling is the
/// interim transport; push (FCM) / SSE replaces it when the backend
/// notification work lands.

/// Disposal-aware pause between poll ticks. `Future.delayed` inside an
/// `async*` poll loop strands a pending timer when the provider disposes
/// mid-wait — widget tests that end with a polling screen still mounted
/// (the dashboard riblet lives at '/') trip the pending-timer invariant on
/// teardown. This waits on a real [Timer] the provider's disposal cancels
/// immediately; after disposal the future never completes, so the cancelled
/// generator parks at the `await` and makes no further repository calls.
class _PollDelay {
  _PollDelay(Ref ref) {
    ref.onDispose(_cancel);
  }

  Timer? _timer;

  Future<void> call(Duration duration) {
    final completer = Completer<void>();
    _timer = Timer(duration, completer.complete);
    return completer.future;
  }

  void _cancel() => _timer?.cancel();
}

/// Today's telemetry — earnings, trips, online time, live-trip ETA. Polls
/// `todayStats()` every 1s because the online clock and the pickup ETA tick
/// visibly at 1Hz on the dashboard. The live capability seam answers null
/// (no telemetry endpoint yet), in which case this stream simply never
/// emits and consuming views degrade gracefully.
final driverStatsProvider =
    StreamProvider.autoDispose<DriverDayStats>((ref) async* {
  final repo = ref.watch(driverRepositoryProvider);
  final pause = _PollDelay(ref);
  while (true) {
    try {
      final stats = await repo.todayStats();
      if (stats != null) yield stats;
    } on Exception {
      // Transient failure — keep the last shown state and retry.
    }
    await pause(const Duration(seconds: 1));
  }
});

/// Pending ride offers — `GET /drivers/me/offers`. Polls every 1s so the
/// offer takeover's entrance feels immediate; the world's own pacing
/// (arrival, decline, re-offer) carries the demo beats.
final pendingOffersProvider =
    StreamProvider.autoDispose<List<RideOffer>>((ref) async* {
  final repo = ref.watch(driverRepositoryProvider);
  final pause = _PollDelay(ref);
  while (true) {
    try {
      yield await repo.offers();
    } on Exception {
      // Transient failure — keep the last shown state and retry.
    }
    await pause(const Duration(seconds: 1));
  }
});

/// Who the rider is and where pickup is — one-shot capability seam for the
/// offer takeover and the trip-runner context row. Family key is the rideId.
/// On live the endpoint returns null when the caller is not the assigned driver.
final tripRiderContextProvider =
    FutureProvider.autoDispose.family<TripRiderContext?, String>(
  (ref, rideId) =>
      ref.watch(driverRepositoryProvider).tripRiderContext(rideId),
);

/// The ride THIS DRIVER IS RUNNING, or null — the BOUND source of the
/// trip-resume redirect. `GET /rides` is scoped to the caller.
///
/// 🔴 THIS MUST NEVER COME FROM A CAPABILITY SEAM. It used to be read off
/// `todayStats().activeRideId` (#7), which answers null on every live request
/// — so the redirect never fired and a driver who refreshed mid-trip was
/// dumped on the dashboard with no way back into a trip the server still had
/// running. Navigation state is sourced from a BOUND read or it is not sourced
/// at all: a capability seam may only feed DECORATION.
///
/// 🔴 "ACCEPTED BY ME" — NOT MERELY "NOT FINISHED". [RideStatusX.isActive] is
/// true for `requested` and `matching` too, and a ride in those states is a
/// ride being OFFERED, not a ride being DRIVEN. Redirecting on it would rip the
/// driver into the trip runner while the offer takeover is still on screen —
/// they would find themselves inside a trip they never accepted. The
/// post-accept statuses below are the ones a driver actually owns.
///
/// 🔴 NOT autoDispose, deliberately. The dashboard router redirects on a CHANGE
/// of `activeRideId`, so this stream's continuity IS the guard against
/// re-redirecting. An autoDispose provider dies when the driver leaves the
/// dashboard for the trip runner and REBUILDS on their return — re-emitting the
/// same ride as a brand-new value against a null `previous`, which fires the
/// redirect again and bounces the driver straight back into the trip they just
/// finished. The active ride is a whole-session fact, like presence.
final activeRideProvider = StreamProvider<Ride?>((ref) async* {
  final repo = ref.watch(ridesRepositoryProvider);
  final pause = _PollDelay(ref);
  while (true) {
    try {
      final rides = await repo.history(limit: 10);
      Ride? running;
      for (final ride in rides) {
        if (_isRunningByDriver(ride)) {
          running = ride;
          break;
        }
      }
      yield running;
    } on Exception {
      // Transient failure — keep the last shown state and retry. A failed read
      // is IGNORANCE, never "no active trip": emitting null here would strand
      // the driver exactly as the null seam did.
    }
    await pause(const Duration(seconds: 2));
  }
});

/// A ride this driver has ACCEPTED and is now running — the only thing the
/// trip-resume redirect may act on.
bool _isRunningByDriver(Ride ride) => switch (ride.status) {
      RideStatus.accepted ||
      RideStatus.arriving ||
      RideStatus.started =>
        true,
      // requested / matching / assigned: dispatch is still deciding, and an
      // offer on screen is not a trip in progress.
      // completed / cancelled / unknown: over, or unknowable.
      _ => false,
    };

/// Rides the driver has explicitly WALKED AWAY FROM (they tapped Done on the
/// completed card). The trip-resume redirect must never pull them back in.
///
/// 🔴 THIS IS NOT BOOKKEEPING — IT IS THE EXIT STAYING SHUT. `GET /rides` is
/// polled on a 2-second cadence and the server's own row does not flip to
/// `completed` the instant the driver's finger leaves the screen. So for a
/// window after Done, the BOUND read still legitimately reports the trip as
/// running — and without this set the dashboard would redirect the driver
/// straight back into the trip they just finished, on a loop they could not
/// escape. A driver who has left a trip has left it.
///
/// Session-scoped and deliberately not persisted: it guards a navigation
/// decision, not a fact about the world.
final dismissedRidesProvider =
    NotifierProvider<DismissedRides, Set<String>>(DismissedRides.new);

/// The set behind [dismissedRidesProvider].
class DismissedRides extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Records that the driver has finished with [rideId] and left its screen.
  void add(String rideId) {
    if (state.contains(rideId)) return;
    state = {...state, rideId};
  }
}

/// Live view of one ride — polls `GET /rides/:id` every 2s until the ride
/// reaches a terminal state, then stops. Driver taps drive the transitions;
/// the poll is confirmation plus F5 resume.
final driverRideStreamProvider =
    StreamProvider.autoDispose.family<Ride, String>((ref, rideId) async* {
  final repo = ref.watch(ridesRepositoryProvider);
  final pause = _PollDelay(ref);
  while (true) {
    try {
      final ride = await repo.getRide(rideId);
      yield ride;
      if (ride.status.isTerminal) return;
    } on Exception {
      // Transient failure — keep the last shown state and retry.
    }
    await pause(const Duration(seconds: 2));
  }
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/geo/place_labeler.dart';
import '../../../core/money.dart';
import '../../../core/result.dart';
import '../data/cancel_reason_repository.dart';
import '../data/models/ride.dart';
import '../data/models/ride_stop.dart';
import '../data/models/waiting_policy.dart';
import '../data/trip_repository.dart';

class TripState {
  final Ride? ride;
  final WaitingPolicy? policy;
  final bool isBusy;
  final ApiException? error;

  /// The per-leg breakdown. [RideStops.empty] on an ordinary single-leg
  /// ride, which is also what a failed read falls back to — the trip screen
  /// must keep working when the stops call is the only thing that broke.
  final RideStops stops;

  /// The widest free-cancellation window any driver reason offers, in
  /// seconds. Read from `free_cancel_seconds` on `/cancellation-reasons`
  /// rather than assumed: it is admin configuration, and `gracedPenalty`
  /// waives the fee against exactly this number.
  final int? freeCancelSeconds;

  const TripState({
    this.ride,
    this.policy,
    this.isBusy = false,
    this.error,
    this.freeCancelSeconds,
    this.stops = RideStops.empty,
  });

  TripState copyWith({
    Ride? ride,
    WaitingPolicy? policy,
    bool? isBusy,
    ApiException? error,
    int? freeCancelSeconds,
    RideStops? stops,
    bool clearError = false,
    bool clearPolicy = false,
  }) =>
      TripState(
        ride: ride ?? this.ride,
        policy: clearPolicy ? null : (policy ?? this.policy),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
        freeCancelSeconds: freeCancelSeconds ?? this.freeCancelSeconds,
        stops: stops ?? this.stops,
      );

  TripPhase get phase => ride?.phase ?? TripPhase.headingToPickup;

  /// Seconds left before a driver cancellation starts carrying a charge.
  ///
  /// The service anchors a `driver_cancel` grace window to `accepted_at`
  /// (`gracedPenalty` compares `time.Since(anchor)` against
  /// `free_cancel_seconds`), so both halves must be known — null means we
  /// cannot say, and the UI shows nothing rather than a guess. Null once the
  /// window has closed, so a countdown never sits at 00:00 implying free.
  int? get freeCancelSecondsRemaining {
    final accepted = ride?.acceptedAt;
    final window = freeCancelSeconds;
    if (accepted == null || window == null || window <= 0) return null;
    final left = accepted
        .toUtc()
        .add(Duration(seconds: window))
        .difference(DateTime.now().toUtc())
        .inSeconds;
    return left > 0 ? left : null;
  }
}

/// Slower than the offer poll: a trip in progress changes on the driver's own
/// actions, and the only external event worth catching is a rider or admin
/// cancelling underneath them.
final tripPollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 10));

/// Owns one ride. The phase is always derived from the server's `status`,
/// never advanced locally, so a cancellation made elsewhere lands correctly.
class TripController extends FamilyAsyncNotifier<TripState, String> {
  Timer? _timer;
  bool _disposed = false;

  TripRepository get _repo => ref.read(tripRepositoryProvider);

  @override
  Future<TripState> build(String rideId) async {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });

    final result = await _repo.ride(rideId);
    final loaded = await result.when(
      ok: (ride) async => TripState(
        ride: await _withRider(ride),
        policy: await _policyFor(ride),
        freeCancelSeconds: await _freeCancelWindow(ride),
        stops: await _stopsFor(ride),
      ),
      err: (e) async => TripState(error: e),
    );
    if (!(loaded.ride?.isFinished ?? true)) _startPolling();
    return loaded;
  }

  /// The grace window a driver cancellation gets before it costs them.
  ///
  /// Reasons are admin-configured and each carries its own
  /// `free_cancel_seconds`, and the driver has not picked one yet when this
  /// countdown is on screen. The NARROWEST window is therefore the only
  /// honest one: showing the widest would leave the clock still running while
  /// a driver who picks a shorter-windowed reason is already being charged.
  /// Under-promising costs them nothing; over-promising costs them money.
  ///
  /// A reason with no window configured is excluded rather than treated as
  /// zero — null there means "no grace configured for this reason", which is
  /// not the same as "the grace has run out".
  ///
  /// Best-effort: a failed lookup means no countdown, never a broken trip
  /// screen. The driver can still cancel; they just do it without the clock.
  Future<int?> _freeCancelWindow(Ride ride) async {
    if (ride.isFinished) return null;
    final result = await ref.read(cancelReasonRepositoryProvider).forDriver();
    final reasons = result.valueOrNull;
    if (reasons == null) return null;
    final windows = reasons
        .map((r) => r.freeCancelSeconds)
        .whereType<int>()
        .where((s) => s > 0);
    if (windows.isEmpty) return null;
    return windows.reduce((a, b) => a < b ? a : b);
  }

  TripState get _current => state.value ?? const TripState();

  void _emit(TripState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  /// Attaches the rider, whose identity `GET /rides/:id` does not carry at
  /// all — it lives only on `/rides/:id/rider-context`.
  ///
  /// Best-effort on purpose: the context 409s once the ride reaches a
  /// terminal state, and losing the rider's name must never cost the driver
  /// the trip screen and its Arrive/Start/Complete actions.
  Future<Ride> _withRider(Ride ride) async {
    if (ride.isFinished) return ride;
    final result = await _repo.riderContext(ride.id);
    final json = result.valueOrNull;
    if (json == null) return ride;
    return ride.withRider(Rider.fromJson(json));
  }

  /// The waiting terms only exist once the driver has marked arrival, so
  /// asking earlier would be a guaranteed 404 on every trip.
  Future<WaitingPolicy?> _policyFor(Ride ride) async {
    if (ride.phase != TripPhase.waiting) return null;
    final result = await _repo.waitingPolicy(ride.id);
    return result.valueOrNull;
  }

  /// The per-leg breakdown.
  ///
  /// Best-effort like the rider and the policy: a multi-stop trip whose
  /// breakdown fails to load still has to show Arrive/Start/Finish, so a
  /// failure degrades to the single-leg view rather than taking the screen.
  Future<RideStops> _stopsFor(Ride ride) async {
    final result = await _repo.stops(ride.id);
    final stops = result.valueOrNull ?? RideStops.empty;
    if (stops.stops.every((s) => s.label.isNotEmpty)) return stops;
    // Rider-created stops arrive as bare coordinates; "Stop 1" tells the
    // driver nothing about where they are going. Label them on-device —
    // cached, so the 3s poll costs no repeat lookups.
    final labeler = ref.read(placeLabelerProvider);
    final labelled = <RideStop>[];
    for (final s in stops.stops) {
      if (s.label.isNotEmpty) {
        labelled.add(s);
      } else {
        final label = await labeler.label(s.to.lat, s.to.lng);
        labelled.add(label.isEmpty ? s : s.withLabel(label));
      }
    }
    return RideStops(
      multiStop: stops.multiStop,
      stops: labelled,
      legsTotal: stops.legsTotal,
      waitingTotal: stops.waitingTotal,
      total: stops.total,
    );
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(tripPollIntervalProvider), (_) {
      if (_current.ride?.isFinished ?? false) {
        _timer?.cancel();
        return;
      }
      refresh();
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final result = await _repo.ride(arg);
    if (_disposed) return;
    await result.when(
      ok: (ride) async {
        final waiting = ride.phase == TripPhase.waiting;
        final policy =
            waiting ? (_current.policy ?? await _policyFor(ride)) : null;
        if (_disposed) return;
        // The rider does not change mid-trip, so carry the one already
        // loaded rather than spending a request on every poll.
        final withRider = _current.ride?.rider != null
            ? ride.withRider(_current.ride!.rider)
            : await _withRider(ride);
        if (_disposed) return;
        // Re-read on every poll: the rider can add a stop mid-trip, and the
        // waiting clock the sheet prints is the server's, not ours.
        final stops = await _stopsFor(ride);
        if (_disposed) return;
        _emit(_current.copyWith(
          ride: withRider,
          policy: policy,
          stops: stops,
          clearPolicy: !waiting,
          clearError: true,
        ));
        if (ride.isFinished) _timer?.cancel();
      },
      err: (e) async => _emit(_current.copyWith(error: e)),
    );
  }

  Future<Result<Ride>> arrive() => _transition(() => _repo.arrive(arg));
  Future<Result<Ride>> start() => _transition(() => _repo.start(arg));
  Future<Result<Ride>> complete() => _transition(() => _repo.complete(arg));

  /// Marks arrival at stop [seq], starting the server's wait clock.
  ///
  /// The breakdown is re-read rather than patched locally: `arrived_at` is
  /// stamped with the database's `now()`, and a clock started from the
  /// handset's idea of the time would drift against the money.
  Future<Result<void>> arriveAtStop(int seq) =>
      _stopAction(() => _repo.arriveAtStop(arg, seq));

  /// Marks departure from stop [seq]. Returns the wait charged there, which
  /// is zero inside the free grace.
  Future<Result<Pence>> departStop(int seq) async {
    final ride = _current.ride;
    if (ride == null) {
      return Err(ApiException('NOT_READY', 'no ride loaded', 0));
    }
    _emit(_current.copyWith(isBusy: true, clearError: true));
    final result = await _repo.departStop(ride.id, seq);
    if (_disposed) return result;
    await _settleStopAction(result.isOk ? null : result.errorOrNull);
    return result;
  }

  /// Adds a stop to the live ride and re-prices every leg.
  ///
  /// The service pushes "Stop added" to the driver whoever called it, so a
  /// driver adding their own stop will also see a notification about it.
  Future<Result<AddedStop>> addStop({
    required double lat,
    required double lng,
    required String label,
  }) async {
    final ride = _current.ride;
    if (ride == null) {
      return Err(ApiException('NOT_READY', 'no ride loaded', 0));
    }
    _emit(_current.copyWith(isBusy: true, clearError: true));
    final result =
        await _repo.addStop(ride.id, lat: lat, lng: lng, label: label);
    if (_disposed) return result;
    await _settleStopAction(result.isOk ? null : result.errorOrNull);
    return result;
  }

  Future<Result<void>> _stopAction(Future<Result<void>> Function() call) async {
    if (_current.ride == null) {
      return Err(ApiException('NOT_READY', 'no ride loaded', 0));
    }
    _emit(_current.copyWith(isBusy: true, clearError: true));
    final result = await call();
    if (_disposed) return result;
    await _settleStopAction(result.isOk ? null : result.errorOrNull);
    return result;
  }

  /// Clears the busy flag and re-reads the breakdown, so the times and the
  /// money on screen are the server's after every stop action.
  ///
  /// The stops read is deliberately not gated on success: a failed depart
  /// may still have moved the row, and a stale breakdown is the one thing
  /// that would misreport what the driver earned.
  Future<void> _settleStopAction(ApiException? error) async {
    final ride = _current.ride;
    final stops = ride == null ? RideStops.empty : await _stopsFor(ride);
    if (_disposed) return;
    _emit(_current.copyWith(
      isBusy: false,
      stops: stops,
      error: error,
      clearError: error == null,
    ));
  }

  Future<Result<Ride>> cancel(String? reasonId) {
    // The handler requires the acting user's id. It comes from the live
    // Supabase session rather than being passed down from the UI, so a
    // screen cannot forget it and turn every cancellation into a 400.
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      return Future.value(
          Err(ApiException('AUTH_FAILED', 'no signed-in driver', 0)));
    }
    return _transition(
        () => _repo.cancel(arg, reasonId: reasonId, driverUserId: userId));
  }

  Future<Result<Ride>> _transition(Future<Result<Ride>> Function() call) async {
    _emit(_current.copyWith(isBusy: true, clearError: true));
    final result = await call();
    if (_disposed) return result;

    await result.when(
      ok: (ride) async {
        final policy = await _policyFor(ride);
        if (_disposed) return;
        // The rider is carried across the transition rather than re-read.
        // `/rides/:id/rider-context` 409s RIDE_NOT_ACTIVE the instant a ride
        // completes, so asking again after Finish Trip loses the name the
        // summary screen is about to ask the driver to rate.
        _emit(_current.copyWith(
          ride: ride.withRider(_current.ride?.rider),
          isBusy: false,
          policy: policy,
          clearPolicy: policy == null,
        ));
        if (ride.isFinished) _timer?.cancel();
      },
      err: (e) async {
        _emit(_current.copyWith(isBusy: false, error: e));
        // The app thought the ride was in a state it was not. Re-reading is
        // the only honest recovery — guessing the real phase would be
        // guessing about a job in progress.
        if (e.code == 'ILLEGAL_TRANSITION') await refresh();
      },
    );
    return result;
  }
}

final tripControllerProvider =
    AsyncNotifierProvider.family<TripController, TripState, String>(
        TripController.new);

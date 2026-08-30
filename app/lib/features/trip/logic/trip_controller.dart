import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/result.dart';
import '../data/models/ride.dart';
import '../data/models/waiting_policy.dart';
import '../data/trip_repository.dart';

class TripState {
  final Ride? ride;
  final WaitingPolicy? policy;
  final bool isBusy;
  final ApiException? error;

  const TripState({this.ride, this.policy, this.isBusy = false, this.error});

  TripState copyWith({
    Ride? ride,
    WaitingPolicy? policy,
    bool? isBusy,
    ApiException? error,
    bool clearError = false,
    bool clearPolicy = false,
  }) =>
      TripState(
        ride: ride ?? this.ride,
        policy: clearPolicy ? null : (policy ?? this.policy),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );

  TripPhase get phase => ride?.phase ?? TripPhase.headingToPickup;
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
      ok: (ride) async => TripState(ride: ride, policy: await _policyFor(ride)),
      err: (e) async => TripState(error: e),
    );
    if (!(loaded.ride?.isFinished ?? true)) _startPolling();
    return loaded;
  }

  TripState get _current => state.value ?? const TripState();

  void _emit(TripState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  /// The waiting terms only exist once the driver has marked arrival, so
  /// asking earlier would be a guaranteed 404 on every trip.
  Future<WaitingPolicy?> _policyFor(Ride ride) async {
    if (ride.phase != TripPhase.waiting) return null;
    final result = await _repo.waitingPolicy(ride.id);
    return result.valueOrNull;
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
        _emit(_current.copyWith(
          ride: ride,
          policy: policy,
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

  Future<Result<Ride>> cancel(String reasonId) {
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
        _emit(_current.copyWith(
          ride: ride,
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

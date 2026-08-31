import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/result.dart';
import 'models/ride.dart';
import 'models/waiting_policy.dart';

class TripRepository {
  final ApiClient _api;
  TripRepository(this._api);

  Future<Result<Ride>> ride(String rideId) =>
      _rideCall(() => _api.get<Map<String, dynamic>>('/rides/$rideId'));

  Future<Result<Ride>> arrive(String rideId) =>
      _transition(rideId, '/rides/$rideId/arrive');

  Future<Result<Ride>> start(String rideId) =>
      _transition(rideId, '/rides/$rideId/start');

  Future<Result<Ride>> complete(String rideId) =>
      _transition(rideId, '/rides/$rideId/complete');

  /// `reasonId` comes from the picker, which only ever offers entries the
  /// server marked `pickable: true`.
  ///
  /// `canceled_by_user_id` and `actor_type` are `binding:"required"` on the
  /// handler, so omitting them fails validation before the ride is even
  /// looked at and every cancellation returns 400.
  Future<Result<Ride>> cancel(
    String rideId, {
    required String reasonId,
    required String driverUserId,
  }) =>
      _transition(rideId, '/rides/$rideId/cancel', body: {
        'reason_id': reasonId,
        'canceled_by_user_id': driverUserId,
        'actor_type': 'driver',
      });

  /// The lifecycle endpoints acknowledge with `{"message": ...}` rather than
  /// returning the ride, so the updated ride is re-read afterwards. Parsing
  /// that acknowledgement as a ride throws on a *successful* transition,
  /// which is how a working arrive/start/complete looked like a crash.
  Future<Result<Ride>> _transition(String rideId, String path,
      {Map<String, dynamic>? body}) async {
    final result = await _api.patch<Map<String, dynamic>>(path, body: body);
    if (!result.isOk) return Err(result.errorOrNull!);
    return ride(rideId);
  }

  Future<Result<WaitingPolicy>> waitingPolicy(String rideId) async {
    final r =
        await _api.get<Map<String, dynamic>>('/rides/$rideId/waiting-policy');
    return r.when(
      ok: (json) => Ok(WaitingPolicy.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  Future<Result<Map<String, dynamic>>> riderContext(String rideId) =>
      _api.get<Map<String, dynamic>>('/rides/$rideId/rider-context');

  /// Rates the passenger on a completed ride.
  ///
  /// `score` is 1–5 and `binding:"required"` — the handler rejects 0, so a
  /// caller must never send an unrated trip. `comments` is the only other
  /// field `rateRideBody` carries: the design's quick-tag chips (Clean,
  /// Polite, Quiet, Ready on Time) have nowhere to go, and the handler would
  /// drop them silently.
  Future<Result<void>> rate(String rideId,
      {required int score, String? comments}) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/rating',
      body: {
        'score': score,
        if (comments != null && comments.trim().isNotEmpty)
          'comments': comments.trim(),
      },
    );
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  Future<Result<Ride>> _rideCall(
      Future<Result<Map<String, dynamic>>> Function() call) async {
    final r = await call();
    return r.when(
      ok: (json) => Ok(Ride.fromJson(json)),
      err: (e) => Err(e),
    );
  }
}

final tripRepositoryProvider = Provider<TripRepository>(
    (ref) => TripRepository(ref.watch(apiClientProvider)));

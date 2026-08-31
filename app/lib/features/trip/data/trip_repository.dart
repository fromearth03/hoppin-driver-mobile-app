import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/money.dart';
import '../../../core/result.dart';
import 'models/ride.dart';
import 'models/ride_stop.dart';
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

  /// The per-leg breakdown of a multi-stop ride.
  ///
  /// Returns `multi_stop:false` with an empty list for an ordinary ride, so
  /// this is safe to call on every trip and needs no guard at the call site.
  Future<Result<RideStops>> stops(String rideId) async {
    final r = await _api.get<Map<String, dynamic>>('/rides/$rideId/stops');
    return r.when(
      ok: (json) => Ok(RideStops.fromJson(json)),
      err: (e) => Err(e),
    );
  }

  /// Marks arrival at stop [seq], starting that stop's wait clock.
  ///
  /// [seq] is the leg index whose destination is the stop, taken from
  /// [stops] — not a position in the list, which differs once the dropoff
  /// leg is filtered out.
  ///
  /// The repository updates only rows with `kind = 'stop'`, so calling this
  /// for the dropoff leg is a no-op that still answers 200.
  Future<Result<void>> arriveAtStop(String rideId, int seq) async {
    final r = await _api
        .patch<Map<String, dynamic>>('/rides/$rideId/stops/$seq/arrive');
    return r.when(ok: (_) => const Ok(null), err: (e) => Err(e));
  }

  /// Marks departure from stop [seq] and returns the wait charged there,
  /// which is zero inside the free grace.
  ///
  /// The grace and the per-minute rate are columns in `multistop_config`
  /// with no endpoint in front of them, so this returned figure is the only
  /// waiting number the app can honestly show.
  Future<Result<Pence>> departStop(String rideId, int seq) async {
    final r = await _api
        .patch<Map<String, dynamic>>('/rides/$rideId/stops/$seq/depart');
    return r.when(
      ok: (json) => Ok(Pence((json['waiting_pence'] as num?)?.toInt() ?? 0)),
      err: (e) => Err(e),
    );
  }

  /// Adds a stop to a live ride. Every leg is re-priced and the new grand
  /// total comes back.
  ///
  /// The handler rejects a zero lat or lng as VALIDATION_FAILED (it treats
  /// 0 as absent), and answers 409 RIDE_CLOSED once the ride has finished.
  Future<Result<AddedStop>> addStop(
    String rideId, {
    required double lat,
    required double lng,
    required String label,
  }) async {
    final r = await _api.post<Map<String, dynamic>>(
      '/rides/$rideId/stops',
      body: {'lat': lat, 'lng': lng, 'label': label},
    );
    return r.when(
      ok: (json) => Ok(AddedStop(
        total: Pence((json['total_pence'] as num?)?.toInt() ?? 0),
        stopsCount: (json['stops_count'] as num?)?.toInt() ?? 0,
      )),
      err: (e) => Err(e),
    );
  }

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

/// What `POST /rides/:id/stops` answers with: the re-priced grand total and
/// how many stops the ride now has.
class AddedStop {
  final Pence total;
  final int stopsCount;

  const AddedStop({required this.total, required this.stopsCount});
}

final tripRepositoryProvider = Provider<TripRepository>(
    (ref) => TripRepository(ref.watch(apiClientProvider)));

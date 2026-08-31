import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../earnings/data/earnings_repository.dart';
import '../../earnings/data/models/ride_earnings.dart';
import '../../trip/data/models/ride.dart';
import '../../trip/data/trip_repository.dart';

class TripDetailState {
  final RideEarnings? earnings;

  /// The trip's geometry from `GET /rides/:id`, which serves finished rides
  /// too. Null when the read failed — the screen just omits the map; a past
  /// trip's addresses and money must not be held hostage to a map read.
  final RideGeo? geo;
  final ApiException? error;

  const TripDetailState({this.earnings, this.geo, this.error});
}

/// The earnings breakdown for one past trip.
///
/// Keyed by ride id: a driver scrolling their history opens several, and each
/// keeps its own result rather than the last one overwriting the rest.
class TripDetailController
    extends FamilyAsyncNotifier<TripDetailState, String> {
  @override
  Future<TripDetailState> build(String rideId) async {
    final (result, rideResult) = await (
      ref.read(earningsRepositoryProvider).rideEarnings(rideId),
      ref.read(tripRepositoryProvider).ride(rideId),
    ).wait;
    final geo = rideResult.valueOrNull?.geo;
    return result.when(
      ok: (earnings) => TripDetailState(earnings: earnings, geo: geo),
      // A trip that never settled has no breakdown. That is a real answer,
      // not a crash, and the screen says so rather than showing zeroes.
      err: (e) => TripDetailState(geo: geo, error: e),
    );
  }
}

final tripDetailControllerProvider = AsyncNotifierProvider.family<
    TripDetailController, TripDetailState, String>(TripDetailController.new);

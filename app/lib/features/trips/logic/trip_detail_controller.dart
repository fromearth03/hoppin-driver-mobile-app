import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../earnings/data/earnings_repository.dart';
import '../../earnings/data/models/ride_earnings.dart';

class TripDetailState {
  final RideEarnings? earnings;
  final ApiException? error;

  const TripDetailState({this.earnings, this.error});
}

/// The earnings breakdown for one past trip.
///
/// Keyed by ride id: a driver scrolling their history opens several, and each
/// keeps its own result rather than the last one overwriting the rest.
class TripDetailController
    extends FamilyAsyncNotifier<TripDetailState, String> {
  @override
  Future<TripDetailState> build(String rideId) async {
    final result =
        await ref.read(earningsRepositoryProvider).rideEarnings(rideId);
    return result.when(
      ok: (earnings) => TripDetailState(earnings: earnings),
      // A trip that never settled has no breakdown. That is a real answer,
      // not a crash, and the screen says so rather than showing zeroes.
      err: (e) => TripDetailState(error: e),
    );
  }
}

final tripDetailControllerProvider = AsyncNotifierProvider.family<
    TripDetailController, TripDetailState, String>(TripDetailController.new);

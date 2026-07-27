import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'rider_rating_state.dart';

/// The driver rates the rider. `POST /rides/:id/rating` is `[either]`, has been
/// BOUND since the API client was written, and has had ZERO DRIVER UI — a pure
/// missing-frontend loss, and the rider has been rating the driver all along.
///
/// 🔴 IT IS NOT REACHABLE IN MOTION (OT-14). Completion happens at the dropoff,
/// where the car is stopped — but a driver can swipe complete while already
/// rolling away, and a five-star picker with an optional comment is exactly the
/// sustained-attention interaction that "driving without due care" is about.
///
/// Note the asymmetry with the rest of this phase, and it is deliberate: the
/// Chat button, the Call button and Arrived STAY LIVE at speed, because a
/// cradled one-tap is legal and glanceable and it is how the job gets done. A
/// rating sheet is neither. The line is not "no touching" — it is GLANCEABILITY.
///
/// 🔴 AND IT NEVER GATES THE EXIT. The completed trip's Done affordance depends
/// on nothing — not a payout figure (that bug shipped, and stranded a driver on
/// a dead card after every single trip), and not a rating. Skipping is normal.
/// The sheet is offered; it is never a toll gate.
class RiderRatingInteractor extends Notifier<RiderRatingState> {
  RiderRatingInteractor(this.rideId);

  /// The completed ride being rated — the family key.
  final String rideId;

  @override
  RiderRatingState build() => const RiderRatingState();

  /// Records the picked score. Ignored mid-submit.
  void setScore(int score) {
    if (state.busy) return;
    state = state.copyWith(score: score, error: () => null);
  }

  /// Submits the picked score; true on success. A failure surfaces as
  /// display-ready copy on [RiderRatingState.error] and 🔴 NEVER traps the
  /// driver — the sheet's Skip exit stays live throughout.
  Future<bool> submit({String? comments}) async {
    if (state.busy) return false;
    if (state.score < 1) {
      state = state.copyWith(error: () => 'Pick a star rating first.');
      return false;
    }
    state = state.copyWith(busy: true, error: () => null);
    final trimmed = comments?.trim();
    try {
      await ref.read(ridesRepositoryProvider).rate(
            rideId: rideId,
            score: state.score,
            comments: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          );
      if (!ref.mounted) return true;
      state = state.copyWith(busy: false);
      return true;
    } on Exception catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(busy: false, error: () => friendlyErrorMessage(e));
      return false;
    }
  }
}

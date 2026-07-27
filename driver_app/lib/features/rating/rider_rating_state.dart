import 'package:flutter/foundation.dart';

/// Immutable state for one rider-rating flow — the driver rating the rider
/// after a completed trip.
@immutable
class RiderRatingState {
  const RiderRatingState({this.score = 0, this.busy = false, this.error});

  /// 1-5 once picked; 0 = nothing selected yet.
  final int score;

  /// True while the submit call is in flight.
  final bool busy;

  /// Display-ready validation/submit failure, if any.
  final String? error;

  RiderRatingState copyWith({
    int? score,
    bool? busy,
    String? Function()? error,
  }) =>
      RiderRatingState(
        score: score ?? this.score,
        busy: busy ?? this.busy,
        error: error == null ? this.error : error(),
      );
}

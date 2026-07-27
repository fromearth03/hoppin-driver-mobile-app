import 'package:flutter/foundation.dart';

/// Where the 'You earned' sheet is in its fixed choreography. The timeline
/// self-advances (check pop → count-up → collapse) — the presenter never
/// has to touch it, and a tap skips straight to done.
enum EarnedPhase {
  /// The success check pops in (~400ms); the odometer still reads £0.00.
  checkPop,

  /// The £0.00 → £x.xx count-up runs (~900ms) and holds (~500ms).
  countUp,

  /// Finished — the router collapses the sheet and hands the number to
  /// the dashboard tile.
  done,
}

/// Immutable snapshot of the earned moment.
///
/// It holds ONLY the phase. The payout figure is NOT here on purpose: it is
/// DECORATION, it may arrive late, and it may never arrive at all — so the view
/// watches it live off the trip runner rather than freezing it at attach time.
/// Freezing it at attach was what forced the old design to WAIT for a figure
/// before opening the sheet, and waiting for a figure that never comes is what
/// stranded the driver on a dead card after every live trip.
@immutable
class EarnedMomentState {
  const EarnedMomentState({this.phase = EarnedPhase.checkPop});

  final EarnedPhase phase;

  EarnedMomentState copyWith({EarnedPhase? phase}) =>
      EarnedMomentState(phase: phase ?? this.phase);
}

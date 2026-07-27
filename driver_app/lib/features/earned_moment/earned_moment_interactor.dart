import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'earned_moment_state.dart';

/// THE BRAIN of the earned-moment riblet (DOCS/05): a tiny self-advancing
/// timeline keyed by rideId (family arg via constructor, Riverpod 3).
///
/// Beats: check pop (400ms) → count-up (900ms) + hold (200ms) → done —
/// 1.5s total (§5 'Success moment': the whole moment stays ≤1.5s, then
/// auto-advances), comfortably inside the world's 3s post-complete idle,
/// so the driver is back on the dashboard before the next scripted offer
/// arms. The router collapses the sheet on done; a full-surface tap skips.
///
/// 🔴 THE TIMELINE DOES NOT WAIT FOR MONEY. It runs identically whether a
/// payout figure ever arrives or not. It used to be keyed on the FIGURE, which
/// meant the sheet could not even be constructed without one — and on live the
/// figure never comes (seam #7), so the sheet never attached, and since the
/// sheet was the completed card's only exit the driver was stranded on a dead
/// screen after every trip. The figure is now watched separately, by the view,
/// as decoration.
///
/// No widget imports, no BuildContext, no navigation.
class EarnedMomentInteractor extends Notifier<EarnedMomentState> {
  EarnedMomentInteractor(this.rideId);

  /// The family argument: the completed ride this moment closes out.
  final String rideId;

  /// The check-pop beat — the sheet's opening.
  static const Duration checkPopBeat = Duration(milliseconds: 400);

  /// The £0 → payout odometer beat.
  static const Duration countUpBeat = Duration(milliseconds: 900);

  /// The quiet hold on the finished number before the collapse — sized so
  /// the whole moment lands exactly on the §5 1.5s budget.
  static const Duration holdBeat = Duration(milliseconds: 200);

  Timer? _timer;

  @override
  EarnedMomentState build() {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer(checkPopBeat, () {
      state = state.copyWith(phase: EarnedPhase.countUp);
      _timer = Timer(countUpBeat + holdBeat, () {
        state = state.copyWith(phase: EarnedPhase.done);
      });
    });
    return const EarnedMomentState();
  }

  /// Tap-to-dismiss: cancel the armed beat and jump straight to done.
  void skip() {
    _timer?.cancel();
    if (state.phase == EarnedPhase.done) return;
    state = state.copyWith(phase: EarnedPhase.done);
  }
}

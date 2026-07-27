import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Where the persistent runner card currently is in the trip. Ride statuses
/// map onto these monotonically — the card MORPHS forward through them and
/// never regresses on a stale telemetry snapshot.
enum TripPhase {
  /// Ride accepted; ETA counts 120→0 and floors at the calm 'Arriving now'
  /// hold. NOTHING advances until the presenter taps Arrived — the world
  /// holds forever by design.
  headingToPickup,

  /// At the pickup, waiting for the rider to board (ride status arriving).
  arrivedAtPickup,

  /// Trip running (ride status started).
  inTrip,

  /// Trip complete — the earned moment takes over.
  completed,
}

/// Immutable snapshot of everything the trip runner view renders. One class
/// + a phase enum, hand-rolled in the DashboardState style (riblet
/// convention).
@immutable
class TripRunnerState {
  const TripRunnerState({
    required this.rideId,
    this.phase = TripPhase.headingToPickup,
    this.etaSeconds,
    this.riderContext,
    this.busy = false,
    this.payoutPence,
    this.error,
    this.dismissed = false,
    this.arrivedAt,
  });

  /// The ride this runner instance is bound to (the /trip/:id path param).
  final String rideId;

  final TripPhase phase;

  /// Seconds to pickup from telemetry; 0 renders as 'Arriving now' in the
  /// VIEW — the state stays numeric. Null once the pickup leg is over.
  final int? etaSeconds;

  /// Who the rider is and where pickup is — null in live mode (no rider
  /// identity surface in the API); the view falls back gracefully.
  final TripRiderContext? riderContext;

  /// True while a lifecycle intent (arrived/start/complete) is in flight.
  final bool busy;

  /// The completed trip's payout, detected from the earnings delta.
  ///
  /// 🔴 PURE DECORATION. It comes from the #7 (`todayStats()`) seam, which the
  /// live backend does not serve, so on live it is null on every trip. NOTHING
  /// may gate on it — not the earned-moment attach, not the Done affordance,
  /// not navigation. It used to gate the sheet, which was the only exit from a
  /// completed trip, so on live the driver was stranded on a dead card after
  /// every single trip. A money figure decorates; it never decides.
  final int? payoutPence;

  /// Display-ready failure message from the last intent, if any.
  final String? error;

  /// The driver has taken the Done affordance on the completed card — the
  /// router lands them back on the dashboard.
  ///
  /// This is the trip's UNCONDITIONAL exit. It is a local intent flag and it
  /// depends on NO seam, NO repository read and NO figure: whatever else the
  /// backend does or does not tell us, a driver who has finished a trip can
  /// always leave the screen.
  final bool dismissed;

  /// When the driver marked themselves arrived, on THIS device's clock.
  ///
  /// 🔴 LOCAL, AND DELIBERATELY SO. It is not a seam, not a server field, and
  /// nothing in the API returns it. Elapsed time since this stamp is the ONE
  /// honest thing we can say about waiting — and it is fully buildable today
  /// with no backend at all.
  ///
  /// 🔴 IT COUNTS UP. There is no countdown, because there is nothing to count
  /// DOWN to: no free-wait window, no per-minute rate, no charge threshold
  /// exists anywhere in the product (#44). A clock ticking toward "5:00 — wait
  /// charge starts" would be a FABRICATED PROMISE ABOUT A SELF-EMPLOYED
  /// PERSON'S PAY. It would be believed. And it would be wrong.
  final DateTime? arrivedAt;

  static const Object _unset = Object();

  /// copyWith with explicit null-clearing for the nullable fields: passing
  /// `null` clears, omitting keeps.
  TripRunnerState copyWith({
    TripPhase? phase,
    Object? etaSeconds = _unset,
    Object? riderContext = _unset,
    bool? busy,
    Object? payoutPence = _unset,
    Object? error = _unset,
    bool? dismissed,
    Object? arrivedAt = _unset,
  }) {
    return TripRunnerState(
      rideId: rideId,
      phase: phase ?? this.phase,
      etaSeconds:
          identical(etaSeconds, _unset) ? this.etaSeconds : etaSeconds as int?,
      riderContext: identical(riderContext, _unset)
          ? this.riderContext
          : riderContext as TripRiderContext?,
      busy: busy ?? this.busy,
      payoutPence: identical(payoutPence, _unset)
          ? this.payoutPence
          : payoutPence as int?,
      error: identical(error, _unset) ? this.error : error as String?,
      dismissed: dismissed ?? this.dismissed,
      arrivedAt: identical(arrivedAt, _unset)
          ? this.arrivedAt
          : arrivedAt as DateTime?,
    );
  }
}

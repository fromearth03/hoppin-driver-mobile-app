import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart' show HopGeoPoint;

/// Where the offer takeover currently is in its short, loud life.
///
/// The takeover is ATTACHED by the dashboard router (an offer surfacing in
/// telemetry) and DETACHED by every exit here: accepted hands off to the
/// trip runner, dismissed pops the overlay (after a decline or the quiet
/// expired note), and the world's re-offer re-attaches a fresh instance.
enum OfferPhase {
  /// On screen, ring draining, waiting for the driver's call.
  presenting,

  /// `acceptOffer` in flight — the Accept shows its busy treatment.
  accepting,

  /// Accepted: the router replaces the stack with /trip/:id.
  accepted,

  /// The wall-clock deadline passed — the quiet 'Offer expired' note beat
  /// plays before the recycle decline dismisses.
  expired,

  /// 🔴 409 `OFFER_EXPIRED` at accept: the driver tapped inside the window and
  /// the network lost the race — someone else got the ride. A SPECIFIC,
  /// non-blaming state (never a red banner on a dead card); the router forwards
  /// them back to the dashboard, still online.
  reassigned,

  /// 🔴 403 `NOT_ELIGIBLE` at accept: the server re-checks eligibility here, so
  /// an MOT that lapsed mid-shift surfaces at accept. The router routes to
  /// `/documents` — the one place the driver can ACT — and the app says NOTHING
  /// about the cause (compliance OR restriction OR suspension; #30).
  notEligible,

  /// Gone. The router pops the overlay exactly once on this.
  dismissed,
}

/// Immutable snapshot of everything the takeover view renders. One class +
/// a phase enum, hand-rolled in the dashboard/trip-runner style (riblet
/// convention).
@immutable
class OfferTakeoverState {
  const OfferTakeoverState({
    required this.offer,
    required this.presentedAt,
    required this.deadline,
    this.phase = OfferPhase.presenting,
    this.acceptedRideId,
    this.driverContextPosition,
    this.error,
  });

  /// The offer being presented — fare, miles, and the raw timestamps.
  final RideOffer offer;

  /// Wall-clock instant the countdown window opened — the ring's 100%
  /// reference. See the interactor for how it anchors against the offer's
  /// own timestamps.
  final DateTime presentedAt;

  /// Wall-clock expiry the ring drains toward and the interactor's expiry
  /// timer fires on. Always comparable to `clock.now()`.
  final DateTime deadline;

  final OfferPhase phase;

  /// The accepted ride's id — non-null only in [OfferPhase.accepted]; the
  /// router navigates to `/trip/{acceptedRideId}` on it.
  final String? acceptedRideId;

  /// Where the driver currently is — one-shot MAP-04 context for the
  /// compact inset (driver→pickup, supporting the accept decision). Null
  /// on live (no driver-location read yet) and until the demo seam
  /// answers; the inset degrades to a pickup-pin-only frame.
  final HopGeoPoint? driverContextPosition;

  /// Display-ready failure message from the last accept attempt, if any.
  final String? error;

  static const Object _unset = Object();

  /// copyWith with explicit null-clearing for the nullable fields: passing
  /// `null` clears, omitting keeps.
  OfferTakeoverState copyWith({
    OfferPhase? phase,
    Object? acceptedRideId = _unset,
    Object? driverContextPosition = _unset,
    Object? error = _unset,
  }) {
    return OfferTakeoverState(
      offer: offer,
      presentedAt: presentedAt,
      deadline: deadline,
      phase: phase ?? this.phase,
      acceptedRideId: identical(acceptedRideId, _unset)
          ? this.acceptedRideId
          : acceptedRideId as String?,
      driverContextPosition: identical(driverContextPosition, _unset)
          ? this.driverContextPosition
          : driverContextPosition as HopGeoPoint?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

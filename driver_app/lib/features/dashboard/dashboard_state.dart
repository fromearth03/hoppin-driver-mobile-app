import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Where the dashboard currently is in the online/offline lifecycle.
///
/// The REPOSITORY (via `driverStatsProvider`) is the source of truth for
/// online/offline: the `going*` phases exist only while a transition is in
/// flight, and the next telemetry emission resolves them — never a local
/// bool, never an optimistic flip.
enum DashboardPhase {
  /// Off the dispatch pool; the GO button breathes.
  offline,

  /// `goOnline()` in flight — held until telemetry confirms.
  goingOnline,

  /// In the pool; finding trips.
  online,

  /// `goOffline()` in flight — held until telemetry confirms.
  goingOffline,
}

/// Immutable snapshot of everything the dashboard view renders. One class +
/// a phase enum, hand-rolled in the BookingState style (riblet convention).
@immutable
class DashboardState {
  const DashboardState({
    this.phase = DashboardPhase.offline,
    this.earningsPence = 0,
    this.tripCount = 0,
    this.onlineTime = Duration.zero,
    this.pickupEtaSeconds,
    this.activeRideId,
    this.pendingOffer,
    this.recentEarnedPence,
    this.error,
    this.statsReady = false,
  });

  final DashboardPhase phase;

  /// Today's earnings so far, in pence.
  final int earningsPence;

  /// Trips completed today.
  final int tripCount;

  /// Time spent online today.
  final Duration onlineTime;

  /// ETA to pickup while a trip is en route; null otherwise.
  final int? pickupEtaSeconds;

  /// A ride this driver accepted and is running, else null. The router's
  /// trip-resume listener (03-04) acts on this.
  ///
  /// SOURCED FROM A BOUND READ (`activeRideProvider` → `GET /rides`), never
  /// from the #7 telemetry seam. This is NAVIGATION state; a capability seam
  /// may only feed decoration.
  final String? activeRideId;

  /// The head of the pending-offers list. The router's offer-attach
  /// listener (03-05) acts on this; the interactor just holds the truth.
  final RideOffer? pendingOffer;

  /// Pence earned since the previous telemetry emission — non-null only
  /// during the tile-absorb window (~2.5s), then cleared.
  final int? recentEarnedPence;

  /// Display-ready failure message from the last intent, if any.
  final String? error;

  /// True once the first telemetry emission has landed. False in live mode
  /// (no telemetry endpoint) — the tile degrades to quiet placeholders.
  final bool statsReady;

  /// Whether a go-online/go-offline transition is in flight.
  bool get transitioning =>
      phase == DashboardPhase.goingOnline ||
      phase == DashboardPhase.goingOffline;

  static const Object _unset = Object();

  /// copyWith with explicit null-clearing for the nullable fields: passing
  /// `null` clears, omitting keeps.
  DashboardState copyWith({
    DashboardPhase? phase,
    int? earningsPence,
    int? tripCount,
    Duration? onlineTime,
    Object? pickupEtaSeconds = _unset,
    Object? activeRideId = _unset,
    Object? pendingOffer = _unset,
    Object? recentEarnedPence = _unset,
    Object? error = _unset,
    bool? statsReady,
  }) {
    return DashboardState(
      phase: phase ?? this.phase,
      earningsPence: earningsPence ?? this.earningsPence,
      tripCount: tripCount ?? this.tripCount,
      onlineTime: onlineTime ?? this.onlineTime,
      pickupEtaSeconds: identical(pickupEtaSeconds, _unset)
          ? this.pickupEtaSeconds
          : pickupEtaSeconds as int?,
      activeRideId: identical(activeRideId, _unset)
          ? this.activeRideId
          : activeRideId as String?,
      pendingOffer: identical(pendingOffer, _unset)
          ? this.pendingOffer
          : pendingOffer as RideOffer?,
      recentEarnedPence: identical(recentEarnedPence, _unset)
          ? this.recentEarnedPence
          : recentEarnedPence as int?,
      error: identical(error, _unset) ? this.error : error as String?,
      statsReady: statsReady ?? this.statsReady,
    );
  }

  /// Value equality over EVERY field.
  ///
  /// 🔴 Load-bearing for performance, not cosmetic. `driverStatsProvider` emits
  /// once per second and the interactor calls `copyWith` on each emission. With
  /// no `==`, every emission yields a reference-unequal state, so Riverpod
  /// notifies and the WHOLE dashboard tree (GoButton, pills, eligibility +
  /// presence watches) rebuilds 60×/min — even while offline, when the backing
  /// telemetry is byte-identical every tick. On Flutter web (single-threaded,
  /// layout on the main thread) that sustained full-tree rebuild pins the main
  /// thread. With value equality an unchanged tick is a no-op: no notify, no
  /// rebuild.
  @override
  bool operator ==(Object other) =>
      other is DashboardState &&
      other.phase == phase &&
      other.earningsPence == earningsPence &&
      other.tripCount == tripCount &&
      other.onlineTime == onlineTime &&
      other.pickupEtaSeconds == pickupEtaSeconds &&
      other.activeRideId == activeRideId &&
      other.pendingOffer == pendingOffer &&
      other.recentEarnedPence == recentEarnedPence &&
      other.error == error &&
      other.statsReady == statsReady;

  @override
  int get hashCode => Object.hash(
        phase,
        earningsPence,
        tripCount,
        onlineTime,
        pickupEtaSeconds,
        activeRideId,
        pendingOffer,
        recentEarnedPence,
        error,
        statsReady,
      );
}

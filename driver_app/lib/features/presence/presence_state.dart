import 'package:flutter/foundation.dart';

import '../location/location_service.dart';

/// Whether the driver is actually REACHABLE by dispatch — which is a different
/// question from whether they tapped GO.
///
/// `POST /drivers/me/online` puts a driver in the pool. `POST
/// /drivers/me/location` is what KEEPS them there: the admin marks a driver
/// Offline after 5 minutes with no ping. A driver can therefore be "online" and
/// completely undispatchable at the same time — which is exactly what shipped,
/// because `heartbeat()` had zero callers anywhere in the app.
enum PresencePhase {
  /// Not online. No heartbeat is running and none should be.
  idle,

  /// Online AND pinging. The driver is genuinely in the dispatch pool.
  live,

  /// Online, but the DEVICE will not give us a fix — OS permission denied or
  /// location services off (seam #84).
  ///
  /// 🔴 NO FIX MEANS NO PING MEANS NOT DISPATCHABLE. We do not send a
  /// fabricated coordinate to keep the presence light green. The backend
  /// ACCEPTS an empty body and binds it to `0,0`, so a "just send something"
  /// heartbeat would silently pin the driver to the Gulf of Guinea and hand
  /// dispatch a confident, wrong answer. We send nothing, and the app SAYS SO.
  noFix,

  /// Online, a fix exists, but the ping itself is failing (network / server).
  /// The timer keeps retrying; presence lapses in 5 minutes if it never lands.
  degraded,
}

/// Immutable snapshot of the driver's dispatch presence.
@immutable
class PresenceState {
  const PresenceState({
    this.phase = PresencePhase.idle,
    this.lastPingAt,
    this.pingCount = 0,
    this.coverage = DriverLocationCoverage.none,
    this.shiftServiceRunning = false,
  });

  final PresencePhase phase;

  /// When the last heartbeat was ACCEPTED by the server. Null until one is.
  final DateTime? lastPingAt;

  /// How many heartbeats have landed this session — the dispatchability proof.
  final int pingCount;

  /// 🔴 HOW MUCH OF THIS SHIFT THE DEVICE ACTUALLY COVERS. Read from the OS at
  /// GO and re-read on every resume — the driver can revoke background location
  /// from Settings mid-shift and Android pushes us no event when they do.
  final DriverLocationCoverage coverage;

  /// Whether the Android foreground service is actually up, asked of the OS. A
  /// `false` here with [coverage] `full` means the OS refused to start the
  /// service (notifications denied, an OEM battery policy) — the permission is
  /// there but the protection is not, and the driver is told the same thing
  /// either way: **the shift dies when the screen locks.**
  final bool shiftServiceRunning;

  /// The driver tapped GO but nobody can reach them. The dashboard raises the
  /// #84 rung on exactly this.
  bool get locationUnavailable => phase == PresencePhase.noFix;

  /// 🔴 THE SHIFT SURVIVES A LOCKED SCREEN — the promise this whole app makes.
  ///
  /// It takes BOTH: the `ACCESS_BACKGROUND_LOCATION` grant AND a running
  /// foreground service. Either one missing and Android stops delivering fixes
  /// the moment the app leaves the screen, the 20-second heartbeat starves, and
  /// the admin drops the driver from the dispatch pool five minutes later.
  ///
  /// This getter is what the ONLINE badge is allowed to be confident about.
  /// Nothing else is.
  bool get backgroundProtected =>
      coverage == DriverLocationCoverage.full && shiftServiceRunning;

  /// The driver IS working and IS dispatchable — but only while the app is on
  /// screen. Not a failure. A **reduced** state, and one they must be told the
  /// exact shape of (seam #85, `BackgroundLocationLimitedNotice`).
  bool get foregroundOnly =>
      coverage != DriverLocationCoverage.none && !backgroundProtected;

  static const Object _unset = Object();

  PresenceState copyWith({
    PresencePhase? phase,
    Object? lastPingAt = _unset,
    int? pingCount,
    DriverLocationCoverage? coverage,
    bool? shiftServiceRunning,
  }) {
    return PresenceState(
      phase: phase ?? this.phase,
      lastPingAt: identical(lastPingAt, _unset)
          ? this.lastPingAt
          : lastPingAt as DateTime?,
      pingCount: pingCount ?? this.pingCount,
      coverage: coverage ?? this.coverage,
      shiftServiceRunning: shiftServiceRunning ?? this.shiftServiceRunning,
    );
  }
}

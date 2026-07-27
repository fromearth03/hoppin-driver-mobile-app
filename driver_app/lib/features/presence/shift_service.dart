import 'dart:async';

/// The seam over the ANDROID FOREGROUND SERVICE that keeps a driver's shift
/// alive with the screen locked.
///
/// 🔴 WHY A FOREGROUND SERVICE AT ALL — AND WHY THE WEB TARGET IS GONE (D1).
///
/// `PresenceInteractor` fires `POST /drivers/me/location` every 20 seconds, and
/// the admin drops a driver from the dispatch pool after 5 minutes without a
/// ping. That timer is a plain Dart `Timer.periodic` living in the app's
/// isolate — and the moment Android decides the app is no longer visible, the
/// OS is entitled to freeze that isolate, throttle the timer, and stop
/// delivering location fixes altogether. A driver who locks their phone and
/// puts it in the cradle pocket therefore stops heartbeating, gets dropped five
/// minutes later, and spends the rest of their shift believing they are online.
///
/// The ONLY sanctioned way on Android to keep reading location while the app is
/// backgrounded is a foreground service with a **persistent, user-visible
/// notification** and a **declared `foregroundServiceType="location"`**. There
/// is no web equivalent — not a harder one, NONE (geolocation is not exposed to
/// `ServiceWorkerGlobalScope`, and the W3C declined to spec it). That is the
/// whole of decision D1.
///
/// ── WHAT THIS SEAM MAY AND MAY NOT DO ────────────────────────────────────────
///
/// It is a LIFECYCLE gateway, not a capability seam, and the distinction is the
/// project's standing rule: *a capability seam may feed only DECORATION — never
/// presence, never navigation, never lifecycle.* This is the other side of that
/// coin. It is allowed to be load-bearing precisely because it never ANSWERS a
/// question — it only starts and stops. It never returns a coordinate, never
/// returns a status the UI trusts, and nothing branches on it. The heartbeat
/// itself still runs in the Dart isolate and still reads its fix through
/// `DriverLocationService`; this service exists solely to keep that isolate
/// ALIVE. If it fails, presence degrades exactly as it would on a phone with the
/// screen on — never silently.
///
/// Every method DEGRADES. None throws. A platform that has no such concept (the
/// test harness, a desktop dev machine) gets the no-op, and the app still runs —
/// just without background coverage, which is a state the driver is TOLD about.
abstract class DriverShiftService {
  /// Starts the persistent shift notification and the wake-lock that keeps the
  /// heartbeat isolate alive with the screen off.
  ///
  /// Returns whether the service is actually running afterwards. `false` is a
  /// real answer, not an error: the OS can refuse (notifications denied, an OEM
  /// battery policy, a `startForeground` throw). A `false` here means the driver
  /// has NO BACKGROUND COVERAGE, and the app must say so rather than draw a
  /// confident ONLINE badge over it.
  Future<bool> start();

  /// Ends the shift notification. Idempotent — safe to call when not running.
  Future<void> stop();

  /// Whether the shift service is running RIGHT NOW, asked of the OS rather than
  /// remembered. The OS is the authority on its own services; our memory of what
  /// we asked for is not.
  Future<bool> isRunning();
}

/// The seam's answer on any platform with no foreground-service concept — every
/// test, and any non-Android build.
///
/// It reports `false` and it means it. It does not pretend the shift is
/// protected; a `true` here would be exactly the kind of comfortable lie that
/// ends with a driver dropped from dispatch while the app shows a green badge.
class NoopDriverShiftService implements DriverShiftService {
  /// Creates the no-op shift service.
  const NoopDriverShiftService();

  @override
  Future<bool> start() async => false;

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => false;
}

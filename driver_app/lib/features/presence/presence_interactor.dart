import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import '../dashboard/dashboard_builder.dart';
import '../dashboard/dashboard_state.dart';
import '../location/location_providers.dart';
import '../location/location_service.dart';
import '../notifications/driver_fcm_gateway.dart';
import '../notifications/driver_push_registration.dart';
import 'presence_builder.dart';
import 'presence_state.dart';

/// THE BRAIN of the presence riblet (DOCS/05) — a SERVICE riblet: interactor +
/// state, no view, no router, no route. It owns the location heartbeat.
///
/// 🔴 WHY THIS EXISTS. `DriverRepository.heartbeat({lat, lng})` →
/// `POST /drivers/me/location` has been bound, typed and correct since the API
/// client was written, and `grep -rn "heartbeat" apps/driver/lib` returned ZERO
/// HITS. A driver tapped GO, the server pooled them, and they NEVER PINGED. The
/// admin drops a driver from the dispatch pool after 5 minutes without a ping,
/// so every driver silently fell out of dispatch five minutes into their shift
/// and earned nothing, and the app told them nothing. (Wave 0 fixed the GO
/// SPINNER. It did not make the driver DISPATCHABLE.)
///
/// TWO RULES, EACH PAID FOR BY A REAL BUG:
///
/// 1. **It listens to the DASHBOARD PHASE, never to `todayStats()`.** Hanging
///    the heartbeat off the #7 seam would recreate the whole family of bugs
///    this phase exists to kill: #7 answers null on every live request, so the
///    heartbeat would never start. Presence is authoritative from `goOnline()`'s
///    200 — that is what the dashboard phase already encodes.
///
/// 2. **No fix → NO PING.** Never a fabricated coordinate, never an empty body.
///    The server accepts `{}` and binds it to `0,0` (CODE-GRAPH §6 #26), so a
///    "send something rather than nothing" heartbeat would pin the driver to
///    the Gulf of Guinea and dispatch would believe it. When the device will
///    not give us a fix, the driver is NOT dispatchable, and the honest thing —
///    the only thing — is to say so (seam #84, `LocationUnavailableBanner`).
class PresenceInteractor extends Notifier<PresenceState> {
  /// The heartbeat cadence.
  ///
  /// The server drops a driver after 5 MINUTES without a ping. Five seconds
  /// gives 60 consecutive misses of headroom before presence lapses and keeps
  /// active-trip maps responsive enough to show meaningful movement. It is
  /// still slow enough to avoid a continuous location/network stream.
  static const Duration cadence = Duration(seconds: 5);

  /// How long a single fix attempt may take before the tick gives up.
  static const Duration fixTimeout = Duration(seconds: 10);

  Timer? _tick;

  /// Bumped whenever the heartbeat stops; an in-flight ping from an older
  /// generation discards its result instead of writing to dead state.
  int _generation = 0;

  @override
  PresenceState build() {
    // Cancel the timer ONLY — never write state from a dispose callback
    // (Riverpod forbids it, and there is nothing left to render anyway).
    ref.onDispose(() {
      _generation++;
      _tick?.cancel();
      _tick = null;
    });

    ref.listen(dashboardInteractorProvider, (previous, next) {
      final online = next.phase == DashboardPhase.online;
      final wasOnline = previous?.phase == DashboardPhase.online;
      if (online == wasOnline) return;
      online ? _start() : _stop();
    });

    // The dashboard may ALREADY be online when this riblet first builds (a
    // rebuild, or a mount that trails the GO tap). Seed from the current phase
    // rather than waiting for a transition that has already happened.
    if (ref.read(dashboardInteractorProvider).phase == DashboardPhase.online) {
      _start();
    }

    return const PresenceState();
  }

  void _start() {
    if (_tick != null) return;
    _tick = Timer.periodic(cadence, (_) => unawaited(_ping(_generation)));
    // STAGE ONE of the permission flow, wired at GO — the one explicit gesture
    // we get. The geolocator heartbeat path (`currentFix`) NEVER prompts on its
    // own, so without this the driver's fix stays null forever and they sit at
    // the #84 "no fix / undispatchable" rung having never been asked. Ping fires
    // immediately after the grant resolves; `goOnline()` already returned 200 so
    // the driver is already in the pool.
    unawaited(_primeLocation(_generation));
    // The ANDROID FOREGROUND SERVICE (Phase 2). Started alongside the timer,
    // never instead of it: the service does not run the heartbeat, it keeps the
    // isolate that runs the heartbeat ALIVE with the screen off.
    unawaited(_startShift(_generation));
  }

  /// Requests foreground location permission at GO (stage one), then fires the
  /// first heartbeat. This is the one place a permission dialog is appropriate:
  /// the driver just tapped GO, so the request rides that gesture (required on
  /// web) and is expected. The heartbeat's own `currentFix()` deliberately never
  /// prompts, so the grant has to be seeded here or it never happens. We never
  /// branch on the request's own answer — the ping asks the OS for a real fix.
  Future<void> _primeLocation(int gen) async {
    await ref.read(driverLocationServiceProvider).requestPermission();
    if (gen != _generation) return;
    await _ping(gen);
  }

  void _stop() {
    _generation++;
    _tick?.cancel();
    _tick = null;
    // Tear the notification down. A persistent "On shift" notification over a
    // driver who has clocked off is its own small lie, and the wake lock is not
    // free.
    unawaited(ref.read(driverShiftServiceProvider).stop());
    if (state.phase != PresencePhase.idle ||
        state.shiftServiceRunning ||
        state.coverage != DriverLocationCoverage.none) {
      state = state.copyWith(
        phase: PresencePhase.idle,
        shiftServiceRunning: false,
        coverage: DriverLocationCoverage.none,
      );
    }
  }

  /// Brings up the persistent shift notification + wake lock, then records —
  /// HONESTLY — how much of the shift the device will actually cover.
  ///
  /// 🔴 NEITHER OUTCOME IS AN ERROR AND NEITHER BLOCKS THE DRIVER. A driver with
  /// foreground-only location, or one whose OS refused to start the service, is
  /// a REAL WORKING DRIVER who is dispatchable while the app is on screen. What
  /// they are not is protected when they lock their phone — and that is a fact
  /// the app owes them out loud (seam #85), not a reason to stop them working.
  Future<void> _startShift(int gen) async {
    final running = await ref.read(driverShiftServiceProvider).start();
    if (gen != _generation) return;
    final coverage = await ref.read(driverLocationServiceProvider).coverage();
    if (gen != _generation) return;
    state = state.copyWith(shiftServiceRunning: running, coverage: coverage);

    // The push token, registered at the SAME explicit driver action — never at
    // boot. On Android 13+ `POST_NOTIFICATIONS` is not a push nicety: it is what
    // lets the foreground service's persistent notification be SEEN, and that
    // notification is the OS's contract for keeping this isolate alive with the
    // screen off. Asking for it is part of the same breath as going online.
    //
    // Fire-and-forget, and that is DELIBERATE: registration must never gate the
    // shift. Presence, dispatch and the heartbeat are entirely independent of
    // push — a driver blocked from working because a notification token would
    // not register would be an absurd defect. (Delivery is GATED on the backend
    // anyway: #15/#16.)
    unawaited(_registerPush());
  }

  Future<void> _registerPush() async {
    try {
      await registerDriverDeviceToken(
        gateway: ref.read(driverFcmGatewayProvider),
        profiles: ref.read(profileRepositoryProvider),
        isWeb: kIsWeb,
        platform: defaultTargetPlatform,
      );
    } catch (_) {
      // Nothing above this line may fail a shift. The default gateway is the
      // no-op, which returns null and registers nothing — the honest state
      // while there is no `google-services.json` in the tree.
    }
  }

  /// 🔴 STAGE TWO OF THE TWO-STAGE PERMISSION FLOW.
  ///
  /// Android 10 (API 29) split location into two grants that CANNOT be asked for
  /// together: "While using the app" (`ACCESS_FINE_LOCATION`) and, separately,
  /// "Allow all the time" (`ACCESS_BACKGROUND_LOCATION`). Stage one runs at GO,
  /// inside the existing `currentPosition()` path. Stage two is THIS — and it is
  /// deliberately driven by an EXPLICIT DRIVER TAP on the #85 rung, never fired
  /// automatically:
  ///
  ///  - Android 11+ shows **no dialog at all** for the background upgrade. The
  ///    request resolves instantly to "denied" and the only real route is the
  ///    Settings app. Firing that silently from a timer would burn the driver's
  ///    one chance and teach them nothing.
  ///  - A permission dialog thrown at a driver mid-junction is a hazard.
  ///
  /// So: the rung explains the CONSEQUENCE, the driver taps, we ask, and if the
  /// OS says no (which on Android 11+ it will, without asking them) we open
  /// Settings — which is the only place the grant actually lives. Then we
  /// re-read coverage from the OS rather than believing our own request.
  Future<void> requestBackgroundCoverage() async {
    final location = ref.read(driverLocationServiceProvider);
    final result = await location.requestBackgroundPermission();
    if (result != DriverLocationPermission.granted) {
      // Not an error. The OS either refused, or (Android 11+) declined to even
      // ask. Settings is where "Allow all the time" actually lives.
      await location.openSettings();
    }
    // NEVER trust the request's own answer as the new truth — the driver may
    // still be standing in the Settings app. Ask the OS what it actually holds.
    await refreshCoverage();
  }

  /// Re-asks the OS what coverage we have, and whether the service is still up.
  ///
  /// 🔴 CALLED ON EVERY APP RESUME, AND IT HAS TO BE. A driver can revoke
  /// background location from the Settings app mid-shift, and Android pushes us
  /// no event when they do — the only honest way to know is to ask again every
  /// time we come back to the foreground. Without this, the app would carry a
  /// cached "background protected" belief across the exact user action that
  /// falsified it, and keep showing a confident badge over a shift that now dies
  /// at the lock screen.
  Future<void> refreshCoverage() async {
    if (_tick == null) return; // not online; nothing to be honest about yet
    final gen = _generation;
    final running = await ref.read(driverShiftServiceProvider).isRunning();
    if (gen != _generation) return;
    final coverage = await ref.read(driverLocationServiceProvider).coverage();
    if (gen != _generation) return;
    state = state.copyWith(shiftServiceRunning: running, coverage: coverage);
  }

  Future<void> _ping(int gen) async {
    final fix = await ref
        .read(driverLocationServiceProvider)
        .currentPosition(timeout: fixTimeout);
    if (gen != _generation) return; // went offline mid-fix

    if (fix == null) {
      // HONEST DEGRADE. No fix → no ping → the driver is not dispatchable, and
      // the dashboard raises the #84 rung. We never invent a coordinate to keep
      // a presence light green.
      state = state.copyWith(phase: PresencePhase.noFix);
      return;
    }

    try {
      await ref
          .read(driverRepositoryProvider)
          .heartbeat(lat: fix.lat, lng: fix.lng);
      if (gen != _generation) return;
      state = state.copyWith(
        phase: PresencePhase.live,
        lastPingAt: clock.now(),
        pingCount: state.pingCount + 1,
      );
    } on Exception {
      if (gen != _generation) return;
      // The fix is good; the wire is not. The timer keeps trying — presence
      // only lapses if it never lands for 5 minutes.
      state = state.copyWith(phase: PresencePhase.degraded);
    }
  }
}

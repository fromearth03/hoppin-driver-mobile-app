import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

/// The outcome of a location-permission request, normalised away from the
/// plugin's enum so widgets and tests never import geolocator directly.
enum DriverLocationPermission {
  /// The driver granted while-in-use (or always) access.
  granted,

  /// The driver declined this time — can be asked again later.
  denied,

  /// The driver declined permanently — must be changed in OS settings.
  deniedForever,

  /// Location services are switched off at the OS level.
  serviceDisabled,
}

/// 🔴 HOW MUCH OF A SHIFT THE DEVICE WILL ACTUALLY COVER (v3.0 Phase 2).
///
/// This is the honesty rule applied to a DEVICE capability. Android 10 (API 29)
/// split location into a **two-stage grant**: `ACCESS_FINE_LOCATION` (which the
/// system dialog offers as "While using the app") and, as a completely separate
/// second request that cannot be bundled with it, `ACCESS_BACKGROUND_LOCATION`
/// ("Allow all the time"), which on Android 11+ cannot even be *prompted* — the
/// OS forces the driver out to the Settings app.
///
/// So there are three genuinely different worlds, and they are NOT degrees of
/// the same thing:
///
///  - [full] — the heartbeat survives the screen locking. The driver can pocket
///    the phone and stay in the dispatch pool. This is the product we promised.
///  - [foregroundOnly] — the driver IS dispatchable, but **only while the app is
///    on screen**. The moment they lock the phone or switch to Google Maps,
///    Android stops delivering fixes, the heartbeat starves, and the admin drops
///    them from the pool five minutes later. **They are still a working driver**
///    — this is not a failure state and it must not be treated as one. It is a
///    REDUCED state, and the driver must be told EXACTLY what they lose.
///  - [none] — no fix at all, therefore no ping, therefore not dispatchable
///    (seam #84).
///
/// 🔴 A CONFIDENT "ONLINE" BADGE OVER A [foregroundOnly] DRIVER WHO HAS JUST
/// LOCKED THEIR PHONE IS A LIE OF THE SAME CLASS AS A FABRICATED PAYMENT CARD.
/// It tells them they are earning when they are not. The app never claims
/// background coverage it does not have.
enum DriverLocationCoverage {
  /// Background location granted: the shift survives a locked screen.
  full,

  /// Foreground location only. Dispatchable while the app is open, and NOT
  /// dispatchable once it is not. The driver is told, in those words.
  foregroundOnly,

  /// No location at all — permission denied or OS location services off.
  none,
}

/// A single device fix, carrying the speed the OS ALREADY GAVE US.
///
/// 🔴 `speedMps` IS NULLABLE AND THE NULL IS LOAD-BEARING. `Position.speed` is
/// `0.0` both when the vehicle is genuinely stationary AND when the platform has
/// no idea — and `speedAccuracy == 0.0` is the only thing that distinguishes
/// them. Collapse the two and a driver parked at a pickup looks identical to a
/// driver at 40 mph. We keep the distinction: no confidence → `null` → the
/// motion gate treats it as NOT MOVING and leaves the driver's controls alone.
///
/// 🔴 THE NUMBER IS ALREADY IN OUR HANDS. `geolocator` has been handing us
/// `speed` and `speedAccuracy` on every heartbeat fix since this service was
/// written, and we threw both away every time. There is no second GPS
/// subscription here and no second battery cost — only a datum we stopped
/// discarding.
typedef DriverFix = ({double lat, double lng, double? speedMps});

/// The driver-app-only seam over the OS location + permission plugins.
///
/// It is duplicated from `apps/rider/lib/features/location/` on purpose, and
/// the ~80 duplicated lines are the correct price: the project's isolation
/// contract says `geolocator` / `permission_handler` imports never leak into
/// `hoppin_shared` / `hoppin_demo` / `hoppin_ui` (there is an isolation grep
/// enforcing it), so the IMPLEMENTATION must live inside an app. The two
/// implementations will diverge anyway — the rider takes a one-shot fix for an
/// SOS payload; the driver takes a fix every 5 seconds for eight hours and is
/// about to grow an Android foreground service behind it (Phase 2).
///
/// Every method here DEGRADES. None throws, none is unbounded, and
/// [currentPosition] never prompts — a driver mid-shift must not have an OS
/// dialog thrown at them by a background timer.
abstract class DriverLocationService {
  /// Requests OS location permission (while-in-use). Called only from an
  /// explicit driver action, never from the heartbeat timer.
  Future<DriverLocationPermission> requestPermission();

  /// Whether permission is already granted — lets the heartbeat skip a fix it
  /// knows will fail, and lets the dashboard raise its rung.
  Future<bool> hasPermission();

  /// The device's current coordinates, or `null` when unavailable (permission
  /// denied / denied-forever, services off, timeout, refusal). NEVER throws and
  /// NEVER prompts.
  ///
  /// 🔴 `null` MEANS NULL. It never falls back to a default coordinate. The
  /// backend ACCEPTS an empty heartbeat body and binds it to `0,0`
  /// (CODE-GRAPH §6 #26) — so a "safe default" here would silently pin the
  /// driver to the Gulf of Guinea and hand dispatch a confident, wrong fix.
  /// No fix means NO PING (see PresenceInteractor).
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  });

  /// The device's current fix INCLUDING speed, or `null` when unavailable.
  /// NEVER throws, NEVER prompts. [currentPosition] is this, narrowed to
  /// coordinates — one fix path, one failure path, no drift between them.
  ///
  /// `speedMps` is `null` when the platform will not vouch for its own speed
  /// (`speedAccuracy <= 0`). See [DriverFix]: **null is not zero.**
  Future<DriverFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  });

  /// STAGE TWO of the permission flow: ask for `ACCESS_BACKGROUND_LOCATION`.
  ///
  /// 🔴 THIS IS A SEPARATE GRANT AND IT CANNOT BE BUNDLED. Android 10+ refuses
  /// a background request that arrives in the same dialog as the foreground
  /// one, and Android 11+ will not show a dialog for it AT ALL — the request
  /// resolves to "denied" and the only route is the Settings app. So this must
  /// only ever be called AFTER [requestPermission] has returned `granted`, from
  /// an explicit driver action, having first told them WHY.
  ///
  /// A `denied`/`deniedForever` answer here is NOT an error and must not be
  /// treated as one. It means [DriverLocationCoverage.foregroundOnly]: a real,
  /// working, dispatchable driver whose shift dies when the screen locks. The
  /// app tells them exactly that and lets them carry on.
  Future<DriverLocationPermission> requestBackgroundPermission();

  /// How much of a shift this device will actually cover, right now, asked of
  /// the OS — never remembered, because the driver can revoke it from Settings
  /// mid-shift and nothing pushes us an event when they do.
  Future<DriverLocationCoverage> coverage();

  /// Opens the OS app-settings page so a `deniedForever` driver has a real
  /// route back. Returns false when the platform cannot open it.
  Future<bool> openSettings();
}

/// Reads a single OS position fix within `timeout`. Injected so every failure
/// path (throw, hang, refusal) is drivable from a test without a MethodChannel
/// mock — the project injects fakes, it never channel-mocks.
typedef DriverPositionReader = Future<Position> Function({
  required Duration timeout,
});

/// Probes whether location permission is already granted. Injected for the
/// same reason as [DriverPositionReader].
typedef DriverPermissionProbe = Future<bool> Function();

/// Reads the CURRENT permission level from the OS, without prompting. Injected
/// so [DriverLocationCoverage] is drivable from a test without a channel mock.
typedef DriverPermissionLevelProbe = Future<LocationPermission> Function();

/// Prompts for a permission level. Injected for the same reason.
typedef DriverPermissionRequester = Future<LocationPermission> Function();

/// Whether OS location services are switched on at all. Injected likewise.
typedef DriverServiceEnabledProbe = Future<bool> Function();

/// The live implementation over `geolocator`. The driver app wires this; the
/// demo composition supplies its own fake, so this class is never reached off
/// the live path.
class GeolocatorDriverLocationService implements DriverLocationService {
  /// The live service. Every seam defaults to the real geolocator/
  /// permission_handler static; tests inject scripted ones to drive every
  /// failure path WITHOUT a MethodChannel mock — which is the project's rule,
  /// and the reason this class is shaped this way at all.
  const GeolocatorDriverLocationService({
    DriverPositionReader? readPosition,
    DriverPermissionProbe? checkPermission,
    DriverPermissionLevelProbe? permissionLevel,
    DriverPermissionRequester? requestForeground,
    DriverPermissionRequester? requestBackground,
    DriverServiceEnabledProbe? serviceEnabled,
  })  : _readPosition = readPosition ?? _geolocatorRead,
        _checkPermission = checkPermission ?? _geolocatorHasPermission,
        _permissionLevel = permissionLevel ?? Geolocator.checkPermission,
        _requestForeground = requestForeground ?? Geolocator.requestPermission,
        _requestBackground = requestBackground ?? _geolocatorRequestBackground,
        _serviceEnabled = serviceEnabled ?? Geolocator.isLocationServiceEnabled;

  final DriverPositionReader _readPosition;
  final DriverPermissionProbe _checkPermission;
  final DriverPermissionLevelProbe _permissionLevel;
  final DriverPermissionRequester _requestForeground;
  final DriverPermissionRequester _requestBackground;
  final DriverServiceEnabledProbe _serviceEnabled;

  static Future<Position> _geolocatorRead({required Duration timeout}) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
  }

  static Future<bool> _geolocatorHasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// STAGE TWO on the real OS.
  ///
  /// On Android, geolocator's `requestPermission()` escalates a `whileInUse`
  /// grant to `always` — but ONLY when the app already holds `whileInUse`, and
  /// on Android 11+ the system shows no dialog for it at all: the call returns
  /// the current level and the driver must go to Settings. Both of those are
  /// correct behaviour to us; both surface as a non-`always` answer, which maps
  /// to [DriverLocationCoverage.foregroundOnly], which the app DISCLOSES. There
  /// is no path here that fabricates coverage.
  static Future<LocationPermission> _geolocatorRequestBackground() =>
      Geolocator.requestPermission();

  @override
  Future<DriverLocationPermission> requestPermission() async {
    try {
      if (!kIsWeb && !await _serviceEnabled()) {
        return DriverLocationPermission.serviceDisabled;
      }
      final p = _map(await _requestForeground());
      if (kIsWeb) print('HOPPIN_LOC reqPerm ok=$p');
      return p;
    } catch (e) {
      if (kIsWeb) print('HOPPIN_LOC reqPerm ERR: $e');
      return DriverLocationPermission.denied;
    }
  }

  @override
  Future<DriverLocationPermission> requestBackgroundPermission() async {
    if (!kIsWeb && !await _serviceEnabled()) {
      return DriverLocationPermission.serviceDisabled;
    }

    // 🔴 STAGE ORDER IS NOT A STYLE CHOICE. Android rejects a background request
    // from an app that does not already hold foreground location, and answers
    // `denied` — which we would then have to disclose as foregroundOnly over a
    // driver who has no location at all. Refuse to ask out of order.
    final current = await _permissionLevel();
    if (current != LocationPermission.whileInUse &&
        current != LocationPermission.always) {
      return DriverLocationPermission.denied;
    }
    if (current == LocationPermission.always) {
      return DriverLocationPermission.granted;
    }

    final result = await _requestBackground();
    // ONLY `always` is background coverage. `whileInUse` coming back out of a
    // background request is the OS saying NO — on Android 11+ that is the
    // normal, expected answer, because it never showed a dialog. Reporting it
    // as `granted` would be the lie.
    return result == LocationPermission.always
        ? DriverLocationPermission.granted
        : DriverLocationPermission.denied;
  }

  @override
  Future<DriverLocationCoverage> coverage() async {
    try {
      if (!kIsWeb && !await _serviceEnabled()) return DriverLocationCoverage.none;
      return switch (await _permissionLevel()) {
        LocationPermission.always => DriverLocationCoverage.full,
        LocationPermission.whileInUse =>
          DriverLocationCoverage.foregroundOnly,
        _ => DriverLocationCoverage.none,
      };
    } catch (_) {
      // We do not KNOW what coverage we have — so we claim none. The failure
      // mode of an optimistic guess here is a driver told their locked phone is
      // still earning them money.
      return DriverLocationCoverage.none;
    }
  }

  @override
  Future<bool> hasPermission() => _checkPermission();

  /// 🔴 THE ONE FIX PATH. [currentPosition] narrows this rather than reading
  /// the OS a second time — two independent reads would drift, and the heartbeat
  /// and the motion gate would end up disagreeing about where and how fast the
  /// same driver is.
  @override
  Future<DriverFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Short-circuit rather than prompt. The heartbeat calls this on a timer;
      // an `await` on an OS permission dialog is an unbounded wait on a human,
      // and a dialog that surprises a driver mid-junction is a hazard.
      final _has = await _checkPermission();
      if (kIsWeb) print('HOPPIN_LOC checkPerm=$_has');
      if (!_has) return null;

      // Belt AND braces on the bound: `timeLimit` is the plugin's own budget,
      // and `.timeout()` guards the platform that never honours it.
      final position = await _readPosition(timeout: timeout)
          .timeout(timeout + const Duration(milliseconds: 250));
      return (
        lat: position.latitude,
        lng: position.longitude,
        // 🔴 `speedAccuracy <= 0` MEANS THE PLATFORM DOES NOT KNOW. It is not
        // "0 mph". Reporting it as a speed would let a junk fix claim 40 mph
        // over a driver sitting still at a kerb — and the motion gate would
        // take their keyboard away for it.
        speedMps: position.speedAccuracy > 0 ? position.speed : null,
      );
    } catch (e) {
      if (kIsWeb) print('HOPPIN_LOC currentFix ERR: $e');
      // Deliberately bare. TimeoutException, PermissionDeniedException,
      // LocationServiceDisabledException, an untyped platform refusal — all of
      // them mean exactly one thing to the caller: NO FIX. A typed catch would
      // let one escape and kill the heartbeat timer.
      return null;
    }
  }

  @override
  Future<({double lat, double lng})?> currentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final fix = await currentFix(timeout: timeout);
    return fix == null ? null : (lat: fix.lat, lng: fix.lng);
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  DriverLocationPermission _map(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return DriverLocationPermission.granted;
      case LocationPermission.deniedForever:
        return DriverLocationPermission.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return DriverLocationPermission.denied;
    }
  }
}

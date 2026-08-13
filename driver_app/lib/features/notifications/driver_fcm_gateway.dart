import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The seam over the platform FCM SDK (DRIVER-APP-ONLY).
///
/// `firebase_core` / `firebase_messaging` are isolated to
/// `firebase_driver_fcm_gateway.dart` plus one guarded `Firebase.initializeApp()`
/// in `main.dart` — never in `hoppin_shared` / `hoppin_demo` / `hoppin_ui`,
/// mirroring the rider's identical contract and the `flutter_foreground_task`
/// one next door.
///
/// ── 🔴 THE #69 CORRECTION, AND WHY THE ANDROID PIVOT MATTERS ─────────────────
///
/// Gap **#69** has been read across the project as "push is blocked". It is not.
/// `POST /me/device-tokens` validates `device_os` against `{ios, android}` and
/// rejects `"web"`. That blocks the **RIDER**, which ships web and — correctly —
/// **refuses to send a false `"android"`** to get past the validator. It has
/// never blocked the driver, and going Android **UNBLOCKS** driver token
/// registration outright: `"android"` is a value the contract already accepts.
///
/// What remains GATED is **DELIVERY**, on the backend's `FCM_CREDENTIALS_FILE`
/// (#15/#16) and on a push-event schema that has never been published. So the
/// honest state of the driver push rail is:
///
///   registration → **BOUND**, and it really posts a real token.
///   delivery     → **GATED**, and the server simply cannot send yet.
///
/// That is not a fake and it is not a stub: it is a correctly-wired client
/// waiting on a server. **No badge over a dead handler** — that mistake was made
/// once already and is not being made again. The driver app renders no
/// notification count, no unread dot, and no "you'll be notified" promise off
/// this rail until delivery lands.
abstract interface class DriverFcmGateway {
  /// Ask the OS for notification permission. **Android 13+ (API 33) requires an
  /// explicit `POST_NOTIFICATIONS` grant** — and on Android that grant is not
  /// merely about push: it is what lets the **foreground service's persistent
  /// notification** be seen. Returns the honest outcome; NEVER assumes granted.
  Future<DriverFcmPermission> requestPermission();

  /// The device's FCM registration token, or `null` when unavailable (no
  /// permission, no `google-services.json` compiled in, no Firebase project).
  ///
  /// A `null` here is the honest answer, and the caller must never substitute a
  /// placeholder for it — a fabricated token registered against the driver's
  /// account is a device that can never be reached, recorded as one that can.
  Future<String?> token();

  /// Foreground pushes, normalised away from the platform SDK.
  ///
  /// 🔴 **EMPTY ON THE LIVE DEFAULT, AND THAT IS THE HONEST STATE.** Delivery is
  /// GATED on the backend's `FCM_CREDENTIALS_FILE` (#15/#16) — the server cannot
  /// send. A correctly-wired client listening to a stream that never emits is
  /// exactly what waiting on a server looks like; it is not a stub and it is
  /// not a fake.
  ///
  /// The notification centre listens to this. Because it is empty, the centre's
  /// cold start renders its #68 disclosure rather than a list — and the unread
  /// count over it is a REAL 0, never a drawn badge.
  Stream<DriverPushMessage> onMessage();

  /// A push the driver TAPPED (background → foreground). Empty on the no-op.
  Stream<DriverPushMessage> onMessageOpened();

  /// The push that cold-started the app, if any. `null` on the no-op.
  Future<DriverPushMessage?> initialMessage();

  /// Token rotations — re-POST to `/me/device-tokens`. Empty on the no-op.
  Stream<String> onTokenRefresh();
}

/// A push, normalised away from `RemoteMessage` so nothing above this boundary
/// imports firebase.
///
/// The wire shape is ASSUMED (#15 — the backend has published no push-event
/// schema). It mirrors the rider's `PushMessage` so that when a schema lands,
/// both clients parse the same thing. It is deliberately NOT imported from
/// `apps/rider`: the driver app cannot see it, and a shared push model belongs
/// in `hoppin_shared` on the day there is a published schema to share.
class DriverPushMessage {
  /// Creates a normalised push.
  const DriverPushMessage({
    this.title,
    this.body,
    this.rideId,
    this.deepLink,
    this.sentAt,
  });

  /// Display headline.
  final String? title;

  /// Display body.
  final String? body;

  /// The trip this push is about, when it is about one.
  final String? rideId;

  /// The in-app path the backend wants opened. ASSUMED (#15), and OBEYED only
  /// after an allowlist check — a push payload is attacker-influenceable and is
  /// never followed blind.
  final String? deepLink;

  /// When the backend says it sent this.
  final DateTime? sentAt;
}

/// Normalised permission outcome — widgets and tests never import a firebase
/// enum. Same normalisation discipline as `DriverLocationPermission`.
enum DriverFcmPermission {
  /// The driver allowed notifications.
  granted,

  /// The driver refused. On Android 13+ this also means the foreground service's
  /// notification is suppressed — which the driver is told about via the #85
  /// rung, because the consequence (the shift dies at the lock screen) is the
  /// same one.
  denied,

  /// No answer yet — nothing has been asked.
  notDetermined,

  /// No push surface at all: the no-op gateway, or a build with no Firebase
  /// project compiled in. **The honest answer while delivery is gated.**
  unsupported,
}

/// The current live gateway when no Firebase project is compiled in.
///
/// It reports the gate honestly: no permission, no token. It never fabricates a
/// token and never claims a push surface it does not have. Mirrors the rider's
/// `NoopFcmGateway` exactly.
///
/// This is also the gateway every widget and unit test gets for free — which is
/// precisely what keeps `flutter test` off `Firebase.initializeApp()`. If a test
/// ever needs a firebase mock, this boundary has leaked.
class NoopDriverFcmGateway implements DriverFcmGateway {
  /// Creates the no-op gateway.
  const NoopDriverFcmGateway();

  @override
  Future<DriverFcmPermission> requestPermission() async =>
      DriverFcmPermission.unsupported;

  @override
  Future<String?> token() async => null;

  // Nothing arrives, because the server cannot send (#15/#16). An empty stream
  // is the truthful answer here — not a synthesised message to make a screen
  // look alive.
  @override
  Stream<DriverPushMessage> onMessage() => const Stream.empty();

  @override
  Stream<DriverPushMessage> onMessageOpened() => const Stream.empty();

  @override
  Future<DriverPushMessage?> initialMessage() async => null;

  @override
  Stream<String> onTokenRefresh() => const Stream.empty();
}

/// Exposes the active [DriverFcmGateway]. Defaults to [NoopDriverFcmGateway] —
/// the honest state with no `google-services.json` in the tree. `main.dart`
/// overrides it with `FirebaseDriverFcmGateway` ONLY after a successful,
/// guarded `Firebase.initializeApp()`. Nothing else ever constructs a gateway.
final driverFcmGatewayProvider = Provider<DriverFcmGateway>(
  (ref) => const NoopDriverFcmGateway(),
);

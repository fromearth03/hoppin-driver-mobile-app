import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'driver_fcm_gateway.dart';

/// Background isolate: required so Android/iOS deliver a killed-app offer
/// wake-up. No navigation here — DriverShell tap handling does that.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Must be called after a successful `Firebase.initializeApp()`.
void registerDriverBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// The CONCRETE [DriverFcmGateway], over `firebase_messaging`.
///
/// This is the ONLY file in `apps/driver` — besides `main.dart`'s single
/// guarded `Firebase.initializeApp()` — permitted to import
/// `package:firebase_*`. Keeping the SDK here (rather than in
/// `driver_fcm_gateway.dart`, which imports `flutter_riverpod` and nothing else)
/// makes the isolation trivially greppable and keeps every test and the demo
/// structurally unable to reach a real Firebase instance.
///
/// It is NEVER constructed unless a real `android/app/google-services.json` was
/// compiled in AND `Firebase.initializeApp()` has already succeeded. With no
/// such file — today's reality — `main.dart` skips the whole block and the
/// provider keeps its [NoopDriverFcmGateway] default.
///
/// 🔴 DELIVERY REMAINS GATED (#15/#16). This class is wired and correct, and it
/// will simply never receive anything until the backend's `FCM_CREDENTIALS_FILE`
/// lands. That is the honest state — not a fake stream, and not a badge over a
/// dead handler.
class FirebaseDriverFcmGateway implements DriverFcmGateway {
  /// Creates the live gateway. Only valid after a successful
  /// `Firebase.initializeApp()`.
  const FirebaseDriverFcmGateway();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<DriverFcmPermission> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      // Anything that is not an explicit grant degrades to the honest answer —
      // never a fabricated "granted".
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => DriverFcmPermission.granted,
        AuthorizationStatus.denied => DriverFcmPermission.denied,
        AuthorizationStatus.notDetermined => DriverFcmPermission.notDetermined,
      };
    } catch (_) {
      return DriverFcmPermission.unsupported;
    }
  }

  @override
  Future<String?> token() async {
    try {
      final vapid = Env.fcmVapidKey;
      return await _messaging.getToken(vapidKey: vapid.isEmpty ? null : vapid);
    } catch (_) {
      return null;
    }
  }

  /// Foreground pushes, normalised off `RemoteMessage`.
  @override
  Stream<DriverPushMessage> onMessage() =>
      FirebaseMessaging.onMessage.map(driverPushFromRemote);

  @override
  Stream<DriverPushMessage> onMessageOpened() =>
      FirebaseMessaging.onMessageOpenedApp.map(driverPushFromRemote);

  @override
  Future<DriverPushMessage?> initialMessage() async {
    final m = await _messaging.getInitialMessage();
    return m == null ? null : driverPushFromRemote(m);
  }

  @override
  Stream<String> onTokenRefresh() => _messaging.onTokenRefresh;
}

/// Parses FCM data. Backend sends both camelCase and snake_case (`rideId` /
/// `ride_id`, `deep_link`) so a missed schema never silently drops the wake-up.
DriverPushMessage driverPushFromRemote(RemoteMessage m) {
  final data = m.data;
  String? str(String key) {
    final v = data[key];
    if (v is! String || v.isEmpty) return null;
    return v;
  }

  final rideId = str('ride_id') ?? str('rideId');
  final deepLink =
      str('deep_link') ??
      str('deepLink') ??
      (str('type') == 'ride_offer' ? '/offer' : null);
  return DriverPushMessage(
    notificationId: str('notification_id') ?? str('notificationId'),
    title: m.notification?.title ?? str('title'),
    body: m.notification?.body ?? str('body'),
    rideId: rideId,
    deepLink: deepLink,
    sentAt: m.sentTime,
  );
}

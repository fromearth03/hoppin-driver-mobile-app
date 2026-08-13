import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'driver_fcm_gateway.dart';

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
        AuthorizationStatus.provisional =>
          DriverFcmPermission.granted,
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
  ///
  /// 🔴 This is wired and correct, and it will simply never emit until the
  /// backend's `FCM_CREDENTIALS_FILE` lands (#15/#16). The parse is defensive
  /// because the push-event schema has never been published (#15): every field
  /// is optional and an unexpected payload degrades to a titleless message
  /// rather than throwing on the driver's device.
  @override
  Stream<DriverPushMessage> onMessage() {
    return FirebaseMessaging.onMessage.map((m) {
      final data = m.data;
      return DriverPushMessage(
        title: m.notification?.title ?? data['title'] as String?,
        body: m.notification?.body ?? data['body'] as String?,
        rideId: data['ride_id'] as String?,
        deepLink: data['deep_link'] as String?,
        sentAt: m.sentTime,
      );
    });
  }
}

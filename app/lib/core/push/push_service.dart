import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// FCM is the wake-up half of offer delivery: the service pushes a
/// high-priority "new ride request" heads-up (channel `ride_alerts`), and the
/// app treats the payload as a trigger only — the authoritative offer always
/// comes from `GET /drivers/me/offers`. The 5-second poll stays as the
/// safety net, so every path here is best-effort: a device without Google
/// services, a blocked token fetch, a failed registration — none of them may
/// cost the driver anything but the heads-up.
class PushService {
  final Ref _ref;

  bool _registered = false;
  String? _lastToken;

  /// Called when a ride-offer push lands with the app in the foreground —
  /// wired by the controller that owns the offer card.
  void Function()? onRideOffer;

  /// Called for every other foreground push: penalties, compliance notices,
  /// a ride ending underneath the driver.
  ///
  /// With the app open, FCM hands the payload to the client and shows the
  /// driver nothing — so without this, the news that costs them money is the
  /// news they never see. The shell turns it into a toast.
  void Function(PushAlert alert)? onAlert;

  PushService(this._ref);

  /// Boots Firebase once per process. Android reads google-services.json via
  /// the gms Gradle plugin, so no options object is needed. Web is skipped —
  /// browser push needs a VAPID key and a service worker this app does not
  /// carry.
  static Future<void> boot() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // No Firebase on this platform/build — the poll carries offers alone.
    }
  }

  /// Registers this device's FCM token with the ride service so offers can
  /// wake the app. Idempotent per token; safe to call on every sign-in and
  /// on each Home build.
  Future<void> register() async {
    if (kIsWeb) return;
    if (Firebase.apps.isEmpty) return; // boot() failed or never ran
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;
      if (!_registered || token != _lastToken) {
        await _post(token);
        _registered = true;
        _lastToken = token;
        messaging.onTokenRefresh.listen(_post);
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_onForegroundMessage);
      }
    } catch (_) {
      // No Google services on this device — the poll still delivers.
    }
  }

  Future<void> _post(String token) async {
    await _ref.read(apiClientProvider).post<dynamic>(
      '/me/device-tokens',
      body: {
        'fcm_token': token,
        'device_os':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      },
    );
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    if (type == 'ride_offer') {
      onRideOffer?.call();
      return;
    }

    // The service sends `alert` (title/body already written for a human) and
    // `ride_update` (a status change, with the ride it belongs to). Anything
    // else is ignored rather than guessed at.
    if (type != 'alert' && type != 'ride_update') return;

    final title = data['title'] ?? message.notification?.title ?? '';
    final body = data['body'] ?? message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    onAlert?.call(PushAlert(
      title: title.isEmpty ? 'Update' : title,
      body: body,
      rideId: data['ride_id'] ?? data['rideId'],
      deepLink: data['deep_link'],
      status: data['status'],
      // The service has no severity field, so it is read off the copy it did
      // send. A penalty is money already taken from the driver: it has to
      // outlast a four-second window, and guessing wrong the other way only
      // costs them a toast they must tap once.
      critical: _looksCritical('$title $body'),
    ));
  }

  /// Whether this reads as news the driver cannot afford to miss.
  static bool _looksCritical(String text) {
    final t = text.toLowerCase();
    const markers = [
      'penalt',
      'charge',
      'fee',
      'suspend',
      'block',
      'expir',
      'rejected',
      'cancel',
      'urgent',
      'debt',
    ];
    return markers.any(t.contains);
  }
}

/// One foreground push, reduced to what a toast needs.
class PushAlert {
  final String title;
  final String body;
  final String? rideId;
  final String? deepLink;
  final String? status;
  final bool critical;

  const PushAlert({
    required this.title,
    required this.body,
    this.rideId,
    this.deepLink,
    this.status,
    this.critical = false,
  });
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));

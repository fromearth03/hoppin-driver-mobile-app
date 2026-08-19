import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'driver_fcm_gateway.dart';

/// The outcome of a device-token registration attempt. Every value is a state
/// the app can HONESTLY report; none of them is a lie dressed as a success.
enum DriverTokenRegistration {
  /// A real FCM token was posted to `POST /me/device-tokens`.
  registered,

  /// The driver refused notification permission, or the OS gave us no token.
  /// Nothing was sent. **We do not invent one.**
  gatedNoToken,

  /// Desktop native (macOS/Windows/Linux) — no contract `device_os`.
  gatedNoPlatformValue,
}

/// Registers this device's FCM token against the driver's account.
///
/// 🔴 CALLED FROM AN EXPLICIT DRIVER ACTION (the GO tap), never from boot. Two
/// reasons, and the second is the important one:
///
///  1. An OS permission dialog thrown at a driver mid-junction is a hazard.
///  2. On Android 13+, `POST_NOTIFICATIONS` is what lets the **foreground
///     service's persistent notification** be seen at all — and that
///     notification is the OS's contract for keeping the heartbeat isolate
///     alive with the screen off. So the notification prompt is not a push
///     nicety here; it is part of the same breath as going online.
///
/// **What is BOUND and what is GATED, said plainly:**
///  - Registration: **BOUND.** `device_os: "android"` is a value the contract
///    already accepts. **Gap #69 does NOT block the driver** — it rejects only
///    `"web"`, which is why the rider (web) still cannot register and the
///    Android pivot UNBLOCKS the driver.
///  - Delivery: **GATED** on the backend's `FCM_CREDENTIALS_FILE` (#15/#16).
///    The server cannot send yet. A correctly-registered token that never
///    receives anything is the honest state of a wired client waiting on a
///    server — it is NOT a reason to draw a bell, a badge, or a "you'll be
///    notified" promise. **No badge over a dead handler.**
Future<DriverTokenRegistration> registerDriverDeviceToken({
  required DriverFcmGateway gateway,
  required ProfileRepository profiles,
  required bool isWeb,
  required TargetPlatform platform,
}) async {
  final deviceOs = driverContractDeviceOs(isWeb: isWeb, platform: platform);
  if (deviceOs == null) return DriverTokenRegistration.gatedNoPlatformValue;

  final permission = await gateway.requestPermission();
  if (permission != DriverFcmPermission.granted) {
    return DriverTokenRegistration.gatedNoToken;
  }

  final token = await gateway.token();
  if (token == null || token.isEmpty) {
    return DriverTokenRegistration.gatedNoToken;
  }

  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      await profiles.registerDeviceToken(fcmToken: token, deviceOs: deviceOs);
      return DriverTokenRegistration.registered;
    } on ApiException catch (error) {
      if (error.statusCode >= 400 && error.statusCode < 500) {
        return DriverTokenRegistration.gatedNoToken;
      }
    } on Exception {
      // Retry transient network/server failures below. Push registration must
      // never block presence, dispatch, or the driver's shift.
    }
    await Future<void>.delayed(Duration(seconds: attempt + 1));
  }
  return DriverTokenRegistration.gatedNoToken;
}

/// The `device_os` value the contract accepts for this platform, or `null` when
/// there is none. Browser builds send `"web"` — never a fake `"android"`.
String? driverContractDeviceOs({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return 'web';
  return switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => null,
  };
}

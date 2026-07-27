import 'package:flutter/foundation.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'driver_fcm_gateway.dart';

/// The outcome of a device-token registration attempt. Every value is a state
/// the app can HONESTLY report; none of them is a lie dressed as a success.
enum DriverTokenRegistration {
  /// A real FCM token was posted to `POST /me/device-tokens` with
  /// `device_os: "android"`. **This is BOUND and it really works.**
  registered,

  /// The driver refused notification permission, or the OS gave us no token.
  /// Nothing was sent. **We do not invent one.**
  gatedNoToken,

  /// This is not a platform the contract has a `device_os` value for.
  ///
  /// 🔴 THE ONE THAT MUST NOT BE CHEATED. `device_os` validates against
  /// `{ios, android}` (#69). A web build of this app — or a desktop dev run —
  /// has NO honest value to send, and the correct behaviour is to send NOTHING.
  /// Passing `"android"` from a browser to get past the validator would file a
  /// device that can never receive a push as one that can, and dispatch would
  /// believe it. The rider app refuses exactly this, on exactly these grounds.
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

  try {
    await profiles.registerDeviceToken(fcmToken: token, deviceOs: deviceOs);
    return DriverTokenRegistration.registered;
  } on Exception {
    // A failed registration is a push the driver will not get. It is NOT a
    // reason to fail the GO tap: presence, dispatch and the heartbeat are
    // entirely independent of push, and a driver blocked from working because a
    // notification token would not register would be an absurd defect.
    return DriverTokenRegistration.gatedNoToken;
  }
}

/// The `device_os` value the contract accepts for this platform, or `null` when
/// there is none.
///
/// `null` on web — deliberately, and **even when the browser's host OS reports
/// Android**. The platform there is the BROWSER, and the contract has no value
/// for it. Returning `'android'` would be a lie that the validator would happily
/// accept.
String? driverContractDeviceOs({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return null;
  return switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    // macOS / Windows / Linux / Fuchsia have no contract value either. A dev
    // running the driver app on a desktop registers nothing, and that is right.
    _ => null,
  };
}

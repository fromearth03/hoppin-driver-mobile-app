import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app's process alive while the driver is online.
///
/// 🔴 WITHOUT THIS THE DRIVER SILENTLY LEAVES THE DISPATCH POOL. Android stops
/// a backgrounded process within minutes — sooner on aggressive OEM builds
/// (Xiaomi, Oppo, Samsung) — and once it is stopped the location beat stops
/// with it. The app still shows "online" the next time the driver looks,
/// because nothing told it otherwise, so from their seat they are waiting for
/// offers that were never going to arrive.
///
/// A foreground service is the supported way to say "this process is doing
/// something the user asked for". The cost is a permanent notification, which
/// is the honest trade: the driver can see at a glance that their location is
/// being reported, and can stop it by going offline.
///
/// **This is not background location.** It runs only between going online and
/// going offline, and only with the notification visible. That keeps the app
/// clear of `ACCESS_BACKGROUND_LOCATION`, the Play Console declaration and
/// Apple's justification form — none of which we need, because a driver who
/// has closed the app is not on shift.
class ShiftService {
  const ShiftService();

  /// Android-only. iOS keeps the process alive through its own background
  /// location modes rather than a service, and calling this there is a no-op
  /// rather than an error so callers need no platform branch.
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Called once before the first start. Safe to call repeatedly.
  static void init() {
    if (!_supported) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hoppin_shift',
        channelName: 'On shift',
        // LOW, deliberately: this notification is a status line, not an
        // alert. IMPORTANCE_HIGH here would buzz the driver every time they
        // went online and compete with the ride-offer alert that genuinely
        // needs their attention.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        channelDescription:
            'Shown while you are online so ride offers can reach you.',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // The Dart beat owns its own timing; this only keeps the process
        // alive. An event interval here would be a second, competing clock.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Starts the service. Returns false when it could not start, so the caller
  /// can decide whether going online is honest.
  Future<bool> start() async {
    if (!_supported) return true;
    try {
      if (await FlutterForegroundTask.isRunningService) return true;
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'You are online',
        notificationText: 'Hoppin is sharing your location so you get offers.',
      );
      return result is ServiceRequestSuccess;
    } catch (_) {
      // A device that refuses the service still runs the beat while the app
      // is foregrounded, which is worse but not nothing.
      return false;
    }
  }

  Future<void> stop() async {
    if (!_supported) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Nothing to do: the process is going idle either way.
    }
  }

  /// Whether the OS will let us post the service notification.
  ///
  /// On Android 13+ a denied notification permission means the service cannot
  /// show its notification, and a foreground service without one is stopped.
  Future<bool> canPostNotification() async {
    if (!_supported) return true;
    try {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status == NotificationPermission.granted) return true;
      final asked = await FlutterForegroundTask.requestNotificationPermission();
      return asked == NotificationPermission.granted;
    } catch (_) {
      return false;
    }
  }
}

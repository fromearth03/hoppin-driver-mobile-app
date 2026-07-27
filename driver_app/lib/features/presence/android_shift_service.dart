import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'shift_service.dart';

/// The CONCRETE [DriverShiftService], over `flutter_foreground_task` (D6).
///
/// This is the ONLY file in the repository permitted to import
/// `package:flutter_foreground_task` — the isolation grep
/// (`grep -rn "flutter_foreground_task" packages/`) proves the plugin never
/// reaches `hoppin_shared` / `hoppin_ui` / `hoppin_demo`, and nothing above the
/// [DriverShiftService] seam imports it either. Every test in the driver app
/// gets [NoopDriverShiftService] for free, which is exactly what keeps
/// `flutter test` off a platform channel. If a test ever needs to mock a
/// MethodChannel, this boundary has leaked.
///
/// ── WHAT THIS DOES, AND THE ONE THING IT DOES NOT ────────────────────────────
///
/// It starts a **persistent notification** and holds a **wake lock**, which
/// together tell Android: this process is doing work the user asked for, do not
/// freeze its isolate and keep delivering it location. That is all. It does NOT
/// run the heartbeat — `PresenceInteractor`'s 20-second timer still does that,
/// in the app's own isolate, reading its fix through `DriverLocationService`.
///
/// That split is deliberate. `flutter_foreground_task` CAN run a separate
/// `TaskHandler` isolate, and it is tempting: a second isolate that owns the
/// ping. But a second isolate cannot see the Riverpod graph, cannot see the
/// Supabase session, and would need its own auth, its own repository and its own
/// copy of the "no fix means NO PING" rule — a second, divergent implementation
/// of the single most safety-critical loop in the app, with no test covering it.
/// One heartbeat. One rule. The service exists to keep it ALIVE, not to
/// duplicate it.
///
/// 🔴 ANDROID 14. `startService(serviceTypes: [ForegroundServiceTypes.location])`
/// must match `android:foregroundServiceType="location"` in the manifest AND the
/// `FOREGROUND_SERVICE_LOCATION` permission. Any of the three missing and
/// `startForeground()` throws at runtime — the app dies the instant the driver
/// taps GO. All three are in place; a manifest test pins them.
class AndroidDriverShiftService implements DriverShiftService {
  /// Creates the Android shift service. Constructed only from `main.dart`, and
  /// only on Android.
  AndroidDriverShiftService();

  /// The notification channel. Set once, on first use, for the life of the
  /// install — renaming it later is a no-op on Android 8+.
  static const String channelId = 'hoppin_driver_shift';

  bool _initialised = false;

  void _initOnce() {
    if (_initialised) return;
    _initialised = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: 'On shift',
        channelDescription:
            'Shows while you are online so Hoppin can keep sending your '
            'location to dispatch with the screen off.',
        // LOW, not DEFAULT: the notification must be PERSISTENT and VISIBLE
        // (that is the whole contract with the OS and with the driver), but it
        // must never buzz, chime, or peek over a moving-vehicle surface. The
        // driver sees it once when they go online and then it just sits there.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No repeat event: we run NO task-handler isolate at all (see above).
        // `nothing()` keeps the service alive without scheduling any callback.
        eventAction: ForegroundTaskEventAction.nothing(),

        // 🔴 THE WAKE LOCK. Without it Doze can stretch a 20-second heartbeat
        // into a several-minute one across an 8-hour shift, and 5 minutes
        // without a ping is a driver dropped from dispatch.
        allowWakeLock: true,

        // The heartbeat is a small HTTPS POST every 20s. Holding the Wi-Fi
        // radio awake for it would burn battery for nothing — the driver is on
        // mobile data in a car, not on Wi-Fi.
        allowWifiLock: false,

        // The OS killed us mid-shift (memory pressure, an OEM battery killer).
        // Come back: the driver never asked to go offline, and the server still
        // has them in the pool.
        allowAutoRestart: true,

        // 🔴 A DRIVER WHO SWIPES THE APP AWAY HAS NOT CLOCKED OFF. Dismissing
        // the task card must not end the shift — only "Go offline" does, which
        // is the only thing that calls `POST /drivers/me/offline`. If the
        // service died here, the driver would stay in the server's pool with no
        // heartbeat: the exact undispatchable-but-online state this whole phase
        // exists to delete.
        stopWithTask: false,

        // Deliberately NOT auto-run on boot. A phone that reboots at 3am must
        // not silently put its owner back on shift.
        autoRunOnBoot: false,
      ),
    );
  }

  @override
  Future<bool> start() async {
    try {
      _initOnce();
      if (await FlutterForegroundTask.isRunningService) return true;

      final result = await FlutterForegroundTask.startService(
        // 🔴 THE ANDROID-14 TYPE. Must match the manifest's
        // `foregroundServiceType="location"`. Without it, `startForeground()`
        // throws and the process dies on GO.
        serviceTypes: const [ForegroundServiceTypes.location],
        notificationTitle: 'On shift',
        notificationText:
            "You're online. Hoppin is sending your location to dispatch.",
      );
      // `ServiceRequestFailure` is a REAL, expected answer — notifications
      // denied, an OEM policy, a `startForeground` refusal. It is not an
      // exception to swallow: the caller raises the honest rung on it.
      return result is ServiceRequestSuccess;
    } catch (_) {
      // Deliberately bare, and deliberately `false`. Whatever went wrong, the
      // driver's shift is NOT protected in the background, and the only
      // dangerous answer here would be an optimistic `true`.
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Nothing to do and nothing to say: the driver has already tapped "Go
      // offline" and `POST /drivers/me/offline` is what actually removes them
      // from the pool. A stranded notification is a cosmetic wart, not a lie.
    }
  }

  @override
  Future<bool> isRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }
}

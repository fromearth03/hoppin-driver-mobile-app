import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/notifications/driver_fcm_gateway.dart';
import 'features/notifications/firebase_driver_fcm_gateway.dart';
import 'features/documents/upload/platform_avatar_picker.dart';
import 'features/presence/android_shift_service.dart';
import 'features/presence/presence_builder.dart';
import 'features/comms/real_url_launcher.dart';
import 'features/comms/url_launcher_gateway.dart' as comms;
import 'features/trip/trip_nav_handoff.dart' as nav;
import 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart';

/// Entry point for the Hoppin DRIVER app — **ANDROID** (D1).
///
/// The web target was DROPPED in v3.0 Phase 2, and not as a preference. A
/// browser tab cannot hold a driver's shift: geolocation is not exposed to
/// `ServiceWorkerGlobalScope` (the only web context that survives a backgrounded
/// tab) and the W3C declined to spec it; Chrome freezes hidden tabs and clamps
/// their timers to ~1/min; iOS Safari suspends `watchPosition` when backgrounded.
/// The server drops a driver from the dispatch pool after 5 minutes without a
/// ping. There is no web mitigation for that — not a hard one, NONE.
///
/// Run:
///   flutter run \
///     --dart-define=SUPABASE_URL=... \
///     --dart-define=SUPABASE_ANON_KEY=... \
///     --dart-define=RIDE_SERVICE_URL=http://10.0.2.2:8080/api/v1
///
/// (On the Android emulator, `localhost` is the EMULATOR. `10.0.2.2` is the host
/// machine — a `:8080` that works from a browser will silently fail from the
/// app, and it will look like an auth bug.)
///
/// The signed release command is documented in `apps/driver/README.md`.
Future<void> main() async {
  hoppinCaptureAuthLink();
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    // Web reset links must work even when the email is opened in another tab
    // or browser. PKCE's verifier is browser-local, so use an implicit token
    // callback on web while retaining PKCE for native authentication.
    authOptions: FlutterAuthClientOptions(
      authFlowType: kIsWeb ? AuthFlowType.implicit : AuthFlowType.pkce,
    ),
  );
  // After GoTrue has read `#access_token=` / `?code=` from the bar.
  hoppinUsePathUrlStrategy();

  // ── FCM (Phase 2) ──────────────────────────────────────────────────────────
  //
  // On Android the Firebase config is a FILE (`android/app/google-services.json`)
  // that the gradle plugin bakes into the APK's resources — NOT a set of
  // dart-defines like the rider's web build. So there is no compile-time flag to
  // test: we simply try, and we degrade honestly when there is no project.
  //
  // 🔴 THE `catch` IS LOAD-BEARING. `Firebase.initializeApp()` with no config
  // resources throws, and an unguarded `await` here — before `runApp()` — would
  // make the driver app fail to boot at all, on every machine that has not been
  // given the real `google-services.json`. Push is ADDITIVE; its absence is a
  // soft, honest GATED state, never a boot failure.
  //
  // The overrides below are the app's ONLY construction sites for the platform
  // gateways. Absent them, the providers keep their honest defaults —
  // `NoopDriverFcmGateway` (no token, no permission) and `NoopDriverShiftService`
  // (reports `false`, and MEANS it).
  var fcmReady = false;
  try {
    if (Env.fcmConfigured) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: Env.fcmApiKey,
          appId: Env.fcmAppId,
          messagingSenderId: Env.fcmSenderId,
          projectId: Env.fcmProjectId,
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    registerDriverBackgroundHandler();
    fcmReady = true;
  } catch (_) {
    // No Firebase config in this build. Push is additive; the app still runs.
  }

  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  runApp(ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      // 🔴 THE FOREGROUND SERVICE — what makes an 8-hour locked-screen shift
      // possible at all. Overridden ONLY on Android; every test, every other
      // platform, gets the no-op, which is what makes "no MethodChannel mocks
      // anywhere" structurally true rather than a promise.
      if (isAndroid)
        driverShiftServiceProvider.overrideWithValue(
          AndroidDriverShiftService(),
        ),
      if (fcmReady)
        driverFcmGatewayProvider.overrideWithValue(
          const FirebaseDriverFcmGateway(),
        ),
      // Profile-photo camera/gallery. `hoppin_shared` ships no default (it must
      // not depend on a plugin), so this is the only construction site of the
      // real picker; tests inject a plain Dart fake.
      avatarPickerProvider.overrideWithValue(PlatformAvatarPicker()),
      // The real URL launcher — the single construction site (isolation
      // contract). Wires payout onboarding, force-update, and the in-trip
      // Navigate hand-off (both lane providers) to the OS, not the no-op.
      comms.urlLauncherProvider.overrideWithValue(const RealUrlLauncher()),
      nav.urlLauncherProvider.overrideWithValue(const RealUrlLauncher()),
    ],
    child: const DriverApp(),
  ));
}

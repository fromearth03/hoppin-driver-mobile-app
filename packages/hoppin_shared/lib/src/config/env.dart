/// Runtime configuration for the Hoppin mobile apps.
///
/// Values are read from --dart-define at build time so no secrets are baked
/// into source. Example run command:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon-key> \
///   --dart-define=RIDE_SERVICE_URL=http://localhost:8080
/// ```
///
/// The ride-service base URL already includes the /api/v1 prefix that every
/// endpoint in docs/04-app-api-reference.md is relative to.
class Env {
  const Env._();

  /// Supabase project URL — used by the Supabase SDK for auth (GoTrue) and by
  /// the ride-service (server-side) to verify the JWT via JWKS.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon key — safe to ship in the client; RLS + JWT gate real access.
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The ride-service app API. Base already includes `/api/v1`.
  /// Defaults to the live service; override with --dart-define=RIDE_SERVICE_URL
  /// pointing at http://localhost:8080/api/v1 for local work.
  static const String rideServiceUrl = String.fromEnvironment(
    'RIDE_SERVICE_URL',
    defaultValue: 'https://api.hoppin.tech/api/v1',
  );

  /// This build's version, sent to `GET /app-status` so the server can decide
  /// whether it is below the required floor. Supplied via
  /// `--dart-define=APP_VERSION=x.y.z` at build time (the CI/release step reads
  /// it from pubspec); defaults to `0.0.0`, which the server treats as "behind
  /// everything" — a safe default, since an unversioned build SHOULD be nudged.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

  // ── FCM (NOTIF-01) ────────────────────────────────────────────────────────
  // The public Firebase web-app config. Safe to ship in the client (the VAPID
  // key is a *public* Web Push certificate), but supplied via --dart-define for
  // parity with SUPABASE_*. Absent → push is GATED and the app runs on the 3s
  // poll floor, exactly as it does today.

  /// Firebase web API key.
  static const String fcmApiKey = String.fromEnvironment('FCM_API_KEY');

  /// Firebase project id.
  static const String fcmProjectId = String.fromEnvironment('FCM_PROJECT_ID');

  /// Firebase messaging sender id.
  static const String fcmSenderId = String.fromEnvironment('FCM_SENDER_ID');

  /// Firebase web app id.
  static const String fcmAppId = String.fromEnvironment('FCM_APP_ID');

  /// The public Web Push certificate (VAPID key) passed to `getToken`.
  static const String fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  /// True only when a complete Firebase web-app config was compiled in.
  ///
  /// This GUARDS the single `Firebase.initializeApp()` call in `main.dart`. The
  /// app must boot, test, and demo with all five defines absent — which is the
  /// current state of the world. On web an unconfigured `initializeApp()` throws
  /// a bare `TypeError` (NOT a `FirebaseException`), and an unguarded `await` in
  /// `main()` before `runApp()` white-screens the app. This compile-time flag is
  /// the primary guard; a bare `catch (_)` is the backstop.
  static bool get fcmConfigured =>
      fcmApiKey.isNotEmpty &&
      fcmProjectId.isNotEmpty &&
      fcmSenderId.isNotEmpty &&
      fcmAppId.isNotEmpty &&
      fcmVapidKey.isNotEmpty;

  /// Fail fast in main() if the app was built without the required defines.
  ///
  /// SUPABASE ONLY, deliberately. FCM is NOT asserted here and must never be:
  /// push is ADDITIVE over the 3s poll floor, so its absence is a soft, honest
  /// GATED state — never a boot failure.
  static void assertConfigured() {
    assert(
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty,
      'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Pass them via --dart-define. '
      'See packages/hoppin_shared/lib/src/config/env.dart.',
    );
  }
}

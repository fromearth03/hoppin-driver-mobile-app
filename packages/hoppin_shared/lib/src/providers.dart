import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/api_client.dart';
import 'auth/auth_service.dart';
import 'repositories/ads_repository.dart';
import 'repositories/driver_repository.dart';
import 'repositories/payments_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/notifications_repository.dart';
import 'repositories/rides_repository.dart';
import 'repositories/safety_repository.dart';
import 'repositories/support_repository.dart';

/// Riverpod dependency graph for the shared core. Both apps read these; the
/// driver app additionally uses [driverRepositoryProvider].
///
/// Riverpod primer (for newcomers): a "provider" is a lazily-created singleton
/// that other providers/widgets can `ref.watch` or `ref.read`. Changing one
/// rebuilds only what depends on it. This file is the composition root.

/// The Supabase client. `Supabase.initialize(...)` must run in main() first.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth wrapper (GoTrue). Exposes token, role, sign-in/out.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});

/// The HTTP client to the ride-service. Injects the bearer token per request.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(auth: ref.watch(authServiceProvider));
});

/// Streams auth changes — routers watch this to redirect signed-in/out.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).onAuthStateChange;
});

/// Auth headers for loading an image from an authenticated API route.
///
/// Profile photos are served by `GET /api/v1/images/*path`, which requires a
/// bearer token — the object store behind it is private. A plain
/// `Image.network` sends no header and 401s, which renders identically to "no
/// photo set", so the failure is silent. Pass this to `HopAvatar.headers`.
///
/// Deliberately NOT cached across a token refresh: it reads `accessToken` at
/// call time, so a widget rebuilt after a refresh picks up the fresh bearer.
/// Empty when signed out — the avatar then shows its initials fallback.
///
/// Resolving the token is guarded because [authServiceProvider] reaches through
/// to `Supabase.instance`, which ASSERTS when the SDK was never initialised —
/// as in widget tests and the demo composition, neither of which calls
/// `Supabase.initialize`. An avatar must degrade to its initials there, never
/// take the whole screen down with a ProviderException.
final imageAuthHeadersProvider = Provider<Map<String, String>>((ref) {
  String? token;
  try {
    token = ref.watch(authServiceProvider).accessToken;
  } catch (_) {
    return const {};
  }
  return token == null ? const {} : {'Authorization': 'Bearer $token'};
});

/// Initial credentials for the login form. Null in production (fields
/// start empty); the demo composition overrides this with seeded
/// credentials so sign-in is a single tap.
final loginPrefillProvider = Provider<({String email, String password})?>(
  (_) => null,
);

// ── Feature repositories ────────────────────────────────────────────────────

final ridesRepositoryProvider = Provider<RidesRepository>((ref) {
  return RidesRepository(ref.watch(apiClientProvider));
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(apiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final profileSnapshotProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(ref.watch(apiClientProvider));
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepository(ref.watch(apiClientProvider));
});

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(ref.watch(apiClientProvider));
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

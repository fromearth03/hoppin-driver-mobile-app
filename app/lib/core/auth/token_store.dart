import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supplies the bearer token for ride-service calls.
///
/// This deliberately holds no state. `supabase_flutter` persists and
/// refreshes the session already; a second copy here could only drift out
/// of date and start sending an expired token.
abstract class TokenStore {
  Future<String?> read();
}

/// Production: asks the Supabase SDK for its current access token.
class CallbackTokenStore implements TokenStore {
  final String? Function() _source;
  CallbackTokenStore(this._source);

  @override
  Future<String?> read() async => _source();
}

/// Test double.
class InMemoryTokenStore implements TokenStore {
  final String? token;
  InMemoryTokenStore([this.token]);

  @override
  Future<String?> read() async => token;
}

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Reads the access token, refreshing it first when it has expired.
///
/// 🔴 `currentSession?.accessToken` HANDS BACK A DEAD TOKEN. The SDK refreshes
/// on a timer, not when you read — so a session that expired while the app was
/// backgrounded, or whose scheduled refresh failed (no network at the moment
/// it fired), keeps returning the stale token. Every call then 401s, forever,
/// and the driver cannot get out of it by pulling to refresh or by signing in
/// again, because the sign-in they perform is not what the interceptor reads.
class SupabaseTokenStore implements TokenStore {
  SupabaseTokenStore(this._source);

  /// Resolved per call, not at construction. Reading the client eagerly makes
  /// every test that touches the API client require a live Supabase, which is
  /// the opposite of what this seam exists for.
  final SupabaseClient Function() _source;

  @override
  Future<String?> read() async {
    final client = _source();
    final session = client.auth.currentSession;
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;
    try {
      final refreshed = await client.auth.refreshSession();
      return refreshed.session?.accessToken;
    } catch (_) {
      // Refresh genuinely failed — the refresh token is spent or revoked.
      // Returning the expired token would only produce another 401; null
      // lets the caller treat this as signed out, which it is.
      return null;
    }
  }
}

final tokenStoreProvider = Provider<TokenStore>(
    (ref) => SupabaseTokenStore(() => ref.read(supabaseClientProvider)));

/// The signed-in driver's user id, or null when signed out.
///
/// A narrow seam over the SDK: controllers that need the id should not have
/// to stand up Supabase to be tested, and reaching for the whole client
/// makes them untestable without initialising it.
final currentUserIdProvider = Provider<String?>(
    (ref) => ref.watch(supabaseClientProvider).auth.currentSession?.user.id);

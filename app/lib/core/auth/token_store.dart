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

final tokenStoreProvider = Provider<TokenStore>((ref) => CallbackTokenStore(
    () => ref.read(supabaseClientProvider).auth.currentSession?.accessToken));

/// The signed-in driver's user id, or null when signed out.
///
/// A narrow seam over the SDK: controllers that need the id should not have
/// to stand up Supabase to be tested, and reaching for the whole client
/// makes them untestable without initialising it.
final currentUserIdProvider = Provider<String?>(
    (ref) => ref.watch(supabaseClientProvider).auth.currentSession?.user.id);

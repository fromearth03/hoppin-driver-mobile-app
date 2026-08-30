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

import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A test double for [AuthService] that records the seams the 401→refresh→retry
/// interceptor drives — `refreshSession()` and `signOut()` — without touching
/// Supabase. It subclasses the real service (passing a throwaway client that is
/// never called) so it satisfies the [ApiClient] constructor's type.
class FakeAuthService extends AuthService {
  FakeAuthService({
    String? initialToken = 'expired-token',
    this.refreshFails = false,
    this.newToken = 'fresh-token',
  })  : _token = initialToken,
        super(SupabaseClient('http://localhost:54321', 'test-key'));

  /// When true, [refreshSession] throws — the interceptor must then sign out.
  final bool refreshFails;

  /// The token installed after a successful refresh.
  final String newToken;

  String? _token;

  int refreshCount = 0;
  int signOutCount = 0;

  @override
  String? get accessToken => _token;

  @override
  bool get isSignedIn => _token != null;

  @override
  Future<void> refreshSession() async {
    refreshCount++;
    // Simulate real refresh latency so concurrent 401s genuinely overlap and
    // the single-flight Completer is exercised.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (refreshFails) {
      throw const AuthException('refresh token reuse');
    }
    _token = newToken;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _token = null;
  }
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/result.dart';

/// Wraps `supabase_flutter`'s auth client so the rest of the app sees the
/// same `Result` + `{code}` contract it uses for the ride service.
///
/// The SDK owns refresh and persistence — nothing here re-implements them.
class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<Result<Session>> signIn(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final session = response.session;
      if (session == null) {
        return Err(ApiException('AUTH_FAILED', 'no session returned', 0));
      }
      return Ok(session);
    } on AuthException catch (e) {
      return Err(_map(e));
    } catch (e) {
      return Err(ApiException('INTERNAL', e.toString(), 0));
    }
  }

  /// Registers a driver.
  ///
  /// The metadata key is **`signup_role`**, never `role`: a `role` key is
  /// reserved for the admin/invite flows and makes the database trigger skip
  /// the user entirely, leaving an account that is neither rider nor driver.
  ///
  /// The trigger creates the driver restricted by construction — pending, not
  /// active on the platform — so an admin still has to approve them.
  Future<Result<AuthResponse>> signUpDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'signup_role': 'driver',
          'full_name': fullName.trim(),
          'phone': phone.trim(),
        },
      );
      return Ok(response);
    } on AuthException catch (e) {
      return Err(_map(e));
    } catch (e) {
      return Err(ApiException('INTERNAL', e.toString(), 0));
    }
  }

  /// The role the service actually gave this account, read from the
  /// `user_role` claim on the access token.
  ///
  /// Driver registration has an admin kill-switch. With it off, a driver
  /// signup silently becomes a **rider** rather than an orphan account — so
  /// asking for a driver account is not proof of getting one, and the app has
  /// to check rather than assume.
  String? get currentRole {
    final token = _auth.currentSession?.accessToken;
    if (token == null) return null;
    try {
      // Read the claim directly rather than taking a dependency for one
      // field. This is not verification — the token was just issued to us by
      // the SDK over TLS, and every request is authorised server-side anyway.
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return (jsonDecode(payload) as Map<String, dynamic>)['user_role']
          as String?;
    } catch (_) {
      // A token we cannot read is not a driver claim we can trust.
      return null;
    }
  }

  /// Claims the single live session the backend allows per account.
  ///
  /// The service keeps one `active_session_id` per user and answers every
  /// other session with 401 SESSION_REPLACED. Without this call the row
  /// still names whichever session claimed it last — an old build, another
  /// tab — so a freshly signed-in driver is refused on every request and
  /// the app looks like it cannot reach the backend at all.
  ///
  /// Best-effort: a failure here must not strand a driver who has just
  /// authenticated successfully.
  Future<void> claimSession(ApiClient api) async {
    await api.post<dynamic>('/me/session');
  }

  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
      return const Ok(null);
    } on AuthException catch (e) {
      return Err(_map(e));
    } catch (e) {
      return Err(ApiException('INTERNAL', e.toString(), 0));
    }
  }

  /// Called on the recovery screen — the SDK has already exchanged the
  /// emailed link for a session by the time the driver types a new password.
  Future<Result<void>> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      return const Ok(null);
    } on AuthException catch (e) {
      return Err(_map(e));
    } catch (e) {
      return Err(ApiException('INTERNAL', e.toString(), 0));
    }
  }

  /// Always reports success: the SDK clears local state before the network
  /// call, so a server error leaves the driver signed out locally, which is
  /// the outcome they asked for.
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Intentionally swallowed — see above.
    }
    return const Ok(null);
  }

  ApiException _map(AuthException e) {
    final status = int.tryParse(e.statusCode ?? '') ?? 0;
    final message = e.message.toLowerCase();

    if (status == 429 || message.contains('rate limit')) {
      return ApiException('TOO_MANY_ATTEMPTS', e.message, status);
    }
    if (message.contains('expired') || message.contains('invalid token')) {
      return ApiException('EXPIRED_LINK', e.message, status);
    }
    if (status == 400 || message.contains('invalid login')) {
      return ApiException('INVALID_CREDENTIALS', e.message, status);
    }
    if (status >= 500) return ApiException('INTERNAL', e.message, status);
    return ApiException('AUTH_FAILED', e.message, status);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => AuthRepository(ref.watch(supabaseClientProvider)));

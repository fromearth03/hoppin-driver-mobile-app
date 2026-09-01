import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/device/device_identity.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/result.dart';

/// The same build-time defines main.dart boots Supabase with — the raw
/// password-reset request signs itself with them.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Wraps `supabase_flutter`'s auth client so the rest of the app sees the
/// same `Result` + `{code}` contract it uses for the ride service.
///
/// The SDK owns refresh and persistence — nothing here re-implements them.
class AuthRepository {
  final SupabaseClient _client;

  /// The reset request bypasses the SDK on purpose (see
  /// [requestPasswordReset]); injectable so tests can stub the transport.
  final Dio _resetDio;

  AuthRepository(this._client, {Dio? resetDio}) : _resetDio = resetDio ?? Dio();

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
    // Same beat, second half: the fingerprint ingest that fills the
    // admin's Device Fingerprints screen. The gate header alone blocks
    // blacklisted devices; this is what lets an operator SEE devices.
    // Best-effort like the claim — a failed ingest must not cost a login.
    await api.post<dynamic>('/me/device', body: {
      'device_hardware_id': DeviceIdentity.id,
      'operating_system': DeviceIdentity.operatingSystem,
      'app_version': DeviceIdentity.appVersion,
      'is_emulator': false,
    });
  }

  /// The Supabase project is shared with the admin panel, and the
  /// project-wide "Reset Password" template is the admin OTP email — the
  /// SDK's resetPasswordForEmail sends the WRONG mail. The magic-link
  /// template is the branded one, so this posts the raw OTP request. Raw
  /// Dio, not signInWithOtp: the SDK attaches PKCE, and a PKCE link only
  /// completes inside the app instance that minted it — but the driver
  /// opens the email in a browser. The plain token_hash link works
  /// anywhere, including the hosted reset page.
  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      final base = _supabaseUrl.replaceFirst(RegExp(r'/+$'), '');
      await _resetDio.post<void>(
        '$base/auth/v1/otp',
        queryParameters: {'redirect_to': passwordResetRedirect()},
        options: Options(headers: {
          'apikey': _supabaseAnonKey,
          'Content-Type': 'application/json',
        }),
        data: {
          'email': email.trim(),
          // Never sign someone up by a typo in the reset form.
          'create_user': false,
          'data': <String, dynamic>{},
        },
      );
      return const Ok(null);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status == 429) {
        return Err(ApiException('TOO_MANY_ATTEMPTS', '', status));
      }
      // The screen's copy never confirms whether the address exists; most
      // failures still resolve to the same neutral confirmation upstream.
      return Err(ApiException('AUTH_FAILED', e.message ?? '', status));
    } catch (e) {
      return Err(ApiException('INTERNAL', e.toString(), 0));
    }
  }

  /// Where the emailed link lands. Env override first, then the web
  /// build's own public origin, then the hosted production page (shared
  /// with riders — it is account-agnostic). Never localhost: GoTrue
  /// silently falls back to the project Site URL (the admin panel) for a
  /// redirect it refuses.
  static String passwordResetRedirect() {
    const configured = String.fromEnvironment('PASSWORD_RESET_REDIRECT');
    if (_isPublicUrl(configured)) return configured;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (_isPublicUrl(origin)) return '$origin/reset';
    }
    return 'https://rider.hoppin.tech/reset';
  }

  static bool _isPublicUrl(String url) {
    if (url.isEmpty) return false;
    final u = url.toLowerCase();
    if (u.contains('localhost') || u.contains('127.0.0.1')) return false;
    return u.startsWith('http://') || u.startsWith('https://');
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

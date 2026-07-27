import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_exception.dart';

/// Maps any failure surfaced to the UI to a message safe to show the user.
///
/// Handles three families:
///  * Supabase (GoTrue) auth failures — carry a machine `code`
///    (https://supabase.com/docs/guides/auth/debugging/error-codes); the
///    common ones are translated, the rest fall back to the server's own
///    message, which is generally readable.
///  * Ride-service failures ([ApiException]) — already display-ready
///    (docs/04 · Global conventions: `{ error, code }`).
///  * Anything else — a generic fallback.
String friendlyErrorMessage(Object error) {
  // Network-level auth failure (DNS, offline, timeout) — no code on these.
  if (error is AuthRetryableFetchException) {
    return "Can't reach the server — check your connection and try again.";
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'email_not_confirmed':
        return 'Please confirm your email first — check your inbox.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists — try signing in.';
      case 'weak_password':
        return 'That password is too weak — use at least 8 characters.';
      case 'over_request_rate_limit':
        return 'Too many attempts — wait a minute and try again.';
      case 'user_banned':
        return 'This account has been suspended. Contact support.';
      case 'signup_disabled':
        return 'Sign-ups are currently disabled. Contact support.';
      case 'otp_expired':
        return 'That code has expired — request a new one.';
    }
    return error.message;
  }
  if (error is ApiException) {
    if (error.code == 'NETWORK_ERROR') {
      return "Can't reach the server — check your connection and try again.";
    }
    return error.message;
  }
  // Defensive: a DioException that escaped ApiClient's unwrapping.
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return friendlyErrorMessage(inner);
    return "Can't reach the server — check your connection and try again.";
  }
  return 'Something went wrong. Please try again.';
}

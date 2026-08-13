import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'current_uri_stub.dart'
    if (dart.library.html) 'current_uri_web.dart';

/// The app role stamped into every Supabase JWT as the top-level `user_role`
/// claim by the custom access-token hook (docs/04 · Authentication §3).
enum AppRole { rider, driver, admin, unknown }

/// Wraps Supabase GoTrue auth for the mobile apps.
///
/// The apps authenticate DIRECTLY with Supabase — the ride-service does not
/// issue or refresh tokens; there is no `/auth/*` on `:8080`. It only verifies
/// the JWT you send. (docs/04 · Authentication.)
///
/// Rider sign-up self-provisions a `rider_profile` via DB triggers. Drivers are
/// provisioned by an admin and follow an emailed set-password invite — they
/// cannot self-register, so the driver app should NOT expose sign-up.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// The current session, or null if signed out.
  Session? get currentSession => _auth.currentSession;

  /// The current, non-expired access token to send as the Bearer on every
  /// ride-service call. Null when signed out.
  String? get accessToken => currentSession?.accessToken;

  bool get isSignedIn => currentSession != null;

  /// The signed-in user's id (JWT subject) — e.g. required by
  /// `PATCH /rides/:id/cancel` as `canceled_by_user_id`. Null when signed out.
  String? get userId => _auth.currentUser?.id;

  /// The signed-in user's display name, from the `full_name` user metadata
  /// that [signUpRider] writes at registration. Null when signed out, or when
  /// the account was created without one.
  ///
  /// The session's own metadata is the ONLY identity source the app has today:
  /// there is no `GET /me/profile` endpoint (gap #70 / SL-5). Anything the
  /// session does not itself carry — a city, an avatar — is simply **not
  /// knowable** and must NOT be invented. The Profile hub rendered a hardcoded
  /// placeholder name and city to every real user until Wave 0 (2026-07-12).
  ///
  /// What the session DOES carry is [email], [phone] and [createdAt]. Those are
  /// real facts, and the Personal Information screen (#70) shows exactly them
  /// and nothing more.
  String? get fullName =>
      _auth.currentUser?.userMetadata?['full_name'] as String?;

  /// The signed-in user's email (the account's own identifier). Null when
  /// signed out. Used as the honest fallback label when no [fullName] was set.
  String? get email => _auth.currentUser?.email;

  /// The signed-in user's phone number.
  ///
  /// **Only OTP-signup riders have one** — the email/password [signUpRider] path
  /// never sets it, so null is the honest and common case.
  ///
  /// Consumers must **OMIT** the field rather than render a placeholder or a
  /// dash. *"We cannot tell you"* is not *"you have not filled this in"*, and a
  /// dashed row says the second while meaning the first.
  String? get phone => _auth.currentUser?.phone;

  /// When the account was created — a real fact the session already carries.
  ///
  /// The one thing beyond name / email / phone that the Personal Information
  /// screen (#70) can honestly show while `GET /me/profile` does not exist.
  DateTime? get createdAt =>
      DateTime.tryParse(_auth.currentUser?.createdAt ?? '');

  /// Emits on sign-in / sign-out / token-refresh. Drive routing off this.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// The app role the backend gates on.
  ///
  /// Canonical source is the top-level `user_role` claim the
  /// `custom_access_token_hook` stamps into the JWT from `public.users.role`.
  /// Being top-level, it is NOT exposed on `appMetadata`/`userMetadata`, so it
  /// can only be read by decoding the access token. Fallback: the `role` key
  /// that admin (`app_metadata`) and driver (`user_metadata`) provisioning
  /// writes — so a role still resolves if the hook ever fails to stamp.
  AppRole get role {
    final claim = _jwtRole() ??
        _auth.currentUser?.appMetadata['role'] as String? ??
        _auth.currentUser?.userMetadata?['role'] as String?;
    switch (claim) {
      case 'rider':
        return AppRole.rider;
      case 'driver':
        return AppRole.driver;
      case 'admin':
        return AppRole.admin;
      default:
        return AppRole.unknown;
    }
  }

  /// Decodes the top-level `user_role` claim out of the current access-token
  /// JWT. Null when signed out or the token is malformed.
  String? _jwtRole() {
    final token = accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final role = payload['user_role'];
      return role is String && role.isNotEmpty ? role : null;
    } catch (_) {
      return null;
    }
  }

  /// Rider self-sign-up (email/password). Role defaults to `rider`; the DB
  /// trigger auto-creates the rider_profile. Drivers do NOT use this.
  ///
  /// [fullName] is stored as user metadata (`full_name`) — harmless if the
  /// provisioning trigger ignores it, useful if it reads it.
  Future<AuthResponse> signUpRider({
    required String email,
    required String password,
    String? fullName,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      data: fullName == null ? null : {'full_name': fullName},
    );
  }

  /// Driver forgot-password. Do NOT use recover/resetPasswordForEmail — that
  /// hits the project-wide Reset Password template (admin OTP email).
  /// Magic-link is a separate template (a URL) and [emailRedirectTo] lands on
  /// THIS app's `/reset`, not the Supabase Site URL (admin/invite).
  Future<void> sendPasswordReset(String email) {
    return _auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: hoppinPasswordResetRedirect(),
    );
  }

  /// Sets a NEW password on the current (recovery/invite) session.
  Future<void> updatePassword(String newPassword) {
    return _auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  /// Phone/OTP start (docs/04 mentions the OTP grant path).
  Future<void> signInWithOtp({required String phone}) {
    return _auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) {
    return _auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<void> signOut() => _auth.signOut();

  /// Forces a session refresh against Supabase GoTrue.
  ///
  /// The SDK already auto-refreshes on a timer; this is the single seam the
  /// [ApiClient] 401→refresh→retry interceptor drives when a request fires with
  /// a token that expired between those timed refreshes. After it completes,
  /// [accessToken] re-reads the fresh bearer from [currentSession].
  Future<void> refreshSession() => _auth.refreshSession();
}

/// Where the reset email should send the user.
///
/// Never return localhost — GoTrue falls back to the project Site URL, which
/// was `http://localhost:5173` and opened the admin Vite port from a driver
/// reset email. Production default is driver.hoppin.tech.
String? hoppinPasswordResetRedirect() {
  const configured = String.fromEnvironment('PASSWORD_RESET_REDIRECT');
  if (_isPublicHoppinRedirect(configured)) return configured;
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (_isPublicHoppinOrigin(origin)) return '$origin/reset';
  }
  return 'https://driver.hoppin.tech/reset';
}

bool _isLocalRedirect(String url) {
  final u = url.toLowerCase();
  return u.contains('localhost') || u.contains('127.0.0.1');
}

bool _isPublicHoppinRedirect(String url) =>
    url.isNotEmpty && !_isLocalRedirect(url);

bool _isPublicHoppinOrigin(String origin) {
  if (origin.isEmpty || _isLocalRedirect(origin)) return false;
  return origin.startsWith('http://') || origin.startsWith('https://');
}

/// Invite / reset params from the route, the browser URL, or the hash fragment.
class HoppinAuthLink {
  const HoppinAuthLink({
    required this.tokenHash,
    required this.type,
    required this.code,
  });
  final String tokenHash;
  final String type;
  final String code;
  bool get isCallback =>
      tokenHash.isNotEmpty ||
      code.isNotEmpty ||
      type == 'recovery' ||
      type == 'invite' ||
      type == 'magiclink';
}

HoppinAuthLink? _capturedAuthLink;
bool _resetFlowConsumed = false;
bool _passwordJustUpdated = false;

HoppinAuthLink _parseAuthLink(Uri u) {
  String pick(String key) {
    final fromQuery = u.queryParameters[key];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    if (u.fragment.isEmpty) return '';
    // Hash router: `#/reset?token_hash=...` — query lives inside the fragment.
    final frag = u.fragment;
    final qIndex = frag.indexOf('?');
    final query = qIndex >= 0 ? frag.substring(qIndex + 1) : frag;
    final fromFrag = Uri.splitQueryString(query)[key];
    if (fromFrag != null && fromFrag.isNotEmpty) return fromFrag;
    return '';
  }

  return HoppinAuthLink(
    tokenHash: pick('token_hash'),
    type: pick('type'),
    code: pick('code'),
  );
}

/// Snapshot the invite/reset query BEFORE go_router rewrites `/reset?token_hash=`
/// into `/#/reset` and drops it. Call from `main()` before [Supabase.initialize].
void hoppinCaptureAuthLink([Uri? uri]) {
  final link = _parseAuthLink(uri ?? hoppinCurrentUri());
  if (link.isCallback) _capturedAuthLink = link;
}

@visibleForTesting
void hoppinClearCapturedAuthLink() {
  _capturedAuthLink = null;
  _resetFlowConsumed = false;
  _passwordJustUpdated = false;
}

/// Call after a successful (or already-set) password write so go_router stops
/// treating the spent invite URL as a live auth callback.
void hoppinMarkResetConsumed({bool passwordUpdated = false}) {
  _capturedAuthLink = null;
  _resetFlowConsumed = true;
  if (passwordUpdated) _passwordJustUpdated = true;
}

/// One-shot banner for the login screen after reset dumps them there signed-out.
bool hoppinTakePasswordUpdatedNotice() {
  final v = _passwordJustUpdated;
  _passwordJustUpdated = false;
  return v;
}

HoppinAuthLink hoppinAuthLinkParams([Uri? routeUri]) {
  final fromRoute = routeUri == null ? null : _parseAuthLink(routeUri);
  final fromBase = _parseAuthLink(hoppinCurrentUri());
  final fresh = (fromRoute != null && fromRoute.isCallback)
      ? fromRoute
      : fromBase.isCallback
          ? fromBase
          : fromRoute ?? fromBase;
  if (fresh.isCallback) _capturedAuthLink = fresh;
  return _capturedAuthLink ?? fresh;
}

/// Query string to keep on `/reset` so a go_router bounce does not drop the
/// one-time token before submit. PKCE `code` is omitted once we already have
/// a session — exchanging it twice is what made the link "expire on landing".
String hoppinResetRedirectQuery(Uri routeUri, {required bool signedIn}) {
  final link = hoppinAuthLinkParams(routeUri);
  final q = <String, String>{};
  if (link.tokenHash.isNotEmpty) q['token_hash'] = link.tokenHash;
  if (link.type.isNotEmpty) q['type'] = link.type;
  if (!signedIn && link.code.isNotEmpty) q['code'] = link.code;
  if (q.isEmpty) return '';
  return '?${Uri(queryParameters: q).query}';
}

/// True when this navigation (or the current web URL) is a Supabase recovery /
/// invite / magic-link callback and should open `/reset` instead of home/login.
bool hoppinIsAuthCallback(Uri routeUri) {
  if (_resetFlowConsumed) return false;
  if (_parseAuthLink(routeUri).isCallback) return true;
  return hoppinAuthLinkParams(routeUri).isCallback;
}

bool hoppinPasswordAlreadySet(Object error) {
  final code = error is AuthException ? (error.code ?? '') : '';
  if (code == 'same_password') return true;
  final raw = error is AuthException ? error.message : error.toString();
  final m = raw.toLowerCase();
  return m.contains('different from') || m.contains('same password');
}

/// Completes an invite/reset link on SUBMIT, not on first paint.
/// Prefetch / a second PKCE exchange on redirect was burning the one-time
/// token before the driver could type a password.
Future<void> hoppinEstablishResetSession({required bool alreadySignedIn}) async {
  final link = hoppinAuthLinkParams();
  if (link.tokenHash.isNotEmpty) {
    // A leftover browser session must not skip THIS invite token.
    if (alreadySignedIn) {
      await Supabase.instance.client.auth.signOut();
    }
    final type = switch (link.type) {
      'recovery' => OtpType.recovery,
      'invite' => OtpType.invite,
      'email' => OtpType.email,
      _ => OtpType.magiclink,
    };
    await Supabase.instance.client.auth.verifyOTP(
      tokenHash: link.tokenHash,
      type: type,
    );
    return;
  }
  if (alreadySignedIn) return;
  throw StateError('no reset session');
}

/// Honest copy: leaked/weak passwords were being labelled "expired link".
String hoppinResetErrorMessage(Object error) {
  final raw = error is AuthException ? error.message : error.toString();
  final m = raw.toLowerCase();
  if (m.contains('leak') ||
      m.contains('pwned') ||
      m.contains('weak') ||
      m.contains('too short') ||
      m.contains('characters')) {
    return 'That password is too weak or too common. Use letters, numbers and symbols — not 12345678.';
  }
  if (m.contains('no reset session') ||
      m.contains('expired') ||
      m.contains('invalid') ||
      m.contains('otp') ||
      m.contains('token')) {
    return 'This reset link has expired or is invalid. Request a new one from the sign-in screen.';
  }
  return raw.replaceFirst(RegExp(r'^(Exception|AuthException|StateError):\s*'), '');
}

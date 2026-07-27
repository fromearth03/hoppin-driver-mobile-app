import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// The app role, read from the `user_role` claim the backend gates on.
  AppRole get role {
    final claim =
        _auth.currentUser?.appMetadata['user_role'] as String? ??
        _auth.currentUser?.userMetadata?['user_role'] as String?;
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

  /// Sends a password-reset email (also used by drivers who forget theirs).
  /// Completing the reset opens a link — the in-app deep-link handler is
  /// pending platform config; until then the link lands on the Supabase
  /// project's configured site URL.
  Future<void> sendPasswordReset(String email) {
    return _auth.resetPasswordForEmail(email);
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

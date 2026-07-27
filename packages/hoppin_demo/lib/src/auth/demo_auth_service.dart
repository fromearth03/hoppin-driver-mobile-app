import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../seed/demo_seed.dart';
import '../seed/personas.dart';
import '../world/demo_world.dart';

/// The demo composition's auth surface — a gotrue-native stand-in for the
/// live [AuthService], satisfied entirely with public gotrue constructors
/// ([Session], [User], [AuthState], [AuthResponse]).
///
/// [AuthService] is a concrete class, but Dart implicit interfaces make
/// `implements` safe here: its private members (`_client`, `_auth`) are only
/// reachable from `auth_service.dart` itself, and every public member is
/// overridden below, so no code path can ever dispatch to the missing
/// privates.
///
/// The stream is a [BehaviorSubject] — the same mechanism gotrue itself uses
/// for `onAuthStateChange` — so the latest [AuthState] REPLAYS to every new
/// subscriber. The router's refresh listenable and the derived
/// `authStateProvider` both subscribe at their own moments (including after
/// an F5 restore) and always agree on the current state.
class DemoAuthService implements AuthService {
  /// Builds the auth surface for [persona] over [world]. When the world was
  /// restored already signed in (an F5 mid-demo), the subject seeds with a
  /// live session so boot lands past the login screen.
  DemoAuthService({required this.persona, required DemoWorld world})
      : _world = world {
    if (world.signedIn) {
      _session = _buildSession(persona.email);
    }
    _subject = BehaviorSubject<AuthState>.seeded(
      AuthState(AuthChangeEvent.initialSession, _session),
    );
  }

  /// The seeded identity this composition signs in as (rider or driver).
  final DemoPersona persona;

  final DemoWorld _world;
  late final BehaviorSubject<AuthState> _subject;
  Session? _session;

  /// The signed-in session for [email]. The access token is a plain opaque
  /// string, NOT a JWT: gotrue parses it lazily for `expiresAt`, catches the
  /// parse failure, and returns null — and `isExpired` is false when
  /// `expiresAt` is null (gotrue session.dart:78-95), so the demo session
  /// never expires mid-presentation.
  Session _buildSession(String email) {
    final user = User(
      id: persona.userId,
      appMetadata: {'user_role': persona.roleClaim},
      userMetadata: {'full_name': persona.fullName},
      aud: 'authenticated',
      email: email,
      createdAt: DemoSeed.anchor.toIso8601String(),
    );
    return Session(
      accessToken: 'demo-access-token',
      tokenType: 'bearer',
      user: user,
    );
  }

  @override
  Stream<AuthState> get onAuthStateChange => _subject.stream;

  @override
  Session? get currentSession => _session;

  @override
  String? get accessToken => _session?.accessToken;

  @override
  bool get isSignedIn => _session != null;

  @override
  String? get userId => _session?.user.id;

  /// The persona's display name. Mirrors the live path, which reads the
  /// `full_name` user metadata this service already seeds at :54 — so the
  /// Profile hub renders the signed-in persona in demo exactly as it renders
  /// the real rider on live. (Before Wave 0 it rendered a hardcoded
  /// "Clark Kent" to everyone, on both paths.)
  @override
  String? get fullName => _session == null ? null : persona.fullName;

  @override
  String? get email => _session == null ? null : persona.email;

  /// Always null. **This is correct, and it must stay null.**
  ///
  /// [DemoPersona] has no phone field, and inventing one here would make the
  /// demo *more* capable than live — where `phone` is null for every
  /// email/password signup, which is every rider the app creates. The Personal
  /// Information screen (#70) OMITS the row when this is null; seeding a
  /// plausible number would hide that branch behind a value that only exists in
  /// the demo, and the omit path would ship untested.
  ///
  /// The demo's job is to be honest about the same things live is honest about.
  @override
  String? get phone => null;

  /// Always null — the seeded persona has no creation timestamp, and the demo
  /// world's virtual clock is not an account age.
  ///
  /// Same rule as [phone]: the screen omits "Member since" when this is null,
  /// and a fabricated date here would mean the demo renders a row that live
  /// cannot. See [phone].
  @override
  DateTime? get createdAt => null;

  /// Reads the seeded persona, not JWT claims — there is no JWT to parse.
  @override
  AppRole get role => switch (persona.roleClaim) {
        'rider' => AppRole.rider,
        'driver' => AppRole.driver,
        'admin' => AppRole.admin,
        _ => AppRole.unknown,
      };

  /// Accepts whatever credentials arrive — the login form's validators
  /// already gate format upstream, and determinism beats gatekeeping in a
  /// demo. Marks the world signed in so the snapshot round-trips auth.
  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    _session = _buildSession(email);
    _world.markSignedIn();
    _subject.add(AuthState(AuthChangeEvent.signedIn, _session));
    return AuthResponse(session: _session);
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _world.markSignedOut();
    _subject.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  /// The demo session never expires (the opaque token has no `expiresAt`), so
  /// a refresh is a no-op that simply re-affirms the current session.
  @override
  Future<void> refreshSession() async {}

  // Unreachable on the demo path: the prefilled login only ever taps
  // Sign in. Each throws synchronously and self-explains.

  @override
  Future<AuthResponse> signUpRider({
    required String email,
    required String password,
    String? fullName,
  }) =>
      throw UnsupportedError('Not part of the demo');

  @override
  Future<void> sendPasswordReset(String email) =>
      throw UnsupportedError('Not part of the demo');

  @override
  Future<void> signInWithOtp({required String phone}) =>
      throw UnsupportedError('Not part of the demo');

  @override
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) =>
      throw UnsupportedError('Not part of the demo');
}

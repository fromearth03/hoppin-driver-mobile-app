import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DemoAuthService acceptance: a gotrue-native auth surface backed by a
/// replay-latest stream, so the router and authStateProvider always agree —
/// even for subscribers that arrive after sign-in (the F5 resume path).
void main() {
  DemoWorld riderWorld() =>
      DemoWorld.riderScenario(seed: DemoSeed.seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  DemoWorld driverWorld() =>
      DemoWorld.driverScenario(seed: DemoSeed.seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  DemoAuthService riderAuth(DemoWorld world) =>
      DemoAuthService(persona: DemoPersonas.rider, world: world);

  Future<AuthResponse> signIn(DemoAuthService auth) => auth.signInWithPassword(
        email: DemoSeed.riderCredentials.email,
        password: DemoSeed.riderCredentials.password,
      );

  test('fresh world starts signed out', () async {
    final auth = riderAuth(riderWorld());

    final first = await auth.onAuthStateChange.first;
    expect(first.event, AuthChangeEvent.initialSession);
    expect(first.session, isNull);
    expect(auth.isSignedIn, isFalse);
    expect(auth.currentSession, isNull);
    expect(auth.userId, isNull);
    expect(auth.accessToken, isNull);
  });

  test('signInWithPassword produces a signed-in gotrue session', () async {
    final auth = riderAuth(riderWorld());
    final events = <AuthState>[];
    final sub = auth.onAuthStateChange.listen(events.add);
    addTearDown(sub.cancel);

    final response = await signIn(auth);
    await pumpEventQueue();

    expect(response.session, isNotNull);
    expect(events.last.event, AuthChangeEvent.signedIn);
    expect(events.last.session, same(response.session));
    expect(auth.isSignedIn, isTrue);
    expect(auth.userId, DemoPersonas.rider.userId);
    expect(auth.role, AppRole.rider);
    // Opaque non-JWT token: expiresAt parses to null, so the session can
    // never read as expired mid-demo (gotrue session.dart:78-95).
    expect(response.session!.isExpired, isFalse);
  });

  test('driver persona signs in with the driver role', () async {
    final auth =
        DemoAuthService(persona: DemoPersonas.driver, world: driverWorld());

    final response = await auth.signInWithPassword(
      email: DemoSeed.driverCredentials.email,
      password: DemoSeed.driverCredentials.password,
    );

    expect(response.session, isNotNull);
    expect(auth.userId, DemoPersonas.driver.userId);
    expect(auth.role, AppRole.driver);
  });

  test('late subscriber replays current state', () async {
    final auth = riderAuth(riderWorld());
    await signIn(auth);

    // Subscribe AFTER sign-in: the first event this subscription sees must
    // already be the signed-in state (BehaviorSubject replay) — this is what
    // keeps the router and authStateProvider consistent after an F5.
    final first = await auth.onAuthStateChange.first;
    expect(first.event, AuthChangeEvent.signedIn);
    expect(first.session, isNotNull);
  });

  test('restored world boots signed in', () async {
    final world = riderWorld()..markSignedIn();

    final auth = riderAuth(world);

    expect(auth.isSignedIn, isTrue);
    expect(auth.currentSession, isNotNull);
    expect(auth.userId, DemoPersonas.rider.userId);
    final first = await auth.onAuthStateChange.first;
    expect(first.event, AuthChangeEvent.initialSession);
    expect(first.session, isNotNull);
  });

  test('signOut emits signedOut and clears the session', () async {
    final world = riderWorld();
    final auth = riderAuth(world);
    await signIn(auth);
    expect(world.signedIn, isTrue);

    await auth.signOut();

    expect(auth.isSignedIn, isFalse);
    expect(auth.currentSession, isNull);
    expect(auth.accessToken, isNull);
    expect(world.signedIn, isFalse, reason: 'markSignedOut must reach the world');
    final latest = await auth.onAuthStateChange.first;
    expect(latest.event, AuthChangeEvent.signedOut);
    expect(latest.session, isNull);
  });

  test('non-demo paths throw UnsupportedError', () {
    final auth = riderAuth(riderWorld());

    expect(
      () => auth.signUpRider(email: 'x@y.uk', password: 'pw'),
      throwsUnsupportedError,
    );
    expect(() => auth.sendPasswordReset('x@y.uk'), throwsUnsupportedError);
    expect(
      () => auth.signInWithOtp(phone: '+447700900123'),
      throwsUnsupportedError,
    );
    expect(
      () => auth.verifyOtp(phone: '+447700900123', token: '123456'),
      throwsUnsupportedError,
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 exports the Override type from misc.dart, not the main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

/// DEMO-02 acceptance: demo mode is composed ENTIRELY at the Riverpod root.
/// A container built with riderDemoOverrides()/driverDemoOverrides() resolves
/// every repository to its fake, arms the Supabase/network guards, prefills
/// the login, and reroutes the DERIVED authStateProvider — no widget ever
/// knows demo exists.
void main() {
  DemoWorld riderWorld() =>
      DemoWorld.riderScenario(seed: DemoSeed.seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  DemoWorld driverWorld() =>
      DemoWorld.driverScenario(seed: DemoSeed.seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  ProviderContainer containerWith(List<Override> overrides) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  /// The root cause must be a StateError ("Bad state:") whose message
  /// self-explains with 'Demo mode' — asserted on toString so the check
  /// holds whether or not Riverpod wraps init errors in ProviderException.
  Matcher throwsDemoGuard() => throwsA(
        predicate(
          (Object? e) => e.toString().contains('Bad state: Demo mode'),
          'a StateError whose message starts with "Demo mode"',
        ),
      );

  void expectFakeRepositories(ProviderContainer container) {
    expect(container.read(ridesRepositoryProvider),
        isA<FakeRidesRepository>());
    expect(container.read(driverRepositoryProvider),
        isA<FakeDriverRepository>());
    expect(container.read(profileRepositoryProvider),
        isA<FakeProfileRepository>());
    expect(container.read(safetyRepositoryProvider),
        isA<FakeSafetyRepository>());
    expect(container.read(supportRepositoryProvider),
        isA<FakeSupportRepository>());
    expect(container.read(paymentsRepositoryProvider),
        isA<FakePaymentsRepository>());
    expect(container.read(adsRepositoryProvider), isA<FakeAdsRepository>());
  }

  test('rider container resolves every repository provider to its fake', () {
    expectFakeRepositories(containerWith(riderDemoOverrides(riderWorld())));
  });

  test('driver container resolves every repository provider to its fake', () {
    expectFakeRepositories(containerWith(driverDemoOverrides(driverWorld())));
  });

  test('authServiceProvider resolves to DemoAuthService with the app persona',
      () {
    final rider = containerWith(riderDemoOverrides(riderWorld()));
    final riderAuth = rider.read(authServiceProvider);
    expect(riderAuth, isA<DemoAuthService>());
    expect(riderAuth.role, AppRole.rider);

    final driver = containerWith(driverDemoOverrides(driverWorld()));
    final driverAuth = driver.read(authServiceProvider);
    expect(driverAuth, isA<DemoAuthService>());
    expect(driverAuth.role, AppRole.driver);
  });

  test('supabaseClientProvider and apiClientProvider are guard-overridden',
      () {
    final container = containerWith(riderDemoOverrides(riderWorld()));

    expect(() => container.read(supabaseClientProvider), throwsDemoGuard());
    expect(() => container.read(apiClientProvider), throwsDemoGuard());
  });

  test('loginPrefillProvider serves the seeded credentials per app', () {
    final rider = containerWith(riderDemoOverrides(riderWorld()));
    expect(rider.read(loginPrefillProvider), DemoSeed.riderCredentials);

    final driver = containerWith(driverDemoOverrides(driverWorld()));
    expect(driver.read(loginPrefillProvider), DemoSeed.driverCredentials);
  });

  test(
      'authStateProvider (NOT overridden) streams demo auth events — '
      'the derived reroute needs zero extra overrides', () async {
    final container = containerWith(riderDemoOverrides(riderWorld()));

    // Listener subscribed BEFORE sign-in sees the event flow through...
    final states = <AsyncValue<AuthState>>[];
    final sub = container.listen(authStateProvider, (_, next) {
      states.add(next);
    });
    addTearDown(sub.close);

    await container.read(authServiceProvider).signInWithPassword(
          email: DemoSeed.riderCredentials.email,
          password: DemoSeed.riderCredentials.password,
        );

    // ...and a late `.future` read replays the current signed-in state.
    final state = await container.read(authStateProvider.future);
    expect(state.event, AuthChangeEvent.signedIn);
    expect(state.session, isNotNull);

    await pumpEventQueue();
    expect(
      states.any((s) => s.value?.event == AuthChangeEvent.signedIn),
      isTrue,
      reason: 'the derived stream must deliver the signedIn event',
    );
  });

  test('the composition surface is exactly 12 overrides per app', () {
    // 11 original + avatarPickerProvider (the camera/gallery seam, added when
    // profile-photo upload was wired — the live provider throws when
    // unoverridden, so the demo MUST supply a fake picker).
    expect(riderDemoOverrides(riderWorld()), hasLength(12));
    expect(driverDemoOverrides(driverWorld()), hasLength(12));
  });
}

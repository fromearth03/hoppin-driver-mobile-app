// Riverpod 3 exports the Override type from misc.dart, not the main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hoppin_shared/hoppin_shared.dart';

import 'auth/demo_auth_service.dart';
import 'fakes/fake_ads_repository.dart';
import 'fakes/fake_avatar_picker.dart';
import 'fakes/fake_driver_repository.dart';
import 'fakes/fake_payments_repository.dart';
import 'fakes/fake_profile_repository.dart';
import 'fakes/fake_rides_repository.dart';
import 'fakes/fake_safety_repository.dart';
import 'fakes/fake_support_repository.dart';
import 'seed/demo_seed.dart';
import 'seed/personas.dart';
import 'world/demo_world.dart';

/// The complete demo composition (DEMO-02): 11 overrides per app — the "~9"
/// of the requirement plus the per-app login prefill and ads fake.
/// Everything the demo changes about the app is in this list; no widget
/// knows demo exists.
///
/// Breakdown: 2 guards + 1 auth + 6 fake repositories (shared below) + 1
/// audience-stamped ads fake (per app) + 1 login prefill (per app).
/// `authStateProvider` is deliberately ABSENT — it is derived
/// (`ref.watch(authServiceProvider).onAuthStateChange`), so overriding the
/// auth service reroutes it for free.
List<Override> _commonOverrides(DemoWorld world, DemoAuthService auth) => [
      // Guards: nothing should ever reach these in demo mode. Their bodies
      // are lazy — they only run if a future regression watches one
      // directly, and then they fail loudly with a self-explaining error
      // instead of a cryptic "Supabase not initialized" crash.
      supabaseClientProvider.overrideWith(
        (ref) => throw StateError(
          'Demo mode: Supabase is never initialized. Something read '
          'supabaseClientProvider inside the demo composition — route it '
          'through a repository interface instead.',
        ),
      ),
      apiClientProvider.overrideWith(
        (ref) => throw StateError(
          'Demo mode: there is no network client. Something read '
          'apiClientProvider inside the demo composition — route it '
          'through a repository interface instead.',
        ),
      ),
      authServiceProvider.overrideWithValue(auth),
      ridesRepositoryProvider.overrideWithValue(FakeRidesRepository(world)),
      driverRepositoryProvider.overrideWithValue(FakeDriverRepository(world)),
      profileRepositoryProvider
          .overrideWithValue(FakeProfileRepository(world)),
      safetyRepositoryProvider.overrideWithValue(const FakeSafetyRepository()),
      supportRepositoryProvider
          .overrideWithValue(const FakeSupportRepository()),
      paymentsRepositoryProvider
          .overrideWithValue(FakePaymentsRepository(world)),
      // The camera/gallery seam. Required, not optional: the live provider
      // throws when unoverridden, so without this the first avatar tap in demo
      // mode crashes instead of demonstrating the upload.
      avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
    ];

/// The rider app's demo composition: Sophie Bell signs in over [world] with
/// the rider credentials prefilled. Pass this to the root `ProviderScope`
/// (or a `ProviderContainer`) — nothing else changes.
List<Override> riderDemoOverrides(DemoWorld world) => [
      ..._commonOverrides(
        world,
        DemoAuthService(persona: DemoPersonas.rider, world: world),
      ),
      // Live derives the ads audience from the JWT role — rider app: riders.
      adsRepositoryProvider
          .overrideWithValue(FakeAdsRepository(audience: 'riders')),
      loginPrefillProvider.overrideWithValue(DemoSeed.riderCredentials),
    ];

/// The driver app's demo composition: Gurpreet Singh signs in over [world]
/// with the driver credentials prefilled.
List<Override> driverDemoOverrides(DemoWorld world) => [
      ..._commonOverrides(
        world,
        DemoAuthService(persona: DemoPersonas.driver, world: world),
      ),
      // Ads target drivers too — driver app banners carry the drivers
      // audience, exactly what the role-derived live read would serve.
      adsRepositoryProvider
          .overrideWithValue(FakeAdsRepository(audience: 'drivers')),
      loginPrefillProvider.overrideWithValue(DemoSeed.driverCredentials),
    ];

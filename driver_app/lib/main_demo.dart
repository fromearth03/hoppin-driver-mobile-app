import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_demo/hoppin_demo.dart';

import 'app.dart';
import 'features/dashboard/eligibility_builder.dart';
import 'features/location/location_providers.dart';

/// Demo entry point for the Hoppin DRIVER app (DEMO-01).
///
/// Boots the full production shell on ZERO backend: no env asserts, no
/// backend client boot, no dart-defines, no network. The demo world seeds
/// deterministically and every repository is a fake driven by [DemoWorld].
///
/// Run:   flutter run -d chrome -t lib/main_demo.dart
/// Build: flutter build web -t lib/main_demo.dart
///
/// Reset (DEMO-06): reload with the query param BEFORE the hash —
///   http://host:PORT/?demo_reset=1#/
/// — which clears the session snapshot so boot lands on the fresh seed.
/// A plain F5 (no param) resumes exactly where the demo was. Phase 6 moves
/// reset into the control drawer via `world.reset()`.
///
/// Theme (DESIGN-02): `?theme=dark` / `?theme=light` forces the window's
/// ThemeMode — the D2 stage picture runs driver DARK beside rider LIGHT on
/// one machine. Absent param = follow the platform, same as live.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = SnapshotStore.forPlatform();
  if (Uri.base.queryParameters.containsKey('demo_reset')) {
    // Explicit reset beat: the presenter reloads with ?demo_reset=1.
    store.clear();
  }

  // Provider-level theme seam: parsed once before runApp, forced value
  // arrives as a root override. Views never branch on demo mode.
  final forcedTheme = switch (Uri.base.queryParameters['theme']) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => null,
  };

  final world = DemoWorld.driverScenario(seed: DemoSeed.seed, store: store)
    ..restoreOrSeed();

  // Same shell as live main.dart — only the overrides differ.
  runApp(ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      ...driverDemoOverrides(world),
      // The location seam is DRIVER-APP-LOCAL (the isolation contract keeps
      // geolocator out of hoppin_demo), so the demo double is overridden here
      // rather than inside `driverDemoOverrides`. The demo never prompts for
      // OS location and never depends on the presenting machine having GPS.
      driverLocationServiceProvider
          .overrideWithValue(const FakeDriverLocationService()),
      // 🔴 THE DEMO CLOCK IS THE DEMO'S ANCHOR, NOT THE WALL CLOCK.
      //
      // Every demo timestamp derives from `DemoSeed.anchor` (30 Jun 2026), and
      // the seeded MOT certificate expires 20 days after it — drawn that way on
      // purpose, to stage the RENEWAL-REMINDER beat.
      //
      // Compliance, though, compared those anchored documents against
      // `clock.now`. So on 20 Jul 2026 the reminder silently became an EXPIRY:
      // the eligibility gate did its job, refused to let the driver go online,
      // and the demo's whole loop died at the GO tap. Correct code, correct
      // gate, wrong clock — the fixture had a time bomb in it and the fuse was
      // exactly twenty days long.
      //
      // Pinning `now` to the anchor puts the demo back in its own time, where
      // the MOT is 20 days from renewal and stays there.
      nowProvider.overrideWithValue(() => DemoSeed.anchor),
      if (forcedTheme != null)
        themeModeProvider.overrideWith(
          () => DriverThemeModeController.forced(forcedTheme),
        ),
    ],
    child: const DriverApp(),
  ));
}

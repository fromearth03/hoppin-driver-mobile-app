import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/no_network_tile_provider.dart';

import '../../support/demo_clock.dart';

/// Router layer (riblet testing contract, DOCS/05) on the full demo
/// composition: /trip/:id mounts the runner, the arrivingHold holds
/// forever (DRIVER-03's calm beat — only the presenter's tap releases
/// it), and an F5 mid-trip resumes INTO the runner via the dashboard
/// router's activeRideId redirect. Bounded pumps — the world's timers
/// stall settle-detection.
void main() {
  Future<DemoWorld> boot(WidgetTester tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    // Backstop only: the world's timers outlive the widget tree, and the
    // binding checks !timersPending BEFORE addTearDown runs — any test
    // that ends with a world timer armed must call world.reset() itself.
    addTearDown(world.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...driverDemoOverrides(world),
        demoClockOverride,
        // The runner now carries the live MAP-04 canvas (demo geo flows) —
        // serve tiles from memory so no HTTP leaves the test.
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: const DriverApp(),
    ));
    await tester.pump();
    return world;
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpSeconds(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  /// goOnline → scripted offer (~5s) → accept directly on the world (the
  /// takeover UI is 03-05's). Returns the accepted ride's id.
  Future<String> driveToAccepted(WidgetTester tester, DemoWorld world) async {
    world.goOnline();
    await pumpSeconds(tester, 6);
    final offer = world.pendingOffers().single;
    world.acceptOffer(offer.offerId);
    return offer.rideId;
  }

  testWidgets('/trip/:id mounts the runner and the arrivingHold holds forever',
      (tester) async {
    final world = await boot(tester);
    await signIn(tester);
    final rideId = await driveToAccepted(tester, world);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DriverApp)),
      listen: false,
    );
    container.read(driverRouterProvider).go('/trip/$rideId');
    await tester.pump();
    await pumpSeconds(tester, 1);

    expect(find.byType(TripRunnerRiblet), findsOneWidget);
    expect(find.text('Head to Wolverhampton Rail Station'), findsOneWidget);
    expect(find.text('Sophie Bell'), findsOneWidget);
    expect(find.text('Arrived'), findsOneWidget);

    // The ETA counts 120→0 and floors at the calm hold.
    await pumpSeconds(tester, 122);
    expect(find.text('Arriving now'), findsOneWidget);

    // NOTHING advances until the presenter taps Arrived — the world holds
    // forever by design.
    await pumpSeconds(tester, 10);
    expect(find.byType(TripRunnerRiblet), findsOneWidget);
    expect(find.text('Arriving now'), findsOneWidget);
    expect(find.text('Arrived'), findsOneWidget);
  });

  testWidgets('F5 mid-trip resumes into the runner via the dashboard redirect',
      (tester) async {
    final world = await boot(tester);
    await signIn(tester);
    final rideId = await driveToAccepted(tester, world);

    // The F5: a fresh app tree over the SAME world. Boot lands signed-in
    // on '/', the dashboard router sees activeRideId in telemetry and
    // redirects straight into the runner.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...driverDemoOverrides(world),
        demoClockOverride,
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: const DriverApp(),
    ));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(TripRunnerRiblet), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DriverApp)),
      listen: false,
    );
    final router = container.read(driverRouterProvider);
    expect(router.state.matchedLocation, '/trip/$rideId');

    // Quiesce the world before the binding's timer invariant runs — the
    // accepted phase keeps the 1Hz ETA ticker armed (addTearDown is too
    // late for flutter_test's !timersPending check).
    world.reset();
    await tester.pump();
  });
}

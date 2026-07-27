import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/audio/offer_chime.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/no_network_tile_provider.dart';

import '../../support/demo_clock.dart';

/// Router layer (riblet testing contract, DOCS/05) on the full demo
/// composition: the DASHBOARD router attaches the takeover when the
/// world's scripted offer lands (~5s after GO), decline detaches and the
/// re-offer re-attaches (~4.2s), accept replaces the stack with the trip
/// runner, and an extra-less '/offer' (the F5 case) redirects home for
/// the attach listener to re-push. Bounded pumps — the world's timers
/// stall settle-detection.
void main() {
  Future<(DemoWorld, _RecordingChime)> boot(WidgetTester tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    // Backstop only — tests that end with world timers armed call
    // world.reset() themselves (the binding checks !timersPending BEFORE
    // addTearDown runs).
    addTearDown(world.reset);
    final chime = _RecordingChime();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...driverDemoOverrides(world),
        demoClockOverride,
        offerChimeProvider.overrideWithValue(chime),
        // The takeover inset + runner canvas render live demo geo now —
        // serve tiles from memory so no HTTP leaves the test.
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: const DriverApp(),
    ));
    await tester.pump();
    return (world, chime);
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

  GoRouterStateReader routerOf(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DriverApp)),
      listen: false,
    );
    return GoRouterStateReader(container);
  }

  testWidgets(
      'GO → takeover attaches OVER the dashboard with the chime; decline '
      'detaches and the re-offer re-attaches; accept lands in the runner',
      (tester) async {
    final (world, chime) = await boot(tester);
    await signIn(tester);
    expect(chime.playCalls, 0);

    // The presenter's GO tap — the scripted offer lands ~5s later and the
    // 1s offers poll mirrors it into dashboard state within a tick.
    await tester.tap(find.byType(GoButton));
    await pumpSeconds(tester, 7);

    // Attached: payout hero on screen, chime played at the entrance, and
    // the dashboard is STILL in the tree below (opaque: false).
    expect(find.text('£6.39'), findsOneWidget);
    expect(chime.playCalls, 1);
    expect(find.byType(DashboardRiblet), findsOneWidget);
    expect(routerOf(tester).matchedLocation, '/offer');
    final firstOfferId = world.pendingOffers().single.offerId;

    // Decline: the takeover slides away and '/' is interactive again.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Decline'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('£6.39'), findsNothing);
    expect(routerOf(tester).matchedLocation, '/');

    // The world re-offers the SAME trip with a FRESH offer id ~4.2s later;
    // the offerId compare re-attaches.
    await pumpSeconds(tester, 6);
    expect(find.text('£6.39'), findsOneWidget);
    expect(routerOf(tester).matchedLocation, '/offer');
    expect(world.pendingOffers().single.offerId, isNot(firstOfferId));
    expect(world.pendingOffers().single.rideId, isNotNull);

    // Accept: go replaces overlay + dashboard with the runner.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Accept'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Head to Wolverhampton Rail Station'), findsOneWidget);
    expect(routerOf(tester).matchedLocation, startsWith('/trip/'));

    // Quiesce the world before the binding's timer invariant runs — the
    // accepted phase keeps the 1Hz ETA ticker armed.
    world.reset();
    await tester.pump();
  });

  testWidgets("'/offer' without an offer extra redirects home (W4 F5 guard)",
      (tester) async {
    final (world, _) = await boot(tester);
    await signIn(tester);

    // The F5 shape: a FRESH navigation to /offer with state.extra == null
    // (a reload can never restore the pushed offer object).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DriverApp)),
      listen: false,
    );
    container.read(driverRouterProvider).go('/offer');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(routerOf(tester).matchedLocation, '/');
    expect(find.byType(DashboardRiblet), findsOneWidget);

    world.reset();
    await tester.pump();
  });
}

/// Reads the router's current location off the app's container.
class GoRouterStateReader {
  GoRouterStateReader(this._container);

  final ProviderContainer _container;

  String get matchedLocation =>
      _container.read(driverRouterProvider).state.matchedLocation;
}

/// Records prime/play without ever touching the audio plugin.
class _RecordingChime extends OfferChime {
  int primeCalls = 0;
  int playCalls = 0;

  @override
  Future<void> prime() async {
    primeCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }
}

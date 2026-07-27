import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/features/earned_moment/earned_moment_view.dart';
import 'package:hoppin_driver/features/rating/rider_rating_sheet.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/no_network_tile_provider.dart';

import '../../support/demo_clock.dart';

/// 🔴 REACHABILITY (Group-C/D): the rider-rating sheet must be CONSTRUCTED on a
/// real, reachable completed-trip path — not in a hand-built harness.
///
/// The riblet under `features/rating/` was fully built and BOUND to
/// `POST /rides/:id/rating`, and NOTHING outside `features/rating/` ever
/// referenced it. A driver completed a trip → earned-moment sheet → Done →
/// dashboard, and NEVER rated the rider. This test boots the real driver app,
/// drives a real trip to `completed` through the runner's OWN controls,
/// dismisses the earned-moment sheet, and asserts the rating sheet actually
/// appears. It FAILS on the un-mounted code.
///
/// The sheet is motion-gated (the demo location service reports no motion, so
/// the gate presents), skippable, and NEVER blocks the Done→dashboard exit —
/// those invariants are proven in `rating/rider_rating_test.dart`; this test
/// proves only that the sheet is REACHED at all.
///
/// Bounded pumps only — the world's timers stall settle-detection.
void main() {
  Future<DemoWorld> boot(WidgetTester tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    addTearDown(world.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...driverDemoOverrides(world),
        demoClockOverride,
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: const DriverApp(),
    ));
    await tester.pump();
    return world;
  }

  testWidgets(
      'the rider-rating sheet is REACHED after the completed-trip earned moment',
      (tester) async {
    final world = await boot(tester);

    // Sign in.
    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Go online, accept the scripted offer through the takeover UI.
    world.goOnline();
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Accept'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(TripRunnerRiblet), findsOneWidget,
        reason: 'accept lands on the runner');

    // Run the trip through the runner's OWN controls.
    await tester.tap(find.text('Arrived'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byIcon(Icons.chevron_right), const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byIcon(Icons.chevron_right), const Offset(600, 0));

    // The earned-moment sheet attaches once the payout is known.
    var earnedShown = false;
    for (var i = 0; i < 10 && !earnedShown; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      earnedShown = tester.any(find.text('You earned'));
    }
    expect(earnedShown, isTrue,
        reason: 'the earned-moment sheet must attach on completion');

    // Dismiss the earned-moment sheet: a tap anywhere skips to done, which
    // collapses the sheet and lands on the dashboard.
    await tester.tap(find.byType(EarnedCheck).first);

    // 🔴 THE ASSERTION: after the earned moment closes, the driver is offered
    // the rider-rating sheet. On today's code nothing mounts it, so this fails.
    var ratingShown = false;
    for (var i = 0; i < 24 && !ratingShown; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      ratingShown = tester.any(find.byType(RiderRatingSheetView));
    }
    expect(ratingShown, isTrue,
        reason: '🔴 the driver-rates-rider sheet must be REACHABLE on the '
            'completed-trip flow — it was fully built and never mounted');

    world.reset();
    await tester.pump();
  });
}

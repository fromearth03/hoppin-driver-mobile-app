import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'support/demo_clock.dart';

/// DEMO-01 + DEMO-05 acceptance for the driver app.
///
/// Boots the exact composition `main_demo.dart` assembles — a seeded
/// [DemoWorld] under [driverDemoOverrides] wrapping the production
/// [DriverApp] — with ZERO backend. The demo beat under test: boot lands on
/// the production-identical login with credentials prefilled, and ONE tap
/// on Sign in puts Gurpreet Singh on the dashboard riblet, still OFFLINE
/// with the seeded morning trio on screen — going online is a scripted
/// presenter beat, never an auto-fire.
void main() {
  testWidgets(
      'demo boot: prefilled login, one tap lands on the offline dashboard '
      'riblet with the seeded trio', (tester) async {
    // Same construction as main_demo.dart, with the test-safe store.
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();

    await tester.pumpWidget(ProviderScope(
      overrides: [...driverDemoOverrides(world), demoClockOverride],
      child: const DriverApp(),
    ));
    await tester.pump();

    // Signed out, so the router redirected '/' -> /login. Production
    // chrome: the driver wordmark lockup and the normal Sign in button.
    expect(find.text('Hoppin'), findsOneWidget);
    expect(find.text('DRIVER'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // Prefill (DEMO-05): both fields carry the seeded driver credentials.
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields, hasLength(2));
    expect(fields[0].controller!.text, DemoSeed.driverCredentials.email);
    expect(fields[1].controller!.text, DemoSeed.driverCredentials.password);

    // ONE tap, zero typing.
    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));

    // Bounded pumps (not pumpAndSettle): dashboard providers resolve off
    // the fakes; the world's timers would stall settle-detection.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Landed on the dashboard riblet, still offline (no auto-fired beats).
    expect(find.byType(DashboardRiblet), findsOneWidget);
    expect(find.text('Ready to drive?'), findsOneWidget);

    // Seeded-morning world intact AND on screen: £43.75 earned before the
    // demo starts, carried by the earnings tile trio (DRIVER-01 boot beat).
    expect(find.text('£43.75'), findsOneWidget);
    expect(world.todayEarningsPence, 4375);
    expect(world.signedIn, isTrue);
  });
}

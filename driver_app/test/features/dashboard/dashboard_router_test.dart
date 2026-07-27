import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/demo_clock.dart';

/// Router layer (riblet testing contract, DOCS/05): on the full demo
/// composition, the AppRiblet's auth-gated redirect + the riblet-composed
/// route table land the driver on the dashboard riblet at '/', and
/// sign-out hands navigation back to the login screen. Bounded pumps —
/// the GO pulse loops and the world's timers stall settle-detection.
void main() {
  Future<DemoWorld> boot(WidgetTester tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    await tester.pumpWidget(ProviderScope(
      overrides: [...driverDemoOverrides(world), demoClockOverride],
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

  testWidgets('signed-in boot lands on the dashboard riblet at /',
      (tester) async {
    await boot(tester);
    await signIn(tester);

    expect(find.byType(DashboardRiblet), findsOneWidget);
    expect(find.text('Ready to drive?'), findsOneWidget);
    expect(find.byType(GoButton), findsOneWidget);
    // Login chrome is gone — '/' owns the screen.
    expect(find.widgetWithText(HopButton, 'Sign in'), findsNothing);
  });

  testWidgets('sign-out returns to login (AppRiblet owns auth navigation)',
      (tester) async {
    await boot(tester);
    await signIn(tester);
    expect(find.byType(DashboardRiblet), findsOneWidget);

    // Sign-out ASKS first — a mis-tap must never end a live shift — so the
    // journey to login now runs through the confirmation. The destination
    // assertions below are unchanged: this still proves the AppRiblet's auth
    // redirect owns the navigation, end to end, through the real router.
    await tester.tap(find.byTooltip('Sign out'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(
      find.byType(HopPopup),
      findsOneWidget,
      reason: 'the logout tap must raise the confirmation, not sign out',
    );

    await tester.tap(find.text('Log out'), warnIfMissed: true);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(DashboardRiblet), findsNothing);
    expect(find.widgetWithText(HopButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('🔴 cancelling sign-out keeps the driver on the dashboard',
      (tester) async {
    await boot(tester);
    await signIn(tester);
    expect(find.byType(DashboardRiblet), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('Stay signed in'), warnIfMissed: true);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The shift survives against the REAL router and the REAL auth service —
    // the view-level stub cannot prove the redirect stayed put.
    expect(find.byType(DashboardRiblet), findsOneWidget);
    expect(find.widgetWithText(HopButton, 'Sign in'), findsNothing);
  });
}

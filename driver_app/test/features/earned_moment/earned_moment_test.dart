import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/features/earned_moment/earned_moment_builder.dart';
import 'package:hoppin_driver/features/earned_moment/earned_moment_interactor.dart';
import 'package:hoppin_driver/features/earned_moment/earned_moment_state.dart';
import 'package:hoppin_driver/features/earned_moment/earned_moment_view.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/demo_clock.dart';

/// The earned-moment riblet's three layers in one file (the riblet is
/// small): interactor timeline, view choreography, and the DRIVER-04
/// end-to-end — trip completed through the runner's own controls, the
/// 'You earned' sheet plays, collapses, and the dashboard tile absorbs
/// the same number. Bounded pumps only.
void main() {
  const rideId = 'ride-1';

  test('timeline auto-advances checkPop → countUp → done', () {
    FakeAsync().run((async) {
      final container = ProviderContainer();
      final sub =
          container.listen(earnedMomentInteractorProvider(rideId), (_, _) {});
      EarnedMomentState state() =>
          container.read(earnedMomentInteractorProvider(rideId));

      expect(state().phase, EarnedPhase.checkPop,
          reason: 'the sheet opens on the check pop');

      async.elapse(
        EarnedMomentInteractor.checkPopBeat + const Duration(milliseconds: 50),
      );
      expect(state().phase, EarnedPhase.countUp,
          reason: 'the timeline self-advances — it never waits for a figure');

      async.elapse(
        EarnedMomentInteractor.countUpBeat +
            EarnedMomentInteractor.holdBeat +
            const Duration(milliseconds: 100),
      );
      expect(state().phase, EarnedPhase.done,
          reason: 'the timeline reaches done, which is what collapses the '
              'sheet and returns the driver to the dashboard');

      sub.close();
      container.dispose();
    });
  });

  test('skip() jumps straight to done (tap-to-dismiss)', () {
    FakeAsync().run((async) {
      final container = ProviderContainer();
      final sub =
          container.listen(earnedMomentInteractorProvider(rideId), (_, _) {});

      container.read(earnedMomentInteractorProvider(rideId).notifier).skip();
      expect(
        container.read(earnedMomentInteractorProvider(rideId)).phase,
        EarnedPhase.done,
        reason: 'a tap anywhere skips the celebration and exits',
      );

      // The armed beat was cancelled — nothing fires later.
      async.elapse(const Duration(seconds: 3));
      expect(
        container.read(earnedMomentInteractorProvider(rideId)).phase,
        EarnedPhase.done,
        reason: 'the armed beat was cancelled — nothing fires after done',
      );

      sub.close();
      container.dispose();
    });
  });

  testWidgets('view choreography: check pop, £0.00 → £6.39 count-up',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // The payout is DECORATION the view watches off the runner.
        tripRunnerInteractorProvider(rideId).overrideWith(
          () => _StubRunner(payoutPence: 639),
        ),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const Scaffold(
          body: Center(child: EarnedMomentView(rideId: rideId)),
        ),
      ),
    ));
    await tester.pump();

    // t≈0: the check paint is on, the odometer reads zero.
    expect(find.byType(EarnedCheck), findsOneWidget,
        reason: 'the check pops on open');
    expect(find.text('£0.00'), findsOneWidget,
        reason: 'the odometer mounts at zero and counts UP to the payout');
    expect(find.text('You earned'), findsOneWidget,
        reason: 'a real figure gets the celebratory caption');

    // Past the check beat the count-up arms…
    await tester.pump(const Duration(milliseconds: 450));
    // …and past the count-up the payout reads whole.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('£6.39'), findsOneWidget,
        reason: 'the odometer lands on the whole payout');
    expect(find.text('You earned'), findsOneWidget,
        reason: 'the caption stays with the figure');
    expect(tester.takeException(), isNull,
        reason: 'the choreography must not throw');
  });

  // 🔴 THE LIVE SHAPE. `payoutPence` comes from the #7 (`todayStats()`) seam,
  // which answers null on EVERY live request — so this, not the test above, is
  // what a real Wolverhampton driver sees after every trip they finish.
  testWidgets('with NO figure the sheet still opens, and never fakes a number',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRunnerInteractorProvider(rideId).overrideWith(
          () => _StubRunner(), // payoutPence: null — the live case
        ),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const Scaffold(
          body: Center(child: EarnedMomentView(rideId: rideId)),
        ),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(find.byType(EarnedFigureUnavailable), findsOneWidget,
        reason: 'with no figure the sheet renders the designed #7 rung — it '
            'still OPENS, because it is the completed trip\'s only exit and an '
            'exit may not hang on a money figure');
    expect(find.text('Trip complete'), findsOneWidget,
        reason: 'it confirms the thing that IS true: the trip finished');

    expect(find.text('You earned'), findsNothing,
        reason: 'there is nothing to celebrate — we do not know the figure');
    expect(find.text('£0.00'), findsNothing,
        reason: '🔴 £0.00 is a LIE. It tells the driver they earned nothing, '
            'when the truth is that we do not know what they earned (D2: the '
            'driver app renders NO figure the server did not send)');
    expect(find.byType(MoneyTicker), findsNothing,
        reason: 'no odometer over a number that does not exist');
    expect(tester.takeException(), isNull,
        reason: 'the no-figure path must not throw');
  });

  testWidgets(
      'attach → dismiss → dashboard absorbs the payout (DRIVER-04 loop)',
      (tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    addTearDown(world.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [...driverDemoOverrides(world), demoClockOverride],
      child: const DriverApp(),
    ));
    await tester.pump();

    // Sign in, go online, accept the scripted offer through the takeover
    // riblet's own UI (03-05 — the offer now attaches over the dashboard).
    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    world.goOnline();
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('£6.39'), findsOneWidget,
        reason: 'the scripted offer must attach the takeover');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Accept'));

    // Accept replaces the stack with the runner.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(TripRunnerRiblet), findsOneWidget);

    // Run the trip through the runner's OWN controls: tap Arrived…
    await tester.tap(find.text('Arrived'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // …slide to start…
    await tester.drag(
      find.byIcon(Icons.chevron_right),
      const Offset(600, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // …slide to complete.
    await tester.drag(
      find.byIcon(Icons.chevron_right),
      const Offset(600, 0),
    );

    // The stats bump lands within one poll tick; the runner's router
    // attaches the sheet.
    var sheetShown = false;
    for (var i = 0; i < 8 && !sheetShown; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      sheetShown = tester.any(find.text('You earned'));
    }
    expect(sheetShown, isTrue,
        reason: 'the earned sheet must attach once the payout is known');

    // The sheet plays its full timeline (1.5s — the §5 success-moment
    // budget), collapses, and hands off to the dashboard where the absorb
    // chip rises.
    var chipShown = false;
    for (var i = 0; i < 24 && !chipShown; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      chipShown = tester.any(find.text('+£6.39'));
    }
    expect(chipShown, isTrue,
        reason: 'the dashboard must absorb the same number the sheet showed');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DriverApp)),
      listen: false,
    );
    expect(
      container.read(driverRouterProvider).state.matchedLocation,
      '/',
      reason: 'the sheet owns the collapse navigation back to the dashboard',
    );

    // The tile total ticks up to the new figure — the celebration number
    // becomes the dashboard number (300ms landing hold + 700ms tick, with
    // margin).
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('£50.14'), findsOneWidget);

    // Quiesce the world before the binding's timer invariant runs (the
    // post-complete idle re-arms the next scripted offer while online).
    world.reset();
    await tester.pump();
  });
}

/// A completed trip runner with (or, by default, WITHOUT) a payout figure —
/// the sheet's only dependency, and a pure decoration. It touches no repository
/// and starts no timer, so the sheet's own choreography is what is under test.
class _StubRunner extends TripRunnerInteractor {
  _StubRunner({this.payoutPence}) : super('ride-1');

  final int? payoutPence;

  @override
  TripRunnerState build() => TripRunnerState(
        rideId: 'ride-1',
        phase: TripPhase.completed,
        payoutPence: payoutPence,
      );
}

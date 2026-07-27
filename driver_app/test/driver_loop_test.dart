import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/audio/offer_chime.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'support/no_network_tile_provider.dart';

import 'support/demo_clock.dart';

/// THE Phase 3 acceptance: DRIVER-01..04 observable in ONE continuous run
/// on the exact main_demo composition — login → GO → chimed takeover →
/// decline/re-offer → accept → the arrivingHold that never auto-advances →
/// arrived → slide-start → slide-complete → 'You earned £6.39' → the
/// dashboard absorbs to £50.14 — and a SECOND offer arrives afterwards:
/// the shift continues, no dead end. Bounded pumps only (the world's
/// timers stall settle-detection); each pump block is commented with the
/// script beat it crosses.
void main() {
  testWidgets(
      'the full driver loop: login → GO → takeover → decline → re-offer → '
      'accept → hold → arrive → start → complete → earned → absorb → next offer',
      (tester) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
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

    String location() => ProviderScope.containerOf(
          tester.element(find.byType(DriverApp)),
          listen: false,
        ).read(driverRouterProvider).state.matchedLocation;

    Future<void> pumpSeconds(int seconds) async {
      for (var i = 0; i < seconds; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    Future<void> pumpMs(int times, int ms) async {
      for (var i = 0; i < times; i++) {
        await tester.pump(Duration(milliseconds: ms));
      }
    }

    // ── DRIVER-01: boot → prefilled login → ONE tap → seeded dashboard ──
    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));
    await pumpMs(8, 300); // auth + dashboard providers resolve off the fakes
    expect(find.text('Ready to drive?'), findsOneWidget);
    expect(find.text('£43.75'), findsOneWidget);
    expect(find.text('5 trips'), findsOneWidget);
    expect(chime.playCalls, 0, reason: 'no offer yet — no chime');

    // ── DRIVER-02: GO → online → the scripted offer takes the screen ──
    await tester.tap(find.byType(GoButton));
    await pumpSeconds(2); // telemetry confirms the online flip (~1s poll)
    expect(find.text("You're online"), findsOneWidget);

    await pumpSeconds(5); // offer beat ~5.0s + ≤1s offers poll → attach
    expect(find.text('£6.39'), findsOneWidget,
        reason: 'the payout hero IS the takeover');
    expect(location(), '/offer');
    final secondsText = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && RegExp(r'^\d+$').hasMatch(w.data!),
    );
    expect(secondsText, findsOneWidget,
        reason: 'the ring never renders without numeric seconds');
    expect(chime.playCalls, 1, reason: 'chime exactly once at the entrance');
    final firstOfferId = world.pendingOffers().single.offerId;

    // ── Decline → quiet detach → the SAME trip re-offers ~4.2s later ──
    await pumpMs(1, 400); // entrance settles
    await tester.tap(find.text('Decline'));
    await pumpMs(3, 150); // dismissal pop + reverse transition
    expect(find.text('£6.39'), findsNothing);
    expect(location(), '/');

    await pumpSeconds(6); // re-offer beat ~4.2s + ≤1s poll → re-attach
    expect(find.text('£6.39'), findsOneWidget);
    expect(location(), '/offer');
    expect(world.pendingOffers().single.offerId, isNot(firstOfferId),
        reason: 'the re-offer carries a FRESH offer id');
    expect(chime.playCalls, 2, reason: 'the re-offer chimes its own entrance');

    // ── Accept → the runner owns the screen ──
    await pumpMs(1, 400); // entrance settles
    await tester.tap(find.text('Accept'));
    await pumpMs(5, 300); // accept → go replaces overlay + dashboard
    expect(find.text('Head to Wolverhampton Rail Station'), findsOneWidget);
    expect(find.text('Sophie Bell'), findsOneWidget);
    expect(location(), startsWith('/trip/'));

    // ── DRIVER-03: the ETA runs 120→0 and HOLDS — never auto-advances ──
    await pumpSeconds(121); // the full en-route countdown, 1s bounded chunks
    expect(find.text('Arriving now'), findsOneWidget);
    await pumpSeconds(10); // …and NOTHING moves without the presenter
    expect(find.text('Arriving now'), findsOneWidget);
    expect(find.text('Arrived'), findsOneWidget,
        reason: 'the arrivingHold waits for the tap forever');

    // ── Arrived (tap) → waiting → slide to start → in trip ──
    await tester.tap(find.text('Arrived'));
    await pumpMs(2, 300); // morph beat
    expect(find.text('Waiting for Sophie'), findsOneWidget);

    await tester.drag(find.byIcon(Icons.chevron_right), const Offset(600, 0));
    await pumpMs(2, 300); // slide snap + morph beat
    expect(find.text('Trip in progress'), findsOneWidget);

    // ── DRIVER-04: slide to complete → 'You earned £6.39' ──
    await tester.drag(find.byIcon(Icons.chevron_right), const Offset(600, 0));
    var sheetShown = false;
    for (var i = 0; i < 8 && !sheetShown; i++) {
      await tester.pump(const Duration(milliseconds: 250)); // payout poll tick
      sheetShown = tester.any(find.text('You earned'));
    }
    expect(sheetShown, isTrue,
        reason: 'completion must attach the earned sheet');
    var payoutShown = false;
    for (var i = 0; i < 16 && !payoutShown; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // pop + count-up
      payoutShown = tester.any(find.text('£6.39'));
    }
    expect(payoutShown, isTrue,
        reason: 'the odometer lands on the whole payout');

    // ── The sheet collapses; the dashboard tile absorbs the same number ──
    var chipShown = false;
    for (var i = 0; i < 24 && !chipShown; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // hold + collapse
      chipShown = tester.any(find.text('+£6.39'));
    }
    expect(chipShown, isTrue,
        reason: 'the dashboard absorbs the number the sheet celebrated');
    expect(location(), '/');
    await pumpMs(10, 100); // tick-up 700ms after the 300ms landing delay
    expect(find.text('£50.14'), findsOneWidget);
    expect(find.text('6 trips'), findsOneWidget);

    // ── The shift continues: a SECOND offer arrives — no dead end ──
    // post-complete idle ~3s + offer arrival ~5s + ≤1s poll, minus the
    // ~2.4s the sheet/absorb pumps above already consumed.
    var nextOffer = false;
    for (var i = 0; i < 12 && !nextOffer; i++) {
      await tester.pump(const Duration(seconds: 1));
      nextOffer = tester.any(find.text('£6.39'));
    }
    expect(nextOffer, isTrue, reason: 'the shift continues past one trip');
    expect(location(), '/offer');
    expect(chime.playCalls, 3);

    // Quiesce the world before the binding's timer invariant runs — the
    // presenting phase keeps script timers armed.
    world.reset();
    await tester.pump();
  });
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

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/audio/offer_chime.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_builder.dart';
import 'package:hoppin_driver/features/offer_takeover/widgets/offer_reassigned_state.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/router.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/no_network_tile_provider.dart';

import '../../support/demo_clock.dart';

/// 🔴 THE OFFER ACCEPT IS SERVER-AUTHORITATIVE — THE CLIENT'S BELIEF IS NOT
/// THE TRUTH.
///
/// This file is the sabotage-verified proof of four invariants and their
/// three honest failure states:
///
///   O1  A double-tap fires EXACTLY ONE POST.        (already green — a fence)
///   O2  No navigation to /trip/ before the 200.     (already green — a fence)
///   O3  409 OFFER_EXPIRED → non-blaming, back to /. (RED until Task 2)
///   O4  403 NOT_ELIGIBLE → /documents, NO guess.    (RED until Task 2)
///   O5  403 FORBIDDEN is NOT NOT_ELIGIBLE.          (RED until Task 2)
///   O6  a past-expiresAt offer is REMOVED, not greyed — recomputed from
///       clock.now(), never trusting a (clamped) timer fired.
///   O7  SF-05 — the Decline control claims NOTHING about consequences.
///
/// The real `driverRouterProvider` is booted so every navigation assertion is
/// real. A recording driver repository captures the accept/decline calls and
/// scripts the throw. Bounded pumps only — NEVER `pumpAndSettle` (the driver
/// app's polling providers stall settle-detection forever).
void main() {
  RideOffer offer({
    DateTime? offeredAt,
    DateTime? expiresAt,
  }) =>
      RideOffer(
        offerId: 'offer-1',
        rideId: 'ride-1',
        pickupLat: 52.5875,
        pickupLng: -2.1288,
        dropoffLat: 52.5906,
        dropoffLng: -2.0929,
        fare: 6.39,
        estimatedMiles: 1.7,
        offeredAt: offeredAt ?? clock.now(),
        expiresAt: expiresAt ?? clock.now().add(const Duration(seconds: 45)),
      );

  /// Boots the FULL demo composition, then layers a recording driver
  /// repository OVER it (last override wins) so the takeover's accept path
  /// is scripted while every read still answers off the world.
  Future<(ProviderContainer, _RecordingDriverRepo, DemoWorld)> boot(
    WidgetTester tester,
  ) async {
    final world = DemoWorld.driverScenario(
      seed: DemoSeed.seed,
      store: InMemorySnapshotStore(),
    )..restoreOrSeed();
    addTearDown(world.reset);
    final repo = _RecordingDriverRepo(FakeDriverRepository(world));
    final auth = DemoAuthService(persona: DemoPersonas.driver, world: world);

    // The driver demo composition, hand-built so the driver repository is the
    // RECORDING one (Riverpod forbids overriding a provider twice in one
    // container, so we cannot spread driverDemoOverrides and re-override it).
    // Everything else answers off the world exactly as the demo does.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        demoClockOverride,
        ridesRepositoryProvider.overrideWithValue(FakeRidesRepository(world)),
        driverRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider
            .overrideWithValue(FakeProfileRepository(world)),
        safetyRepositoryProvider
            .overrideWithValue(const FakeSafetyRepository()),
        supportRepositoryProvider
            .overrideWithValue(const FakeSupportRepository()),
        paymentsRepositoryProvider
            .overrideWithValue(FakePaymentsRepository(world)),
        adsRepositoryProvider
            .overrideWithValue(FakeAdsRepository(audience: 'drivers')),
        loginPrefillProvider.overrideWithValue(DemoSeed.driverCredentials),
        offerChimeProvider.overrideWithValue(_SilentChime()),
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: const DriverApp(),
    ));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DriverApp)),
      listen: false,
    );
    return (container, repo, world);
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(HopButton, 'Sign in'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  String locationOf(ProviderContainer c) =>
      c.read(driverRouterProvider).state.matchedLocation;

  /// Pushes the takeover for [o] OVER the dashboard — mirroring exactly how the
  /// dashboard router attaches it (`context.push('/offer', extra:)`), so the
  /// terminal exits can POP back to a live dashboard. The deterministic path to
  /// the accept surface, without racing the world's offer pacing.
  Future<void> presentOffer(
    WidgetTester tester,
    ProviderContainer c,
    RideOffer o,
  ) async {
    unawaited(c.read(driverRouterProvider).push('/offer', extra: o));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('O1 — a double-tap fires EXACTLY ONE POST (pre-existing fence)',
      (tester) async {
    final (c, repo, world) = await boot(tester);
    await signIn(tester);
    await presentOffer(tester, c, offer());

    // Gate the accept so both taps land while the first is still in flight.
    final gate = Completer<void>();
    repo.acceptGate = gate;

    await tester.tap(find.text('Accept'), warnIfMissed: false);
    await tester.tap(find.text('Accept'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.acceptCalls, 1,
        reason: '🔴 two taps must fire ONE POST — the phase!=presenting guard. '
            'A future refactor that deletes it costs a double-accept and a '
            'server race we did not need to have.');

    gate.complete();
    await tester.pump(const Duration(milliseconds: 300));
    world.reset();
    await tester.pump();
  });

  testWidgets('O2 — NO navigation to /trip/ before the accept returns 200',
      (tester) async {
    final (c, repo, world) = await boot(tester);
    await signIn(tester);
    await presentOffer(tester, c, offer());

    // The accept hangs on an uncompleted Completer.
    final gate = Completer<void>();
    repo.acceptGate = gate;

    await tester.tap(find.text('Accept'), warnIfMissed: false);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(locationOf(c), isNot(startsWith('/trip/')),
        reason: '🔴 an optimistic nav lands the driver on a trip they were '
            'NOT given — they will drive to somebody else\'s pickup.');

    // The 200 lands: NOW the runner owns the screen.
    gate.complete();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(locationOf(c), startsWith('/trip/'),
        reason: 'the server is the authority — navigation happens on the 200');

    world.reset();
    await tester.pump();
  });

  testWidgets('O3 — 409 OFFER_EXPIRED → non-blaming state, back to /',
      (tester) async {
    final (c, repo, world) = await boot(tester);
    await signIn(tester);
    await presentOffer(tester, c, offer());

    repo.acceptError = const ApiException(
      statusCode: 409,
      message: 'This offer is no longer available.',
      code: 'OFFER_EXPIRED',
    );

    await tester.tap(find.text('Accept'), warnIfMissed: false);
    // Just enough for the accept to resolve into the reassigned state — LESS
    // than the note beat, so the non-blaming state is still on screen.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // A SPECIFIC, non-blaming state — not a red banner on a dead card.
    expect(find.byType(OfferReassignedState), findsOneWidget,
        reason: '🔴 the driver tapped inside the window; the network lost the '
            'race. They did their job — we did not. This is an apology, not an '
            'error.');

    final rendered = _renderedText(tester);
    for (final blaming in ['error', 'failed', 'sorry, something went wrong']) {
      for (final line in rendered) {
        expect(line.contains(blaming), isFalse,
            reason: '🔴 "$blaming" blames the driver for our latency. '
                'Rendered: "$line"');
      }
    }

    // …and, after the beat, it returns them to the dashboard, still online.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(locationOf(c), '/',
        reason: 'the non-blaming state forwards to the dashboard — never a '
            'dead card that does nothing');
    expect(find.byType(DashboardRiblet), findsOneWidget);

    world.reset();
    await tester.pump();
  });

  testWidgets('O4 — 403 NOT_ELIGIBLE → /documents, and the reason is NOT '
      'guessed', (tester) async {
    final (c, repo, world) = await boot(tester);
    await signIn(tester);
    await presentOffer(tester, c, offer());

    // The worst case the server actually sends: the code and an EMPTY message.
    repo.acceptError = const ApiException(
      statusCode: 403,
      message: '',
      code: 'NOT_ELIGIBLE',
    );

    // 🔴 The reason is NEVER guessed. NOT_ELIGIBLE covers compliance OR
    // restriction OR suspension — three different things, three different
    // actions, one opaque code. Any string OUR lane maps from it is a defect.
    // We watch the TAKEOVER's own transition copy across every frame from the
    // tap until the redirect settles: the guess would have to appear here, on
    // the takeover, and it must not — while `document` on the DESTINATION
    // Documents screen is a place to look, not a stated cause, so the check
    // stops the instant navigation lands.
    await tester.tap(find.text('Accept'), warnIfMissed: false);
    const guesses = ['document', 'expired', 'suspended', 'restricted'];
    for (var i = 0; i < 10; i++) {
      if (locationOf(c) == '/documents') break;
      for (final line in _renderedText(tester)) {
        for (final guess in guesses) {
          expect(line.contains(guess), isFalse,
              reason: '🔴 "$guess" is a GUESS about what NOT_ELIGIBLE meant, '
                  'rendered on the takeover during the transition. Telling a '
                  'suspended driver their paperwork is out of date is a lie '
                  'about their own status. Rendered: "$line"');
        }
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(locationOf(c), '/documents',
        reason: '🔴 NOT_ELIGIBLE at accept is a COMPLIANCE EVENT — the server '
            're-checks eligibility here. Route to Documents, the one place the '
            'driver can act.');

    world.reset();
    await tester.pump();
  });

  testWidgets('O5 — 403 FORBIDDEN is NOT NOT_ELIGIBLE (branch on code, not '
      'status)', (tester) async {
    final (c, repo, world) = await boot(tester);
    await signIn(tester);
    await presentOffer(tester, c, offer());

    // Same 403 status, different code, different world: this offer belongs to
    // ANOTHER driver. It must NOT route to Documents.
    repo.acceptError = const ApiException(
      statusCode: 403,
      message: 'You do not have access to this offer.',
      code: 'FORBIDDEN',
    );

    await tester.tap(find.text('Accept'), warnIfMissed: false);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(locationOf(c), isNot('/documents'),
        reason: '🔴 if you branched on `statusCode == 403` this fails — which '
            'is the entire point. FORBIDDEN is another driver\'s offer, not an '
            'eligibility problem.');

    world.reset();
    await tester.pump();
  });

  testWidgets('O6 — a past-expiresAt offer is REMOVED, not greyed '
      '(recomputed from clock.now())', (tester) async {
    final (c, repo, world) = await boot(tester);
    await signIn(tester);

    // The resume shape: an offer made ~3 minutes ago with a 45s window — its
    // deadline is long past. On Android a background-clamped expiry timer
    // would NEVER have fired, so the phase must be recomputed from clock.now()
    // rather than trusted to have been swept by a timer.
    final past = offer(
      offeredAt: clock.now().subtract(const Duration(minutes: 3)),
      expiresAt: clock
          .now()
          .subtract(const Duration(minutes: 3) - const Duration(seconds: 45)),
    );
    await presentOffer(tester, c, past);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    // No live offer card — the payout hero is gone, recomputed as expired.
    expect(find.text('£6.39'), findsNothing,
        reason: '🔴 a stale offer is REMOVED, not greyed. A clamped Android '
            'background timer would never have fired — the phase is recomputed '
            'from the clock, not from a timer.');
    expect(repo.acceptCalls, 0, reason: 'a dead offer is never acceptable');

    world.reset();
    await tester.pump();
  });

  testWidgets('O7 — SF-05: the Decline control claims NOTHING about '
      'consequences', (tester) async {
    final (c, _, world) = await boot(tester);
    await signIn(tester);
    await presentOffer(tester, c, offer());

    expect(find.text('Decline'), findsOneWidget);

    // 🔴 `POST /offers/:id/decline` re-dispatches until an attempt cap and
    // then the ride is CANCELLED server-side — and we do NOT know the
    // acceptance-rate policy (#25/#81). Any reassurance is a promise we have
    // no right to make.
    final rendered = _renderedText(tester);
    const forbidden = [
      'no penalty',
      "won't affect",
      'wont affect',
      'decline freely',
      'no impact',
      "doesn't count",
      'free to decline',
    ];
    for (final claim in forbidden) {
      for (final line in rendered) {
        expect(line.contains(claim), isFalse,
            reason: '🔴 "$claim" reassures the driver about a consequence we '
                'cannot see. Rendered: "$line"');
      }
    }

    world.reset();
    await tester.pump();
  });
}

/// Every string rendered anywhere in the tree, lower-cased.
List<String> _renderedText(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final data = w.data;
    if (data != null) out.add(data.toLowerCase());
  }
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    out.add(w.text.toPlainText().toLowerCase());
  }
  return out;
}

/// A chime that records nothing and touches no audio plugin.
class _SilentChime extends OfferChime {
  @override
  Future<void> prime() async {}

  @override
  Future<void> play() async {}
}

/// Wraps the demo [FakeDriverRepository] for all reads, but INTERCEPTS the
/// accept/decline intents: it counts them, can gate the accept (in flight) or
/// script it to throw a documented `ApiException`.
class _RecordingDriverRepo implements DriverRepository {
  _RecordingDriverRepo(this._inner);

  final DriverRepository _inner;

  int acceptCalls = 0;
  int declineCalls = 0;
  Completer<void>? acceptGate;
  ApiException? acceptError;

  @override
  Future<void> acceptOffer(String offerId) async {
    acceptCalls++;
    final err = acceptError;
    if (err != null) throw err;
    await acceptGate?.future;
    // No inner call: the world's own accept would advance the scenario and
    // race the navigation assertions. The recording IS the behaviour here.
  }

  @override
  Future<void> declineOffer(String offerId) async {
    declineCalls++;
    await _inner.declineOffer(offerId);
  }

  @override
  Future<List<RideOffer>> offers() => _inner.offers();

  @override
  Future<DriverDayStats?> todayStats() => _inner.todayStats();

  @override
  Future<List<DriverDocument>> documents() => _inner.documents();

  @override
  Future<void> goOnline() => _inner.goOnline();

  @override
  Future<void> goOffline() => _inner.goOffline();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      (_inner as dynamic).noSuchMethod(invocation);
}

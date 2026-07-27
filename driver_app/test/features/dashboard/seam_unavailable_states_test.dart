import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_view.dart';
import 'package:hoppin_driver/features/dashboard/widgets/seam_unavailable_states.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_builder.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_interactor.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_state.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_view.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/no_network_tile_provider.dart';

/// Wave-0 seam-rung acceptance: the two DRIVER capability seams that used to
/// ship UNDISCLOSED (#7 driver day stats, #6 trip rider context) now render
/// designed unavailable-states on the REAL null branch of the REAL views.
///
/// These are behavioural, not isolation, tests. A rung that is merely declared
/// — never constructed by a view a driver can actually reach — is precisely the
/// dead-code failure Wave 0 exists to kill, so each test drives the live-shaped
/// null seam through the production widget tree and asserts the rung comes out
/// the other end. The #7 test additionally re-proves the live bug is dead: with
/// telemetry silent forever, GO must still land the driver online AND the quiet
/// 'Go offline' affordance must still be there to get them back out.
///
/// Bounded pumps only — the GO pulse loops and the offer countdown ticks, so
/// pumpAndSettle would never return.
void main() {
  // ── #7 · Driver day stats (SEAMED — no telemetry endpoint) ───────────────

  /// Pumps the REAL [DashboardView] over the REAL [DashboardInteractor] and the
  /// REAL polling providers, backed by a live-shaped repository whose
  /// `todayStats()` answers null forever. ONLY [driverRepositoryProvider] is
  /// overridden — no demo override list, so nothing is double-overridden.
  ///
  /// [DashboardView], not [DashboardRiblet]: the riblet wraps the view in the
  /// router listener, which needs a GoRouter ancestor the moment real state
  /// moves. The view IS the render layer under test.
  Future<_LiveDriverRepo> pumpLiveDashboard(WidgetTester tester) async {
    final repo = _LiveDriverRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [driverRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const DashboardView(),
      ),
    ));
    await tester.pump();
    return repo;
  }

  testWidgets(
      '#7 rung: online with silent telemetry renders DriverStatsUnavailable',
      (tester) async {
    final repo = await pumpLiveDashboard(tester);

    // Offline boot: the quiet em-dash placeholders hold the slot — the rung is
    // for the ONLINE-but-blind state, not for "not started yet".
    expect(find.byType(DriverStatsUnavailable), findsNothing,
        reason: 'an offline driver has no stats to be missing yet');
    expect(find.text('— trips'), findsOneWidget,
        reason: 'the offline tile keeps its quiet placeholder trio');

    // GO. The 200 is the confirmation: presence never waits on seam #7.
    await tester.tap(find.byType(GoButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.goOnlineCalls, 1,
        reason: 'the GO tap must reach POST /drivers/me/online exactly once');
    expect(find.text("You're online"), findsOneWidget,
        reason:
            'presence is authoritative from the 200 — the driver IS dispatchable '
            'even though todayStats() answered null');

    // THE RUNG. The driver is online and taking offers; only the stats display
    // is unavailable — and it says so, in the tile's own slot.
    expect(find.byType(DriverStatsUnavailable), findsOneWidget,
        reason:
            'the null #7 seam must render its designed rung, never a blank slot');
    expect(find.text("Today's stats unavailable"), findsOneWidget,
        reason: 'the rung names the gap honestly in visible copy');

    // No zero passed off as the day's real takings.
    expect(find.text('£0.00'), findsNothing,
        reason: 'a fabricated £0.00 total would be a lie, not a degrade');
    expect(find.text('0 trips'), findsNothing,
        reason: 'a fabricated zero trip count would be a lie, not a degrade');
    // Graceful degradation is never a spinner-centred screen.
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'the rung is a designed state, never an endless spinner');
  });

  testWidgets(
      '#7 rung: the driver can still get back OFFLINE (the live bug is dead)',
      (tester) async {
    final repo = await pumpLiveDashboard(tester);

    await tester.tap(find.byType(GoButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(DriverStatsUnavailable), findsOneWidget,
        reason: 'precondition: the driver is online over a null stats seam');

    // THE LIVE BUG: the 'Go offline' affordance only renders while
    // phase == online. When presence was gated on the null telemetry seam the
    // phase hung at goingOnline forever, this affordance never appeared, and
    // the driver was stranded IN the dispatch pool with no way out.
    final offline = find.text('Go offline');
    expect(offline, findsOneWidget,
        reason:
            'the escape hatch must exist while the stats rung is showing — this '
            'is the exact affordance the Wave-0 live bug withheld');

    await tester.tap(offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.goOfflineCalls, 1,
        reason: 'the tap must reach POST /drivers/me/offline exactly once');
    expect(find.text('Ready to drive?'), findsOneWidget,
        reason: 'the offline 200 confirms departure from the dispatch pool');
    expect(find.byType(DriverStatsUnavailable), findsNothing,
        reason: 'back offline, the tile returns to its quiet placeholders');
    expect(tester.takeException(), isNull,
        reason: 'the full online→offline round trip raises nothing');
  });

  testWidgets('#7 rung: renders visibly in the light theme too', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: HoppinTheme.driverLight(),
        home: const Scaffold(body: DriverStatsUnavailable()),
      ),
    ));
    await tester.pump();

    expect(find.text("Today's stats unavailable"), findsOneWidget,
        reason: 'the rung renders non-blank copy under the light theme');
    expect(tester.getSize(find.byType(DriverStatsUnavailable)).height,
        greaterThan(0),
        reason: 'a zero-height rung is a blank by another name');
  });

  // ── #6 · Trip rider context (SEAMED — no rider identity on the offer) ─────

  final offer = RideOffer(
    offerId: 'offer-1',
    rideId: 'ride-1',
    pickupLat: 52.5875,
    pickupLng: -2.1288,
    dropoffLat: 52.5906,
    dropoffLng: -2.0929,
    fare: 6.39,
    estimatedMiles: 1.7,
    expiresAt: clock.now().add(const Duration(seconds: 45)),
    offeredAt: clock.now(),
  );

  /// Pumps the REAL [OfferTakeoverView] with the #6 seam answering null — the
  /// live shape. The interactor is the established fixture stub (it would
  /// otherwise arm timers and play the chime); the rider-context provider is
  /// overridden to the live null, and the map tiles are served from memory so
  /// no HTTP leaves the test.
  Future<void> pumpNullRiderTakeover(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        offerTakeoverInteractorProvider.overrideWith2(
          (offer) => _StubInteractor(
            offer,
            OfferTakeoverState(
              offer: offer,
              presentedAt: clock.now(),
              deadline: clock.now().add(const Duration(seconds: 45)),
            ),
          ),
        ),
        tripRiderContextProvider.overrideWith((ref, _) async => null),
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: OfferTakeoverView(offer: offer),
      ),
    ));
    // Resolve the rider-context future, then play the entrance stagger out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('#6 rung: null rider context renders RiderContextUnavailable',
      (tester) async {
    await pumpNullRiderTakeover(tester);

    expect(find.byType(RiderContextUnavailable), findsOneWidget,
        reason:
            'the null #6 seam must render its designed rung — the rider slot '
            'may never silently collapse');
    expect(find.text('Rider details unavailable'), findsOneWidget,
        reason: 'the rung names the gap honestly in visible copy');

    // The JOB is untouched: the payout, the pickup context and the Accept are
    // all real. Only WHO is unknown.
    expect(find.text('£6.39'), findsOneWidget,
        reason: 'the payout hero is real and unaffected by the rider seam');
    expect(find.text('1.7 mi to pickup'), findsOneWidget,
        reason: 'pickup distance comes off the offer, not the rider seam');
    expect(find.text('Accept'), findsOneWidget,
        reason: 'the driver can still take the job with the rider unknown');
    expect(find.byType(CountdownRing), findsOneWidget,
        reason: 'the offer clock keeps running under the rung');
    expect(tester.takeException(), isNull,
        reason: 'the rung slots into the locked anatomy without overflow');
  });

  testWidgets('#6 rung: never invents a rider identity', (tester) async {
    await pumpNullRiderTakeover(tester);

    expect(find.textContaining('★'), findsNothing,
        reason: 'no rating may be fabricated when the seam answers null');
    expect(find.text('Sophie Bell'), findsNothing,
        reason: 'the demo persona must never leak onto the live null path');
  });
}

/// The LIVE-shaped driver repository: presence works (the endpoints are real),
/// the telemetry seam (#7) answers null forever, and there are never any
/// offers. Exactly what a real driver hits on production today.
class _LiveDriverRepo implements DriverRepository {
  int goOnlineCalls = 0;
  int goOfflineCalls = 0;

  @override
  Future<void> goOnline() async => goOnlineCalls++;

  @override
  Future<void> goOffline() async => goOfflineCalls++;

  /// SEAM(#7): no telemetry endpoint — null, every single poll, forever.
  @override
  Future<DriverDayStats?> todayStats() async => null;

  @override
  Future<List<RideOffer>> offers() async => const [];

  /// BOUND — and it is one of the very few driver reads that IS. The expiry
  /// ladder (13-04) reads the real `expires_at` off it. This live-shaped driver
  /// is fully compliant, so it answers empty: no rung, nothing blocked.
  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fixture-holding stub: build() returns the fixed state without arming timers
/// or playing the chime; the intents are inert here (they have their own
/// coverage in offer_takeover_view_test.dart).
class _StubInteractor extends OfferTakeoverInteractor {
  _StubInteractor(super.offer, this.fixture);

  final OfferTakeoverState fixture;

  @override
  OfferTakeoverState build() => fixture;

  @override
  Future<void> accept() async {}

  @override
  Future<void> decline() async {}
}

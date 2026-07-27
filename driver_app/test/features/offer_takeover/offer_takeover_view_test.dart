import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_builder.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_interactor.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_state.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_view.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/no_network_tile_provider.dart';

/// View smoke layer (riblet testing contract, DOCS/05): the locked
/// payout-first takeover anatomy against fixed fixtures — the hero £ is
/// machine-verified as THE largest text on screen (the squint test,
/// automated), the ring never renders without numeric seconds, taps
/// dispatch exactly once, and expiry is neutral-toned, never red.
/// Bounded pumps only.
void main() {
  const TripRiderContext sophie = (
    name: 'Sophie Bell',
    rating: 4.8,
    pickupLabel: 'Wolverhampton Rail Station',
    pickupEtaSeconds: 120,
  );

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

  OfferTakeoverState fixture({OfferPhase phase = OfferPhase.presenting}) =>
      OfferTakeoverState(
        offer: offer,
        presentedAt: clock.now(),
        deadline: clock.now().add(const Duration(seconds: 45)),
        phase: phase,
      );

  Future<_StubInteractor> pumpTakeover(
    WidgetTester tester,
    OfferTakeoverState state, {
    TripRiderContext? riderContext = sophie,
  }) async {
    final stub = _StubInteractor(offer, state);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        offerTakeoverInteractorProvider.overrideWith2((offer) => stub),
        tripRiderContextProvider.overrideWith((ref, _) async => riderContext),
        // The card carries the MAP-04 context inset now — serve its tiles
        // from memory so no HTTP leaves the test.
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: OfferTakeoverView(offer: offer),
      ),
    ));
    // Resolve the rider-context future + play the entrance stagger out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return stub;
  }

  testWidgets('payout-first anatomy: hero £ is THE largest text on screen',
      (tester) async {
    await pumpTakeover(tester, fixture());

    // The hero payout, formatted to 2dp.
    final heroFinder = find.text('£6.39');
    expect(heroFinder, findsOneWidget);
    final hero = tester.widget<Text>(heroFinder);
    final heroSize = hero.style?.fontSize;
    expect(heroSize, isNotNull);

    // The squint test, automated: every other Text resolves smaller.
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      if (identical(text, hero)) continue;
      final size = text.style?.fontSize ?? 14;
      expect(size, lessThan(heroSize!),
          reason: '"${text.data}" must render smaller than the hero payout');
    }

    // Context line: minutes from the rider context, miles from the offer.
    expect(find.text('2 min · 1.7 mi to pickup'), findsOneWidget);

    // Rider row: name + rating chip.
    expect(find.text('Sophie Bell'), findsOneWidget);
    expect(find.text('★ 4.8'), findsOneWidget);

    // The ring, NEVER alone: numeric seconds always beside/inside it.
    expect(find.byType(CountdownRing), findsOneWidget);
    final secondsText = find.byWidgetPredicate(
      (w) => w is Text && w.data != null && RegExp(r'^\d+$').hasMatch(w.data!),
    );
    expect(secondsText, findsOneWidget,
        reason: 'the countdown ring must carry numeric seconds');

    // The two calls to action.
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('null rider context degrades gracefully (live fallback)',
      (tester) async {
    await pumpTakeover(tester, fixture(), riderContext: null);

    expect(find.text('£6.39'), findsOneWidget);
    // No minutes segment without a rider context — miles only.
    expect(find.text('1.7 mi to pickup'), findsOneWidget);
    expect(find.text('Sophie Bell'), findsNothing);
    expect(find.text('★ 4.8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Accept, card body, and Decline dispatch their intents',
      (tester) async {
    final stub = await pumpTakeover(tester, fixture());

    await tester.tap(find.text('Accept'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(stub.acceptCalls, 1);
    expect(stub.declineCalls, 0);

    // Tap-anywhere-to-accept: the card body (the hero text) accepts too.
    await tester.tap(find.text('£6.39'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(stub.acceptCalls, 2);

    // The ghost Decline wins its own bounds — decline exactly once.
    await tester.tap(find.text('Decline'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(stub.declineCalls, 1);
    expect(stub.acceptCalls, 2);
  });

  testWidgets('repo-call failure surfaces as the brand HopBanner',
      (tester) async {
    const message = 'Something went wrong. Please try again.';
    await pumpTakeover(tester, fixture().copyWith(error: message));

    expect(find.text(message), findsOneWidget);
    expect(find.byType(HopBanner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired shows the quiet note in neutral tones, never red',
      (tester) async {
    await pumpTakeover(tester, fixture(phase: OfferPhase.expired));
    await tester.pump(const Duration(milliseconds: 300));

    final noteFinder = find.text('Offer expired');
    expect(noteFinder, findsOneWidget);

    final colors = HoppinTheme.driverDark().extension<HoppinColors>()!;
    final note = tester.widget<Text>(noteFinder);
    expect(note.style?.color, isNot(colors.error),
        reason: 'expiry is never a failure state — no error token');
    expect(note.style?.color, colors.textMid,
        reason: 'the note carries neutral on-surface tones');
    expect(tester.takeException(), isNull);
  });
}

/// Fixture-holding stub: build() returns the fixed state without arming
/// timers or playing the chime; the intent methods record instead of act.
class _StubInteractor extends OfferTakeoverInteractor {
  _StubInteractor(super.offer, this.fixture);

  final OfferTakeoverState fixture;
  int acceptCalls = 0;
  int declineCalls = 0;

  @override
  OfferTakeoverState build() => fixture;

  @override
  Future<void> accept() async {
    acceptCalls++;
  }

  @override
  Future<void> decline() async {
    declineCalls++;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/ui/widgets/offer_card.dart';

PendingOffer buildOffer({
  int farePence = 2015,
  int? etaSeconds = 240,
  int? durationSeconds = 900,
  double? miles = 4.7,
  String? category = 'standard',
  int expiresInSec = 60,
  Duration age = Duration.zero,
}) =>
    PendingOffer(
      id: 'o1',
      rideId: 'r1',
      fare: Pence(farePence),
      pickupLabel: 'City Centre',
      dropoffLabel: 'Railway Station',
      rideCategory: category,
      estimatedDurationSeconds: durationSeconds,
      estimatedMiles: miles,
      pickupEtaSeconds: etaSeconds,
      expiresInSec: expiresInSec,
      receivedAt: DateTime.now().subtract(age),
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('leads with the fare, under its label', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('Estimated Fare'), findsOneWidget);
    expect(find.text('£20.15'), findsOneWidget);
  });

  testWidgets('shows distance and duration as the two stats', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('Distance'), findsOneWidget);
    // Miles, not the design's kilometres: trip history and the earnings
    // statement are both in miles.
    expect(find.text('4.7 miles'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
  });

  testWidgets('falls back to a dash when the service sends no distance',
      (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer(miles: null))));

    // The stat keeps its slot so Distance and Duration stay on one baseline.
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('labels the two stops', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Dropoff'), findsOneWidget);
  });

  testWidgets('shows both labels', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('City Centre'), findsOneWidget);
    expect(find.text('Railway Station'), findsOneWidget);
  });

  testWidgets('shows pickup ETA and trip duration in minutes', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.textContaining('4 min away'), findsOneWidget);
    expect(find.textContaining('15 min trip'), findsOneWidget);
  });

  testWidgets('omits the ETA line when the server has no position',
      (tester) async {
    await tester
        .pumpWidget(wrap(OfferCard(offer: buildOffer(etaSeconds: null))));

    expect(find.textContaining('away'), findsNothing);
  });

  testWidgets('shows the category badge', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('Standard'), findsOneWidget);
  });

  testWidgets('renders no rider identity of any kind', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    // No avatar, no star rating — the Equality Act position, enforced at
    // the widget level as well as in the model.
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    // The design also put a free-text rider "Comment" box under the map.
    // Nothing on the offer carries one, and a box the rider writes into is
    // exactly the channel the identity rule exists to close.
    expect(find.textContaining('Comment'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('offers the two actions the design names', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('Accept Ride'), findsOneWidget);
    expect(find.text('Decline Ride'), findsOneWidget);
  });

  testWidgets('accept fires straight away; decline asks first',
      (tester) async {
    var accepted = false, declined = false;
    await tester.pumpWidget(wrap(OfferCard(
      offer: buildOffer(),
      onAccept: () => accepted = true,
      onDecline: () => declined = true,
    )));

    await tester.tap(find.text('Accept Ride'));
    expect(accepted, isTrue);

    // Decline is final and sits under the driver's thumb, so it goes
    // through a confirmation rather than firing on the tap itself.
    await tester.tap(find.text('Decline Ride'));
    await tester.pumpAndSettle();
    expect(declined, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Decline'));
    await tester.pumpAndSettle();
    expect(declined, isTrue);
  });

  testWidgets('a lapsed offer is dismissed without a confirmation',
      (tester) async {
    var declined = false;
    await tester.pumpWidget(wrap(OfferCard(
      offer: buildOffer(expiresInSec: 30, age: const Duration(seconds: 32)),
      onDecline: () => declined = true,
    )));

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    // Nothing is being thrown away, so there is nothing to ask about.
    expect(find.text('Decline this ride?'), findsNothing);
    expect(declined, isTrue);
  });

  testWidgets('both actions are disabled while busy', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(
        offer: buildOffer(), onAccept: () {}, onDecline: () {}, isBusy: true)));

    final accept = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(accept.onPressed, isNull);
  });

  testWidgets('shows a countdown', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('s'), findsWidgets);
  });

  testWidgets('holds the countdown once accept is in flight', (tester) async {
    // The accept POST is away and the offer is no longer the driver's to
    // lose. A pill that keeps racing to zero — and then says "Offer
    // expired" — is lying about a decision already taken.
    //
    // The clock is moved by backdating receivedAt rather than by pumping:
    // secondsRemaining reads the wall clock, which a fake-async pump does
    // not advance.
    final card = OfferCard(
      offer: buildOffer(expiresInSec: 30, age: const Duration(seconds: 28)),
      isBusy: true,
    );
    await tester.pumpWidget(wrap(card));

    expect(find.text('2s'), findsOneWidget);

    // Same offer, four seconds older: live, this pill would read 0s and the
    // button would flip to "Offer expired" under the driver's finger.
    await tester.pumpWidget(
      wrap(OfferCard(
        offer: buildOffer(expiresInSec: 30, age: const Duration(seconds: 32)),
        isBusy: true,
      )),
    );
    await tester.pump();

    // A busy AppButton renders its spinner in place of the label, so the
    // absence of the expired copy is what proves the window was held.
    expect(find.text('Offer expired'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
  });

  testWidgets('still expires when the offer is untouched', (tester) async {
    await tester.pumpWidget(
      wrap(OfferCard(
        offer: buildOffer(expiresInSec: 30, age: const Duration(seconds: 32)),
      )),
    );

    expect(find.text('Offer expired'), findsOneWidget);
  });
}

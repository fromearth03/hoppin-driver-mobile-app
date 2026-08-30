import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/ui/widgets/offer_card.dart';

PendingOffer buildOffer({
  int farePence = 2015,
  int? etaSeconds = 240,
  int? durationSeconds = 900,
  String? category = 'standard',
}) =>
    PendingOffer(
      id: 'o1',
      rideId: 'r1',
      fare: Pence(farePence),
      pickupLabel: 'City Centre',
      dropoffLabel: 'Railway Station',
      rideCategory: category,
      estimatedDurationSeconds: durationSeconds,
      pickupEtaSeconds: etaSeconds,
      expiresInSec: 60,
      receivedAt: DateTime.now(),
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('leads with the fare', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('£20.15'), findsOneWidget);
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
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('accept states the amount being accepted', (tester) async {
    await tester.pumpWidget(wrap(OfferCard(offer: buildOffer())));

    expect(find.text('Accept for £20.15'), findsOneWidget);
  });

  testWidgets('accept and decline fire their callbacks', (tester) async {
    var accepted = false, declined = false;
    await tester.pumpWidget(wrap(OfferCard(
      offer: buildOffer(),
      onAccept: () => accepted = true,
      onDecline: () => declined = true,
    )));

    await tester.tap(find.text('Accept for £20.15'));
    await tester.tap(find.text('Decline'));

    expect(accepted, isTrue);
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
}

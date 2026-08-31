import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/theme/colors.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/ui/widgets/offer_card.dart';

/// Renders the offer card at the Figma artboard width and writes it to
/// `test/visual/goldens/`, so the build can be held against
/// `Ride Request On@2x.png` by eye.
///
/// Run with `flutter test --update-goldens test/visual/offer_golden_test.dart`.
void _noop() {}

void main() {
  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name, {
    Size size = const Size(430, 620),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(child: child),
      ),
    ));
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  PendingOffer offer({
    int? etaSeconds = 300,
    int? durationSeconds = 780,
    double? miles = 4.7,
    String? category = 'standard',
  }) =>
      PendingOffer(
        id: 'o1',
        rideId: 'r1',
        fare: const Pence(2015),
        pickupLabel: 'Wolverhampton City Center',
        dropoffLabel: 'Transit station in Wolverhampton, England',
        rideCategory: category,
        estimatedDurationSeconds: durationSeconds,
        estimatedMiles: miles,
        pickupEtaSeconds: etaSeconds,
        expiresInSec: 60,
        // Fixed window so the countdown goldens at a stable "15s".
        expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 15)),
        receivedAt: DateTime.now(),
      );

  testWidgets(
    'offer card',
    (t) => capture(
      t,
      OfferCard(offer: offer(), onAccept: _noop, onDecline: _noop),
      'offer',
    ),
  );

  testWidgets(
    'offer card without distance or ETA',
    (t) => capture(
      t,
      OfferCard(
        offer: offer(etaSeconds: null, miles: null, category: null),
        onAccept: _noop,
        onDecline: _noop,
      ),
      'offer_sparse',
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/driver_today.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:hoppin_driver/features/home/ui/home_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockStatusRepo extends Mock implements DriverStatusRepository {}

class MockOfferRepo extends Mock implements OfferRepository {}

Widget wrap(MockStatusRepo s, MockOfferRepo o) => ProviderScope(
      overrides: [
        driverStatusRepositoryProvider.overrideWithValue(s),
        offerRepositoryProvider.overrideWithValue(o),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  late MockStatusRepo status;
  late MockOfferRepo offers;

  setUp(() {
    status = MockStatusRepo();
    offers = MockOfferRepo();
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));
    // Home now shows the day-so-far tiles. These tests are not about them,
    // so answer with the quiet case.
    when(() => status.today())
        .thenAnswer((_) async => const Ok(DriverToday()));

  });

  testWidgets('an offer below a long blocker list is still built',
      (tester) async {
    // A driver blocked by several documents has a tall list above the offer
    // card. A lazy ListView never builds children past the viewport, so the
    // card would be absent from the tree entirely — not merely scrolled off.
    when(() => status.status()).thenAnswer((_) async => const Ok(DriverStatus(
          presence: Presence.online,
          staleAfterSeconds: 90,
          dispatchable: false,
          blockedReason: 'DOCS_EXPIRED',
          blockingDocumentTypes: [
            'vehicle_insurance',
            'private_hire_licence',
            'dbs_check',
            'mot_certificate',
            'vehicle_logbook',
          ],
        )));
    when(() => offers.offers()).thenAnswer((_) async => Ok([
          PendingOffer(
            id: 'o1',
            rideId: 'r1',
            fare: const Pence(2015),
            pickupLabel: 'City Centre',
            dropoffLabel: 'Station',
            expiresInSec: 60,
            receivedAt: DateTime.now(),
          )
        ]));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await container.read(homeControllerProvider.notifier).onPushWake();
    await tester.pumpAndSettle();

    expect(find.text('Accept Ride', skipOffstage: false), findsOneWidget);
  });
}

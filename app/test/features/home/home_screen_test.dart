import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:hoppin_driver/features/home/ui/home_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatusRepo extends Mock implements DriverStatusRepository {}

class _MockOfferRepo extends Mock implements OfferRepository {}

DriverStatus buildStatus({
  Presence presence = Presence.offline,
  String? blocked,
  List<String> docs = const [],
}) =>
    DriverStatus(
      presence: presence,
      staleAfterSeconds: 90,
      dispatchable: blocked == null && presence == Presence.online,
      blockedReason: blocked,
      blockingDocumentTypes: docs,
    );

Widget wrap(_MockStatusRepo s, _MockOfferRepo o) => ProviderScope(
      overrides: [
        driverStatusRepositoryProvider.overrideWithValue(s),
        offerRepositoryProvider.overrideWithValue(o),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  late _MockStatusRepo status;
  late _MockOfferRepo offers;

  setUp(() {
    status = _MockStatusRepo();
    offers = _MockOfferRepo();
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));
  });

  testWidgets('shows the offline toggle by default', (tester) async {
    when(() => status.status()).thenAnswer((_) async => Ok(buildStatus()));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('shows the blocker list and disables the toggle when blocked',
      (tester) async {
    when(() => status.status()).thenAnswer((_) async => Ok(
        buildStatus(blocked: 'DOCS_EXPIRED', docs: ['vehicle_insurance'])));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Insurance'), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.onChanged, isNull);
  });

  testWidgets('shows the offer card when an offer arrives', (tester) async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
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
    // Simulate the push wake path rather than waiting for a real 5s tick.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    await container.read(homeControllerProvider.notifier).onPushWake();
    await tester.pumpAndSettle();

    expect(find.text('£20.15'), findsOneWidget);
    expect(find.text('Accept for £20.15'), findsOneWidget);
  });

  testWidgets('warns when the GPS position has gone stale', (tester) async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.stale)));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.textContaining('location'), findsOneWidget);
  });
}

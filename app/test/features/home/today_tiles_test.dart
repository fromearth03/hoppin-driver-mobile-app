import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/driver_today.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/ui/home_screen.dart';
import 'package:hoppin_driver/features/home/ui/widgets/active_trip_banner.dart';
import 'package:mocktail/mocktail.dart';

class MockStatusRepo extends Mock implements DriverStatusRepository {}

class MockOfferRepo extends Mock implements OfferRepository {}

DriverStatus offlineStatus() => const DriverStatus(
      presence: Presence.offline,
      staleAfterSeconds: 90,
      dispatchable: false,
    );

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
    when(() => status.status()).thenAnswer((_) async => Ok(offlineStatus()));
  });

  testWidgets('shows the day so far', (tester) async {
    when(() => status.today()).thenAnswer((_) async => const Ok(DriverToday(
          earnings: Pence(8450),
          tripCount: 6,
          onlineTime: Duration(seconds: 8100),
        )));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.text('£84.50'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('2h 15m'), findsOneWidget);
  });

  testWidgets('offers a way back into a trip still running', (tester) async {
    when(() => status.today()).thenAnswer(
        (_) async => const Ok(DriverToday(activeRideId: 'r9')));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    // Without this a driver who force-quits mid-job cannot reach Arrive,
    // Start or Complete - with a passenger already in the car.
    expect(find.byType(ActiveTripBanner), findsOneWidget);
  });

  testWidgets('shows no trip banner when there is no trip', (tester) async {
    when(() => status.today())
        .thenAnswer((_) async => const Ok(DriverToday(tripCount: 2)));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveTripBanner), findsNothing);
  });

  testWidgets('a failed today call still leaves Home usable', (tester) async {
    when(() => status.today()).thenAnswer(
        (_) async => Err(ApiException('INTERNAL', 'boom', 500)));

    await tester.pumpWidget(wrap(status, offers));
    await tester.pumpAndSettle();

    // The toggle is what Home is for; losing the tiles must not cost it.
    expect(find.byType(Switch), findsOneWidget);
  });
}
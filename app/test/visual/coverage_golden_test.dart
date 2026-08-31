import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/driver_today.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/ui/home_screen.dart';
import 'package:hoppin_driver/features/trip/data/chat_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_message.dart';
import 'package:hoppin_driver/features/trip/ui/chat_screen.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:hoppin_driver/features/trips/ui/trip_detail_screen.dart';
import 'package:hoppin_driver/features/trips/ui/trips_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockStatusRepo extends Mock implements DriverStatusRepository {}

class _MockOfferRepo extends Mock implements OfferRepository {}

class _MockTripsRepo extends Mock implements TripsRepository {}

class _MockEarningsRepo extends Mock implements EarningsRepository {}

class _MockChatRepo extends Mock implements ChatRepository {}

/// Goldens for the screens the fidelity audit found uncovered: the offline
/// home, trip history, one past trip, and the ride chat.
///
/// Run with `flutter test --update-goldens test/visual/coverage_golden_test.dart`.
void main() {
  setUpAll(() => registerFallbackValue(TripFilter.all));

  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: child,
      ),
    ));
    // Fixed pumps rather than pumpAndSettle: home and chat keep pollers
    // alive, and settling would wait on timers that never stop.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );

    // Unmount so periodic pollers are disposed before the test ends.
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('home, offline with a day behind it', (tester) async {
    final status = _MockStatusRepo();
    final offers = _MockOfferRepo();
    when(() => status.status()).thenAnswer((_) async => const Ok(DriverStatus(
          presence: Presence.offline,
          staleAfterSeconds: 90,
          dispatchable: false,
        )));
    when(() => status.today()).thenAnswer((_) async => const Ok(DriverToday(
          earnings: Pence(4230),
          tripCount: 5,
          onlineTime: Duration(hours: 6, minutes: 40),
        )));
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));

    await capture(tester, const HomeScreen(), 'home_offline', overrides: [
      driverStatusRepositoryProvider.overrideWithValue(status),
      offerRepositoryProvider.overrideWithValue(offers),
    ]);
  });

  testWidgets('trips list, mixed outcomes', (tester) async {
    final trips = _MockTripsRepo();
    when(() =>
            trips.page(filter: any(named: 'filter'), cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Ok(TripsPage(trips: [
              DriverTrip(
                id: 'r1',
                ref: 'R-1042',
                status: 'completed',
                pickupLabel: 'Dudley Street, Wolverhampton',
                dropoffLabel: 'Railway Station',
                distanceMiles: 3.2,
                earnings: const Pence(830),
                penalty: const Pence(0),
                completedAt: DateTime.utc(2026, 8, 30, 7, 21),
              ),
              DriverTrip(
                id: 'r2',
                ref: 'R-1038',
                status: 'cancelled',
                pickupLabel: 'Bilston Road',
                dropoffLabel: 'City Centre',
                earnings: const Pence(0),
                penalty: const Pence(865),
                cancelledBy: 'driver',
                completedAt: DateTime.utc(2026, 8, 30, 6, 2),
              ),
            ])));

    await capture(tester, const TripsScreen(), 'trips_list', overrides: [
      tripsRepositoryProvider.overrideWithValue(trips),
    ]);
  });

  testWidgets('trip detail with a settled breakdown', (tester) async {
    final earnings = _MockEarningsRepo();
    when(() => earnings.rideEarnings('r1'))
        .thenAnswer((_) async => Ok(RideEarnings.fromJson(const {
              'base_pence': 250,
              'distance_pence': 480,
              'time_pence': 160,
              'surge_pence': 0,
              'waiting_pence': 60,
              'commission_pence': -120,
              'net_pence': 830,
            })));

    final trip = DriverTrip(
      id: 'r1',
      ref: 'R-1042',
      status: 'completed',
      pickupLabel: 'Dudley Street, Wolverhampton',
      dropoffLabel: 'Railway Station',
      distanceMiles: 3.2,
      earnings: const Pence(830),
      penalty: const Pence(0),
      completedAt: DateTime.utc(2026, 8, 30, 7, 21),
    );

    await capture(tester, TripDetailScreen(trip: trip), 'trip_detail',
        overrides: [
          earningsRepositoryProvider.overrideWithValue(earnings),
        ]);
  });

  testWidgets('chat, both sides of a conversation', (tester) async {
    final chat = _MockChatRepo();
    when(() => chat.messages('r1')).thenAnswer((_) async => Ok([
          RideMessage.fromJson(const {
            'id': 'm1',
            'body': 'On my way, two minutes out.',
            'sender_role': 'driver',
            'created_at': '2026-08-30T10:00:00Z',
          }),
          RideMessage.fromJson(const {
            'id': 'm2',
            'body': 'Great, waiting by the gate.',
            'sender_role': 'rider',
            'created_at': '2026-08-30T10:01:00Z',
          }),
        ]));

    await capture(tester, const ChatScreen(rideId: 'r1'), 'trip_chat',
        overrides: [
          chatRepositoryProvider.overrideWithValue(chat),
        ]);
  });
}

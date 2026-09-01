import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/core/theme/app_theme.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/driver_today.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/ui/home_screen.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_stop.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/ui/trip_screen.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/cancel_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockReasonRepo extends Mock implements CancelReasonRepository {}

class _MockEarningsRepo extends Mock implements EarningsRepository {}

class _MockStatusRepo extends Mock implements DriverStatusRepository {}

class _MockOfferRepo extends Mock implements OfferRepository {}

/// Not a regression suite — a demo gallery. Renders every live-trip screen
/// with the REAL fonts and fixture data, so the trip flow can be seen
/// without waiting for a real rider. Run:
///
///   flutter test --update-goldens test/visual/demo_gallery_test.dart
///
/// The PNGs land in test/visual/goldens/demo/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real typefaces: the default test font renders text as black boxes,
    // which defeats a gallery meant for human eyes.
    for (final (file, _) in const [
      ('Baloo2-Regular.ttf', FontWeight.w400),
      ('Baloo2-Medium.ttf', FontWeight.w500),
      ('Baloo2-SemiBold.ttf', FontWeight.w600),
      ('Baloo2-Bold.ttf', FontWeight.w700),
    ]) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      final loader = FontLoader('Baloo2')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    for (var id = 0; id < 12; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('plugins.flutter.io/google_maps_$id'),
        (_) async => null,
      );
    }
  });

  const rider = Rider(
      id: 'u1', fullName: 'Taimoor Ali', rating: 4.3, ratingCount: 13);

  Ride ride(String status, {DateTime? arrivedAt}) => Ride(
        id: 'r1',
        status: status,
        ref: 'R-1042',
        rider: rider,
        pickupEtaSeconds: 300,
        acceptedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
        arrivedAt: arrivedAt,
        geo: const RideGeo(
          pickup:
              GeoPoint(lat: 52.586, lng: -2.128, label: 'Wolverhampton City Center'),
          dropoff: GeoPoint(
              lat: 52.587, lng: -2.12, label: 'Transit station in Wolverhampton'),
          steps: [
            NavStep(
                instruction: 'Take left',
                distanceMeters: 2414,
                maneuver: 'turn-left'),
          ],
        ),
      );

  late _MockTripRepo trip;
  late _MockReasonRepo reasons;
  late _MockEarningsRepo earnings;
  late _MockStatusRepo status;
  late _MockOfferRepo offers;

  setUp(() {
    trip = _MockTripRepo();
    reasons = _MockReasonRepo();
    earnings = _MockEarningsRepo();
    status = _MockStatusRepo();
    offers = _MockOfferRepo();

    when(() => trip.stops(any()))
        .thenAnswer((_) async => const Ok(RideStops.empty));
    when(() => trip.riderContext(any())).thenAnswer(
        (_) async => Err(ApiException('NOT_FOUND', 'no rider context', 404)));
    when(() => trip.waitingPolicy(any())).thenAnswer((_) async => Ok(
        WaitingPolicy(
          freeWaitSeconds: 180,
          perMinutePence: const Pence(30),
          noShowFeePence: const Pence(5900),
          arrivedAt:
              DateTime.now().toUtc().subtract(const Duration(minutes: 7)),
          billableFrom:
              DateTime.now().toUtc().add(const Duration(seconds: 157)),
        )));
    when(() => reasons.forDriver()).thenAnswer((_) async => const Ok([
          CancelReason(
            id: 'no_show',
            text: 'Passenger did not show up, not responding',
            pickable: true,
            freeCancelSeconds: 400,
          ),
          CancelReason(
              id: 'wrong_pickup',
              text: 'Wrong pickup location',
              pickable: true,
              freeCancelSeconds: 400),
        ]));
    when(() => earnings.rideEarnings(any()))
        .thenAnswer((_) async => Ok(RideEarnings.fromJson(const {
              'base_pence': 250,
              'distance_pence': 1480,
              'time_pence': 260,
              'surge_pence': 0,
              'waiting_pence': 25,
              'commission_pence': -302,
              'net_pence': 1713,
            })));
  });

  Future<void> capture(WidgetTester tester, Widget child, String name,
      {List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trip),
        cancelReasonRepositoryProvider.overrideWithValue(reasons),
        earningsRepositoryProvider.overrideWithValue(earnings),
        driverStatusRepositoryProvider.overrideWithValue(status),
        offerRepositoryProvider.overrideWithValue(offers),
        ...overrides,
      ],
      child: MaterialApp(theme: appTheme(), home: child),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/demo/$name.png'),
    );
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('1 offer arrives', (tester) async {
    when(() => status.status()).thenAnswer((_) async => const Ok(DriverStatus(
        presence: Presence.online, staleAfterSeconds: 90, dispatchable: true)));
    when(() => status.today()).thenAnswer((_) async => const Ok(DriverToday(
        online: true,
        earnings: Pence(4230),
        tripCount: 5,
        onlineTime: Duration(hours: 6, minutes: 40))));
    when(() => offers.offers()).thenAnswer((_) async => Ok([
          PendingOffer(
            id: 'o1',
            rideId: 'r1',
            fare: const Pence(2015),
            pickupLabel: 'Wolverhampton City Center',
            dropoffLabel: 'Transit station in Wolverhampton, England',
            estimatedMiles: 2.9,
            estimatedDurationSeconds: 780,
            pickupEtaSeconds: 300,
            pickup: (lat: 52.586, lng: -2.128),
            dropoff: (lat: 52.587, lng: -2.12),
            expiresInSec: 15,
            receivedAt: DateTime.now(),
          )
        ]));

    await capture(tester, const HomeScreen(), '1_offer');
  });

  testWidgets('2 heading to pickup', (tester) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('accepted')));
    await capture(tester, const TripScreen(rideId: 'r1'), '2_heading_to_pickup');
  });

  testWidgets('3 waiting at pickup', (tester) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('arrived',
        arrivedAt:
            DateTime.now().toUtc().subtract(const Duration(minutes: 7)))));
    await capture(tester, const TripScreen(rideId: 'r1'), '3_waiting');
  });

  testWidgets('4 trip in progress', (tester) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('started')));
    await capture(tester, const TripScreen(rideId: 'r1'), '4_in_trip');
  });

  testWidgets('5 cancel sheet', (tester) async {
    await capture(
        tester,
        const Scaffold(body: CancelSheet(freeCancelRemaining: 157)),
        '5_cancel_sheet');
  });

  testWidgets('6 finish summary', (tester) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('completed')));
    await capture(tester, const TripScreen(rideId: 'r1'), '6_finish_summary');
  });
}

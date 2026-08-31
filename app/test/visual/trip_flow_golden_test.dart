import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/ui/trip_screen.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/cancel_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockReasonRepo extends Mock implements CancelReasonRepository {}

class _MockEarningsRepo extends Mock implements EarningsRepository {}

/// Renders each trip-flow phase at the Figma artboard size and writes it to
/// `test/visual/goldens/`, so the build can be held against the design by eye.
///
/// The map itself never renders in a widget test (GoogleMap is a platform
/// view), so these goldens are about the chrome the design owns: the status
/// pill, the floating cards, the sheet and its action button.
///
/// Run with `flutter test --update-goldens test/visual/trip_flow_golden_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // GoogleMap is a platform view, which has no implementation in a widget
  // test — it throws MissingPluginException and fails the frame. Answering
  // the channel keeps the map an empty rectangle so the chrome the design
  // actually owns (pills, cards, sheet) is what gets goldened.
  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create' ? 0 : null,
    );
    // The controller then talks to its own per-view channel. Ids are handed
    // out from 0 upward; a handful covers every map this file builds.
    for (var id = 0; id < 12; id++) {
      messenger.setMockMethodCallHandler(
        MethodChannel('plugins.flutter.io/google_maps_$id'),
        (_) async => null,
      );
    }
  });

  const rider = Rider(
      id: 'u1', fullName: 'Taimoor Ali Asghar', rating: 4.9, ratingCount: 128);

  Ride ride(String status, {DateTime? arrivedAt}) => Ride(
        id: 'r1',
        status: status,
        ref: 'R-1042',
        rider: rider,
        pickupEtaSeconds: 240,
        acceptedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 4)),
        arrivedAt: arrivedAt,
        geo: const RideGeo(
          pickup: GeoPoint(lat: 53.49, lng: -2.24, label: 'Cheetham Hill'),
          dropoff:
              GeoPoint(lat: 53.52, lng: -2.20, label: 'Penrith Call, United Kingdom'),
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

  setUp(() {
    trip = _MockTripRepo();
    reasons = _MockReasonRepo();
    earnings = _MockEarningsRepo();

    when(() => trip.riderContext(any())).thenAnswer(
        (_) async => Err(ApiException('NOT_FOUND', 'no rider context', 404)));
    when(() => trip.waitingPolicy(any())).thenAnswer((_) async => Ok(
        WaitingPolicy(
          freeWaitSeconds: 180,
          perMinutePence: const Pence(30),
          noShowFeePence: const Pence(5900),
          arrivedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
          billableFrom:
              DateTime.now().toUtc().add(const Duration(seconds: 119)),
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
          CancelReason(
              id: 'other',
              text: 'Other Reason',
              pickable: true,
              freeCancelSeconds: 400),
        ]));
    when(() => earnings.rideEarnings(any())).thenAnswer((_) async => const Ok(
        RideEarnings(
          base: Pence(1405),
          distance: Pence(305),
          time: Pence(305),
          surge: Pence(0),
          waiting: Pence(0),
          commission: Pence(0),
          net: Pence(2015),
        )));
  });

  Future<void> capture(
    WidgetTester tester,
    String name, {
    Size size = const Size(430, 932),
    Future<void> Function(WidgetTester)? after,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trip),
        cancelReasonRepositoryProvider.overrideWithValue(reasons),
        earningsRepositoryProvider.overrideWithValue(earnings),
        currentUserIdProvider.overrideWithValue('driver-1'),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TripScreen(rideId: 'r1'),
      ),
    ));
    // The waiting card and timer tick once a second, so pumpAndSettle would
    // never return. Fixed pumps are enough for a still frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (after != null) await after(tester);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('heading to pickup', (t) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('accepted')));
    await capture(t, 'trip_heading_to_pickup');
  });

  testWidgets('waiting for passenger', (t) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('arrived',
        arrivedAt:
            DateTime.now().toUtc().subtract(const Duration(minutes: 1)))));
    await capture(t, 'trip_waiting');
  });

  testWidgets('under way', (t) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(ride('in_progress')));
    await capture(t, 'trip_in_progress');
  });

  // The cancel sheet is captured by 'cancel sheet alone' below, at a
  // viewport that fits it. Driving it open over the map here never renders
  // the reason list inside a golden harness, and a second capture of the
  // same sheet earns nothing.

  testWidgets('cancel sheet alone', (t) async {
    t.view.physicalSize = const Size(430, 700);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        cancelReasonRepositoryProvider.overrideWithValue(reasons),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black26,
          // The real sheet is a modal pinned to the bottom of the screen;
          // aligning it here goldens it the way a driver actually sees it.
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CancelSheet(freeCancelRemaining: 157),
          ),
        ),
      ),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/trip_cancel_sheet_only.png'));
  });

  testWidgets('finish ride summary', (t) async {
    when(() => trip.ride('r1')).thenAnswer((_) async => Ok(ride('completed')));
    await capture(t, 'trip_finish_summary');
  });
}

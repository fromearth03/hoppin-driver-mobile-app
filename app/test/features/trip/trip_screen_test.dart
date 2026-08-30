import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/auth/token_store.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/cancel_reason.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/waiting_policy.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/ui/trip_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

class MockReasonRepo extends Mock implements CancelReasonRepository {}

Ride buildRide(String status) => Ride(
      id: 'r1',
      status: status,
      ref: 'R-1042',
      rider: const Rider(id: 'u1', fullName: 'Alex Morgan', rating: 4.8),
      geo: const RideGeo(
        pickup: GeoPoint(lat: 1, lng: 2, label: 'City Centre'),
        dropoff: GeoPoint(lat: 3, lng: 4, label: 'Station'),
      ),
    );

Widget wrap(MockTripRepo trip, MockReasonRepo reasons) => ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(trip),
        cancelReasonRepositoryProvider.overrideWithValue(reasons),
        currentUserIdProvider.overrideWithValue('driver-1'),
      ],
      child: const MaterialApp(home: TripScreen(rideId: 'r1')),
    );

void main() {
  late MockTripRepo trip;
  late MockReasonRepo reasons;

  setUp(() {
    trip = MockTripRepo();
    reasons = MockReasonRepo();
    // The controller now enriches a live ride with rider-context. These
    // tests are not about the rider, so answer with the empty-handed case.
    when(() => trip.riderContext(any())).thenAnswer(
        (_) async => Err(ApiException('NOT_FOUND', 'no rider context', 404)));

    when(() => trip.waitingPolicy(any())).thenAnswer((_) async => const Ok(
        WaitingPolicy(
            freeWaitSeconds: 180,
            perMinutePence: Pence(30),
            noShowFeePence: Pence(5900))));
    when(() => reasons.forDriver()).thenAnswer((_) async => const Ok([
          CancelReason(
              id: 'vehicle_issue', text: 'Vehicle issue', pickable: true),
          CancelReason(
            id: 'rider_no_show',
            text: "Rider didn't show up",
            pickable: true,
            penaltyFee: Pence(5900),
          ),
        ]));
  });

  testWidgets('offers Arrived while heading to the pickup', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.text('Arrived at Pickup'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
  });

  testWidgets('offers Start Trip once arrived, with the charging terms',
      (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.text('Start Trip'), findsOneWidget);
    expect(find.textContaining('free waiting'), findsOneWidget);
  });

  testWidgets('offers Finish Trip while under way', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('in_progress')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.text('Finish Trip'), findsOneWidget);
  });

  testWidgets('shows the ride reference for support', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();

    expect(find.textContaining('R-1042'), findsOneWidget);
  });

  testWidgets('the cancel sheet lists only pickable reasons', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('accepted')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle issue'), findsOneWidget);
    expect(find.text("Rider didn't show up"), findsOneWidget);
  });

  testWidgets('a reason carrying a penalty states the exact charge first',
      (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Rider didn't show up"));
    await tester.pumpAndSettle();

    // The driver sees the amount before the charge, not after.
    expect(find.textContaining('£59.00'), findsOneWidget);
    verifyNever(() => trip.cancel(any(), reasonId: any(named: 'reasonId'), driverUserId: any(named: 'driverUserId')));
  });

  testWidgets('an early no-show says how long is left', (tester) async {
    when(() => trip.ride('r1'))
        .thenAnswer((_) async => Ok(buildRide('arrived')));
    when(() => trip.cancel(any(), reasonId: any(named: 'reasonId'), driverUserId: any(named: 'driverUserId'))).thenAnswer(
        (_) async => Err(ApiException('NO_SHOW_TOO_EARLY', '', 400,
            fields: {'seconds_remaining': 120})));

    await tester.pumpWidget(wrap(trip, reasons));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Rider didn't show up"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel ride'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 min'), findsOneWidget);
  });
}

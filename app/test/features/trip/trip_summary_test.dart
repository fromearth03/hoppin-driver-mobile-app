import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/trip_summary.dart';
import 'package:mocktail/mocktail.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockEarningsRepo extends Mock implements EarningsRepository {}

void main() {
  late _MockTripRepo trip;
  late _MockEarningsRepo earnings;

  const ride = Ride(
    id: 'r1',
    status: 'completed',
    ref: 'R-1',
    geo: RideGeo(
      pickup: GeoPoint(lat: 1, lng: 1, label: 'A'),
      dropoff: GeoPoint(lat: 2, lng: 2, label: 'B'),
    ),
  );

  setUp(() {
    trip = _MockTripRepo();
    earnings = _MockEarningsRepo();
    // The money half is not under test; a failed read renders the pending
    // copy and keeps the rating card interactive.
    when(() => earnings.rideEarnings(any())).thenAnswer(
        (_) async => Err(ApiException('NOT_FOUND', 'settling', 404)));
    when(() => trip.rate(any(),
            score: any(named: 'score'), comments: any(named: 'comments')))
        .thenAnswer((_) async => const Ok(null));
  });

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(trip),
          earningsRepositoryProvider.overrideWithValue(earnings),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('chosen quick tags are folded into the comments', (tester) async {
    await tester
        .pumpWidget(wrap(TripSummary(ride: ride, onDone: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('4 stars'));
    await tester.pump();
    await tester.tap(find.text('Clean'));
    await tester.tap(find.text('Ready on Time'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'smooth trip');
    await tester.ensureVisible(find.text('Ready for Next Request'));
    await tester.tap(find.text('Ready for Next Request'));
    await tester.pumpAndSettle();

    // Tag order follows the chip row, not tap order, so the wording is
    // stable however the driver picked them.
    verify(() => trip.rate('r1',
        score: 4, comments: 'Clean, Ready on Time. smooth trip')).called(1);
  });

  testWidgets('a deselected tag does not reach the comments', (tester) async {
    await tester
        .pumpWidget(wrap(TripSummary(ride: ride, onDone: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('5 stars'));
    await tester.pump();
    await tester.tap(find.text('Polite'));
    await tester.pump();
    await tester.tap(find.text('Polite')); // toggle off
    await tester.pump();
    await tester.tap(find.text('Quiet'));
    await tester.pump();
    await tester.ensureVisible(find.text('Ready for Next Request'));
    await tester.tap(find.text('Ready for Next Request'));
    await tester.pumpAndSettle();

    verify(() => trip.rate('r1', score: 5, comments: 'Quiet')).called(1);
  });

  testWidgets('an unrated trip sends nothing, tags or not', (tester) async {
    var done = false;
    await tester
        .pumpWidget(wrap(TripSummary(ride: ride, onDone: () => done = true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clean'));
    await tester.pump();
    await tester.ensureVisible(find.text('Ready for Next Request'));
    await tester.tap(find.text('Ready for Next Request'));
    await tester.pumpAndSettle();

    // The handler rejects a zero score, so tags alone must not trigger a
    // doomed request — the driver just moves on.
    verifyNever(() => trip.rate(any(),
        score: any(named: 'score'), comments: any(named: 'comments')));
    expect(done, isTrue);
  });
}

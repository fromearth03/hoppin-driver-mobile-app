import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:hoppin_driver/features/trips/ui/trips_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockTripsRepo extends Mock implements TripsRepository {}

DriverTrip completed() => DriverTrip(
      id: 'r1',
      ref: 'R-1042',
      status: 'completed',
      pickupLabel: 'City Centre',
      dropoffLabel: 'Railway Station',
      distanceMiles: 3.2,
      earnings: const Pence(830),
      penalty: const Pence(0),
      completedAt: DateTime.now(),
    );

DriverTrip cancelled({int penalty = 5900, String by = 'rider'}) => DriverTrip(
      id: 'r2',
      ref: 'R-1038',
      status: 'cancelled',
      pickupLabel: 'Bilston Road',
      dropoffLabel: 'City Centre',
      earnings: const Pence(0),
      penalty: Pence(penalty),
      cancelledBy: by,
      completedAt: DateTime.now(),
    );

Widget wrap(MockTripsRepo repo) => ProviderScope(
      overrides: [tripsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TripsScreen()),
    );

void main() {
  // mocktail needs a concrete TripFilter to stand in for `any(named:)` on a
  // non-nullable enum argument.
  setUpAll(() => registerFallbackValue(TripFilter.all));

  late MockTripsRepo repo;
  setUp(() => repo = MockTripsRepo());

  void stub(List<DriverTrip> trips) {
    when(() => repo.page(
            filter: any(named: 'filter'), cursor: any(named: 'cursor')))
        .thenAnswer((_) async => Ok(TripsPage(trips: trips)));
  }

  testWidgets('shows the three filters', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('shows the reference so a driver can quote it', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('R-1042'), findsOneWidget);
  });

  testWidgets('shows earnings on a completed trip', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('+£8.30'), findsOneWidget);
  });

  testWidgets('states who cancelled and shows the penalty', (tester) async {
    stub([cancelled()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Cancelled by rider'), findsOneWidget);
    expect(find.text('−£59.00'), findsOneWidget);
  });

  testWidgets('a cancellation with no penalty shows an em dash, not £0.00',
      (tester) async {
    stub([cancelled(penalty: 0)]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
    expect(find.text('£0.00'), findsNothing);
  });

  testWidgets('changing the filter refetches server-side', (tester) async {
    stub([completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();

    verify(() => repo.page(
        filter: TripFilter.cancelled, cursor: any(named: 'cursor'))).called(1);
  });

  testWidgets('the empty state names the filter', (tester) async {
    stub([]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No cancelled trips'), findsOneWidget);
  });

  testWidgets('shows no totals — that is the Earnings screen job',
      (tester) async {
    stub([completed(), completed()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Two screens computing the same total is two screens that can disagree.
    expect(find.textContaining('Total'), findsNothing);
  });
}

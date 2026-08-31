import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';
import 'package:hoppin_driver/features/earnings/ui/earnings_screen.dart';
import 'package:hoppin_driver/features/trips/data/models/driver_trip.dart';
import 'package:hoppin_driver/features/trips/data/trips_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockEarningsRepo extends Mock implements EarningsRepository {}

class MockTripsRepo extends Mock implements TripsRepository {}

Widget wrap(MockEarningsRepo repo, MockTripsRepo trips) => ProviderScope(
      overrides: [
        earningsRepositoryProvider.overrideWithValue(repo),
        tripsRepositoryProvider.overrideWithValue(trips),
      ],
      child: const MaterialApp(home: EarningsScreen()),
    );

void main() {
  setUpAll(() => registerFallbackValue(TripFilter.all));

  late MockEarningsRepo repo;
  late MockTripsRepo trips;

  setUp(() {
    repo = MockEarningsRepo();
    trips = MockTripsRepo();
    // The screen shows all four periods at once, so every one is stubbed;
    // the week is the selected default and carries the figures under test.
    when(() => repo.summary(any())).thenAnswer((_) async => Ok(EarningsSummary(
          net: const Pence(24000),
          gross: const Pence(30000),
          commission: const Pence(6000),
          tripCount: 12,
          from: DateTime(2026, 8, 17),
          to: DateTime(2026, 8, 24),
        )));
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(Wallet(
        availableBalance: Pence(21050), pendingBalance: Pence(4200))));
    // Bonus campaigns are their own concern; these tests are about money
    // already earned.
    when(() => repo.promotions()).thenAnswer((_) async => const Ok([]));
    when(() => trips.page(
          filter: any(named: 'filter'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Ok(TripsPage(trips: [])));
  });

  testWidgets('shows the period total', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    // Once per period card, once as the breakdown's net total.
    expect(find.text('£240.00'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('changing the period refetches', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Month'));
    await tester.pumpAndSettle();

    // Twice: once in the initial all-periods load, once for the reload the
    // selection triggered.
    verify(() => repo.summary('month')).called(2);
    expect(find.text("This Month's Breakdown"), findsOneWidget);
  });

  testWidgets('shows the deductions between gross and net', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    expect(find.text('Gross Earnings'), findsOneWidget);
    expect(find.text('- £60.00'), findsOneWidget);
    expect(find.text('Net Total'), findsOneWidget);
  });

  testWidgets('never invents a tip line', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    // Tips do not exist anywhere in the backend. The design's line items
    // must never grow one.
    expect(find.textContaining('Tip'), findsNothing);
  });

  testWidgets('omits a deduction that did not apply', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    // Settlement writes tax as a literal zero; a "Tax £0.00" row would
    // assert a treatment nobody has signed off.
    expect(find.text('Tax'), findsNothing);
    expect(find.text('Penalties'), findsNothing);
  });

  testWidgets('shows payout history read-only, with no retry', (tester) async {
    when(() => repo.wallet()).thenAnswer((_) async => Ok(Wallet(
          availableBalance: const Pence(0),
          pendingBalance: const Pence(0),
          recentPayouts: [
            Payout(
                id: 'p1',
                amount: const Pence(21050),
                status: 'paid',
                transferredAt: DateTime.utc(2026, 8, 25)),
            const Payout(
                id: 'p2',
                amount: Pence(8800),
                status: 'failed',
                failureReason: 'Bank rejected the transfer'),
          ],
        )));

    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    expect(find.text('£210.50'), findsOneWidget);
    expect(find.text('Reason: Bank rejected the transfer'), findsOneWidget);
    // Payouts are operator-run; the design puts a Retry beside the failure
    // reason and there is no endpoint behind it.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('offers no way to add a payout method', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add payment'), findsNothing);
    expect(find.textContaining('Add bank'), findsNothing);
    // The design's masked bank number and payout-method card have no source
    // in the app's data at all.
    expect(find.textContaining('****'), findsNothing);
    expect(find.textContaining('Payouts Methods'), findsNothing);
  });

  testWidgets('promises no next payout date or threshold', (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    // The design's Next Payout card — a date, a countdown chip, a progress
    // bar and a threshold — has no endpoint. None of it is drawn.
    expect(find.textContaining('Next Payout'), findsNothing);
    expect(find.textContaining('Threshold'), findsNothing);
  });

  testWidgets('a driver in debt sees it here too', (tester) async {
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(
        Wallet(availableBalance: Pence(-5000), pendingBalance: Pence(0))));

    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    expect(find.text('−£50.00'), findsOneWidget);
    // A red "Company Owes You" is a contradiction; debt says so.
    expect(find.text('You Owe'), findsOneWidget);
  });

  testWidgets('lists the trips behind the selected period', (tester) async {
    when(() => trips.page(
          filter: any(named: 'filter'),
          from: any(named: 'from'),
          to: any(named: 'to'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => Ok(TripsPage(trips: [
          DriverTrip(
            id: 't1',
            status: 'completed',
            pickupLabel: 'City centre',
            dropoffLabel: 'Railway Station',
            earnings: const Pence(1000),
            penalty: const Pence(0),
            completedAt: DateTime.now(),
          ),
        ])));

    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    expect(find.text('Railway Station'), findsOneWidget);
    expect(find.text('£10.00'), findsOneWidget);
    expect(find.text('View All Trips'), findsOneWidget);
  });

  testWidgets('offers CSV, the only format the service produces',
      (tester) async {
    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    expect(find.text('CSV'), findsOneWidget);
    // The design's dropdown defaults to PDF; the report endpoint 400s on it.
    expect(find.text('PDF'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('a summary that fails to load shows no total of zero',
      (tester) async {
    when(() => repo.summary(any()))
        .thenAnswer((_) async => Err(ApiException('INTERNAL', '', 500)));

    await tester.pumpWidget(wrap(repo, trips));
    await tester.pumpAndSettle();

    // Zero would read as "you earned nothing", which is a different and
    // much worse claim than "this did not load".
    expect(find.text('£0.00'), findsNothing);
  });
}

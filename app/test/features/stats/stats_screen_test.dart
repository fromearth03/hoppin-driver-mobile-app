import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/stats/data/appeals_repository.dart';
import 'package:hoppin_driver/features/stats/data/models/appeal.dart';
import 'package:hoppin_driver/features/stats/data/models/driver_stats.dart';
import 'package:hoppin_driver/features/stats/data/models/penalty.dart';
import 'package:hoppin_driver/features/stats/data/stats_repository.dart';
import 'package:hoppin_driver/features/stats/ui/stats_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockStatsRepo extends Mock implements StatsRepository {}

class MockAppealsRepo extends Mock implements AppealsRepository {}

Widget wrap(MockStatsRepo stats, MockAppealsRepo appeals) => ProviderScope(
      overrides: [
        statsRepositoryProvider.overrideWithValue(stats),
        appealsRepositoryProvider.overrideWithValue(appeals),
      ],
      child: const MaterialApp(home: StatsScreen()),
    );

void main() {
  setUpAll(() => registerFallbackValue(StatsPeriod.month));

  late MockStatsRepo stats;
  late MockAppealsRepo appeals;

  /// The default 800x600 test window puts the penalties card below the fold,
  /// where a tap lands on nothing. Give every test a phone-sized viewport so
  /// the accordion is reachable.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  void givenStats(DriverStats value) =>
      when(() => stats.stats(period: any(named: 'period')))
          .thenAnswer((_) async => Ok(value));

  setUp(() {
    stats = MockStatsRepo();
    appeals = MockAppealsRepo();
    when(() => appeals.mine()).thenAnswer((_) async => const Ok([]));
    when(() => stats.penalties()).thenAnswer(
        (_) async => const Ok(PenaltyList(penalties: [], count: 0)));
  });

  testWidgets('shows the rating and trip counts', (tester) async {
    givenStats(const DriverStats(
        averageRating: 4.8,
        ratingCount: 5,
        tripsCompleted: 15,
        acceptanceRate: 0.94));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
  });

  testWidgets('an unknown rate shows an em dash, not 0%', (tester) async {
    givenStats(const DriverStats());

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('says whose cancellations are being counted', (tester) async {
    givenStats(const DriverStats(tripsCancelled: 3, cancellationRate: 0.04));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    // Rider and admin cancels are excluded server-side; the driver needs to
    // know the number is theirs alone.
    expect(find.textContaining('you cancelled'), findsOneWidget);
    expect(find.text('4%'), findsOneWidget);
  });

  testWidgets('never puts a currency symbol on a trip count', (tester) async {
    givenStats(const DriverStats(tripsCompleted: 1247));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    // The Figma renders this tile as "£ 1247.00". It is a count.
    expect(find.text('1247'), findsOneWidget);
    expect(find.text('£1247'), findsNothing);
    expect(find.textContaining('£'), findsNothing);
  });

  testWidgets('shows the window the service resolved, not one we invented',
      (tester) async {
    givenStats(DriverStats(
      period: StatsPeriod.month,
      from: DateTime.utc(2026, 8, 1),
      to: DateTime.utc(2026, 8, 31),
    ));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('This Month'), findsOneWidget);
    expect(find.textContaining('1 Aug'), findsOneWidget);
  });

  testWidgets('prints no date range before the service has sent one',
      (tester) async {
    givenStats(const DriverStats(period: StatsPeriod.month));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('This Month'), findsOneWidget);
    // A made-up range under a real figure would be worse than no range.
    expect(find.textContaining(' - '), findsNothing);
  });

  testWidgets('the penalty count opens the list', (tester) async {
    givenStats(const DriverStats(penaltiesActive: 2));
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 2,
          penalties: [
            Penalty(
              id: 'p1',
              createdAt: DateTime.utc(2026, 8, 26),
              amount: const Pence(1000),
              displayTitle: 'Complaint penalty',
              displayReason: 'A penalty following a rider complaint.',
              appealable: true,
            ),
          ],
        )));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    // The group header states the count; the detail sits behind the tap.
    expect(find.text('Active (1)'), findsOneWidget);
    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Complaint penalty'), findsOneWidget);
    expect(find.text('A penalty following a rider complaint.'), findsOneWidget);
    expect(find.textContaining('£10.00'), findsOneWidget);
  });

  testWidgets('offers Appeal only where the server allows it', (tester) async {
    givenStats(const DriverStats(penaltiesActive: 2));
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 2,
          penalties: [
            Penalty(
                id: 'p1',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(1000),
                displayTitle: 'Appealable',
                appealable: true),
            Penalty(
                id: 'p2',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(300),
                displayTitle: 'Not appealable',
                appealable: false),
          ],
        )));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Appeal'), findsOneWidget);
  });

  testWidgets('never shows an appeal countdown it has no deadline for',
      (tester) async {
    givenStats(const DriverStats());
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 1,
          penalties: [
            Penalty(
                id: 'p1',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(1200),
                displayTitle: 'Cancellation after arrival',
                appealable: true),
          ],
        )));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();

    // The Figma shows "Appeal window: 48h left". No penalty field carries a
    // deadline, so promising one would be a lie the driver could act on.
    expect(find.textContaining('48h'), findsNothing);
    expect(find.textContaining('Appeal window'), findsNothing);
  });

  testWidgets('a resolved appeal shows the reviewer note', (tester) async {
    givenStats(const DriverStats());
    when(() => appeals.mine()).thenAnswer((_) async => Ok([
          Appeal(
            id: 'a1',
            reason: 'It was in date',
            status: AppealStatus.approved,
            reviewNote: 'Confirmed — the certificate was valid. Reinstated.',
            createdAt: DateTime.utc(2026, 8, 28),
          )
        ]));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolved (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed — the certificate was valid. Reinstated.'),
        findsOneWidget);
  });

  testWidgets('an appeal under review says so without inventing an outcome',
      (tester) async {
    givenStats(const DriverStats());
    when(() => appeals.mine()).thenAnswer((_) async => Ok([
          Appeal(
            id: 'a2',
            reason: 'Please review',
            status: AppealStatus.underReview,
            createdAt: DateTime.utc(2026, 8, 28),
          )
        ]));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Under review (1)'), findsOneWidget);

    await tester.tap(find.text('Under review (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsWidgets);
    // The Figma promises "Decision within 24h". Nothing states an SLA.
    expect(find.textContaining('24h'), findsNothing);
  });

  testWidgets('the appeal modal fixes the design typos and promises no SLA',
      (tester) async {
    givenStats(const DriverStats());
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 1,
          penalties: [
            Penalty(
                id: 'p1',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(1200),
                displayTitle: 'Cancellation after arrival',
                appealable: true),
          ],
        )));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appeal'));
    await tester.pumpAndSettle();

    expect(find.text('Appeal Penalty'), findsOneWidget);
    // "reviewd" and "with 48 hours" in the Figma; and no SLA is stated in
    // the contract, so no hours are promised at all.
    expect(find.textContaining('reviewd'), findsNothing);
    expect(find.textContaining('48 hours'), findsNothing);
    expect(find.textContaining('reviewer reads every appeal'), findsOneWidget);
  });

  testWidgets('the appeal modal names the penalty being appealed',
      (tester) async {
    givenStats(const DriverStats());
    when(() => stats.penalties()).thenAnswer((_) async => Ok(PenaltyList(
          count: 1,
          penalties: [
            Penalty(
                id: 'p1',
                createdAt: DateTime.utc(2026, 8, 26),
                amount: const Pence(1200),
                displayTitle: 'Cancellation after arrival',
                appealable: true),
          ],
        )));

    phone(tester);
    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appeal'));
    await tester.pumpAndSettle();

    // The endpoint takes no penalty id, so the subject is stated rather
    // than offered as a picker that could file against the wrong thing.
    expect(find.text('Cancellation after arrival'), findsWidgets);
    expect(find.text('Document Selection'), findsNothing);
  });
}

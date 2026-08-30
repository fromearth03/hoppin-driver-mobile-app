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
  late MockStatsRepo stats;
  late MockAppealsRepo appeals;

  setUp(() {
    stats = MockStatsRepo();
    appeals = MockAppealsRepo();
    when(() => appeals.mine()).thenAnswer((_) async => const Ok([]));
    when(() => stats.penalties()).thenAnswer(
        (_) async => const Ok(PenaltyList(penalties: [], count: 0)));
  });

  testWidgets('shows the rating and trip counts', (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats(
        averageRating: 4.8,
        ratingCount: 5,
        tripsCompleted: 15,
        acceptanceRate: 0.94)));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
  });

  testWidgets('an unknown rate shows an em dash, not 0%', (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats()));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('says whose cancellations are being counted', (tester) async {
    when(() => stats.stats())
        .thenAnswer((_) async => const Ok(DriverStats(tripsCancelled: 3)));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    // Rider and admin cancels are excluded server-side; the driver needs to
    // know the number is theirs alone.
    expect(find.textContaining('you cancelled'), findsOneWidget);
  });

  testWidgets('never puts a currency symbol on a trip count', (tester) async {
    when(() => stats.stats())
        .thenAnswer((_) async => const Ok(DriverStats(tripsCompleted: 1247)));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('1247'), findsOneWidget);
    expect(find.text('£1247'), findsNothing);
  });

  testWidgets('the penalty count opens the list', (tester) async {
    when(() => stats.stats())
        .thenAnswer((_) async => const Ok(DriverStats(penaltiesCount: 2)));
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

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Complaint penalty'), findsOneWidget);
    expect(find.text('A penalty following a rider complaint.'), findsOneWidget);
    expect(find.text('£10.00'), findsOneWidget);
  });

  testWidgets('offers Appeal only where the server allows it', (tester) async {
    when(() => stats.stats())
        .thenAnswer((_) async => const Ok(DriverStats(penaltiesCount: 2)));
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

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Appeal'), findsOneWidget);
  });

  testWidgets('a resolved appeal shows the reviewer note', (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats()));
    when(() => appeals.mine()).thenAnswer((_) async => Ok([
          Appeal(
            id: 'a1',
            reason: 'It was in date',
            status: AppealStatus.approved,
            reviewNote: 'Confirmed — the certificate was valid. Reinstated.',
            createdAt: DateTime.utc(2026, 8, 28),
          )
        ]));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed — the certificate was valid. Reinstated.'),
        findsOneWidget);
  });

  testWidgets('an appeal under review says so without inventing an outcome',
      (tester) async {
    when(() => stats.stats()).thenAnswer((_) async => const Ok(DriverStats()));
    when(() => appeals.mine()).thenAnswer((_) async => Ok([
          Appeal(
            id: 'a2',
            reason: 'Please review',
            status: AppealStatus.underReview,
            createdAt: DateTime.utc(2026, 8, 28),
          )
        ]));

    await tester.pumpWidget(wrap(stats, appeals));
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsOneWidget);
  });
}

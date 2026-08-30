import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/earnings/data/earnings_repository.dart';
import 'package:hoppin_driver/features/earnings/data/models/ride_earnings.dart';
import 'package:hoppin_driver/features/earnings/data/models/wallet.dart';
import 'package:hoppin_driver/features/earnings/ui/earnings_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockEarningsRepo extends Mock implements EarningsRepository {}

Widget wrap(MockEarningsRepo repo) => ProviderScope(
      overrides: [earningsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: EarningsScreen()),
    );

void main() {
  late MockEarningsRepo repo;

  setUp(() {
    repo = MockEarningsRepo();
    when(() => repo.summary(any())).thenAnswer((_) async =>
        const Ok(EarningsSummary(total: Pence(24000), tripCount: 12)));
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(Wallet(
        availableBalance: Pence(21050), pendingBalance: Pence(4200))));
  });

  testWidgets('shows the period total', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£240.00'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
  });

  testWidgets('changing the period refetches', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    verify(() => repo.summary('month')).called(1);
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

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£210.50'), findsOneWidget);
    expect(find.text('Bank rejected the transfer'), findsOneWidget);
    // Payouts are operator-run; a Retry the driver cannot action would be
    // a button that lies.
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('offers no way to add a payout method', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Add payment'), findsNothing);
    expect(find.textContaining('Add bank'), findsNothing);
  });

  testWidgets('a driver in debt sees it here too', (tester) async {
    when(() => repo.wallet()).thenAnswer((_) async => const Ok(
        Wallet(availableBalance: Pence(-5000), pendingBalance: Pence(0))));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('−£50.00'), findsOneWidget);
  });
}

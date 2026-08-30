import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/statement/data/ledger_repository.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_entry.dart';
import 'package:hoppin_driver/features/statement/ui/statement_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockLedgerRepo extends Mock implements LedgerRepository {}

LedgerEntry entry({
  int amount = -300,
  String title = 'Late arrival penalty',
  String? reason = 'A penalty for arriving late to a pickup.',
}) =>
    LedgerEntry(
      id: 'e1',
      createdAt: DateTime.utc(2026, 8, 30, 9, 12),
      amount: Pence(amount),
      entryType: 'penalty',
      displayTitle: title,
      displayReason: reason,
      runningBalance: const Pence(-5000),
    );

Widget wrap(MockLedgerRepo repo) => ProviderScope(
      overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: StatementScreen()),
    );

void main() {
  late MockLedgerRepo repo;
  setUp(() => repo = MockLedgerRepo());

  testWidgets('shows a negative balance plainly and signed', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Debt is stated, not euphemised.
    expect(find.text('−£50.00'), findsOneWidget);
  });

  testWidgets('renders the server title and reason verbatim', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Late arrival penalty'), findsOneWidget);
    expect(
        find.text('A penalty for arriving late to a pickup.'), findsOneWidget);
  });

  testWidgets('never asserts a deduction the backend refused to write',
      (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('deducted'), findsNothing);
    expect(find.textContaining('VAT'), findsNothing);
  });

  testWidgets('a positive balance is what the company owes', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(21050), entries: [
          entry(amount: 830, title: 'Trip earnings', reason: null)
        ])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£210.50'), findsOneWidget);
    expect(find.textContaining('owe'), findsNothing);
  });

  testWidgets('offers Dispute on a charge but not on a credit', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(-5000), entries: [
          entry(),
          entry(amount: 830, title: 'Trip earnings', reason: null),
        ])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Disputing money you were paid makes no sense; only charges get it.
    expect(find.text('Dispute'), findsOneWidget);
  });

  testWidgets('an empty statement says so', (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer(
        (_) async => const Ok(LedgerPage(balance: Pence(0), entries: [])));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('No entries'), findsOneWidget);
  });
}

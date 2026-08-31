import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/statement/data/ledger_repository.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_entry.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_summary.dart';
import 'package:hoppin_driver/features/statement/ui/statement_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';

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

/// Stubs both calls the screen makes. The summary is optional to the screen
/// but not to the mock: an unstubbed method throws, which would fail every
/// test for the wrong reason.
void stub(
  MockLedgerRepo repo, {
  required int balance,
  required List<LedgerEntry> entries,
  LedgerSummary? summary,
}) {
  when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer(
      (_) async => Ok(LedgerPage(balance: Pence(balance), entries: entries)));
  when(() => repo.summary(any())).thenAnswer(
      (_) async => Ok(summary ?? LedgerSummary(closing: Pence(balance))));
}

Widget wrap(MockLedgerRepo repo) => ProviderScope(
      overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: StatementScreen()),
    );

void main() {
  late MockLedgerRepo repo;
  setUp(() => repo = MockLedgerRepo());

  testWidgets('states a debt as a debt, at its real size', (tester) async {
    stub(repo, balance: -5000, entries: [entry()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Debt is named, not euphemised, and the figure is the real one.
    expect(find.text('What you owe the company'), findsOneWidget);
    expect(find.text('£50.00'), findsWidgets);
  });

  testWidgets('renders the server title and reason verbatim', (tester) async {
    stub(repo, balance: -5000, entries: [entry()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Late arrival penalty'), findsOneWidget);
    expect(
        find.text('A penalty for arriving late to a pickup.'), findsOneWidget);
  });

  testWidgets('never asserts a deduction the backend refused to write',
      (tester) async {
    stub(repo, balance: -5000, entries: [entry()]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('deducted'), findsNothing);
    expect(find.textContaining('VAT'), findsNothing);
  });

  testWidgets('never invents a tip line the backend has no field for',
      (tester) async {
    stub(repo, balance: 24580, entries: [entry(amount: 830)]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Tips do not exist anywhere in the backend; the design's "Tip
    // correction" row would be a number the app made up.
    expect(find.textContaining('Tip'), findsNothing);
  });

  testWidgets('a positive balance is what the company owes', (tester) async {
    stub(repo, balance: 21050, entries: [
      entry(amount: 830, title: 'Trip earnings', reason: null),
    ]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('£210.50'), findsWidgets);
    // Credit is never framed as a debt.
    expect(find.text('What you owe the company'), findsNothing);
    expect(find.text('What the company owes you'), findsOneWidget);
  });

  testWidgets('breaks the period down from the server summary', (tester) async {
    stub(
      repo,
      balance: -24580,
      entries: [entry()],
      summary: const LedgerSummary(
        period: 'week',
        opening: Pence(-18060),
        credits: Pence(9520),
        debits: Pence(-16040),
        closing: Pence(-24580),
      ),
    );

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Opening balance'), findsOneWidget);
    expect(find.text('−£180.60'), findsOneWidget);
    expect(find.text('£95.20'), findsOneWidget);
    // debits_pence arrives negative and is printed as received, not re-signed.
    expect(find.text('−£160.40'), findsOneWidget);
    expect(find.text('Total outstanding'), findsOneWidget);
  });

  testWidgets('a failed summary still shows the balance and the entries',
      (tester) async {
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: const Pence(-5000), entries: [entry()])));
    when(() => repo.summary(any())).thenAnswer((_) async =>
        Err(ApiException('INTERNAL', 'server error', 500)));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // The breakdown is a nicety; the balance is the point of the screen.
    expect(find.text('£50.00'), findsOneWidget);
    expect(find.text('Late arrival penalty'), findsOneWidget);
    expect(find.text('Opening balance'), findsNothing);
  });

  testWidgets('offers Dispute on a charge but not on a credit', (tester) async {
    stub(repo, balance: -5000, entries: [
      entry(),
      entry(amount: 830, title: 'Trip earnings', reason: null),
    ]);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // Disputing money you were paid makes no sense; only charges get it.
    expect(find.text('Dispute'), findsOneWidget);
  });

  testWidgets('an empty statement says so', (tester) async {
    stub(repo, balance: 0, entries: []);

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('No entries'), findsOneWidget);
  });
}

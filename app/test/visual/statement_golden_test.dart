import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/payment/data/models/payout_status.dart';
import 'package:hoppin_driver/features/payment/data/payout_repository.dart';
import 'package:hoppin_driver/features/payment/ui/payout_screen.dart';
import 'package:hoppin_driver/features/statement/data/ledger_repository.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_entry.dart';
import 'package:hoppin_driver/features/statement/data/models/ledger_summary.dart';
import 'package:hoppin_driver/features/statement/ui/dispute_sheet.dart';
import 'package:hoppin_driver/features/statement/ui/statement_screen.dart';
import 'package:hoppin_driver/features/support/data/support_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockLedgerRepo extends Mock implements LedgerRepository {}

class _MockPayoutRepo extends Mock implements PayoutRepository {}

class _MockSupportRepo extends Mock implements SupportRepository {}

/// Renders the statement and payout screens at the Figma artboard size and
/// writes each to `test/visual/goldens/`, so the build can be held against the
/// design by eye rather than by assertion.
///
/// Run with `flutter test --update-goldens test/visual/statement_golden_test.dart`.
void main() {
  Future<void> capture(
    WidgetTester tester,
    Widget child,
    String name, {
    List<Override> overrides = const [],
    double height = 932,
  }) async {
    tester.view.physicalSize = Size(430, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: child,
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  LedgerEntry entry({
    required String id,
    required int amount,
    required String title,
    String? reason,
    required int balance,
    required DateTime at,
  }) =>
      LedgerEntry(
        id: id,
        createdAt: at,
        amount: Pence(amount),
        entryType: amount > 0 ? 'earning' : 'penalty',
        displayTitle: title,
        displayReason: reason,
        runningBalance: Pence(balance),
      );

  final entries = [
    entry(
      id: 'e1',
      amount: -600,
      title: 'Cancellation penalty',
      reason: 'A penalty for a cancelled trip.',
      balance: -24580,
      at: DateTime.utc(2026, 8, 30, 17, 40),
    ),
    entry(
      id: 'e2',
      amount: -1204,
      title: 'Platform fee',
      reason: "Hoppin's service fee on a completed trip.",
      balance: -23980,
      at: DateTime.utc(2026, 8, 30, 14, 12),
    ),
    entry(
      id: 'e3',
      amount: 4180,
      title: 'Trip earnings',
      reason: 'Your fare for a completed trip.',
      balance: -22776,
      at: DateTime.utc(2026, 8, 29, 19, 5),
    ),
    entry(
      id: 'e4',
      amount: 1500,
      title: 'Bonus',
      reason: 'A bonus credited to your account.',
      balance: -26956,
      at: DateTime.utc(2026, 8, 28, 9, 30),
    ),
  ];

  _MockLedgerRepo ledgerWith(int balancePence, LedgerSummary summary) {
    final repo = _MockLedgerRepo();
    when(() => repo.page(cursor: any(named: 'cursor'))).thenAnswer((_) async =>
        Ok(LedgerPage(balance: Pence(balancePence), entries: entries)));
    when(() => repo.summary(any())).thenAnswer((_) async => Ok(summary));
    return repo;
  }

  // A driver in debt: the design's "What you owe the company".
  testWidgets('statement owing', (t) async {
    final repo = ledgerWith(
      -24580,
      const LedgerSummary(
        period: 'week',
        opening: Pence(-18060),
        credits: Pence(9520),
        debits: Pence(-16040),
        closing: Pence(-24580),
      ),
    );
    await capture(t, const StatementScreen(), 'statement_owing',
        overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
        height: 1400);
  });

  // The same screen the other way up: the design's "What company owes you".
  testWidgets('statement owed', (t) async {
    final repo = ledgerWith(
      24580,
      const LedgerSummary(
        period: 'week',
        opening: Pence(4520),
        credits: Pence(36100),
        debits: Pence(-16040),
        closing: Pence(24580),
      ),
    );
    await capture(t, const StatementScreen(), 'statement_owed',
        overrides: [ledgerRepositoryProvider.overrideWithValue(repo)],
        height: 1400);
  });

  // The dispute modal, opened over the statement.
  testWidgets('dispute sheet', (t) async {
    final ledger = ledgerWith(
      -24580,
      const LedgerSummary(
        opening: Pence(-18060),
        credits: Pence(9520),
        debits: Pence(-16040),
        closing: Pence(-24580),
      ),
    );
    final support = _MockSupportRepo();
    when(() => support.complaintTypes()).thenAnswer((_) async => const Ok([
          ComplaintType('fare_dispute', 'Fare or earnings'),
          ComplaintType('penalty', 'A penalty I was given'),
          ComplaintType('other', 'Something else'),
        ]));

    t.view.physicalSize = const Size(430, 932);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(ProviderScope(
      overrides: [
        ledgerRepositoryProvider.overrideWithValue(ledger),
        supportRepositoryProvider.overrideWithValue(support),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
        home: const StatementScreen(),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Dispute').first);
    await t.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/statement_dispute.png'),
    );
    expect(find.byType(DisputeSheet), findsOneWidget);
  });

  testWidgets('payout not set up', (t) async {
    final repo = _MockPayoutRepo();
    when(() => repo.status())
        .thenAnswer((_) async => const Ok(PayoutStatus()));
    await capture(t, const PayoutScreen(), 'payout_setup_needed',
        overrides: [payoutRepositoryProvider.overrideWithValue(repo)]);
  });

  testWidgets('payout ready', (t) async {
    final repo = _MockPayoutRepo();
    when(() => repo.status()).thenAnswer((_) async => const Ok(
        PayoutStatus(connected: true, payoutsEnabled: true, accountId: 'a')));
    await capture(t, const PayoutScreen(), 'payout_ready',
        overrides: [payoutRepositoryProvider.overrideWithValue(repo)]);
  });
}

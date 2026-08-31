import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/support/data/models/support_ticket.dart';
import 'package:hoppin_driver/features/support/data/support_repository.dart';
import 'package:hoppin_driver/features/support/ui/support_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockSupportRepo extends Mock implements SupportRepository {}

Widget wrap(_MockSupportRepo repo) => ProviderScope(
      overrides: [supportRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SupportScreen()),
    );

void main() {
  late _MockSupportRepo repo;

  setUp(() {
    repo = _MockSupportRepo();
    when(() => repo.complaintTypes()).thenAnswer((_) async => const Ok([
          ComplaintType('fare_dispute', 'Fare or earnings'),
          ComplaintType('other', 'Something else'),
        ]));
    when(() => repo.tickets()).thenAnswer((_) async => const Ok([]));
  });

  testWidgets('shows the FAQ, contact and legal sections from the design',
      (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Frequently Asked Questions (FAQs)'), findsOneWidget);
    expect(find.text('Contact to Support'), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Recent Issues'), findsOneWidget);
  });

  testWidgets('has no Preferred Resolution field', (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // The design offers a "Preferred Resolution: Generate Payout" dropdown.
    // The create endpoint has no such field, so collecting it would discard
    // the driver's choice silently.
    expect(find.text('Preferred Resolution'), findsNothing);
    expect(find.text('Generate Payout'), findsNothing);
  });

  testWidgets('the category list comes from the server, not a hardcoded set',
      (tester) async {
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('category')));
    await tester.pumpAndSettle();

    // `type_code` is validated against a table server-side, so the options
    // must be the ones it actually accepts.
    expect(find.text('Fare or earnings'), findsWidgets);
    verify(() => repo.complaintTypes()).called(1);
  });

  testWidgets('submits the chosen reason as the validated type_code',
      (tester) async {
    when(() => repo.create(
          subject: any(named: 'subject'),
          category: any(named: 'category'),
          typeCode: any(named: 'typeCode'),
          ticketBody: any(named: 'ticketBody'),
        )).thenAnswer((_) async => Ok(SupportTicket(
          id: 't1',
          subject: 'Fare or earnings',
          status: TicketStatus.open,
          createdAt: DateTime.utc(2026, 8, 31),
        )));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fare or earnings').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('description')), 'I was underpaid.');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    verify(() => repo.create(
          subject: 'Fare or earnings',
          category: 'fare_dispute',
          typeCode: 'fare_dispute',
          ticketBody: 'I was underpaid.',
        )).called(1);
  });
}

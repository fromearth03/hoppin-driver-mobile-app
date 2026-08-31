import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/profile/data/deletion_repository.dart';
import 'package:hoppin_driver/features/profile/ui/delete_account_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockDeletionRepo extends Mock implements DeletionRepository {}

// ignore: library_private_types_in_public_api
Widget wrap(_MockDeletionRepo repo) => ProviderScope(
      overrides: [deletionRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DeleteAccountScreen()),
    );

void main() {
  late _MockDeletionRepo repo;

  setUp(() => repo = _MockDeletionRepo());

  testWidgets('offers deletion only — there is no deactivate endpoint',
      (tester) async {
    when(() => repo.requestDeletion())
        .thenAnswer((_) async => const Ok(null));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Permanent Deletion'), findsOneWidget);
    // The design offers "Temporary Deactivation" beside it. No endpoint
    // deactivates an account, so the option must not appear at all — a
    // button that cannot work is worse than an absent one.
    expect(find.text('Temporary Deactivation'), findsNothing);
    expect(find.text('Deactivate'), findsNothing);
  });

  testWidgets('a blocked deletion names every blocker without inventing a sum',
      (tester) async {
    when(() => repo.requestDeletion()).thenAnswer((_) async => Err(
        ApiException('DELETION_BLOCKED', 'cannot delete', 409, fields: {
          'blockers': ['outstanding_balance', 'active_trip'],
        })));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Confirm the irreversible action.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    // A driver stopped by two things should see both at once.
    expect(find.text('You have an outstanding balance'), findsOneWidget);
    expect(find.text('You have a trip in progress'), findsOneWidget);

    // The design prints "Outstanding Balance is £124.00" and a pay button.
    // The blocker payload is codes only — no amount — and nothing settles a
    // balance from the app, so neither may be rendered.
    expect(find.textContaining('£'), findsNothing);
    expect(find.text('Clear Outstanding dues'), findsNothing);
  });
}

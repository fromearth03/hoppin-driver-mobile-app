import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/ui/documents_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockDocsRepo extends Mock implements DocumentsRepository {}

DocumentSlot slot({
  String code = 'vehicle_insurance',
  String label = 'Vehicle Insurance',
  bool uploadable = true,
  DriverDocument? document,
}) =>
    DocumentSlot(
      type: DocumentType(code: code, label: label, uploadable: uploadable),
      document: document,
    );

DriverDocument doc({
  DocumentStatus status = DocumentStatus.approved,
  String? rejectionReason,
  DateTime? expiresAt,
}) =>
    DriverDocument(
      id: 'd1',
      documentType: 'vehicle_insurance',
      status: status,
      rejectionReason: rejectionReason,
      expiresAt: expiresAt,
      uploadedAt: DateTime.now(),
    );

Widget wrap(MockDocsRepo repo) => ProviderScope(
      overrides: [documentsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DocumentsScreen()),
    );

void main() {
  late MockDocsRepo repo;
  setUp(() => repo = MockDocsRepo());

  testWidgets('shows a rejected document reason verbatim', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document: doc(
                  status: DocumentStatus.rejected,
                  rejectionReason:
                      'The photo was too blurry to read the expiry date.'))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('The photo was too blurry to read the expiry date.'),
        findsOneWidget);
  });

  testWidgets('never substitutes a generic message for a real reason',
      (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document: doc(
                  status: DocumentStatus.rejected,
                  rejectionReason: 'Wrong page uploaded.'))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Wrong page uploaded.'), findsOneWidget);
    expect(find.textContaining('Please try again'), findsNothing);
  });

  testWidgets('a missing document invites an upload', (tester) async {
    when(() => repo.slots())
        .thenAnswer((_) async => Ok([slot(document: null)]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Not uploaded'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
  });

  testWidgets('an operator-run document offers no upload', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              code: 'nr3s_background_check',
              label: 'Background Check',
              uploadable: false)
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Background Check'), findsOneWidget);
    // The driver cannot supply this one; an Upload button would be a lie.
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('a document under review offers no action', (tester) async {
    when(() => repo.slots()).thenAnswer(
        (_) async => Ok([slot(document: doc(status: DocumentStatus.pending))]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('warns about a document expiring soon', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document:
                  doc(expiresAt: DateTime.now().add(const Duration(days: 14))))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Expires'), findsOneWidget);
  });
}

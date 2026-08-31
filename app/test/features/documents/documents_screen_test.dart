import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/documents/data/documents_repository.dart';
import 'package:hoppin_driver/features/documents/data/models/driver_document.dart';
import 'package:hoppin_driver/features/documents/ui/documents_screen.dart';
import 'package:hoppin_driver/features/documents/ui/widgets/document_card.dart';
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

    // The tile states the status where an expiry date would otherwise go,
    // and tapping it is what starts an upload.
    expect(find.text('Not uploaded'), findsOneWidget);
    expect(find.byType(DocumentCard), findsOneWidget);
    expect(tester.widget<DocumentCard>(find.byType(DocumentCard)).canUpload,
        isTrue);
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
    // The driver cannot supply this one; an upload affordance would be a lie.
    expect(tester.widget<DocumentCard>(find.byType(DocumentCard)).canUpload,
        isFalse);
  });

  testWidgets('a document under review offers no action', (tester) async {
    when(() => repo.slots()).thenAnswer(
        (_) async => Ok([slot(document: doc(status: DocumentStatus.pending))]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Under review'), findsOneWidget);
    // Nothing to act on while we are checking it.
    expect(tester.widget<DocumentCard>(find.byType(DocumentCard)).canUpload,
        isFalse);
  });

  testWidgets('warns about a document expiring soon', (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document:
                  doc(expiresAt: DateTime.now().add(const Duration(days: 14))))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Expire:'), findsOneWidget);
  });

  testWidgets('a rejection reason is shown in full, not truncated in a tile',
      (tester) async {
    const long =
        'The expiry date on the second page was covered by your thumb. '
        'Re-take the photo with the whole page visible and both dates legible.';
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          slot(
              document: doc(
                  status: DocumentStatus.rejected, rejectionReason: long))
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // A grid tile cannot hold a sentence; truncating it is what leaves a
    // driver re-uploading the same bad file.
    final text = tester.widget<Text>(find.text(long));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(text.maxLines, isNull);
  });

  testWidgets('offers a document appeal, the only appeal path that exists',
      (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([slot()]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // There is no document-appeal endpoint; compliance-appeals takes a
    // document_type, which is what this tile files.
    expect(find.byType(DocumentAppealCard), findsOneWidget);
  });

  testWidgets('a type with no expiry shows its status, not a made-up date',
      (tester) async {
    when(() => repo.slots()).thenAnswer((_) async => Ok([
          DocumentSlot(
            type: const DocumentType(code: 'right_to_work', label: 'Right to Work'),
            document: DriverDocument(
              id: 'd1',
              documentType: 'right_to_work',
              status: DocumentStatus.approved,
              uploadedAt: DateTime.now(),
            ),
          )
        ]));

    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    // The Figma prints "Expire: January 15, 2026" on every tile.
    expect(find.textContaining('Expire:'), findsNothing);
    expect(find.text('Approved'), findsOneWidget);
  });
}

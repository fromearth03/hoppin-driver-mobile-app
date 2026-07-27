import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/document_type_labels.dart';
import 'package:hoppin_driver/features/documents/documents_builder.dart';
import 'package:hoppin_driver/features/documents/documents_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// The documents interactor: `GET /drivers/me/documents` → [DocumentsState].
///
/// The three branches that matter, and why each is a separate test:
///   - a list          → ready
///   - 503 STORAGE_DISABLED → a DESIGNED unavailable phase (matched on CODE)
///   - anything else   → error, NOT an empty wallet
void main() {
  DriverDocument doc(
    String type,
    String status, {
    required DateTime uploadedAt,
    String? id,
  }) =>
      DriverDocument(
        id: id ?? 'doc-$type-${uploadedAt.millisecondsSinceEpoch}',
        documentType: type,
        verificationStatus: status,
        uploadedAt: uploadedAt,
      );

  ProviderContainer containerOver(_StubDriverRepository repo) {
    final container = ProviderContainer(
      overrides: [driverRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a served list lands in ready, exactly as the server sent it', () async {
    final container = containerOver(
      _StubDriverRepository(served: [
        doc('dvla_license', 'pending_review', uploadedAt: DateTime.utc(2026, 7)),
      ]),
    );
    container.read(documentsInteractorProvider);
    await container.read(documentsInteractorProvider.notifier).refresh();

    final state = container.read(documentsInteractorProvider);
    expect(state.phase, DocumentsPhase.ready);
    expect(state.documents, hasLength(1));
    expect(state.documents.single.verificationStatus, 'pending_review',
        reason: 'the server\'s own token, untouched');
  });

  test('🔴 503 STORAGE_DISABLED → storageDisabled, matched on the CODE',
      () async {
    final container = containerOver(
      _StubDriverRepository(
        throws: const ApiException(
          statusCode: 503,
          code: 'STORAGE_DISABLED',
          message: 'document storage is not configured',
        ),
      ),
    );
    container.read(documentsInteractorProvider);
    await container.read(documentsInteractorProvider.notifier).refresh();

    expect(
      container.read(documentsInteractorProvider).phase,
      DocumentsPhase.storageDisabled,
      reason: 'OD-11: this is a designed state, not a failure',
    );
  });

  test('🔴 a BARE 503 with a different code is an error, not storageDisabled',
      () async {
    // The guard on the guard. A status number is not a contract — if the
    // interactor branched on `statusCode == 503` this test goes red, and it is
    // exactly the mistake 409 (CHAT_CLOSED *and* ACTIVE_TRIP_EXISTS) already
    // cost this project once.
    final container = containerOver(
      _StubDriverRepository(
        throws: const ApiException(
          statusCode: 503,
          code: 'UPSTREAM_UNAVAILABLE',
          message: 'try again shortly',
        ),
      ),
    );
    container.read(documentsInteractorProvider);
    await container.read(documentsInteractorProvider.notifier).refresh();

    final state = container.read(documentsInteractorProvider);
    expect(state.phase, DocumentsPhase.error);
    expect(state.error, isNotNull);
  });

  test('🔴 a transport failure is an ERROR, never an empty wallet', () async {
    final container = containerOver(
      _StubDriverRepository(throws: Exception('socket closed')),
    );
    container.read(documentsInteractorProvider);
    await container.read(documentsInteractorProvider.notifier).refresh();

    final state = container.read(documentsInteractorProvider);
    expect(state.phase, DocumentsPhase.error,
        reason: 'a dead network is IGNORANCE about the wallet, not a verdict '
            'that the wallet is empty');
    expect(state.documents, isEmpty);
  });

  group('documentFor', () {
    test('returns the NEWEST of that type, never merely the first in the list',
        () {
      // The server serves newest-first (DOCS/04 L178) — but a correctness
      // decision may not rest on list ORDER, which the server is free to
      // change without telling us. So this list is DELIBERATELY oldest-first.
      final state = DocumentsState(
        phase: DocumentsPhase.ready,
        documents: [
          doc('insurance_policy', 'rejected',
              uploadedAt: DateTime.utc(2026, 1), id: 'old'),
          doc('insurance_policy', 'pending_review',
              uploadedAt: DateTime.utc(2026, 7), id: 'new'),
        ],
      );

      expect(state.documentFor('insurance_policy')?.id, 'new');
    });

    test('🔴 an un-uploaded type is NULL — not pending, not valid', () {
      const state = DocumentsState(phase: DocumentsPhase.ready);
      for (final type in DriverRepository.documentTypes) {
        expect(state.documentFor(type), isNull,
            reason: 'the driver has uploaded nothing; $type is NOT UPLOADED');
      }
    });
  });

  test('the label map is SET-EQUAL to the contract — no ninth type, ever', () {
    // The cheapest possible guard against a future contributor "helpfully"
    // adding the Figma's `Medical Certificate` row back in. It would
    // 400 VALIDATION_FAILED, and the driver who filled it would believe they
    // were compliant.
    expect(kDocumentTypeLabels.keys.toSet(),
        DriverRepository.documentTypes.toSet());
    expect(kDocumentTypeLabels, hasLength(8));
  });
}

/// The network, under test control. `implements` so anything the interactor
/// reaches for beyond `documents()` throws loudly.
class _StubDriverRepository implements DriverRepository {
  _StubDriverRepository({this.served = const [], this.throws});

  final List<DriverDocument> served;
  final Object? throws;

  @override
  Future<List<DriverDocument>> documents() async {
    if (throws != null) throw throws!;
    return served;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'the documents interactor reached for ${invocation.memberName}. This '
        'stub answers `documents()` and nothing else.',
      );
}

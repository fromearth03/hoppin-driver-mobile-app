import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/documents/document_type_labels.dart';
import 'package:hoppin_driver/features/documents/documents_builder.dart';
import 'package:hoppin_driver/features/documents/widgets/document_row.dart';
import 'package:hoppin_driver/features/documents/widgets/document_status_chip.dart';
import 'package:hoppin_driver/features/documents/widgets/document_storage_unavailable.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/code_lines.dart';

/// 🔴 THE HONESTY ASSERTIONS FOR THE DOCUMENTS SURFACE (13-01, OD-04/07/08/11).
///
/// These were written and watched FAIL before a single line of
/// `features/documents/lib` existed. *A fix asserted without a preceding red is
/// not proven* — Wave 0 found thirteen shipped lies hiding behind a green suite,
/// and every one of them was "covered" by a test that could not fail.
///
/// What is being defended:
///
/// The Figma renders a green **"Valid"** badge over a document. That word is
/// not in the backend's vocabulary. `DOCS/04` (L174) publishes exactly ONE
/// `verification_status` — `pending_review` — and says admin review moves a
/// document on from there **without ever saying where to**. The rest of the
/// enum is UNPUBLISHED (seam #83).
///
/// Rendering "Valid" over a `pending_review` DVLA licence tells a driver **they
/// may legally work** when we do not know that. A driver who reads it and takes
/// a fare is uninsured and unlicensed on our word. That is not a cosmetic
/// defect: it is a lie about a person's right to work, it carries operator
/// licensing exposure, and it is the same species as the fabricated
/// accessibility UUID this project has already paid for once.
///
/// The Figma is ALSO wrong about the type list: it invents a `Medical
/// Certificate` (the backend would `400 VALIDATION_FAILED` — "invalid document
/// type") and OMITS three documents a Wolverhampton private-hire driver is
/// legally required to hold (`mot_certificate`, `v5c_logbook`,
/// `caz_compliance_proof`). **D4: TRUTH WINS OVER FIGMA COPY.**
void main() {
  DriverDocument doc(String type, String status, {DateTime? uploadedAt}) =>
      DriverDocument(
        id: 'doc-$type',
        documentType: type,
        verificationStatus: status,
        uploadedAt: uploadedAt ?? DateTime.utc(2026, 7, 1),
      );

  /// Pumps the REAL documents riblet over a repository under test control.
  ///
  /// The real riblet, the real route widget, the real interactor — the only
  /// thing faked is the network. A test that builds its own view proves its own
  /// view works.
  Future<void> pumpDocuments(
    WidgetTester tester, {
    List<DriverDocument> documents = const [],
    Object? throws,
  }) async {
    // A TALL viewport, on purpose. The wallet is a ListView and the default
    // 800px test surface leaves the last rows unbuilt — so `findsNWidgets(8)`
    // would fail on a CORRECT view, and (much worse) a global text sweep would
    // PASS over an off-screen "Valid" chip it never built. Lay out all eight.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          driverRepositoryProvider.overrideWithValue(
            _StubDriverRepository(served: documents, throws: throws),
          ),
        ],
        child: MaterialApp(
          // SF-02: dark is the driver's PRIMARY theme.
          theme: HoppinTheme.driverDark(),
          home: const DocumentsRiblet(),
        ),
      ),
    );
    // Bounded pumps only — never pumpAndSettle. The driver app runs live
    // polling providers and settle-detection never terminates.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The text a CHIP renders — the app's claim about a document's standing.
  ///
  /// The assertions below are scoped to the chip on purpose. A blanket
  /// `find.textContaining('valid')` over the whole surface would also forbid
  /// the #83 rung from saying *"we will never tell you a document is valid
  /// unless the platform says so"* — which is the one place the word belongs,
  /// because there it is a DISCLAIMER, not a claim. What must never happen is
  /// the app putting that word **on a document**.
  Iterable<String> chipTexts(WidgetTester tester) => tester
      .widgetList<DocumentStatusChip>(find.byType(DocumentStatusChip))
      .map((c) => DocumentStatusChip.prettify(c.status));

  group('🔴 the app never claims a document is valid', () {
    testWidgets("no chip says 'Valid' over a pending_review document",
        (tester) async {
      await pumpDocuments(
        tester,
        documents: [doc('dvla_license', 'pending_review')],
      );

      final chips = chipTexts(tester).toList();
      expect(chips, hasLength(1));
      expect(
        chips.single.toLowerCase(),
        isNot(contains('valid')),
        reason:
            'A `pending_review` DVLA licence rendered as "Valid" tells a driver '
            'they may LEGALLY WORK when the platform has said no such thing. '
            'The backend publishes exactly one status word and "Valid" is not '
            'it (#83). Render the SERVER\'S token, verbatim.',
      );
      expect(chips.single, 'Pending review',
          reason: 'the server said `pending_review`; the driver reads that');

      // And the raw token is what the widget was actually handed — no mapping
      // happened upstream of the chip either.
      final chip = tester.widget<DocumentStatusChip>(
        find.byType(DocumentStatusChip),
      );
      expect(chip.status, 'pending_review');
    });

    testWidgets("an 'approved' document renders 'Approved', not 'Valid'",
        (tester) async {
      await pumpDocuments(
        tester,
        documents: [doc('dvla_license', 'approved')],
      );

      // Prettifying is a PURE function of the server's token, so
      // `approved` → `Approved` is fine. Mapping it to a word the server never
      // said is not.
      expect(chipTexts(tester).single, 'Approved',
          reason: 'the chip must render the server\'s own token (prettified at '
              'most), so the driver reads what the platform actually said');
      expect(
        find.descendant(
          of: find.byType(DocumentStatusChip),
          matching: find.textContaining('Valid'),
        ),
        findsNothing,
      );
    });
  });

  group("the server's word, verbatim", () {
    // Three plausible tokens the backend might one day send. Only
    // `pending_review` is published; the app has never been told the others.
    // An UNRECOGNISED status is IGNORANCE, not invalidity — it must still
    // render, never as a blank, never as "Unknown", never as a crash.
    for (final status in const ['pending_review', 'rejected', 'expired']) {
      testWidgets("'$status' surfaces as itself", (tester) async {
        await pumpDocuments(
          tester,
          documents: [doc('insurance_policy', status)],
        );

        final pretty = status.replaceAll('_', ' ');
        expect(
          chipTexts(tester).single.toLowerCase(),
          pretty.toLowerCase(),
          reason:
              'the exact server token "$status" must reach the driver. The enum '
              'is unpublished (#83): a value we have never heard of means we are '
              'IGNORANT, not that the value is invalid — so it renders AS '
              'ITSELF. Never a blank, never "Unknown", never a crash.',
        );
        // And it is actually RENDERED, not merely held in the model. Matched
        // case-insensitively because the ONLY transform the chip is allowed is
        // sentence-casing (`rejected` → `Rejected`) — a pure, reversible
        // function of the server's token. Anything that is not a re-casing of
        // "$status" fails the assertion above.
        expect(
          find.descendant(
            of: find.byType(DocumentStatusChip),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  (w.data ?? '').toLowerCase() == pretty.toLowerCase(),
            ),
          ),
          findsOneWidget,
        );
      });
    }
  });

  test("🔴 'Medical Certificate' is in NO CODE PATH in apps/driver/lib", () {
    // A SOURCE assertion, not a widget assertion — the type must be
    // unreachable, not merely unrendered. There is no `medical_certificate`
    // `document_type`; sending one `400 VALIDATION_FAILED`s ("invalid document
    // type"), and a driver who filled that form would believe they were
    // compliant and would not be. The Figma invented it. D4: truth wins over
    // Figma copy.
    //
    // COMMENTS ARE EXCLUDED, DELIBERATELY. What must not exist is the word in
    // CODE. What SHOULD exist — and what `document_type_labels.dart` carries —
    // is a comment saying why the row a contributor is looking for is not
    // there. Grep-proofing the warning out of the codebase would guarantee the
    // next person re-adds the row.
    // The comment stripper lives in test/support/code_lines.dart — ONE copy,
    // and a SANITY-TESTED one. This test used to carry its own inline version,
    // which (like the one in no_self_signup_test.dart) silently dropped code
    // that followed a same-line `/* … */`. A sweep with a hole in it is
    // indistinguishable from a clean codebase, which is the whole reason the
    // shared helper is watched to work rather than merely assumed to.
    final offenders = <String>[];
    for (final source in driverSources()) {
      for (var i = 0; i < source.lines.length; i++) {
        if (source.lines[i].toLowerCase().contains('medical')) {
          offenders.add('${source.path}:${i + 1} → ${source.lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The Figma invents a `Medical Certificate`. The backend has no '
          'such `document_type` and would reject it with 400 '
          'VALIDATION_FAILED. A driver who uploads one believes they are '
          'compliant and is not.\n\n${offenders.join('\n')}',
    );
  });

  testWidgets('exactly EIGHT rows, and they ARE the contract', (tester) async {
    await pumpDocuments(tester);

    final rows = tester.widgetList<DocumentRow>(find.byType(DocumentRow));

    expect(
      rows.map((r) => r.documentType).toSet(),
      DriverRepository.documentTypes.toSet(),
      reason:
          'the rows must be SET-EQUAL to `DriverRepository.documentTypes` — a '
          'hardcoded list in the view is exactly how a ninth type (or a missing '
          'MOT certificate) gets in front of a driver',
    );
    expect(rows.length, DriverRepository.documentTypes.length,
        reason: 'eight types. Not six (the Figma). Not nine.');
    expect(rows.length, 8);
  });

  test('every backend type has a label, and no label invents a type', () {
    expect(
      kDocumentTypeLabels.keys.toSet(),
      DriverRepository.documentTypes.toSet(),
      reason: 'the label map is a projection of the contract, not a menu. A '
          'ninth key here is a document type the backend rejects; a missing key '
          'is a legally-required document the driver never sees.',
    );
  });

  testWidgets('🔴 a 503 STORAGE_DISABLED is a DESIGNED state, not a crash',
      (tester) async {
    await pumpDocuments(
      tester,
      throws: const ApiException(
        statusCode: 503,
        code: 'STORAGE_DISABLED',
        message: 'document storage is not configured',
      ),
    );

    expect(find.byType(DocumentStorageUnavailable), findsOneWidget,
        reason: 'OD-11: the 503 must land on a designed unavailable-state');
    expect(tester.takeException(), isNull,
        reason: 'a red error screen is not a design');
    expect(
      find.textContaining('document storage is not configured'),
      findsNothing,
      reason: 'a raw server message is not designed copy',
    );
  });

  testWidgets('🔴 an un-uploaded type reads NOT UPLOADED — never pending',
      (tester) async {
    // Absence of a document is NOT `pending_review`. It is not "under review",
    // it is not "submitted", and it is certainly not valid. It is nothing at
    // all, and the driver must be able to tell.
    await pumpDocuments(tester);

    expect(find.byType(DocumentRow), findsNWidgets(8));
    expect(find.text('Not uploaded'), findsNWidgets(8),
        reason: 'every one of the eight rows is empty, and each must say so');

    // 🔴 NOT ONE STATUS WORD ANYWHERE ON THE WALLET. The chip is the app's
    // claim-making surface; over a driver who has uploaded nothing there is
    // nothing to claim, so not a single chip may exist — never mind what it
    // would have said.
    expect(
      find.byType(DocumentStatusChip),
      findsNothing,
      reason: 'the driver has uploaded NOTHING. A status chip over an empty '
          'wallet invents a submission that never happened — and "pending" is '
          'exactly the word a well-meaning contributor reaches for.',
    );

    // And every row's own copy is free of status vocabulary.
    final rowText = tester
        .widgetList<Text>(
          find.descendant(of: find.byType(DocumentRow), matching: find.byType(Text)),
        )
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' ');
    for (final word in const ['pending', 'review', 'valid', 'submitted']) {
      expect(rowText, isNot(contains(word)),
          reason: 'no row may say "$word" over a document that does not exist');
    }
  });
}

/// The network, under test control. `implements` (not `extends`) so every OTHER
/// method the surface reaches for lands in [noSuchMethod] and THROWS — rather
/// than silently returning a plausible nothing that a future test would read as
/// a pass.
class _StubDriverRepository implements DriverRepository {
  _StubDriverRepository({this.served = const [], this.throws});

  /// What `GET /drivers/me/documents` serves.
  final List<DriverDocument> served;

  /// What `GET /drivers/me/documents` throws instead, if anything.
  final Object? throws;

  @override
  Future<List<DriverDocument>> documents() async {
    if (throws != null) throw throws!;
    return served;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'the documents surface reached for ${invocation.memberName}. This stub '
        'answers `documents()` and nothing else — if that call is deliberate, '
        'answer it here explicitly rather than letting it return a plausible '
        'nothing.',
      );
}

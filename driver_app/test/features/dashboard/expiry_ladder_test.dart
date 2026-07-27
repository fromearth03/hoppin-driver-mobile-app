import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_view.dart';
import 'package:hoppin_driver/features/dashboard/eligibility_builder.dart';
import 'package:hoppin_driver/features/dashboard/eligibility_state.dart';
import 'package:hoppin_driver/features/dashboard/widgets/document_expiry_ladder.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE LADDER. A driver NEVER learns their MOT expired by tapping GO at 5am
/// in a car park and eating a 403.
///
/// `GET /drivers/me/documents` returns a real `expires_at` per document. It is
/// one of the very few driver features that is **fully BOUND today** — the data
/// has always been there and nothing read it. So a driver whose MOT lapsed last
/// Tuesday got up at 5am, drove to a rank, tapped GO, and got a red banner —
/// having burnt a morning on a problem the app could have named **thirty days
/// earlier**, on the home screen, in their own words.
///
/// The four rungs are DELIBERATELY asymmetric: three of them are NOTICES and
/// only one BLOCKS. A driver on their last valid day can still legally work,
/// and taking that away from them costs a real shift's earnings for nothing.
void main() {
  /// A fixed clock. 🔴 NEVER `DateTime.now()` — a T-1d assertion that passes at
  /// 23:59:58 and fails in CI at 00:00:01 is worse than no test at all: it
  /// teaches the team to re-run the suite instead of reading it.
  final now = DateTime.utc(2026, 7, 14, 9);

  DriverDocument doc(String type, {DateTime? expiresAt}) => DriverDocument(
        id: 'doc-$type',
        documentType: type,
        verificationStatus: 'approved',
        uploadedAt: now.subtract(const Duration(days: 90)),
        expiresAt: expiresAt,
      );

  Future<void> pumpLadder(
    WidgetTester tester, {
    required _StubDriverRepo repo,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const DashboardView(),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  bool goIsDisabled(WidgetTester tester) {
    final buttons = tester.widgetList<GoButton>(find.byType(GoButton));
    if (buttons.isEmpty) return true;
    return buttons.first.onPressed == null;
  }

  String surfaceText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? '')
      .join(' | ');

  group('Test 6: the four rungs, off the REAL expires_at', () {
    testWidgets('T-45d: silence. We do not nag a driver about a fine document',
        (tester) async {
      final repo = _StubDriverRepo(documentsResult: [
        doc('mot_certificate',
            expiresAt: now.add(const Duration(days: 45))),
      ]);
      await pumpLadder(tester, repo: repo);

      expect(find.byType(DocumentExpiryLadder), findsNothing);
      expect(goIsDisabled(tester), isFalse);
    });

    testWidgets('T-30d and T-8d: an INFORMATIONAL rung, naming the document; '
        'GO stays enabled', (tester) async {
      for (final days in [30, 8]) {
        final repo = _StubDriverRepo(documentsResult: [
          doc('mot_certificate',
              expiresAt: now.add(Duration(days: days))),
        ]);
        await pumpLadder(tester, repo: repo);

        expect(find.byType(DocumentExpiryLadder), findsOneWidget,
            reason: 'T-${days}d must warn');
        expect(surfaceText(tester), contains('MOT certificate'),
            reason: '🔴 the rung NAMES the document — in the driver\'s words, '
                'never the raw `mot_certificate` key');
        expect(goIsDisabled(tester), isFalse,
            reason: 'a notice is a notice: it blocks nothing');
      }
    });

    testWidgets('T-7d and T-2d: a PROMINENT rung; GO stays enabled',
        (tester) async {
      for (final days in [7, 2]) {
        final repo = _StubDriverRepo(documentsResult: [
          doc('insurance_policy',
              expiresAt: now.add(Duration(days: days))),
        ]);
        await pumpLadder(tester, repo: repo);

        final ladder =
            tester.widget<DocumentExpiryLadder>(find.byType(DocumentExpiryLadder));
        expect(ladder.expiries.single.rung, ExpiryRung.prominent,
            reason: 'T-${days}d is the louder rung');
        expect(surfaceText(tester), contains('Insurance policy'));
        expect(goIsDisabled(tester), isFalse,
            reason: 'still legal to work — GO is not taken away');
      }
    });

    testWidgets('T-1d and T-0: the LAST-DAY rung — unmissable, and GO stays '
        'enabled (they can still legally work today)', (tester) async {
      for (final hours in [24, 6]) {
        final repo = _StubDriverRepo(documentsResult: [
          doc('mot_certificate',
              expiresAt: now.add(Duration(hours: hours))),
        ]);
        await pumpLadder(tester, repo: repo);

        final ladder =
            tester.widget<DocumentExpiryLadder>(find.byType(DocumentExpiryLadder));
        expect(ladder.expiries.single.rung, ExpiryRung.lastDay);
        expect(surfaceText(tester), contains('MOT certificate'));
        expect(goIsDisabled(tester), isFalse,
            reason: '🔴 taking a legal working day away from a driver costs '
                'them a real shift for no reason at all');
      }
    });

    testWidgets('EXPIRED: 🔴 GO IS DISABLED and the rung NAMES THE EXACT '
        'DOCUMENT', (tester) async {
      final repo = _StubDriverRepo(documentsResult: [
        doc('mot_certificate',
            expiresAt: now.subtract(const Duration(days: 1))),
      ]);
      await pumpLadder(tester, repo: repo);

      expect(goIsDisabled(tester), isTrue,
          reason: 'an expired document blocks the dispatch pool');

      // 🔴 "You can't go online" WITHOUT NAMING THE DOCUMENT is the failure mode
      // this rung exists to delete. A driver who reads it and does not know
      // WHICH of eight documents to fix has been told nothing useful — so they
      // will tap GO again to find out, and eventually drive to a rank to find
      // out the hard way.
      expect(surfaceText(tester), contains('MOT certificate'),
          reason: 'the human label, never the `mot_certificate` key');
    });
  });

  testWidgets('Test 7: 🔴 a NULL expires_at contributes NOTHING', (tester) async {
    // A null `expires_at` means *this document does not expire, or the server
    // did not tell us when*. It is NOT "expires today" and it is NOT "expired".
    // An off-by-one that treated it as a date would disable a working driver's
    // GO button FOREVER, for a background check that was never going to expire.
    final repo = _StubDriverRepo(documentsResult: [
      doc('nr3s_background_check'),
      doc('right_to_work'),
    ]);
    await pumpLadder(tester, repo: repo);

    expect(find.byType(DocumentExpiryLadder), findsNothing,
        reason: 'null produces NO rung — not `none`, not "expires today"');
    expect(goIsDisabled(tester), isFalse,
        reason: '🔴 a document with no expiry can never block a driver');
  });

  testWidgets('Test 8: the WORST document wins, and ALL of them are named',
      (tester) async {
    final repo = _StubDriverRepo(documentsResult: [
      doc('insurance_policy', expiresAt: now.add(const Duration(days: 20))),
      doc('mot_certificate',
          expiresAt: now.subtract(const Duration(days: 3))),
    ]);
    await pumpLadder(tester, repo: repo);

    expect(goIsDisabled(tester), isTrue,
        reason: 'the expired document dominates');

    // 🔴 TELL THEM EVERYTHING YOU KNOW, ONCE. A driver fixing their MOT must
    // not tap GO, get blocked again, and only THEN discover the insurance was
    // also about to lapse.
    final surface = surfaceText(tester);
    expect(surface, contains('MOT certificate'));
    expect(surface, contains('Insurance policy'));
  });

  testWidgets('Test 9: the ladder is BOUND — a FAILED READ is IGNORANCE, and '
      '🔴 GO STAYS ENABLED', (tester) async {
    // We could not read their documents. That is OUR problem, not theirs — and
    // the SERVER is the authority on eligibility anyway: it re-checks at
    // `POST /drivers/me/online` and will 403 if it must. A `catch` that
    // disabled GO here would strand a perfectly legal driver on a transient
    // 500 with no idea why. (A seam may only feed DECORATION — never presence,
    // never lifecycle.)
    final repo = _StubDriverRepo(
      documentsError: const ApiException(
        statusCode: 500,
        message: 'Internal server error',
      ),
    );
    await pumpLadder(tester, repo: repo);

    expect(find.byType(DocumentExpiryLadder), findsNothing);
    expect(goIsDisabled(tester), isFalse,
        reason: '🔴 a failed read must NEVER disable a driver\'s ability to '
            'earn');
  });
}

/// Drives the two BOUND driver reads this lane cares about, and nothing else.
class _StubDriverRepo implements DriverRepository {
  _StubDriverRepo({
    this.documentsResult = const [],
    this.documentsError,
  });

  List<DriverDocument> documentsResult;
  Object? documentsError;

  @override
  Future<List<DriverDocument>> documents() async {
    final err = documentsError;
    if (err != null) throw err as Exception;
    return documentsResult;
  }

  @override
  Future<void> goOnline() async {}

  @override
  Future<void> goOffline() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

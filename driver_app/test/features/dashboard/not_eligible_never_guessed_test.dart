import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/dashboard/dashboard_view.dart';
import 'package:hoppin_driver/features/dashboard/widgets/not_eligible_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE TEST THIS PLAN EXISTS FOR: `403 NOT_ELIGIBLE` IS NEVER GUESSED.
///
/// 🔴 READ THIS BEFORE YOU ADD A "HELPFUL" WORD TO THAT STRING.
///
/// `POST /drivers/me/online` is compliance-gated and it answers **one**
/// `403 NOT_ELIGIBLE` for **three completely different situations**:
///
///   * **compliance** — a document is missing, expired, or unapproved,
///   * **restriction** — an operational restriction on this driver,
///   * **suspension** — the account is suspended pending review.
///
/// Three different problems. Three completely different driver actions. One
/// indistinguishable code, and the server does **not** tell us which (the ask
/// for a machine-readable sub-reason is relayed under #30 in DOCS/06).
///
/// The tempting change — the one that LOOKS helpful and IS a defect — is to
/// map the code to a sentence:
///
///     "You can't go online. Please check your documents."
///
/// If that driver was actually **suspended**, that sentence sends them off to
/// re-upload a licence that was never the problem. They will do it. Then they
/// will do it again. Then they will ring support furious about the wrong thing,
/// and support will have to unpick a story **the app invented** — while the
/// real problem sits untouched and the driver loses a day's earnings to it.
///
/// So: **ANY STRING MAPPED FROM `NOT_ELIGIBLE` IS A DEFECT.** The app renders
/// the server's literal words when it sends them, and otherwise says — plainly
/// — that it does not know, and hands the driver a real route to a human.
/// **Admitting ignorance is a feature.**
///
/// The word-list assertion below is the guard. It is deliberately blunt: if you
/// are here because it went red, you did not break a test — you were about to
/// ship a guess to a driver.
void main() {
  /// The exact words that would each be a GUESS about what NOT_ELIGIBLE meant.
  const forbidden = <String>[
    'documents',
    'document',
    'expired',
    'upload',
    'licence',
    'license',
    'mot',
    'insurance',
    'suspended',
    'restricted',
    'verification',
  ];

  /// Every string rendered anywhere in the tree, lower-cased.
  List<String> renderedText(WidgetTester tester) {
    final out = <String>[];
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      final data = w.data;
      if (data != null) out.add(data.toLowerCase());
    }
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      out.add(w.text.toPlainText().toLowerCase());
    }
    return out;
  }

  late _StubSupportRepo support;

  Future<_StubDriverRepo> pumpDashboard(
    WidgetTester tester, {
    required _StubDriverRepo repo,
  }) async {
    support = _StubSupportRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        driverRepositoryProvider.overrideWithValue(repo),
        supportRepositoryProvider.overrideWithValue(support),
      ],
      child: MaterialApp(
        theme: HoppinTheme.driverDark(),
        home: const DashboardView(),
      ),
    ));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return repo;
  }

  Future<void> tapGo(WidgetTester tester) async {
    await tester.tap(find.byType(GoButton));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('403 NOT_ELIGIBLE — never guessed', () {
    testWidgets('Test 1: a BARE 403 NOT_ELIGIBLE renders NO GUESS',
        (tester) async {
      // The worst case, and the one the server actually sends today: the code,
      // and an EMPTY message. The app knows precisely nothing about why.
      final repo = _StubDriverRepo(
        goOnlineError: const ApiException(
          statusCode: 403,
          message: '',
          code: 'NOT_ELIGIBLE',
        ),
      );
      await pumpDashboard(tester, repo: repo);
      await tapGo(tester);

      expect(find.byType(NotEligibleState), findsOneWidget,
          reason: 'the 403 lands on the honest eligibility rung');

      final rendered = renderedText(tester);
      for (final word in forbidden) {
        for (final line in rendered) {
          expect(line.contains(word), isFalse,
              reason: '🔴 "$word" is a GUESS. The server said NOT_ELIGIBLE and '
                  'nothing else — it means compliance OR restriction OR '
                  'suspension and the app does not know which. Rendered: '
                  '"$line"');
        }
      }
    });

    testWidgets('Test 2: the honest copy renders, and it has an EXIT',
        (tester) async {
      final repo = _StubDriverRepo(
        goOnlineError: const ApiException(
          statusCode: 403,
          message: '',
          code: 'NOT_ELIGIBLE',
        ),
      );
      await pumpDashboard(tester, repo: repo);
      await tapGo(tester);

      final rendered = renderedText(tester);
      expect(rendered.any((l) => l.contains("can't go online")), isTrue,
          reason: 'the driver is told, plainly, that they cannot go online');

      // A block with no way forward is half a message.
      final exit = find.byKey(const Key('not-eligible-support'));
      expect(exit, findsOneWidget,
          reason: 'every NOT_ELIGIBLE state carries a REAL route to a human');

      await tester.tap(exit);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      // 🔴 A REAL EXIT, NOT A DECORATIVE ONE. The BOUND
      // `POST /me/support-tickets` fired: a human will read this.
      expect(support.subjects.length, 1,
          reason: 'the exit opens a real ticket a real person reads');
      expect(support.subjects.single, contains('NOT_ELIGIBLE'),
          reason: '🔴 the ticket names the CODE, which is all we actually '
              'know — support can look the driver up and see which of the '
              'three things it was, which is exactly what the app cannot do');
    });

    testWidgets("Test 3: the SERVER'S OWN words win, verbatim", (tester) async {
      const serverWords = 'Your taxi badge has been suspended pending review.';
      final repo = _StubDriverRepo(
        goOnlineError: const ApiException(
          statusCode: 403,
          message: serverWords,
          code: 'NOT_ELIGIBLE',
        ),
      );
      await pumpDashboard(tester, repo: repo);
      await tapGo(tester);

      // Unmodified, un-prettified, un-shortened. The app has no opinion here:
      // if the server tells the driver something, the driver reads it.
      expect(find.text(serverWords), findsOneWidget);
    });

    testWidgets('Test 4: a 403 that is NOT NOT_ELIGIBLE is not an eligibility '
        'screen', (tester) async {
      // 🔴 BRANCH ON THE CODE, NEVER ON THE BARE STATUS. A bare-403 branch
      // would show an eligibility screen over an EXPIRED SESSION — and send the
      // driver off to re-upload documents to fix a token refresh. (409 in this
      // codebase is both CHAT_CLOSED and ACTIVE_TRIP_EXISTS. The status number
      // is not a contract. The code is.)
      const message = 'You do not have access to this resource.';
      final repo = _StubDriverRepo(
        goOnlineError: const ApiException(
          statusCode: 403,
          message: message,
          code: 'FORBIDDEN',
        ),
      );
      await pumpDashboard(tester, repo: repo);
      await tapGo(tester);

      expect(find.byType(NotEligibleState), findsNothing,
          reason: 'a non-NOT_ELIGIBLE 403 is an auth problem, not eligibility');
      expect(find.text(message), findsOneWidget,
          reason: 'it lands on the normal error banner, unchanged');
      expect(find.byType(HopBanner), findsWidgets);
    });

    testWidgets('Test 5: GO returns — a refusal is not a terminal state',
        (tester) async {
      final repo = _StubDriverRepo(
        goOnlineError: const ApiException(
          statusCode: 403,
          message: '',
          code: 'NOT_ELIGIBLE',
        ),
      );
      await pumpDashboard(tester, repo: repo);
      await tapGo(tester);

      // Never stuck in goingOnline: the driver may fix the problem and retry.
      final go = tester.widget<GoButton>(find.byType(GoButton));
      expect(go.online, isFalse);
      expect(go.busy, isFalse,
          reason: 'a refused GO settles back to offline, never a dead spinner');

      // And it is tappable again — the generation guard holds, and the second
      // intent reaches the repository.
      repo.goOnlineError = null;
      await tapGo(tester);
      expect(repo.goOnlineCalls, 2,
          reason: 'the driver can retry after fixing whatever it was');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WHAT THIS PHASE CANNOT PROVE, AND SAYS SO.
  //
  // 🔴 Every test in Phase 13 is a CLIENT-CORRECTNESS proof. Not one of them
  // is an end-to-end proof, and it would be dishonest to let a green suite
  // imply otherwise.
  //
  // 1. **#29 — does the bucket accept our presigned PUT?** (OD-14) 13-02 proves
  //    the PUT carries no `Authorization` header and echoes the slot's
  //    `Content-Type` byte-for-byte. It CANNOT prove the bucket agrees. That is
  //    a round-trip against real storage and no unit test substitutes for it.
  //    The Android-native pivot (D1) retired the *browser* CORS risk; the
  //    HEADER CONTRACT still needs the backend's blessing. Relayed in 13-00.
  //
  // 2. **#49 — the invite email dead-ends on a URL with no page behind it.**
  //    🔴 A REAL, ADMIN-PROVISIONED DRIVER CANNOT SIGN IN AT ALL. Every screen
  //    this phase builds is correct and unreachable by a genuinely new driver
  //    until the Supabase redirect target is configured. Relayed in 13-00 as
  //    BLOCKING. **This is the single largest open item in the phase.**
  //
  // 3. **#30 — which of the three things did `NOT_ELIGIBLE` actually mean?**
  //    The app is honest about not knowing, and that is CORRECT behaviour, not
  //    a placeholder. Confirming which reason fires in practice needs a real
  //    suspended/restricted driver on staging. The sub-code ask is relayed.
  //
  // A test cannot assert any of these. What it CAN do is make sure nobody
  // deletes the disclosure — so that is what this group does.
  // ─────────────────────────────────────────────────────────────────────────
  group('Phase 13 — the gates a green suite does NOT close', () {
    test('DOCS/06 still relays #29, #49 and the #30 sub-code ask', () {
      final relay = File('../../DOCS/06-backend-gaps-relay.md');
      expect(relay.existsSync(), isTrue,
          reason: 'the relay is the only place these asks live');
      final text = relay.readAsStringSync();

      // 🔴 A REGRESSION GUARD ON THE RELAY ITSELF. A future tidy-up that
      // deleted this section would silently un-ask three questions the backend
      // team has not yet answered — and the suite would stay green while a real
      // driver still could not log in.
      expect(text.contains('#29'), isTrue,
          reason: 'the storage presigned-PUT round-trip is still unproven');
      expect(text.contains('#49'), isTrue,
          reason: 'the invite dead-end still blocks the front door end-to-end');
      expect(text.contains('#30'), isTrue,
          reason: 'the NOT_ELIGIBLE sub-code is still not served');
      expect(text.contains('NOT_ELIGIBLE'), isTrue,
          reason: 'the sub-code ask names the code it is about');
    });
  });
}

/// Drives the two BOUND driver reads this lane cares about, and nothing else.
///
/// The documents read answers EMPTY throughout this file, deliberately: every
/// test here drives a `403 NOT_ELIGIBLE` against a driver whose documents are
/// perfectly fine. That is the whole point — the app has NO local evidence of a
/// compliance problem, and it must still not invent one.
class _StubDriverRepo implements DriverRepository {
  _StubDriverRepo({this.goOnlineError});

  Object? goOnlineError;
  int goOnlineCalls = 0;

  @override
  Future<List<DriverDocument>> documents() async => const [];

  @override
  Future<void> goOnline() async {
    goOnlineCalls++;
    final err = goOnlineError;
    if (err != null) throw err as Exception;
  }

  @override
  Future<void> goOffline() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the BOUND `POST /me/support-tickets` the honest 403 rung fires —
/// so "there is a way out" is ASSERTED rather than assumed.
class _StubSupportRepo implements SupportRepository {
  final subjects = <String>[];

  @override
  Future<String> createTicket({
    required String subject,
    String? category,
    String? typeCode,
    String? priority,
    String? rideId,
    String? body,
    List<String>? tags,
  }) async {
    subjects.add(subject);
    return 'ticket-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

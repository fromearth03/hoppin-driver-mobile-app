import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/settings/widgets/delete_account_popup.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/code_lines.dart';

/// 🔴 THE HONESTY ASSERTIONS FOR THE DRIVER ACCOUNT-DELETION CONTROL.
///
/// Written and watched FAIL before `features/settings/` existed.
///
/// ## What this file defends
///
/// `DELETE /me` does not exist (#43). The naive responses to that are both
/// wrong:
///
///  * **An inert button.** A control that acknowledges a tap and does nothing
///    with a statutory right is worse than no control, because the driver walks
///    away believing they exercised it.
///  * **A fake success.** Rendering a confirmation that the account is gone,
///    over a request that has merely been queued, is a lie about a legal right.
///
/// The correct answer — and the one these assertions pin — is that the STATE is
/// MISSING_BE while **the ACTION is FULLY BOUND**. UK GDPR Art. 17 mandates the
/// OUTCOME and the DEADLINE, not an automated endpoint, so a manual erasure
/// process is LAWFUL. The control files a real `POST /me/support-tickets` under
/// the `account_deletion` category — a real row, read by a real person, against
/// a real one-month statutory clock — and the copy says exactly that.
///
/// Three things it must NEVER do, one assertion each below:
///  1. Claim the account was DELETED (Test 2).
///  2. Sign the driver out — that SIMULATES deletion and strands them outside
///     the very ticket they now need to follow (Test 3).
///  3. Call an endpoint that does not exist (Test 4).
void main() {
  late _RecordingSupport support;
  late _RecordingAuth auth;

  setUp(() {
    support = _RecordingSupport();
    auth = _RecordingAuth();
  });

  /// Mounts the delete popup over recording stubs.
  ///
  /// The REAL presenter over the REAL widget — only the network and the auth
  /// service are under test control. A test that builds its own sheet proves
  /// only that its own sheet works.
  ///
  /// **Bounded pumps only.** `pumpAndSettle` never returns here: polling
  /// providers keep the frame scheduler busy forever (project convention).
  Future<void> pumpDeleteFlow(WidgetTester tester) async {
    // A TALL viewport, on purpose. The sheet carries a four-paragraph legal
    // disclosure above the confirm button; at the default 800px the button
    // sits below the fold, `tester.tap` silently misses, and Tests 2 and 3
    // would then pass VACUOUSLY over a flow that never ran.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWithValue(support),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDriverDeleteAccountPopup(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Scrolls the confirm button into view, taps it, and lets the future settle.
  ///
  /// The `ensureVisible` is not ceremony. The sheet carries a four-paragraph
  /// legal disclosure above the button; without it `tap` misses, the flow never
  /// runs, and Tests 2 and 3 pass VACUOUSLY over a control that was never
  /// pressed. `warnIfMissed: false` is deliberately NOT set — a missed tap must
  /// stay loud here.
  Future<void> tapConfirm(WidgetTester tester) async {
    final confirm = find.byKey(DriverDeleteAccountKeys.confirmDelete);
    await tester.ensureVisible(confirm);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every string the widget tree currently renders, lower-cased.
  String renderedText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' \n ')
      .toLowerCase();

  // ── Test 1 ────────────────────────────────────────────────────────────────
  testWidgets(
    'the delete action files exactly one REAL ticket under account_deletion',
    (tester) async {
      await pumpDeleteFlow(tester);

      await tapConfirm(tester);

      expect(
        support.calls,
        hasLength(1),
        reason: 'The Art. 17 route is BOUND. Zero calls means the right went '
            'unhonoured; two means a duplicate statutory request ops must '
            'disambiguate by hand.',
      );
      expect(
        support.calls.single.category,
        // The rider's literal, verbatim. The SAME human works the SAME queue,
        // and a driver-specific spelling is a category that gets missed.
        'account_deletion',
        reason: 'Deletion tickets must carry the identical category the rider '
            'files under — one queue, one filter.',
      );
      expect(
        support.calls.single.subject.trim(),
        isNotEmpty,
        reason: 'The request type rides in the subject too, so ops can triage '
            'even if the server drops an unknown category.',
      );
    },
  );

  // ── Test 2 ────────────────────────────────────────────────────────────────
  testWidgets(
    '🔴 it NEVER claims the account was deleted',
    (tester) async {
      await pumpDeleteFlow(tester);

      await tapConfirm(tester);

      final rendered = renderedText(tester);

      // A confirmation of deletion, over a ticket, is a lie about a statutory
      // right. The ticket was FILED. It has not been ACTIONED.
      const banned = <String>[
        'has been deleted',
        'account removed',
        'successfully deleted',
        'your data has been erased',
        'account deleted',
      ];
      for (final phrase in banned) {
        expect(
          rendered.contains(phrase),
          isFalse,
          reason: 'The surface rendered "$phrase" after filing a ticket. '
              'Nothing has been deleted — a person has not yet read the '
              'request. Say a request was SUBMITTED and name the one-month '
              'clock.',
        );
      }

      // And the honest half: it must actually say what DID happen.
      expect(
        rendered.contains('month'),
        isTrue,
        reason: 'The submitted state must name the one-month statutory clock — '
            'otherwise the driver has no idea whether anything is happening.',
      );
    },
  );

  // ── Test 3 ────────────────────────────────────────────────────────────────
  testWidgets(
    '🔴 it does NOT sign the driver out',
    (tester) async {
      await pumpDeleteFlow(tester);

      await tapConfirm(tester);

      expect(
        auth.signOutCalls,
        0,
        reason: 'Signing the driver out SIMULATES deletion and strands them '
            'outside the very ticket they now need to follow. They stay '
            'signed in.',
      );
    },
  );

  // ── Test 4 ────────────────────────────────────────────────────────────────
  test(
    '🔴 no `DELETE /me` call and no deleteAccount( exists anywhere in lib/',
    () {
      // 🔴 COMMENT-STRIPPED. This very file, and the widget it guards, DOCUMENT
      // the ban at length. A raw-text grep would match the prose explaining the
      // rule and go RED on a correct codebase — and a test that cries wolf is
      // deleted within the month, leaving no guard at all.
      final offenders = <String>[];

      for (final src in driverSources()) {
        for (var i = 0; i < src.lines.length; i++) {
          final line = src.lines[i];
          if (line.contains('deleteAccount(')) {
            offenders.add('${src.path}:${i + 1}  $line');
            continue;
          }
          // `.delete(` targeting a `/me` path — the endpoint that does not
          // exist. A call to it 404s and shows the driver a generic failure
          // over what is actually a working manual route.
          if (line.contains('.delete(') && line.contains('/me')) {
            offenders.add('${src.path}:${i + 1}  $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'There is no `DELETE /me` (#43). Calling it 404s and buries a '
            'WORKING manual Art. 17 route under a generic error:\n'
            '${offenders.join('\n')}',
      );
    },
  );
}

/// One recorded `createTicket` invocation.
typedef _TicketCall = ({String subject, String? category, String? body});

/// Records every ticket the flow files. Files nothing over the network.
class _RecordingSupport implements SupportRepository {
  final List<_TicketCall> calls = <_TicketCall>[];

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
    calls.add((subject: subject, category: category, body: body));
    return 'ticket-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records sign-outs. There must never be one.
class _RecordingAuth implements AuthService {
  int signOutCalls = 0;

  @override
  String? get userId => 'driver-1';

  @override
  String? get email => 'driver@example.com';

  @override
  String? get fullName => 'Test Driver';

  @override
  bool get isSignedIn => true;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

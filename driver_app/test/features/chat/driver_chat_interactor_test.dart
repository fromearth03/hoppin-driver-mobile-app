// 15-01 — the driver half of in-trip chat. THE CONTRACT WITH THE SERVER.
//
// `POST|GET /rides/:id/messages` is BOUND and `[either]`. This file pins the
// two inherited non-negotiables paid for once already on the rider side, plus
// the driver's own send-through-a-template path:
//
//   * 🔴 T3 — 409 CHAT_CLOSED is TERMINAL: the composer AND the template chips
//     leave the tree; `DriverChatClosedState` takes their place; no further
//     send is possible.
//   * 🔴 T4 — the OTHER 409 (ACTIVE_TRIP_EXISTS) is a DIFFERENT WORLD: the
//     composer survives. The branch is on `code`, never on `statusCode`.
//   * T1/T2/T5 — the thread loads, a send appends, a transient throw keeps the
//     last list on screen.
//   * T6 — the back exit works from a `go`-navigated route (the rider's shipped
//     bug; we do not re-ship it).
//   * T7 — a template chip sends its body verbatim through the SAME path and
//     gets the SAME CHAT_CLOSED handling.
//
// Bounded pumps ONLY — the chat poll is an infinite `StreamProvider` and
// `pumpAndSettle` would hang forever. Standing project convention.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/chat/driver_chat_builder.dart';
import 'package:hoppin_driver/features/chat/driver_chat_router.dart';
import 'package:hoppin_driver/features/chat/widgets/driver_chat_closed_state.dart';
import 'package:hoppin_driver/features/chat/widgets/driver_chat_templates.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The real ride-service error shape: `{ error, code }` at a 4xx status.
const _chatClosed = ApiException(
  statusCode: 409,
  message: 'Chat is closed for this ride.',
  code: 'CHAT_CLOSED',
);

/// A DIFFERENT 409 — same status, different code. Proves the branch is on
/// `code`, not on the status and not on the human-readable message.
const _otherConflict = ApiException(
  statusCode: 409,
  message: 'You already have an active trip.',
  code: 'ACTIVE_TRIP_EXISTS',
);

final _dark = HoppinTheme.driverDark();

void main() {
  testWidgets('T1 — the thread loads: three messages render, the driver\'s own '
      'and the rider\'s, keyed off the driver\'s userId', (tester) async {
    // Bodies chosen NOT to collide with any DriverChatTemplates chip label —
    // the chips are also on screen, and a fixture that reused a chip string
    // would find two widgets for one message.
    final repo = _RecordingRidesRepo(thread: [
      _msg('m1', 'driver-1', 'Pulling up to the blue door'),
      _msg('m2', 'rider-1', 'Great, thank you'),
      _msg('m3', 'driver-1', 'Two minutes out'),
    ]);
    await _pumpChat(tester, repo);

    expect(find.text('Pulling up to the blue door'), findsOneWidget);
    expect(find.text('Great, thank you'), findsOneWidget);
    expect(find.text('Two minutes out'), findsOneWidget,
        reason: 'every message the repo returned must render as a bubble');

    await _unmount(tester);
  });

  testWidgets('T2 — a send appends: sendMessage is called with the exact body, '
      'the composer clears, the poll refreshes', (tester) async {
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo);

    await tester.enterText(find.byType(TextField), 'I am by the blue door');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.sent, hasLength(1),
        reason: 'tapping send reaches the BOUND sendMessage exactly once');
    expect(repo.sent.single.body, 'I am by the blue door',
        reason: 'the body is verbatim — no prefix, no paraphrase');
    expect(repo.sent.single.rideId, 'ride-1');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
      reason: 'a successful send clears the composer',
    );

    await _unmount(tester);
  });

  testWidgets(
      '🔴 T3 — 409 CHAT_CLOSED is TERMINAL: composer AND chips leave the tree, '
      'DriverChatClosedState replaces them, and no further send is possible',
      (tester) async {
    final repo = _RecordingRidesRepo(
      thread: [_msg('m1', 'rider-1', 'Are you close?')],
      sendThrows: _chatClosed,
    );
    await _pumpChat(tester, repo);

    expect(find.byType(TextField), findsOneWidget,
        reason: 'precondition: the composer is live before the 409');
    expect(find.byType(DriverChatTemplates), findsOneWidget,
        reason: 'precondition: the chips are live before the 409');

    await tester.enterText(find.byType(TextField), 'nearly there');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DriverChatClosedState), findsOneWidget,
        reason: 'a 409 CHAT_CLOSED is PERMANENT — the driver is shown the '
            'terminal state, never a transient error');
    expect(find.byType(TextField), findsNothing,
        reason: 'THE contract: the composer is REMOVED, not greyed. A live '
            'composer under a "chat closed" toast makes the driver keep typing '
            'into a channel that rejects them');
    expect(find.byType(DriverChatTemplates), findsNothing,
        reason: 'a chip is a send affordance too — it goes with the composer');

    // Once closed, always closed. The send surface is structurally gone (no
    // composer, no chips — asserted above), and the interactor's `send`
    // short-circuits on `chatClosed`. Prove the latch holds: a second attempt
    // to drive a send changes nothing.
    final sendsAtClose = repo.sent.length;
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(DriverChatClosedState)),
    ).read(driverChatInteractorProvider.notifier);
    await notifier.send('ride-1', 'try me anyway');
    await tester.pump(const Duration(milliseconds: 50));
    expect(repo.sent.length, sendsAtClose,
        reason: 'after CHAT_CLOSED the send path is a no-op — once closed, '
            'always closed, no request, no retry');

    await _unmount(tester);
  });

  testWidgets(
      '🔴 T4 — the OTHER 409 (ACTIVE_TRIP_EXISTS) is a DIFFERENT WORLD: the '
      'composer SURVIVES. A statusCode branch fails here, and that is the point',
      (tester) async {
    final repo = _RecordingRidesRepo(sendThrows: _otherConflict);
    await _pumpChat(tester, repo);

    await tester.enterText(find.byType(TextField), 'hello?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DriverChatClosedState), findsNothing,
        reason: 'the branch is on code == CHAT_CLOSED — a DIFFERENT 409 must '
            'NOT terminate a live thread. A statusCode == 409 branch would '
            'permanently kill this conversation on an unrelated failure');
    expect(find.byType(TextField), findsOneWidget,
        reason: 'a non-CHAT_CLOSED failure leaves the composer live to retry');

    await _unmount(tester);
  });

  testWidgets('T5 — a transient throw mid-poll keeps the last thread on screen '
      '— ignorance is not emptiness', (tester) async {
    final repo = _RecordingRidesRepo(
      thread: [_msg('m1', 'driver-1', 'Pulling up now')],
    );
    await _pumpChat(tester, repo);

    expect(find.text('Pulling up now'), findsOneWidget);

    // The next poll tick throws — the previously-loaded list must persist.
    repo.messagesThrows = Exception('transient network blip');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Pulling up now'), findsOneWidget,
        reason: 'a transient read failure keeps the last list — an unreachable '
            'server and an empty thread must never look identical');

    await _unmount(tester);
  });

  testWidgets(
      '🔴 T6 — the back exit works from a go-navigated route (no stack): tapping '
      'back lands on /trip/r1, not a dead end', (tester) async {
    final repo = _RecordingRidesRepo();
    final router = GoRouter(
      initialLocation: '/trip/r1',
      routes: [
        GoRoute(
          path: '/trip/:id',
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('TRIP SCREEN')),
          ),
        ),
        ...driverChatRoutes,
      ],
    );
    // Reach chat with `go` — REPLACES rather than pushes, so canPop is false.
    router.go('/trip/r1/chat');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ridesRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(_StubAuth()),
      ],
      child: MaterialApp.router(theme: _dark, routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(DriverChatTemplates), findsOneWidget,
        reason: 'precondition: we are on the chat surface');

    await tester.tap(find.byTooltip('Back'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('TRIP SCREEN'), findsOneWidget,
        reason: 'reached with go (canPop false), the unconditional onBack must '
            'still return the driver to /trip/r1 — the rider shipped this bug '
            'with no leading arrow and stranded the user on the chat screen');

    await _unmount(tester);
  });

  testWidgets(
      'T7 — a template chip sends its body VERBATIM through the same path, and '
      'gets the same CHAT_CLOSED handling', (tester) async {
    final repo = _RecordingRidesRepo(sendThrows: _chatClosed);
    await _pumpChat(tester, repo);

    expect(find.byType(DriverChatTemplates), findsOneWidget);
    final chipText = DriverChatTemplates.templates.first;

    await tester.tap(find.text(chipText));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.sent, hasLength(1),
        reason: 'the chip goes through the same send path as the composer');
    expect(repo.sent.single.body, chipText,
        reason: 'the chip body is sent VERBATIM — never a prefill, never a '
            'paraphrase');
    expect(find.byType(DriverChatClosedState), findsOneWidget,
        reason: 'because the chip shares the ONE send path, it gets byte-'
            'identical CHAT_CLOSED handling');
    expect(find.byType(DriverChatTemplates), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await _unmount(tester);
  });
}

// ── Harness ──────────────────────────────────────────────────────────────────

RideMessage _msg(String id, String senderId, String body) =>
    RideMessage(id: id, senderId: senderId, body: body);

Future<void> _pumpChat(WidgetTester tester, RidesRepository repo) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      ridesRepositoryProvider.overrideWithValue(repo),
      authServiceProvider.overrideWithValue(_StubAuth()),
    ],
    child: MaterialApp(
      theme: _dark,
      home: const DriverChatRiblet(rideId: 'ride-1'),
    ),
  ));
  // The first poll tick lands; the thread paints.
  await tester.pump(const Duration(milliseconds: 50));
}

/// Unmounts so the infinite 3s poll dies with the provider scope before the
/// pending-timer check. The poll's in-flight `Future.delayed(3s)` outlives the
/// dispose, so the tree is torn down and then pumped past the beat.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
}

/// Repo-level recording fake — the ONLY injection point. Records every
/// `sendMessage`, serves a scripted thread, and can be told to throw on send or
/// on the next read.
class _RecordingRidesRepo implements RidesRepository {
  _RecordingRidesRepo({List<RideMessage> thread = const [], this.sendThrows})
      : thread = List.of(thread);

  List<RideMessage> thread;

  /// If set, every `sendMessage` throws this instead of succeeding.
  final Object? sendThrows;

  /// If set, the NEXT `messages()` read throws this once, then clears.
  Object? messagesThrows;

  final List<({String rideId, String body})> sent = [];

  @override
  Future<List<RideMessage>> messages(String rideId, {DateTime? since}) async {
    final t = messagesThrows;
    if (t != null) {
      messagesThrows = null;
      throw t;
    }
    return List.of(thread);
  }

  @override
  Future<RideMessage> sendMessage({
    required String rideId,
    required String body,
  }) async {
    sent.add((rideId: rideId, body: body));
    if (sendThrows != null) throw sendThrows!;
    final m =
        RideMessage(id: 'sent-${sent.length}', senderId: 'driver-1', body: body);
    thread = [...thread, m];
    return m;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal auth double — the chat surface reads only `userId` (to decide which
/// bubbles are "mine"). The driver is `driver-1`.
class _StubAuth implements AuthService {
  @override
  String? get userId => 'driver-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

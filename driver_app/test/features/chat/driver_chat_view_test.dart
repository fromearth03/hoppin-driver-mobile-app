// 15-01 — the driver chat VIEW: templates-first, keyboard-second, and the
// designed terminal state. Dark is the driver's PRIMARY theme (SF-02).
//
// The contract tests live in driver_chat_interactor_test.dart and
// driver_chat_motion_test.dart. This file pins the surface itself: the five
// verbatim templates, the composer's presence when stationary, the closed
// state's copy and its forward exit, and a clean dark-theme pump.
//
// Bounded pumps ONLY — the chat poll is an infinite StreamProvider.
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

const _chatClosed = ApiException(
  statusCode: 409,
  message: 'Chat is closed for this ride.',
  code: 'CHAT_CLOSED',
);

final _dark = HoppinTheme.driverDark();

void main() {
  testWidgets('the five driver templates render verbatim, in order — this is '
      'the driver\'s half of the conversation', (tester) async {
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo);

    // The chip row is a horizontal scroller — trailing chips lay out off the
    // right edge, so we assert the constant (the verbatim source of truth the
    // chips render from) plus that the row itself is present and the leading
    // chips are on screen.
    expect(find.byType(DriverChatTemplates), findsOneWidget);
    expect(DriverChatTemplates.templates, const [
      "I'm on my way",
      "I'm outside",
      "I've arrived",
      "I'm waiting outside — can't see you",
      'Running a few minutes late',
    ], reason: 'the driver set is five verbatim quick replies, in order');
    expect(find.text(DriverChatTemplates.templates.first), findsOneWidget,
        reason: 'the leading chip is on the surface, verbatim');

    await _unmount(tester);
  });

  testWidgets('stationary: the composer is present with a Send action',
      (tester) async {
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets(
      'the closed state explains itself and offers a FORWARD exit — never a '
      'dead end', (tester) async {
    final repo = _RecordingRidesRepo(sendThrows: _chatClosed);
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
    router.go('/trip/r1/chat');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ridesRepositoryProvider.overrideWithValue(repo),
        authServiceProvider.overrideWithValue(_StubAuth()),
      ],
      child: MaterialApp.router(theme: _dark, routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text(DriverChatTemplates.templates.first));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DriverChatClosedState), findsOneWidget);
    expect(find.text(DriverChatClosedState.headline), findsOneWidget,
        reason: 'the driver is told, in words, why they can no longer send');

    // The forward exit works and returns to the trip.
    await tester.tap(find.text('Back to trip'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('TRIP SCREEN'), findsOneWidget,
        reason: 'the terminal state carries a forward exit — it never strands '
            'the driver on a closed surface');

    await _unmount(tester);
  });

  testWidgets('dark theme: the chat surface pumps clean', (tester) async {
    final repo = _RecordingRidesRepo(thread: const [
      RideMessage(id: 'm1', senderId: 'rider-1', body: 'Where are you?'),
    ]);
    await _pumpChat(tester, repo);

    expect(find.text('Where are you?'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the dark theme (SF-02 primary) must pump without exceptions');

    await _unmount(tester);
  });
}

// ── Harness ──────────────────────────────────────────────────────────────────

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
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
}

class _RecordingRidesRepo implements RidesRepository {
  _RecordingRidesRepo({List<RideMessage> thread = const [], this.sendThrows})
      : thread = List.of(thread);

  List<RideMessage> thread;
  final Object? sendThrows;
  final List<({String rideId, String body})> sent = [];

  @override
  Future<List<RideMessage>> messages(String rideId, {DateTime? since}) async =>
      List.of(thread);

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

class _StubAuth implements AuthService {
  @override
  String? get userId => 'driver-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

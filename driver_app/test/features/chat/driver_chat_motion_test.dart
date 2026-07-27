// 🔴 15-01 — THE MOTION CONTRACT. BOTH HALVES.
//
// The keyboard goes away above 5 mph (15-00). The template chips DO NOT. That
// asymmetry is the entire design: the driver never NEEDS the keyboard, so
// removing it costs them nothing — but suppressing the chips too would leave
// them MUTE at the exact moment they most need to say "I'm outside", and they
// would pick up their phone and text on WhatsApp, which is the HANDHELD offence
// we were trying to avoid.
//
//   * M1 — the keyboard is GONE at speed: no TextField, and the designed
//     TypingUnavailableInMotion notice stands in its place.
//   * 🔴 M2 — THE TEMPLATES ARE STILL LIVE AT SPEED, and tapping one actually
//     fires sendMessage. This is the assertion people skip.
//   * M3 — the composer comes back when stopped.
//   * M4 — no >2-tap flow: a template send at speed is ONE tap.
//
// Bounded pumps ONLY — the chat poll is an infinite StreamProvider.
// Theme: HoppinTheme.driverDark() (SF-02 — dark is the driver's PRIMARY theme).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/chat/driver_chat_builder.dart';
import 'package:hoppin_driver/features/chat/widgets/driver_chat_templates.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';
import 'package:hoppin_driver/features/motion/widgets/typing_locked_in_motion.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final _dark = HoppinTheme.driverDark();

void main() {
  testWidgets(
      '🔴 M1 — the keyboard is GONE at speed: no TextField, and '
      'TypingUnavailableInMotion stands in its place', (tester) async {
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo, inMotion: true);

    expect(find.byType(TextField), findsNothing,
        reason: 'a keyboard is the least glanceable thing in the app — at speed '
            'it is REMOVED from the tree, not disabled');
    expect(find.byType(TypingUnavailableInMotion), findsOneWidget,
        reason: 'the composer never vanishes silently — a designed notice names '
            'the quick replies that still work');

    await _unmount(tester);
  });

  testWidgets(
      '🔴 M2 — THE TEMPLATES ARE STILL LIVE AT SPEED, and tapping one actually '
      'fires sendMessage — one tap, at 30 mph, in a cradle', (tester) async {
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo, inMotion: true);

    expect(find.byType(DriverChatTemplates), findsOneWidget,
        reason: '🔴 the chips are the ONLY send path that survives 5 mph. '
            'Suppressing them makes the driver mute and sends them to WhatsApp');

    final chip = DriverChatTemplates.templates.first;
    expect(find.text(chip), findsOneWidget,
        reason: 'the chip is on screen and readable at speed');

    await tester.tap(find.text(chip));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.sent, hasLength(1),
        reason: '🔴 a driver at 30 mph must be able to tell the rider "I\'m '
            'outside" with ONE tap. The chip must actually send in motion — not '
            'just render');
    expect(repo.sent.single.body, chip,
        reason: 'the template body is sent verbatim, even in motion');

    await _unmount(tester);
  });

  testWidgets(
      'M3 — the composer comes back when stopped: the TextField is reachable '
      'again once inMotion flips false', (tester) async {
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo, inMotion: false);

    expect(find.byType(TextField), findsOneWidget,
        reason: 'a gate that never opens is a deletion, not a gate — stopped, '
            'the driver gets their keyboard back');
    expect(find.byType(TypingUnavailableInMotion), findsNothing,
        reason: 'stationary, the lock is transparent — the composer is real');

    await _unmount(tester);
  });

  testWidgets(
      'M4 — no >2-tap flow: sending a template from the chat surface at speed is '
      'exactly ONE tap', (tester) async {
    // Chat is one `context.go('/trip/:id/chat')` away from the runner (15-03
    // wires that ONE-TAP control). This lane owns the surface AT the path: once
    // there, a template send must cost exactly one tap and reveal no keyboard.
    final repo = _RecordingRidesRepo();
    await _pumpChat(tester, repo, inMotion: true);

    expect(find.byType(TextField), findsNothing,
        reason: 'no keyboard step is interposed — the send stays one tap');

    await tester.tap(find.text(DriverChatTemplates.templates.first));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));

    expect(repo.sent, hasLength(1),
        reason: 'one tap, one message — the whole reason templates exist');

    await _unmount(tester);
  });
}

// ── Harness ──────────────────────────────────────────────────────────────────

Future<void> _pumpChat(
  WidgetTester tester,
  RidesRepository repo, {
  required bool inMotion,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      ridesRepositoryProvider.overrideWithValue(repo),
      authServiceProvider.overrideWithValue(_StubAuth()),
      motionInteractorProvider.overrideWith(() => _PinnedMotion(inMotion)),
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

/// The motion gate, pinned. Overriding the provider keeps the assertions about
/// the INTERACTION BUDGET, not about geolocation.
class _PinnedMotion extends MotionInteractor {
  _PinnedMotion(this._inMotion);

  final bool _inMotion;

  @override
  MotionState build() => MotionState(
        inMotion: _inMotion,
        speedMps: _inMotion ? 13.4 : 0.0,
      );
}

class _RecordingRidesRepo implements RidesRepository {
  _RecordingRidesRepo({List<RideMessage> thread = const []})
      : thread = List.of(thread);

  List<RideMessage> thread;

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

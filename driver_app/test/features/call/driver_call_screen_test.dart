import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/call/driver_call_screen.dart';
import 'package:hoppin_driver/features/call/widgets/driver_call_unavailable_state.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The four inert call frames — reachable, disabled, identity-free.
///
/// The driver call surface is BUILT, REACHABLE and INERT. There is no
/// `POST /rides/:id/call` proxy and no masked-number field on any payload
/// (#45), so nothing dials and no rider identity exists to render. These tests
/// assert the surface tells that truth: four frames a selector reaches, every
/// control visibly disabled, the #45 rung mounted with a working forward exit
/// to chat, and NOT ONE fabricated character of rider identity.
///
/// The never-dial guarantee itself lives in `never_dial_test.dart`.
/// Bounded pumps only.
void main() {
  GoRouter buildRouter({String initial = '/trip/r1/call'}) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/trip/:id/call',
            builder: (_, s) =>
                DriverCallScreen(rideId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/trip/:id/chat',
            builder: (_, s) => Scaffold(
              body: Text('chat-landing:${s.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/trip/:id',
            builder: (_, s) => Scaffold(
              body: Text('trip-landing:${s.pathParameters['id']}'),
            ),
          ),
        ],
      );

  Future<void> pumpScreen(WidgetTester tester, {GoRouter? router}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HoppinTheme.driverDark(),
          routerConfig: router ?? buildRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> select(WidgetTester tester, DriverCallFrame frame) async {
    await tester.tap(find.byKey(Key('call.frame.${frame.name}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('C1 — all FOUR frames are reachable, including incoming',
      (tester) async {
    await pumpScreen(tester);
    for (final frame in DriverCallFrame.values) {
      await select(tester, frame);
      expect(find.byKey(Key('call.frame.body.${frame.name}')), findsOneWidget,
          reason: 'frame ${frame.name} must render its own distinct body');
    }
    // The driver-only frame the rider surface does not have.
    expect(DriverCallFrame.values, contains(DriverCallFrame.incoming));
  });

  testWidgets('C2 — every control is visibly INERT (onPressed null / disabled)',
      (tester) async {
    await pumpScreen(tester);

    // Connected exposes hangup/speaker/mute — each reads as a DISABLED button.
    await select(tester, DriverCallFrame.connected);
    for (final key in const [
      'call.action.hangup',
      'call.action.speaker',
      'call.action.mute',
    ]) {
      expect(
        tester.getSemantics(find.byKey(Key(key))),
        isSemantics(isButton: true, isEnabled: false),
        reason: '$key must read as a disabled button — there is no call to '
            'act on',
      );
    }

    // Incoming exposes answer/decline — both DISABLED buttons.
    await select(tester, DriverCallFrame.incoming);
    for (final key in const [
      'call.action.answer',
      'call.action.decline',
    ]) {
      expect(
        tester.getSemantics(find.byKey(Key(key))),
        isSemantics(isButton: true, isEnabled: false),
        reason: '$key must be disabled — Answer to a real number is the '
            'single most dangerous control in the product',
      );
    }
  });

  testWidgets('C3 — the #45 rung is MOUNTED on every frame', (tester) async {
    await pumpScreen(tester);
    for (final frame in DriverCallFrame.values) {
      await select(tester, frame);
      expect(find.byType(DriverCallUnavailableState), findsOneWidget,
          reason: 'the #45 rung must be constructed in the real view on '
              'frame ${frame.name} — Group C checks the mount site');
    }
  });

  testWidgets('C4 — the rung has a FORWARD EXIT to chat', (tester) async {
    await pumpScreen(tester);
    // The rung's action is what forwards — mounted under the `call.rung` key.
    final action = find.descendant(
      of: find.byKey(const Key('call.rung')),
      matching: find.text('Message rider'),
    );
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    // `context.push` layers a page over this one — the M3 FadeForwards runs
    // ~800ms, so settle with pump() + 3×350ms rather than a single short pump.
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(find.text('chat-landing:r1'), findsOneWidget,
        reason: 'the rung must route to /trip/r1/chat — the channel that works');
  });

  testWidgets('C5 — NOT ONE fabricated character of rider identity',
      (tester) async {
    // Boots over the base (live-shaped) providers: tripRiderContext() → null.
    await pumpScreen(tester);

    for (final frame in DriverCallFrame.values) {
      await select(tester, frame);

      final ratingShape = RegExp(r'\d\.\d');
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final data = text.data ?? '';
        expect(data.contains('★'), isFalse,
            reason: 'a star glyph renders on ${frame.name}: "$data"');
        expect(data.toLowerCase().contains('trips'), isFalse,
            reason: 'a trip count renders on ${frame.name}: "$data"');
        expect(ratingShape.hasMatch(data), isFalse,
            reason: 'a \\d.\\d rating shape renders on ${frame.name}: "$data" '
                '— the clock reads 00:00, never a rating');
        expect(data.contains('Sarah'), isFalse,
            reason: 'the Figma persona "Sarah" renders on ${frame.name} — '
                'that person does not exist');
      }
    }
  });

  testWidgets('C6 — the exit works from a `go`-navigated route with no stack',
      (tester) async {
    await pumpScreen(tester, router: buildRouter());
    // No stack beneath — reached as the initial location. The exit is the
    // top-bar back chevron, which must `go` to /trip/r1 rather than a no-op pop.
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('trip-landing:r1'), findsOneWidget,
        reason: 'back must land on /trip/r1 even with nothing to pop — the '
            'rider shipped this broken');
  });
}

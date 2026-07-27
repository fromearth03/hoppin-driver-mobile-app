import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/call/driver_call_screen.dart';
import 'package:hoppin_driver/features/comms/url_launcher_gateway.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/source_scan.dart';

/// 🔴 THE NEVER-DIAL GUARANTEE.
///
/// Two independent assertions, deliberately redundant, because either one alone
/// can be defeated:
///
///  - N1 (source) can be beaten by string concatenation, by a plugin that dials
///    without a URI, or by a constant living in a shared package.
///  - N2 (runtime) cannot: nothing reaches the OS except through the gateway,
///    and in test the gateway is a recording fake required to record ZERO
///    launches across every control on every frame.
///
/// With no masked-call bridge (#45) the only number the DRIVER app could ever
/// reach is the RIDER'S PERSONAL MOBILE — which this app must never even
/// possess. That is not a UX concern; it is safeguarding, and a locked
/// prohibition.
void main() {
  test(
      '🔴 N1 — no telephone scheme, no direct-caller plugin anywhere in '
      'apps/driver/lib', () {
    // Build the banned needles AT RUNTIME so this test file does not itself
    // contain the literal string it bans — otherwise the next lane that greps
    // `apps/driver` wholesale trips over the guard's own source.
    final telScheme = '${String.fromCharCode(116)}${String.fromCharCode(101)}'
        '${String.fromCharCode(108)}:'; // t-e-l-colon
    final directCaller = 'flutter_phone_direct'
        '${String.fromCharCode(95)}caller'; // the phone-direct plugin import

    final sources = scanDartSources();
    expect(sources, isNotEmpty,
        reason: 'the source sweep found no .dart files — it would pass '
            'vacuously and guard nothing');

    final telHits = <String>[];
    final callerHits = <String>[];
    for (final src in sources) {
      for (var i = 0; i < src.lines.length; i++) {
        final line = src.lines[i];
        if (line.contains(telScheme)) {
          telHits.add('${src.path}:${i + 1}');
        }
        if (line.contains(directCaller)) {
          callerHits.add('${src.path}:${i + 1}');
        }
      }
    }

    expect(telHits, isEmpty,
        reason: 'apps/driver/lib names the telephone URI scheme. With no masked '
            "bridge (#45) that scheme reaches the RIDER'S PERSONAL NUMBER:\n"
            '${telHits.join('\n')}');
    expect(callerHits, isEmpty,
        reason: 'apps/driver/lib imports a direct-caller plugin — it dials '
            'without a URI and defeats the gateway entirely:\n'
            '${callerHits.join('\n')}');
  });

  testWidgets(
      '🔴 N2 — the recording fake records ZERO launches across every control on '
      'ALL FOUR frames', (tester) async {
    final recorder = _RecordingUrlLauncher();

    await _pumpCallScreen(tester, recorder: recorder);

    for (final frame in DriverCallFrame.values) {
      await tester.tap(find.byKey(Key('call.frame.${frame.name}')));
      await _bounded(tester);

      for (final key in const [
        'call.action.hangup',
        'call.action.speaker',
        'call.action.mute',
        'call.action.answer',
        'call.action.decline',
        'call.identity',
        'call.rung',
        'call.close',
      ]) {
        final finder = find.byKey(Key(key));
        if (finder.evaluate().isNotEmpty) {
          // 🔴 Scroll the control into view FIRST. A control below the fold is
          // silently missed by a bare tap — which is exactly how a wired Answer
          // button would slip past this guard. Sabotage-verified: without this,
          // launching from the incoming Answer button was NOT caught.
          await tester.ensureVisible(finder);
          await _bounded(tester);
          await tester.tap(finder, warnIfMissed: false);
          await _bounded(tester);
        }
      }
    }

    expect(recorder.calls, isEmpty,
        reason: 'The driver app launched a URL from the call surface. With no '
            "masked bridge (#45) the only number reachable is the RIDER'S "
            'PERSONAL ONE.');
  });

  testWidgets('🔴 N3 — the connected timer never ticks', (tester) async {
    await _pumpCallScreen(tester, recorder: _RecordingUrlLauncher());

    await tester.tap(find.byKey(const Key('call.frame.connected')));
    await _bounded(tester);

    final timer = find.byKey(const Key('call.connected.timer'));
    expect(timer, findsOneWidget);
    expect(tester.widget<Text>(timer).data, '00:00');

    // Pump five seconds of time in bounded steps.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(tester.widget<Text>(timer).data, '00:00',
        reason: 'a clock that counts is a counterfeit call duration over a call '
            'that does not exist');
  });
}

/// Pumps the call screen at `/trip/r1/call` with the recording gateway and
/// live-shaped nulling repository stubs.
Future<void> _pumpCallScreen(
  WidgetTester tester, {
  required _RecordingUrlLauncher recorder,
}) async {
  final router = GoRouter(
    initialLocation: '/trip/r1/call',
    routes: [
      GoRoute(
        path: '/trip/:id/call',
        builder: (_, s) => DriverCallScreen(rideId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/chat',
        builder: (_, s) => const Scaffold(body: Text('chat-landing')),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (_, s) => const Scaffold(body: Text('trip-landing')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        urlLauncherProvider.overrideWithValue(recorder),
      ],
      child: MaterialApp.router(
        theme: HoppinTheme.driverDark(),
        routerConfig: router,
      ),
    ),
  );
  await _bounded(tester);
}

Future<void> _bounded(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Records every URI it is asked to launch and launches nothing.
class _RecordingUrlLauncher implements UrlLauncher {
  final calls = <Uri>[];

  @override
  Future<bool> launch(Uri uri) async {
    calls.add(uri);
    return true;
  }
}

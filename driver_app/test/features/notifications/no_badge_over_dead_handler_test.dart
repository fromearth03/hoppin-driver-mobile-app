import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/notifications/notification_centre_screen.dart';
import 'package:hoppin_driver/features/notifications/notification_feed.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/code_lines.dart';

/// 🔴 NO BADGE OVER A DEAD HANDLER.
///
/// Push REGISTRATION is BOUND on Android — `device_os: "android"` is a value the
/// contract accepts, and the GO tap really posts a real token. Push DELIVERY is
/// GATED on the backend's `FCM_CREDENTIALS_FILE` (#15/#16): **the server cannot
/// send.**
///
/// A bell with an unread badge over a handler that cannot fire is a promise the
/// platform cannot keep. That mistake was made once already in this project — a
/// hardcoded `notificationCount: 2` shipped a permanent fake unread badge on
/// every rider screen, and Wave 0 deleted it. These are the guards that stop it
/// coming back.
void main() {
  test('Test 5: the unread count over the LIVE no-op gateway is zero', () {
    // No feed override. The live `driverFcmGatewayProvider` default is
    // `NoopDriverFcmGateway`, whose `onMessage()` emits nothing — today's
    // honest state of a correctly-wired client waiting on a server.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(driverNotificationFeedProvider),
      isEmpty,
      reason: 'The live gateway delivers nothing (#15/#16), so the session '
          'feed is empty. That is correct, not a bug.',
    );
    expect(
      container.read(unreadDriverNotificationCountProvider),
      0,
      reason: '🔴 The unread count must be a REAL count over the REAL feed. '
          'Over the live no-op gateway it is 0, and `HopTopBar` hides the badge '
          'at 0. Anything else is a badge over a handler that cannot fire.',
    );
  });

  test('Test 6: no hardcoded notification/badge count anywhere in apps/driver',
      () {
    // Comments blanked first — the doc comments across this feature discuss
    // `notificationCount: 2` at length as the mistake NOT to repeat, and a
    // raw-text grep would go red on a correct codebase.
    final sources = driverSources();
    expect(sources, isNotEmpty, reason: 'the sweep must actually scan files');

    // `notificationCount: 2`, `badgeCount:7`, `unreadCount: 3`, … — an INTEGER
    // LITERAL handed to a count parameter. A `ref.watch(...)` expression is
    // fine; a number is not.
    final hardcoded = RegExp(
      r'\b(notificationCount|badgeCount|unread\w*)\s*:\s*[0-9]+',
    );

    final offences = <String>[];
    for (final source in sources) {
      for (var i = 0; i < source.lines.length; i++) {
        final match = hardcoded.firstMatch(source.lines[i]);
        if (match != null) {
          offences.add('${source.path}:${i + 1}: ${source.lines[i].trim()}');
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason: '🔴 A HARDCODED UNREAD BADGE IS BACK:\n${offences.join('\n')}\n'
          'Push delivery is GATED (#15/#16) — the server cannot send. A '
          'constant count draws a badge over a handler that cannot fire. This '
          'exact defect shipped a permanent fake badge on every rider screen '
          'once. The count must be read from the real feed.',
    );
  });

  testWidgets('Test 7: the centre says push delivery is not yet switched on',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverNotificationCentreScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? t.textSpan?.toPlainText() ?? '').toLowerCase())
        .join('   ');

    // It must NAME the gate in plain English: pushes are not being sent yet.
    expect(
      rendered.contains('push'),
      isTrue,
      reason: 'The centre must name the push rail plainly so the driver knows '
          'why nothing arrives (#15/#16).',
    );
    expect(
      RegExp(r"(not|isn't|aren't|cannot|can't|yet)").hasMatch(rendered),
      isTrue,
      reason: 'The centre must say push delivery is NOT yet switched on.',
    );

    // 🔴 And it must PROMISE NOTHING. "You'll be notified" over a server that
    // cannot send is the same lie as the badge, one sentence longer.
    for (final promise in <String>[
      "you'll be notified",
      'you will be notified',
      "we'll let you know",
      'we will notify you',
      "you'll get a notification",
    ]) {
      expect(
        rendered.contains(promise),
        isFalse,
        reason: '🔴 The centre promised "$promise" over a delivery rail that '
            'is GATED (#15/#16). The server cannot send. Do not promise what '
            'the platform cannot keep.',
      );
    }
  });
}

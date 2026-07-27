import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/auth/reset_landing_screen.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/code_lines.dart';

/// 🔴 THE HONESTY ASSERTIONS FOR THE DRIVER PASSWORD-RESET LANDING (#49).
///
/// The Supabase reset redirect lands on a URL with **no page behind it**. So a
/// "New Password" form on this path would take a driver's new password and post
/// it **nowhere**. They would see a tick, close the app, and be locked out of
/// their own livelihood tomorrow morning — and they would not know why.
///
/// The Figma's `New Password.jpg` frame is exactly the form these assertions
/// refuse to let anybody draw.
void main() {
  /// Pumps the real landing screen on the driver's PRIMARY theme (SF-02: dark).
  ///
  /// **Bounded pumps only. Never `pumpAndSettle`** — project convention.
  Future<void> pumpReset(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const DriverResetLandingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ── Test 6 ────────────────────────────────────────────────────────────────
  testWidgets(
    '🔴 there is NO password field of any kind on the reset landing',
    (tester) async {
      await pumpReset(tester);

      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'A field on this path posts a new password NOWHERE (#49). The '
            'driver sees a tick and is locked out tomorrow morning.',
      );
      expect(
        find.byType(TextFormField),
        findsNothing,
        reason: 'Same failure mode, wrapped in a Form. There is no page behind '
            'the redirect to receive it.',
      );
      expect(
        find.byType(EditableText),
        findsNothing,
        reason: 'No editable text of any kind. Nothing typed here can go '
            'anywhere.',
      );
    },
  );

  // ── Test 7 ────────────────────────────────────────────────────────────────
  testWidgets(
    'the gated state is DESIGNED and offers a real way forward',
    (tester) async {
      await pumpReset(tester);

      // It names the situation honestly rather than failing silently.
      expect(
        find.byType(HopEmptyState),
        findsOneWidget,
        reason: 'A dead end with no designed state is just as opaque to the '
            'driver as a fake form is dishonest.',
      );

      // 🔴 And it does not STRAND them. A disclosure with no exit is only
      // half-honest — a driver locked out of their livelihood needs a route,
      // not an apology.
      expect(
        find.byKey(DriverResetKeys.contactSupport),
        findsOneWidget,
        reason: 'Support is the BOUND route — a human can reset the password '
            'today.',
      );
      expect(
        find.byKey(DriverResetKeys.backToSignIn),
        findsOneWidget,
        reason: 'And back to sign-in, for the driver who still knows their '
            'current password.',
      );
    },
  );

  // ── Test 8 ────────────────────────────────────────────────────────────────
  test(
    '🔴 nothing under features/auth/ would take a password on the reset path',
    () {
      // 🔴 COMMENT-STRIPPED (see `code_lines.dart`). The reset screen's own doc
      // comment explains at length why there is no password form here. A raw
      // grep would match that prose and go red on a CORRECT codebase.
      final offenders = <String>[];
      const banned = <String>['updateUser(', 'resetPassword(', 'newPassword'];

      final dir = Directory('lib/features/auth');
      for (final file in dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = codeLines(file.readAsStringSync());
        for (var i = 0; i < lines.length; i++) {
          for (final needle in banned) {
            if (lines[i].contains(needle)) {
              offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Nothing on the reset path may accept or submit a password — '
            'there is no endpoint behind the redirect (#49):\n'
            '${offenders.join('\n')}',
      );
    },
  );
}

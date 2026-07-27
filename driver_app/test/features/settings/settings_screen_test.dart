import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/app.dart';
import 'package:hoppin_driver/features/settings/settings_screen.dart';
import 'package:hoppin_driver/features/settings/widgets/driver_settings_prefs_unavailable.dart';
import 'package:hoppin_driver/features/settings/widgets/driver_settings_toggle_row.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/code_lines.dart';

/// 🔴 THE HONESTY ASSERTIONS FOR THE DRIVER SETTINGS SCREEN (PS-02).
///
/// A screen full of controls, exactly one of which works. The failure modes it
/// guards against, in order of severity:
///
///  1. **A security claim the platform cannot honour.** The Figma renders a
///     passcode/PIN switch ON. No such feature exists anywhere in this
///     codebase. A switch that is ON and advertises a protection that does not
///     exist is a SECURITY LIE — materially worse than a broken preference, and
///     there is no honest rung for it. You cannot disclose your way out of
///     telling someone their money is guarded when it is not.
///  2. **A no-op closure.** `onChanged: (_) {}` gives a full interactive
///     response over silence and is indistinguishable from a working control.
///     Inert means NULL.
///  3. **Eight rungs instead of one.** Noise is how a disclosure gets ignored.
void main() {
  final dark = HoppinTheme.driverDark();

  /// **Bounded pumps only. Never `pumpAndSettle`** — project convention.
  Future<void> pumpSettings(WidgetTester tester) async {
    // A TALL viewport. Settings is a long ListView and the delete-account route
    // sits at the bottom by design; at the default 800px it is never built and
    // an assertion about it would be about the viewport, not the screen.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(_StubAuth())],
        child: MaterialApp(
          theme: dark,
          home: const DriverSettingsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('🔴 ONE screen-level rung, not one per toggle', (tester) async {
    await pumpSettings(tester);

    expect(
      find.byType(DriverSettingsPrefsUnavailable),
      findsOneWidget,
      reason: 'Eight identical rungs is noise, and noise is how a disclosure '
          'gets ignored.',
    );
  });

  testWidgets(
    '🔴 every inert toggle has onChanged NULL — never a no-op closure',
    (tester) async {
      await pumpSettings(tester);

      final rows =
          tester.widgetList<DriverSettingsToggleRow>(
        find.byType(DriverSettingsToggleRow),
      ).toList();

      expect(rows, isNotEmpty);

      // Exactly ONE live control on the screen: the theme.
      final live = rows.where((r) => r.onChanged != null).toList();
      expect(
        live,
        hasLength(1),
        reason: 'The theme is the one genuinely working control. Any other '
            'live switch writes to a preferences endpoint that does not exist.',
      );
      expect(
        find.byKey(DriverSettingsKeys.themeToggle),
        findsOneWidget,
        reason: 'And it is the theme — an ADDITION the Figma omits. Truth here '
            'means adding a control, not only removing them. Dark is the '
            "driver's PRIMARY theme (SF-02), not a courtesy.",
      );
    },
  );

  testWidgets('the theme toggle genuinely applies', (tester) async {
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(_StubAuth())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: dark, home: const DriverSettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      container.read(themeModeProvider),
      isNot(ThemeMode.system),
      reason: 'It writes the REAL theme provider the whole app watches — not a '
          'local bool that pretends to. A toggle wired to a local bool is the '
          'exact false-persistence signal the rest of this screen refuses.',
    );
  });

  testWidgets('the delete-account route is findable, in the destructive role',
      (tester) async {
    await pumpSettings(tester);

    expect(
      find.byKey(DriverSettingsKeys.deleteAccountRow),
      findsOneWidget,
      reason: 'Art. 17 is not honoured by a right you have to know to look '
          'for.',
    );
  });

  // ── The security-claim sweep ──────────────────────────────────────────────
  test(
    '🔴 no PIN / passcode / biometric claim anywhere in apps/driver/lib',
    () {
      // 🔴 COMMENT-STRIPPED. `settings_screen.dart`'s own doc comment explains
      // at length why the toggle is omitted — a raw grep would match that prose
      // and go red on a CORRECT codebase, and a test that cries wolf is deleted
      // within the month, leaving no guard at all.
      final offenders = <String>[];
      final banned = <RegExp>[
        RegExp(r'require\s*pin', caseSensitive: false),
        RegExp(r'\brequirePin\b'),
        RegExp(r'\bpasscode\b', caseSensitive: false),
        RegExp(r'\bbiometric', caseSensitive: false),
      ];

      for (final src in driverSources()) {
        for (var i = 0; i < src.lines.length; i++) {
          for (final pattern in banned) {
            if (pattern.hasMatch(src.lines[i])) {
              offenders.add('${src.path}:${i + 1}  ${src.lines[i].trim()}');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'A control claiming the app or its payments are protected by a '
            'passcode, when no such feature exists, is a SECURITY LIE. There '
            'is no honest rung for it — it is OMITTED, not seamed:\n'
            '${offenders.join('\n')}',
      );
    },
  );

  // ── The no-op-closure sweep ───────────────────────────────────────────────
  test('🔴 no no-op closures on inert controls in profile/ or settings/', () {
    final offenders = <String>[];
    final banned = <RegExp>[
      RegExp(r'onPressed:\s*\(\s*\)\s*\{\s*\}'),
      RegExp(r'onChanged:\s*\(\s*_\s*\)\s*\{\s*\}'),
      RegExp(r'onTap:\s*\(\s*\)\s*\{\s*\}'),
    ];

    for (final src in driverSources()) {
      final path = src.path.replaceAll(r'\', '/');
      if (!path.contains('lib/features/profile') &&
          !path.contains('lib/features/settings')) {
        continue;
      }
      for (var i = 0; i < src.lines.length; i++) {
        for (final pattern in banned) {
          if (pattern.hasMatch(src.lines[i])) {
            offenders.add('${src.path}:${i + 1}  ${src.lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'An empty callback is a lie: it gives a full tap ripple over '
          'silence, indistinguishable from a working control. Inert means '
          'NULL:\n${offenders.join('\n')}',
    );
  });
}

class _StubAuth implements AuthService {
  @override
  String? get userId => 'driver-1';

  @override
  bool get isSignedIn => true;

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
